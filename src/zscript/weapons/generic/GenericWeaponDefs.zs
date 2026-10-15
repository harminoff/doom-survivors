// Generic data-driven weapons (TODO step 5/6). Each weapon is one behaviour
// mode plus a few geometry numbers here; its per-rank damage, area, speed,
// amount, cooldown, duration, interval and pierce come from DSN3Rows (the
// wiki research rows). The engine is gameplay/slice/SliceGeneric.zs.
//
// Behaviour and geometry are engineering approximations of each weapon's
// wiki description, not source-exact. Where a research row is missing or
// implausible (area/speed under 0.2x, cooldown 0, duration 0) the labelled
// fallbacks below apply.

class DSGenericWeaponDefs
{
    enum EMode
    {
        MODE_NONE,
        MODE_PROJECTILE,    // shots at the nearest enemies
        MODE_FAN,           // short-lived cone in front of the player
        MODE_FIELD_PLAYER,  // damage zone under the player
        MODE_FIELD_ENEMY,   // damage zones on random nearby enemies
        MODE_COMPANION,     // creatures that chase enemies and bite
        MODE_STRIKE,        // instant hits on random nearby enemies
        MODE_RAIN,          // explosions at random points around the player
        MODE_FREEZE,        // freezes nearby enemies, no damage
        MODE_HALVE,         // halves nearby enemies' health and freezes them
        MODE_SHIELD,        // blocks contact damage for a moment
        MODE_RETALIATE,     // radial burst when the player is hit
        MODE_ON_CRIT,       // damage zone where any weapon lands a critical hit
        MODE_BEAM           // light columns from the sky at random spots near the player
    }

    static int Mode(int s)
    {
        switch (s)
        {
        case DSN3Rows.SYSTEM_VICTORY_SWORD: case DSN3Rows.SYSTEM_AMMO_APPALATE:
        case DSN3Rows.SYSTEM_GUNASTROPHE: case DSN3Rows.SYSTEM_GLASS_FANDANGO:
        case DSN3Rows.SYSTEM_CELESTIAL_VOULGE: case DSN3Rows.SYSTEM_SANTA_JAVELIN:
        case DSN3Rows.SYSTEM_SERAPHIC_CRY:
        case DSN3Rows.SYSTEM_PENSHIN_FATCHA:
            return MODE_PROJECTILE;
        case DSN3Rows.SYSTEM_FLAMES_OF_MISSPELL: case DSN3Rows.SYSTEM_ASHES_OF_MUSPELL:
            return MODE_FAN;
        case DSN3Rows.SYSTEM_SHADOW_PINION: case DSN3Rows.SYSTEM_VALKYRIE_TURNER:
            return MODE_FIELD_PLAYER;
        case DSN3Rows.SYSTEM_GAZE_OF_GAEA: case DSN3Rows.SYSTEM_PHAS3R:
        case DSN3Rows.SYSTEM_PHOTONSTORM: case DSN3Rows.SYSTEM_CHAOS_RUNE:
        case DSN3Rows.SYSTEM_EMBRACE_OF_GAEA: case DSN3Rows.SYSTEM_WICKED_RULER:
            return MODE_FIELD_ENEMY;
        case DSN3Rows.SYSTEM_GATTI_AMARI: case DSN3Rows.SYSTEM_VICIOUS_HUNGER:
            return MODE_COMPANION;
        case DSN3Rows.SYSTEM_UNEARTHLY_BOLT: case DSN3Rows.SYSTEM_SPIRIT_DISTURBANCE:
            return MODE_ON_CRIT;
        case DSN3Rows.SYSTEM_GREATEST_JUBILEE:
            return MODE_RAIN;
        case DSN3Rows.SYSTEM_CLOCK_LANCET:
            return MODE_FREEZE;
        case DSN3Rows.SYSTEM_INFINITE_CORRIDOR:
            return MODE_HALVE;
        case DSN3Rows.SYSTEM_LAUREL: case DSN3Rows.SYSTEM_CRIMSON_SHROUD:
            return MODE_SHIELD;
        case DSN3Rows.SYSTEM_PAKO_BATTILIAR: case DSN3Rows.SYSTEM_MAZO_FAMILIAR:
            return MODE_RETALIATE;
        case DSN3Rows.SYSTEM_SONG_OF_MANA: case DSN3Rows.SYSTEM_MANNAJJA:
            return MODE_BEAM;
        }
        return MODE_NONE;
    }

