"""Generate src/zscript/gameplay/stages/StageTables.zs from the stage data.

Inputs per stage: data/stages/<stage>.json and data/enemies/<stage>-enemies.json
(wiki approximations; see each file's sources). Stages without data files are
skipped. Enemy types are global across stages (the union of every stage's
enemy file, first definition wins), so a type id means the same enemy
everywhere; waves, bosses and events are per stage.

Unit conversion only:
- speed: the wiki's Pipeestrello speed 140 equals 2.0 logical units per tic
  (the player moves 3.0), so speed_milli_per_tic = min(speed * 2000 / 140, 4500);
- hp/power/xp: wiki values x 1000 (milli-units);
- seconds: x 35 tics.
Run: python tools/gen_stages.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from enemy_traits import TRAITS  # noqa: E402
OUT = ROOT / "src/zscript/gameplay/stages/StageTables.zs"
# (data slug, id, name, map, spawn clamp x, spawn clamp y, stage-select blurb).
# The list position is the stage index and episode number; it never shifts
# when a stage's data is missing (that stage is just unavailable).
STAGES = [
    ("mad-forest", "FOREST", "Mad Forest", "MAP16", 0, 0,
     "Open forest with bats, ghosts and flower walls."),
    ("inlaid-library", "LIBRARY", "Inlaid Library", "MAP30", 0, 820,
     "A long hall of bookcases, attacked from both ends."),
    ("dairy-plant", "PLANT", "Dairy Plant", "MAP31", 0, 0,
     "Farmland with barns and fences."),
    ("gallo-tower", "TOWER", "Gallo Tower", "MAP32", 820, 0,
     "A tall hall, attacked from above and below."),
    ("cappella-magna", "CAPPELLA", "Cappella Magna", "MAP33", 0, 0,
     "Cathedral grounds. The fifth stage."),
    ("green-acres", "ACRES", "Green Acres", "MAP34", 0, 0,
     "Challenge: waves from every stage, +50% enemy health."),
    ("bone-zone", "BONEZONE", "The Bone Zone", "MAP35", 0, 0,
     "Challenge: no item drops, enemies grow stronger."),
    ("il-molise", "MOLISE", "Il Molise", "MAP36", 0, 0,
     "Bonus 15:00: enemies don't move."),
    ("moongolow", "MOONGOLOW", "Moongolow", "MAP37", 0, 0,
     "Bonus 15:00 under the moon."),
    ("boss-rash", "BOSSRASH", "Boss Rash", "MAP38", 0, 0,
     "Challenge 15:00: bosses from every stage, +50% enemy health."),
    ("whiteout", "WHITEOUT", "Whiteout", "MAP39", 0, 0,
     "Bonus 20:00: a snowbound glacier."),
    ("lycaeum", "LYCAEUM", "The Lycaeum", "MAP40", 0, 0,
     "Bonus 20:00: a sunken library."),
    ("the-coop", "COOP", "The Coop", "MAP41", 0, 900,
     "Bonus 20:00: a long farm strip, -65% XP."),
    ("space-54", "SPACE54", "Space 54", "MAP42", 0, 0,
     "Bonus 20:00: slimes in space."),
    ("laborratory", "LABORRATORY", "Laborratory", "MAP43", 0, 0,
     "Challenge 20:00: a laboratory complex."),
    ("westwoods", "WESTWOODS", "Westwoods", "MAP44", 0, 0,
     "Challenge 20:00: a gambling forest."),
    ("bat-country", "BATCOUNTRY", "Bat Country", "MAP45", 0, 0,
     "Challenge 20:00: bats that grow stronger, -75% XP."),
    ("astral-stair", "ASTRAL", "Astral Stair", "MAP46", 1400, 0,
     "Challenge 20:00: a starry stairway, enemies grow stronger."),
    ("mazerella", "MAZERELLA", "Mazerella", "MAP47", 0, 0,
     "Challenge 20:00: a walled maze."),
    ("tiny-bridge", "TINYBRIDGE", "Tiny Bridge", "MAP48", 0, 300,
     "Challenge 20:00: a very narrow bridge."),
    ("carlo-cart", "CARLOCART", "Carlo Cart", "MAP49", 0, 900,
     "Bonus 15:00: the track keeps scrolling; you can't stop."),
    ("room-1665", "ROOM1665", "Room 1665", "MAP50", 900, 0,
     "Hidden 30:00: enemy health grows with your level."),
    ("holy-forbidden", "HOLYFORBIDDEN", "Holy Forbidden", "MAP51", 0, 0,
     "Hidden 2:00: a forbidden hall. Survive the short rush."),
    ("eudaimonia-machine", "EUDAIMONIA", "Eudaimonia Machine", "MAP52", 0, 0,
     "Endurance 99:00: a machine that never stops."),
    ("the-depths", "DEPTHS", "The Depths", "MAP53", 0, 0,
     "Roguelike: take the Amulet from the bottom floor and climb back out."),
]

# Presentation archetype per enemy (sprite only; never gameplay). Numbers
# follow tools/art/enemy_art.py ARCHETYPES (1 bat ... 20 blob). The first
# rule whose keyword appears in "ID NAME" (upper case) wins.
ARCHETYPE_RULES = [
    (10, ("XLDEATH", "REAPER", "TRAINEE", "STALKER", "DROWNER", "MADDENER", "TRICKSTER",
          "ENDER", "BLINDER", "STAGEKILLER", "DEATH")),
    (3, ("SKELE", "SKULL", "SKULO", "SKETAMARI", "SCARLETON", "MIRAGELLOS", "BONE", "DULLAHAN", "DULL")),
    (8, ("MUMMY",)),
    (1, ("BAT", "PIPEE", "SQUILL")),
    (11, ("MEDUSA", "JELLY", "EYE", "SLIME", "HEAD")),
    (4, ("GHOST", "ECTO", "POLTER", "SHADE", "SPIRIT", "SIG.RA", "SIGRA", "CURTAIN", "CLOAK",
         "KIZZUNE", "GHOULETTE")),
    (2, ("ZOMBIE", "GHOUL", "ASTRAL GHOUL")),
    (9, ("FLOWER", "VENUS", "GARLIC", "MOSS", "HEMO", "MUSHROU", "PICKLE", "SPINACH", "ONION",
         "VINE", "PLANT", "DANDYBRINE")),
    (14, ("DRAGON", "GALLOTRICE", "COCKATRICE", "HARP", "SNEK", "SERPENT", "SNAKE", "DRAGOGION")),
    (15, ("FISH", "MERMA", "MERMAN", "TRITON", "SEA", "SALMON", "AHUIZOTL", "AWIZOTL", "OLMO",
          "GYORUNTIN", "ICHTHYO", "CRAB", "PINCER", "BUKAVAC", "ENYPNASTYS", "SLUG")),
    (19, ("CHICKEN", "COCK", "CHIK", "DUCK", "RABBIT", "GALLO", "COOP_EGG", "EGG")),
    (17, ("ANGEL", "CHERUB", "THRONE", "ABRAXAS", "VALENTINE")),
    (16, ("DEMON", "DEVIL", "IMP", "BUER", "NESUFERIT", "DARKASSO", "DAIMON", "KALI", "TETRA",
          "TRINACRIA", "SUCCUBUS", "KA'SOS", "R'KASSO")),
    (12, ("WITCH", "MAGE", "MAGIO", "LIBRARIAN", "COUNT", "MADD", "CARDSHARP", "CARD SHARP",
          "GAMBLIN", "GAMBERGAR", "TOLL", "BOUNTY", "HUNTER", "APEX")),
    (13, ("ARMOR", "KNIGHT", "ARCHON", "SWORD", "GUARDIAN", "MASK", "SPADES", "BOT", "ER2000",
          "TDCCC", "GOLDIE")),
    (6, ("WEREWOLF", "PANTHER", "MANTICORE", "CHIMERA", "MIGNO", "TAUR", "TORINO", "LIZARD",
         "MINOTAUR", "BARM", "KAMAITACHI", "MINION")),
    (7, ("MANTIS", "ANT", "INSECT", "SPIDER")),
    (5, ("MUDMAN", "MUD", "ELEMENTAL", "GOLEM", "MELONE", "MILK", "MENTA", "CUBE", "STARDUST")),
    (18, ("BOOK", "PILE", "ANFORA", "DIAMOND", "MIMIC", "BULLET", "RETRO", "COSMIC")),
    (20, ("MOLISANO", "SNOWMAN", "BAMBAMAN", "SPACE")),
]


def family(enemy_id: str, name: str = "") -> int:
    text = f"{enemy_id} {name}".upper()
    for archetype, keys in ARCHETYPE_RULES:
        if any(key in text for key in keys):
            return archetype
    return 20


def variant(enemy_id: str, name: str = "") -> int:
    """Sprite colour variant: 0 normal, 1 elite (red), 2 special (hue-shifted)."""
    if enemy_id.startswith(("BOSS_", "XL")):
        return 3
    text = f"{enemy_id} {name}".upper()
    if any(k in text for k in ("ELITE", "RED", "FLAME", "FIRE", "ROSSO", "BLOOD")):
        return 1
    if any(k in text for k in ("BLUE", "ICE", "MOON", "ASTRAL", "STAR", "GREEN", "GOLD", "SNOW", "MOLISE")):
        return 2
    digits = [c for c in enemy_id if c.isdigit()]
    return {"2": 1, "3": 2, "4": 1, "5": 2}.get(digits[-1], 0) if digits else 0
# Event kinds (runtime MFStartEvent): 1 swarm crossing on a random heading,
# 2 ghost swarm (same motion), 3 flower ring, 4 wall line crossing
# horizontally, 5 short-lived chaser burst, 6 horizontal swarm.
EVENT_KIND = {"bat_swarm": 1, "ghost_swarm": 2, "flower_wall": 3, "medusa_wall": 4,
              "shade_bomb": 5, "skull_swarm": 1, "medusa_swarm": 6,
              # Dairy Plant (approximate shapes): generic swarms cross like bat
              # swarms, the Jellyfish Wall closes in as a ring, Jellyfish
              # Swarms and Minotaur Rushes cross horizontally, Pile Assaults
              # and Stalkers burst in as chasers.
              "swarm": 1, "jellyfish_wall": 3, "jellyfish_swarm": 6, "minotaur_rush": 6,
              "pile_assault": 5, "stalker": 5,
              # Gallo Tower: dragon swarms and shooting stars cross like bat
              # swarms; dragon streams run along the hall.
              "dragon_swarm": 1, "shooting_star": 1, "dragon_stream": 6,
              # Shapes from the wiki's map events (approximate geometry):
              # 7 Monster Dance ring circling the player, 8 Diamond Road, 9
              # Diamond Square, 10 Diamond Maze (stationary blockers), 11
              # Invaders block marching in, 12 a lone boss visit (Drowner,
              # Trickster). Monster Rain falls as a line; the Lycaeum swarms
              # cross horizontally; Westwoods' gemstones form a still ring.
              "monster_dance": 7, "diamond_road": 8, "diamond_square": 9, "diamond_maze": 10,
              "invaders": 11, "drowner": 12, "trickster": 12, "maddener": 12, "monster_rain": 4,
              "medusa_event_unspecified": 6, "gemstone_hits_static": 3,
              # Trap events (no time of their own): only the trap plates start them.
              "poltergeist_roulette": 1, "poltergeist_swarm": 1, "impefinger_swarm": 1,
              "musc_musc_swarm": 1}
DEFAULT_EVENT_ENEMY = {"bat_swarm": "BATSWARM", "ghost_swarm": "GHOSTSWARM", "flower_wall": "FLOWER",
                       "diamond_road": "EX_DIAMOND", "diamond_square": "EX_DIAMOND",
                       "diamond_maze": "EX_DIAMOND", "gemstone_hits_static": "EX_DIAMOND"}
DEFAULT_EVENT_AMOUNT = {"bat_swarm": 50, "ghost_swarm": 20, "flower_wall": 40, "monster_dance": 24,
                        "invaders": 32, "medusa_event_unspecified": 20, "gemstone_hits_static": 30}
DEFAULT_EVENT_SECONDS_BY_KIND = {7: 10, 8: 30, 9: 30, 10: 60, 11: 30, 12: 60}
TRAP_TIC = 0x7FFFFFF
# Hyper and Inverse per stage, from the wiki's stage pages: Hyper adds
# (player speed, enemy speed, projectile speed, gold, luck, enemy health);
# Inverse doubles gold and enemy health, adds +20% Luck and grows enemy
# health / speed every minute by the last two values.
MODES = {
    "FOREST": (0.9, 0.9, 0.25, 0.5, 0, 0, 0.05, 0.005),
    "LIBRARY": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "PLANT": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "TOWER": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "CAPPELLA": (0.6, 0.6, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "ACRES": (0.65, 0.65, 0.15, 0.5, 0.1, 0.5, 0.05, 0.005),
    "BONEZONE": (0.65, 0.65, 0.15, 0.5, 0, 0, 0.05, 0.005),
    "MOLISE": (0.75, 0.75, 0.15, 0.5, 0.2, 0.6, 0.05, 0.005),
    "MOONGOLOW": (0.65, 0.65, 0.15, 0.5, 0.2, 0.6, 0.05, 0.005),
    "BOSSRASH": (0.65, 0.65, 0.15, 0.5, 0.1, 0.5, 0.05, 0.005),
    "WHITEOUT": (0.65, 0.1, 0.15, 0.25, 0, 0, 0.1, 0.3),
    "LYCAEUM": (1.0, 1.0, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "COOP": (0.65, 0.65, 0.15, 0.25, 0, 1, 0.1, 0.3),
    "SPACE54": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "LABORRATORY": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "WESTWOODS": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "BATCOUNTRY": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "ASTRAL": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "MAZERELLA": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "TINYBRIDGE": (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005),
    "CARLOCART": (0.25, 0.25, 0.1, 0.5, 0.1, 0, 0.05, 0.005),
}
MODE_DEFAULT = (0.65, 0.65, 0.15, 0.5, 0.1, 0, 0.05, 0.005)
# Inverse mode's colour tint per stage (the original's), as 0xRRGGBB.
INVERSE_TINT = {
    "FOREST": 0x8888EE, "LIBRARY": 0xFFAAFF, "PLANT": 0xCCFFCC, "TOWER": 0xFF8888, "CAPPELLA": 0xAA88EE,
    "ACRES": 0x88FFFF, "BONEZONE": 0xFFAAAA, "MOLISE": 0xFF8888, "MOONGOLOW": 0xFF6666, "BOSSRASH": 0x8888FF,
    "WHITEOUT": 0xFF5151, "LYCAEUM": 0x5FB6F3, "COOP": 0xFF5151, "SPACE54": 0xFF88FF, "LABORRATORY": 0x5FB6F3,
    "WESTWOODS": 0x8888EE, "BATCOUNTRY": 0xFFFF88, "ASTRAL": 0xFF88FF, "MAZERELLA": 0xFF88FF,
    "TINYBRIDGE": 0xFF8888, "CARLOCART": 0xCCFFCC,
}
DEFAULT_EVENT_SECONDS = {"shade_bomb": 3}


def tics(seconds: float) -> int:
    return max(1, int(round(seconds * 35)))


def event_tic(at: str) -> int:
    minutes, seconds = at.split(":")
    return int(round((int(minutes) * 60 + float(seconds)) * 35))


def num(v, default=0.0):
    return float(v) if isinstance(v, (int, float)) else default


def modifier(stage: dict, key: str) -> int:
    """A normal-mode multiplier from the stage file as milli (1000 = x1)."""
    value = (stage["stage"].get("modifiers_normal_mode") or {}).get(key)
    return int(round(float(value) * 1000)) if isinstance(value, (int, float)) and value > 0 else 1000


# Carlo Cart scroll speed: the wiki gives none; about a third of the
# player's 3.0 units/tic (approximation).
AUTO_SCROLL = {"CARLOCART": 1000}
# Challenge rules the wiki states only in prose for some stages (the stage
# file's stage.modifiers wins when it has the field).
CHALLENGE_FALLBACK = {}
# Light sources per stage, from the wiki's stage pages: spawn chance
# per attempt (%), chance cap after Luck (%), how many may stand at once, and
# the time between spawn attempts (ms). Stages not listed keep 10/50/5/1000.
LIGHT_SOURCES = {
    "FOREST": (10, 50, 10, 1000), "LIBRARY": (7.5, 50, 10, 1000),
    "PLANT": (20, 60, 12, 1000), "TOWER": (7.5, 50, 10, 1000),
    "CAPPELLA": (20, 80, 20, 1000), "ACRES": (10, 50, 10, 1000),
    "BONEZONE": (40, 50, 10, 500), "MOLISE": (30, 60, 10, 1000),
    "MOONGOLOW": (30, 60, 10, 1000), "BOSSRASH": (10, 50, 5, 1000),
    "WHITEOUT": (80, 90, 10, 2000), "LYCAEUM": (80, 90, 16, 2000),
    "COOP": (80, 90, 8, 2000), "SPACE54": (10, 90, 16, 500),
    "LABORRATORY": (20, 60, 12, 1000), "WESTWOODS": (7.5, 50, 12, 1000),
    "BATCOUNTRY": (1, 50, 10, 1000), "ASTRAL": (7, 70, 12, 500),
    "MAZERELLA": (7, 70, 12, 500), "TINYBRIDGE": (7.5, 50, 10, 1000),
    "CARLOCART": (20, 60, 12, 1000), "ROOM1665": (50, 80, 20, 1000),
    "HOLYFORBIDDEN": (100, 100, 100, 100000), "EUDAIMONIA": (20, 80, 20, 1000),
}


def challenge(sid: str, stage: dict, key: str) -> int:
    """A per-minute growth (milli) or flag (1/0) for a challenge stage."""
    rules = dict(CHALLENGE_FALLBACK.get(sid, {}))
    rules.update((stage["stage"].get("modifiers") or {}))
    value = rules.get(key)
    if isinstance(value, bool):
        return 1 if value else 0
    return int(round(float(value) * 1000)) if isinstance(value, (int, float)) else 0


def type_table(name: str, const: str, rtype: str, values: list, default) -> str:
    """Per-enemy-type values as a static array indexed by type (index 0 is
    unused). If-chains over hundreds of types exceed the ZScript VM register
    limit."""
    body = ", ".join(values) or str(default)
    return (f"    static const {rtype} {const}[] = {{ {body} }};\n"
            f"    static {rtype} {name}(int type)\n    {{\n"
            f"        return type > 0 && type < {len(values)} ? DSStage.{const}[type] : {default};\n"
            f"    }}\n")


def switch(name: str, args: str, cases: list[tuple[str, int]], default: int = 0) -> str:
    body = "".join(f"        if ({cond}) return {v};\n" for cond, v in cases)
    return f"    static int {name}({args})\n    {{\n{body}        return {default};\n    }}\n"


def main() -> None:
    loaded = []
    for position, (slug, sid, _name, _map, _cx, _cy, _blurb) in enumerate(STAGES):
        stage_path = ROOT / f"data/stages/{slug}.json"
        enemy_path = ROOT / f"data/enemies/{slug}-enemies.json"
        if not stage_path.exists() or not enemy_path.exists():
            continue
        stage = json.loads(stage_path.read_text(encoding="utf-8"))
        raw = json.loads(enemy_path.read_text(encoding="utf-8"))["enemies"]
        enemies = dict(raw) if isinstance(raw, list) else raw
        loaded.append((position, slug, sid, stage, enemies))

    enemies_all: dict[str, dict] = {}
    for _, _, _, _, enemies in loaded:
        for eid, row in enemies.items():
            enemies_all.setdefault(eid, row)
    order = list(enemies_all)
    type_of = {eid: i + 1 for i, eid in enumerate(order)}

    def per_type(field, default, scale):
        return [(f"type == {type_of[e]}", scale(num(enemies_all[e].get(field), default))) for e in order]

    hp = per_type("hp", 1, lambda v: int(v * 1000))
    power = per_type("power", 1, lambda v: int(v * 1000))
    # Wiki speed 140 (a bat) = 2.0 units/tic: x4 the original 0.5, which was set when the player
    # moved 0.5 units/tic; the player now moves 3.0 (playtest 2026-09-29), so the enemies scale
    # with it. Capped at 4.5 so the Reaper (wiki 1200) stays about 1.5x the player, not 6x.
    # Wiki speed 140 (a bat) = 2.0 units/tic: 4x the original 0.5, which was set when the player
    # moved 0.5 units/tic; the player now moves 3.0 (playtest 2026-09-29), so enemies scale with
    # it. Capped at 4.5 so the Reaper (wiki 1200) stays about 1.5x the player, not 6x.
    speed = per_type("speed", 100, lambda v: min(int(round(v * 2000 / 140)), 4500))
    xp = per_type("xp", 1, lambda v: int(round(v * 1000)))
    # Wiki knockback multiplier (0 = immune, negative = pulled toward the hit).
    knock = per_type("knockback", 1, lambda v: int(round(max(-1.0, min(v, 3.0)) * 1000)))
    big = [(f"type == {type_of[e]}", 1) for e in order if e.startswith(("BOSS_", "XL"))]
    fam = [(f"type == {type_of[e]}", family(e, enemies_all[e].get("name", ""))) for e in order]

    # Per-stage tables, emitted as static arrays (long if-chains exceed the
    # ZScript VM register limit). tables[name][stage] = list of values.
    tables: dict[str, dict[int, list[int]]] = {}

    def put(name: str, stage_index: int, values: list[int]) -> None:
        tables.setdefault(name, {})[stage_index] = values

    for index, slug, sid, stage, enemies in loaded:
        waves = {w["minute"]: w for w in stage["waves"]}
        minutes = max(waves) + 1
        put("POOL_COUNT", index, [len(waves[m]["pool"]) if m in waves else 0 for m in range(minutes)])
        pool = [0] * (minutes * 16)
        for m, w in waves.items():
            for i, enemy in enumerate(w["pool"][:16]):
                pool[m * 16 + i] = type_of[enemy]
        put("POOL", index, pool)
        put("ENEMY_MIN", index, [int(waves[m]["enemy_min"]) if m in waves else 0 for m in range(minutes)])
        put("INTERVAL", index, [tics(float(waves[m]["spawn_interval_s"])) if m in waves else 35 for m in range(minutes)])
        bosses = [b for b in stage["bosses"] if b["enemy"] in type_of]
        chances = [((b.get("chest") or {}).get("chance_pct") or {}) for b in bosses]
        put("BOSS_MINUTE", index, [b["minute"] for b in bosses])
        put("BOSS_TYPE", index, [type_of[b["enemy"]] for b in bosses])
        put("BOSS_C5", index, [int(c.get("5_item", 0)) for c in chances])
        put("BOSS_C3", index, [int(c.get("3_item", 0)) for c in chances])
        put("BOSS_C1", index, [int(c.get("1_item", 0)) for c in chances])
        put("BOSS_ARCANA", index, [1 if (b.get("chest") or {}).get("type") == "arcana" else 0 for b in bosses])
        raw_events = [e for w in stage["waves"] for e in w.get("events", [])]
        raw_events += stage.get("unsupported_events", [])
        events = []
        for e in raw_events:
            etype = e.get("type")
            kind = EVENT_KIND.get(etype)
            trap = bool(e.get("trap")) and not e.get("at")
            if kind is None or not (e.get("at") or trap):
                continue
            enemy = e.get("enemy") or DEFAULT_EVENT_ENEMY.get(etype)
            if enemy not in type_of:
                # No usable enemy: take the first of that minute's wave pool.
                minute = int(num(e.get("minute"), 0))
                pool = waves.get(minute, {}).get("pool") or []
                enemy = next((p for p in pool if p in type_of), None)
                if enemy is None:
                    continue
            amount = int(num(e.get("amount"), DEFAULT_EVENT_AMOUNT.get(etype, 10)))
            seconds = float(e.get("duration_s") or DEFAULT_EVENT_SECONDS.get(etype)
                            or DEFAULT_EVENT_SECONDS_BY_KIND.get(kind, 30))
            if trap:
                events.append((TRAP_TIC, kind, tics(seconds), type_of[enemy], amount, 100))
                continue
            chance = int(num(e.get("chance_pct"), 100))
            repeats = max(1, int(num(e.get("repeats"), 1)))
            # Mad Forest rows name it repeat_delay_s; the Library rows delay_s.
            delay = num(e.get("repeat_delay_s"), num(e.get("delay_s"), 5.0))
            for r in range(repeats):
                start = event_tic(e["at"]) + (tics(delay * r) if r else 0)
                events.append((start, kind, tics(seconds), type_of[enemy], amount, chance))
        events.sort()
        for column, name in enumerate(("EVENT_TIC", "EVENT_KIND", "EVENT_DURATION", "EVENT_ENEMY",
                                       "EVENT_AMOUNT", "EVENT_CHANCE")):
            put(name, index, [ev[column] for ev in events])
        print(f"  stage {index} {sid}: {len(stage['waves'])} minutes, {len(bosses)} bosses, {len(events)} events")

    def arrays() -> str:
        out = []
        for name, per_stage in tables.items():
            for stage_index, values in per_stage.items():
                body = ", ".join(str(v) for v in values) or "0"
                out.append(f"    static const int {name}_{stage_index}[] = {{ {body} }};")
        return "\n".join(out) + "\n"

    def accessor(func: str, name: str, arg: str, default: int, key: str | None = None) -> str:
        key = key or arg
        lines = [f"    static int {func}(int stage, int {arg}{', int index' if func == 'PoolType' else ''})", "    {"]
        if func == "PoolType":
            lines.append("        int key = minute * 16 + index;")
            key = "key"
        for stage_index, values in tables[name].items():
            arr = f"DSStage.{name}_{stage_index}"
            size = len(values) if values else 0
            lines.append(f"        if (stage == {stage_index}) return {key} >= 0 && {key} < {size} ? {arr}[{key}] : {default};")
        lines.append(f"        return {default};")
        lines.append("    }")
        return "\n".join(lines) + "\n"

    def count(func: str, name: str) -> str:
        body = "".join(f"        if (stage == {i}) return {len(v)};\n" for i, v in tables[name].items())
        return f"    static int {func}(int stage)\n    {{\n{body}        return 0;\n    }}\n"

    names = "".join(f'        if (type == {type_of[e]}) return "{e}";\n' for e in order)
    stage_consts = "".join(f"    const {s[1]} = {i};\n" for i, s in enumerate(STAGES))

    def per_stage(func: str, rtype: str, default: str, rows: list[tuple[int, str]]) -> str:
        body = "".join(f"        if (stage == {i}) return {v};\n" for i, v in rows)
        return f"    static {rtype} {func}(int stage)\n    {{\n{body}        return {default};\n    }}\n"

    stage_fns = "".join([
        per_stage("Name", "String", '"Mad Forest"', [(i, f'"{s[2]}"') for i, s in enumerate(STAGES)]),
        per_stage("Has", "bool", "false", [(index, "true") for index, _, _, _, _ in loaded]),
        per_stage("MapFor", "String", '"MAP16"', [(i, f'"{s[3]}"') for i, s in enumerate(STAGES)]),
        "    // Spawn clamp (half-width/height in map units) for hall stages; 0 = none.\n",
        per_stage("ClampX", "int", "0", [(i, str(s[4])) for i, s in enumerate(STAGES) if s[4]]),
        per_stage("ClampY", "int", "0", [(i, str(s[5])) for i, s in enumerate(STAGES) if s[5]]),
        per_stage("Blurb", "String", '""', [(i, f'"{s[6]}"') for i, s in enumerate(STAGES)]),
        "    // Stage time limit and wiki normal-mode modifiers (milli; 1000 = x1).\n",
        per_stage("DurationTics", "int", "63000", [(i, str(int(st["stage"].get("duration_seconds", 1800)) * 35)) for i, _, _, st, _ in loaded]),
        per_stage("PlayerSpeedMilli", "int", "1000", [(i, str(modifier(st, "player_speed"))) for i, _, _, st, _ in loaded]),
        per_stage("EnemySpeedMilli", "int", "1000", [(i, str(modifier(st, "enemy_speed"))) for i, _, _, st, _ in loaded]),
        per_stage("GreedMilli", "int", "1000", [(i, str(modifier(st, "greed"))) for i, _, _, st, _ in loaded]),
        per_stage("StageXpMilli", "int", "1000", [(i, str(modifier(st, "xp"))) for i, _, _, st, _ in loaded]),
        per_stage("EnemyHealthMilli", "int", "1000", [(i, str(modifier(st, "enemy_health"))) for i, _, _, st, _ in loaded]),
        "    // Challenge stages: enemy health/speed multipliers grow per minute\n",
        "    // (milli added each minute), and light sources may drop only coins.\n",
        per_stage("HealthPerMinuteMilli", "int", "0", [(i, str(challenge(sid, st, "enemy_health_per_minute"))) for i, _, sid, st, _ in loaded]),
        per_stage("SpeedPerMinuteMilli", "int", "0", [(i, str(challenge(sid, st, "enemy_speed_per_minute"))) for i, _, sid, st, _ in loaded]),
        per_stage("HealthPerLevelMilli", "int", "0", [(i, str(challenge(sid, st, "enemy_health_per_level"))) for i, _, sid, st, _ in loaded]),
        "    // Carlo Cart scrolls the player along +X (milli units per tic).\n",
        per_stage("AutoScrollMilli", "int", "0", [(i, str(AUTO_SCROLL[sid])) for i, _, sid, _, _ in loaded if sid in AUTO_SCROLL]),
        "    // Light sources: chance per attempt (per mille), Luck cap (%), cap, attempt interval.\n",
        per_stage("LightChancePermille", "int", "100", [(i, str(int(round(LIGHT_SOURCES[sid][0] * 10)))) for i, _, sid, _, _ in loaded if sid in LIGHT_SOURCES]),
        per_stage("LightChanceMaxPct", "int", "50", [(i, str(LIGHT_SOURCES[sid][1])) for i, _, sid, _, _ in loaded if sid in LIGHT_SOURCES]),
        per_stage("LightMax", "int", "5", [(i, str(LIGHT_SOURCES[sid][2])) for i, _, sid, _, _ in loaded if sid in LIGHT_SOURCES]),
        per_stage("LightIntervalTics", "int", "35", [(i, str(max(1, round(LIGHT_SOURCES[sid][3] * 35 / 1000)))) for i, _, sid, _, _ in loaded if sid in LIGHT_SOURCES]),
        "    // Hyper bonuses and Inverse growth per stage (milli; tools/gen_stages.py MODES).\n",
        per_stage("HyperPlayerMilli", "int", "650", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[0] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("HyperEnemyMilli", "int", "650", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[1] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("HyperProjectileMilli", "int", "150", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[2] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("HyperGoldMilli", "int", "500", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[3] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("HyperLuckMilli", "int", "100", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[4] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("HyperHealthMilli", "int", "0", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[5] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("InverseHealthPerMinuteMilli", "int", "50", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[6] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("InverseSpeedPerMinuteMilli", "int", "5", [(i, str(int(round(MODES.get(sid, MODE_DEFAULT)[7] * 1000)))) for i, _, sid, _, _ in loaded]),
        per_stage("InverseTint", "int", "0", [(i, str(INVERSE_TINT[sid])) for i, _, sid, _, _ in loaded if sid in INVERSE_TINT]),
        per_stage("CoinsOnly", "bool", "false", [(i, "true") for i, _, sid, st, _ in loaded if challenge(sid, st, "no_item_drops")]),
        "    static int ForMap(String map)\n    {\n"
        + "".join(f'        if (map == "{s[3]}") return {i};\n' for i, s in enumerate(STAGES))
        + "        return -1;\n    }\n",
    ])
    lines = [
        "// GENERATED by tools/gen_stages.py from data/stages/*.json and",
        "// data/enemies/*-enemies.json (wiki approximations). Do not edit.",
        "class DSStage",
        "{",
        stage_consts.rstrip("\n"),
        f"    const STAGE_COUNT = {len(STAGES)};",
        f"    const ENEMY_TYPE_COUNT = {len(order)};",
        f"    const REAPER_TYPE = {type_of.get('BOSS_XLDEATH', 0)};",
        f"    const ENDER_TYPE = {type_of.get('BOSS_ENDER', 0)};",
        f"    const BAT_SWARM_TYPE = {type_of.get('BATSWARM', 0)};",
        f"    const GHOST_SWARM_TYPE = {type_of.get('GHOSTSWARM', 0)};",
        f"    const FLOWER_TYPE = {type_of.get('FLOWER', 0)};",
        "    const BAT_SWARM_COUNT = 50;",
        "    const GHOST_SWARM_COUNT = 20;",
        "    // Flower-wall ring size is not on the wiki: labelled approximation.",
        "    const FLOWER_RING_COUNT = 40;",
        "    const FLOWER_RING_RADIUS = 220;",
        "",
        stage_fns,
        "    // The Reaper and the Ender share the unkillable-by-effects rules.\n"
        "    static bool IsReaperLike(int type) { return type == REAPER_TYPE || (ENDER_TYPE > 0 && type == ENDER_TYPE); }\n",
        type_table("HpMilli", "TYPE_HP", "int", ["0"] + [str(v) for _, v in hp], 1000),
        type_table("PowerMilli", "TYPE_POWER", "int", ["0"] + [str(v) for _, v in power], 1000),
        type_table("SpeedMilliPerTic", "TYPE_SPEED", "int", ["0"] + [str(v) for _, v in speed], 500),
        type_table("XpMilli", "TYPE_XP", "int", ["0"] + [str(v) for _, v in xp], 1000),
        type_table("KnockbackMilli", "TYPE_KNOCKBACK", "int", ["0"] + [str(v) for _, v in knock], 1000),
        type_table("IsBig", "TYPE_BIG", "int", ["0"] + ["1" if e.startswith(("BOSS_", "XL")) else "0" for e in order], 0),
        type_table("Family", "TYPE_FAMILY", "int", ["0"] + [str(family(e, enemies_all[e].get("name", ""))) for e in order], 1),
        type_table("Variant", "TYPE_VARIANT", "int", ["0"] + [str(variant(e, enemies_all[e].get("name", ""))) for e in order], 0),
        # First enemy type of each archetype (art gallery debug view).
        type_table("FamilyExample", "FAMILY_EXAMPLE", "int", ["0"] + [str(next((type_of[e] for e in order if family(e, enemies_all[e].get("name", "")) == f), 0)) for f in range(1, 21)], 0),
        arrays(),
        accessor("PoolCount", "POOL_COUNT", "minute", 0),
        accessor("PoolType", "POOL", "minute", 0),
        accessor("EnemyMin", "ENEMY_MIN", "minute", 0),
        accessor("IntervalTics", "INTERVAL", "minute", 35),
        count("BossCount", "BOSS_TYPE"),
        accessor("BossMinute", "BOSS_MINUTE", "index", -1),
        accessor("BossType", "BOSS_TYPE", "index", 0),
        accessor("BossChest5Pct", "BOSS_C5", "index", 0),
        accessor("BossChest3Pct", "BOSS_C3", "index", 0),
        accessor("BossChest1Pct", "BOSS_C1", "index", 0),
        accessor("BossArcana", "BOSS_ARCANA", "index", 0),
        count("EventCount", "EVENT_TIC"),
        accessor("EventTic", "EVENT_TIC", "index", -1),
        accessor("EventKind", "EVENT_KIND", "index", 0),
        accessor("EventDurationTics", "EVENT_DURATION", "index", 1050),
        accessor("EventEnemy", "EVENT_ENEMY", "index", 0),
        accessor("EventAmount", "EVENT_AMOUNT", "index", 0),
        accessor("EventChancePct", "EVENT_CHANCE", "index", 100),
        "    // Original enemy traits (tools/enemy_traits.py). Resist bits: 2 Rosary,\n"
        "    // 4 knockback, 8 Defang, 16 debuffs. Freeze resistance divides freeze time\n"
        "    // (milli, 0 = none, 100000 = immune). Shooters fire BulletType every FireTics.\n",
        type_table("ResistBits", "TYPE_RESIST", "int", ["0"] + [str(sum(bit for key, bit in (("rosary", 2), ("knockback", 4), ("defang", 8), ("debuff", 16)) if TRAITS.get(e, {}).get(key))) for e in order], 0),
        type_table("FreezeResistMilli", "TYPE_FREEZE_RES", "int", ["0"] + [str(int(round(TRAITS.get(e, {}).get("freeze", 0) * 1000))) for e in order], 0),
        type_table("ExtraLives", "TYPE_LIVES", "int", ["0"] + [str(TRAITS.get(e, {}).get("lives", 0)) for e in order], 0),
        type_table("BulletType", "TYPE_BULLET", "int", ["0"] + [str(type_of.get(TRAITS.get(e, {}).get("bullet", ""), 0)) for e in order], 0),
        type_table("FireTics", "TYPE_FIRE", "int", ["0"] + [str(max(1, round(TRAITS.get(e, {}).get("fire_ms", 1000) * 35 / 1000))) for e in order], 35),
        type_table("Waves", "TYPE_WAVE", "int", ["0"] + [str(TRAITS.get(e, {}).get("wave", 0)) for e in order], 0),
        type_table("TypeName", "TYPE_NAME", "String", ['""'] + [f'"{e}"' for e in order], '"UNKNOWN"'),
        type_table("TypeLabel", "TYPE_LABEL", "String", ['""'] + ['"' + enemies_all[e].get("name", e).split(" (")[0].replace("\\", "").replace('"', "'") + '"' for e in order], '"Unknown"'),
        "}",
        "",
    ]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(order)} enemy types, {len(loaded)} stages")


if __name__ == "__main__":
    main()
