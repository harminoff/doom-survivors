"""Ground-decoration actor table (standard library only).

Single source for gen_decor.py (ZScript classes and editor numbers) and the
room generators. name -> (editor number, sprite, scale). Sprites come from
tools/art/decor_art.py and decor_art2.py.
"""
from __future__ import annotations

DECOR = {
    "tree_dead_a": (30101, "DTRE", 1.3), "tree_dead_b": (30102, "DTRF", 1.3), "tree_dead_c": (30103, "DTRG", 1.3),
    "bush_a": (30104, "DBSH", 1.0), "bush_b": (30105, "DBSI", 1.0),
    "rock_a": (30106, "DRCK", 0.8), "rock_b": (30107, "DRCL", 0.8),
    "flowers_a": (30108, "DFLW", 1.0), "flowers_b": (30109, "DFLX", 1.0),
    "grave": (30110, "DGRV", 1.0),
    "tree_leaf_a": (30111, "DTLA", 1.6), "tree_leaf_b": (30112, "DTLB", 1.6),
    "tree_fruit": (30113, "DTFR", 1.6), "tree_dark": (30114, "DTDK", 1.6),
    "pine": (30115, "DPNE", 1.6), "pine_snow": (30116, "DPNS", 1.6),
    "mushroom_red": (30117, "DMSH", 1.4), "mushroom_orange": (30118, "DMSI", 1.4),
    "snowman": (30119, "DSNW", 1.4), "ice": (30120, "DICE", 1.4),
    "skull": (30121, "DSKL", 1.0), "bones_a": (30122, "DBNE", 1.0), "bones_b": (30123, "DBNF", 1.0),
    "crystal_blue": (30124, "DCRY", 1.4), "crystal_purple": (30125, "DCRZ", 1.4),
    "asteroid_a": (30126, "DAST", 1.6), "asteroid_b": (30127, "DASU", 1.6),
    "planet_a": (30128, "DPLN", 3.0), "planet_b": (30129, "DPLO", 3.0),
    "statue": (30130, "DSTA", 1.5), "column": (30131, "DCOL", 1.5),
    "piano": (30132, "DPNO", 1.5), "table_red": (30133, "DTBL", 1.3), "table_white": (30134, "DTBM", 1.3),
    "books": (30135, "DBKS", 1.0), "chicken": (30136, "DCHK", 0.9), "hay": (30137, "DHAY", 1.3),
    "fence": (30138, "DFNC", 1.6), "milk_can": (30139, "DMLK", 1.4), "lamp": (30140, "DLMP", 1.6),
    "candelabra": (30141, "DCND", 1.5), "seaweed": (30142, "DSWD", 1.4), "urn": (30143, "DURN", 1.2),
    "beaker": (30144, "DBKR", 1.2), "door": (30147, "DDOR", 1.6), "coffin": (30151, "DCFN", 1.6), "merchant": (30148, "DMRC", 1.6),
    "window": (30149, "DWND", 1.6), "cart": (30150, "DCRT", 1.6), "shrub_dark_a": (30145, "DSHD", 1.2), "shrub_dark_b": (30146, "DSHE", 1.2),
}


def ednum(name: str) -> int:
    return DECOR[name][0]