    static bool Handles(int s) { return Mode(s) != MODE_NONE; }

    // Effect/collision radius in map units at Area x1.
    static double BaseRadius(int s)
    {
        switch (Mode(s))
        {
        case MODE_PROJECTILE: return s == DSN3Rows.SYSTEM_VICTORY_SWORD || s == DSN3Rows.SYSTEM_SANTA_JAVELIN
            || s == DSN3Rows.SYSTEM_SERAPHIC_CRY ? 14.0 : 8.0;
        case MODE_FAN: return 8.0;
        case MODE_FIELD_PLAYER: return 40.0;
        case MODE_FIELD_ENEMY: return 32.0;
        case MODE_COMPANION: return 12.0;
        case MODE_STRIKE: return 20.0;
        case MODE_RAIN: return 36.0;
        case MODE_FREEZE: return 200.0;
        case MODE_HALVE: return 320.0;
        case MODE_RETALIATE: return 8.0;
        case MODE_ON_CRIT: return 28.0;
        case MODE_BEAM: return s == DSN3Rows.SYSTEM_MANNAJJA ? 30.0 : 20.0;   // Mannajja's beam is wider
        }
        return 8.0;
    }

    // Travel speed in map units per tic at Speed x1 (Magic Wand is ~9).
    static double BaseSpeed(int s)
    {
        switch (Mode(s))
        {
        case MODE_PROJECTILE: return 8.0;
        case MODE_FAN: return 6.0;
        case MODE_COMPANION: return 1.2;
        case MODE_RETALIATE: return 7.0;
        }
        return 0.0;
    }

    static Color Tint(int s)
    {
        switch (Mode(s))
        {
        case MODE_PROJECTILE: return Color(255, 255, 240, 160);
        case MODE_FAN: return Color(255, 255, 110, 30);
        case MODE_FIELD_PLAYER: return Color(255, 110, 40, 160);
        case MODE_FIELD_ENEMY: return Color(255, 60, 200, 120);
        case MODE_COMPANION: return Color(255, 240, 200, 90);
        case MODE_STRIKE: case MODE_ON_CRIT: return Color(255, 150, 200, 255);
        case MODE_RAIN: return Color(255, 255, 80, 200);
        case MODE_FREEZE: return Color(255, 120, 220, 255);
        case MODE_HALVE: return Color(255, 200, 120, 255);
        case MODE_SHIELD: return Color(255, 120, 255, 140);
        case MODE_RETALIATE: return Color(255, 255, 60, 60);
        case MODE_BEAM: return s == DSN3Rows.SYSTEM_MANNAJJA ? Color(255, 220, 120, 255) : Color(255, 120, 190, 255);
        }
        return Color(255, 255, 255, 255);
    }

    // ---- per-rank values with fallbacks ---------------------------------------

    // Weapons with no research rows: values from the wiki infobox (Embrace of
    // Gaea, Wicked Ruler) or an engineering guess (Penshin Fatcha has no level
    // table). One rank only.
    static bool Own(int s)
    {
        return s == DSN3Rows.SYSTEM_PENSHIN_FATCHA || s == DSN3Rows.SYSTEM_EMBRACE_OF_GAEA
            || s == DSN3Rows.SYSTEM_WICKED_RULER;
    }

    static int MaxRank(int s)
    {
        if (s == DSN3Rows.SYSTEM_PENSHIN_FATCHA) return 7;
        return Own(s) ? 1 : DSN3Rows.RankCount(s);
    }

    // Penshin Fatcha: every rank-up re-evolves it into one of six tuna forms,
    // each leaning on one stat; earlier forms' bonuses carry over, and the
    // seventh rank is Miracle of Multiplication (all six forms at once).
    // Per-form bonus sizes are engineering guesses (the wiki gives none).
    static String TunaName(int form)
    {
        switch (form)
        {
        case 0: return "Tonno Subito"; case 1: return "Tonnado"; case 2: return "Tonn'omoto";
        case 3: return "Tonn'oddeeo"; case 4: return "Tonne";
        }
        return "Unsurpassed";
    }

