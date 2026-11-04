#include "bitrateadapter.h"

#include "backend/nvhttp.h"
#include "backend/nvcomputer.h"

#include <QThread>
#include <SDL.h>

#include <algorithm>

std::atomic<uint32_t> BitrateAdapter::s_Received{0};
std::atomic<uint32_t> BitrateAdapter::s_Dropped{0};
std::atomic<bool> BitrateAdapter::s_Stop{false};
QThread* BitrateAdapter::s_Thread = nullptr;

namespace {
// Half-second decision windows
constexpr int kTickMs = 500;
// Ignore windows with too few frames to judge (a still desktop sends few frames)
constexpr uint32_t kMinFramesPerWindow = 10;
// Back off when a window loses at least this share of its frames (and 2+ frames)
constexpr double kBackoffLoss = 0.03;
constexpr double kBackoffFactor = 0.75;
// Ramp up after this many clean windows, then again every kRampEveryTicks
constexpr int kCleanTicksBeforeRamp = 8;   // 4 s
constexpr int kRampEveryTicks = 4;         // 2 s
constexpr double kRampFactor = 1.08;
// Never go below this share of the user's bitrate, or below 10 Mbps
constexpr double kFloorShare = 0.35;
constexpr int kAbsoluteFloorKbps = 10000;

int roundKbps(double kbps) { return (int)(kbps / 500.0 + 0.5) * 500; }
}

int BitrateAdapter::decide(State& s, uint32_t received, uint32_t dropped)
{
    s.ticksSinceChange++;
    const uint32_t total = received + dropped;
    if (total < kMinFramesPerWindow) {
        return s.currentKbps;
    }

    const double loss = (double)dropped / total;
    if (dropped >= 2 && loss >= kBackoffLoss) {
        s.cleanTicks = 0;
        const int next = std::max(s.floorKbps, roundKbps(s.currentKbps * kBackoffFactor));
        if (next < s.currentKbps) {
            s.ticksSinceChange = 0;
        }
        return next;
    }

    if (dropped == 0) {
        s.cleanTicks++;
    }
    else {
        // A single lost frame: neither punish nor reward
        s.cleanTicks = 0;
    }

    if (s.cleanTicks >= kCleanTicksBeforeRamp && s.ticksSinceChange >= kRampEveryTicks &&
            s.currentKbps < s.ceilingKbps) {
        s.ticksSinceChange = 0;
        return std::min(s.ceilingKbps, roundKbps(s.currentKbps * kRampFactor));
    }
    return s.currentKbps;
}

void BitrateAdapter::start(NvComputer* computer, int ceilingKbps)
{
    stop();
    if (qgetenv("DECKVOID_ADAPTIVE_BITRATE") == "0" || computer == nullptr || ceilingKbps <= kAbsoluteFloorKbps) {
        return;
    }
    s_Stop = false;
    s_Received = 0;
    s_Dropped = 0;
    s_Thread = QThread::create([computer, ceilingKbps]() { run(computer, ceilingKbps); });
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

void BitrateAdapter::run(NvComputer* computer, int ceilingKbps)
{
    State state;
    state.ceilingKbps = ceilingKbps;
    state.currentKbps = ceilingKbps;
    state.floorKbps = std::max(kAbsoluteFloorKbps, roundKbps(ceilingKbps * kFloorShare));

    NvHTTP http(computer);
    int failures = 0;

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Adaptive bitrate: on (ceiling %d kbps, floor %d kbps)",
                state.ceilingKbps, state.floorKbps);

    while (!s_Stop) {
        for (int slept = 0; slept < kTickMs && !s_Stop; slept += 50) {
            QThread::msleep(50);
        }
        if (s_Stop) {
            break;
        }

        const uint32_t received = s_Received.exchange(0);
        const uint32_t dropped = s_Dropped.exchange(0);
        const int previous = state.currentKbps;
        const int next = decide(state, received, dropped);
        if (next == previous) {
            continue;
        }

        const int status = http.setRuntimeBitrate(next);
        if (status == 200) {
            failures = 0;
            state.currentKbps = next;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Adaptive bitrate: %d -> %d kbps (%u of %u frames lost in the last %d ms)",
                        previous, next, dropped, received + dropped, kTickMs);
        }
        else {
            // Hosts without the endpoint (404/unsupported) or that refuse it (403):
            // stop trying after a few attempts so we never add traffic for nothing.
            if (++failures >= 3) {
                SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                            "Adaptive bitrate: off (host answered %d to runtime bitrate changes)", status);
                break;
            }
        }
    }
}
