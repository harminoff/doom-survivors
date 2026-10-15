"""Rational P014 scheduling helpers.

The model advances logical simulation time only when a caller accepts a
simulation WorldTick. Engine callback counts, simulation tics, UI/render
observations and input observations therefore remain separate. It does not
claim sub-tic UZDoom input or physics.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from typing import Iterable


@dataclass(frozen=True)
class RationalClock:
    """An immutable rational interval sampled at a fixed simulation rate."""

    interval_seconds: Fraction
    ticks_per_second: int = 35

    def __post_init__(self) -> None:
        if self.interval_seconds <= 0:
            raise ValueError("interval_seconds must be positive")
        if self.ticks_per_second <= 0:
            raise ValueError("ticks_per_second must be positive")

    def deadline(self, event_index: int) -> int:
        """Return the first engine tic at or after the exact event deadline."""

        if event_index < 1:
            raise ValueError("event_index must be at least 1")
        exact_ticks = event_index * self.interval_seconds * self.ticks_per_second
        return -(-exact_ticks.numerator // exact_ticks.denominator)

    def deadlines(self, count: int) -> list[int]:
        if count < 0:
            raise ValueError("count cannot be negative")
        return [self.deadline(index) for index in range(1, count + 1)]

    def trace(self, count: int) -> list[dict[str, int]]:
        deadlines = self.deadlines(count)
        previous = 0
        result = []
        for index, tick in enumerate(deadlines, start=1):
            result.append({"event_index": index, "tick": tick, "gap_ticks": tick - previous})
            previous = tick
        return result


@dataclass(frozen=True)
class ClockSpec:
    """One independent logical clock and its deterministic tie-break priority."""

    name: str
    clock: RationalClock
    priority: int
    event_count: int

    def __post_init__(self) -> None:
        if not self.name:
            raise ValueError("clock name must be non-empty")
        if self.event_count < 0:
            raise ValueError("event_count cannot be negative")


@dataclass(frozen=True)
class ScheduledEvent:
    """An event released at an absolute logical simulation tic."""

    simulation_tic: int
    clock_name: str
    priority: int
    event_index: int


@dataclass(frozen=True)
class SchedulerSnapshot:
    """Serializable state for pause/save inspection without hidden advancement."""

    engine_world_ticks: int
    simulation_tic: int
    paused: bool
    next_event_indices: tuple[tuple[str, int], ...]


class RationalScheduler:
    """Advance independent rational clocks on accepted simulation WorldTicks.

    A paused engine callback increments ``engine_world_ticks`` but never
    increments ``simulation_tic`` or releases events. Resuming does not replay
    wall-clock time or create a backlog; it continues from the saved logical
    tic. Events sharing a deadline sort by fixed clock priority, event index,
    then declaration order.
    """

    def __init__(self, specs: Iterable[ClockSpec], ticks_per_second: int = 35) -> None:
        self.specs = tuple(specs)
        if not self.specs:
            raise ValueError("at least one clock is required")
        if ticks_per_second <= 0:
            raise ValueError("ticks_per_second must be positive")
        names = [spec.name for spec in self.specs]
        if len(set(names)) != len(names):
            raise ValueError("clock names must be unique")
        if any(spec.clock.ticks_per_second != ticks_per_second for spec in self.specs):
            raise ValueError("all clocks must use the scheduler tick rate")
        self.ticks_per_second = ticks_per_second
        self.engine_world_ticks = 0
        self.simulation_tic = 0
        self.paused = False
        self._next_event_indices = {spec.name: 1 for spec in self.specs}

    def set_paused(self, paused: bool) -> None:
        self.paused = bool(paused)

    def _due_events(self) -> list[ScheduledEvent]:
        due: list[tuple[int, int, int, int, str]] = []
        for declaration_index, spec in enumerate(self.specs):
            event_index = self._next_event_indices[spec.name]
            while event_index <= spec.event_count and spec.clock.deadline(event_index) <= self.simulation_tic:
                due.append((spec.clock.deadline(event_index), spec.priority, event_index, declaration_index, spec.name))
                event_index += 1
            self._next_event_indices[spec.name] = event_index
        due.sort(key=lambda row: row[:4])
        return [ScheduledEvent(tick, name, priority, event_index) for tick, priority, event_index, _, name in due]

    def accept_world_tick(self, paused: bool | None = None) -> list[ScheduledEvent]:
        """Accept one engine WorldTick and release due logical events."""

        self.engine_world_ticks += 1
        if paused is not None:
            self.paused = bool(paused)
        if self.paused:
            return []
        self.simulation_tic += 1
        return self._due_events()

    def advance_world_ticks(self, count: int, paused: bool = False) -> list[ScheduledEvent]:
        if count < 0:
            raise ValueError("count cannot be negative")
        return [event for _ in range(count) for event in self.accept_world_tick(paused=paused)]

    def snapshot(self) -> SchedulerSnapshot:
        return SchedulerSnapshot(
            self.engine_world_ticks,
            self.simulation_tic,
            self.paused,
            tuple((spec.name, self._next_event_indices[spec.name]) for spec in self.specs),
        )

    def restore(self, snapshot: SchedulerSnapshot) -> None:
        if snapshot.engine_world_ticks < 0 or snapshot.simulation_tic < 0:
            raise ValueError("snapshot counters cannot be negative")
        expected_names = tuple(spec.name for spec in self.specs)
        if tuple(name for name, _ in snapshot.next_event_indices) != expected_names:
            raise ValueError("snapshot clock set does not match scheduler")
        for spec_name, next_index in snapshot.next_event_indices:
            spec = next(spec for spec in self.specs if spec.name == spec_name)
            if next_index < 1 or next_index > spec.event_count + 1:
                raise ValueError("snapshot event index is outside the configured sequence")
        self.engine_world_ticks = snapshot.engine_world_ticks
        self.simulation_tic = snapshot.simulation_tic
        self.paused = snapshot.paused
        self._next_event_indices = dict(snapshot.next_event_indices)


def merge_deadlines(clocks: list[RationalClock], counts: list[int], priorities: list[int] | None = None) -> list[tuple[int, int, int]]:
    """Merge clocks as ``(tick, clock_index, event_index)`` in stable order.

    The returned compatibility tuple retains declaration indices while sorting
    by absolute deadline, explicit clock priority, event index and declaration
    index.
    """

    if len(clocks) != len(counts):
        raise ValueError("clocks and counts must have the same length")
    if priorities is None:
        priorities = list(range(len(clocks)))
    if len(priorities) != len(clocks):
        raise ValueError("priorities and clocks must have the same length")
    events = [
        (clock.deadline(event_index), priorities[clock_index], event_index, clock_index)
        for clock_index, (clock, count) in enumerate(zip(clocks, counts))
        for event_index in range(1, count + 1)
    ]
    return [(tick, clock_index, event_index) for tick, _, event_index, clock_index in sorted(events)]
