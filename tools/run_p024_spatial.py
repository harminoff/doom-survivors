"""Build, run and strictly validate the packaged P024 spatial-index fixture.

The validator reconstructs every exact result list from the engine-emitted
logical world and query records.  Counts and digests are additional evidence;
they are never accepted in place of ordered full handles.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.build import build
from tools.run_probe import run

BOOT_RE = re.compile(r"DS_P024_BOOT\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
WORLD_BEGIN_RE = re.compile(r"DS_P024_WORLD_BEGIN\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
WORLD_RE = re.compile(r"DS_P024_WORLD\s+version=(?P<version>-?\d+)\s+slot=(?P<slot>-?\d+)\s+generation=(?P<generation>-?\d+)\s+stable_id=(?P<stable_id>-?\d+)\s+live=(?P<live>-?\d+)\s+x=(?P<x>-?[0-9.]+)\s+y=(?P<y>-?[0-9.]+)\s+radius=(?P<radius>-?[0-9.]+)")
WORLD_END_RE = re.compile(r"DS_P024_WORLD_END\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
QUERY_RE = re.compile(r"DS_P024_QUERY\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
RESULT_RE = re.compile(r"DS_P024_RESULT\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
PERF_WORKLOAD_RE = re.compile(r"DS_P024_PERF_WORKLOAD\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
PERF_RE = re.compile(r"DS_P024_PERF\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
PROXY_RE = re.compile(r"DS_P024_PROXY\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
STALE_RE = re.compile(r"DS_P024_STALE\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
REBASE_RE = re.compile(r"DS_P024_REBASE\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
TIE_RE = re.compile(r"DS_P024_NEAREST_TIE_CHECK\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)
COMPLETE_RE = re.compile(r"DS_P024_COMPLETE\s+(?P<body>.*?)(?=\sDS_[A-Z0-9_]+\s|$)", re.S)


def fields(body: str) -> dict[str, str]:
    return {key: value for key, value in re.findall(r"([A-Za-z_][A-Za-z0-9_]*)=([^\s]+)", body)}


def integer(value: str) -> int:
    return int(value)


def signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value >= 0x80000000 else value


def multiply_add(value: int, multiplier: int, addend: int) -> int:
    return signed32(value * multiplier + addend)


def result_digest(results: list[tuple[int, int, int]]) -> int:
    digest = 216613626
    for _slot, generation, stable_id in results:
        digest = multiply_add(digest, 16777619, stable_id)
        digest = multiply_add(digest, 16777619, generation)
    return digest


def world_digest(world: dict[int, dict[str, Any]]) -> int:
    digest = 216613626
    for slot in sorted(world):
        entity = world[slot]
        digest = multiply_add(digest, 31, slot)
        digest = multiply_add(digest, 31, entity["generation"])
        digest = multiply_add(digest, 31, entity["stable_id"])
        digest = multiply_add(digest, 31, int(entity["x"] * 1000.0))
        digest = multiply_add(digest, 31, int(entity["y"] * 1000.0))
        digest = multiply_add(digest, 31, int(entity["radius"] * 1000.0))
    return digest


def exact_radius(entity: dict[str, Any], x: float, y: float, radius: float) -> bool:
    if radius < 0.0 or entity["radius"] < 0.0:
        return False
    reach = radius + entity["radius"]
    return (entity["x"] - x) ** 2 + (entity["y"] - y) ** 2 <= reach * reach + 1e-9


def exact_rectangle(entity: dict[str, Any], min_x: float, max_x: float,
                    min_y: float, max_y: float) -> bool:
    if entity["radius"] < 0.0:
        return False
    min_x, max_x = sorted((min_x, max_x))
    min_y, max_y = sorted((min_y, max_y))
    closest_x = min(max(entity["x"], min_x), max_x)
    closest_y = min(max(entity["y"], min_y), max_y)
    return ((entity["x"] - closest_x) ** 2 + (entity["y"] - closest_y) ** 2
            <= entity["radius"] ** 2 + 1e-9)


def exact_swept(entity: dict[str, Any], start_x: float, start_y: float,
                end_x: float, end_y: float, sweep_radius: float = 8.0) -> bool:
    if sweep_radius < 0.0 or entity["radius"] < 0.0:
        return False
    dx, dy = end_x - start_x, end_y - start_y
    length_squared = dx * dx + dy * dy
    t = 0.0 if length_squared == 0.0 else ((entity["x"] - start_x) * dx + (entity["y"] - start_y) * dy) / length_squared
    t = min(1.0, max(0.0, t))
    closest_x, closest_y = start_x + t * dx, start_y + t * dy
    reach = sweep_radius + entity["radius"]
    return ((entity["x"] - closest_x) ** 2 + (entity["y"] - closest_y) ** 2
            <= reach * reach + 1e-9)


def expected_results(world: dict[int, dict[str, Any]], kind: str,
                     a: float, b: float, c: float, d: float) -> list[tuple[int, int, int]]:
    eligible: list[dict[str, Any]] = []
    for entity in world.values():
        if kind in ("radius", "nearest"):
            ok = exact_radius(entity, a, b, c)
        elif kind == "rectangle":
            ok = exact_rectangle(entity, a, b, c, d)
        elif kind == "swept":
            ok = exact_swept(entity, a, b, c, d)
        else:
            ok = False
        if ok:
            eligible.append(entity)
    if kind == "nearest":
        eligible.sort(key=lambda e: ((e["x"] - a) ** 2 + (e["y"] - b) ** 2, e["stable_id"]))
        eligible = eligible[:1]
    else:
        eligible.sort(key=lambda e: (e["stable_id"], e["slot"]))
    return [(e["slot"], e["generation"], e["stable_id"]) for e in eligible]


def parse_records(log: str, regex: re.Pattern[str]) -> list[dict[str, str]]:
    return [fields(match.groupdict().get("body", match.group(0))) for match in regex.finditer(log)]


def validate_performance_record(
    perf: dict[str, str],
    workload: list[dict[str, str]],
    world: dict[int, dict[str, Any]],
) -> list[str]:
    """Validate the declared query-only comparison independently of the engine.

    The runtime owns measured times and counters; this helper owns the
    same-workload arithmetic and full ordered-result digest reconstruction so
    unit tests can exercise rejection of forged or non-improving records.
    """
    errors: list[str] = []
    try:
        count = integer(perf["query_count"])
        repeat = integer(perf["repeat_count"])
        entity_count = integer(perf["entity_count"])
        if len(workload) != count or [integer(row["ordinal"]) for row in workload] != list(range(count)):
            errors.append("performance workload is truncated or reordered")
        if perf.get("timing_scope") != "QUERY_ONLY" or perf.get("index_rebuild_excluded") != "1":
            errors.append("performance timing scope is not declared query-only")
        if integer(perf["brute_checks"]) != entity_count * count * repeat:
            errors.append("performance brute workload mismatch")
        if integer(perf["optimized_narrow_checks"]) >= integer(perf["brute_checks"]):
            errors.append("performance optimized path did not reduce narrow checks")
        if float(perf["optimized_ms"]) >= float(perf["brute_ms"]):
            errors.append("performance optimized query path was not faster")
        workload_digest = 216613626
        expected_workload: list[tuple[str, float, float, float, float]] = []
        kind_names = ("radius", "rectangle", "swept", "nearest")
        for row in workload:
            mode = integer(row["kind"])
            if mode < 0 or mode >= len(kind_names):
                errors.append("performance workload contains an unknown query kind")
                continue
            values = (float(row["a"]), float(row["b"]), float(row["c"]), float(row["d"]))
            workload_digest = multiply_add(workload_digest, 31, mode)
            for value in values:
                workload_digest = multiply_add(workload_digest, 31, int(value * 1000.0))
            expected_workload.append((kind_names[mode], *values))
        if integer(perf["workload_digest"]) != workload_digest:
            errors.append("performance workload digest does not reconstruct")
        expected_result_digest = 216613626
        for _ in range(repeat):
            for kind, a, b, c, d in expected_workload:
                expected = expected_results(world, kind, a, b, c, d)
                expected_result_digest = multiply_add(expected_result_digest, 31, result_digest_value_for(expected))
        if integer(perf["brute_digest"]) != expected_result_digest or integer(perf["optimized_digest"]) != expected_result_digest:
            errors.append("performance digest does not reconstruct full ordered results")
        if integer(perf["parity"]) != 1:
            errors.append("performance parity marker is false")
    except (KeyError, ValueError, IndexError, TypeError, ZeroDivisionError) as exc:
        errors.append(f"malformed performance record: {exc}")
    return errors


def validate(log: str, expected_variant: int | None = None) -> dict[str, Any]:
    errors: list[str] = []
    if "DS_P024_BOOT map=MAP10" not in log:
        errors.append("missing MAP10 P024 boot marker")
    if "cell_size=128.000" not in log or "floor=MATHEMATICAL" not in log:
        errors.append("missing locked cell size or mathematical floor marker")
    if "grid=UNIFORM_CSR" not in log or "handles=FULL_GENERATION_STABLE_ID" not in log:
        errors.append("missing production CSR/full-handle marker")
    if "random_seed=240924" not in log:
        errors.append("deterministic randomized-world seed marker is missing")

    worlds: dict[int, dict[int, dict[str, Any]]] = {}
    world_begins = parse_records(log, WORLD_BEGIN_RE)
    world_ends = parse_records(log, WORLD_END_RE)
    world_rows = parse_records(log, WORLD_RE)
    for row in world_rows:
        try:
            version = integer(row["version"])
            entity = {"slot": integer(row["slot"]), "generation": integer(row["generation"]),
                      "stable_id": integer(row["stable_id"]), "live": integer(row["live"]),
                      "x": float(row["x"]), "y": float(row["y"]), "radius": float(row["radius"])}
            worlds.setdefault(version, {})[entity["slot"]] = entity
        except (KeyError, ValueError) as exc:
            errors.append(f"malformed world record: {exc}")
    if not world_begins or not world_ends or not worlds:
        errors.append("world records are missing; marker-only output is rejected")
    begin_versions = [integer(row["version"]) for row in world_begins if "version" in row]
    end_versions = [integer(row["version"]) for row in world_ends if "version" in row]
    if begin_versions != sorted(set(begin_versions)) or end_versions != sorted(set(end_versions)):
        errors.append("world versions are duplicated or out of order")
    for row in world_begins:
        try:
            version = integer(row["version"])
            if version not in worlds:
                errors.append(f"world {version} has no entity records")
            elif integer(row["live"]) != len(worlds[version]):
                errors.append(f"world {version} live count does not match records")
        except (KeyError, ValueError):
            errors.append("malformed world begin marker")
    for row in world_ends:
        try:
            version = integer(row["version"])
            if version not in worlds:
                continue
            if integer(row["records"]) != len(worlds[version]):
                errors.append(f"world {version} record count is truncated")
            if integer(row["digest"]) != world_digest(worlds[version]):
                errors.append(f"world {version} digest does not reconstruct")
        except (KeyError, ValueError):
            errors.append("malformed world end marker")

    # Required deterministic fixture features.
    all_entities = [entity for world in worlds.values() for entity in world.values()]
    if not any(abs(entity["x"] + 128.0) < 1e-5 for entity in all_entities):
        errors.append("inclusive -128 cell boundary fixture is missing")
    if not any(entity["x"] < -128.0 for entity in all_entities):
        errors.append("negative fractional cell fixture is missing")
    if not any(entity["radius"] >= 180.0 for entity in all_entities):
        errors.append("large multi-cell entity fixture is missing")
    tie_markers = parse_records(log, TIE_RE)
    if not tie_markers:
        errors.append("nearest tie fixture marker is missing")

    results: dict[tuple[int, str], list[tuple[int, int, int]]] = {}
    result_ordinals: dict[tuple[int, str], list[int]] = {}
    for row in parse_records(log, RESULT_RE):
        try:
            key = (integer(row["qid"]), row["path"])
            value = (integer(row["slot"]), integer(row["generation"]), integer(row["stable_id"]))
            results.setdefault(key, []).append(value)
            result_ordinals.setdefault(key, []).append(integer(row["ordinal"]))
        except (KeyError, ValueError) as exc:
            errors.append(f"malformed result record: {exc}")

    queries = parse_records(log, QUERY_RE)
    if not queries:
        errors.append("query records are missing; marker-only output is rejected")
    qids = [integer(row["qid"]) for row in queries if "qid" in row]
    if qids != list(range(1, len(qids) + 1)):
        errors.append("query IDs are truncated, duplicated, or reordered")
    kinds: set[str] = set()
    result_digest = hashlib.sha256()
    for query in queries:
        try:
            qid, version, kind = integer(query["qid"]), integer(query["world"]), query["kind"]
            kinds.add(kind)
            if version not in worlds:
                errors.append(f"query {qid} references missing world {version}")
                continue
            expected = expected_results(worlds[version], kind, float(query["a"]), float(query["b"]), float(query["c"]), float(query["d"]))
            if kind == "nearest" and abs(float(query["a"]) - 2000.0) < 1e-5 and abs(float(query["b"]) - 2000.0) < 1e-5:
                if not expected or expected[0][2] != 1006:
                    errors.append(f"query {qid} did not resolve the equal-distance nearest tie to lower stable ID")
            for path in ("brute", "optimized"):
                actual = results.get((qid, path), [])
                if result_ordinals.get((qid, path), []) != list(range(len(actual))):
                    errors.append(f"query {qid} {path} ordinals are truncated or reordered")
                if actual != expected:
                    errors.append(f"query {qid} {path} full ordered handle list differs from exact oracle")
                if len({(slot, generation, stable_id) for slot, generation, stable_id in actual}) != len(actual):
                    errors.append(f"query {qid} {path} contains duplicate handles")
                if any(actual[i][2] >= actual[i + 1][2] for i in range(len(actual) - 1)):
                    errors.append(f"query {qid} {path} is not stable-ID ascending")
                for slot, generation, stable_id in actual:
                    entity = worlds[version].get(slot)
                    if entity is None or (entity["generation"], entity["stable_id"]) != (generation, stable_id):
                        errors.append(f"query {qid} {path} contains stale or foreign generation")
                result_digest.update(f"{qid}:{path}:{actual};".encode())
            if integer(query.get("brute_count", "-1")) != len(expected) or integer(query.get("optimized_count", "-1")) != len(expected):
                errors.append(f"query {qid} count fields do not match full lists")
            expected_digest = result_digest_value_for(expected)
            if integer(query.get("brute_digest", "0")) != expected_digest:
                errors.append(f"query {qid} brute digest does not match its full list")
            if integer(query.get("optimized_digest", "0")) != expected_digest:
                errors.append(f"query {qid} optimized digest does not match its full list")
            if integer(query.get("parity", "0")) != 1:
                errors.append(f"query {qid} did not report optimized/brute parity")
            if integer(query.get("optimized_narrow_checks", "0")) != integer(query.get("candidate_count", "-1")):
                errors.append(f"query {qid} narrow check count is not the deduplicated candidate count")
            if integer(query.get("candidate_count", "0")) > integer(query.get("brute_checks", "0")):
                errors.append(f"query {qid} broad phase did more checks than brute force")
            if kind == "nearest":
                expected_nearest = expected[0] if expected else (-1, 0, 0)
                observed_nearest = (integer(query.get("nearest_slot", "-2")), integer(query.get("nearest_generation", "-2")), integer(query.get("nearest_id", "-2")))
                if observed_nearest != expected_nearest:
                    errors.append(f"query {qid} nearest handle differs from the exact stable tie oracle")
        except (KeyError, ValueError, TypeError) as exc:
            errors.append(f"malformed query record: {exc}")
    for required in ("radius", "rectangle", "swept", "nearest"):
        if required not in kinds:
            errors.append(f"missing {required} query workload")

    proxy = parse_records(log, PROXY_RE)
    if not proxy:
        errors.append("missing proxy invariance record")
    elif expected_variant is not None and integer(proxy[-1].get("variant", "-1")) != expected_variant:
        errors.append(f"expected proxy variant {expected_variant}")
    if proxy:
        try:
            variant = integer(proxy[-1]["variant"])
            if variant == 1 and integer(proxy[-1].get("hidden", "0")) != 1:
                errors.append("hidden proxy variant did not mark proxies hidden")
            if variant == 2 and integer(proxy[-1].get("culled", "0")) != 1:
                errors.append("culled proxy variant did not mark proxies culled")
        except (KeyError, ValueError):
            errors.append("malformed proxy invariance record")
    if expected_variant == 2 and proxy and integer(proxy[-1].get("allocated", "-1")) != 0:
        errors.append("culled proxy variant allocated presentation actors")
    if expected_variant == 3 and proxy and proxy[-1].get("allocation_order") != "stable_descending":
        errors.append("reverse proxy allocation was not exercised")
    stale = parse_records(log, STALE_RE)
    if not stale:
        errors.append("missing stale-generation reuse record")
    else:
        row = stale[-1]
        try:
            if integer(row["stale_rejected"]) <= 0:
                errors.append("stale generation entry was not rejected")
            if integer(row["old_slot"]) != integer(row["replacement_slot"]):
                errors.append("stale test did not reuse the released slot")
            if integer(row["replacement_generation"]) == integer(row["old_generation"]):
                errors.append("slot reuse did not increment generation")
            if integer(row["replacement_stable_id"]) == integer(row["old_stable_id"]):
                errors.append("slot reuse did not assign a new stable ID")
        except (KeyError, ValueError):
            errors.append("malformed stale-generation record")
    rebase = parse_records(log, REBASE_RE)
    if not rebase or rebase[-1].get("query_unchanged") != "1":
        errors.append("logical origin rebase did not preserve query state")
    if len(worlds) >= 2:
        versions = sorted(worlds)
        if not any((worlds[versions[i]].get(slot, {}).get("x"), worlds[versions[i]].get(slot, {}).get("y")) != (worlds[versions[i + 1]].get(slot, {}).get("x"), worlds[versions[i + 1]].get(slot, {}).get("y")) for i in range(len(versions) - 1) for slot in set(worlds[versions[i]]) & set(worlds[versions[i + 1]])):
            errors.append("movement world versions did not change logical coordinates")
        if not any(len(worlds[versions[i + 1]]) < len(worlds[versions[i]]) for i in range(len(versions) - 1)):
            errors.append("mass deletion world version did not reduce live entities")

    workload = parse_records(log, PERF_WORKLOAD_RE)
    perf_rows = parse_records(log, PERF_RE)
    if not workload or not perf_rows:
        errors.append("performance workload or result is missing")
    perf = perf_rows[-1] if perf_rows else {}
    latest_world = worlds[max(worlds)] if worlds else {}
    errors.extend(validate_performance_record(perf, workload, latest_world))

    completion = parse_records(log, COMPLETE_RE)
    if not completion:
        errors.append("missing strict P024 completion marker")
    elif integer(completion[-1].get("failures", "-1")) != 0:
        errors.append("engine reported internal P024 parity/performance failures")
    if "Script error" in log or "Execution could not continue" in log:
        errors.append("engine log contains a script/runtime error")
    return {
        "status": "PASS" if not errors else "FAIL",
        "classification": "P024_PACKAGED_UZDOOM_SPATIAL_INDEX",
        "errors": errors,
        "world_count": len(worlds),
        "query_count": len(queries),
        "query_kinds": sorted(kinds),
        "result_digest": result_digest.hexdigest(),
        "performance": perf or None,
        "completion": completion[-1] if completion else None,
    }


def result_digest_value_for(results: list[tuple[int, int, int]]) -> int:
    return result_digest(results)


def run_probe(*, package: Path | None = None, seconds: float = 30.0) -> dict[str, Any]:
    if not 10.0 <= seconds <= 120.0:
        raise ValueError("seconds must be between 10 and 120")
    if package is None:
        package = Path(build(ROOT, room_spec=ROOT / "maps/source/p024-spatial/room.json")["package"])
    package = Path(package)
    compile_result = run(package, seconds, True, False, "P024", 60, 1280, 720,
                         map_name="MAP10", completion_marker="DS_P024_COMPLETE")
    if compile_result["status"] != "COMPILE_PASS":
        return {"status": "FAIL", "classification": "P024_PACKAGED_UZDOOM_SPATIAL_INDEX", "errors": ["compile gate failed"], "compile": compile_result}
    runs: list[dict[str, Any]] = []
    for variant in range(4):
        runtime = run(package, seconds, False, False, "P024", 60, 1280, 720,
                      map_name="MAP10", completion_marker="DS_P024_COMPLETE",
                      active_in_background=True, vsync=False,
                      startup_commands=["+set", "ds_p024_proxy_variant", str(variant)])
        evidence = Path(runtime["evidence"])
        log_path = evidence / "engine.log"
        log = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
        strict = validate(log, expected_variant=variant)
        strict.update({"variant": variant, "runtime": runtime, "engine_log": str(log_path),
                       "package_sha256": runtime.get("package_sha256")})
        if runtime.get("status") != "RUNTIME_PASS":
            strict["errors"].append(f"runtime status was {runtime.get('status')}")
        if not runtime.get("captures"):
            strict["errors"].append("runtime did not produce a framebuffer capture")
        strict["status"] = "PASS" if not strict["errors"] else "FAIL"
        (evidence / "p024-result.json").write_text(json.dumps(strict, indent=2) + "\n", encoding="utf-8")
        runs.append(strict)
    # A second independent front run proves that the full ordered result
    # stream is deterministic across UZDoom processes, rather than merely
    # invariant across proxy presentation variants.
    replay_runtime = run(package, seconds, False, False, "P024", 60, 1280, 720,
                         map_name="MAP10", completion_marker="DS_P024_COMPLETE",
                         active_in_background=True, vsync=False,
                         startup_commands=["+set", "ds_p024_proxy_variant", "0"])
    replay_evidence = Path(replay_runtime["evidence"])
    replay_log_path = replay_evidence / "engine.log"
    replay_log = replay_log_path.read_text(encoding="utf-8", errors="replace") if replay_log_path.exists() else ""
    replay = validate(replay_log, expected_variant=0)
    replay.update({"variant": 0, "replay": True, "runtime": replay_runtime,
                   "engine_log": str(replay_log_path), "package_sha256": replay_runtime.get("package_sha256")})
    if replay_runtime.get("status") != "RUNTIME_PASS":
        replay["errors"].append(f"replay runtime status was {replay_runtime.get('status')}")
    if not replay_runtime.get("captures"):
        replay["errors"].append("replay did not produce a framebuffer capture")
    replay["status"] = "PASS" if not replay["errors"] else "FAIL"
    (replay_evidence / "p024-replay-result.json").write_text(json.dumps(replay, indent=2) + "\n", encoding="utf-8")
    errors = [f"variant {item['variant']}: {error}" for item in runs for error in item["errors"]]
    errors.extend(f"replay: {error}" for error in replay["errors"])
    if any(item.get("package_sha256") != compile_result.get("package_sha256") for item in runs):
        errors.append("runtime used a package different from the compile gate")
    if len({item.get("result_digest") for item in runs}) != 1:
        errors.append("proxy visibility/allocation changed the logical ordered result digest")
    if replay.get("result_digest") != runs[0].get("result_digest"):
        errors.append("deterministic front replay changed the logical ordered result digest")
    result = {"status": "PASS" if not errors and all(item["status"] == "PASS" for item in runs) else "FAIL",
              "classification": "P024_PACKAGED_UZDOOM_SPATIAL_INDEX", "errors": errors,
              "package": str(package), "package_sha256": hashlib.sha256(package.read_bytes()).hexdigest(),
              "compile": compile_result, "runs": runs, "replay": replay}
    evidence_dir = ROOT / "evidence" / "P024"
    evidence_dir.mkdir(parents=True, exist_ok=True)
    result["evidence"] = str(evidence_dir / "latest-result.json")
    (evidence_dir / "latest-result.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2, sort_keys=True))
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path)
    parser.add_argument("--seconds", type=float, default=30.0)
    parser.add_argument("--validate-log", type=Path)
    parser.add_argument("--variant", type=int)
    args = parser.parse_args(argv)
    try:
        result = (validate(args.validate_log.read_text(encoding="utf-8", errors="replace"), args.variant)
                  if args.validate_log else run_probe(package=args.package, seconds=args.seconds))
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
