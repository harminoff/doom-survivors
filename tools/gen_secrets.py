"""Generate src/zscript/gameplay/meta/Secrets.zs: Vampire Survivors' Forbidden
Scrolls spells this port can honour, with what each unlocks. Typed on the
Secrets page once the Forbidden Scrolls of Morbane relic is found.
Run: python tools/gen_secrets.py
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "src/zscript/gameplay/catalog/ItemCatalog.zs"
OUT = ROOT / "src/zscript/gameplay/meta/Secrets.zs"

# Reward kinds.
CHARACTER, STAGE, RELIC, ARCANA, WEAPON, MODIFIER = range(1, 7)
EVERYTHING, EVERYWHERE = 1, 2

C = {n: i for i, n in enumerate(
    "ANTONIO IMELDA PASQUALINA GENNARO ARCA PORTA LAMA POE CLERICI DOMMARIO KROCHI "
    "CHRISTINE PUGNALA POPPEA MORTACCIO YATTA BIANCA OSOLE ZIASSUNTA AMBROJOE EXDASH "
    "TOASTIE GIOVANNA CONCETTA IGUANA DIVANO SMITH MARRABBIO MINNAH LEDA PEPPINO BOROS "
    "GYORUNTON REDDEATH TROUSER AVATAR SIGMA ROBBERT ZIAPPUNTA TROUBLER SHEMOON COOLIO "
    "SANTA GAZEBO CHULAREH SPACEDUDE BATS ROSE GYORUNTIN SECRETINO SPACEDETTE RANDOM".split())}
S = {"MOLISE": 7, "SINKING": 8, "GREENACRES": 5, "BONEZONE": 6, "RASH": 9, "WHITEOUT": 10,
     "EX_LYCAEUM": 11, "CARLOCART": 20, "LABORRATORY": 14, "COOP": 12, "EX_WESTWOODS": 15,
     "SPAZIE": 13, "BATCOUNTRY": 16, "ASTRALSTAIR": 17, "TOWERBRIDGE": 19, "EX_MAZERELLA": 18}
R = {"RELIC_YELLOW": 1, "RELIC_RANDOMAZZO": 2, "RELIC_GRIMOIRE": 3, "RELIC_MAP": 4, "RELIC_GOUDA": 5,
     "RELIC_TEAR": 6, "RELIC_BANGER": 7, "RELIC_TRISECTION": 8, "RELIC_BRAVESTORY": 10,
     "RELIC_MIRROR": 11, "RELIC_TRUMPET": 12, "RELIC_GGOSPEL": 13,
     "RELIC_GLASSMASK": 14, "RELIC_NOSEGLASSES": 15, "RELIC_CHARM": 16, "RELIC_ANTIDOTE": 17, "RELIC_RECYCLE": 18}

# (spell, [(kind, value), ...]) from the wiki's spell list.
SPELLS = [
    ("x-x1viiq", [(CHARACTER, "EXDASH")]), ("exdashexoneviiq", [(CHARACTER, "EXDASH")]),
    ("tramezzini", [(CHARACTER, "TOASTIE")]), ("maybeimastallion", [(CHARACTER, "SMITH")]),
    ("igottagettotheedgeofsoul", [(CHARACTER, "RANDOM")]),
    ("noneladonna", [(CHARACTER, "ARCA")]), ("vivaladonna", [(CHARACTER, "PORTA")]),
    ("superladonna", [(CHARACTER, "LAMA")]), ("strongestcharacter", [(CHARACTER, "POE")]),
    ("bioparco", [(CHARACTER, "DOMMARIO")]), ("faschiuma", [(CHARACTER, "CLERICI")]),
    ("accidenti", [(CHARACTER, "KROCHI")]), ("crystalmakeup", [(CHARACTER, "CHRISTINE")]),
    ("flymetothemoon", [(CHARACTER, "PUGNALA")]), ("thetwoassassins", [(CHARACTER, "GIOVANNA")]),
    ("feldschlacht", [(CHARACTER, "POPPEA")]), ("ifeellovevenus", [(CHARACTER, "CONCETTA")]),
    ("yattapanda", [(CHARACTER, "YATTA")]), ("carramba", [(CHARACTER, "BIANCA")]),
    ("reset", [(CHARACTER, "OSOLE")]), ("languorino", [(CHARACTER, "AMBROJOE")]),
    ("waitreaction", [(CHARACTER, "IGUANA")]), ("quandolodicelui", [(CHARACTER, "DIVANO")]),
    ("paradigmshift", [(CHARACTER, "ZIASSUNTA")]), ("allatonce", [(CHARACTER, "SIGMA")]),
    ("bimbumbam", [(CHARACTER, "ROBBERT")]), ("cygnusmagnus", [(CHARACTER, "SHEMOON")]),
    ("fastisfortuna", [(CHARACTER, "COOLIO")]), ("shesawit", [(CHARACTER, "SANTA")]),
    ("allegedcannibal", [(CHARACTER, "GAZEBO")]), ("thegoodguy", [(CHARACTER, "SPACEDUDE")]),
    ("frozenbutler", [(CHARACTER, "ZIAPPUNTA")]), ("wifeseeker", [(CHARACTER, "TROUBLER")]),
    ("malcomtent", [(CHARACTER, "CHULAREH")]), ("secondevolution", [(CHARACTER, "GYORUNTON")]),
    ("earrivatolarrotino", [(CHARACTER, "TROUSER")]), ("fettinepanate", [(CHARACTER, "MARRABBIO")]),
    ("kalvasflam", [(CHARACTER, "AVATAR"), (WEAPON, "N3_FLAMES_OF_MISSPELL")]),
    ("foldinthecheese", [(CHARACTER, "MINNAH")]), ("iwillneverletyouforgetaboutme", [(CHARACTER, "LEDA")]),
    ("pinociampino", [(CHARACTER, "PEPPINO")]), ("highfive", [(CHARACTER, "BOROS")]),
    ("ablasphemousmockery", [(CHARACTER, "REDDEATH")]), ("rescuefromtheshadows", [(CHARACTER, "ROSE")]),
    ("blunderingfool", [(CHARACTER, "GYORUNTIN")]), ("whydithavetobebats", [(CHARACTER, "BATS")]),
    ("silentlaugh", [(CHARACTER, "SECRETINO")]), ("loveknowsnobounds", [(CHARACTER, "SPACEDETTE")]),
    ("apritisedano", [(WEAPON, "N3_ARMA_DIO")]), ("chefacciolascio", [(WEAPON, "N3_PARM_AEGIS")]),
    ("thisshouldhavebeenunlockedbydefault", [(RELIC, "RELIC_GRIMOIRE")]),
    ("thistooshouldhavebeenunlockedbydefault", [(RELIC, "RELIC_GOUDA")]),
    ("thankelrond", [(RELIC, "RELIC_BANGER")]), ("leadmetothecheese", [(RELIC, "RELIC_MAP")]),
    ("timecompression", [(RELIC, "RELIC_TEAR")]),
    ("randomazzami", [(RELIC, "RELIC_RANDOMAZZO"), (ARCANA, 6)]),
    ("ihaveseenitihaveseenitihaveseenitihaveseenitihaveseenitihaveseenitihaveseenit", [(RELIC, "RELIC_YELLOW")]),
    ("icanhearthecriesofcaptainplanet", [(RELIC, "RELIC_GGOSPEL")]),
    ("freezearrow", [(RELIC, "RELIC_MIRROR")]), ("dootdoot", [(RELIC, "RELIC_TRUMPET")]),
    ("haeralisploy", [(RELIC, "RELIC_TRISECTION")]), ("lugrianstale", [(RELIC, "RELIC_BRAVESTORY")]),
    ("eggseggseggs", [(RELIC, "RELIC_GLASSMASK")]), ("teleportustomars", [(RELIC, "RELIC_NOSEGLASSES")]),
    ("tengillesbalm", [(RELIC, "RELIC_CHARM")]), ("duraistruth", [(RELIC, "RELIC_ANTIDOTE")]),
    ("rererecycle", [(RELIC, "RELIC_RECYCLE")]),
    ("everything", [(MODIFIER, EVERYTHING)]), ("everywhere", [(MODIFIER, EVERYWHERE)]),
]
for stage_key, spell in (("MOLISE", "relaxenjoylife"), ("SINKING", "honesty"), ("GREENACRES", "dotgogreenacres"),
                         ("BONEZONE", "rottingpizza"), ("RASH", "peakgamedesign"), ("WHITEOUT", "buriedinthesnow"),
                         ("EX_LYCAEUM", "honestest"), ("CARLOCART", "thenextstopis"),
                         ("LABORRATORY", "divineassault"), ("COOP", "coopwhen"),
                         ("EX_WESTWOODS", "onebranchbandit"), ("SPAZIE", "jumptheshark"),
                         ("BATCOUNTRY", "recycletheforest"), ("ASTRALSTAIR", "recyclethelibrary"),
                         ("TOWERBRIDGE", "recyclethetower"), ("EX_MAZERELLA", "recycletheplant")):
    SPELLS.append((spell, [(STAGE, stage_key)]))
# Arcana: Il Matto is Game Killer (22 here), the rest keep their numbers.
for n, spell in enumerate(["ilmatto", "ilbagatto", "lapapessa", "limperatrice", "limperatore", "ilpapa",
                           None, "ilcarro", "laforza", "leremita", "laruota", "lagiustizia", "lappeso",
                           "lamorte", "latemperanza", "ildiavolo", "latorre", "lastella", "laluna", "ilsole",
                           "ilgiudizio", "ilmondo"]):
    if spell:
        SPELLS.append((spell, [(ARCANA, 22 if n == 0 else n)]))


def main() -> None:
    ids = {k: int(v) for k, v in re.findall(r"const (ID_\w+) = (\d+);", CATALOG.read_text(encoding="utf-8"))}

    def value(kind, v):
        if kind == CHARACTER:
            return C[v]
        if kind == STAGE:
            return S[v]
        if kind == RELIC:
            return R[v]
        if kind == WEAPON:
            return ids["ID_" + v]
        return v

    rows = []
    for spell, rewards in SPELLS:
        r = [(k, value(k, v)) for k, v in rewards] + [(0, 0)]
        rows.append((spell, r[0][0], r[0][1], r[1][0], r[1][1]))
    col = lambda i: ", ".join(str(row[i]) for row in rows)  # noqa: E731
    OUT.write_text(f"""// GENERATED by tools/gen_secrets.py. Do not edit.
// The original's Forbidden Scrolls spells this port honours (kind 1 character,
// 2 stage, 3 relic, 4 Arcana, 5 weapon, 6 modifier: 1 Everything, 2 Everywhere).
class DSSecretData
{{
    const COUNT = {len(rows)};
    static const String SPELL[] = {{ {", ".join('"' + r[0] + '"' for r in rows)} }};
    static const int KIND[] = {{ {col(1)} }};
    static const int VALUE[] = {{ {col(2)} }};
    static const int KIND2[] = {{ {col(3)} }};
    static const int VALUE2[] = {{ {col(4)} }};
}}
""", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(rows)} spells")


if __name__ == "__main__":
    main()
