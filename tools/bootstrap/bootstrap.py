"""Install the locked portable toolchain into this project; never update the lock."""
from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import subprocess
import sys
import urllib.request
import venv
import zipfile
from pathlib import Path, PurePosixPath

ROOT = Path(__file__).resolve().parents[2]


def project_path(root: Path, value: str) -> Path:
    path = (root / value).resolve()
    if Path(value).is_absolute() or not path.is_relative_to(root) or path == root:
        raise ValueError(f"Unsafe project path: {value}")
    return path


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def install(root: Path, lock: dict, offline: bool) -> None:
    if lock["schema_version"] != 1:
        raise ValueError("Unsupported lock schema")
    if platform.system() != "Windows" or platform.machine().lower() not in ("amd64", "x86_64"):
        raise ValueError("This locked artifact supports Windows x64 only")
    if platform.python_version() != lock["python"]["version"]:
        raise ValueError(f"Use Python {lock['python']['version']}; found {platform.python_version()}")
    engine = lock["uzdoom"]
    asset = engine["asset"]
    if asset["publisher_sha256"] != asset["observed_sha256"]:
        raise ValueError("Publisher and observed archive digests disagree")
    archive = project_path(root, asset["download_path"])
    executable = project_path(root, engine["executable"]["path"])
    runtime = executable.parent
    if not archive.exists() and not executable.exists():
        if offline:
            raise ValueError(f"Offline prerequisite absent: {archive}")
        expected_url = f"https://github.com/UZDoom/UZDoom/releases/download/{engine['version']}/{asset['name']}"
        if asset["url"] != expected_url:
            raise ValueError("Runtime URL does not match the pinned official release")
        archive.parent.mkdir(parents=True, exist_ok=True)
        pending = archive.with_suffix(".partial")
        if pending.exists():
            raise ValueError(f"Preserved incomplete download requires inspection: {pending}")
        request = urllib.request.Request(asset["url"], headers={"User-Agent": "DoomSurvivors-Bootstrap"})
        with urllib.request.urlopen(request, timeout=120) as response, pending.open("xb") as stream:
            shutil.copyfileobj(response, stream)
        if sha256(pending) != asset["publisher_sha256"]:
            raise ValueError(f"Downloaded archive digest mismatch; preserved {pending}")
        pending.rename(archive)
    if archive.exists() and sha256(archive) != asset["publisher_sha256"]:
        raise ValueError(f"Cached archive digest mismatch: {archive}")
    if not executable.exists():
        if runtime.exists() and any(runtime.iterdir()):
            raise ValueError(f"Refusing to overwrite incomplete runtime: {runtime}")
        with zipfile.ZipFile(archive) as package:
            for entry in package.infolist():
                path = PurePosixPath(entry.filename.replace("\\", "/"))
                if path.is_absolute() or ".." in path.parts or ":" in entry.filename:
                    raise ValueError(f"Unsafe archive entry: {entry.filename}")
                if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError(f"Archive symlink is unsupported: {entry.filename}")
                if not (runtime / str(path)).resolve().is_relative_to(runtime):
                    raise ValueError(f"Archive entry escapes runtime: {entry.filename}")
            package.extractall(runtime)
    for record in [engine["executable"], *engine["support_files"]]:
        path = project_path(root, record["path"])
        if not path.is_file() or sha256(path) != record["sha256"]:
            raise ValueError(f"Required runtime file absent or modified: {path}")
    source = engine["source"]
    source_path = project_path(root, source["path"])
    if not source_path.exists():
        if offline:
            raise ValueError(f"Offline prerequisite absent: {source_path}")
        if source["url"] != "https://github.com/UZDoom/UZDoom.git":
            raise ValueError("Source URL is not the official UZDoom repository")
        source_path.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(["git", "clone", "--depth", "1", "--branch", source["tag"],
                        "--single-branch", source["url"], str(source_path)], check=True, timeout=300)
    head = subprocess.check_output(["git", "-C", str(source_path), "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output(["git", "-C", str(source_path), "status", "--porcelain"], text=True).strip()
    if head != source["commit"] or dirty:
        raise ValueError("Pinned source is modified or its commit differs; preserving checkout")
    environment = project_path(root, lock["python"]["venv_path"])
    if not environment.exists():
        venv.EnvBuilder(with_pip=False).create(environment)
    interpreter = environment / "Scripts" / "python.exe"
    version = subprocess.check_output([str(interpreter), "-c", "import platform; print(platform.python_version())"], text=True).strip()
    if version != lock["python"]["version"]:
        raise ValueError(f"Virtual environment version differs: {version}")
    print(f"PASS: locked UZDoom {engine['version']}, source {head}, Python {version}")
    print(f"Runtime: {executable}")
    print("No global settings or lock values changed. Runtime gameplay acceptance is separate.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--offline", action="store_true", help="use existing source and cached archive; no network")
    args = parser.parse_args()
    try:
        root = args.root.resolve()
        lock = json.loads((root / "toolchain/lock.json").read_text(encoding="utf-8"))
        install(root, lock, args.offline)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError, zipfile.BadZipFile) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
