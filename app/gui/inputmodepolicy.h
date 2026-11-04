#pragma once

#include <cstdint>
#include <cstdlib>

// Which UI layout to show: the last kind of input used wins (docs/design/DESIGN.md,
// "Input modes"). Pure logic so the switching rules can be unit-tested.
class InputModePolicy
{
public:
    enum Mode { Controller, Mouse, Touch };

    // A stray trackpad/mouse nudge right after controller use must not flip the UI.
    static constexpr int kMouseSlopPx = 8;
    static constexpr int64_t kMouseGraceMs = 600;

    explicit InputModePolicy(Mode initial) : m_Mode(initial) {}

    Mode mode() const { return m_Mode; }

    // Each returns true when the mode changed.
    bool controllerUsed(int64_t nowMs)
    {
        m_LastControllerMs = nowMs;
        m_SlopX = m_SlopY = 0;
        return set(Controller);
    }

    bool mouseMoved(int dx, int dy, int64_t nowMs)
    {
        if (m_Mode == Controller && nowMs - m_LastControllerMs < kMouseGraceMs) {
            return false;
        }
        if (m_Mode != Mouse) {
            m_SlopX += dx;
            m_SlopY += dy;
            if (std::abs(m_SlopX) < kMouseSlopPx && std::abs(m_SlopY) < kMouseSlopPx) {
                return false;
            }
        }
        m_SlopX = m_SlopY = 0;
        return set(Mouse);
    }

    bool mouseClicked() { return set(Mouse); }
    bool keyPressed() { return set(Mouse); }
    bool touched() { return set(Touch); }

private:
    bool set(Mode mode)
    {
        if (m_Mode == mode) {
            return false;
        }
        m_Mode = mode;
        return true;
    }

    Mode m_Mode;
    int64_t m_LastControllerMs = -1000000;
    int m_SlopX = 0;
    int m_SlopY = 0;
};
