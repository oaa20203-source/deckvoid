#include <QtTest>

#include "streaming/bitratepolicy.h"

// Windows are half a second; a 120 FPS stream delivers about 60 frames per window.
class BitratePolicyTest : public QObject
{
    Q_OBJECT

    using Window = BitratePolicy::Window;

    static BitratePolicy::State fresh(int ceiling = 84000, int fps = 120, bool inPlace = false)
    {
        auto s = BitratePolicy::initial(ceiling, fps);
        s.inPlaceChanges = inPlace;
        return s;
    }

    static Window win(uint32_t received, uint32_t events = 0, uint32_t lost = 0, int delayMs = 0, bool outage = false)
    {
        Window w;
        w.received = received;
        w.lossEvents = events;
        w.lostFrames = lost;
        w.longestLossEvent = events ? lost / events : 0;
        w.queueDelayMs = delayMs;
        w.outage = outage;
        return w;
    }

    // Apply one window and take the decision, as the adapter does on success
    static int step(BitratePolicy::State& s, const Window& w)
    {
        s.currentKbps = BitratePolicy::decide(s, w);
        return s.currentKbps;
    }

    static int clean(BitratePolicy::State& s, int ticks, uint32_t received = 65, int delayMs = 0)
    {
        for (int i = 0; i < ticks; i++) {
            step(s, win(received, 0, 0, delayMs));
        }
        return s.currentKbps;
    }

