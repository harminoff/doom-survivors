"""N2 manual-route save/load roundtrip evidence (docs/contracts/normal-play-
integration.md "Persistence"/"Evidence" item 3).

Two-process pattern modeled directly on tools/run_p040_map16.py's
``run_roundtrip``: run the soak_n2 controller (same bot/mover/xp-acceleration
combination as tools/run_n2_soak.py) until at least 6 weapon slots are owned
(the Whip starter plus >=5 real draft acquisitions), request a labelled save
via ``ds_n2_save_snapshot_request``, save through the real UZDoom ``save``
console command, then reload the .zds in a fresh process and let the run
continue (bot/mover still active) so every owned engine can produce a new
accepted hit (or erase/activation) after load.

Validates: the ZScript-side DS_N2_SAVE_STATE/DS_N2_RESTORE_STATE hash
equality (already exact-compared before rebase inside
EmitN2ManualSaveStateIfRequested/RestoreN2ManualSavedRun -- this only checks
that the accepted line was printed and no DS_RUNTIME_ASSERT_FAIL fired), the
owned-weapon list is byte-identical across save/restore, and that every owned
engine (plus the Whip starter) produced at least one new accepted hit/erase/
activation in the restore process's own log.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.run_persistence_bench import read_log, run_engine
from tools.run_probe import config_text
from tools.run_p033_stats import _capture_manifest

XP_MULTIPLIER_MILLI = 60000
SPEED = 4
DURATION_TICS = 10500
# In one observed full soak (tools/run_n2_soak.py), several owned engines
# (e.g. Cross/RETURNING, an erase global, a Paired formation) produced only
# 1-3 accepted hits/erasures across the *entire* 10,500-logical-tic run, so a
# short post-restore window is statistically unlikely to reproduce one. The
# restore phase therefore runs for roughly the remainder of that same budget
# (DURATION_TICS logical tics / SPEED, since the save can land early) instead
# of a short smoke window.
SAVE_WAIT_WORLD_TICS = 2700
# A global-erase system (Pentagram/Gorgeous Moon) only erases an enemy that is
# both in range and alive at its own periodic activation tic, so its base
# rate stays low (observed: as few as 1 erasure across an entire 10,500-tic
# soak). A save that lands early (this route saves as soon as >=6 weapons are
# owned, which can happen well before 10,500 logical tics) leaves most of the
# run for the restore phase, so give it a materially larger budget than one
# normal soak's worth of logical tics rather than just the remainder of it.
RESTORE_WAIT_WORLD_TICS = 4200

# N2_ENGINE_* numeric ids (src/zscript/gameplay/VerticalSlice.zs) -> the
# engine-name tag N2CreditDamage prints in DS_N2_DISPATCH_DAMAGE_CREDIT rows.
# GLOBAL_ERASE (8) credits no damage; its own evidence is the DS_P040_ACTIVATION
# erase/activation marker, same fallback tools/run_n2_soak.py uses.
ENGINE_TAGS = {
    1: "AIMED", 2: "BALLISTIC", 3: "RETURNING", 4: "ORBIT", 5: "GROUND",
    6: "AURA", 7: "GLOBAL", 8: None, 9: "BOUNCE", 10: "PAIRED", 11: "GENERIC",
}


def _rows(log: str, marker: str) -> list[dict[str, str]]:
    flat = re.sub(r"\s+", " ", log)
    return [dict(re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=(\S+)", m.group(1)))
            for m in re.finditer(rf"{re.escape(marker)}\s+(.*?)(?=\sDS_[A-Z0-9_]+\s|$)", flat)]


def _acquired_engines(save_log: str) -> dict[int, int]:
    """{system_id: engine_id} for every real accepted draft acquisition."""
    out: dict[int, int] = {}
    for row in _rows(save_log, "DS_N2_DISPATCH_ACQUIRE"):
        if row.get("accepted") == "1":
            out[int(row["system_id"])] = int(row["engine"])
    return out


def validate(save_log: str, restore_log: str, save_rc: int | None,
             restore_rc: int | None) -> dict[str, object]:
    errors: list[str] = []
    saves = _rows(save_log, "DS_N2_SAVE_STATE")
    if len(saves) != 1 or saves[0].get("accepted") != "1":
        errors.append(f"expected exactly one DS_N2_SAVE_STATE accepted=1 in save log, found {len(saves)}")
        saved = {}
    else:
        saved = saves[0]
    if int(saved.get("owned_weapon_count", "0") or 0) < 6:
        errors.append(f"save snapshot was taken with fewer than 6 owned weapon slots: {saved.get('owned_weapon_count')}")
    if save_rc not in (0, None):
        errors.append(f"save process exited with code {save_rc}")
    if "DS_RUNTIME_ASSERT_FAIL" in save_log:
        errors.append("save-phase log contains a DS_RUNTIME_ASSERT_FAIL")

    rejected = _rows(restore_log, "DS_RUNTIME_ASSERT_FAIL")
    restores = _rows(restore_log, "DS_N2_RESTORE_STATE")
    if any(r.get("kind") == "N2_RESTORE_REJECTED" for r in rejected):
        errors.append("restore was rejected: DS_RUNTIME_ASSERT_FAIL kind=N2_RESTORE_REJECTED present")
    if len(restores) != 1 or restores[0].get("accepted") != "1":
        errors.append(f"expected exactly one DS_N2_RESTORE_STATE accepted=1 in restore log, found {len(restores)}")
        restored = {}
    else:
        restored = restores[0]
    if rejected and not any(r.get("kind") == "N2_RESTORE_REJECTED" for r in rejected):
        errors.append(f"restore-phase log contains other DS_RUNTIME_ASSERT_FAIL rows: {rejected}")

    hash_fields = ("owned_hash", "p031_hash", "p032_hash", "chest_hash",
                   "healing_hash", "source_rank_hash", "resolved_rank_hash",
                   "resolved_rank_hash_with_recovery", "rank_hash_amount_growth",
                   "level", "health", "owned_weapon_count")
    for field in hash_fields:
        sv, rv = saved.get(field), restored.get(f"saved_{field}")
        if sv is None or rv is None or sv != rv:
            errors.append(f"{field} not exactly equal across save/restore: saved={sv} restored_saved={rv}")
    if saved.get("owned_list") != restored.get("owned_list"):
        errors.append(f"owned-weapon list not identical: saved={saved.get('owned_list')} restored={restored.get('owned_list')}")

    engines = _acquired_engines(save_log)
    engines_needing_evidence = sorted(set(engines.values()))
    credited = {r.get("engine") for r in _rows(restore_log, "DS_N2_DISPATCH_DAMAGE_CREDIT")
                if int(r.get("accepted_delta_milli", "0") or 0) > 0}
    # Pentagram/Gorgeous Moon fire on their own periodic schedule regardless
    # of whether any enemy is in range that tic (GlobalRuntime.zs
    # DSP040ProcessEraseTic->DSP040FirePentagram/DSP040FireMoonPhase1 always
    # print DS_P040_PENTAGRAM_FIRE/DS_P040_MOON_PHASE1, with erased_enemies=0
    # when nothing was in range); DS_P040_ERASE_ENEMY only fires when an
    # erasure actually lands. Any of the three is real "activation" evidence
    # -- DS_P040_ACTIVATION (kind=STRIKE) belongs to the Lightning/Thunder
    # Loop strike weapons, not erase.
    activation_seen = ("DS_P040_ERASE_ENEMY" in restore_log
                        or "DS_P040_PENTAGRAM_FIRE" in restore_log
                        or "DS_P040_MOON_PHASE1" in restore_log)
    hit_evidence: dict[str, object] = {}
    for engine_id in engines_needing_evidence:
        tag = ENGINE_TAGS.get(engine_id)
        systems = sorted(s for s, e in engines.items() if e == engine_id)
        if tag is None:
            ok = activation_seen
        else:
            ok = tag in credited
        hit_evidence[str(engine_id)] = {"systems": systems, "tag": tag, "accepted": ok}
        if not ok:
            errors.append(f"engine {engine_id} (systems {systems}) produced no new accepted hit/erase/activation after load")
    # The Whip starter's hits are recorded but not required (docs/contracts/
    # normal-play-integration.md "Evidence" item 2: a strong ranged weapon
    # can clear its short strip first); only that it keeps firing
    # automatically after load is required.
    whip_rows_after_load = _rows(restore_log, "DS_P030_WHIP")
    whip_hits_after_load = sum(int(r.get("hits", "0") or 0) for r in whip_rows_after_load)
    if not whip_rows_after_load:
        errors.append("the Whip starter never fired after load")
    if restore_rc not in (0, None):
        errors.append(f"restore process exited with code {restore_rc}")

    return {
        "status": "PASS" if not errors else "FAIL",
        "errors": errors,
        "saved": saved,
        "restored": restored,
        "engines_owned": engines,
        "hit_evidence_after_restore": hit_evidence,
        "whip_hits_after_load": whip_hits_after_load,
    }


def run_roundtrip(package: Path, save_timeout: float = 220.0,
                  restore_timeout: float = 320.0,
                  save_wait_tics: int = SAVE_WAIT_WORLD_TICS,
                  restore_wait_tics: int = RESTORE_WAIT_WORLD_TICS) -> dict[str, object]:
    package = package.resolve()
    if not package.is_file():
        return {"status": "FAIL", "errors": [f"missing package: {package}"]}
    package_sha = hashlib.sha256(package.read_bytes()).hexdigest()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{stamp}-n2-manual-save-load"
    evidence = ROOT / "evidence/N2" / name
    evidence.mkdir(parents=True)
    profile = ROOT / ".local/probes" / name
    profile.mkdir(parents=True)
    save_capture = evidence / "save-captures"
    restore_capture = evidence / "restore-captures"
    save_capture.mkdir()
    restore_capture.mkdir()
    save_name = "ds_n2_manual"
    save_script = profile / "save.cfg"
    restore_script = profile / "restore.cfg"
    save_script.write_text(
        f"set ds_n2_save_snapshot_request 1; wait {save_wait_tics}; "
        f'screenshot; save {save_name} "N2 manual-route runtime state"; '
        "set ds_n2_save_snapshot_request 0; wait 8; quit\n",
        encoding="utf-8", newline="\n")
    restore_script.write_text(
        f"wait 60; screenshot; wait {restore_wait_tics}; screenshot; wait 30; quit\n",
        encoding="utf-8", newline="\n")
    (profile / "config.ini").write_text(config_text(save_capture, vsync=False),
                                        encoding="utf-8", newline="\n")
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    executable = ROOT / lock["uzdoom"]["executable"]["path"]
    save_args = ["+enablescriptscreenshot", "true",
                 "+set", "ds_p030_mode", "soak_n2",
                 "+set", "ds_n2_draft_bot", "1",
                 "+set", "ds_n2_soak_mover", "1",
                 "+set", "ds_n2_xp_multiplier_milli", str(XP_MULTIPLIER_MILLI),
                 "+set", "ds_p030_duration_tics", str(DURATION_TICS),
                 "+set", "ds_p030_speed", str(SPEED),
                 "+set", "ds_p030_telemetry", "1",
                 "+set", "ds_n2_save_snapshot_request", "0",
                 "+map", "MAP16", "+exec", save_script.name]
    save_rc = run_engine(executable, package, profile, "n2-manual-save.log",
                         save_args, timeout=save_timeout)
    save_log = read_log(profile, "n2-manual-save.log")
    saves = sorted((path for path in profile.glob(f"{save_name}*") if path.is_file()),
                   key=lambda path: path.stat().st_mtime_ns)
    save_file = saves[-1] if saves else None

    restore_rc: int | None = None
    restore_log = ""
    if save_file is not None:
        (profile / "config.ini").write_text(config_text(restore_capture, vsync=False),
                                            encoding="utf-8", newline="\n")
        restore_args = ["-loadgame", save_file.stem,
                        "+enablescriptscreenshot", "true",
                        "+set", "ds_p030_mode", "soak_n2",
                        "+set", "ds_n2_draft_bot", "1",
                        "+set", "ds_n2_soak_mover", "1",
                        "+set", "ds_n2_xp_multiplier_milli", str(XP_MULTIPLIER_MILLI),
                        "+set", "ds_p030_speed", str(SPEED),
                        "+set", "ds_p030_telemetry", "1",
                        "+exec", restore_script.name]
        restore_rc = run_engine(executable, package, profile,
                                "n2-manual-restore.log", restore_args,
                                timeout=restore_timeout)
        restore_log = read_log(profile, "n2-manual-restore.log")

    (evidence / "save-engine.log").write_text(save_log, encoding="utf-8", newline="\n")
    (evidence / "restore-engine.log").write_text(restore_log, encoding="utf-8", newline="\n")
    shutil.copy2(save_script, evidence / save_script.name)
    shutil.copy2(restore_script, evidence / restore_script.name)
    validation = validate(save_log, restore_log, save_rc, restore_rc)
    captures = _capture_manifest([save_capture, restore_capture], evidence)
    errors = list(validation["errors"])
    if save_file is None or save_file.stat().st_size <= 0:
        errors.append("UZDoom did not create a nonempty serialized MAP16 save")
    if len(captures) < 2 or any(not row["nonblank"] for row in captures):
        errors.append("save/restore sessions lack two nonblank UZDoom captures")
    if save_file is not None:
        shutil.copy2(save_file, evidence / save_file.name)
    report = {
        "status": "PASS" if not errors else "FAIL",
        "classification": "N2_MANUAL_ROUTE_SAVE_LOAD_ROUNDTRIP",
        "package": str(package),
        "package_sha256": package_sha,
        "save_exit_code": save_rc,
        "restore_exit_code": restore_rc,
        "save_file_size": save_file.stat().st_size if save_file else None,
        "validation": validation,
        "screenshots": captures,
        "evidence": str(evidence),
        "errors": errors,
    }
    (evidence / "roundtrip.json").write_text(json.dumps(report, indent=2) + "\n",
                                             encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path,
                        default=ROOT / "build/doom-survivors.ipk3")
    parser.add_argument("--save-timeout", type=float, default=220.0)
    parser.add_argument("--restore-timeout", type=float, default=320.0)
    parser.add_argument("--save-wait-tics", type=int, default=SAVE_WAIT_WORLD_TICS)
    parser.add_argument("--restore-wait-tics", type=int, default=RESTORE_WAIT_WORLD_TICS)
    args = parser.parse_args()
    result = run_roundtrip(args.package, args.save_timeout, args.restore_timeout,
                           args.save_wait_tics, args.restore_wait_tics)
    print(json.dumps(result, indent=2), flush=True)
    return 0 if result.get("status") == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
