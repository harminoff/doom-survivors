// P032 transformation recipes and atomic inventory transactions.
// Only recipe 1 is source-reported base-game content.  The remaining recipes
// are controlled engine fixtures whose IDs deliberately do not name content.
mixin class DSP032TransformationGraph
{
    const DSP032_CATEGORY_WEAPON = 1;
    const DSP032_CATEGORY_PASSIVE = 2;
    const DSP032_KIND_EVOLUTION = 1;
    const DSP032_KIND_UNION = 2;
    const DSP032_KIND_GIFT = 3;
    const DSP032_KIND_REPLACEMENT = 4;
    const DSP032_GRAPH_CHEST_SILVER = 2;
    const DSP032_ID_WHIP = 1;
    const DSP032_ID_HOLLOW_HEART = 5;
    const DSP032_ID_BLOODY_TEAR = 6;
    // P042 paired-union item ids reuse the DSP042Paired system numbering
    // (docs/contracts/paired-unions.md) so the graph and the runtime agree
    // on which weapon each id names.
    const DSP032_ID_PEACHONE = 59;
    const DSP032_ID_EBONY_WINGS = 60;
    const DSP032_ID_VANDALIER = 61;
    const DSP032_ID_PHIERA = 62;
    const DSP032_ID_EIGHT = 63;
    const DSP032_ID_PHIERAGGI = 64;
    const DSP032_ID_VENTO_SACRO = 65;
    const DSP032_ID_FUWALAFUWALOO = 66;
    const DSP032_ID_BRACELET = 67;
    const DSP032_ID_BI_BRACELET = 68;
    const DSP032_ID_TRI_BRACELET = 69;
    // Tirajisu (REVIVAL passive) gates the Phieraggi union per the contract
    // but is never consumed by it.
    const DSP032_ID_TIRAJISU = 70;
    const DSP032_RECIPE_WHIP_BLOODY_TEAR = 1;
    const DSP032_RECIPE_FIXTURE_UNION = 101;
    const DSP032_RECIPE_FIXTURE_GIFT = 102;
    const DSP032_RECIPE_FIXTURE_REPLACEMENT = 103;
    // P042 real recipes: three unions plus the Bracelet chain evolutions.
    // These use slot-preserving insertion (contract "lower slot index"
    // transaction) instead of the append-at-end behaviour kept for the
    // pre-existing fixture recipes above, so P032's older tests must not
    // observe any change.
    const DSP032_RECIPE_UNION_VANDALIER = 201;
    const DSP032_RECIPE_UNION_PHIERAGGI = 202;
    const DSP032_RECIPE_UNION_FUWALAFUWALOO = 203;
    const DSP032_RECIPE_CHAIN_BRACELET_BI = 204;
    const DSP032_RECIPE_CHAIN_BI_TRI = 205;
    // N2-W5 (docs/contracts/normal-play-integration.md "Evolutions and
    // chests"): the eleven remaining accepted base-game evolutions, each
    // gated on its weapon input at max rank (INFERENCE, same rule as recipe
    // 1) plus its passive at rank>=1 (never consumed). Weapon/evolved system
    // ids reuse each engine's own DSP03xWeaponRows/DSP03xRows numbering so
    // DSP032Rank/DSP032Category read the same ids the N2 dispatcher (n2System)
    // already tracks; passive ids reuse DSN2Catalog's numbering.
    const DSP032_RECIPE_HOLY_WAND = 301;
    const DSP032_RECIPE_THOUSAND_EDGE = 302;
    const DSP032_RECIPE_DEATH_SPIRAL = 303;
    const DSP032_RECIPE_HELLFIRE = 304;
    const DSP032_RECIPE_HEAVEN_SWORD = 305;
    const DSP032_RECIPE_UNHOLY_VESPERS = 306;
    const DSP032_RECIPE_LA_BORRA = 307;
    const DSP032_RECIPE_SOUL_EATER = 308;
    const DSP032_RECIPE_THUNDER_LOOP = 309;
    const DSP032_RECIPE_GORGEOUS_MOON = 310;
    const DSP032_RECIPE_NO_FUTURE = 311;
    // N3 remaining base-game evolutions (docs/contracts/remaining-weapons.md):
    // 19 of the 20 outstanding evolutions follow the same weapon(max)+passive(>=1)
    // pattern as 301-311. Miracle of Multiplication (Penshin Fatcha family) is
    // deliberately NOT wired here: its source input is "any accumulated forms"
    // of the Track-B selector chain, not a single weapon+passive pair, so it
    // does not fit this binary recipe model and is left to the selector-chain
    // engine task instead of being force-fit or invented.
    const DSP032_RECIPE_N3_VICIOUS_HUNGER = 401;
    const DSP032_RECIPE_N3_MANNAJJA = 402;
    const DSP032_RECIPE_N3_VALKYRIE_TURNER = 403;
    const DSP032_RECIPE_N3_INFINITE_CORRIDOR = 404;
    const DSP032_RECIPE_N3_CRIMSON_SHROUD = 405;
    const DSP032_RECIPE_N3_PROFUSIONE_DAMORE = 406;
    const DSP032_RECIPE_N3_ASHES_OF_MUSPELL = 407;
    const DSP032_RECIPE_N3_MAZO_FAMILIAR = 408;
    const DSP032_RECIPE_N3_GUNASTROPHE = 409;
    const DSP032_RECIPE_N3_SPIRIT_DISTURBANCE = 410;
    const DSP032_RECIPE_N3_CELESTIAL_VOULGE = 411;
    const DSP032_RECIPE_N3_SERAPHIC_CRY = 412;
    const DSP032_RECIPE_N3_EMBRACE_OF_GAEA = 413;
    const DSP032_RECIPE_N3_KYRA_STONES = 414;
    const DSP032_RECIPE_N3_PHOTONSTORM = 415;
    const DSP032_RECIPE_N3_WICKED_RULER = 416;
    const DSP032_RECIPE_N3_ANIMA_OF_MORTACCIO = 417;
    const DSP032_RECIPE_N3_YATTA_DAIKARIN = 418;
    const DSP032_RECIPE_N3_CARROZZA = 419;
    const DSP032_ID_MAGIC_WAND = 34;
    const DSP032_ID_HOLY_WAND = 35;
    const DSP032_ID_KNIFE = 36;
    const DSP032_ID_THOUSAND_EDGE = 37;
    const DSP032_ID_AXE = 38;
    const DSP032_ID_DEATH_SPIRAL = 39;
    const DSP032_ID_FIRE_WAND = 40;
    const DSP032_ID_HELLFIRE = 41;
    const DSP032_ID_CROSS = 42;
    const DSP032_ID_HEAVEN_SWORD = 43;
    const DSP032_ID_KING_BIBLE = 44;
    const DSP032_ID_UNHOLY_VESPERS = 45;
    const DSP032_ID_HOLYWATER = 46;
    const DSP032_ID_LA_BORRA = 47;
    const DSP032_ID_GARLIC = 48;
    const DSP032_ID_SOUL_EATER = 49;
    const DSP032_ID_LIGHTNING_RING = 50;
    const DSP032_ID_THUNDER_LOOP = 51;
    const DSP032_ID_PENTAGRAM = 52;
    const DSP032_ID_GORGEOUS_MOON = 53;
    const DSP032_ID_RUNETRACER = 54;
    const DSP032_ID_NO_FUTURE = 55;
    const DSP032_ID_SPINACH = 2;
    const DSP032_ID_ARMOR = 3;
    const DSP032_ID_EMPTY_TOME = 7;
    const DSP032_ID_PUMMAROLA = 8;
    const DSP032_ID_DUPLICATOR = 9;
    const DSP032_ID_CROWN = 10;
    const DSP032_ID_ATTRACTORB = 71;
    const DSP032_ID_CANDELABRADOR = 72;
    const DSP032_ID_CLOVER = 73;
    const DSP032_ID_BRACER = 74;
    const DSP032_ID_SPELLBINDER = 75;
    // N3 weapon ids (docs/contracts/remaining-weapons.md), matching
    // DSN3Rows.SYSTEM_*/DSN2Catalog.ID_N3_* verbatim.
    const DSP032_ID_N3_AMMO_APPALATE = 96;
    const DSP032_ID_N3_ANIMA_OF_MORTACCIO = 123;
    const DSP032_ID_N3_ARMA_DIO = 122;
    const DSP032_ID_N3_ASHES_OF_MUSPELL = 93;
    const DSP032_ID_N3_CANDYBOX = 90;
    const DSP032_ID_N3_CARROZZA = 125;
    const DSP032_ID_N3_CELESTIAL_DUSTING = 86;
    const DSP032_ID_N3_CELESTIAL_VOULGE = 103;
    const DSP032_ID_N3_CHAOS_RUNE = 120;
    const DSP032_ID_N3_CLOCK_LANCET = 82;
    const DSP032_ID_N3_CRIMSON_SHROUD = 85;
    const DSP032_ID_N3_EMBRACE_OF_GAEA = 115;
    const DSP032_ID_N3_FLAMES_OF_MISSPELL = 92;
    const DSP032_ID_N3_GATTI_AMARI = 76;
    const DSP032_ID_N3_GAZE_OF_GAEA = 114;
    const DSP032_ID_N3_GLASS_FANDANGO = 102;
    const DSP032_ID_N3_GREATEST_JUBILEE = 89;
    const DSP032_ID_N3_GUNASTROPHE = 97;
    const DSP032_ID_N3_INFINITE_CORRIDOR = 83;
    const DSP032_ID_N3_KYRA_STONES = 117;
    const DSP032_ID_N3_LA_ROBBA = 88;
    const DSP032_ID_N3_LAUREL = 84;
    const DSP032_ID_N3_MAGI_STONE = 116;
    const DSP032_ID_N3_MANNAJJA = 79;
    const DSP032_ID_N3_MAZO_FAMILIAR = 95;
    const DSP032_ID_N3_MIRACLE_OF_MULTIPLICATION = 111;
    const DSP032_ID_N3_PAKO_BATTILIAR = 94;
    const DSP032_ID_N3_PENSHIN_FATCHA = 104;
    const DSP032_ID_N3_PHAS3R = 118;
    const DSP032_ID_N3_PHOTONSTORM = 119;
    const DSP032_ID_N3_PROFUSIONE_DAMORE = 87;
    const DSP032_ID_N3_SANTA_JAVELIN = 112;
    const DSP032_ID_N3_SERAPHIC_CRY = 113;
    const DSP032_ID_N3_SHADOW_PINION = 80;
    const DSP032_ID_N3_SONG_OF_MANA = 78;
    const DSP032_ID_N3_SPIRIT_DISTURBANCE = 99;
    const DSP032_ID_N3_TONN_ODDEEO = 108;
    const DSP032_ID_N3_TONN_OMOTO = 107;
    const DSP032_ID_N3_TONNADO = 106;
    const DSP032_ID_N3_TONNE = 109;
    const DSP032_ID_N3_TONNO_SUBITO = 105;
    const DSP032_ID_N3_UNEARTHLY_BOLT = 98;
    const DSP032_ID_N3_UNSURPASSED = 110;
    const DSP032_ID_N3_VALKYRIE_TURNER = 81;
    const DSP032_ID_N3_VICIOUS_HUNGER = 77;
    const DSP032_ID_N3_VICTORY_SWORD = 91;
    const DSP032_ID_N3_WICKED_RULER = 121;
    const DSP032_ID_N3_YATTA_DAIKARIN = 124;
    // Already-implemented base weapons needed as N3 evolution inputs.
    const DSP032_ID_BONE = 56;
    const DSP032_ID_CHERRY_BOMB = 57;
    const DSP032_ID_CARRELLO = 58;
    // N3 new passives (docs/contracts/remaining-weapons.md), matching
    // DSN2Catalog.ID_N3_* verbatim.
    const DSP032_ID_N3_STONE_MASK = 126;
    const DSP032_ID_N3_SKULL_O_MANIAC = 127;
    const DSP032_ID_N3_WINGS = 128;
    const DSP032_ID_N3_SILVER_RING = 129;
    const DSP032_ID_N3_METAGLIO_LEFT = 130;
    const DSP032_ID_N3_METAGLIO_RIGHT = 131;
    const DSP032_ID_N3_CHAOS_ALTEMANNA = 132;
    const DSP032_ID_N3_TORRONA_S_BOX = 133;
    const DSP032_ID_N3_PARM_AEGIS = 134;
    const DSP032_ID_N3_KAROMA_S_MANA = 135;
    const DSP032_ID_N3_CHAOS_MALACHITE = 136;
    const DSP032_ID_N3_CHAOS_ROSALIA = 137;
    const DSP032_ID_N3_CHAOS_LAZULIA = 138;
    const DSP032_ID_N3_GOLD_RING = 139;
    const DSP032_FIXTURE_UNION_LEFT = 1001;
    const DSP032_FIXTURE_UNION_RIGHT = 1002;
    const DSP032_FIXTURE_UNION_RESULT = 1003;
    const DSP032_FIXTURE_UNION_FILLER_A = 1004;
    const DSP032_FIXTURE_UNION_FILLER_B = 1005;
    const DSP032_FIXTURE_UNION_FILLER_C = 1006;
    const DSP032_FIXTURE_UNION_FILLER_D = 1007;
    const DSP032_FIXTURE_UNION_FILLER_E = 1008;
    const DSP032_FIXTURE_UNION_FILLER_F = 1009;
    const DSP032_FIXTURE_GIFT_SOURCE = 1010;
    const DSP032_FIXTURE_GIFT_RESULT = 1011;
    const DSP032_FIXTURE_GIFT_FILLER_A = 1012;
    const DSP032_FIXTURE_GIFT_FILLER_B = 1013;
    const DSP032_FIXTURE_GIFT_FILLER_C = 1014;
    const DSP032_FIXTURE_GIFT_FILLER_D = 1015;
    const DSP032_FIXTURE_GIFT_FILLER_E = 1016;
    const DSP032_FIXTURE_REPLACEMENT_SOURCE = 1020;
    const DSP032_FIXTURE_REPLACEMENT_RESULT = 1021;
    const DSP032_FIXTURE_REPLACEMENT_FILLER_A = 1022;
    const DSP032_FIXTURE_REPLACEMENT_FILLER_B = 1023;
    const DSP032_FIXTURE_REPLACEMENT_FILLER_C = 1024;
    const DSP032_FIXTURE_REPLACEMENT_FILLER_D = 1025;
    const DSP032_FIXTURE_REPLACEMENT_FILLER_E = 1026;
    const DSP032_FIXTURE_REWARD_A = 1101;
    const DSP032_FIXTURE_REWARD_B = 1102;
    const DSP032_FIXTURE_REWARD_C = 1103;
    // N2-W6 evolution-evidence fixture: the manual/soak_n2 full-catalog route
    // never un-equips a passive gate (evolution recipes only ever remove
    // inputA, per DSP032ApplyRecipe below) and every completed evolution's
    // output also lingers forever, so exercising every recipe once (1,
    // 201-205, 301-311) through real chests permanently accumulates 13
    // passives + Whip + up to 17 evolution/union outputs -- about 30 items
    // at peak, once every recipe has applied. 16 was sized for the small,
    // hand-seeded P032 unit fixtures above (DSP032Seed*Fixture, at most 8
    // items) and is otherwise unreferenced by any test or contract value, so
    // raising it here only unblocks the full-catalog route from silently
    // dropping later SetItem/AcquireItem calls once inventory crosses 16;
    // it does not relax any recipe predicate or slot-limit check.
    // N3 Track A (bounce engine, this worker): raised again from 48 to 64.
    // An actual evolution-fixture run showed recipes 417/418/419 (whose
    // weapon inputs -- Bone/Cherry Bomb/Carréllo -- are granted late, in
    // batch 4 at tic ~1960, well after 18+ other items have already
    // accumulated) never becoming eligible: DSP032SetItem silently fails to
    // add a brand-new item once dsp032ItemIds.Size() reaches this cap, so
    // DSP032Rank(56/57/58) kept reading 0 in the graph even though the real
    // AcquireWeapon dispatcher owned them, permanently failing
    // DSP032CanApplyRecipe's `DSP032Rank(inputA) <= 0` gate for those three
    // recipes. Recipe 406 (whose input, Celestial Dusting, is also a batch-4
    // grant) happened to squeak through only because its own sync landed at
    // a lower item count that cycle.
    // 96: the evolution fixture holds every passive gate (Gold Ring and
    // Metaglio Right added two) plus each batch's weapons and outputs.
    const DSP032_MAX_ITEMS = 96;
    const DSP032_MAX_TRANSACTIONS = 96;
    const DSP032_NORMAL_WEAPON_SLOTS = 6;
    const DSP032_NORMAL_PASSIVE_SLOTS = 6;

    Array<int> dsp032ItemIds;
    Array<int> dsp032ItemRanks;
    Array<int> dsp032TransactionIds;
    int dsp032WeaponExtraSlots;
    int dsp032PassiveExtraSlots;
    int dsp032FixtureMode;

    int DSP032IndexOf(int id)
    {
        for (int i = 0; i < dsp032ItemIds.Size(); i++)
            if (dsp032ItemIds[i] == id) return i;
        return -1;
    }

    int DSP032Rank(int id)
    {
        int index = DSP032IndexOf(id);
        return index < 0 ? 0 : dsp032ItemRanks[index];
    }

    int DSP032Category(int id)
    {
        if (id == DSP032_ID_WHIP || id == DSP032_ID_BLOODY_TEAR
            // N3 Track A (bounce engine, this worker): DSP032_ID_MAGIC_WAND
            // (34) through DSP032_ID_TRI_BRACELET (69) is one unbroken run
            // of weapon-only ids (verified against DSN2Catalog/DSP03x*Rows'
            // own SYSTEM_* numbering); the original two separate ranges
            // (34-55, 59-69) left a gap at 56-58 (Bone/Cherry Bomb/
            // Carréllo) that silently fell through to the default
            // CATEGORY_PASSIVE below. That gap was never exercised before
            // this worker's recipes 417/418/419 (Bone/Cherry Bomb/Carréllo
            // -> Anima of Mortaccio/Yatta Daikarin/Carrozza!), whose
            // DSP032CanApplyRecipe evolution-category-match check
            // (`DSP032Category(inputA) != DSP032Category(output)`) an
            // actual run showed silently rejecting all three: inputA
            // (PASSIVE, wrongly) never matched output (WEAPON, correctly,
            // 102-125).
            || (id >= DSP032_ID_MAGIC_WAND && id <= DSP032_ID_TRI_BRACELET)
            // N3 weapon id blocks (76-99, 102-125; 100/101 are the reserved
            // SYSTEM_PLAYER_HEALTH/SYSTEM_INCOMING_DAMAGE stat systems, never
            // catalog item ids, so the two N3 blocks skip over them).
            || (id >= 76 && id <= 99) || (id >= 102 && id <= 125)
            || (id >= DSP032_FIXTURE_UNION_LEFT && id <= DSP032_FIXTURE_UNION_FILLER_F)
            || (id >= DSP032_FIXTURE_REPLACEMENT_SOURCE && id <= DSP032_FIXTURE_REPLACEMENT_FILLER_E))
            return DSP032_CATEGORY_WEAPON;
        if (id >= DSP032_FIXTURE_GIFT_SOURCE && id <= DSP032_FIXTURE_GIFT_FILLER_E)
            return DSP032_CATEGORY_PASSIVE;
        return DSP032_CATEGORY_PASSIVE;
    }

    // P042 recipes are the only ones needing slot-preserving insertion; the
    // pre-existing fixture recipes keep appending at the end so their tests
    // keep observing identical inventory hashes.
    bool DSP032RecipeIsPositional(int recipeId)
    {
        return recipeId == DSP032_RECIPE_UNION_VANDALIER
            || recipeId == DSP032_RECIPE_UNION_PHIERAGGI
            || recipeId == DSP032_RECIPE_UNION_FUWALAFUWALOO
            || recipeId == DSP032_RECIPE_CHAIN_BRACELET_BI
            || recipeId == DSP032_RECIPE_CHAIN_BI_TRI;
    }

    // Weapon-input rank ceiling for the P042 union/chain predicates. Bloody
    // Tear's only rank is 1 (P032 fixture); the paired weapons and the
    // Bracelet chain are 8/8/6 per the contract's identities table.
    int DSP032MaxRankForItem(int id)
    {
        if (id == DSP032_ID_BLOODY_TEAR) return 1;
        if (id == DSP032_ID_BRACELET || id == DSP032_ID_BI_BRACELET) return 6;
        // N3 weapon inputs whose own RankCount (DSN3Rows.RankCount) is not 8:
        // Clock Lancet and Laurel both cap at rank 7 per their infoboxes.
        if (id == DSP032_ID_N3_CLOCK_LANCET || id == DSP032_ID_N3_LAUREL) return 7;
        return 8;
    }

    // Rank the passive input must reach (original requiresMax); 0 = any rank.
    int DSP032RecipePassiveMinRank(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_N3_INFINITE_CORRIDOR
            || recipeId == DSP032_RECIPE_N3_CRIMSON_SHROUD
            || recipeId == DSP032_RECIPE_N3_ASHES_OF_MUSPELL) return 9;
        if (recipeId == DSP032_RECIPE_N3_MAZO_FAMILIAR
            || recipeId == DSP032_RECIPE_N3_GUNASTROPHE
            || recipeId == DSP032_RECIPE_N3_CELESTIAL_VOULGE
            || recipeId == DSP032_RECIPE_N3_SERAPHIC_CRY
            || recipeId == DSP032_RECIPE_N3_PHOTONSTORM) return 5;
        if (recipeId == DSP032_RECIPE_N3_SPIRIT_DISTURBANCE) return 2;
        return 0;
    }

    // Second passive an evolution needs (at the same rank), never consumed.
    int DSP032RecipeSecondPassive(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_N3_INFINITE_CORRIDOR) return DSP032_ID_N3_GOLD_RING;
        if (recipeId == DSP032_RECIPE_N3_CRIMSON_SHROUD) return DSP032_ID_N3_METAGLIO_RIGHT;
        return 0;
    }

    // Passive gate required (rank >= 1, never consumed) for a P042 union.
    // Zero means no passive gate.
    int DSP032RecipeRequiredPassive(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_UNION_PHIERAGGI) return DSP032_ID_TIRAJISU;
        return 0;
    }

    // N2-W5 standard evolutions (301-311): weapon input must be at max rank
    // (INFERENCE, same rule recipe 1 already applies via its own special
    // case), independent of the P042 positional-insertion behaviour so
    // recipes 1/101-103/201-205 stay byte-identical.
    bool DSP032RecipeRequiresMaxRankInputA(int recipeId)
    {
        return (recipeId >= DSP032_RECIPE_HOLY_WAND && recipeId <= DSP032_RECIPE_NO_FUTURE)
            || (recipeId >= DSP032_RECIPE_N3_VICIOUS_HUNGER && recipeId <= DSP032_RECIPE_N3_CARROZZA);
    }

    int DSP032OwnedSlots(int category)
    {
        // Occupancy counts owned items only. Extra slots change capacity, not
        // the number of occupied slots.
        int count = 0;
        for (int i = 0; i < dsp032ItemIds.Size(); i++)
            if (DSP032Category(dsp032ItemIds[i]) == category) count++;
        return count;
    }

    int DSP032ExtraSlots(int category)
    {
        return category == DSP032_CATEGORY_WEAPON ? dsp032WeaponExtraSlots
            : dsp032PassiveExtraSlots;
    }

    int DSP032SlotLimit(int category)
    {
        return (category == DSP032_CATEGORY_WEAPON ? DSP032_NORMAL_WEAPON_SLOTS
            : DSP032_NORMAL_PASSIVE_SLOTS) + DSP032ExtraSlots(category);
    }

    bool DSP032SetItem(int id, int rank)
    {
        if (id <= 0 || rank <= 0 || dsp032ItemIds.Size() > DSP032_MAX_ITEMS) return false;
        int index = DSP032IndexOf(id);
        if (index >= 0) { dsp032ItemRanks[index] = rank; return true; }
        if (dsp032ItemIds.Size() >= DSP032_MAX_ITEMS) return false;
        dsp032ItemIds.Push(id);
        dsp032ItemRanks.Push(rank);
        return true;
    }

    void DSP032RemoveIndex(int index)
    {
        if (index < 0 || index >= dsp032ItemIds.Size()) return;
        dsp032ItemIds.Delete(index);
        dsp032ItemRanks.Delete(index);
    }

    void DSP032ResetInventory()
    {
        dsp032ItemIds.Clear();
        dsp032ItemRanks.Clear();
        dsp032TransactionIds.Clear();
        dsp032WeaponExtraSlots = 0;
        dsp032PassiveExtraSlots = 0;
        dsp032FixtureMode = 1;
    }

    void DSP032SeedWhipEvolutionFixture()
    {
        DSP032ResetInventory();
        DSP032SetItem(DSP032_ID_WHIP, 8);
        DSP032SetItem(DSP032_ID_HOLLOW_HEART, 1);
    }

    void DSP032SeedUnionFixture(bool fullWeaponSlots)
    {
        DSP032ResetInventory();
        DSP032SetItem(DSP032_FIXTURE_UNION_LEFT, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_RIGHT, 1);
        if (fullWeaponSlots)
        {
            DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_A, 1);
            DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_B, 1);
            DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_C, 1);
            DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_D, 1);
        }
    }

    void DSP032SeedUnionExtraFixture()
    {
        DSP032ResetInventory();
        DSP032SetItem(DSP032_FIXTURE_UNION_LEFT, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_RIGHT, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_A, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_B, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_C, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_D, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_E, 1);
        DSP032SetItem(DSP032_FIXTURE_UNION_FILLER_F, 1);
        dsp032WeaponExtraSlots = 2;
    }

    void DSP032SeedGiftFixture(bool fullPassiveSlots)
    {
        DSP032ResetInventory();
        DSP032SetItem(DSP032_FIXTURE_GIFT_SOURCE, 1);
        if (fullPassiveSlots)
        {
            DSP032SetItem(DSP032_FIXTURE_GIFT_FILLER_A, 1);
            DSP032SetItem(DSP032_FIXTURE_GIFT_FILLER_B, 1);
            DSP032SetItem(DSP032_FIXTURE_GIFT_FILLER_C, 1);
            DSP032SetItem(DSP032_FIXTURE_GIFT_FILLER_D, 1);
            DSP032SetItem(DSP032_FIXTURE_GIFT_FILLER_E, 1);
        }
    }

    void DSP032SeedGiftExtraFixture()
    {
        DSP032SeedGiftFixture(true);
        dsp032PassiveExtraSlots = 1;
    }

    void DSP032SeedReplacementFixture()
    {
        DSP032ResetInventory();
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_SOURCE, 1);
    }

    void DSP032SeedReplacementFullFixture()
    {
        DSP032SeedReplacementFixture();
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_FILLER_A, 1);
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_FILLER_B, 1);
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_FILLER_C, 1);
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_FILLER_D, 1);
        DSP032SetItem(DSP032_FIXTURE_REPLACEMENT_FILLER_E, 1);
    }

    int DSP032RecipeKind(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_WHIP_BLOODY_TEAR) return DSP032_KIND_EVOLUTION;
        if (recipeId == DSP032_RECIPE_FIXTURE_UNION) return DSP032_KIND_UNION;
        if (recipeId == DSP032_RECIPE_FIXTURE_GIFT) return DSP032_KIND_GIFT;
        if (recipeId == DSP032_RECIPE_FIXTURE_REPLACEMENT) return DSP032_KIND_REPLACEMENT;
        if (recipeId == DSP032_RECIPE_UNION_VANDALIER
            || recipeId == DSP032_RECIPE_UNION_PHIERAGGI
            || recipeId == DSP032_RECIPE_UNION_FUWALAFUWALOO) return DSP032_KIND_UNION;
        if (recipeId == DSP032_RECIPE_CHAIN_BRACELET_BI
            || recipeId == DSP032_RECIPE_CHAIN_BI_TRI) return DSP032_KIND_EVOLUTION;
        if (DSP032RecipeRequiresMaxRankInputA(recipeId)) return DSP032_KIND_EVOLUTION;
        return 0;
    }

    int DSP032RecipeInputA(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_WHIP_BLOODY_TEAR) return DSP032_ID_WHIP;
        if (recipeId == DSP032_RECIPE_FIXTURE_UNION) return DSP032_FIXTURE_UNION_LEFT;
        if (recipeId == DSP032_RECIPE_FIXTURE_GIFT) return DSP032_FIXTURE_GIFT_SOURCE;
        if (recipeId == DSP032_RECIPE_FIXTURE_REPLACEMENT) return DSP032_FIXTURE_REPLACEMENT_SOURCE;
        if (recipeId == DSP032_RECIPE_UNION_VANDALIER) return DSP032_ID_PEACHONE;
        if (recipeId == DSP032_RECIPE_UNION_PHIERAGGI) return DSP032_ID_PHIERA;
        if (recipeId == DSP032_RECIPE_UNION_FUWALAFUWALOO) return DSP032_ID_VENTO_SACRO;
        if (recipeId == DSP032_RECIPE_CHAIN_BRACELET_BI) return DSP032_ID_BRACELET;
        if (recipeId == DSP032_RECIPE_CHAIN_BI_TRI) return DSP032_ID_BI_BRACELET;
        if (recipeId == DSP032_RECIPE_HOLY_WAND) return DSP032_ID_MAGIC_WAND;
        if (recipeId == DSP032_RECIPE_THOUSAND_EDGE) return DSP032_ID_KNIFE;
        if (recipeId == DSP032_RECIPE_DEATH_SPIRAL) return DSP032_ID_AXE;
        if (recipeId == DSP032_RECIPE_HELLFIRE) return DSP032_ID_FIRE_WAND;
        if (recipeId == DSP032_RECIPE_HEAVEN_SWORD) return DSP032_ID_CROSS;
        if (recipeId == DSP032_RECIPE_UNHOLY_VESPERS) return DSP032_ID_KING_BIBLE;
        if (recipeId == DSP032_RECIPE_LA_BORRA) return DSP032_ID_HOLYWATER;
        if (recipeId == DSP032_RECIPE_SOUL_EATER) return DSP032_ID_GARLIC;
        if (recipeId == DSP032_RECIPE_THUNDER_LOOP) return DSP032_ID_LIGHTNING_RING;
        if (recipeId == DSP032_RECIPE_GORGEOUS_MOON) return DSP032_ID_PENTAGRAM;
        if (recipeId == DSP032_RECIPE_NO_FUTURE) return DSP032_ID_RUNETRACER;
        if (recipeId == DSP032_RECIPE_N3_VICIOUS_HUNGER) return DSP032_ID_N3_GATTI_AMARI;
        if (recipeId == DSP032_RECIPE_N3_MANNAJJA) return DSP032_ID_N3_SONG_OF_MANA;
        if (recipeId == DSP032_RECIPE_N3_VALKYRIE_TURNER) return DSP032_ID_N3_SHADOW_PINION;
        if (recipeId == DSP032_RECIPE_N3_INFINITE_CORRIDOR) return DSP032_ID_N3_CLOCK_LANCET;
        if (recipeId == DSP032_RECIPE_N3_CRIMSON_SHROUD) return DSP032_ID_N3_LAUREL;
        if (recipeId == DSP032_RECIPE_N3_PROFUSIONE_DAMORE) return DSP032_ID_N3_CELESTIAL_DUSTING;
        if (recipeId == DSP032_RECIPE_N3_ASHES_OF_MUSPELL) return DSP032_ID_N3_FLAMES_OF_MISSPELL;
        if (recipeId == DSP032_RECIPE_N3_MAZO_FAMILIAR) return DSP032_ID_N3_PAKO_BATTILIAR;
        if (recipeId == DSP032_RECIPE_N3_GUNASTROPHE) return DSP032_ID_N3_AMMO_APPALATE;
        if (recipeId == DSP032_RECIPE_N3_SPIRIT_DISTURBANCE) return DSP032_ID_N3_UNEARTHLY_BOLT;
        if (recipeId == DSP032_RECIPE_N3_CELESTIAL_VOULGE) return DSP032_ID_N3_GLASS_FANDANGO;
        if (recipeId == DSP032_RECIPE_N3_SERAPHIC_CRY) return DSP032_ID_N3_SANTA_JAVELIN;
        if (recipeId == DSP032_RECIPE_N3_EMBRACE_OF_GAEA) return DSP032_ID_N3_GAZE_OF_GAEA;
        if (recipeId == DSP032_RECIPE_N3_KYRA_STONES) return DSP032_ID_N3_MAGI_STONE;
        if (recipeId == DSP032_RECIPE_N3_PHOTONSTORM) return DSP032_ID_N3_PHAS3R;
        if (recipeId == DSP032_RECIPE_N3_WICKED_RULER) return DSP032_ID_N3_CHAOS_RUNE;
        if (recipeId == DSP032_RECIPE_N3_ANIMA_OF_MORTACCIO) return DSP032_ID_BONE;
        if (recipeId == DSP032_RECIPE_N3_YATTA_DAIKARIN) return DSP032_ID_CHERRY_BOMB;
        if (recipeId == DSP032_RECIPE_N3_CARROZZA) return DSP032_ID_CARRELLO;
        return 0;
    }

    int DSP032RecipeInputB(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_WHIP_BLOODY_TEAR) return DSP032_ID_HOLLOW_HEART;
        if (recipeId == DSP032_RECIPE_FIXTURE_UNION) return DSP032_FIXTURE_UNION_RIGHT;
        if (recipeId == DSP032_RECIPE_UNION_VANDALIER) return DSP032_ID_EBONY_WINGS;
        if (recipeId == DSP032_RECIPE_UNION_PHIERAGGI) return DSP032_ID_EIGHT;
        if (recipeId == DSP032_RECIPE_UNION_FUWALAFUWALOO) return DSP032_ID_BLOODY_TEAR;
        if (recipeId == DSP032_RECIPE_HOLY_WAND) return DSP032_ID_EMPTY_TOME;
        if (recipeId == DSP032_RECIPE_THOUSAND_EDGE) return DSP032_ID_BRACER;
        if (recipeId == DSP032_RECIPE_DEATH_SPIRAL) return DSP032_ID_CANDELABRADOR;
        if (recipeId == DSP032_RECIPE_HELLFIRE) return DSP032_ID_SPINACH;
        if (recipeId == DSP032_RECIPE_HEAVEN_SWORD) return DSP032_ID_CLOVER;
        if (recipeId == DSP032_RECIPE_UNHOLY_VESPERS) return DSP032_ID_SPELLBINDER;
        if (recipeId == DSP032_RECIPE_LA_BORRA) return DSP032_ID_ATTRACTORB;
        if (recipeId == DSP032_RECIPE_SOUL_EATER) return DSP032_ID_PUMMAROLA;
        if (recipeId == DSP032_RECIPE_THUNDER_LOOP) return DSP032_ID_DUPLICATOR;
        if (recipeId == DSP032_RECIPE_GORGEOUS_MOON) return DSP032_ID_CROWN;
        if (recipeId == DSP032_RECIPE_NO_FUTURE) return DSP032_ID_ARMOR;
        if (recipeId == DSP032_RECIPE_N3_VICIOUS_HUNGER) return DSP032_ID_N3_STONE_MASK;
        if (recipeId == DSP032_RECIPE_N3_MANNAJJA) return DSP032_ID_N3_SKULL_O_MANIAC;
        if (recipeId == DSP032_RECIPE_N3_VALKYRIE_TURNER) return DSP032_ID_N3_WINGS;
        if (recipeId == DSP032_RECIPE_N3_INFINITE_CORRIDOR) return DSP032_ID_N3_SILVER_RING;
        if (recipeId == DSP032_RECIPE_N3_CRIMSON_SHROUD) return DSP032_ID_N3_METAGLIO_LEFT;
        if (recipeId == DSP032_RECIPE_N3_PROFUSIONE_DAMORE) return DSP032_ID_N3_CHAOS_ALTEMANNA;
        if (recipeId == DSP032_RECIPE_N3_ASHES_OF_MUSPELL) return DSP032_ID_N3_TORRONA_S_BOX;
        if (recipeId == DSP032_RECIPE_N3_MAZO_FAMILIAR) return DSP032_ID_HOLLOW_HEART;
        if (recipeId == DSP032_RECIPE_N3_GUNASTROPHE) return DSP032_ID_BRACER;
        if (recipeId == DSP032_RECIPE_N3_SPIRIT_DISTURBANCE) return DSP032_ID_TIRAJISU;
        if (recipeId == DSP032_RECIPE_N3_CELESTIAL_VOULGE) return DSP032_ID_N3_WINGS;
        if (recipeId == DSP032_RECIPE_N3_SERAPHIC_CRY) return DSP032_ID_CLOVER;
        if (recipeId == DSP032_RECIPE_N3_EMBRACE_OF_GAEA) return DSP032_ID_N3_PARM_AEGIS;
        if (recipeId == DSP032_RECIPE_N3_KYRA_STONES) return DSP032_ID_N3_KAROMA_S_MANA;
        if (recipeId == DSP032_RECIPE_N3_PHOTONSTORM) return DSP032_ID_EMPTY_TOME;
        if (recipeId == DSP032_RECIPE_N3_WICKED_RULER) return DSP032_ID_SPELLBINDER;
        if (recipeId == DSP032_RECIPE_N3_ANIMA_OF_MORTACCIO) return DSP032_ID_N3_CHAOS_MALACHITE;
        if (recipeId == DSP032_RECIPE_N3_YATTA_DAIKARIN) return DSP032_ID_N3_CHAOS_ROSALIA;
        if (recipeId == DSP032_RECIPE_N3_CARROZZA) return DSP032_ID_N3_CHAOS_LAZULIA;
        return 0;
    }

    int DSP032RecipeOutput(int recipeId)
    {
        if (recipeId == DSP032_RECIPE_WHIP_BLOODY_TEAR) return DSP032_ID_BLOODY_TEAR;
        if (recipeId == DSP032_RECIPE_FIXTURE_UNION) return DSP032_FIXTURE_UNION_RESULT;
        if (recipeId == DSP032_RECIPE_FIXTURE_GIFT) return DSP032_FIXTURE_GIFT_RESULT;
        if (recipeId == DSP032_RECIPE_FIXTURE_REPLACEMENT) return DSP032_FIXTURE_REPLACEMENT_RESULT;
        if (recipeId == DSP032_RECIPE_UNION_VANDALIER) return DSP032_ID_VANDALIER;
        if (recipeId == DSP032_RECIPE_UNION_PHIERAGGI) return DSP032_ID_PHIERAGGI;
        if (recipeId == DSP032_RECIPE_UNION_FUWALAFUWALOO) return DSP032_ID_FUWALAFUWALOO;
        if (recipeId == DSP032_RECIPE_CHAIN_BRACELET_BI) return DSP032_ID_BI_BRACELET;
        if (recipeId == DSP032_RECIPE_CHAIN_BI_TRI) return DSP032_ID_TRI_BRACELET;
        if (recipeId == DSP032_RECIPE_HOLY_WAND) return DSP032_ID_HOLY_WAND;
        if (recipeId == DSP032_RECIPE_THOUSAND_EDGE) return DSP032_ID_THOUSAND_EDGE;
        if (recipeId == DSP032_RECIPE_DEATH_SPIRAL) return DSP032_ID_DEATH_SPIRAL;
        if (recipeId == DSP032_RECIPE_HELLFIRE) return DSP032_ID_HELLFIRE;
        if (recipeId == DSP032_RECIPE_HEAVEN_SWORD) return DSP032_ID_HEAVEN_SWORD;
        if (recipeId == DSP032_RECIPE_UNHOLY_VESPERS) return DSP032_ID_UNHOLY_VESPERS;
        if (recipeId == DSP032_RECIPE_LA_BORRA) return DSP032_ID_LA_BORRA;
        if (recipeId == DSP032_RECIPE_SOUL_EATER) return DSP032_ID_SOUL_EATER;
        if (recipeId == DSP032_RECIPE_THUNDER_LOOP) return DSP032_ID_THUNDER_LOOP;
        if (recipeId == DSP032_RECIPE_GORGEOUS_MOON) return DSP032_ID_GORGEOUS_MOON;
        if (recipeId == DSP032_RECIPE_NO_FUTURE) return DSP032_ID_NO_FUTURE;
        if (recipeId == DSP032_RECIPE_N3_VICIOUS_HUNGER) return DSP032_ID_N3_VICIOUS_HUNGER;
        if (recipeId == DSP032_RECIPE_N3_MANNAJJA) return DSP032_ID_N3_MANNAJJA;
        if (recipeId == DSP032_RECIPE_N3_VALKYRIE_TURNER) return DSP032_ID_N3_VALKYRIE_TURNER;
        if (recipeId == DSP032_RECIPE_N3_INFINITE_CORRIDOR) return DSP032_ID_N3_INFINITE_CORRIDOR;
        if (recipeId == DSP032_RECIPE_N3_CRIMSON_SHROUD) return DSP032_ID_N3_CRIMSON_SHROUD;
        if (recipeId == DSP032_RECIPE_N3_PROFUSIONE_DAMORE) return DSP032_ID_N3_PROFUSIONE_DAMORE;
        if (recipeId == DSP032_RECIPE_N3_ASHES_OF_MUSPELL) return DSP032_ID_N3_ASHES_OF_MUSPELL;
        if (recipeId == DSP032_RECIPE_N3_MAZO_FAMILIAR) return DSP032_ID_N3_MAZO_FAMILIAR;
        if (recipeId == DSP032_RECIPE_N3_GUNASTROPHE) return DSP032_ID_N3_GUNASTROPHE;
        if (recipeId == DSP032_RECIPE_N3_SPIRIT_DISTURBANCE) return DSP032_ID_N3_SPIRIT_DISTURBANCE;
        if (recipeId == DSP032_RECIPE_N3_CELESTIAL_VOULGE) return DSP032_ID_N3_CELESTIAL_VOULGE;
        if (recipeId == DSP032_RECIPE_N3_SERAPHIC_CRY) return DSP032_ID_N3_SERAPHIC_CRY;
        if (recipeId == DSP032_RECIPE_N3_EMBRACE_OF_GAEA) return DSP032_ID_N3_EMBRACE_OF_GAEA;
        if (recipeId == DSP032_RECIPE_N3_KYRA_STONES) return DSP032_ID_N3_KYRA_STONES;
        if (recipeId == DSP032_RECIPE_N3_PHOTONSTORM) return DSP032_ID_N3_PHOTONSTORM;
        if (recipeId == DSP032_RECIPE_N3_WICKED_RULER) return DSP032_ID_N3_WICKED_RULER;
        if (recipeId == DSP032_RECIPE_N3_ANIMA_OF_MORTACCIO) return DSP032_ID_N3_ANIMA_OF_MORTACCIO;
        if (recipeId == DSP032_RECIPE_N3_YATTA_DAIKARIN) return DSP032_ID_N3_YATTA_DAIKARIN;
        if (recipeId == DSP032_RECIPE_N3_CARROZZA) return DSP032_ID_N3_CARROZZA;
        return 0;
    }

    bool DSP032CanApplyRecipe(int recipeId, int chestSubtype, bool sourceAllowsTransformation,
        bool outputUnlocked)
    {
        int kind = DSP032RecipeKind(recipeId);
        int inputA = DSP032RecipeInputA(recipeId);
        int inputB = DSP032RecipeInputB(recipeId);
        int output = DSP032RecipeOutput(recipeId);
        if (kind == 0 || !sourceAllowsTransformation || !outputUnlocked || output <= 0
            || DSP032IndexOf(output) >= 0)
            return false;
        // The reported Whip route requires max rank and an eligible silver
        // source.  It remains separately classified until gameplay integration.
        if (recipeId == DSP032_RECIPE_WHIP_BLOODY_TEAR)
        {
            if (chestSubtype != DSP032_GRAPH_CHEST_SILVER || DSP032Rank(inputA) != 8
                || DSP032Rank(inputB) < 1) return false;
        }
        else if (chestSubtype != DSP032_GRAPH_CHEST_SILVER) return false;
        if (DSP032Rank(inputA) <= 0) return false;
        if (inputB > 0 && DSP032Rank(inputB) <= 0) return false;
        // The original's requiresMax passives: some evolutions need their
        // passive (and Infinite Corridor / Crimson Shroud a second one) maxed.
        int passiveRank = DSP032RecipePassiveMinRank(recipeId);
        if (passiveRank > 0 && DSP032Rank(inputB) < passiveRank) return false;
        int secondPassive = DSP032RecipeSecondPassive(recipeId);
        if (secondPassive > 0 && DSP032Rank(secondPassive) < passiveRank) return false;
        // N2-W5 standard evolutions (301-311): weapon input must be at max
        // rank, matching recipe 1's own dedicated rank check above.
        if (DSP032RecipeRequiresMaxRankInputA(recipeId)
            && DSP032Rank(inputA) != DSP032MaxRankForItem(inputA)) return false;
        // P042 unions/chains: both weapon inputs must be at max rank
        // (INFERENCE, contract "Engineering and slot policy"), and a
        // required passive (Tirajisu for Phieraggi) must be owned at
        // rank >= 1 but is never itself consumed.
        if (DSP032RecipeIsPositional(recipeId))
        {
            if (DSP032Rank(inputA) != DSP032MaxRankForItem(inputA)) return false;
            // The original only needs the first weapon maxed for Vandalier
            // (Peachone) and Phieraggi (Phiera); the partner just has to be owned.
            bool partnerAnyRank = recipeId == DSP032_RECIPE_UNION_VANDALIER || recipeId == DSP032_RECIPE_UNION_PHIERAGGI;
            if (inputB > 0 && !partnerAnyRank && DSP032Rank(inputB) != DSP032MaxRankForItem(inputB)) return false;
            int requiredPassive = DSP032RecipeRequiredPassive(recipeId);
            if (requiredPassive > 0 && DSP032Rank(requiredPassive) < 1) return false;
        }
        if (kind == DSP032_KIND_GIFT)
        {
            int category = DSP032Category(output);
            int limit = DSP032SlotLimit(category);
            if (DSP032OwnedSlots(category) >= limit) return false;
        }
        int removed = kind == DSP032_KIND_UNION ? 2
            : (kind == DSP032_KIND_EVOLUTION || kind == DSP032_KIND_REPLACEMENT ? 1 : 0);
        if (dsp032ItemIds.Size() - removed + 1 > DSP032_MAX_ITEMS) return false;
        if ((kind == DSP032_KIND_EVOLUTION || kind == DSP032_KIND_REPLACEMENT)
            && DSP032Category(inputA) != DSP032Category(output)) return false;
        if (kind == DSP032_KIND_UNION
            && (DSP032Category(inputA) != DSP032Category(output)
                || DSP032Category(inputB) != DSP032Category(output))) return false;
        return true;
    }

    bool DSP032HasTransaction(int transactionId)
    {
        for (int i = 0; i < dsp032TransactionIds.Size(); i++)
            if (dsp032TransactionIds[i] == transactionId) return true;
        return false;
    }

    bool DSP032CanAcquireItem(int id, int rank, int maxRank)
    {
        if (id <= 0 || rank <= 0 || rank > maxRank) return false;
        int index = DSP032IndexOf(id);
        if (index >= 0) return rank > dsp032ItemRanks[index];
        int category = DSP032Category(id);
        int limit = category == DSP032_CATEGORY_WEAPON ? DSP032_NORMAL_WEAPON_SLOTS
            : DSP032_NORMAL_PASSIVE_SLOTS;
        if (category == DSP032_CATEGORY_WEAPON) limit += dsp032WeaponExtraSlots;
        else limit += dsp032PassiveExtraSlots;
        return dsp032ItemIds.Size() < DSP032_MAX_ITEMS
            && DSP032OwnedSlots(category) < limit;
    }

    bool DSP032AcquireItem(int id, int rank, int maxRank, int transactionId)
    {
        if (transactionId <= 0 || DSP032HasTransaction(transactionId)
            || dsp032TransactionIds.Size() >= DSP032_MAX_TRANSACTIONS
            || !DSP032CanAcquireItem(id, rank, maxRank))
        {
            Console.Printf("DS_P032_ITEM_REWARD accepted=0 item=%d rank=%d tx=%d reason=ILLEGAL_OR_DUPLICATE", id, rank, transactionId);
            return false;
        }
        int index = DSP032IndexOf(id);
        if (index >= 0) dsp032ItemRanks[index] = rank;
        else { dsp032ItemIds.Push(id); dsp032ItemRanks.Push(rank); }
        dsp032TransactionIds.Push(transactionId);
        Console.Printf("DS_P032_ITEM_REWARD accepted=1 item=%d rank=%d tx=%d inventory_hash=%d classification=CONTROLLED_ENGINE_FIXTURE", id, rank, transactionId, DSP032InventoryHash());
        return true;
    }

    // All checks precede mutation. Multi-input transforms remove both inputs
    // and add one output within this synchronous authority call.
    bool DSP032ApplyRecipe(int recipeId, int sourceId, int chestSubtype,
        bool sourceAllowsTransformation, bool outputUnlocked, int transactionId)
    {
        if (transactionId <= 0 || dsp032TransactionIds.Size() >= DSP032_MAX_TRANSACTIONS)
        {
            Console.Printf("DS_P032_TRANSFORM accepted=0 recipe=%d source=%d tx=%d reason=INVALID_TRANSACTION", recipeId, sourceId, transactionId);
            return false;
        }
        if (DSP032HasTransaction(transactionId))
        {
            Console.Printf("DS_P032_TRANSFORM accepted=0 recipe=%d source=%d tx=%d reason=DUPLICATE_TRANSACTION", recipeId, sourceId, transactionId);
            return false;
        }
        if (!DSP032CanApplyRecipe(recipeId, chestSubtype, sourceAllowsTransformation,
                outputUnlocked))
        {
            Console.Printf("DS_P032_TRANSFORM accepted=0 recipe=%d source=%d tx=%d reason=PREDICATE_REJECTED", recipeId, sourceId, transactionId);
            return false;
        }
        int kind = DSP032RecipeKind(recipeId);
        int inputA = DSP032RecipeInputA(recipeId);
        int inputB = DSP032RecipeInputB(recipeId);
        int output = DSP032RecipeOutput(recipeId);
        bool positional = DSP032RecipeIsPositional(recipeId);
        int insertAt = -1;
        if (kind == DSP032_KIND_EVOLUTION || kind == DSP032_KIND_REPLACEMENT)
        {
            int idxA = DSP032IndexOf(inputA);
            if (positional) insertAt = idxA;
            DSP032RemoveIndex(idxA);
        }
        else if (kind == DSP032_KIND_UNION)
        {
            int idxA = DSP032IndexOf(inputA);
            int idxB = DSP032IndexOf(inputB);
            if (positional)
            {
                // Contract slot transaction: the output takes the LOWER of
                // the two input slot indices; the higher slot is freed.
                int lowerIdx = idxA < idxB ? idxA : idxB;
                int higherIdx = idxA < idxB ? idxB : idxA;
                DSP032RemoveIndex(higherIdx);
                DSP032RemoveIndex(lowerIdx);
                insertAt = lowerIdx;
            }
            else
            {
                DSP032RemoveIndex(idxB);
                DSP032RemoveIndex(idxA);
            }
        }
        // All output-capacity and category checks ran before mutation. The
        // named Whip evolution starts Bloody Tear at rank 1; fixture recipes
        // use rank 1 outputs as well.
        // The bounded recipe table, prior output-ownership check and count
        // preflight make this insertion non-failing after the removals above.
        if (positional && insertAt >= 0 && insertAt <= dsp032ItemIds.Size())
        {
            dsp032ItemIds.Insert(insertAt, output);
            dsp032ItemRanks.Insert(insertAt, 1);
        }
        else
        {
            dsp032ItemIds.Push(output);
            dsp032ItemRanks.Push(1);
        }
        dsp032TransactionIds.Push(transactionId);
        Console.Printf("DS_P032_TRANSFORM accepted=1 kind=%d recipe=%d source=%d tx=%d input_a=%d input_b=%d output=%d whip_rank=%d hollow_heart=%d output_owned=%d classification=%s", kind, recipeId, sourceId, transactionId, inputA, inputB, output, DSP032Rank(DSP032_ID_WHIP), DSP032Rank(DSP032_ID_HOLLOW_HEART), DSP032Rank(output), recipeId == DSP032_RECIPE_WHIP_BLOODY_TEAR ? "ONLINE_REPORTED_RECIPE_CONTROLLED_INVENTORY_FIXTURE" : "CONTROLLED_ENGINE_FIXTURE");
        return true;
    }

    int DSP032InventoryHash()
    {
        int hash = 32032 + dsp032WeaponExtraSlots * 7 + dsp032PassiveExtraSlots * 11;
        for (int i = 0; i < dsp032ItemIds.Size(); i++)
            hash = hash * 31 + dsp032ItemIds[i] * 13 + dsp032ItemRanks[i];
        return hash;
    }
}
