#include "bitrateadapter.h"

#include "backend/nvhttp.h"
#include "backend/nvcomputer.h"

#include <Limelight.h>

#include <QThread>
#include <SDL.h>

#include <algorithm>
#include <climits>
#include <iterator>

std::atomic<uint32_t> BitrateAdapter::s_Received{0};
std::atomic<uint32_t> BitrateAdapter::s_LossEvents{0};
std::atomic<uint32_t> BitrateAdapter::s_LostFrames{0};
std::atomic<uint32_t> BitrateAdapter::s_LongestLossEvent{0};
std::atomic<uint64_t> BitrateAdapter::s_LastKeyFrameUs{0};
std::atomic<int64_t> BitrateAdapter::s_WindowMinDelayUs{INT64_MAX};
std::atomic<bool> BitrateAdapter::s_ResetTiming{false};
std::atomic<bool> BitrateAdapter::s_Stop{false};
QThread* BitrateAdapter::s_Thread = nullptr;

namespace {
constexpr int kAbsoluteFloorKbps = 10000;
// The uncongested one-way delay is the lowest window minimum over this many windows
// (60 s): long enough that a standing queue does not become the baseline
constexpr int kDelayBaselineWindows = 120;
// A window in which no video packet arrived for this long held a Wi-Fi outage
constexpr uint64_t kOutageGapUs = 250000;
// A keyframe this soon after a bitrate change means the host sends one with every change
constexpr uint64_t kKeyFrameAfterChangeUs = 200000;
// Failed requests are retried after a wait that doubles up to this many windows (60 s)
constexpr int kMaxRetryBackoffTicks = 120;
}

void BitrateAdapter::noteLossEvent(uint32_t lostFrames)
{
    s_LossEvents.fetch_add(1, std::memory_order_relaxed);
    s_LostFrames.fetch_add(lostFrames, std::memory_order_relaxed);
    uint32_t longest = s_LongestLossEvent.load(std::memory_order_relaxed);
    while (lostFrames > longest &&
           !s_LongestLossEvent.compare_exchange_weak(longest, lostFrames, std::memory_order_relaxed)) {
    }
}

void BitrateAdapter::noteFrameTiming(uint64_t completeUs, uint32_t rtpTimestamp)
{
    // Decoder thread only
    static uint32_t s_LastRtp = 0;
    static uint64_t s_Wraps = 0;
    if (s_ResetTiming.exchange(false, std::memory_order_relaxed)) {
        // A new stream: its RTP clock starts over
        s_LastRtp = 0;
        s_Wraps = 0;
    }
    if (rtpTimestamp == 0) {
        return;
    }
    if (s_LastRtp != 0 && rtpTimestamp < s_LastRtp && s_LastRtp - rtpTimestamp > 0x80000000U) {
        s_Wraps++;
    }
    s_LastRtp = rtpTimestamp;
    const int64_t rtpUs = int64_t(((s_Wraps << 32) | rtpTimestamp) * 1000 / 90);
    // One-way delay plus the (constant) offset between the two clocks
    const int64_t delayUs = int64_t(completeUs) - rtpUs;
    int64_t current = s_WindowMinDelayUs.load(std::memory_order_relaxed);
    while (delayUs < current &&
           !s_WindowMinDelayUs.compare_exchange_weak(current, delayUs, std::memory_order_relaxed)) {
    }

}

void BitrateAdapter::start(NvComputer* computer, int ceilingKbps, int fps)
{
    stop();
    if (qgetenv("DECKVOID_ADAPTIVE_BITRATE") == "0" || computer == nullptr || ceilingKbps <= kAbsoluteFloorKbps) {
        return;
    }
    s_Stop = false;
    s_Received = 0;
    s_LossEvents = 0;
    s_LostFrames = 0;
    s_LongestLossEvent = 0;
    s_LastKeyFrameUs = 0;
    s_WindowMinDelayUs = INT64_MAX;
    s_ResetTiming = true;
    s_Thread = QThread::create([computer, ceilingKbps, fps]() { run(computer, ceilingKbps, fps); });
    s_Thread->setObjectName("BitrateAdapter");
    s_Thread->start(QThread::LowPriority);
}

void BitrateAdapter::stop()
{
    if (s_Thread == nullptr) {
        return;
    }
    s_Stop = true;
    s_Thread->wait();
    delete s_Thread;
    s_Thread = nullptr;
}

