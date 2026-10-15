import unittest
from fractions import Fraction

from tools.timing.scheduler import ClockSpec, RationalClock, RationalScheduler, merge_deadlines


class RationalClockTests(unittest.TestCase):
    def test_fractional_interval_carries_remainder_without_drift(self):
        clock = RationalClock(Fraction(1, 10))
        self.assertEqual(clock.deadlines(10), [4, 7, 11, 14, 18, 21, 25, 28, 32, 35])
        self.assertEqual({row["gap_ticks"] for row in clock.trace(100)}, {3, 4})
        self.assertEqual(clock.deadline(100), 350)

    def test_absolute_deadline_differs_from_rounding_each_interval(self):
        clock = RationalClock(Fraction(1, 10))
        independently_rounded = 4 * 100
        self.assertEqual(clock.deadline(100), 350)
        self.assertNotEqual(clock.deadline(100), independently_rounded)

    def test_independent_clocks_have_stable_simultaneous_order(self):
        tenth = RationalClock(Fraction(1, 10))
        fifth = RationalClock(Fraction(1, 5))
        merged = merge_deadlines([tenth, fifth], [2, 1])
        self.assertEqual(merged, [(4, 0, 1), (7, 0, 2), (7, 1, 1)])

    def test_priority_orders_simultaneous_independent_events(self):
        tenth = RationalClock(Fraction(1, 10))
        fifth = RationalClock(Fraction(1, 5))
        merged = merge_deadlines([tenth, fifth], [2, 1], priorities=[20, 10])
        self.assertEqual(merged, [(4, 0, 1), (7, 1, 1), (7, 0, 2)])

    def test_long_sequence_keeps_absolute_deadline_and_gap_pattern(self):
        scheduler = RationalScheduler([ClockSpec("third", RationalClock(Fraction(1, 3)), 0, 120)])
        events = scheduler.advance_world_ticks(1400)
        self.assertEqual(len(events), 120)
        self.assertEqual(events[-1].simulation_tic, 1400)
        self.assertEqual([event.simulation_tic for event in events[:4]], [12, 24, 35, 47])
        self.assertLessEqual(max(events[index + 1].simulation_tic - events[index].simulation_tic for index in range(119)), 12)

    def test_paused_world_ticks_do_not_advance_or_burst_after_resume(self):
        scheduler = RationalScheduler([ClockSpec("tenth", RationalClock(Fraction(1, 10)), 0, 4)])
        self.assertEqual([event.event_index for event in scheduler.advance_world_ticks(3)], [])
        snapshot = scheduler.snapshot()
        self.assertEqual(scheduler.advance_world_ticks(20, paused=True), [])
        self.assertEqual(scheduler.simulation_tic, snapshot.simulation_tic)
        self.assertEqual(scheduler.engine_world_ticks, snapshot.engine_world_ticks + 20)
        resumed = scheduler.accept_world_tick(paused=False)
        self.assertEqual([event.event_index for event in resumed], [1])
        self.assertEqual(scheduler.simulation_tic, snapshot.simulation_tic + 1)

    def test_snapshot_restore_preserves_independent_clock_state(self):
        specs = [
            ClockSpec("fast", RationalClock(Fraction(1, 10)), 1, 5),
            ClockSpec("slow", RationalClock(Fraction(1, 5)), 0, 3),
        ]
        scheduler = RationalScheduler(specs)
        scheduler.advance_world_ticks(8)
        snapshot = scheduler.snapshot()
        expected = scheduler.advance_world_ticks(8)
        restored = RationalScheduler(specs)
        restored.restore(snapshot)
        self.assertEqual(restored.advance_world_ticks(8), expected)
        self.assertEqual(restored.snapshot(), scheduler.snapshot())

    def test_invalid_inputs_fail(self):
        with self.assertRaises(ValueError):
            RationalClock(Fraction(0, 1))
        with self.assertRaises(ValueError):
            RationalClock(Fraction(1, 1), ticks_per_second=0)
        with self.assertRaises(ValueError):
            RationalClock(Fraction(1, 10)).deadline(0)
        with self.assertRaises(ValueError):
            RationalClock(Fraction(1, 10)).deadlines(-1)
        with self.assertRaises(ValueError):
            merge_deadlines([RationalClock(Fraction(1, 10))], [])


if __name__ == "__main__":
    unittest.main()
