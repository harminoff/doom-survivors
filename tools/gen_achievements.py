"""Generate src/zscript/gameplay/meta/Achievements.zs: Vampire Survivors'
base-game achievements (wiki) that this port can track, with what each unlocks
(weapons and passives for the level-up draft, PowerUps, characters, stages,
Arcana, gold). Conditions and rewards follow the Vampire Survivors wiki;
where the original needs something not built, a labelled stand-in is used.
Run: python tools/gen_achievements.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "src/zscript/gameplay/catalog/ItemCatalog.zs"
OUT = ROOT / "src/zscript/gameplay/meta/Achievements.zs"

# Condition kinds (a, b, c are ints; s is a text parameter).
LEVEL, STAGE_LEVEL, SURVIVE, STAGE_MINUTE, RANK, SEEN, COUNTER, KILLS_MATCH, COFFIN, \
    CHAR_LEVEL, RELIC, COLLECTION, ALL_EVOS, SURVIVE_EITHER = range(1, 15)
# Reward kinds.
NONE, WEAPON, CHARACTER, STAGE, POWERUP, ARCANA, GOLD = range(7)

# DSCharacters order.
C = {n: i for i, n in enumerate(
    "ANTONIO IMELDA PASQUALINA GENNARO ARCA PORTA LAMA POE CLERICI DOMMARIO KROCHI "
    "CHRISTINE PUGNALA POPPEA MORTACCIO YATTA BIANCA OSOLE ZIASSUNTA AMBROJOE EXDASH "
    "TOASTIE GIOVANNA CONCETTA IGUANA DIVANO SMITH MARRABBIO MINNAH LEDA PEPPINO BOROS "
    "GYORUNTON REDDEATH TROUSER AVATAR SIGMA ROBBERT ZIAPPUNTA TROUBLER SHEMOON COOLIO "
    "SANTA GAZEBO CHULAREH SPACEDUDE BATS ROSE GYORUNTIN SECRETINO SPACEDETTE".split())}
# DSPowerUps order.
P = {n: i for i, n in enumerate(
    "MIGHT ARMOR MAX_HEALTH RECOVERY COOLDOWN AREA SPEED DURATION AMOUNT MOVE MAGNET "
    "LUCK GROWTH GREED CURSE REVIVAL OMNI REROLL SKIP BANISH CHARM DEFANG PRESERVE".split())}
FOREST, LIBRARY, PLANT, TOWER, CAPPELLA, ACRES, BONEZONE, MOLISE, MOONGOLOW, BOSSRASH = range(10)

# The evolutions and unions behind "Evolve X" (500 gold each) and Candybox.
EVOLUTIONS = [
    ("the Whip", "BLOODY_TEAR"), ("the Magic Wand", "HOLY_WAND"), ("the Knife", "THOUSAND_EDGE"),
    ("the Axe", "DEATH_SPIRAL"), ("the Santa Water", "LA_BORRA"), ("the Lightning Ring", "THUNDER_LOOP"),
    ("the King Bible", "UNHOLY_VESPERS"), ("the Cross", "HEAVEN_SWORD"), ("the Fire Wand", "HELLFIRE"),
    ("the Garlic", "SOUL_EATER"), ("the Runetracer", "NO_FUTURE"), ("the Pentagram", "GORGEOUS_MOON"),
    ("Ebony Wings and Peachone", "VANDALIER"), ("Phiera and Eight", "PHIERAGGI"),
    ("the Gatti Amari", "N3_VICIOUS_HUNGER"), ("the Song of Mana", "N3_MANNAJJA"),
    ("the Shadow Pinion", "N3_VALKYRIE_TURNER"), ("Vento Sacro and Bloody Tear", "FUWALAFUWALOO"),
    ("the Bracelet twice", "TRI_BRACELET"),
]


def rows(ids: dict[str, int], collection_size: int) -> list[tuple]:
    """(text, kind, a, b, c, s, reward kind, reward value)."""
    i = lambda name: ids["ID_" + name]  # noqa: E731
    r = [
        # Weapons and passives for the level-up draft.
        ("Reach level 5", LEVEL, 5, 0, 0, "", WEAPON, i("N3_WINGS")),
        ("Reach level 10", LEVEL, 10, 0, 0, "", WEAPON, i("CROWN")),
        ("Survive 1 minute", SURVIVE, 60, -1, 0, "", WEAPON, i("HOLLOW_HEART")),
        ("Survive 5 minutes with Pasqualina", SURVIVE, 300, C["PASQUALINA"], 0, "", WEAPON, i("RUNETRACER")),
        ("Survive 5 minutes with Gennaro", SURVIVE, 300, C["GENNARO"], 0, "", WEAPON, i("PUMMAROLA")),
        ("Survive 10 minutes", SURVIVE, 600, -1, 0, "", WEAPON, i("PEACHONE")),
        ("Survive 10 minutes with Pugnala", SURVIVE, 600, C["PUGNALA"], 0, "", WEAPON, i("PHIERA")),
        ("Survive 15 minutes with Pugnala", SURVIVE, 900, C["PUGNALA"], 0, "", WEAPON, i("EIGHT")),
        ("Survive 15 minutes with Giovanna", SURVIVE, 900, C["GIOVANNA"], 0, "", WEAPON, i("N3_GATTI_AMARI")),
        ("Survive 15 minutes with Poppea", SURVIVE, 900, C["POPPEA"], 0, "", WEAPON, i("N3_SONG_OF_MANA")),
        ("Survive 15 minutes with Concetta", SURVIVE, 900, C["CONCETTA"], 0, "", WEAPON, i("N3_SHADOW_PINION")),
        ("Survive 15 minutes with Zi'Assunta", SURVIVE, 900, C["ZIASSUNTA"], 0, "", WEAPON, i("VENTO_SACRO")),
        ("Survive 20 minutes", SURVIVE, 1200, -1, 0, "", WEAPON, i("PENTAGRAM")),
        ("Survive 20 minutes with Krochi", SURVIVE, 1200, C["KROCHI"], 0, "", WEAPON, i("TIRAJISU")),
        ("Survive 30 minutes with Lama", SURVIVE, 1800, C["LAMA"], 0, "", WEAPON, i("N3_SKULL_O_MANIAC")),
        ("Survive 30 minutes with Iguana or Divano", SURVIVE_EITHER, 1800, C["IGUANA"], C["DIVANO"], "", WEAPON, i("BRACELET")),
        ("Get King Bible to level 4", RANK, i("KING_BIBLE"), 4, i("UNHOLY_VESPERS"), "", WEAPON, i("BRACER")),
        ("Get Santa Water to level 4", RANK, i("SANTA_WATER"), 4, i("LA_BORRA"), "", WEAPON, i("CANDELABRADOR")),
        ("Get Magic Wand to level 7", RANK, i("MAGIC_WAND"), 7, i("HOLY_WAND"), "", WEAPON, i("DUPLICATOR")),
        ("Get Peachone to level 7", RANK, i("PEACHONE"), 7, i("VANDALIER"), "", WEAPON, i("EBONY_WINGS")),
        ("Get Runetracer to level 7", RANK, i("RUNETRACER"), 7, i("NO_FUTURE"), "", WEAPON, i("SPELLBINDER")),
        ("Hold 6 different evolutions at once", COUNTER, 1, 0, 0, "evo6", WEAPON, i("N3_TORRONA_S_BOX")),
        ("Hold 6 different weapons at once", COUNTER, 1, 0, 0, "wpn6", WEAPON, i("EMPTY_TOME")),
        ("Destroy 20 light sources", COUNTER, 20, 0, 0, "lsrc", WEAPON, i("FIRE_WAND")),
        ("Find 5 Floor Chickens", COUNTER, 5, 0, 0, "chk", WEAPON, i("GARLIC")),
        ("Find a Little Clover", COUNTER, 1, 0, 0, "clv", WEAPON, i("CLOVER")),
        ("Find a Vacuum", COUNTER, 1, 0, 0, "vac", WEAPON, i("ATTRACTORB")),
        ("Find an Orologion", COUNTER, 1, 0, 0, "oro", WEAPON, i("N3_CLOCK_LANCET")),
        ("Find a Rosary", COUNTER, 1, 0, 0, "ros", WEAPON, i("CROSS")),
        ("Find a Stone Mask", SEEN, i("N3_STONE_MASK"), 0, 0, "", WEAPON, i("N3_STONE_MASK")),
        ("Defeat 5000 enemies", COUNTER, 5000, 0, 0, "kills", WEAPON, i("LIGHTNING_RING")),
        # Stand-in: the original needs 100000 kills in one run with Queen Sigma (not built).
        ("Defeat 100000 enemies in one run", COUNTER, 100000, 0, 0, "maxkills", WEAPON, i("N3_VICTORY_SWORD")),
        # Stand-in for "See the final fireworks".
        ("Survive the Cappella Magna", STAGE_MINUTE, CAPPELLA, 30, 0, "", WEAPON, i("N3_GREATEST_JUBILEE")),
        ("Discover every standard evolution and union", ALL_EVOS, 0, 0, 0, "", WEAPON, i("N3_CANDYBOX")),
        # Stages.
        ("Reach level 20 in the Mad Forest", STAGE_LEVEL, FOREST, 20, 0, "", STAGE, LIBRARY),
        ("Reach level 40 in the Inlaid Library", STAGE_LEVEL, LIBRARY, 40, 0, "", STAGE, PLANT),
        ("Reach level 60 in the Dairy Plant", STAGE_LEVEL, PLANT, 60, 0, "", STAGE, TOWER),
        ("Reach level 80 in the Gallo Tower", STAGE_LEVEL, TOWER, 80, 0, "", STAGE, CAPPELLA),
        # Characters.
        ("Survive 20 minutes with at least +10% Curse", COUNTER, 1, 0, 0, "curse20", CHARACTER, C["LAMA"]),
        ("Get Fire Wand to level 4", RANK, i("FIRE_WAND"), 4, i("HELLFIRE"), "", CHARACTER, C["ARCA"]),
        ("Get Lightning Ring to level 4", RANK, i("LIGHTNING_RING"), 4, i("THUNDER_LOOP"), "", CHARACTER, C["PORTA"]),
        ("Get Garlic to level 7", RANK, i("GARLIC"), 7, i("SOUL_EATER"), "", CHARACTER, C["POE"]),
        ("Get Pentagram to level 7", RANK, i("PENTAGRAM"), 7, i("GORGEOUS_MOON"), "", CHARACTER, C["CHRISTINE"]),
        ("Recover a total of 1000 HP", COUNTER, 1000, 0, 0, "heal", CHARACTER, C["CLERICI"]),
        ("Earn 5000 gold in a single run", COUNTER, 5000, 0, 0, "maxgold", CHARACTER, C["DOMMARIO"]),
        ("Defeat a total of 100000 enemies", COUNTER, 100000, 0, 0, "kills", CHARACTER, C["KROCHI"]),
        ("Open the coffin in the Mad Forest", COFFIN, 0, 0, 0, "", CHARACTER, C["PUGNALA"]),
        ("Open the coffin in the Inlaid Library", COFFIN, 1, 0, 0, "", CHARACTER, C["GIOVANNA"]),
        ("Open the coffin in the Dairy Plant", COFFIN, 2, 0, 0, "", CHARACTER, C["POPPEA"]),
        ("Open the coffin in the Gallo Tower", COFFIN, 3, 0, 0, "", CHARACTER, C["CONCETTA"]),
        ("Open the coffin in the Cappella Magna", COFFIN, 4, 0, 0, "", CHARACTER, C["ZIASSUNTA"]),
        ("Defeat 3000 Skeletons", KILLS_MATCH, 3000, 0, 0, "SKELETON", CHARACTER, C["MORTACCIO"]),
        ("Defeat 3000 Lion Heads", KILLS_MATCH, 3000, 0, 0, "BUER", CHARACTER, C["YATTA"]),
        ("Defeat 3000 Milk Elementals", KILLS_MATCH, 3000, 0, 0, "MILK", CHARACTER, C["BIANCA"]),
        ("Defeat 3000 Dragon Shrimps", KILLS_MATCH, 3000, 0, 0, "XLDRAGON", CHARACTER, C["OSOLE"]),
        ("Defeat 6000 Stage Killers", KILLS_MATCH, 6000, 0, 0, "STAGEKILLER", CHARACTER, C["AMBROJOE"]),
        ("Obtain the Infinite Corridor", SEEN, i("N3_INFINITE_CORRIDOR"), 0, 0, "", CHARACTER, C["IGUANA"]),
        ("Obtain the Crimson Shroud", SEEN, i("N3_CRIMSON_SHROUD"), 0, 0, "", CHARACTER, C["DIVANO"]),
        ("Survive 20 minutes in Whiteout", STAGE_MINUTE, 10, 20, 0, "", CHARACTER, C["SHEMOON"]),
        ("Survive 20 minutes in The Lycaeum", STAGE_MINUTE, 11, 20, 0, "", CHARACTER, C["COOLIO"]),
        ("Survive 20 minutes in The Coop", STAGE_MINUTE, 12, 20, 0, "", CHARACTER, C["GAZEBO"]),
        ("Survive 20 minutes in Space 54", STAGE_MINUTE, 13, 20, 0, "", CHARACTER, C["SPACEDUDE"]),
        ("Survive 20 minutes in Laborratory", STAGE_MINUTE, 14, 20, 0, "", CHARACTER, C["SANTA"]),
        ("Survive 20 minutes in Westwoods", STAGE_MINUTE, 15, 20, 0, "", CHARACTER, C["CHULAREH"]),
        ("Evolve Pako Battiliar", SEEN, i("N3_MAZO_FAMILIAR"), 0, 0, "", CHARACTER, C["ROBBERT"]),
        ("Evolve Ammo Appalate", SEEN, i("N3_GUNASTROPHE"), 0, 0, "", CHARACTER, C["ZIAPPUNTA"]),
        ("Evolve Unearthly Bolt", SEEN, i("N3_SPIRIT_DISTURBANCE"), 0, 0, "", CHARACTER, C["TROUBLER"]),
        ("Complete the Collection", COLLECTION, collection_size, 0, 0, "", CHARACTER, C["SIGMA"]),
        # PowerUps.
        ("Get Torrona's Box to level 9", RANK, i("N3_TORRONA_S_BOX"), 9, 0, "", POWERUP, P["OMNI"]),
    ]
    for who in ("MORTACCIO", "YATTA", "BIANCA", "OSOLE", "AMBROJOE"):
        name = {"YATTA": "Yatta Cavallo", "BIANCA": "Bianca Ramba", "OSOLE": "O'Sole Meeo",
                "AMBROJOE": "Sir Ambrojoe"}.get(who, who.title())
        r.append((f"Reach level 80 with {name}", CHAR_LEVEL, C[who], 80, 0, "", POWERUP, P["REROLL"]))
    for stage, minutes, name in ((MOLISE, 15, "Il Molise"), (MOONGOLOW, 15, "Moongolow"),
                                 (ACRES, 30, "Green Acres"), (BONEZONE, 30, "The Bone Zone"),
                                 (BOSSRASH, 15, "Boss Rash")):
        r.append((f"Survive {minutes} minutes in {name}", STAGE_MINUTE, stage, minutes, 0, "", POWERUP, P["SKIP"]))
    for n in (60, 70, 80, 90, 100):
        r.append((f"Fill {n} entries in the Collection", COLLECTION, n, 0, 0, "", POWERUP, P["BANISH"]))
    # Arcana (same rules as DSUnlocks.ArcanaUnlocked).
    arcana_char = [(1, "PUGNALA"), (2, "DOMMARIO"), (3, "PORTA"), (4, "KROCHI"), (5, "GIOVANNA"),
                   (7, "GENNARO"), (9, "CLERICI"), (10, "ANTONIO"), (11, "IMELDA"), (13, "CHRISTINE"),
                   (14, "PASQUALINA"), (16, "LAMA"), (17, "POPPEA"), (18, "CONCETTA"), (19, "ARCA"), (21, "POE")]
    for n, who in arcana_char:
        r.append((f"Reach level 50 with {who.title()}", CHAR_LEVEL, C[who], 50, 0, "", ARCANA, n))
    r.append(("Find the Randomazzo", RELIC, 2, 0, 0, "", ARCANA, 6))
    for n, stage, name in ((8, FOREST, "the Mad Forest"), (12, TOWER, "the Gallo Tower"),
                           (15, LIBRARY, "the Inlaid Library"), (20, PLANT, "the Dairy Plant")):
        r.append((f"Reach minute 31 in {name}", STAGE_MINUTE, stage, 31, 0, "", ARCANA, n))
    r.append(("Defeat the final enemy in the Cappella Magna", COUNTER, 1, 0, 0, "ender", ARCANA, 22))
    r.append(("Find the Yellow Sign", RELIC, 1, 0, 0, "", NONE, 0))
    r.append(("Find the Grim Grimoire", RELIC, 3, 0, 0, "", NONE, 0))
    r.append(("Find the Milky Way Map", RELIC, 4, 0, 0, "", NONE, 0))
    r.append(("Find the Ars Gouda", RELIC, 5, 0, 0, "", NONE, 0))
    r.append(("Find the Sorceress' Tears", RELIC, 6, 0, 0, "", NONE, 0))
    r.append(("Find the Magic Banger", RELIC, 7, 0, 0, "", NONE, 0))
    r.append(("Find the Trisection", RELIC, 8, 0, 0, "", NONE, 0))
    r.append(("Find the Forbidden Scrolls of Morbane", RELIC, 9, 0, 0, "", NONE, 0))
    r.append(("Find the Brave Story", RELIC, 10, 0, 0, "", NONE, 0))
    r.append(("Find Gracia's Mirror", RELIC, 11, 0, 0, "", NONE, 0))
    r.append(("Find the Glass Vizard", RELIC, 14, 0, 0, "", NONE, 0))
    r.append(("Find the Apoplexy", RELIC, 16, 0, 0, "", NONE, 0))
    r.append(("Find the Antidote", RELIC, 17, 0, 0, "", NONE, 0))
    r.append(("Find the Wax Fetish", RELIC, 18, 0, 0, "", NONE, 0))
    r.append(("Find the Seventh Trumpet", RELIC, 12, 0, 0, "", NONE, 0))
    # Gold prizes.
    for label, evo in EVOLUTIONS:
        verb = "Unite" if " and " in label else "Evolve"
        r.append((f"{verb} {label}", SEEN, i(evo), 0, 0, "", GOLD, 500))
    return r


def main() -> None:
    text = CATALOG.read_text(encoding="utf-8")
    ids = {k: int(v) for k, v in re.findall(r"const (ID_\w+) = (\d+);", text)}
    body = text[text.index("static void AllIds"):text.index("static void DraftableIds")]
    data = rows(ids, body.count("ids.Push("))
    evo_ids = [ids["ID_" + e] for _, e in EVOLUTIONS]

    def ints(col: int) -> str:
        return ", ".join(str(row[col]) for row in data)

    def strs(col: int) -> str:
        return ", ".join('"' + row[col].replace('"', "'") + '"' for row in data)

    OUT.write_text(f"""// GENERATED by tools/gen_achievements.py. Do not edit.
// Vampire Survivors' base-game achievements (wiki) this port can track, with what
// each unlocks. Kinds and rewards are documented in the generator.
class DSAchievementData
{{
    const COUNT = {len(data)};
    static const String TEXT[] = {{ {strs(0)} }};
    static const int KIND[] = {{ {ints(1)} }};
    static const int A[] = {{ {ints(2)} }};
    static const int B[] = {{ {ints(3)} }};
    static const int C[] = {{ {ints(4)} }};
    static const String S[] = {{ {strs(5)} }};
    static const int REWARD_KIND[] = {{ {ints(6)} }};
    static const int REWARD[] = {{ {ints(7)} }};
    // Standard evolutions and unions (Candybox needs all of them).
    static const int EVOLUTIONS[] = {{ {", ".join(map(str, evo_ids))} }};
}}
""", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(data)} achievements")


if __name__ == "__main__":
    main()
