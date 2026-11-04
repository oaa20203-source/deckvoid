#pragma once

#include <cstdint>

// The decision logic of the adaptive bitrate, with no Qt or network code in it so
// it can be unit tested (tests/streaming). BitrateAdapter feeds it one half-second
// window at a time: the frames the decoder received and the frames the network lost.
//
// Rules:
// - A window that loses 3% or more of its frames (and at least 2) cuts the bitrate by
//   a quarter and caps the later ramp at 90% of the bitrate that just failed.
// - For 2 s after a cut, loss is ignored: the host is still applying the change and
//   frames encoded at the old bitrate are still in flight. Loss that continues after
//   the hold cuts again.
// - A window counts as clean only when it carried at least half the frames the stream
//   should deliver. A window spent waiting for a reference-frame recovery is not clean.
// - After 4 s of clean windows the bitrate climbs 8% every 2 s, up to the cap.
// - The cap lifts by one 8% step after 30 s of clean windows at the cap, so a link
//   that failed at a bitrate is probed again slowly instead of every few seconds.
// - Every further cut doubles that wait (60 s, 120 s, ... up to 5 min): a link that
//   keeps failing the same probe is probed less and less often. The wait goes back to
//   30 s once the stream has sat at the user's bitrate for 30 clean seconds.
class BitratePolicy
{
public:
    static constexpr int kTickMs = 500;

    struct State {
        int currentKbps = 0;
        int ceilingKbps = 0;            // the user's bitrate
        int floorKbps = 0;
        int capKbps = 0;                // highest bitrate the ramp may reach now
        int expectedFramesPerWindow = 0; // stream fps / 2; 0 when unknown
        int cleanTicks = 0;             // consecutive clean, full windows
        int ticksSinceChange = 0;
        int holdTicks = 0;              // windows left in which loss is ignored
        int capLiftWaitTicks = 0;       // clean windows needed at the cap before it lifts
        int cutsSinceReset = 0;         // cuts since the stream last held the ceiling
    };

    static State initial(int ceilingKbps, int fps);
    static int decide(State& s, uint32_t received, uint32_t dropped);
    static int roundKbps(double kbps);
};