void BitrateAdapter::run(NvComputer* computer, int ceilingKbps, int fps)
{
    BitratePolicy::State state = BitratePolicy::initial(ceilingKbps, fps);

    NvHTTP http(computer);
    int64_t windowMins[kDelayBaselineWindows];
    std::fill(std::begin(windowMins), std::end(windowMins), INT64_MAX);
    int windowIndex = 0;
    int retryBackoffTicks = 0;      // windows to wait after a failed request
    int retryWaitTicks = 0;
    uint64_t changeRequestedUs = 0; // the last change, until checked for a keyframe
    uint64_t changeAppliedUs = 0;
    int changesWithoutKeyFrame = 0;
    bool modeKnown = false;

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Adaptive bitrate: on (ceiling %d kbps, floor %d kbps, %d frames expected per %d ms)",
                state.ceilingKbps, state.floorKbps, state.expectedFramesPerWindow, BitratePolicy::kTickMs);

    while (!s_Stop) {
        for (int slept = 0; slept < BitratePolicy::kTickMs && !s_Stop; slept += 50) {
            QThread::msleep(50);
        }
        if (s_Stop) {
            break;
        }

        BitratePolicy::Window window;
        window.received = s_Received.exchange(0);
        window.lossEvents = s_LossEvents.exchange(0);
        window.lostFrames = s_LostFrames.exchange(0);
        window.longestLossEvent = s_LongestLossEvent.exchange(0);

        // How far this window's best-case delay sits above the uncongested baseline
        const int64_t windowMin = s_WindowMinDelayUs.exchange(INT64_MAX);
        windowMins[windowIndex] = windowMin;
        windowIndex = (windowIndex + 1) % kDelayBaselineWindows;
        const int64_t baseline = *std::min_element(std::begin(windowMins), std::end(windowMins));
        window.queueDelayMs = (windowMin != INT64_MAX && baseline != INT64_MAX) ?
                                  int(std::min<int64_t>((windowMin - baseline) / 1000, 60000)) : 0;
        // No video packets at all for this long is an outage; waiting for a
        // recovery frame still receives (dropped) packets, so it is not one
        window.outage = LiGetAndResetLongestVideoPacketGapUs() >= kOutageGapUs;

        // Does this host send a keyframe with every bitrate change? Watch the first changes.
        if (changeAppliedUs != 0 && LiGetMicroseconds() - changeAppliedUs >= kKeyFrameAfterChangeUs) {
            // The keyframe can arrive before the HTTP answer does, so look from the request on
            const uint64_t keyFrameUs = s_LastKeyFrameUs.load(std::memory_order_relaxed);
            const bool keyFrame = keyFrameUs >= changeRequestedUs && keyFrameUs < changeAppliedUs + kKeyFrameAfterChangeUs;
            changeAppliedUs = 0;
            if (keyFrame) {
                changesWithoutKeyFrame = 0;
                if (!modeKnown || state.inPlaceChanges) {
                    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                                "Adaptive bitrate: the host sends a keyframe with each change; few, large steps");
                }
                state.inPlaceChanges = false;
                modeKnown = true;
            }
            else if (++changesWithoutKeyFrame >= 2 && !state.inPlaceChanges) {
                SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                            "Adaptive bitrate: the host changes the bitrate in place (no keyframe); small, frequent steps");
                state.inPlaceChanges = true;
                modeKnown = true;
            }
        }

        if (retryWaitTicks > 0) {
            // Waiting after a failed request: time still passes for the policy
            retryWaitTicks--;
            state.tick++;
            state.ticksSinceChange++;
            continue;
        }

        const int previous = state.currentKbps;
        const BitratePolicy::State beforeDecision = state;
        const int next = BitratePolicy::decide(state, window);
        if (next == previous) {
            continue;
        }

        int applied = next;
        const uint64_t requestUs = LiGetMicroseconds();
        const int status = http.setRuntimeBitrate(next, 2000, &applied);
        if (status == 200) {
            retryBackoffTicks = 0;
            state.currentKbps = applied;
            changeRequestedUs = requestUs;
            changeAppliedUs = LiGetMicroseconds();
            if (applied < next) {
                // The host clamped it: never ramp past what it accepts
                state.capKbps = std::min(state.capKbps, applied);
                state.ceilingKbps = std::min(state.ceilingKbps, applied);
                state.floorKbps = std::min(state.floorKbps, applied);
            }
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Adaptive bitrate: %d -> %d kbps%s (%u loss events, %u frames lost, longest %u, queue delay %d ms%s, knee %d kbps, %s)",
                        previous, applied, applied != next ? " (host clamped the request)" : "",
                        window.lossEvents, window.lostFrames, window.longestLossEvent, window.queueDelayMs,
                        window.outage ? ", outage" : "", state.capKbps,
                        state.inPlaceChanges ? "in-place host" : "keyframe host");
        }
        else if (status == 400) {
            // The bitrate does not fit the host's pacing ceiling. Going up: treat the
            // current bitrate as the ceiling and stop trying.
            if (next > previous) {
                state.capKbps = state.ceilingKbps = previous;
                state.floorKbps = std::min(state.floorKbps, previous);
            }
            else {
                // A refused cut was not applied: undo what the decision recorded
                const int ticks = state.ticksSinceChange;
                state = beforeDecision;
                state.ticksSinceChange = ticks;
            }
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Adaptive bitrate: host refused %d kbps (over its pacing ceiling); staying at %d kbps",
                        next, previous);
        }
        else {
            // The change was not applied: undo what the decision recorded (knee,
            // hold, cut count) so a failed cut is not counted as a real one, and
            // retry after a wait that doubles each time. A timeout (a lossy or relayed
            // link) is not a refusal, so the adapter never gives up.
            const int ticks = state.ticksSinceChange;
            state = beforeDecision;
            state.ticksSinceChange = ticks;
            retryBackoffTicks = std::min(kMaxRetryBackoffTicks, std::max(2, retryBackoffTicks * 2));
            retryWaitTicks = retryBackoffTicks;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Adaptive bitrate: request for %d kbps failed (host answered %d); retrying in %d ms",
                        next, status, retryBackoffTicks * BitratePolicy::kTickMs);
        }
    }
}
