"""Process memory sampling for the P015 benchmark (standard library only).

The pinned engine exposes no ZScript memory statistic, so working set is read
from the operating system while the benchmark runs. Sampling is best-effort: a
platform without the required API returns ``None`` rather than failing a run,
and the caller must record that memory was not measured.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field


@dataclass
class MemoryTrace:
    """Ordered working-set samples for one benchmark process."""

    samples: list[tuple[float, int]] = field(default_factory=list)
    supported: bool = False
    note: str = ""

    def record(self, elapsed_seconds: float, working_set_bytes: int) -> None:
        self.samples.append((round(elapsed_seconds, 3), int(working_set_bytes)))

    def summary(self) -> dict:
        if not self.supported:
            return {"supported": False, "note": self.note, "samples": 0}
        if not self.samples:
            return {"supported": True, "note": "no_samples", "samples": 0}
        values = [value for _, value in self.samples]
        return {
            "supported": True,
            "note": self.note,
            "samples": len(values),
            "start_bytes": values[0],
            "end_bytes": values[-1],
            "peak_bytes": max(values),
            "min_bytes": min(values),
            "delta_bytes": values[-1] - values[0],
        }


def working_set_bytes(pid: int) -> int | None:
    """Return the process working set in bytes, or ``None`` when unavailable."""

    if not sys.platform.startswith("win"):
        return None
    try:
        import ctypes
        import ctypes.wintypes as wintypes
    except ImportError:  # pragma: no cover - Windows always ships ctypes
        return None

    class PROCESS_MEMORY_COUNTERS(ctypes.Structure):
        _fields_ = [
            ("cb", wintypes.DWORD),
            ("PageFaultCount", wintypes.DWORD),
            ("PeakWorkingSetSize", ctypes.c_size_t),
            ("WorkingSetSize", ctypes.c_size_t),
            ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
            ("QuotaPagedPoolUsage", ctypes.c_size_t),
            ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
            ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
            ("PagefileUsage", ctypes.c_size_t),
            ("PeakPagefileUsage", ctypes.c_size_t),
        ]

    PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return None
    try:
        counters = PROCESS_MEMORY_COUNTERS()
        counters.cb = ctypes.sizeof(PROCESS_MEMORY_COUNTERS)
        if not psapi.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb):
            return None
        return int(counters.WorkingSetSize)
    finally:
        kernel32.CloseHandle(handle)


def percentile(values: list[float], fraction: float) -> float | None:
    """Nearest-rank percentile; returns ``None`` for an empty input."""

    if not values:
        return None
    if not 0.0 <= fraction <= 1.0:
        raise ValueError("fraction must be between 0 and 1")
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def describe(values: list[float]) -> dict:
    """Return p50/p95/p99 plus min/max/mean for a sample list."""

    if not values:
        return {"count": 0, "min": None, "max": None, "mean": None,
                "p50": None, "p95": None, "p99": None}
    return {
        "count": len(values),
        "min": round(min(values), 3),
        "max": round(max(values), 3),
        "mean": round(sum(values) / len(values), 3),
        "p50": round(percentile(values, 0.50), 3),
        "p95": round(percentile(values, 0.95), 3),
        "p99": round(percentile(values, 0.99), 3),
    }
