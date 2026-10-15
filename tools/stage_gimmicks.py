"""Stage gimmick data (standard library only): stage items placed on the map
and trap plates, from the Vampire Survivors wiki "Stage items" sections.

Positions are in "tilesets" (the wiki's unit) from the start; one tileset is
TILESET map units here (an approximation). Directions: N is +y, E is +x.
Rows are (item name, dx, dy, chance %). Hidden Yellow Sign items are not
built. Used by tools/gen_gimmicks.py.
"""
from __future__ import annotations

TILESET = 700

# slug -> list of (item display name, dx tilesets, dy tilesets, chance percent)
ITEMS = {
    "mad-forest": [
        ("Skull O'Maniac", -4.5, 4.5, 100), ("Hollow Heart", 0, 4.5, 100),
        ("Spinach", 3, 2, 100), ("Spinach", 5, 2, 30), ("Spinach", 4, -2, 20), ("Spinach", 6, -2, 10),
        ("Pummarola", 0, -5, 100),
        ("Clover", -4, -3, 100), ("Clover", -2, -4, 30), ("Clover", -4, -4, 20), ("Clover", -5, -3, 10),
    ],
    "inlaid-library": [
        ("Empty Tome", -5, 0, 100), ("Empty Tome", -6, 0, 40), ("Empty Tome", -7, 0, 30), ("Empty Tome", -8, 0, 20),
        ("Stone Mask", 5, 0, 100),
    ],
    "dairy-plant": [
        ("Attractorb", -3, 3, 100), ("Armor", 1.5, 1.5, 100), ("Wings", -1.5, -1.5, 100),
        ("Candelabrador", 3, -3, 100),
        ("Silver Ring", 0, 7, 100), ("Metaglio Right", 7, 0, 100),
        ("Gold Ring", 0, -7, 100), ("Metaglio Left", -7, 0, 100),
    ],
    "gallo-tower": [("Bracer", 0, 6, 100), ("Spellbinder", 0, -6, 100),
                    ("Silver Ring", -0.4, 8, 100), ("Metaglio Left", 0.4, 8, 100),
                    ("Gold Ring", -0.4, -8, 100), ("Metaglio Right", 0.4, -8, 100)],
    "cappella-magna": [
        ("Crown", -0.3, 6, 100), ("Tirajisu", 0.3, 6, 100), ("Duplicator", 1.2, -7, 100),
        ("Metaglio Left", -6, 0.3, 100), ("Metaglio Right", -6, -0.3, 100),
        ("Silver Ring", 6, 0.3, 100), ("Gold Ring", 6, -0.3, 100),
    ],
    "bone-zone": [
        ("Silver Ring", 0, 5, 100), ("Metaglio Right", 5, 0, 100),
        ("Gold Ring", 0, -5, 100), ("Metaglio Left", -5, 0, 100),
    ],
    "moongolow": [
        ("Hollow Heart", -5, -5, 100), ("Pummarola", -4.8, -5, 100), ("Armor", -5, -4.7, 100), ("Wings", -4.7, -4.8, 100),
        ("Spinach", 5, 5, 100), ("Bracer", 4.8, 5, 100), ("Spellbinder", 5, 4.7, 100), ("Candelabrador", 4.7, 4.8, 100),
        ("Empty Tome", 5, -5, 100), ("Duplicator", 4.8, -5, 100), ("Tirajisu", 5, -4.7, 100), ("Attractorb", 4.7, -4.8, 100),
        ("Clover", -5, 5, 100), ("Crown", -4.8, 5, 100), ("Stone Mask", -5, 4.7, 100), ("Skull O'Maniac", -4.7, 4.8, 100),
    ],
    "whiteout": [
        ("Glass Fandango", 3.5, 3.5, 100), ("Skull O'Maniac", -3.5, 4, 100),
        ("Spinach", -4.5, -3, 100), ("Wings", 4.5, -4, 100),
    ],
    "space-54": [("Candelabrador", 4, 3, 100), ("Empty Tome", -4, 3.5, 100), ("Phas3r", 0, -6, 100)],
    "the-coop": [("Parm Aegis", 3, 0, 100), ("Fire Wand", 8, 0, 100)],
    "tiny-bridge": [
        ("Wings", -4, 0, 100), ("Vento Sacro", -5, 0, 100), ("Attractorb", 4, 0, 100), ("Lightning Ring", 5, 0, 100),
    ],
    "westwoods": [("Magi-Stone", 1, 0.5, 100)],
    "astral-stair": [("Phiera Der Tuphello", 0, 7, 100), ("Eight The Sparrow", 0, -7, 100)],
    "lycaeum": [("Attractorb", -3.4, 0, 100), ("Spellbinder", 3.4, 0, 100),
                ("Penshin Fatcha", 0, -5, 100), ("Wings", 0.2, -5, 100)],
}

