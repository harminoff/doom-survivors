"""Every floor pickup's effect branch in MFApplyItem must be reachable.

A sound-only `else if (kind == ...)` line earlier in the same chain once
swallowed the Rosary, Orologion and Vacuum effects without any error.
"""
import re
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "src/zscript/gameplay/slice/SliceMadForest.zs"


def apply_item_body() -> str:
    text = SOURCE.read_text(encoding="utf-8")
    start = text.index("void MFApplyItem(")
    end = text.index("\n    }\n", start)
    return text[start:end]


def test_each_pickup_kind_has_one_branch_in_the_chain():
    # Branches sit at method-body indentation; a plain `if` starts a new chain.
    chains: list[list[str]] = []
    for word, kind in re.findall(r"^        (else if|if) \(kind == (MF_ITEM_\w+)", apply_item_body(), re.M):
        if word == "if" or not chains:
            chains.append([])
        chains[-1].append(kind)
    repeated = sorted({kind for chain in chains for kind in chain if chain.count(kind) > 1})
    assert not repeated, f"kinds tested twice in one MFApplyItem chain (later branch unreachable): {repeated}"


def test_every_dropped_pickup_has_an_effect():
    body = apply_item_body()
    for kind in ("COIN", "COIN_BAG", "RICH_BAG", "CHICKEN", "ROSARY", "OROLOGION", "VACUUM",
                 "LITTLE_CLOVER", "NDUJA", "GILDED_CLOVER", "REROLLO", "SORBETTO"):
        assert f"MF_ITEM_{kind}" in body, kind
