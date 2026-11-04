#pragma once

#include "renderer.h"
#include "SDL_compat.h"

class SdlAudioRenderer : public IAudioRenderer
{
public:
    SdlAudioRenderer();

    virtual ~SdlAudioRenderer();

    virtual bool prepareForPlayback(const OPUS_MULTISTREAM_CONFIGURATION* opusConfig);

    virtual void* getAudioBuffer(int* size);

    virtual bool submitAudio(int bytesWritten);

    virtual AudioFormat getAudioBufferFormat();

private:
    SDL_AudioDeviceID m_AudioDevice;
    void* m_AudioBuffer;
    Uint32 m_FrameSize;
    Uint32 m_FrameDurationMs;

    // Once-a-second audio health line in the log, to line up audio trouble
    // with video loss: chunks played, chunks dropped to catch up, times the
    // speaker ran dry, and the deepest queues seen.
    void logAudioStats(Uint32 pendingMs, Uint32 deviceMs);
    Uint32 m_StatWindowStartMs = 0;
    Uint32 m_StatQueued = 0;
    Uint32 m_StatDropped = 0;
    Uint32 m_StatUnderruns = 0;
    Uint32 m_StatMaxPendingMs = 0;
    Uint32 m_StatMaxDeviceMs = 0;
    bool m_StartedPlaying = false;
    // Catch-up drops are spread out (at most every other chunk) so a burst of
    // late packets costs a few short gaps instead of a run of missing audio.
    bool m_DroppedLastChunk = false;
};