# stages whose stage items are scattered at random free spots (name list)
RANDOM_ITEMS = {
    "mazerella": ["Axe", "Knife", "Clock Lancet", "Laurel", "Armor", "Armor", "Wings", "Wings", "Wings",
                  "Attractorb", "Attractorb", "Attractorb", "Candelabrador", "Candelabrador", "Candelabrador",
                  "Carréllo", "Carréllo", "Arma Dio"],
}

# slug -> list of (x, y, kind, target x, target y) in map units. Kinds:
#   1 random map event of the stage      2 train along a lane (Laborratory)
#   3 button: a crab boss (Lycaeum)      4 zone: the Drowner (Lycaeum, once)
#   5 door: teleports to the target      6 merchant (buys weapons with gold)
#   7 wheel (Spin the Wheel!, Westwoods)
#   10 lever: a swarm bursts in (Laborratory)
PLATES = {
    "boss-rash": [(600, 0, 1, 0, 0), (-600, 0, 1, 0, 0), (0, 700, 1, 0, 0), (0, -700, 1, 0, 0)],
    "gallo-tower": [(700, 9000, 9, 2, 0), (-700, -11000, 8, 3, 0), (-700, -4900, 9, 6, 0), (0, -9000, 1, 0, 0), (0, -4200, 1, 0, 0), (0, 2600, 1, 0, 0), (0, 6000, 1, 0, 0), (0, 9500, 1, 0, 0)],
    # Laborratory: four train levers plus swarm levers (kind 10; the fourth
    # number picks the room's swarm list: 0 central, 1 Danger/Electricity).
    "laborratory": [(2500, 1500, 2, 0, 0), (-2500, 1500, 2, 0, 0), (2500, -1500, 2, 0, 0), (-2500, -1500, 2, 0, 0),
                    (0, 2600, 10, 0, 0), (-3600, 0, 10, 1, 0), (3600, 0, 10, 1, 0)],
    "lycaeum": [(0, -1500, 3, 0, 0), (-2700, -1500, 3, 0, 0), (2700, -1500, 3, 0, 0), (0, -3200, 4, 0, 0)],
    "moongolow": [(900, -700, 6, 0, 0)],
    # coffins (kind 8): the last number is the coffin index (Meta.zs)
    "mad-forest": [(3000, 3000, 8, 0, 0)],
    "westwoods": [(1100, -300, 7, 0, 0)],
    "cappella-magna": [(0, -5000, 8, 4, 0)],
    # relics (kind 9): the fourth number is the relic id (DSRelics in Meta.zs;
    # 1 = Yellow Sign). Positions follow the wiki's directions (approximate).
    "holy-forbidden": [(1500, 0, 9, 1, 0)],
    "inlaid-library": [(-6200, -300, 8, 1, 0), (-2800, 0, 9, 3, 0)],
    "dairy-plant": [(1500, -1500, 8, 2, 0), (1800, 1800, 1, 0, 0), (-1800, -1200, 1, 0, 0), (0, 3300, 1, 0, 0), (3600, 0, 1, 0, 0),
                    (-3800, 400, 1, 0, 0), (2400, -2800, 1, 0, 0), (-2200, -3600, 1, 0, 0), (500, -4800, 1, 0, 0),
                    (0, -2100, 9, 4, 0), (300, -4200, 9, 5, 0)],
    "green-acres": [(2800, 2800, 9, 7, 0)],
    "bone-zone": [(0, -3500, 9, 9, 0)],
    "space-54": [(0, 2800, 9, 10, 0)],
    "eudaimonia-machine": [(1400, 0, 9, 11, 0), (-1400, 0, 9, 12, 0)],
    "whiteout": [(0, -3500, 9, 17, 0)],
    "mazerella": [(3600, 0, 9, 18, 0)],
    "astral-stair": [(0, -9300, 9, 8, 0), (0, 9800, 5, 0, -9500), (0, -9800, 5, 0, 9500), (-1350, 6500, 5, 1350, 2500),
                     (1350, 2500, 5, -1350, 6500), (1350, 6500, 5, -1350, -3000), (-1350, -3000, 5, 1350, 6500)],
}

# slug -> list of (kind, x, y, target x, target y): destructible props.
#   1 stained glass window (explodes in light)  2 dairy cart (launches toward the target)
PROPS = {
    "cappella-magna": [(1, sx * 4600, y, 0, 0) for sx in (-1, 1) for y in (-4500, -2000, 500, 3000, 5000)]
                      + [(1, x, sy * 5200, 0, 0) for sy in (-1, 1) for x in (-1500, 0, 1500)],
    "dairy-plant": [(2, -3600, -5200, 3600, -5200), (2, 3600, 1200, -3600, 1200), (2, -3600, -800, 3600, -800)],
}
