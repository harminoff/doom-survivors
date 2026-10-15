"""Every sound effect in the game, in one table (the single source of truth).

tools/audio/sa3_sfx.py generates candidates from the prompts, tools/audio/sfx_mix.py turns
the picked take into the game file and writes SNDINFO plus the ZScript lookup table
(src/zscript/gameplay/slice/SliceAudioTable.zs). Adding a sound = one line here, then run both.

Each entry: KEY (ZScript enum name) -> Sound(group, role, prompt, length range in seconds,
kind, plus optional overrides). The prompt describes the source, the action and the
production, as the Stable Audio 3 prompt guide suggests; generation prefixes "TrackType: SFX".
kind: "impact" (fast attack, one hit), "tonal" (pitched chime), "wash" (anything goes,
may contain several events, e.g. a flurry or an arpeggio).

The weapon / family / item maps at the bottom tie sounds to game ids (weapon system ids,
enemy families from DSStage.Family, MF_ITEM_* kinds).
"""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Sound:
    group: str
    role: str                       # weapon | frequent | ui | feedback | stinger
    prompt: str
    length: tuple[float, float]     # audible length the scorer aims for (s)
    kind: str = "wash"
    clip: float = 0.0               # generated clip length; 0 = from length
    lufs: float | None = None       # override the role's loudness
    duck: float | None = None       # music gain while it plays (1 = none)
    hold: int | None = None         # tics the duck is held
    pitch: tuple[float, float] | None | bool = True   # True = the role default
    limit: int | None = None
    extra: dict = field(default_factory=dict)


# role defaults: loudness (LUFS of the event), high-pass Hz, body cut dB @ 450 Hz,
# presence lift dB @ 3 kHz, peak ceiling dBFS, pitch range, voice limit, duck, hold tics,
# max_len (s, the audible tail is cut there; None = the entry's own length).
# The order of ROLES is the DSSfx category order (DSSfx.CAT); the first four are the
# combat bus: frequent sounds that are rate-limited per category and ducked under
# feedback and stingers (SliceAudio.zs). Levels follow a clear hierarchy: what the
# player must notice (stingers, feedback) > own weapons > pickups > deaths > hits.
ROLES = {
    "weapon":   dict(lufs=-33, hp=300, body=-4.0, presence=2.0, ceiling=-10.0, pitch=(0.95, 1.05), limit=2, duck=1.0, hold=0, max_len=None),
    "hit":      dict(lufs=-37, hp=450, body=-6.0, presence=1.5, ceiling=-13.0, pitch=(0.9, 1.1), limit=2, duck=1.0, hold=0, max_len=0.22),
    "death":    dict(lufs=-35, hp=350, body=-5.0, presence=2.0, ceiling=-12.0, pitch=(0.92, 1.08), limit=2, duck=1.0, hold=0, max_len=0.45),
    "pickup":   dict(lufs=-33, hp=500, body=0.0, presence=1.0, ceiling=-11.0, pitch=(0.96, 1.08), limit=2, duck=1.0, hold=0, max_len=0.45),
    "ui":       dict(lufs=-27, hp=400, body=-1.0, presence=1.0, ceiling=-9.0, pitch=None, limit=2, duck=1.0, hold=0, max_len=None),
    "feedback": dict(lufs=-25, hp=200, body=-3.0, presence=2.0, ceiling=-6.0, pitch=None, limit=1, duck=0.7, hold=30, max_len=None),
    "stinger":  dict(lufs=-22, hp=60, body=0.0, presence=0.0, ceiling=-4.0, pitch=None, limit=1, duck=0.4, hold=80, max_len=None),
}
CATEGORIES = list(ROLES)
COMBAT = ("weapon", "hit", "death", "pickup")

