#include "bitratepolicy.h"

#include <algorithm>

namespace {
// Ignore windows with too few frames to judge (a still screen sends few frames)
constexpr uint32_t kMinFramesPerWindow = 10;
// A window is "full" (can count as clean) when it carried this share of the expected frames
constexpr double kFullWindowShare = 0.5;
// Loss events this many windows apart or closer are "repeated" (5 s)
constexpr uint32_t kRepeatLossTicks = 10;
// One loss event spanning this much video (a third of a second) is an outage, not
// congestion, unless the link is also queueing (then recoveries are just slow)
constexpr int kOutageLossMs = 333;
// Standing queue: the window's lowest delay above the baseline, and for how long
constexpr int kQueueDelayTrendMs = 25;
constexpr int kQueueDelayTrendTicks = 3;
constexpr int kQueueDelaySevereMs = 100;
constexpr int kQueueDelaySevereTicks = 2;
// A clean window's delay stays within this much of the baseline
constexpr int kQueueDelayCleanMs = 20;
constexpr double kBackoffFactor = 0.85;
// The knee: 90% of the bitrate that failed
constexpr double kCapFactor = 0.9;
// Windows after a cut or an outage during which loss is ignored (2 s)
constexpr int kHoldTicks = 4;

// In-place hosts: cheap, frequent, small steps
constexpr int kFastCleanTicks = 4;          // 2 s clean
constexpr int kFastEveryTicks = 6;          // at most every 3 s
constexpr double kFastStep = 1.04;
constexpr double kFastStepNearKnee = 1.015;
constexpr double kNearKneeShare = 0.95;

// Keyframe hosts: every change costs a keyframe, so few and large steps
constexpr int kSlowCleanTicks = 20;         // 10 s
constexpr int kSlowCleanTicksAfterCut = 60; // 30 s
constexpr int kSlowEveryTicks = 18;         // 9 s
constexpr double kSlowStep = 1.15;
constexpr double kSlowMinStepShare = 0.04;
constexpr double kSlowKneeProbe = 1.03;
constexpr int kSlowKneeProbeTicks = 600;    // 5 min
constexpr int kSlowKneeProbeMaxTicks = 2400; // 20 min

// Never go below this share of the user's bitrate, or below 10 Mbps
constexpr double kFloorShare = 0.35;
constexpr int kAbsoluteFloorKbps = 10000;
}

int BitratePolicy::roundKbps(double kbps)
{
    return (int)(kbps / 500.0 + 0.5) * 500;
}

BitratePolicy::State BitratePolicy::initial(int ceilingKbps, int fps)
{
    State s;
    s.ceilingKbps = ceilingKbps;
    s.currentKbps = ceilingKbps;
    s.capKbps = ceilingKbps;
    s.floorKbps = std::min(ceilingKbps, std::max(kAbsoluteFloorKbps, roundKbps(ceilingKbps * kFloorShare)));
    s.expectedFramesPerWindow = std::max(0, fps) * kTickMs / 1000;
    s.capLiftWaitTicks = kSlowKneeProbeTicks;
    s.rampWaitTicks = kSlowCleanTicks;
    return s;
}

