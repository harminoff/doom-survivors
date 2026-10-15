from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]


def test_p030_recorder_is_exact_target_window_and_fail_closed():
    source = (ROOT / "tools/record_p030_window.ps1").read_text(encoding="utf-8")
    assert "[Parameter(Mandatory = $true)]" in source
    assert 'ProcessName -notmatch "^uzdoom$"' in source
    assert "MainWindowHandle -eq 0" in source
    assert "VerifiedWindowTitle" in source
    assert "sole live UZDoom process" in source
    assert "$sameTitle.Count -ne 1" in source
    assert '"-i", "title=$windowTitle"' in source
    assert '"-i", "desktop"' not in source.lower()
    assert "-count_frames" in source
    assert "expected_frame_count" in source
    assert "frame_delta" in source
    assert "PeakWorkingSet64" in source
    assert "paired_latest_manual_log" in source
    assert 'Filter "log-p030-manual-*.txt"' in source
    assert "LastWriteTimeUtc -ge $processStartUtc.AddSeconds(-5)" in source
    assert "[math]::Min(30.0" in source
    assert "TARGET_WINDOW_ONLY" in source
    assert "Recorded video is too short" in source
    assert "blank or constant-color" in source
