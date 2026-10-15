"""Generate the third-person player sprite (original pixel art).

A hooded survivor seen from behind (the chase camera always looks at the back),
three frames: PSVRA0 stand, PSVRB0 / PSVRC0 walk. 24x32 art scaled 2x with a
bottom-centre origin. Presentation only.
Run: python tools/art/player_art.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pickup_art import add_grab, outline  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "src/resources/sprites"
CLOAK = (52, 96, 140, 255)
CLOAK_D = (32, 62, 100, 255)
CLOAK_L = (90, 150, 200, 255)
SKIN = (240, 200, 160, 255)
HAIR = (110, 60, 40, 255)
BOOT = (70, 44, 32, 255)
BELT = (200, 150, 60, 255)
SCARF = (220, 50, 60, 255)


def frame(step: int) -> Image.Image:
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lift = 0 if step == 0 else 2
    # legs / boots
    ly = 27
    d.rectangle([8, ly - (lift if step == 1 else 0), 11, 31 - (lift if step == 1 else 0)], fill=BOOT)
    d.rectangle([13, ly - (lift if step == 2 else 0), 16, 31 - (lift if step == 2 else 0)], fill=BOOT)
    # cloak
    d.polygon([(6, 12), (17, 12), (19, 28), (4, 28)], fill=CLOAK)
    d.polygon([(11, 12), (17, 12), (19, 28), (12, 28)], fill=CLOAK_D)
    d.line([(11, 13), (11, 27)], fill=CLOAK_L)
    d.rectangle([5, 19, 18, 20], fill=BELT)
    # arms
    swing = -1 if step == 1 else 1 if step == 2 else 0
    d.rectangle([3, 13 + swing, 5, 21 + swing], fill=CLOAK_D)
    d.rectangle([18, 13 - swing, 20, 21 - swing], fill=CLOAK_D)
    d.rectangle([3, 21 + swing, 5, 22 + swing], fill=SKIN)
    d.rectangle([18, 21 - swing, 20, 22 - swing], fill=SKIN)
    # scarf tail
    d.polygon([(9, 12), (14, 12), (16, 18), (13, 16)], fill=SCARF)
    # hood / head from behind
    d.ellipse([6, 2, 17, 13], fill=CLOAK)
    d.ellipse([8, 4, 15, 11], fill=HAIR)
    d.arc([6, 2, 17, 13], 200, 340, fill=CLOAK_L, width=1)
    return img


def front(step: int) -> Image.Image:
    """The survivor facing the camera (walking backwards): face, scarf and
    buckle show instead of the hood back."""
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lift = 2 if step else 0
    d.rectangle([8, 27 - (lift if step == 1 else 0), 11, 31 - (lift if step == 1 else 0)], fill=BOOT)
    d.rectangle([13, 27 - (lift if step == 2 else 0), 16, 31 - (lift if step == 2 else 0)], fill=BOOT)
    d.polygon([(6, 12), (17, 12), (19, 28), (4, 28)], fill=CLOAK)
    d.polygon([(6, 12), (11, 12), (11, 28), (4, 28)], fill=CLOAK_D)
    d.line([(11, 13), (11, 27)], fill=CLOAK_L)
    d.rectangle([5, 19, 18, 20], fill=BELT)
    d.rectangle([10, 19, 13, 20], fill=(255, 225, 120, 255))      # buckle
    swing = -1 if step == 1 else 1 if step == 2 else 0
    d.rectangle([3, 13 - swing, 5, 21 - swing], fill=CLOAK_D)
    d.rectangle([18, 13 + swing, 20, 21 + swing], fill=CLOAK_D)
    d.rectangle([3, 21 - swing, 5, 22 - swing], fill=SKIN)
    d.rectangle([18, 21 + swing, 20, 22 + swing], fill=SKIN)
    d.polygon([(8, 12), (15, 12), (14, 17), (9, 17)], fill=SCARF)   # scarf across the chest
    d.ellipse([6, 2, 17, 13], fill=CLOAK)                            # hood
    d.ellipse([8, 4, 15, 12], fill=SKIN)                             # face
    d.rectangle([8, 4, 15, 6], fill=HAIR)                            # fringe
    d.point([(10, 8), (13, 8)], fill=(30, 20, 30, 255))              # eyes
    d.line([(10, 10), (13, 10)], fill=(170, 90, 80, 255))            # mouth
    d.arc([6, 2, 17, 13], 200, 340, fill=CLOAK_L, width=1)
    return img


def side(step: int) -> Image.Image:
    """The survivor in profile, facing right; walking left mirrors it in game."""
    img = Image.new("RGBA", (24, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    stride = (0, 3, -3)[step]
    # legs
    d.rectangle([10 + stride, 27, 13 + stride, 31], fill=BOOT)
    d.rectangle([11 - stride, 27 - (1 if step else 0), 14 - stride, 31 - (1 if step else 0)], fill=BOOT)
    # cloak, narrower from the side, with the cape trailing behind (left)
    d.polygon([(9, 12), (16, 12), (17, 28), (7, 28)], fill=CLOAK)
    d.polygon([(9, 12), (6, 14), (3, 27), (7, 28)], fill=CLOAK_D)
    d.rectangle([8, 19, 16, 20], fill=BELT)
    # arm swinging
    d.rectangle([11 - stride // 2, 13, 13 - stride // 2, 21], fill=CLOAK_D)
    d.rectangle([11 - stride // 2, 21, 13 - stride // 2, 22], fill=SKIN)
    d.polygon([(13, 12), (15, 12), (15, 17)], fill=SCARF)
    # head in profile: hood, face, nose
    d.ellipse([7, 2, 17, 13], fill=CLOAK)
    d.ellipse([11, 4, 17, 11], fill=SKIN)
    d.rectangle([17, 7, 18, 8], fill=SKIN)                       # nose
    d.point([(15, 6)], fill=(30, 20, 30, 255))                    # eye
    d.rectangle([8, 3, 14, 6], fill=HAIR)
    return img


def fall(angle: float) -> Image.Image:
    """The standing frame tipped backwards about the feet; angle 90 = flat."""
    base = frame(0)
    canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    canvas.paste(base, (12, 24), base)          # feet end up at (24, 56)
    rotated = canvas.rotate(-angle, resample=Image.NEAREST, center=(24, 56))
    return rotated


def main() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    for i, letter in enumerate("ABC"):
        img = outline(front(i)).resize((48, 64), Image.NEAREST)
        path = SPRITES / f"PSVF{letter}0.png"
        img.save(path, optimize=True)
        add_grab(path, img.width // 2, img.height)
    for i, letter in enumerate("ABC"):
        img = outline(side(i)).resize((48, 64), Image.NEAREST)
        path = SPRITES / f"PSVS{letter}0.png"
        img.save(path, optimize=True)
        add_grab(path, img.width // 2, img.height)
    for i, angle in enumerate((28, 58, 82, 90)):
        img = outline(fall(angle))
        img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        path = SPRITES / f"PSVD{'ABCD'[i]}0.png"
        img.save(path, optimize=True)
        add_grab(path, 48, 112)
    for i, letter in enumerate("ABC"):
        img = outline(frame(i))
        img = img.resize((img.width * 2, img.height * 2), Image.NEAREST)
        path = SPRITES / f"PSVR{letter}0.png"
        img.save(path, optimize=True)
        add_grab(path, img.width // 2, img.height)
    print("wrote player sprites")


if __name__ == "__main__":
    main()
