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
constexpr int kAbsoluteFloorKbps = 10000;
}

void BitrateAdapter::start(NvComputer* computer, int ceilingKbps, int fps)
{
    stop();
    if (qgetenv("DECKVOID_ADAPTIVE_BITRATE") == "0" || computer == nullptr || ceilingKbps <= kAbsoluteFloorKbps) {
        return;
    }
    s_Stop = false;
    s_Received = 0;
    s_Dropped = 0;
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
    int failures = 0;

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

        const uint32_t received = s_Received.exchange(0);
        const uint32_t dropped = s_Dropped.exchange(0);
        const int previous = state.currentKbps;
        const int next = BitratePolicy::decide(state, received, dropped);
        if (next == previous) {
            continue;
        }

        const int status = http.setRuntimeBitrate(next);
        if (status == 200) {
            failures = 0;
            state.currentKbps = next;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Adaptive bitrate: %d -> %d kbps (%u of %u frames lost in the last %d ms, cap %d kbps)",
                        previous, next, dropped, received + dropped, BitratePolicy::kTickMs, state.capKbps);
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