int BitratePolicy::decide(State& s, const Window& w)
{
    s.tick++;
    s.ticksSinceChange++;
    const bool holding = s.holdTicks > 0;
    if (holding) {
        s.holdTicks--;
    }

    // An outage: frames were lost to a pause in the link, not to the bitrate. A
    // pause without loss is a still screen (the host sends nothing when nothing
    // changes): a neutral window. An outage holds, never cuts, is not clean, and
    // is not remembered as a loss event.
    const uint32_t fps = (uint32_t)s.expectedFramesPerWindow * 1000 / kTickMs;
    const uint32_t outageFrames = fps > 0 ? std::max<uint32_t>(20, fps * kOutageLossMs / 1000) : 40;
    const bool longEvent = w.longestLossEvent >= outageFrames && w.queueDelayMs < kQueueDelaySevereMs;
    if (w.lossEvents > 0 && (w.outage || longEvent)) {
        s.cleanTicks = 0;
        s.queueingTicks = 0;
        s.severeQueueingTicks = 0;
        s.holdTicks = std::max(s.holdTicks, kHoldTicks);
        return s.currentKbps;
    }

    // A standing queue (not counted during a hold: the queue built before the
    // cut is still draining)
    const bool delayed = w.received > 0 && !holding;
    s.queueingTicks = (delayed && w.queueDelayMs >= kQueueDelayTrendMs) ? s.queueingTicks + 1 : 0;
    s.severeQueueingTicks = (delayed && w.queueDelayMs >= kQueueDelaySevereMs) ? s.severeQueueingTicks + 1 : 0;
    const bool queueing = s.queueingTicks >= kQueueDelayTrendTicks ||
                          s.severeQueueingTicks >= kQueueDelaySevereTicks;

    // Repeated loss events. Loss during the hold is ignored entirely: frames
    // encoded at the old bitrate are still in flight.
    bool repeatedLoss = false;
    if (w.lossEvents > 0) {
        s.cleanTicks = 0;
        if (!holding) {
            repeatedLoss = w.lossEvents >= 2 ||
                           (s.lastLossEventTick != 0 && s.tick - s.lastLossEventTick <= kRepeatLossTicks);
            s.lastLossEventTick = s.tick;
        }
    }

    if (repeatedLoss || queueing) {
        s.cleanTicks = 0;
        if (holding) {
            // The host is still applying the last cut; judge again once it has landed
            return s.currentKbps;
        }
        const int next = std::max(s.floorKbps, roundKbps(s.currentKbps * kBackoffFactor));
        if (next >= s.currentKbps) {
            // Already at the floor: nothing to change, and nothing to remember
            return s.currentKbps;
        }
        s.capKbps = std::max(s.floorKbps, roundKbps(s.currentKbps * kCapFactor));
        s.holdTicks = kHoldTicks;
        // The losses behind this cut are spent: the next one starts a new count
        s.lastLossEventTick = 0;
        s.queueingTicks = 0;
        s.severeQueueingTicks = 0;
        s.rampWaitTicks = kSlowCleanTicksAfterCut;
        // Keyframe hosts: the first cut keeps the 5 min wait; each one after it doubles it
        if (s.cutsSinceReset++ > 0) {
            s.capLiftWaitTicks = std::min(kSlowKneeProbeMaxTicks, s.capLiftWaitTicks * 2);
        }
        s.ticksSinceChange = 0;
        return next;
    }

    if (w.lossEvents > 0) {
        // An isolated loss event: no cut, but not clean
        return s.currentKbps;
    }

    if (w.received < kMinFramesPerWindow) {
        // Too few frames to judge (a still screen): neither clean nor unclean
        return s.currentKbps;
    }

    if (w.queueDelayMs < kQueueDelayCleanMs) {
        // Only a window that carried most of the expected frames says anything about the link
        if ((double)w.received >= s.expectedFramesPerWindow * kFullWindowShare) {
            s.cleanTicks++;
        }
    }
    else {
        // Delay is rising: no step up
        s.cleanTicks = 0;
    }

    if (s.inPlaceChanges) {
        if (s.cleanTicks < kFastCleanTicks || s.ticksSinceChange < kFastEveryTicks ||
                s.currentKbps >= s.ceilingKbps) {
            return s.currentKbps;
        }
        const double step = s.currentKbps < s.capKbps * kNearKneeShare ? kFastStep : kFastStepNearKnee;
        const int next = std::min(s.ceilingKbps, std::max(s.currentKbps + 500, roundKbps(s.currentKbps * step)));
        // Holding a rate above the knee moves the knee up with it
        s.capKbps = std::max(s.capKbps, next);
        s.ticksSinceChange = 0;
        if (next >= s.ceilingKbps) {
            s.cutsSinceReset = 0;
            s.capLiftWaitTicks = kSlowKneeProbeTicks;
        }
        return next;
    }

    // Keyframe hosts
    if (s.cleanTicks < s.rampWaitTicks || s.ticksSinceChange < kSlowEveryTicks) {
        return s.currentKbps;
    }
    if (s.currentKbps < s.capKbps) {
        const int next = std::min(s.capKbps, roundKbps(s.currentKbps * kSlowStep));
        if (next - s.currentKbps >= s.currentKbps * kSlowMinStepShare) {
            s.ticksSinceChange = 0;
            s.rampWaitTicks = kSlowCleanTicks;
            return next;
        }
        // Close enough to the knee: treat it as reached instead of paying a keyframe for it
    }
    if (s.currentKbps >= s.ceilingKbps && s.cleanTicks >= kSlowKneeProbeTicks) {
        // The link carries the user's bitrate again: probe at the normal pace next time
        s.capLiftWaitTicks = kSlowKneeProbeTicks;
        s.cutsSinceReset = 0;
        return s.currentKbps;
    }
    if (s.capKbps < s.ceilingKbps && s.cleanTicks >= s.capLiftWaitTicks) {
        // Probe one small step past the knee (at least 500 kbps), in one change
        s.capKbps = std::min(s.ceilingKbps, std::max(s.capKbps + 500, roundKbps(s.capKbps * kSlowKneeProbe)));
        s.cleanTicks = 0;
        s.ticksSinceChange = 0;
        return s.capKbps;
    }
    return s.currentKbps;
}
