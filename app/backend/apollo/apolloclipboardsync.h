#pragma once

#include <QString>

// When to exchange clipboard text with an Apollo host during a stream, and the
// loop guard that stops text bouncing back and forth. Pure logic: the session
// does the actual clipboard and network calls.
class ApolloClipboardSync
{
public:
    enum Mode { Off = 0, Manual = 1, Smart = 2 };

    ApolloClipboardSync(Mode mode = Off, bool canRead = false, bool canSet = false)
        : m_Mode(mode), m_CanRead(canRead), m_CanSet(canSet) {}

    bool canPush() const { return m_Mode != Off && m_CanSet; }
    bool canPull() const { return m_Mode != Off && m_CanRead; }

    // Smart: send our clipboard when the stream window gains focus (or at connect).
    bool shouldPushOnFocusGain(const QString& localText) const
    {
        return m_Mode == Smart && canPush() && !localText.isEmpty() && localText != m_LastSynced;
    }

    // Smart: fetch the host clipboard when the user leaves the stream window or disconnects.
    bool shouldPullOnFocusLoss() const { return m_Mode == Smart && canPull(); }
    bool shouldPullOnDisconnect() const { return m_Mode == Smart && canPull(); }

    void pushed(const QString& text) { m_LastSynced = text; }

    // Whether pulled host text should replace the local clipboard.
    bool acceptPulled(const QString& hostText, const QString& localText)
    {
        if (hostText.isEmpty() || hostText == m_LastSynced || hostText == localText) {
            return false;
        }
        m_LastSynced = hostText;
        return true;
    }

    // The host refused with 401: stop trying for this session.
    void permissionDenied() { m_CanRead = m_CanSet = false; }

private:
    Mode m_Mode;
    bool m_CanRead;
    bool m_CanSet;
    QString m_LastSynced;
};