    // Two loss events 1 s apart: repeated loss, which cuts
    static int repeatedLoss(BitratePolicy::State& s)
    {
        step(s, win(55, 1, 5));
        step(s, win(60));
        return step(s, win(55, 1, 5));
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

    void anIsolatedLossEventDoesNotCut()
    {
        auto s = fresh();
        clean(s, 10);
        // One event, even one that discarded 24 frames waiting for its recovery frame
        QCOMPARE(step(s, win(36, 1, 24)), 84000);
        QCOMPARE(s.cleanTicks, 0);
        QCOMPARE(clean(s, 20), 84000);
        // Another one long after the first is isolated too
        QCOMPARE(step(s, win(50, 1, 10)), 84000);
    }

    void repeatedLossCutsFifteenPercentAndRemembersTheKnee()
    {
        auto s = fresh();
        QCOMPARE(repeatedLoss(s), 71500);
        QCOMPARE(s.capKbps, 75500);   // 90% of the 84000 that failed
        // Two events inside one window repeat as well
        auto t = fresh();
        QCOMPARE(step(t, win(50, 2, 8)), 71500);
    }

    void lossEventsFarApartAreNotRepeated()
    {
        auto s = fresh();
        step(s, win(55, 1, 5));
        clean(s, 10);                 // 5 s later
        QCOMPARE(step(s, win(55, 1, 5)), 84000);
    }

    void outagesNeverCut()
    {
        auto s = fresh();
        // No packets at all for 250 ms or more, repeatedly
        QCOMPARE(step(s, win(10, 1, 30, 300, true)), 84000);
        QCOMPARE(step(s, win(20, 1, 30, 300, true)), 84000);
        // One event that lost 40+ frames is an outage too, even without the flag
        QCOMPARE(step(s, win(20, 1, 120)), 84000);
        QCOMPARE(s.cleanTicks, 0);
        QVERIFY(s.holdTicks > 0);
    }

    void ignoredLossesDoNotCountTowardALaterCut()
    {
        // After an outage, one stray loss is isolated
        auto s = fresh();
        step(s, win(10, 1, 120, 0, true));
        clean(s, 5);
        QCOMPARE(step(s, win(55, 1, 2)), 84000);
        // After a cut, a loss during the hold and one just after it are isolated too
        auto t = fresh();
        repeatedLoss(t);                      // 71500
        QCOMPARE(step(t, win(55, 1, 2)), 71500);   // inside the hold: ignored
        clean(t, 3);
        QCOMPARE(step(t, win(55, 1, 2)), 71500);   // first loss after the cut: isolated
    }

    void aStillScreenIsNotAnOutage()
    {
        auto s = fresh(84000, 120, true);
        repeatedLoss(s);
        // No packets for seconds at a time but no loss: neutral, and the climb continues
        for (int i = 0; i < 10; i++) {
            step(s, win(0, 0, 0, 0, true));
        }
        QCOMPARE(clean(s, 6), 74500);
    }

    void longRecoveriesInAStandingQueueAreCongestion()
    {
        auto s = fresh();
        // 50-frame events while every frame is 150 ms late: congestion, not an outage
        step(s, win(40, 1, 50, 150));
        QCOMPARE(step(s, win(40, 1, 50, 150)), 71500);
    }

    void cutsAtTheFloorChangeNothing()
    {
        auto s = fresh();
        s.currentKbps = s.floorKbps;
        const int wait = s.capLiftWaitTicks;
        for (int i = 0; i < 20; i++) {
            step(s, win(30, 2, 10));
        }
        QCOMPARE(s.currentKbps, 29500);
        QCOMPARE(s.capLiftWaitTicks, wait);
        QCOMPARE(s.cutsSinceReset, 0);
    }

    void lossDuringTheHoldIsIgnored()
    {
        auto s = fresh();
        repeatedLoss(s);              // 71500, hold 2 s (4 windows)
        QCOMPARE(step(s, win(40, 2, 10)), 71500);
        QCOMPARE(step(s, win(40, 2, 10)), 71500);
        QCOMPARE(step(s, win(40, 2, 10)), 71500);
        QCOMPARE(step(s, win(40, 2, 10)), 71500);
        // Hold over: loss that continues cuts again
        QCOMPARE(step(s, win(40, 2, 10)), 61000);
    }

    void aStandingQueueCutsWithoutLoss()
    {
        auto s = fresh();
        // 30 ms over the baseline for 1 s: not yet
        QCOMPARE(step(s, win(60, 0, 0, 30)), 84000);
        QCOMPARE(step(s, win(60, 0, 0, 30)), 84000);
        // 1.5 s: a standing queue
        QCOMPARE(step(s, win(60, 0, 0, 30)), 71500);
        // 100 ms or more cuts after 1 s
        auto t = fresh();
        QCOMPARE(step(t, win(60, 0, 0, 150)), 84000);
        QCOMPARE(step(t, win(60, 0, 0, 150)), 71500);
        // Jitter under 25 ms never cuts
        auto u = fresh();
        QCOMPARE(clean(u, 50, 60, 22), 84000);
    }

    void delayAboveTwentyMsBlocksEveryStepUp()
    {
        auto s = fresh(84000, 120, true);
        repeatedLoss(s);
        QCOMPARE(clean(s, 100, 60, 21), 71500);
        QCOMPARE(clean(s, 6), 74500);
    }

    void stillScreenWindowsAreNeutral()
    {
        auto s = fresh(84000, 120, true);
        repeatedLoss(s);
        // A still screen sends a few frames per window: nothing happens either way
        QCOMPARE(clean(s, 100, 3), 71500);
        QCOMPARE(clean(s, 30, 15), 71500);   // under half the expected frames: not clean
    }

    // In-place hosts (no keyframe per change)

    void inPlaceHostsStepFourPercentEveryThreeSeconds()
    {
        auto s = fresh(84000, 120, true);
        repeatedLoss(s);              // 71500, knee 75500
        QCOMPARE(clean(s, 5), 71500); // hold, then 2 s clean, at most every 3 s
        QCOMPARE(clean(s, 1), 74500); // +4%
        QCOMPARE(clean(s, 5), 74500);
        QCOMPARE(clean(s, 1), 75500); // within 5% of the knee: +1.5% (at least 500 kbps)
        QCOMPARE(clean(s, 6), 76500);
        QCOMPARE(s.capKbps, 76500);   // holding above the knee moves it up
        for (int i = 0; i < 1000 && s.currentKbps < 84000; i++) {
            clean(s, 1);
        }
        QCOMPARE(s.currentKbps, 84000);
        QCOMPARE(clean(s, 100), 84000);   // never above the user's bitrate
    }

    void inPlaceHostsPauseAfterAnIsolatedLoss()
    {
        auto s = fresh(84000, 120, true);
        repeatedLoss(s);
        QCOMPARE(clean(s, 11), 74500);
        QCOMPARE(step(s, win(55, 1, 3)), 74500);   // isolated (6 s after the last): no cut, not clean
        QCOMPARE(clean(s, 3), 74500);              // 2 clean seconds again first
        QCOMPARE(clean(s, 1), 75500);
    }

    // Keyframe hosts (or not yet identified)

    void keyframeHostsWaitThirtySecondsAndStepFifteenPercent()
    {
        auto s = fresh();
        QCOMPARE(repeatedLoss(s), 71500);
        s.currentKbps = 55000;       // far under the knee of 75500
        QCOMPARE(clean(s, 59), 55000);
        QCOMPARE(clean(s, 1), 63000);   // +15%
        QCOMPARE(clean(s, 17), 63000);  // steps at least 9 s apart
        QCOMPARE(clean(s, 1), 72500);
        QCOMPARE(clean(s, 17), 72500);
        QCOMPARE(clean(s, 1), 75500);   // up to the knee
        QCOMPARE(clean(s, 100), 75500);
    }

    void keyframeHostsSkipTinySteps()
    {
        auto s = fresh();
        repeatedLoss(s);
        s.currentKbps = 74500;          // 1000 kbps (1.3%) under the knee
        QCOMPARE(clean(s, 200), 74500); // not worth a keyframe
    }

    void keyframeHostsProbePastTheKneeAfterFiveMinutes()
    {
        auto s = fresh();
        repeatedLoss(s);                  // 71500, knee 75500
        QCOMPARE(clean(s, 60), 75500);    // 30 s: one step to the knee
        QCOMPARE(clean(s, 539), 75500);   // 599 clean windows since the cut
        QCOMPARE(clean(s, 1), 78000);     // 5 min: 3% past the knee, in one change
        QCOMPARE(clean(s, 599), 78000);
        QCOMPARE(clean(s, 1), 80500);
        for (int i = 0; i < 5000 && s.currentKbps < 84000; i++) {
            clean(s, 1);
        }
        QCOMPARE(s.currentKbps, 84000);
    }

    void keyframeHostsDoubleTheProbeWaitWithEachCut()
    {
        auto s = fresh();
        repeatedLoss(s);                  // 1st cut
        QCOMPARE(s.capLiftWaitTicks, 600);
        clean(s, 10);
        repeatedLoss(s);                  // 2nd cut
        QCOMPARE(s.capLiftWaitTicks, 1200);
        clean(s, 10);
        repeatedLoss(s);                  // 3rd
        QCOMPARE(s.capLiftWaitTicks, 2400);
        clean(s, 10);
        repeatedLoss(s);                  // capped at 20 min
        QCOMPARE(s.capLiftWaitTicks, 2400);
    }

    void theKneeProbeNeverRoundsToNoChange()
    {
        auto s = fresh(9000, 120);
        s.capKbps = 7000;
        s.currentKbps = 7000;
        s.floorKbps = 7000;
        QCOMPARE(clean(s, 600), 7500);
    }

    void neverBelowTheFloor()
    {
        auto s = fresh();
        for (int i = 0; i < 60; i++) {
            step(s, win(30, 2, 10));
        }
        QCOMPARE(s.currentKbps, 29500);
        QVERIFY(s.capKbps >= s.floorKbps);
    }

    void unknownFpsCountsAnyJudgeableWindowAsFull()
    {
        auto s = fresh(84000, 0, true);
        repeatedLoss(s);
        QCOMPARE(clean(s, 6, 10), 74500);
    }
};

QTEST_APPLESS_MAIN(BitratePolicyTest)
#include "tst_bitratepolicy.moc"
