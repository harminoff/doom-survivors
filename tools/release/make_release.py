"""Build the Windows release: a portable game folder with DoomSurvivors.exe, zipped.

    python tools/release/make_release.py 0.1.0

Produces in dist/:
  DoomSurvivors-<version>-win64.zip   the game: DoomSurvivors.exe (launcher), doom-survivors.ipk3,
                                      engine/ (UZDoom, GPL-3.0), README.txt, LICENSE.txt, THIRD_PARTY.txt
  doom-survivors-<version>.ipk3       the game data on its own (one IWAD; run it with any
                                      UZDoom 5.x: uzdoom -iwad doom-survivors.ipk3)
Needs the pinned UZDoom runtime (python tools/bootstrap/bootstrap.py) and, for the icon,
Pillow (optional). The launcher is compiled with the C# compiler of the .NET Framework,
which ships with Windows.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIST = ROOT / "dist"
LAUNCHER_SRC = Path(__file__).with_name("launcher") / "DoomSurvivors.cs"
ICON_SOURCE = ROOT / "src/resources/graphics/CHP00.png"
CSC = Path(r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe")
SKIP_ENGINE_FILES = {"updater.exe"}   # the game is versioned by its own releases

README_TXT = """Doom Survivors {version}
=====================

A first-person survivors-style action roguelite (in the style of Vampire Survivors)
running on the UZDoom engine. Fan project, not affiliated with or endorsed by poncle.

Play: double-click DoomSurvivors.exe.
Controls: WASD to move, mouse to look, Esc for the menu. Weapons fire on their own.
Your settings and progress are kept in the "userdata" folder next to the exe.

License: the game (doom-survivors.ipk3 and DoomSurvivors.exe) is public domain (CC0 1.0,
see LICENSE.txt). The engine in engine/ is UZDoom, GPL-3.0 (see THIRD_PARTY.txt).

Source, issues and updates: https://github.com/harminoff/doom-survivors
"""

THIRD_PARTY_TXT = """Third-party software
====================

engine/ is UZDoom {engine_version}, licensed under the GNU General Public License v3.0
(engine/licenses.zip holds the full license texts of UZDoom and its components).
Corresponding source code: {source_url} at commit {commit}
  https://github.com/UZDoom/UZDoom/tree/{commit}

The game data (doom-survivors.ipk3) and the launcher are the Doom Survivors project,
dedicated to the public domain under CC0 1.0 (LICENSE.txt):
https://github.com/harminoff/doom-survivors
"""


def make_icon(target: Path) -> Path | None:
    try:
        from PIL import Image
    except ImportError:
        print("Pillow not installed: the launcher gets no icon")
        return None
    im = Image.open(ICON_SOURCE).convert("RGBA")
    side = max(im.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    big = square.resize((256, 256), Image.NEAREST)
    big.save(target, sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    return target


def main() -> int:
    version = sys.argv[1] if len(sys.argv) > 1 else "dev"
    lock = json.loads((ROOT / "toolchain/lock.json").read_text(encoding="utf-8"))
    engine_cfg = lock["uzdoom"]
    runtime = ROOT / Path(engine_cfg["executable"]["path"]).parent
    if not (runtime / "uzdoom.exe").is_file():
        print(f"UZDoom runtime missing at {runtime}; run python tools/bootstrap/bootstrap.py first")
        return 1
    if not CSC.is_file():
        print(f"C# compiler not found at {CSC}")
        return 1

    print("building the game package...")
    subprocess.run([sys.executable, str(ROOT / "tools/build.py"), "--stages"], cwd=ROOT, check=True,
                   stdout=subprocess.DEVNULL)
    package = ROOT / "build/doom-survivors.ipk3"

    name = f"DoomSurvivors-{version}-win64"
    folder = DIST / name
    if folder.exists():
        shutil.rmtree(folder)
    (folder / "engine").mkdir(parents=True)
    for item in runtime.iterdir():
        if item.name in SKIP_ENGINE_FILES:
            continue
        if item.is_dir():
            shutil.copytree(item, folder / "engine" / item.name)
        else:
            shutil.copy2(item, folder / "engine" / item.name)
    shutil.copy2(package, folder / "doom-survivors.ipk3")
    (folder / "README.txt").write_text(README_TXT.format(version=version), encoding="utf-8")
    shutil.copy2(ROOT / "LICENSE", folder / "LICENSE.txt")
    src = engine_cfg["source"]
    (folder / "THIRD_PARTY.txt").write_text(THIRD_PARTY_TXT.format(
        engine_version=engine_cfg["version"], source_url=src["url"], commit=src["commit"]), encoding="utf-8")

    icon = make_icon(DIST / "DoomSurvivors.ico")
    cmd = [str(CSC), "/nologo", "/target:winexe", "/optimize+", f"/out:{folder / 'DoomSurvivors.exe'}",
           "/r:System.Windows.Forms.dll"]
    if icon:
        cmd.append(f"/win32icon:{icon}")
    cmd.append(str(LAUNCHER_SRC))
    subprocess.run(cmd, check=True)

    zip_path = DIST / f"{name}.zip"
    zip_path.unlink(missing_ok=True)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for f in sorted(folder.rglob("*")):
            if f.is_file():
                z.write(f, Path(name) / f.relative_to(folder))
    ipk3 = DIST / f"doom-survivors-{version}.ipk3"
    shutil.copy2(package, ipk3)
    print(f"{zip_path} ({zip_path.stat().st_size / 1e6:.1f} MB)")
    print(f"{ipk3} ({ipk3.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
