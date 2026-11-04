#include <QtTest>

#include "gui/inputmodepolicy.h"

class TestInputMode : public QObject
{
    Q_OBJECT

private slots:
    void lastInputWins()
    {
        InputModePolicy p(InputModePolicy::Mouse);
        QVERIFY(p.controllerUsed(1000));
        QCOMPARE(p.mode(), InputModePolicy::Controller);
        QVERIFY(p.touched());
        QCOMPARE(p.mode(), InputModePolicy::Touch);
        QVERIFY(p.mouseClicked());
        QCOMPARE(p.mode(), InputModePolicy::Mouse);
        QVERIFY(!p.keyPressed()); // already mouse
    }

    void trackpadNudgeAfterControllerIsIgnored()
    {
        InputModePolicy p(InputModePolicy::Mouse);
        p.controllerUsed(1000);
        QVERIFY(!p.mouseMoved(30, 0, 1200));                // within the grace period
        QVERIFY(!p.mouseMoved(3, 2, 2000));                 // after it, but tiny
        QVERIFY(!p.mouseMoved(3, 2, 2050));                 // still under the slop
        QVERIFY(p.mouseMoved(4, 0, 2100));                  // accumulated past 8 px
        QCOMPARE(p.mode(), InputModePolicy::Mouse);
    }

    void touchThenSmallMouseMoveStaysTouch()
    {
        InputModePolicy p(InputModePolicy::Touch);
        QVERIFY(!p.mouseMoved(2, 2, 5000));
        QCOMPARE(p.mode(), InputModePolicy::Touch);
        QVERIFY(p.mouseClicked());
    }

    void controllerResetsSlop()
    {
        InputModePolicy p(InputModePolicy::Controller);
        p.mouseMoved(5, 0, 10000);
        p.controllerUsed(10100);
        QVERIFY(!p.mouseMoved(5, 0, 11000)); // slop restarted from zero
    }
};

QTEST_GUILESS_MAIN(TestInputMode)
#include "tst_inputmode.moc"
