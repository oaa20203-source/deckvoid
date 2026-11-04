#include "inputmode.h"

#include <QCoreApplication>
#include <QFile>
#include <QInputDevice>
#include <QKeyEvent>
#include <QMouseEvent>
#include <QPointingDevice>

InputMode* InputMode::instance()
{
    static InputMode* s_Instance = new InputMode();
    return s_Instance;
}

InputModePolicy::Mode InputMode::initialMode(bool& pinned)
{
    const QByteArray forced = qgetenv("DECKVOID_INPUT_MODE").toLower();
    pinned = true;
    if (forced == "controller") return InputModePolicy::Controller;
    if (forced == "mouse") return InputModePolicy::Mouse;
    if (forced == "touch") return InputModePolicy::Touch;
    pinned = false;

    // Steam Deck / SteamOS (Gaming or Desktop Mode) starts in controller mode.
    if (qgetenv("SteamDeck") == "1" || qgetenv("SteamOS") == "1" || !qgetenv("GAMESCOPE_WAYLAND_DISPLAY").isEmpty()) {
        return InputModePolicy::Controller;
    }
    QFile osRelease(QStringLiteral("/etc/os-release"));
    if (osRelease.open(QIODevice::ReadOnly) && osRelease.readAll().contains("ID=steamos")) {
        return InputModePolicy::Controller;
    }
#if defined(Q_OS_IOS)
    return InputModePolicy::Touch;
#else
    return InputModePolicy::Mouse;
#endif
}

InputMode::InputMode()
    : m_Policy(InputModePolicy::Mouse)
{
    m_Policy = InputModePolicy(initialMode(m_Pinned));
    m_Clock.start();
    if (!m_Pinned) {
        QCoreApplication::instance()->installEventFilter(this);
    }
}

QString InputMode::mode() const
{
    switch (m_Policy.mode()) {
    case InputModePolicy::Controller: return QStringLiteral("controller");
    case InputModePolicy::Touch: return QStringLiteral("touch");
    default: return QStringLiteral("mouse");
    }
}

void InputMode::apply(bool changed)
{
    if (changed) {
        emit modeChanged();
    }
}

void InputMode::reportControllerUsed()
{
    if (!m_Pinned) {
        apply(m_Policy.controllerUsed(m_Clock.elapsed()));
    }
}

bool InputMode::eventFilter(QObject* watched, QEvent* event)
{
    switch (event->type()) {
    case QEvent::TouchBegin:
        apply(m_Policy.touched());
        break;
    case QEvent::MouseButtonPress:
    case QEvent::MouseMove: {
        auto* mouse = static_cast<QMouseEvent*>(event);
        // Mouse events Qt synthesizes from touch belong to the touch.
        if (mouse->source() != Qt::MouseEventNotSynthesized ||
                mouse->pointingDevice()->type() == QInputDevice::DeviceType::TouchScreen) {
            break;
        }
        if (event->type() == QEvent::MouseButtonPress) {
            apply(m_Policy.mouseClicked());
            break;
        }
        const QPointF pos = mouse->globalPosition();
        if (m_HaveMousePos) {
            const QPointF delta = pos - m_LastMousePos;
            apply(m_Policy.mouseMoved(int(delta.x()), int(delta.y()), m_Clock.elapsed()));
        }
        m_LastMousePos = pos;
        m_HaveMousePos = true;
        break;
    }
    case QEvent::KeyPress:
        if (!m_SynthesizingKeys && !static_cast<QKeyEvent*>(event)->isAutoRepeat()) {
            apply(m_Policy.keyPressed());
        }
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}
