#pragma once

#include <cstdint>

// The decision logic of the adaptive bitrate, with no Qt or network code in it so
// it can be unit tested (tests/streaming). BitrateAdapter feeds it one half-second
// window at a time.
//
// Cutting:
// - Loss is counted in loss events (one gap in the frame numbers, however many
//   frames it spans), not in frames: every frame discarded while waiting for a
//   recovery frame belongs to the same event.
// - An isolated loss event does not cut. Loss events that repeat within 5 s do:
//   the link is losing at this rate.
// - A standing queue cuts even without loss: every frame of 3 windows in a row
//   (1.5 s) arrived 25 ms or more later than the uncongested baseline, or 2 windows
//   in a row 100 ms or more later.
// - A Wi-Fi outage (loss after no video packets at all for 250 ms or more, or one
//   event spanning a third of a second of video without a standing queue) is not
//   congestion: a lower bitrate would not prevent the next one. It holds the bitrate
//   for 2 s, never cuts, and is not counted as a loss event. A pause with no loss is
//   a still screen (the host sends nothing when nothing changes): a neutral window.
// - A cut is 15%, and remembers 90% of the bitrate that failed (the knee).
// - For 2 s after a cut, loss is ignored (not even counted toward a repeat): frames
//   encoded at the old bitrate are still in flight. The losses behind a cut are not
//   counted toward the next one either. At the floor, nothing more happens.
// - A window counts as clean only with no loss event and a flat delay (under 20 ms
//   above the baseline). Every step up waits for clean windows.
//
// Stepping up depends on the host (BitrateAdapter finds out by watching for a
// keyframe after each change):
// - In-place hosts change the bitrate on the next frame without a keyframe, so
//   steps are cheap: +4% after 2 clean seconds, at most every 3 s, and +1.5% once
//   within 5% of the knee or above it.
// - Hosts that send a keyframe with every change (and hosts not yet identified)
//   get few, large steps: the first step after a cut waits for 30 clean seconds,
//   then +15% at most every 9 s up to the knee; a step under 4% is skipped. Above
//   the knee it probes 3% after 5 clean minutes since the cut, a wait that doubles
//   with each further cut (up to 20 min) and resets after 5 clean minutes at the
//   user's bitrate.
//
// The user's bitrate is the ceiling: the stream starts there and never goes above it.
class BitratePolicy
{
public:
    static constexpr int kTickMs = 500;

    struct Window {
        uint32_t received = 0;          // frames the decoder received
        uint32_t lossEvents = 0;        // gaps in the frame numbers
        uint32_t lostFrames = 0;        // frames in those gaps
        uint32_t longestLossEvent = 0;  // frames in the largest gap
        int queueDelayMs = 0;           // lowest frame delay above the baseline (0 when unknown)
        bool outage = false;            // no video packets at all for 250 ms or more
    };

    struct State {
        int currentKbps = 0;
        int ceilingKbps = 0;            // the user's bitrate
        int floorKbps = 0;
        int capKbps = 0;                // the knee: 90% of the bitrate that last failed
        int expectedFramesPerWindow = 0; // stream fps / 2; 0 when unknown
        bool inPlaceChanges = false;    // the host changes the bitrate without a keyframe
        uint32_t tick = 0;
        uint32_t lastLossEventTick = 0; // 0 when none yet
        int cleanTicks = 0;             // consecutive clean, full windows
        int ticksSinceChange = 0;
        int holdTicks = 0;              // windows left in which loss is ignored
        int queueingTicks = 0;          // consecutive windows 25 ms or more over the baseline
        int severeQueueingTicks = 0;    // consecutive windows 100 ms or more over it
        int rampWaitTicks = 0;          // clean windows needed before the next step up
        int capLiftWaitTicks = 0;       // keyframe hosts: clean windows before probing past the knee
        int cutsSinceReset = 0;         // cuts since the stream last held the ceiling
    };

    static State initial(int ceilingKbps, int fps);
    // Returns the bitrate for the next window (the current one when nothing changes)
    static int decide(State& s, const Window& w);
    static int roundKbps(double kbps);
};
