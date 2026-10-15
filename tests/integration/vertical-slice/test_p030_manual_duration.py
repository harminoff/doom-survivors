from pathlib import Path

import pytest

from tools.run_p030_vertical_slice import SUPPORTED_DURATIONS, validate
from tools import slice_source


ROOT = Path(__file__).resolve().parents[3]


def test_manual_duration_is_opt_in_and_defaults_to_full_mad_forest():
    source = slice_source.read()
    cvarinfo = (ROOT / "src/resources/CVARINFO").read_text(encoding="utf-8")
    launcher = (ROOT / "Launch Doom Survivors.ps1").read_text(encoding="utf-8")

    assert "const SURVIVAL_TICS = 10500;" in source
    assert "const MIN_SURVIVAL_TICS = 2100;" in source
    assert "const MAX_SURVIVAL_TICS = 10500;" in source
    assert "survivalTics != MIN_SURVIVAL_TICS && survivalTics != MAX_SURVIVAL_TICS" in source
    assert 'CVar.FindCVar("ds_p030_duration_tics")' in source
    assert "tic >= RunEndTic()" in source
    assert "mfEnabled && survivalTics == MAD_FOREST_TICS ? stageTics + mfHeld : survivalTics" in source
    assert "int stageTics = rsHurry ? DSStage.DurationTics(mfStage) / 2 : DSStage.DurationTics(mfStage);" in source
    assert "duration_tics=%d duration_seconds=%d" in source
    assert "nosave int ds_p030_duration_tics = 10500;" in cvarinfo

    assert "[ValidateSet(0, 1)]" in launcher
    assert "[int]$TestMinutes = 0" in launcher
    assert "$durationTics = $TestMinutes * 60 * 35" in launcher
    assert '"+set", "ds_p030_duration_tics"' in launcher
    # The launcher's default is the full Mad Forest stage (docs/TODO.md step 2).
    assert "$durationTics = 63000" in launcher
    assert "if (mfEnabled && survivalTics == MAD_FOREST_TICS) return;" in source


def test_duration_selection_is_retained_across_results_retry():
    source = slice_source.read()
    reset = source[source.index("void ResetRunState()") : source.index("void LogicalTic()")]

    assert "ResetRunState();" in source
    assert "survivalTics" not in reset
    assert "ConfigureDuration(); ResetRunState();" in source


def test_one_minute_engine_evidence_validates_with_selected_duration():
    log_path = ROOT / "evidence/P030/20260913T180803164391Z-doom-survivors-duration2/engine.log"
    if not log_path.exists():
        pytest.skip("one-minute packaged runtime evidence is not present")
    result = validate(log_path.read_text(encoding="utf-8", errors="replace"),
                      accelerated=False, expected_duration=2100)
    assert result["status"] == "PASS", result["errors"]


def test_validator_keeps_strict_default_and_only_supported_durations():
    assert SUPPORTED_DURATIONS == (2100, 10500)
    log_path = ROOT / "evidence/P030/20260913T180803164391Z-doom-survivors-duration2/engine.log"
    if not log_path.exists():
        pytest.skip("one-minute packaged runtime evidence is not present")
    log = log_path.read_text(encoding="utf-8", errors="replace")
    assert validate(log, accelerated=False)["status"] == "FAIL"
    assert validate(log, accelerated=False, expected_duration=4200)["status"] == "FAIL"
