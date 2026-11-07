#pragma once

#include <Limelight.h>
#include <SDL.h>

#include <QDateTime>

#include <cstdint>

// Logs every pause in a stream's incoming data with wall-clock UTC times, so a
// blackout on the client can be matched to the millisecond against the host's
// log (keep both machines' clocks synced, e.g. with NTP). One instance per
// stream (video, audio); call note() from the thread that receives the data.
//
// A still screen does not pause video on its own: the host keeps sending at its
// minimum_fps_target (20 FPS by default). With that set to 0, a still screen can
// show up here as a video-only pause; a real blackout pauses audio too.
class StreamGapLog
{
public:
    explicit StreamGapLog(const char* stream, uint32_t thresholdMs = 250)
        : m_Stream(stream), m_ThresholdUs(uint64_t(thresholdMs) * 1000) {}

    // arrivalUs is on the LiGetMicroseconds() clock; item is a frame or packet number
    void note(uint64_t arrivalUs, uint32_t item)
    {
        if (m_LastArrivalUs != 0 && arrivalUs > m_LastArrivalUs && arrivalUs - m_LastArrivalUs >= m_ThresholdUs) {
            const uint64_t nowUs = LiGetMicroseconds();
            const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
            const qint64 endMs = nowMs - qint64(nowUs > arrivalUs ? (nowUs - arrivalUs) / 1000 : 0);
            const qint64 startMs = endMs - qint64((arrivalUs - m_LastArrivalUs) / 1000);
            const QByteArray start = QDateTime::fromMSecsSinceEpoch(startMs).toUTC().toString(Qt::ISODateWithMs).toLatin1();
            const QByteArray end = QDateTime::fromMSecsSinceEpoch(endMs).toUTC().toString(Qt::ISODateWithMs).toLatin1();
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Stream gap: %s paused %s -> %s UTC (%lld ms, %u -> %u)",
                        m_Stream, start.constData(), end.constData(),
                        (long long)(endMs - startMs), m_LastItem, item);
        }
        m_LastArrivalUs = arrivalUs;
        m_LastItem = item;
    }

    // Writes the current UTC time next to the monotonic clock, for lining up
    // other log lines that only carry relative times.
    static void logClockAnchor()
    {
        const QByteArray utc = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs).toLatin1();
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Clock anchor: %s UTC = %llu us on the stream clock",
                    utc.constData(), (unsigned long long)LiGetMicroseconds());
    }

private:
    const char* m_Stream;
    uint64_t m_ThresholdUs;
    uint64_t m_LastArrivalUs = 0;
    uint32_t m_LastItem = 0;
};
