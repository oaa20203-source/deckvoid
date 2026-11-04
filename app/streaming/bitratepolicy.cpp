#include "bitratepolicy.h"

#include <algorithm>

namespace {
// Ignore windows with too few frames to judge (a still desktop sends few frames)
constexpr uint32_t kMinFramesPerWindow = 10;
// A window is "full" (can count as clean) when it carried this share of the expected frames
constexpr double kFullWindowShare = 0.5;
// Back off when a window loses at least this share of its frames (and 2+ frames)
constexpr double kBackoffLoss = 0.03;
constexpr double kBackoffFactor = 0.75;
// After a cut, the ramp may not go above this share of the bitrate that failed
constexpr double kCapFactor = 0.9;
// Windows after a cut during which further loss is ignored (2 s)
constexpr int kHoldTicks = 4;
// Ramp up after this many clean windows, then again every kRampEveryTicks
constexpr int kCleanTicksBeforeRamp = 8;    // 4 s
constexpr int kRampEveryTicks = 4;          // 2 s
constexpr double kRampFactor = 1.08;
// Clean windows at the cap before the cap lifts by one ramp step (30 s)
constexpr int kCleanTicksBeforeCapRaise = 60;
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
    s.floorKbps = std::max(kAbsoluteFloorKbps, roundKbps(ceilingKbps * kFloorShare));
    s.expectedFramesPerWindow = std::max(0, fps) * kTickMs / 1000;
    return s;
}

int BitratePolicy::decide(State& s, uint32_t received, uint32_t dropped)
{
    s.ticksSinceChange++;
    const bool holding = s.holdTicks > 0;
    if (holding) {
        s.holdTicks--;
    }

    const uint32_t total = received + dropped;
    if (total < kMinFramesPerWindow) {
        return s.currentKbps;
    }

    const double loss = (double)dropped / total;
    if (dropped >= 2 && loss >= kBackoffLoss) {
        s.cleanTicks = 0;
        if (holding) {
            // The host is still applying the last cut; judge again once it has landed
            return s.currentKbps;
        }
        s.capKbps = std::max(s.floorKbps, roundKbps(s.currentKbps * kCapFactor));
        s.holdTicks = kHoldTicks;
        const int next = std::max(s.floorKbps, roundKbps(s.currentKbps * kBackoffFactor));
        if (next < s.currentKbps) {
            s.ticksSinceChange = 0;
        }
        return next;
    }

    if (dropped == 0) {
        // Only a window that carried most of the expected frames says anything about
        // the link; a window spent waiting for a recovery frame does not
        if ((double)received >= s.expectedFramesPerWindow * kFullWindowShare) {
            s.cleanTicks++;
        }
    }
    else {
        // A single lost frame: neither punish nor reward
        s.cleanTicks = 0;
    }

    if (s.cleanTicks < kCleanTicksBeforeRamp || s.ticksSinceChange < kRampEveryTicks) {
        return s.currentKbps;
    }
    if (s.currentKbps < s.capKbps) {
        s.ticksSinceChange = 0;
        return std::min(s.capKbps, roundKbps(s.currentKbps * kRampFactor));
    }
    if (s.capKbps < s.ceilingKbps && s.cleanTicks >= kCleanTicksBeforeCapRaise) {
        // Probe one step above the bitrate that failed, then wait another 30 s
        s.capKbps = std::min(s.ceilingKbps, roundKbps(s.capKbps * kRampFactor));
        s.cleanTicks = 0;
        s.ticksSinceChange = 0;
        return std::min(s.capKbps, roundKbps(s.currentKbps * kRampFactor));
    }
    return s.currentKbps;
}
