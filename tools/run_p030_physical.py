"""Open the bounded P030 physical-input session through the proven probe host."""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.run_probe import run


if __name__ == "__main__":
    run(
        ROOT / "build/doom-survivors.ipk3",
        600.0,
        False,
        True,
        "P030",
        60,
        1280,
        720,
        map_name="MAP16",
        completion_marker="DS_P030_COMPLETE",
        active_in_background=False,
        vsync=False,
        video_backend=0,
        startup_commands=[
            "+con_notifytime", "0",
            "+set", "ds_p030_mode", "manual",
            "+set", "ds_p030_speed", "1",
            "+set", "ds_p030_telemetry", "0",
        ],
    )
