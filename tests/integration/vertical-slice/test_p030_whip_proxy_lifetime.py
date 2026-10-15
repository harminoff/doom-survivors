import re
from pathlib import Path
from tools import slice_source


ROOT = Path(__file__).resolve().parents[3]


def test_whip_proxy_has_five_tic_finite_visual_lifetime():
    source = slice_source.read()
    start = source.index("class DSP030WhipProxy")
    proxy = source[start : source.index("\nclass ", start + 1)]
    states = proxy[proxy.index("States") :]

    durations = [int(value) for value in re.findall(r"WWHP A (\d+) Bright;", states)]
    assert durations == [2, 2, 1]
    assert sum(durations) == 5
    assert "Loop;" not in states
    assert re.search(r"\bStop;", states)
    assert "sweepUntil = tic + 5;" in source


def test_whip_proxy_bound_is_exposed_in_runtime_trace():
    source = slice_source.read()
    trace = source[source.index('Console.Printf("DS_P030_TRACE') :]

    assert "whip_proxies=%d" in trace
    assert "LiveWhipProxyCount()" in trace
    assert 'DS_P030_WHIP_PROXY tic=%d event_id=%d count=%d bounded_lifetime_tics=5' in source
