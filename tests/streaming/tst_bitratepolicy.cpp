#include <QtTest>

#include "streaming/bitratepolicy.h"

// Windows are half a second; a 120 FPS stream delivers about 60 frames per window.
class BitratePolicyTest : public QObject
{
    Q_OBJECT

    static BitratePolicy::State fresh(int ceiling = 84000, int fps = 120)
    {
        return BitratePolicy::initial(ceiling, fps);
    }

    static int clean(BitratePolicy::State& s, int ticks, uint32_t received = 65)
    {
        int kbps = s.currentKbps;
        for (int i = 0; i < ticks; i++) {
            kbps = BitratePolicy::decide(s, received, 0);
            s.currentKbps = kbps;
        }
        return kbps;
    }

private slots:
    void initialState()
    {
        auto s = fresh();
        QCOMPARE(s.currentKbps, 84000);
        QCOMPARE(s.capKbps, 84000);
        QCOMPARE(s.floorKbps, 29500);
        QCOMPARE(s.expectedFramesPerWindow, 60);
    }

    void lossCutsByAQuarterAndLowersTheCap()
    {
        auto s = fresh();
        QCOMPARE(BitratePolicy::decide(s, 27, 43), 63000);
        QCOMPARE(s.capKbps, 75500);   // 90% of the 84000 that just failed
    }

    void lossDuringTheHoldIsIgnored()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        // The host is still applying the cut: the next window's loss must not cut again
        QCOMPARE(BitratePolicy::decide(s, 111, 268), 63000);
        QCOMPARE(BitratePolicy::decide(s, 40, 30), 63000);
        QCOMPARE(BitratePolicy::decide(s, 40, 30), 63000);
        QCOMPARE(BitratePolicy::decide(s, 40, 30), 63000);
        // Hold over (4 windows = 2 s): loss that continues cuts again
        QCOMPARE(BitratePolicy::decide(s, 40, 30), 47500);
    }

    void stalledWindowsAreNotClean()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        // 20 windows with only 10 frames each (waiting for an RFI frame): never ramp
        QCOMPARE(clean(s, 20, 10), 63000);
        // Too few frames to judge at all: no change either
        QCOMPARE(BitratePolicy::decide(s, 3, 0), 63000);
    }

    void rampsBackOnlyUpToTheCap()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        QCOMPARE(clean(s, 7), 63000);   // 3.5 s clean: not yet
        QCOMPARE(clean(s, 1), 68000);   // 4 s clean: first 8% step
        QCOMPARE(clean(s, 3), 68000);
        QCOMPARE(clean(s, 1), 73500);
        QCOMPARE(clean(s, 4), 75500);   // stops at the cap, not at 79500
        QCOMPARE(clean(s, 8), 75500);
    }

    void capLiftsOnlyAfterThirtyCleanSeconds()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        clean(s, 16);                     // back at the cap (75500), cleanTicks = 16
        QCOMPARE(s.currentKbps, 75500);
        QCOMPARE(clean(s, 43), 75500);    // cleanTicks = 59
        QCOMPARE(clean(s, 1), 81500);     // 60 clean windows: one 8% step above the old cap
        QCOMPARE(s.capKbps, 81500);
        QCOMPARE(clean(s, 59), 81500);    // and another 30 s before the next
        QCOMPARE(clean(s, 1), 84000);     // never above the user's bitrate
        QCOMPARE(clean(s, 80), 84000);
    }

    void repeatedCutsDoubleTheWaitBeforeProbingAgain()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);   // 1st cut: 63000, cap 75500
        clean(s, 16);                                        // back at the cap
        clean(s, 44);                                        // 60 clean windows: lifted to 81500
        QCOMPARE(s.currentKbps, 81500);
        s.currentKbps = BitratePolicy::decide(s, 40, 30);   // 2nd cut: the probe failed
        QCOMPARE(s.currentKbps, 61000);
        QCOMPARE(s.capKbps, 73500);
        clean(s, 16);                                        // 61000 -> 66000 -> 71500 -> 73500
        QCOMPARE(s.currentKbps, 73500);
        QCOMPARE(clean(s, 103), 73500);                      // 119 clean windows since the cut: still waiting
        QCOMPARE(clean(s, 1), 79500);                        // 120th: lifted (60 s, not 30 s)
        s.currentKbps = BitratePolicy::decide(s, 40, 30);   // 3rd cut
        QCOMPARE(s.capLiftWaitTicks, 240);                   // 120 s now
    }

    void waitGoesBackToThirtySecondsOnceTheCeilingHolds()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        s.currentKbps = BitratePolicy::decide(s, 40, 30);    // ignored: hold
        clean(s, 4);                                         // hold over
        s.currentKbps = BitratePolicy::decide(s, 40, 30);    // 2nd cut -> wait 120 ticks
        QCOMPARE(s.capLiftWaitTicks, 120);
        // Climb all the way back: ramp to cap, 120 clean at the cap, lift, ... until 84000
        for (int i = 0; i < 2000 && s.currentKbps < 84000; i++) {
            clean(s, 1);
        }
        QCOMPARE(s.currentKbps, 84000);
        QCOMPARE(s.capLiftWaitTicks, 120);                   // not reset yet
        clean(s, 60);                                        // 30 s at the ceiling
        QCOMPARE(s.capLiftWaitTicks, 60);
        QCOMPARE(s.cutsSinceReset, 0);
    }

    void lossAfterRecoveryResetsTheCleanCount()
    {
        auto s = fresh();
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        clean(s, 16);
        QCOMPARE(BitratePolicy::decide(s, 60, 1), 75500);  // one lost frame: no cut, but not clean
        QCOMPARE(s.cleanTicks, 0);
    }

    void neverBelowTheFloor()
    {
        auto s = fresh();
        for (int i = 0; i < 40; i++) {
            s.currentKbps = BitratePolicy::decide(s, 30, 30);
            for (int h = 0; h < 4; h++) {
                s.currentKbps = BitratePolicy::decide(s, 30, 30);
            }
        }
        QCOMPARE(s.currentKbps, 29500);
        QVERIFY(s.capKbps >= s.floorKbps);
    }

    void unknownFpsCountsAnyJudgeableWindowAsFull()
    {
        auto s = fresh(84000, 0);
        s.currentKbps = BitratePolicy::decide(s, 27, 43);
        QCOMPARE(clean(s, 8, 10), 68000);
    }
};

QTEST_APPLESS_MAIN(BitratePolicyTest)
#include "tst_bitratepolicy.moc"