S = Sound
SOUNDS: dict[str, Sound] = {
    # ---- weapons: one per weapon (fires once per volley) ----------------------------------
    "W_WHIP": S("weapon", "weapon", "a leather bullwhip cracking once, sharp snap with a short swish, dry close mic", (0.15, 0.45)),
    "W_BLOODY_TEAR": S("weapon", "weapon", "a heavy wet whip crack with a dark blood splatter, sinister and juicy", (0.2, 0.55)),
    "W_MAGIC_WAND": S("weapon", "weapon", "a small magic missile launched from a wand, bright sparkly zap, fantasy game", (0.15, 0.45)),
    "W_HOLY_WAND": S("weapon", "weapon", "a rapid holy light bolt fired from a wand, bright angelic shimmer zap", (0.15, 0.45)),
    "W_KNIFE": S("weapon", "weapon", "a single throwing knife thrown, thin fast metal swish, close mic", (0.1, 0.35), "impact"),
    "W_THOUSAND_EDGE": S("weapon", "weapon", "three throwing knives thrown in quick succession, fast thin metallic swishes", (0.25, 0.9)),
    "W_AXE": S("weapon", "weapon", "a heavy hand axe thrown spinning through the air, low whooshing whirr", (0.2, 0.6)),
    "W_DEATH_SPIRAL": S("weapon", "weapon", "giant scythes spinning outward, dark ghostly whoosh with a metallic ring", (0.3, 0.8)),
    "W_FIRE_WAND": S("weapon", "weapon", "a fireball launched from a wand, quick whoosh of flame with a crackle", (0.2, 0.55)),
    "W_HELLFIRE": S("weapon", "weapon", "a huge roaring fireball launched, deep fiery whoosh and rumble", (0.3, 0.8)),
    "W_CROSS": S("weapon", "weapon", "a metal cross thrown like a boomerang, spinning metallic whirr", (0.2, 0.6)),
    "W_HEAVEN_SWORD": S("weapon", "weapon", "a holy sword thrown spinning, bright metallic swoosh with a soft choir shimmer", (0.3, 0.7)),
    "W_KING_BIBLE": S("weapon", "weapon", "magical book pages fluttering open, papery flap with a soft magic whoosh", (0.25, 0.7)),
    "W_UNHOLY_VESPERS": S("weapon", "weapon", "dark grimoire pages flapping with an eerie low choir whoosh", (0.3, 0.8)),
    "W_SANTA_WATER": S("weapon", "weapon", "a small glass bottle shattering with a holy water splash", (0.25, 0.6), "impact"),
    "W_LA_BORRA": S("weapon", "weapon", "a big splash of bubbling holy water, liquid surge with a sizzle", (0.35, 0.9)),
    "W_GARLIC": S("weapon", "weapon", "a soft pulsing aura throb, low warbling wobble with a faint sizzle", (0.2, 0.55)),
    "W_SOUL_EATER": S("weapon", "weapon", "a dark soul drain, ghostly whispering suck-in whoosh", (0.3, 0.7)),
    "W_LIGHTNING_RING": S("weapon", "weapon", "a lightning bolt striking the ground, sharp electric crack and sizzle", (0.25, 0.7), "impact"),
    "W_THUNDER_LOOP": S("weapon", "weapon", "a powerful double thunderclap, electric crack with a booming tail", (0.35, 0.9)),
    "W_PENTAGRAM": S("weapon", "weapon", "a magic seal flashing, bright mystical whoomp with a deep boom", (0.5, 1.3)),
    "W_GORGEOUS_MOON": S("weapon", "weapon", "a shimmering lunar blast, glassy celestial chime with a soft boom", (0.6, 1.4)),
    "W_RUNETRACER": S("weapon", "weapon", "a magic crystal diamond launched, glassy ping with a bouncy zing", (0.15, 0.45)),
    "W_NO_FUTURE": S("weapon", "weapon", "a distorted electric crystal ping, glitchy zap with a buzz", (0.2, 0.5)),
    "W_BONE": S("weapon", "weapon", "a bone thrown, dry hollow wooden clack and short whoosh", (0.12, 0.4), "impact"),
    "W_ANIMA": S("weapon", "weapon", "rattling skeleton bones thrown, ghostly hollow clatter", (0.2, 0.6)),
    "W_CHERRY_BOMB": S("weapon", "weapon", "a small cherry bomb tossed and popping, cartoon fuse pop", (0.15, 0.45), "impact"),
    "W_YATTA": S("weapon", "weapon", "a burst of candy bombs popping, cheerful bubbly explosion pops", (0.3, 0.8)),
    "W_CARRELLO": S("weapon", "weapon", "a shopping cart launched, rattling metal wheels rolling fast", (0.3, 0.8)),
    "W_CARROZZA": S("weapon", "weapon", "a heavy carriage launched, rumbling wooden wheels and creak", (0.35, 0.9)),
    "W_PEACHONE": S("weapon", "weapon", "a single quick bird wing flap, feathery whoosh with a tiny chirp", (0.15, 0.55)),
    "W_EBONY_WINGS": S("weapon", "weapon", "a black crow flapping its wings once with a dark croak", (0.2, 0.55)),
    "W_VANDALIER": S("weapon", "weapon", "two large birds flapping together with a shrill cry, powerful wingbeat", (0.3, 0.8)),
    "W_PHIERA": S("weapon", "weapon", "a retro blaster pistol shot, short punchy laser pew", (0.1, 0.35), "impact"),
    "W_EIGHT_SPARROW": S("weapon", "weapon", "a high pitched retro blaster shot, quick bright laser zip", (0.1, 0.35), "impact"),
    "W_PHIERAGGI": S("weapon", "weapon", "a rapid barrage of laser shots, spiralling sci-fi pew pew", (0.3, 0.8)),
    "W_VENTO_SACRO": S("weapon", "weapon", "a fast sword slash cutting the air, sharp wind swoosh", (0.15, 0.4)),
    "W_FUWALAFUWALOO": S("weapon", "weapon", "a gust of wind forming a small tornado, rushing whoosh", (0.35, 0.9)),
    "W_BRACELET": S("weapon", "weapon", "a magic orb fired, clear glassy chime with a soft zap", (0.2, 0.5), "tonal"),
    "W_BI_BRACELET": S("weapon", "weapon", "two magic orbs fired, two clear glassy chimes in a row", (0.25, 0.6), "tonal"),
    "W_TRI_BRACELET": S("weapon", "weapon", "three magic orbs fired, three bright glassy chimes rising", (0.3, 0.7), "tonal"),
    "W_GATTI_AMARI": S("weapon", "weapon", "a small cat meowing once, short playful meow", (0.2, 0.6)),
    "W_VICIOUS_HUNGER": S("weapon", "weapon", "an angry cat hissing and growling, short menacing yowl", (0.3, 0.8)),
    "W_SONG_OF_MANA": S("weapon", "weapon", "a magical harp glissando with a column of shimmering light", (0.4, 1.0), "tonal"),
    "W_MANNAJJA": S("weapon", "weapon", "a huge magical beam, swelling choir shimmer and deep whoosh", (0.5, 1.2)),
    "W_SHADOW_PINION": S("weapon", "weapon", "a dark shadow whoosh trailing behind, airy feathered swish", (0.2, 0.6)),
    "W_VALKYRIE_TURNER": S("weapon", "weapon", "flaming wings bursting, fiery whoosh with a crackle", (0.3, 0.8)),
    "W_CLOCK_LANCET": S("weapon", "weapon", "a clock ticking once with a freezing ice beam, crisp tick and shimmer", (0.2, 0.6)),
    "W_INFINITE_CORRIDOR": S("weapon", "weapon", "a deep grandfather clock bell bong with a time warp swoosh", (0.5, 1.2)),
    "W_LAUREL": S("weapon", "weapon", "leaves rustling quickly with a soft magical shimmer", (0.25, 0.8)),
    "W_CRIMSON_SHROUD": S("weapon", "weapon", "a dark red magic shield pulsing, deep throb with a glassy ring", (0.3, 0.8)),
    "W_CELESTIAL_DUSTING": S("weapon", "weapon", "flower petals falling with sparkling fairy dust twinkles", (0.3, 0.8)),
    "W_PROFUSIONE": S("weapon", "weapon", "a cascade of magical hearts, romantic sparkles and warm twinkles", (0.4, 1.0)),
    "W_LA_ROBBA": S("weapon", "weapon", "a small sack of jewels and trinkets tossed, glittering clatter", (0.25, 0.7)),
    "W_GREATEST_JUBILEE": S("weapon", "weapon", "small fireworks launching and bursting with crackles", (0.5, 1.3)),
    "W_VICTORY_SWORD": S("weapon", "weapon", "a sword slash with a bright metallic ring, heroic swing", (0.2, 0.55)),
    "W_FLAMES_OF_MISSPELL": S("weapon", "weapon", "a short burst from a flamethrower, roaring fire whoosh", (0.3, 0.8)),
    "W_ASHES_OF_MUSPELL": S("weapon", "weapon", "a huge blast of fire, deep roaring flame burst with embers", (0.4, 1.0)),
    "W_PAKO_BATTILIAR": S("weapon", "weapon", "an electric shock burst released in a ring, crackling zap", (0.25, 0.7)),
    "W_MAZO_FAMILIAR": S("weapon", "weapon", "a powerful electric blast in all directions, heavy crackling boom", (0.35, 0.9)),
    "W_AMMO_APPALATE": S("weapon", "weapon", "a single pistol gunshot, short punchy crack", (0.12, 0.4), "impact"),
    "W_GUNASTROPHE": S("weapon", "weapon", "a heavy shotgun blast, punchy boom with a short tail", (0.2, 0.6), "impact"),
    "W_UNEARTHLY_BOLT": S("weapon", "weapon", "a ghostly bolt from the sky, eerie electric whoosh and crack", (0.3, 0.8)),
    "W_SPIRIT_DISTURBANCE": S("weapon", "weapon", "spirits striking down, wailing ghostly crack with thunder", (0.4, 1.0)),
    "W_GLASS_FANDANGO": S("weapon", "weapon", "a glass shard flung, crystalline swish with a delicate ring", (0.15, 0.45)),
    "W_CELESTIAL_VOULGE": S("weapon", "weapon", "a heavenly polearm slash, bright crystalline swoosh with a choir ring", (0.3, 0.8)),
    "W_PENSHIN_FATCHA": S("weapon", "weapon", "a wet fish flung through the air, slap and whoosh, comedic", (0.2, 0.55)),
    "W_SANTA_JAVELIN": S("weapon", "weapon", "a javelin thrown hard, fast whoosh with a holy ring", (0.2, 0.55)),
    "W_SERAPHIC_CRY": S("weapon", "weapon", "a blessed spear hurled, piercing whoosh with an angelic cry", (0.35, 0.9)),
    "W_GAZE_OF_GAEA": S("weapon", "weapon", "roots bursting from the earth, crunchy soil rumble", (0.3, 0.8)),
    "W_EMBRACE_OF_GAEA": S("weapon", "weapon", "the earth erupting with vines, heavy crumbling rumble", (0.4, 1.0)),
    "W_MAGI_STONE": S("weapon", "weapon", "a magic crystal stone launched, hard glassy clink and whoosh", (0.15, 0.45)),
    "W_KYRA_STONES": S("weapon", "weapon", "several magic crystal stones launched, sparkling glassy clinks", (0.25, 0.7)),
    "W_PHAS3R": S("weapon", "weapon", "a sci-fi phaser beam, rising electronic laser zap", (0.2, 0.6)),
    "W_PHOTONSTORM": S("weapon", "weapon", "a storm of sci-fi laser beams, layered electronic zaps", (0.4, 1.0)),
    "W_CHAOS_RUNE": S("weapon", "weapon", "a chaotic dark rune pulsing, distorted magical throb", (0.3, 0.8)),
    "W_WICKED_RULER": S("weapon", "weapon", "an evil ruler's dark command, deep warped magical boom", (0.4, 1.0)),
    "W_NDUJA_BREATH": S("weapon", "weapon", "a burst of fire breath, roaring flame whoosh", (0.3, 0.8)),
    "W_SORBETTO_BREATH": S("weapon", "weapon", "a burst of freezing ice breath, icy hiss with crystal crackle", (0.3, 0.8)),
    "W_EXPLOSION": S("weapon", "weapon", "a small magical bomb exploding, punchy pop boom with crackling sparks", (0.2, 0.6), "impact"),
    "SHOOT": S("weapon", "weapon", "a generic magic projectile shot, quick zap whoosh", (0.12, 0.4)),

    # ---- hits: one per weapon engine (damage landing) -------------------------------------
    "H_WHIP": S("hit", "hit", "a whip striking flesh, sharp leathery smack", (0.08, 0.3), "impact"),
    "H_AIMED": S("hit", "hit", "a small magic projectile hitting a monster, crisp zap impact", (0.08, 0.3), "impact"),
    "H_BALLISTIC": S("hit", "hit", "a heavy blade chopping into a monster, meaty thunk", (0.1, 0.3), "impact"),
    "H_RETURNING": S("hit", "hit", "a metal object striking a monster, clanging metallic hit", (0.1, 0.3), "impact"),
    "H_ORBIT": S("hit", "hit", "a heavy book slamming into a monster, papery thump", (0.08, 0.3), "impact"),
    "H_GROUND": S("hit", "hit", "holy fire burning a monster, short sizzle", (0.1, 0.35), "impact"),
    "H_AURA": S("hit", "hit", "a soft energy tick hitting a monster, muted fizz", (0.06, 0.25), "impact"),
    "H_GLOBAL": S("hit", "hit", "electricity zapping a monster, short crackle", (0.08, 0.3), "impact"),
    "H_BOUNCE": S("hit", "hit", "a hard object bouncing off a monster, springy knock", (0.08, 0.3), "impact"),
    "H_PAIRED": S("hit", "hit", "a bullet hitting a monster, quick punchy smack", (0.06, 0.25), "impact"),
    "H_CRIT": S("hit", "hit", "a critical hit, sharp bright metallic ting with a punchy snap", (0.08, 0.25), "impact"),
    "HIT": S("hit", "hit", "a short punchy impact on a monster, thud with a bright snap", (0.08, 0.3), "impact"),

    # ---- enemy deaths: one per enemy family (DSStage.Family) ------------------------------
    "D_BAT": S("enemy", "death", "a small bat dying, squeak and leathery flutter puff", (0.15, 0.45), "impact"),
    "D_ZOMBIE": S("enemy", "death", "a zombie collapsing, short wet groan and squelch", (0.2, 0.5)),
    "D_SKELETON": S("enemy", "death", "a skeleton shattering, dry bones clattering apart", (0.2, 0.55)),
    "D_GHOST": S("enemy", "death", "a ghost dissipating, short airy wail fading out", (0.25, 0.6)),
    "D_MUDMAN": S("enemy", "death", "a mud creature splattering, thick wet squelch", (0.15, 0.45), "impact"),
    "D_BEAST": S("enemy", "death", "a wild beast dying, short snarling yelp", (0.2, 0.55)),
    "D_INSECT": S("enemy", "death", "a giant bug squashed, crunchy chitin crack with a buzz", (0.15, 0.45), "impact"),
    "D_MUMMY": S("enemy", "death", "a mummy crumbling, dusty bandage rip and dry crumble", (0.2, 0.55)),
    "D_PLANT": S("enemy", "death", "a carnivorous plant bursting, leafy wet pop", (0.15, 0.45), "impact"),
    "D_REAPER": S("enemy", "stinger", "death himself destroyed, huge ghostly wail and shattering scythe", (1.0, 2.5)),
    "D_JELLY": S("enemy", "death", "a jelly blob popping, bubbly wet splat", (0.12, 0.4), "impact"),
    "D_CASTER": S("enemy", "death", "a witch defeated, short cackle cut off with a magic puff", (0.25, 0.6)),
    "D_KNIGHT": S("enemy", "death", "an armored knight falling, clanking metal armor crash", (0.2, 0.55)),
    "D_DRAGON": S("enemy", "death", "a small dragon defeated, raspy screech with a fiery puff", (0.25, 0.6)),
    "D_FISH": S("enemy", "death", "a fishman defeated, wet slap and gurgle", (0.15, 0.45)),
    "D_DEMON": S("enemy", "death", "a demon banished, dark growl collapsing into a hiss", (0.25, 0.6)),
    "D_ANGEL": S("enemy", "death", "a dark angel falling, short choir note and feathers", (0.25, 0.6)),
    "D_OBJECT": S("enemy", "death", "a small wooden object smashed, short dry wood crack and splinter", (0.12, 0.45), "impact"),
    "D_CRITTER": S("enemy", "death", "a small creature defeated, cute squeak and pop", (0.12, 0.4), "impact"),
    "D_BLOB": S("enemy", "death", "a slime blob bursting, gooey splat", (0.12, 0.4), "impact"),
    "DEATH": S("enemy", "death", "a small monster defeated, quick crunchy pop and fade", (0.15, 0.45), "impact"),
    "D_ELITE": S("enemy", "feedback", "a powerful elite monster defeated, heavy crunch with a magical burst", (0.4, 1.0), duck=1.0, hold=0),
    "D_BOSS": S("enemy", "stinger", "a giant boss monster defeated, roaring death cry and a big explosion", (1.0, 2.5), hold=60, duck=0.5),
    "D_BRAZIER": S("enemy", "feedback", "an iron brazier knocked over, metallic clang with fire fizzling out", (0.3, 0.8), duck=1.0, hold=0),
    "D_WINDOW": S("enemy", "feedback", "a stained glass window shattering, glass crash", (0.4, 1.0), duck=1.0, hold=0),
    "D_CART": S("enemy", "feedback", "a wooden mine cart smashed, wood splintering crash", (0.4, 1.0), duck=1.0, hold=0),

    # ---- pickups ---------------------------------------------------------------------------
    "GEM": S("item", "pickup", "a tiny bright crystal gem picked up, single sparkle blip", (0.08, 0.3), "tonal", pitch=(0.96, 1.1)),
    "COIN": S("item", "pickup", "a gold coin picked up, bright metallic ding", (0.2, 0.6), "tonal", lufs=-32),
    "I_COIN_BAG": S("item", "feedback", "a small bag of gold coins picked up, jingling coins", (0.3, 0.8), duck=1.0, hold=0),
    "I_RICH_BAG": S("item", "feedback", "a heavy sack of treasure picked up, big cascade of jingling gold", (0.6, 1.4)),
    "HEAL": S("item", "feedback", "eating a roast chicken, quick crunchy bite with a warm healing chime", (0.4, 1.0), lufs=-28, duck=1.0, hold=0),
    "I_ROSARY": S("item", "stinger", "a holy rosary activated, blinding flash with a choir and a deep boom", (1.0, 2.2), hold=60),
    "FREEZE": S("item", "feedback", "time stopping, crystalline freeze crackle and a clock tick", (0.5, 1.2), lufs=-28),
    "I_VACUUM": S("item", "feedback", "a magnet pulling everything in, rising magnetic whoosh with sparkles", (0.6, 1.4)),
    "I_LITTLE_CLOVER": S("item", "feedback", "a lucky four leaf clover picked up, bright twinkling chime", (0.4, 1.0), "tonal", duck=1.0, hold=0),
    "I_GILDED_CLOVER": S("item", "feedback", "a golden clover starting gold fever, shimmering cascade of golden chimes", (0.8, 1.8), "tonal"),
    "I_REROLLO": S("item", "feedback", "a magic die rolled, wooden dice rattle with a sparkle", (0.3, 0.8), duck=1.0, hold=0),
    "I_NDUJA": S("item", "feedback", "eating spicy food, crunchy bite then a fiery whoosh", (0.4, 1.0), duck=1.0, hold=0),
    "I_SORBETTO": S("item", "feedback", "eating ice cream, cold slurp then an icy shimmer", (0.4, 1.0), duck=1.0, hold=0),
    "I_FEVER_END": S("item", "feedback", "a golden aura fading away, descending soft chimes", (0.5, 1.2), "tonal", duck=1.0, hold=0),
    "I_HEART": S("item", "pickup", "a small floating heart picked up, soft warm healing chime", (0.15, 0.45), "tonal"),
    "I_AMULET": S("item", "stinger", "an ancient sacred amulet claimed, glowing mystical choir swell and a bright chime burst", (1.4, 2.8), hold=80),
    "I_FLOOR_ITEM": S("item", "feedback", "a relic picked up from the floor, magical pickup sparkle", (0.4, 1.0), "tonal", duck=1.0, hold=0),

    # ---- progression and events ------------------------------------------------------------
    "LEVELUP": S("event", "feedback", "level up fanfare, ascending magical chime arpeggio, triumphant sparkle", (0.8, 1.7), "tonal", lufs=-24, duck=0.55, hold=45),
    "E_PICK_WEAPON": S("event", "feedback", "a new weapon acquired, sword unsheathed with a bright shing", (0.3, 0.8), duck=1.0, hold=0),
    "E_PICK_PASSIVE": S("event", "feedback", "a magic trinket equipped, soft glowing chime", (0.3, 0.8), "tonal", duck=1.0, hold=0),
    "E_RANK_UP": S("event", "feedback", "a weapon powered up, quick rising magical whoosh with a ding", (0.3, 0.8), duck=1.0, hold=0),
    "CHEST": S("event", "feedback", "treasure chest opening, wooden creak then magical shimmering reward", (1.0, 2.0), lufs=-24, duck=0.55, hold=50),
    "E_EVOLUTION": S("event", "stinger", "a weapon evolving, powerful magical transformation, rising choir and a bright burst", (1.4, 2.8), lufs=-18, hold=80),
    "ARCANA": S("event", "feedback", "mystical tarot card revealed, ethereal choir shimmer rising", (1.2, 2.2), lufs=-24, duck=0.5, hold=60),
    "E_ARCANA_TAKE": S("event", "feedback", "a tarot card placed on a table, papery snap with a mystical hum", (0.4, 1.0), duck=1.0, hold=0),
    "E_WHEEL": S("event", "feedback", "a prize wheel spinning, rapid clicking ratchet slowing down", (1.0, 2.2), duck=1.0, hold=0),
    "E_MERCHANT": S("event", "feedback", "buying an item at a shop, coins on the counter and a cash register ding", (0.4, 1.0), duck=1.0, hold=0),
    "E_EGG": S("event", "feedback", "a magic egg cracked open, shell crack with a warm sparkle", (0.4, 1.0), duck=1.0, hold=0),
    "E_COFFIN": S("event", "feedback", "a stone coffin lid sliding open, heavy grinding scrape", (0.8, 1.8), duck=0.7, hold=40),
    "E_RELIC": S("event", "feedback", "an ancient relic awakened, deep mystical hum and shimmer", (0.8, 1.8), duck=0.6, hold=50),
    "E_PLATE": S("event", "feedback", "a stone pressure plate clicking down, heavy mechanical clunk", (0.2, 0.6), "impact", duck=1.0, hold=0),
    "E_DOOR": S("event", "feedback", "a magic portal door teleporting, whooshing warp with a shimmer", (0.6, 1.5), duck=1.0, hold=0),
    "E_CART_LAUNCH": S("event", "feedback", "a mine cart released, rolling wheels on rails picking up speed", (0.6, 1.5), duck=1.0, hold=0),
    "E_SWARM": S("event", "feedback", "a swarm of monsters approaching, ominous rising rustle", (0.8, 2.0), duck=0.8, hold=30),
    "E_SHROUD_BLOCK": S("event", "feedback", "a red magic shield absorbing a heavy blow, deep glassy ring with a whoosh", (0.3, 0.8), duck=1.0, hold=0),
    "E_STAIRS_DOWN": S("event", "feedback", "footsteps hurrying down old stone stairs into a cavern, echoing descent", (0.8, 1.8), duck=0.7, hold=30),
    "E_STAIRS_UP": S("event", "feedback", "footsteps climbing old stone stairs, rising echo toward daylight", (0.8, 1.8), duck=0.7, hold=30),
    "E_SPIKES": S("event", "feedback", "iron spike trap springing from the floor, sharp metallic shing and stab", (0.15, 0.5), "impact", duck=1.0, hold=0),
    "E_TREASURE_ROOM": S("event", "feedback", "a hidden treasure room revealed, heavy door creak then a sparkling golden shimmer", (1.0, 2.0), duck=0.55, hold=45),
    "E_STORE_ROOM": S("event", "feedback", "a dusty forgotten storeroom found, wooden door creak and soft candle flicker", (0.6, 1.4), duck=1.0, hold=0),
    "E_DISCOVER": S("event", "feedback", "a faint magical sense of discovery, soft mysterious ping with a shimmer", (0.4, 1.0), "tonal", duck=1.0, hold=0),
    "BOSS": S("event", "stinger", "boss arrival, deep ominous horn hit with rumble", (1.4, 2.6)),
    "REAPER": S("event", "stinger", "death approaches, eerie low bell toll with a ghostly whisper", (1.8, 3.2), duck=0.4, hold=90),
    "HURT": S("event", "feedback", "the player takes damage, short sharp pained impact hit", (0.15, 0.5), "impact", lufs=-21, duck=0.8, hold=12, pitch=(0.96, 1.04), limit=2),
    "REVIVE": S("event", "feedback", "revival, angelic rising chime with a burst of light", (0.9, 1.7), "tonal", lufs=-24, duck=0.5, hold=45),
    "E_GEM_BOMB": S("event", "feedback", "a magic explosion of gems, crystalline burst", (0.4, 1.0), duck=1.0, hold=0),
    "VICTORY": S("event", "stinger", "victory fanfare, triumphant short brass jingle", (1.8, 3.2), duck=0.35, hold=100),
    "DEFEAT": S("event", "stinger", "defeat game over sting, sad descending tones", (1.5, 2.8), duck=0.35, hold=90),

    # ---- interface (UZDoom menu sounds) -----------------------------------------------------
    "MENU": S("ui", "ui", "a soft menu cursor tick, short clean wooden click", (0.03, 0.16), "impact"),
    "CONFIRM": S("ui", "ui", "a menu confirm, pleasant two note blip", (0.15, 0.45), "tonal"),
    "U_BACK": S("ui", "ui", "a menu back button, soft descending blip", (0.1, 0.35), "tonal"),
    "U_CHANGE": S("ui", "ui", "a menu slider changed, tiny tick", (0.03, 0.15), "impact"),
    "U_INVALID": S("ui", "ui", "an invalid action buzzer, short low dull buzz", (0.12, 0.4)),
    "U_OPEN": S("ui", "ui", "a menu opening, soft parchment unfold whoosh", (0.2, 0.6)),
    "U_CLOSE": S("ui", "ui", "a menu closing, soft parchment fold", (0.15, 0.5)),
}