    static String TunaStat(int form)
    {
        switch (form)
        {
        case 0: return "Speed"; case 1: return "Duration"; case 2: return "Cooldown";
        case 3: return "Amount"; case 4: return "Area";
        }
        return "Might";
    }

    static int DamageMilli(int s, int r)
    {
        if (s == DSN3Rows.SYSTEM_EMBRACE_OF_GAEA) return 40000;
        if (s == DSN3Rows.SYSTEM_WICKED_RULER) return 25000;
        if (s == DSN3Rows.SYSTEM_PENSHIN_FATCHA) return 20000;
        return max(0, DSN3Rows.DamageMilli(s, r));
    }

    static int AreaMilli(int s, int r)
    {
        if (Own(s)) return 1000;
        int v = DSN3Rows.AreaMilli(s, r);
        return v < 200 ? 1000 : v;
    }

    static int SpeedMilli(int s, int r)
    {
        if (Own(s)) return 1000;
        int v = DSN3Rows.SpeedMilli(s, r);
        return v < 200 ? 1000 : v;
    }

    static int Amount(int s, int r) { return Own(s) ? 1 : clamp(DSN3Rows.Amount(s, r), 1, 32); }

    static int CooldownTics(int s, int r)
    {
        if (Own(s)) return s == DSN3Rows.SYSTEM_PENSHIN_FATCHA ? 55 : 105;
        int v = DSN3Rows.CooldownTics(s, r);
        if (Mode(s) == MODE_RETALIATE) return max(35, v);
        return v <= 0 ? 105 : v;
    }

    static int DurationTics(int s, int r)
    {
        if (s == DSN3Rows.SYSTEM_EMBRACE_OF_GAEA) return 28;
        if (s == DSN3Rows.SYSTEM_WICKED_RULER) return 10;
        if (s == DSN3Rows.SYSTEM_PENSHIN_FATCHA) return 45;
        int v = DSN3Rows.DurationTics(s, r);
        if (v > 0 && Mode(s) != MODE_PROJECTILE && Mode(s) != MODE_RETALIATE) return v;
        switch (Mode(s))
        {
        case MODE_PROJECTILE: case MODE_RETALIATE: return 45;
        case MODE_FAN: return max(v, 14);
        case MODE_FIELD_PLAYER: case MODE_FIELD_ENEMY: case MODE_ON_CRIT: case MODE_BEAM: return 70;
        case MODE_COMPANION: return 175;
        case MODE_FREEZE: case MODE_HALVE: return 105;
        case MODE_SHIELD: return 35;
        }
        return 35;
    }

    // Critical hits (wiki approximations): chance out of 1000 before Luck,
    // and the damage multiplier. Seraphic Cry's multiplier also grows with
    // Luck (applied by the engine); Spirit Disturbance's zones always crit.
    static int CritChanceMilli(int s)
    {
        switch (s)
        {
        case DSN3Rows.SYSTEM_SANTA_JAVELIN: return 100;
        case DSN3Rows.SYSTEM_SERAPHIC_CRY: return 200;
        case DSN3Rows.SYSTEM_CELESTIAL_VOULGE: return 200;
        case DSN3Rows.SYSTEM_SPIRIT_DISTURBANCE: return 1000;
        }
        return 0;
    }

    static int CritMultiplierMilli(int s)
    {
        if (s == DSN3Rows.SYSTEM_SERAPHIC_CRY) return 3000;
        return 2000;
    }

    // Damage tick for fields and companions (tics between hits on a target).
    static int TickTics(int s, int r) { return Own(s) ? 10 : max(10, DSN3Rows.IntervalTics(s, r)); }

    // Targets a projectile passes through before it ends.
    static int Pierce(int s, int r)
    {
        if (s == DSN3Rows.SYSTEM_WICKED_RULER) return 3;
        if (Own(s)) return 2;
        int v = DSN3Rows.Pierce(s, r);
        return v < 0 ? 999 : max(1, v);
    }
}
