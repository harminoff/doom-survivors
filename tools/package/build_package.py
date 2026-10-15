"""Build deterministic standalone resource archives."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import tempfile
import zipfile
from pathlib import Path


def _entries(source: Path) -> list[tuple[str, Path]]:
    source = source.resolve()
    if not source.is_dir():
        raise ValueError(f"source is not a directory: {source}")
    found: list[tuple[str, Path]] = []
    names: set[str] = set()
    for path in source.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"symlinks are not allowed: {path}")
        if not path.is_file():
            continue
        relative = path.relative_to(source).as_posix()
        _validate_name(relative, names)
        found.append((relative, path))
    return sorted(found, key=lambda item: item[0])


def _validate_name(relative: str, names: set[str]) -> None:
    """Reject names that would collide on a case-insensitive resource filesystem."""
    key = relative.casefold()
    if key in names:
        raise ValueError(f"case-insensitive duplicate resource name: {relative}")
    names.add(key)


def build_package(source: Path, output: Path) -> dict[str, object]:
    """Pack *source* into a deterministic ZIP/IPK3 at *output* atomically."""
    source = Path(source).resolve()
    output = Path(output).resolve()
    try:
        output.relative_to(source)
    except ValueError:
        pass
    else:
        raise ValueError(f"output must be outside source: {output}")
    entries = _entries(source)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(prefix=f".{output.name}.", suffix=".tmp", dir=output.parent, delete=False) as handle:
            temporary = Path(handle.name)
        with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
            for name, path in entries:
                info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_STORED
                info.create_system = 0
                info.create_version = 20
                info.extract_version = 20
                info.external_attr = 0o100644 << 16
                info.flag_bits = 0x800
                archive.writestr(info, path.read_bytes())
        os.replace(temporary, output)
        temporary = None
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    return {"sha256": digest, "entries": [name for name, _ in entries]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(argv)
    try:
        result = build_package(args.source, args.output)
    except (OSError, ValueError, zipfile.BadZipFile) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}))
        return 1
    print(json.dumps({"status": "PASS", **result}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
