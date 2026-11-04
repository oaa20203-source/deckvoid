#pragma once

#include "inputmodepolicy.h"

#include <QElapsedTimer>
#include <QObject>
#include <QPointF>

// Exposes the UI input mode ("controller" | "mouse" | "touch") to QML and keeps it
// following the last input used. Gamepad use is reported by SdlGamepadKeyNavigation;
// mouse, keyboard and touch are seen through an application-wide event filter.
class InputMode : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode NOTIFY modeChanged)

public:
    static InputMode* instance();

    QString mode() const;

    void reportControllerUsed();

    // Keys synthesized by gamepad navigation must not count as keyboard use.
    void setSynthesizingKeys(bool synthesizing) { m_SynthesizingKeys = synthesizing; }

    // Set by DECKVOID_INPUT_MODE (for screenshots/tests): the mode never changes.
    bool isPinned() const { return m_Pinned; }

signals:
    void modeChanged();

protected:
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    InputMode();
    void apply(bool changed);
    static InputModePolicy::Mode initialMode(bool& pinned);

    bool m_Pinned = false;
    InputModePolicy m_Policy;
    QElapsedTimer m_Clock;
    QPointF m_LastMousePos;
    bool m_HaveMousePos = false;
    bool m_SynthesizingKeys = false;
};