# Sounds taken from the synthesiser (tools/audio/sfx_synth_takes.py) instead of the model,
# e.g. {"MENU": "menu", "CONFIRM": "confirm"}. Empty: everything is generated.
SYNTH: dict[str, str] = {}

# weapon system id -> sound key (systems: ResolvedStats.zs, N3Rows.zs)
WEAPON = {
    1: "W_WHIP", 6: "W_BLOODY_TEAR", 34: "W_MAGIC_WAND", 35: "W_HOLY_WAND", 36: "W_KNIFE", 37: "W_THOUSAND_EDGE",
    38: "W_AXE", 39: "W_DEATH_SPIRAL", 40: "W_FIRE_WAND", 41: "W_HELLFIRE", 42: "W_CROSS", 43: "W_HEAVEN_SWORD",
    44: "W_KING_BIBLE", 45: "W_UNHOLY_VESPERS", 46: "W_SANTA_WATER", 47: "W_LA_BORRA", 48: "W_GARLIC",
    49: "W_SOUL_EATER", 50: "W_LIGHTNING_RING", 51: "W_THUNDER_LOOP", 52: "W_PENTAGRAM", 53: "W_GORGEOUS_MOON",
    54: "W_RUNETRACER", 55: "W_NO_FUTURE", 56: "W_BONE", 57: "W_CHERRY_BOMB", 58: "W_CARRELLO", 59: "W_PEACHONE",
    60: "W_EBONY_WINGS", 61: "W_VANDALIER", 62: "W_PHIERA", 63: "W_EIGHT_SPARROW", 64: "W_PHIERAGGI",
    65: "W_VENTO_SACRO", 66: "W_FUWALAFUWALOO", 67: "W_BRACELET", 68: "W_BI_BRACELET", 69: "W_TRI_BRACELET",
    76: "W_GATTI_AMARI", 77: "W_VICIOUS_HUNGER", 78: "W_SONG_OF_MANA", 79: "W_MANNAJJA", 80: "W_SHADOW_PINION",
    81: "W_VALKYRIE_TURNER", 82: "W_CLOCK_LANCET", 83: "W_INFINITE_CORRIDOR", 84: "W_LAUREL", 85: "W_CRIMSON_SHROUD",
    86: "W_CELESTIAL_DUSTING", 87: "W_PROFUSIONE", 88: "W_LA_ROBBA", 89: "W_GREATEST_JUBILEE", 91: "W_VICTORY_SWORD",
    92: "W_FLAMES_OF_MISSPELL", 93: "W_ASHES_OF_MUSPELL", 94: "W_PAKO_BATTILIAR", 95: "W_MAZO_FAMILIAR",
    96: "W_AMMO_APPALATE", 97: "W_GUNASTROPHE", 98: "W_UNEARTHLY_BOLT", 99: "W_SPIRIT_DISTURBANCE",
    102: "W_GLASS_FANDANGO", 103: "W_CELESTIAL_VOULGE", 104: "W_PENSHIN_FATCHA", 112: "W_SANTA_JAVELIN",
    113: "W_SERAPHIC_CRY", 114: "W_GAZE_OF_GAEA", 115: "W_EMBRACE_OF_GAEA", 116: "W_MAGI_STONE", 117: "W_KYRA_STONES",
    118: "W_PHAS3R", 119: "W_PHOTONSTORM", 120: "W_CHAOS_RUNE", 121: "W_WICKED_RULER", 123: "W_ANIMA",
    124: "W_YATTA", 125: "W_CARROZZA",
}

