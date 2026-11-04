#pragma once

#include <QString>
#include <atomic>
#include <cstdint>

class NvComputer;
class QThread;

// Client-side adaptive bitrate for hosts that accept runtime bitrate changes
// (Vibepollo's HTTPS /bitrate endpoint). Wi-Fi drops arrive as bursts: once the
// link starts losing whole frames, a stream at a fixed high bitrate keeps
// overrunning it and every loss becomes a visible spike. The adapter watches
// the decoder's received / network-dropped frame counts twice a second, cuts
// the encoder bitrate quickly when frames start going missing, and ramps it
// back up slowly once the link has been clean for a few seconds.
//
// Set DECKVOID_ADAPTIVE_BITRATE=0 to turn it off.
class BitrateAdapter
{
public:
    // Called from the video decoder thread for every frame.
    static void noteFrameReceived() { s_Received.fetch_add(1, std::memory_order_relaxed); }
    static void noteFramesDropped(uint32_t count) { s_Dropped.fetch_add(count, std::memory_order_relaxed); }

    // Start for a stream at the user's bitrate (the ceiling). Safe to call once per stream.
    static void start(NvComputer* computer, int ceilingKbps);
    // Stop before the connection is torn down. Blocks until the worker exits.
    static void stop();

    // Pure decision step, exposed for tests: returns the next bitrate.
    struct State {
        int currentKbps = 0;
        int ceilingKbps = 0;
        int floorKbps = 0;
        int cleanTicks = 0;      // consecutive half-second windows with no lost frames
        int ticksSinceChange = 0;
    };
    static int decide(State& state, uint32_t received, uint32_t dropped);

private:
    static void run(NvComputer* computer, int ceilingKbps);

    static std::atomic<uint32_t> s_Received;
    static std::atomic<uint32_t> s_Dropped;
    static std::atomic<bool> s_Stop;
    static QThread* s_Thread;
};
