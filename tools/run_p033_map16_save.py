"""Run a strict UZDoom MAP16 P033 save/restore continuation check.

Build the combined MAP16--MAP19 package first.  This script validates the
supplied IPK3; it does not rebuild it.  The save is taken after a bounded
normal-speed wait and only passes when MAP16 itself reports a transformed,
post-draft canonical snapshot and restored automatic Bloody Tear hit.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tests.runtime.stats.test_p033_stats import validate_p033_map16_save_roundtrip
from tools.run_p033_stats import _capture_manifest
from tools.run_persistence_bench import read_log, run_engine
from tools.run_probe import config_text


def run_roundtrip(package: Path, *, timeout: float = 105.0,
                  wait_tics: int = 2400) -> dict[str, object]:
    package = package.resolve()
    if not package.is_file():
        return {"status": "FAIL", "errors": [f"missing package: {package}"]}
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-p033-map16-save-load"
    evidence = ROOT / "evidence/P033" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    restore_capture = evidence / "restore-captures"
    save_capture.mkdir()
    restore_capture.mkdir()
    save_name = "ds_p033_map16"
    save_script = profile / "save.cfg"
    restore_script = profile / "restore.cfg"
    save_script.write_text(
        f'set ds_p033_save_snapshot_request 1; wait {wait_tics}; '
        f'screenshot; save {save_name} "P033 MAP16 state"; '
        'set ds_p033_save_snapshot_request 0; wait 8; quit\n',
        encoding="utf-8", newline="\n")
    restore_script.write_text(
        "wait 150; screenshot; wait 120; quit\n",
        encoding="utf-8", newline="\n")
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_args = ["+enablescriptscreenshot", "true", "+set", "ds_p030_mode", "p033",
                 "+set", "ds_p032_mode", "evolution",
                 # ConfigureDuration accepts the source-adjacent 10500-tic
                 # option; 7000 silently falls back and would misstate setup.
                 "+set", "ds_p030_duration_tics", "10500",
                 "+set", "ds_p030_speed", "1",
                 "+set", "ds_p030_camera_variant", "0",
                 "+set", "ds_p030_telemetry", "1",
                 "+set", "ds_p033_contact_fixture", "0",
                 "+map", "MAP16", "+exec", save_script.name]
    save_rc = run_engine(executable, package, profile, "p033-map16-save.log",
                         save_args, timeout=timeout)
    save_log = read_log(profile, "p033-map16-save.log")
    save_files = sorted(path for path in profile.glob(f"{save_name}*") if path.is_file())
    save_file = save_files[-1] if save_files else None

    restore_rc: int | None = None
    restore_log = ""
    if save_file is not None:
        (profile / "config.ini").write_text(config_text(restore_capture, vsync=False),
                                            encoding="utf-8", newline="\n")
        restore_args = ["-loadgame", save_file.stem,
                        "+enablescriptscreenshot", "true",
                        "+set", "ds_p030_mode", "p033",
                        "+set", "ds_p032_mode", "evolution",
                        "+set", "ds_p030_speed", "1",
                        "+set", "ds_p030_camera_variant", "0",
                        "+set", "ds_p030_telemetry", "1",
                        "+exec", restore_script.name]
        restore_rc = run_engine(executable, package, profile, "p033-map16-restore.log",
                                restore_args, timeout=timeout)
        restore_log = read_log(profile, "p033-map16-restore.log")

    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "restore-engine.log").write_text(restore_log, encoding="utf-8", newline="\n")
    shutil.copy2(save_script, evidence / save_script.name)
    shutil.copy2(restore_script, evidence / restore_script.name)
    validation = validate_p033_map16_save_roundtrip(save_log, restore_log, save_rc, restore_rc)
    captures = _capture_manifest([save_capture, restore_capture], evidence)
    errors = list(validation["errors"])
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a nonempty post-run savegame")
    if len(captures) < 2 or any(not row["nonblank"] for row in captures):
        errors.append("save and restored UZDoom sessions did not produce nonblank framebuffer captures")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    result = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P033_MAP16_CANONICAL_SAVE_RESTORE_AND_WEAPON_CONTINUATION",
        "package": str(package), "package_sha256": package_sha,
        "package_provenance": "SUPPLIED_PACKAGE_VALIDATION_ONLY",
        "source_rebuild_performed": False,
        "save_exit_code": save_rc, "restore_exit_code": restore_rc,
        "save_file": str(save_file) if save_file else None,
        "save_file_size": save_file.stat().st_size if save_file else None,
        "validation": validation, "screenshots": captures,
        "evidence": str(evidence), "errors": errors,
    }
    (evidence / "roundtrip.json").write_text(json.dumps(result, indent=2) + "\n",
                                             encoding="utf-8")
    return result


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--timeout", type=float, default=105.0)
    parser.add_argument("--wait-tics", type=int, default=2400)
    args = parser.parse_args()
    result = run_roundtrip(args.package, timeout=args.timeout, wait_tics=args.wait_tics)
    print(json.dumps(result, indent=2), flush=True)
    raise SystemExit(0 if result["status"] == "PASS" else 1)