# N2CreditDamage engine name -> hit sound
HIT = {"AIMED": "H_AIMED", "BALLISTIC": "H_BALLISTIC", "RETURNING": "H_RETURNING", "ORBIT": "H_ORBIT",
       "GROUND": "H_GROUND", "AURA": "H_AURA", "GLOBAL": "H_GLOBAL", "BOUNCE": "H_BOUNCE", "PAIRED": "H_PAIRED",
       "GENERIC": "HIT"}

# DSStage.Family -> death sound
FAMILY = ["DEATH", "D_BAT", "D_ZOMBIE", "D_SKELETON", "D_GHOST", "D_MUDMAN", "D_BEAST", "D_INSECT", "D_MUMMY",
          "D_PLANT", "D_REAPER", "D_JELLY", "D_CASTER", "D_KNIGHT", "D_DRAGON", "D_FISH", "D_DEMON", "D_ANGEL",
          "D_OBJECT", "D_CRITTER", "D_BLOB"]

# MF_ITEM_* kind -> pickup sound
ITEM = ["COIN", "COIN", "I_COIN_BAG", "I_RICH_BAG", "HEAL", "I_ROSARY", "FREEZE", "I_VACUUM", "I_LITTLE_CLOVER",
        "I_NDUJA", "I_GILDED_CLOVER", "I_REROLLO", "I_SORBETTO"]

# UZDoom menu sound names -> sound key
MENU_ALIASES = {"menu/cursor": "MENU", "menu/choose": "CONFIRM", "menu/backup": "U_BACK", "menu/change": "U_CHANGE",
                "menu/invalid": "U_INVALID", "menu/clear": "U_BACK", "menu/activate": "U_OPEN",
                "menu/dismiss": "U_CLOSE", "menu/prompt": "U_OPEN"}


def setting(key: str, name: str):
    """A sound's mix setting: its own override, else the role default."""
    snd = SOUNDS[key]
    own = getattr(snd, name, None) if name in ("lufs", "duck", "hold", "limit") else None
    if name == "pitch":
        return ROLES[snd.role]["pitch"] if snd.pitch is True else snd.pitch
    return own if own is not None else ROLES[snd.role][name]


def file_stem(key: str) -> str:
    return key.lower()


def logical(key: str) -> str:
    return f"ds/{SOUNDS[key].group}/{file_stem(key)}"


def clip_seconds(key: str) -> float:
    snd = SOUNDS[key]
    return snd.clip or (2.0 if snd.length[1] <= 1.0 else 4.0)
