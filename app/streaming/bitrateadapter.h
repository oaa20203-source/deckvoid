#pragma once

#include "bitratepolicy.h"

#include <QString>
#include <atomic>
#include <cstdint>

class NvComputer;
class QThread;

// Client-side adaptive bitrate for hosts that accept runtime bitrate changes
// (Vibepollo's HTTPS /bitrate endpoint). Wi-Fi drops arrive as bursts: once the
// link starts losing whole frames, a stream at a fixed high bitrate keeps
// overrunning it and every loss becomes a visible spike. The adapter watches
// loss events, outages and frame delay twice a second and lets BitratePolicy
// decide. The rules
// live in BitratePolicy; this class is the thread and the host request.
//
// Set DECKVOID_ADAPTIVE_BITRATE=0 to turn it off.
class BitrateAdapter
{
public:
    // Called from the video decoder thread for every frame.
    static void noteFrameReceived() { s_Received.fetch_add(1, std::memory_order_relaxed); }
    // Called from the video decoder thread for every gap in the frame numbers (one
    // loss event, however many frames it spans)
    static void noteLossEvent(uint32_t lostFrames);
    // Called from the video decoder thread for every keyframe that arrives
    static void noteKeyFrame(uint64_t nowUs) { s_LastKeyFrameUs.store(nowUs, std::memory_order_relaxed); }
    // Called from the video decoder thread for every frame: when the frame was
    // complete (last packet; LiGetMicroseconds clock) and its RTP timestamp (90 kHz, host clock)
    static void noteFrameTiming(uint64_t completeUs, uint32_t rtpTimestamp);

    // Start for a stream at the user's bitrate (the ceiling) and frame rate. Safe to call once per stream.
    static void start(NvComputer* computer, int ceilingKbps, int fps);
    // Stop before the connection is torn down. Blocks until the worker exits.
    static void stop();

private:
    static void run(NvComputer* computer, int ceilingKbps, int fps);

    static std::atomic<uint32_t> s_Received;
    static std::atomic<uint32_t> s_LossEvents;
    static std::atomic<uint32_t> s_LostFrames;
    static std::atomic<uint32_t> s_LongestLossEvent;
    static std::atomic<uint64_t> s_LastKeyFrameUs;
    static std::atomic<int64_t> s_WindowMinDelayUs;
    static std::atomic<bool> s_ResetTiming;
    static std::atomic<bool> s_Stop;
    static QThread* s_Thread;
};
