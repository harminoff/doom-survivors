"""Validate the locked UZDoom development toolchain without changing the host."""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parents[2]
HASH_RE = __import__("re").compile(r"^[0-9a-fA-F]{64}$")
COMMIT_RE = __import__("re").compile(r"^[0-9a-fA-F]{40}$")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _relative_path(root: Path, value: Any, label: str) -> tuple[Path | None, str | None]:
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        return None, f"{label}: path must be a non-empty project-relative path"
    candidate = (root / Path(value)).resolve()
    try:
        candidate.relative_to(root.resolve())
    except ValueError:
        return None, f"{label}: path escapes root: {value}"
    return candidate, None


def _hash(value: Any, label: str) -> str | None:
    if not isinstance(value, str) or not HASH_RE.fullmatch(value):
        return f"{label}: required SHA-256 must be 64 hexadecimal characters"
    return None


def _run(command: list[str], cwd: Path | None = None) -> tuple[int, str, str]:
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, check=False)
    except OSError as exc:
        return 127, "", str(exc)
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def inspect(root: Path, lock_path: Path, runner: Callable[..., tuple[int, str, str]] = _run) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    checks: dict[str, Any] = {}
    root = root.resolve()
    try:
        lock_path = lock_path.resolve()
        lock_path.relative_to(root)
    except ValueError:
        return {"status": "FAIL", "root": str(root), "lock": str(lock_path), "errors": ["lock path escapes root"], "warnings": [], "checks": {}}
    if not lock_path.is_file():
        return {"status": "FAIL", "root": str(root), "lock": str(lock_path), "errors": [f"missing lock: {lock_path}"], "warnings": [], "checks": {}}
    try:
        lock = json.loads(lock_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return {"status": "FAIL", "root": str(root), "lock": str(lock_path), "errors": [f"invalid lock: {exc}"], "warnings": [], "checks": {}}
    if not isinstance(lock, dict) or lock.get("schema_version") != 1:
        errors.append("lock schema_version must be 1")
        lock = lock if isinstance(lock, dict) else {}
    uzdoom = lock.get("uzdoom")
    python_lock = lock.get("python")
    if not isinstance(uzdoom, dict) or not isinstance(python_lock, dict):
        errors.append("lock must contain uzdoom and python objects")
        uzdoom = uzdoom if isinstance(uzdoom, dict) else {}
        python_lock = python_lock if isinstance(python_lock, dict) else {}

    def required_path(value: Any, label: str) -> Path | None:
        path, error = _relative_path(root, value, label)
        if error:
            errors.append(error)
        return path

    def required_hash(value: Any, label: str) -> bool:
        error = _hash(value, label)
        if error:
            errors.append(error)
            return False
        return True

    executable = uzdoom.get("executable") if isinstance(uzdoom.get("executable"), dict) else {}
    if not isinstance(uzdoom.get("version"), str) or not uzdoom["version"]:
        errors.append("uzdoom.version must be a non-empty string")
    exe_path = required_path(executable.get("path"), "uzdoom.executable.path")
    exe_hash_ok = required_hash(executable.get("sha256"), "uzdoom.executable.sha256")
    if exe_path and exe_hash_ok:
        if not exe_path.is_file():
            errors.append(f"missing required executable: {exe_path}")
        else:
            actual = _sha256(exe_path)
            checks["executable"] = {"path": str(exe_path), "sha256": actual, "expected": executable["sha256"]}
            if actual.lower() != executable["sha256"].lower():
                errors.append(f"executable hash mismatch: {exe_path}")

    support = uzdoom.get("support_files")
    if not isinstance(support, list):
        errors.append("uzdoom.support_files must be an array")
        support = []
    for index, item in enumerate(support):
        if not isinstance(item, dict):
            errors.append(f"uzdoom.support_files[{index}] must be an object")
            continue
        label = f"uzdoom.support_files[{index}]"
        path = required_path(item.get("path"), label + ".path")
        hash_ok = required_hash(item.get("sha256"), label + ".sha256")
        if path and hash_ok:
            if not path.is_file():
                errors.append(f"missing required support file: {path}")
            elif _sha256(path).lower() != item["sha256"].lower():
                errors.append(f"support file hash mismatch: {path}")

    asset = uzdoom.get("asset") if isinstance(uzdoom.get("asset"), dict) else {}
    archive = required_path(asset.get("download_path"), "uzdoom.asset.download_path")
    publisher_ok = required_hash(asset.get("publisher_sha256"), "uzdoom.asset.publisher_sha256")
    observed_ok = required_hash(asset.get("observed_sha256"), "uzdoom.asset.observed_sha256")
    if publisher_ok and observed_ok and asset["publisher_sha256"].lower() != asset["observed_sha256"].lower():
        errors.append("uzdoom.asset publisher_sha256 and observed_sha256 disagree")
    if archive and publisher_ok and observed_ok:
        if not archive.is_file():
            warnings.append(f"downloaded archive absent (installed toolchain checks continue): {archive}")
        else:
            actual = _sha256(archive)
            checks["archive"] = {"path": str(archive), "sha256": actual}
            if actual.lower() != asset["observed_sha256"].lower() or actual.lower() != asset["publisher_sha256"].lower():
                errors.append(f"archive hash mismatch: {archive}")

    source = uzdoom.get("source") if isinstance(uzdoom.get("source"), dict) else {}
    source_dir = required_path(source.get("path"), "uzdoom.source.path")
    commit = source.get("commit")
    if not isinstance(commit, str) or not COMMIT_RE.fullmatch(commit):
        errors.append("uzdoom.source.commit must be a full 40-character hexadecimal commit")
    if source_dir:
        if not source_dir.is_dir():
            errors.append(f"missing source directory: {source_dir}")
        else:
            code, head, detail = runner(["git", "rev-parse", "HEAD"], cwd=source_dir)
            if code != 0 or not head:
                errors.append(f"cannot inspect source Git HEAD: {detail or head}")
            elif isinstance(commit, str) and head.lower() != commit.lower():
                errors.append(f"source Git HEAD mismatch: {head} != {commit}")
            code, status, detail = runner(["git", "status", "--porcelain"], cwd=source_dir)
            if code != 0:
                errors.append(f"cannot inspect source dirty status: {detail or status}")
            elif status:
                errors.append("source checkout is dirty")
            checks["source"] = {"path": str(source_dir), "head": head, "dirty": bool(status)}

    expected_python = python_lock.get("version")
    current_python = ".".join(map(str, sys.version_info[:3]))
    checks["python"] = {"version": current_python, "expected": expected_python}
    if not isinstance(expected_python, str) or current_python != expected_python:
        errors.append(f"Python version mismatch: {current_python} != {expected_python}")
    venv = required_path(python_lock.get("venv_path"), "python.venv_path")
    if venv and not venv.is_dir():
        warnings.append(f"Python virtual environment absent: {venv}")

    code, git_version, detail = runner(["git", "--version"], cwd=root)
    checks["git"] = {"version": git_version, "available": code == 0}
    if code != 0:
        errors.append(f"Git unavailable: {detail or git_version}")
    return {"status": "FAIL" if errors else "PASS", "root": str(root), "lock": str(lock_path), "errors": errors, "warnings": warnings, "checks": checks}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="project root (default: computed from doctor.py)")
    parser.add_argument("--lock", type=Path, help="lock file, relative to root by default")
    parser.add_argument("--text", action="store_true", help="print a human-readable summary instead of JSON")
    args = parser.parse_args(argv)
    root = args.root.resolve()
    lock = args.lock or Path("toolchain/lock.json")
    if not lock.is_absolute():
        lock = root / lock
    result = inspect(root, lock)
    if args.text:
        print(f"{result['status']}: root={result['root']} lock={result['lock']}")
        for line in result["errors"]:
            print(f"ERROR: {line}")
        for line in result["warnings"]:
            print(f"WARNING: {line}")
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
