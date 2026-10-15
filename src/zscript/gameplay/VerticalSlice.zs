// P030 playable five-minute first-person vertical slice.
//
// The handler composes the accepted P020-P029 logical seams.  It owns only
// MAP16's orchestration and presentation bridge; native actors remain mirrors
// and never decide combat, spawn, pickup or progression outcomes.
class DSP030EnemyProxy : Actor
{
    mixin DSGroundFollow;
    int logicalSlot;
    int logicalGeneration;
    int logicalStableId;
    int lastHealth;   // for the hit flash (presentation only)
    int flashTics;

    Default
    {
        Radius 10;
        Height 24;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Translucent";
        Alpha 0.86;
        Scale 0.30;
    }

    States
    {
    Spawn:
        BILL A 2 Bright;
        Loop;
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
    }
}

// Stage enemy drawn with its archetype sprite (tools/art/enemy_art.py).
// SpawnEnemyProxy sets the sprite; "####" keeps it while the frames
// alternate. Presentation only.
class DSEnemyArtProxy : DSP030EnemyProxy
{
    Default
    {
        RenderStyle "Normal";
        Alpha 1.0;
        Scale 0.6;
    }

    override void Tick()
    {
        Super.Tick();
        // Hit flash: white for a few tics after the logical health dropped.
        if (flashTics > 0)
        {
            flashTics--;
            if (flashTics > 0) { A_SetRenderStyle(1.0, STYLE_AddStencil); SetShade(Color(255, 255, 255, 255)); }
            else A_SetRenderStyle(1.0, STYLE_Normal);
        }
    }

    States
    {
    Spawn:
        EBTA A 1 Bright;
    Anim:
        #### A 5 Bright;
        #### C 5 Bright;
        #### B 5 Bright;
        #### D 5 Bright;
        Loop;
    }
}

// A defeated enemy squashes and fades where it fell (presentation only).
class DSEnemyDeathFx : Actor
{
    mixin DSGroundFollow;
    int age;
    double baseScale;

    Default
    {
        Radius 1;
        Height 1;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Translucent";
    }

    States
    {
    Spawn:
        EBTA A -1 Bright;
        Stop;
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
        age++;
        if (age >= 10) { Destroy(); return; }
        A_SetScale(baseScale * (1.0 + 0.06 * age), baseScale * max(0.08, 1.0 - 0.1 * age));
        A_SetRenderStyle(1.0 - age / 10.0, STYLE_Translucent);
    }
}

// Mad Forest light source: an enemy-store destructible drawn as a brazier.
class DSMFBrazierProxy : DSP030EnemyProxy
{
    Default
    {
        RenderStyle "Normal";
        Alpha 1.0;
        Scale 0.9;
    }

    States
    {
    Spawn:
        LSRC A 6 Bright;
        LSRC B 6 Bright;
        Loop;
    }
}

// Mad Forest floor item (coin, chicken, Rosary...), tinted per item.
// Generic weapon visual (projectiles, zones, companions). Presentation only.
class DSGenericWeaponProxy : Actor
{
    mixin DSGroundFollow;
    Default
    {
        Radius 4;
        Height 8;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
    }

    States
    {
    Spawn:
        ITEM A -1 Bright;
        Stop;
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
    }
}

class DSMFItemProxy : Actor
{
    mixin DSGroundFollow;
    mixin DSPickupGlow;
    int itemId;

    Default
    {
        Radius 4;
        Height 8;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        Scale 0.5;
    }

    // MFSyncItemProxies sets the sprite per item kind (tools/art/pickup_art.py).
    // Actor.GetSpriteIndex only finds sprite names some state uses and returns
    // -1 otherwise; rendering sprite -1 reads out of bounds, crashes the
    // renderer's worker thread and deadlocks the engine. Register never-entered
    // states so every item sprite resolves.
    States
    {
    Spawn:
        ICOI A 1 Bright;
    Idle:
        #### A -1 Bright;
        Stop;
    Register:
        IBAG A 0; IRIC A 0; ICHK A 0; IROS A 0; IORO A 0; IVAC A 0; ICLV A 0; INDJ A 0; IGLC A 0; IRRL A 0; ISRB A 0;
        Stop;
    }

    override void Tick()
    {
        Super.Tick();
        DSPickupTick(40.0, Color(255, 210, 90));
    }

    override void OnDestroy()
    {
        DSPickupGone();
        Super.OnDestroy();
    }
}

class DSP030PickupProxy : Actor
{
    mixin DSGroundFollow;
    mixin DSPickupGlow;
    int logicalSlot;
    int logicalGeneration;
    int logicalStableId;

    Default
    {
        Radius 5;
        Height 5;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        Scale 0.4;
    }

    // XP gem; BindPickupProxy picks the blue/green/red sprite by value.
    States
    {
    Spawn:
        GEMB A 1 Bright;
    Anim:
        #### A 10 Bright;
        #### B 10 Bright;
        Loop;
    Register: // see DSMFItemProxy: makes GetSpriteIndex find these
        GEMG AB 0; GEMR AB 0;
        Stop;
    }

    override void Tick()
    {
        Super.Tick();
        DSPickupTick(26.0, Color(120, 220, 255));
    }

    override void OnDestroy()
    {
        DSPickupGone();
        Super.OnDestroy();
    }
}

class DSP032Map16ChestProxy : Actor
{
    mixin DSGroundFollow;
    int chestStableId;

    Default
    {
        Radius 6;
        Height 8;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        Scale 0.7;
    }

    // Treasure chest (Arcana chests switch to the purple CHSR sprite).
    States
    {
    Spawn:
        CHST A 1 Bright;
    Anim:
        #### A 12 Bright;
        #### B 12 Bright;
        Loop;
    Register: // see DSMFItemProxy: makes GetSpriteIndex find CHSR
        CHSR AB 0;
        Stop;
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
    }
}

class DSP030WhipProxy : Actor
{
    mixin DSGroundFollow;
    int logicalEventId;
    int logicalLobe;
    int age;
    double baseScale;

    // Presentation only: a crescent lying on the floor over the lobe.
    void Setup(double px, double py, double yaw, double radius)
    {
        bFlatSprite = true;
        angle = yaw;
        baseScale = radius * 2.0 / 64.0;
        A_SetScale(baseScale * 0.6);
        SetOrigin((px + cos(yaw) * radius * 0.5, py + sin(yaw) * radius * 0.5, 1.5), false);
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
        age++;
        if (baseScale > 0.0)
        {
            A_SetScale(baseScale * (0.6 + 0.1 * age));
            A_SetRenderStyle(max(0.15, 0.85 - 0.15 * age), STYLE_Add);
        }
    }

    Default
    {
        Radius 4;
        Height 12;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Add";
        Alpha 0.72;
        Scale 1.0;
    }

    States
    {
    Spawn:
        // A sweep is authoritative for five tics; the proxy is presentation
        // only and must disappear with that bounded visual window.
        WWHP A 2 Bright;
        WWHP A 2 Bright;
        WWHP A 1 Bright;
        Stop;
    }
}

class DSP037OrbitProxy : Actor
{
    mixin DSGroundFollow;
    int memberIndex;
    int cohortId;
    int memberOrdinal;
    int memberGeneration;
    int artSprite;

    Default
    {
        Radius 3;
        Height 5;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOINTERACTION;
        RenderStyle "Normal";
        Alpha 1.0;
        Scale 0.4;
    }

    States
    {
    Spawn:
        PROP A 2 Bright;
        Loop;
    }

    override void Tick()
    {
        Super.Tick();
        DSFollowGround();
        if (artSprite > 0) sprite = artSprite;
    }
}

class DSP030VerticalSlice : EventHandler
{
    // n2Pending* (queue DraftFull.zs writes to) live in the
    // DSP028LevelUpProgression mixin (Draft.zs), right next to whipRank --
    // see that declaration's comment for why (ZSCRIPT #include order, not
    // mixin-list order, gates a mixin body's symbol visibility).
    mixin DSP020EntityStore;
    mixin DSP024SpatialIndex;
    mixin DSP025AttackCore;
    mixin DSP027ExperienceStore;
    mixin DSP028LevelUpProgression;
    mixin DSP031InventoryDraftAuthority;
    mixin DSP032TransformationGraph;
    mixin DSP032ChestRewardAuthority;
    mixin DSP033ResolvedStats;
    mixin DSRunStatFields;
    mixin DSP034AimedTargeting;
    mixin DSP034AimedProjectileRuntime;
    mixin DSP035BallisticTargeting;
    mixin DSP035BallisticProjectileRuntime;
    mixin DSP036ReturningTargeting;
    mixin DSP036ReturningProjectileRuntime;
    mixin DSP037OrbitRuntime;
    mixin DSP038GroundFieldRuntime;
    mixin DSP039Aura;
    mixin DSP039Healing;
    mixin DSP040Global;
    mixin DSP041BounceTargeting;
    mixin DSP042PairedTargeting;
    mixin DSP042Paired;
    mixin DSP041Bounce;

    const MAP = "MAP16";
    const STATE_STARTING = 0;
    const STATE_ACTIVE = 1;
    const STATE_LEVELUP = 2;
    const STATE_ENDING = 3;
    const STATE_RESULTS = 4;
    const STATE_RESTARTING = 5;
    const LEVELUP_ACTION_REROLL = 1;
    const LEVELUP_ACTION_SKIP = 2;
    const LEVELUP_ACTION_BANISH = 3;
    const KIND_PLAYER = 99;
    const KIND_WEAPON = 2;
    const KIND_ENEMY = 1;
    const PLAYER_HEALTH = 120000;
    const ENEMY_HEALTH = 3000;
    const ENEMY_SPEED = 0.5;
    const CONTACT_RADIUS = 14.0;   // about the player's body (radius 16); was 4.0
    const CONTACT_DAMAGE = 1250;
    const CONTACT_COOLDOWN = 7;
    const INVULNERABLE_TICS = 3;
    const PICKUP_VALUE = 1000;
    const ATTRACT_RADIUS = 96.0;
    const COLLECT_RADIUS = 24.0;
    const PICKUP_SPEED = 8.0;
    const SURVIVAL_TICS = 10500;
    const MIN_SURVIVAL_TICS = 2100;
    const MAX_SURVIVAL_TICS = 10500;
    const MAX_TEST_STEPS = 200;
    const PROFILE_SCHEMA = 1;

    bool enabled;
    bool completed;
    bool completionEmitted;
    transient bool startedThisProcess;
    int runState;
    int priorState;
    int runId;
    int runGeneration;
    int tic;
    // Weapon effect actors (SliceWeaponFx.zs).
    Array<int> fxKeys;
    Array<DSWeaponFx> fxActors;
    Array<int> fxSeen;
    int fxStamp;
    // Stage items and trap plates (SliceGimmicks.zs).
    Array<int> gmItemId;
    Array<double> gmItemX;
    Array<double> gmItemY;
    Array<Actor> gmItemActor;
    Array<double> gmPlateX;
    Array<double> gmPlateY;
    Array<int> gmPlateKind;
    Array<int> gmPlateReady;
    int gmRng;
    // Stage objects (SliceGimmicks.zs): toast, doors/merchants, windows/carts,
    // crabs, and the walled stages (Westwoods, Room 1665).
    String gmToast;
    int gmToastUntil;
    Array<Actor> gmDecorActors;
    Array<double> gmPlateTX;
    Array<double> gmPlateTY;
    Array<int> gmPropKind;
    Array<double> gmPropX;
    Array<double> gmPropY;
    Array<double> gmPropTX;
    Array<double> gmPropTY;
    Array<int> gmPropSlot;
    Array<int> gmPropId;
    Array<int> gmPropReady;
    Array<double> gmMvX;
    Array<double> gmMvY;
    Array<double> gmMvVX;
    Array<double> gmMvVY;
    Array<int> gmMvLife;
    Array<int> gmCrabSlot;
    Array<int> gmCrabId;
    int gmShopIndex;
    int gmShopCount;
    Array<int> rsEggs;   // Golden Eggs per stat (DSEggs), loaded at run start
    int gmWoodUnlock;
    int gmReaperNext;
    int gmRoomsShown;
    int gmTypeCrab;
    int gmTypeDrowner;
    int gmTypeStalker;
    int gmTypeTrickster;
    bool mfWoods;
    // Meta progression (SliceMeta.zs).
    Array<int> metaTypeKills;
    int metaOro;
    int metaVac;
    int metaRos;
    int metaChk;
    String metaNewUnlocks;
    bool mfRoom;
    // The Depths, MAP53 (SliceDungeon.zs): this run's plan over the superset
    // dungeon, the open/closed cell grid and the breadth-first step map from
    // the player's cell that enemies follow.
    bool dgActive;
    bool dgAmulet;
    bool dgEscaped;
    bool dgExitWarned;
    int dgDepth;
    int dgDeepest;
    int dgPlayerCell;
    int dgSpikeNext;
    bool dgSpikeWarned;
    double dgAmuletX;
    double dgAmuletY;
    Array<int> dgCells;
    Array<int> dgDist;
    Array<int> dgQueue;
    Array<int> dgSeen;         // per cell: explored (minimap and full map)
    Array<int> dgPlan;         // per room slot: 0 unused, 1 in the plan, 2 dead end not yet visited
    Array<int> dgTemplate;     // per room slot
    Array<int> dgConnOpen;     // per connector
    Array<int> dgStart;        // per floor: the room slot the floor is entered by
    Array<int> dgDown;         // per floor: the open stairs connector down (-1 on the bottom)
    Array<int> dgKnown;        // per floor: the way on has been seen
    Array<double> dgLastX;
    Array<double> dgAimX;      // per enemy slot: steering plan (SliceDungeon.zs DgPlanSteer)
    Array<double> dgAimY;
    Array<int> dgAimMode;      // -1 none, 0 a cell along the way, 1 straight at the player
    Array<double> dgDirX;      // last heading, for turning inertia
    Array<double> dgDirY;
    Array<double> dgLastY;
    Array<Actor> dgDecor;
    Actor dgAmuletActor;
    // Stage rules (SliceGimmicks.zs): The Coop holds its clock until the first
    // kill and opens a fence each minute; Il Molise tiles its immobile spawns.
    int mfHeld;
    bool mfCoop;
    bool mfMolise;
    bool mfCoopStarted;
    Array<Actor> gmFenceActors;
    int phase;
    int nextSpawnTic;
    int spawnIndex;
    int spawnRng;
    int spawnAttempts;
    int spawnAdmissions;
    int spawnRejections;
    int attackRng;
    int attackEventId;
    int nextWhipQuarter;
    int pendingRear;       // Whip swings still to come in the current volley
    int whipSwingIdx;      // swing index in the volley; odd swings go behind
    // Whip Duration: a swing's hit area lingers, catching enemies that walk in.
    Array<int> whipLingerEvent;
    Array<int> whipLingerLobe;
    Array<int> whipLingerYaw;
    Array<int> whipLingerUntil;
    Array<int> whipLingerDamage;
    int pendingRearQuarter;
    int playerSlot;
    int weaponSlot;
    int diagnosticWeaponSlot;
    int diagnosticEventId;
    int diagnosticNextQuarter;
    int diagnosticAttackRng;
    int playerHealth;
    int playerInvulnerableUntil;
    int kills;
    int damageDealt;
    int contactHits;
    int contactRejects;
    int xpCreatedLedger;
    int xpCollectedLedger;
    int earnedCurrency;
    int levelUpChoices;
    int logicalStepsPerWorldTick;
    int survivalTics;
    // Mad Forest stage (docs/TODO.md step 2): DSMadForest tables are
    // generated from wiki data and remain approximations. Per-slot rows are
    // valid only while mfStable[slot] matches the slot's stable id.
    const MAD_FOREST_TICS = 63000;
    const MF_LIVE_CAP = 300;
    const MF_BURST_CAP = 30;
    const MF_LEASH = 2400.0;
    // Enemies spawn this many times farther out than the source band (160).
    const MF_SPAWN_SCALE = 6.0;
    bool mfEnabled;
    int mfNextWaveTic;
    int mfNextBossIndex;
    int mfNextEventIndex;
    int mfNextReaperTic;
    int mfEventRng;
    int mfChestRng;
    int mfChestSeq;
    Array<int> mfStable;
    Array<int> mfTypes;
    Array<int> mfMotion;
    Array<int> mfExpire;
    Array<int> mfBoss;
    Array<double> mfVX;
    Array<double> mfVY;
    Array<int> mfChestIds;
    Array<int> mfChestItems;
    // Arcana (gameplay/slice/SliceArcana.zs).
    bool arEnabled;
    bool arPickOpen;
    Array<int> arOwned;
    Array<int> arPickLevel;
    Array<int> arOffers;
    int arAwakeRevivals;
    int arRng;
    int arMoveTic;
    double arLastX;
    double arLastY;
    // Light sources (braziers) and floor items. Brazier HP, item weights,
    // level gates and effects are wiki values; the Mad Forest spawn chance
    // and cap are not published (engineering approximation).
    // Props share the enemy slots but use type ids above the enemy table
    // (DSStage types are 1..ENEMY_TYPE_COUNT=357), so no real enemy is a prop.
    const MF_BRAZIER_TYPE = 900;
    const MF_WINDOW_TYPE = 901;
    const MF_CART_TYPE = 902;
    const MF_BRAZIER_HP = 10000;
    const MF_BRAZIER_MAX = 5;
    const MF_BRAZIER_CHANCE_PCT = 10;
    const MF_ROSARY_RADIUS = 320.0;
    const MF_FREEZE_TICS = 350;
    const MF_ITEM_COIN = 1;
    const MF_ITEM_COIN_BAG = 2;
    const MF_ITEM_RICH_BAG = 3;
    const MF_ITEM_CHICKEN = 4;
    const MF_ITEM_ROSARY = 5;
    const MF_ITEM_OROLOGION = 6;
    const MF_ITEM_VACUUM = 7;
    const MF_ITEM_LITTLE_CLOVER = 8;
    const MF_ITEM_NDUJA = 9;
    const MF_ITEM_GILDED_CLOVER = 10;
    const MF_ITEM_REROLLO = 11;
    const MF_ITEM_SORBETTO = 12;
    const MF_ITEM_LAST = 12;
    int mfGold;
    // HUD values the ui scope cannot compute itself (play functions).
    int hudHealthCap;
    // Run stats totals (RecomputeRunStats) and gold before Greed rounding.
    DSRunStatBlock rsTotal;
    int mfGoldMilli;
    // DSStage index of the loaded map (DSStage.FOREST / DSStage.LIBRARY).
    int mfStage;
    // Generic weapon engine (slice/SliceGeneric.zs).
    Array<int> gwSystem;
    Array<int> gwNextFire;
    Array<int> gwFrozenUntil;
    Array<int> gwSlowUntil;
    Array<int> gwPinionMoving; Array<int> gwPinionBurstReady;
    int gwAmmoStock; int gwAshesKills;
    Array<int> gwHitSystem;
    Array<int> gwHitCount;
    int gwShieldUntil;
    // Shared hit effects (slice/SliceEffects.zs).
    Array<int> kbUntil; Array<int> kbId; Array<double> kbVX; Array<double> kbVY;
    int critRng;
    double fxLastX; double fxLastY; int fxMoveTic;
    Array<String> tallyKeys; Array<int> tallyCounts;   // DS_FX_COUNT end-of-run tallies
    int rsCharm; int rsDefangPct; int rsInvulnTics; int rsFeverPct;
    double whipAimYaw;   // direction of the current Whip / Bloody Tear sweep
    int deathFxTic; int deathFxCount;
    int metaClv;   // Little Clovers this run
    bool mfEnderAlive;
    // Run mode (ds_mode): 0 normal, 1 Hyper, 2 Inverse. The wiki's exact
    // numbers vary per stage; these are labelled approximations.
    //   Hyper: player and enemy speed x1.5, Greed x1.7, Luck +10%, +50% spawns.
    //   Inverse: enemy health x1.5, +50% spawns, XP and Greed x1.5, enemy speed x1.2.
    int rsMode;
    int mfClovers;            // Little Clovers collected this run (+10% Luck each)
    int mfFeverTics;          // Gold Fever time left
    int mfBreathUntil;        // Nduja Fritta Tanto / Sorbetto temporary weapon
    int mfBreathKind;
    int mfBreathStart;
    Array<int> mfDefang;      // 1 = enemy cannot hurt the player
    Array<int> gwTunaForms;   // Penshin Fatcha forms taken so far, in order
    int gwEventId;
    int gwRng;
    int gwAcceptedDamageMilli;
    Array<int> geSystem;
    Array<int> geMode;
    Array<double> geX;
    Array<double> geY;
    Array<double> geVX;
    Array<double> geVY;
    Array<double> geRadius;
    Array<int> geDamage;
    Array<int> geExpire;
    Array<int> geNextTick;
    Array<int> geTick;
    Array<int> gePierce;
    Array<int> geLastHit;
    Array<Actor> geProxy;
    int hudXpNeed;
    int mfFreezeUntil;
    bool mfVacuumActive;
    int mfLootRng;
    int mfItemSeq;
    Array<int> mfItemIds;
    Array<int> mfItemKinds;
    Array<double> mfItemX;
    Array<double> mfItemY;
    int telemetryEnabled;
    int cameraVariant;
    int cameraYaw;
    int cameraPitch;
    int cameraFov;
    String configuredMode;
    bool p031RouteEnabled;
    bool p032RouteEnabled;
    bool p033RouteEnabled;
    bool p034RouteEnabled;
    bool p035RouteEnabled;
    bool p036RouteEnabled;
    bool p037RouteEnabled;
    bool p038RouteEnabled;
    bool p039RouteEnabled;
    bool p040RouteEnabled;
    bool p033ContactFixtureEnabled;
    bool p033ContactFixtureAttempted;
    bool p033SaveStateEmitted;
    bool p033SaveSnapshotHeld;
    bool p033RestorePendingAttack;
    bool p034TransformAttempted;
    bool p035AxeTransformAttempted;
    bool p035FireTransformAttempted;
    bool p036TransformAttempted;
    bool p037TransformAttempted;
    bool p037SaveStateEmitted;
    bool p037SaveSnapshotHeld;
    bool p037RestoreAttackPending;
    bool p038TransformAttempted;
    bool p038SaveStateEmitted;
    bool p038SaveSnapshotHeld;
    bool p038RestorePendingHit;
    bool p039TransformAttempted;
    bool p039RestorePendingHit;
    bool p039ContactFixtureAttemptedPre;
    bool p039ContactFixtureAttemptedPost;
    bool p040LoopTransformAttempted;
    bool p040MoonTransformAttempted;
    bool p040MoonTargetFixtureSpawned;
    bool p040PickupRepositionAttempted;
    bool p040PentagramPickupFixtureSpawned;
    bool p040BigGemFixtureSpawned;
    int p033ContactFixtureId;
    int p034MagicWeaponSlot;
    int p034KnifeWeaponSlot;
    int p034TargetFixtureId;
    int p035FrontFixtureId;
    int p035AxeFixtureId;
    int p035AxeWeaponSlot;
    int p035FireWeaponSlot;
    int p036WeaponSlot;
    int p037WeaponSlot;
    int p037TargetFixtureId;
    int p037LastPlayOrbitHash;
    int p038WeaponSlot;
    int p038LastPlayGroundHash;
    int p038SavedGroundHash;
    int p038SavedP031Hash;
    int p038SavedP032Hash;
    int p038SavedChestHash;
    int p038SavedOrbitHash;
    int p038SavedAimedHash;
    int p038SavedBallisticHash;
    int p038SavedReturningHash;
    int p038SavedSourceRankHash;
    int p038SavedResolvedRankHash;
    int p038SavedPlayerXMilli;
    int p038SavedPlayerYMilli;
    int p038SavedLogicalTic;
    int p038SavedWeaponFormGeneration;
    int p039WeaponSlot;
    int p039PummarolaRank;
    int p039ContactFixtureId;
    int p039ContactFixtureDamageMilli;
    int p039ContactFixtureTargetMilli;
    int p039LastPlayAuraHash;
    int p038SavedAuraHash;
    int p038SavedHealingHash;
    int p040StrikeWeaponSlot;
    int p040EraseWeaponSlot;
    int p040ErasedCredited;
    int p038SavedGlobalHash;
    int p038SavedRankHashAmountGrowth;
    bool p041RouteEnabled;
    bool p041NoFutureTransformAttempted;
    bool p041ContactFixtureAttempted;
    int p041RunetracerWeaponSlot;
    int p041BoneWeaponSlot;
    int p041CherryWeaponSlot;
    int p041CarrelloWeaponSlot;
    int p041RunetracerWeaponIndex;
    int p041BoneWeaponIndex;
    int p041CherryWeaponIndex;
    int p041CarrelloWeaponIndex;
    int p041ContactFixtureId;
    int p041NoFutureExplosionsCredited;
    int p038SavedBounceHash;

    // N2-W9 manual-route save/load evidence gate (docs/contracts/normal-
    // play-integration.md "Persistence"/"Evidence" item 3). Active only when
    // n2ChestCadenceEnabled (configuredMode manual/soak_n2); mirrors the
    // EmitP038Map16SaveStateIfRequested/RestoreP038Map16SavedRun two-process
    // pattern, but hashes the full N2 dispatcher/DraftFull/chest/healing
    // state via the already-generic OwnedWeaponsHash()/RebaseOwnedWeapons()
    // instead of any single route's fixed engine.
    bool n2SaveStateEmitted;
    bool n2SaveSnapshotHeld;
    int n2SavedOwnedHash;
    int n2SavedP031Hash;
    int n2SavedP032InventoryHash;
    int n2SavedChestHash;
    int n2SavedHealingHash;
    int n2SavedSourceRankHash;
    int n2SavedResolvedRankHash;
    int n2SavedResolvedRankHashWithRecovery;
    int n2SavedRankHashAmountGrowth;
    int n2SavedPlayerXMilli;
    int n2SavedPlayerYMilli;
    int n2SavedLogicalTic;
    int n2SavedPlayerLevel;
    int n2SavedPlayerHealth;
    int n2SavedOwnedWeaponCount;

    // N2 weapon dispatcher (docs/contracts/normal-play-integration.md
    // "Weapon dispatcher"). Arrays keyed by draft/catalog system id (== the
    // DSP033StatRules SYSTEM_* value per DSN2Catalog.System), not named
    // per-route fields, per the frozen contract. Whip/Bloody Tear are
    // tracked read-only here (whipRank stays the single source of truth;
    // see AcquireWeapon/SetWeaponRank below) so OwnedWeaponsHash/reset/
    // rebase can report on the full owned set without touching the
    // already-working Whip firing path.
    const N2_ENGINE_NONE = 0;
    const N2_ENGINE_AIMED = 1;
    const N2_ENGINE_BALLISTIC = 2;
    const N2_ENGINE_RETURNING = 3;
    const N2_ENGINE_ORBIT = 4;
    const N2_ENGINE_GROUND = 5;
    const N2_ENGINE_AURA = 6;
    const N2_ENGINE_GLOBAL_STRIKE = 7;
    const N2_ENGINE_GLOBAL_ERASE = 8;
    const N2_ENGINE_BOUNCE = 9;
    const N2_ENGINE_PAIRED = 10;
    const N2_ENGINE_GENERIC = 11;
    Array<int> n2System;
    Array<int> n2Rank;
    Array<int> n2Slot;
    Array<int> n2EngineIndex; // engine-internal index (bounce/paired only); -1 otherwise
    int n2AcquireCount;
    int n2RankChangeCount;
    bool n2GrantAllAcquired;
    int n2GrantAllRankStep;
    // Dispatcher-owned cumulative accepted-hit/erase totals, one per engine.
    // These accumulate the same before/after delta each engine's own pNNN
    // route already reads off its live dsp0xxAcceptedHits/dsp040ErasedEnemies
    // counter (see N2CreditDamage's damageDealt pattern above), because
    // TearDownRun() resets every engine's live counters back to 0 before
    // EndRun's N2LogDispatchSummary() runs -- reading the live counters at
    // results time always reports 0 regardless of what actually happened
    // during the run. N2LogDispatchSummary reads these cumulative totals
    // instead so the summary reflects real accepted hits/erases.
    int n2CumAimedHits;
    int n2CumBallisticHits;
    int n2CumReturningHits;
    int n2CumOrbitHits;
    int n2CumGroundHits;
    int n2CumAuraHits;
    int n2CumGlobalStrikeHits;
    int n2CumGlobalErased;
    int n2CumBounceHits;
    int n2CumPairedHits;
    // N2 dispatch evidence density fixture (see N2MaintainDispatchEvidenceRing
    // below): tracked ring-slot identities so a dead/expired member is
    // detected and respawned in place next tic.
    const N2_RING_COUNT = 12;
    Array<int> n2RingSlot;
    Array<int> n2RingGeneration;
    Array<int> n2RingStableId;
    // N2-W5 interim chest cadence (docs/contracts/normal-play-integration.md
    // "Evolutions and chests" INTERIM_CHEST_CADENCE): manual/soak_n2 route
    // only, independent of the opt-in p032RouteEnabled/p033RouteEnabled Map16
    // fixture path above, which keeps its own UI-modal single-recipe flow
    // unchanged. N5 replaces this with real enemy drops per the contract.
    bool n2ChestCadenceEnabled;
    int n2ChestCadenceInterval;
    int n2NextChestTic;
    int n2ChestSeq;
    int n2ActiveChestId;
    double n2ChestTargetX;
    double n2ChestTargetY;
    int n2EvolutionAppliedCount;
    Array<int> n2AppliedRecipeIds;
    // N2-W6 evolution-evidence fixture (ds_n2_evolve_fixture,
    // N2_EVOLUTION_EVIDENCE_FIXTURE, off by default): grants every recipe's
    // inputs through the real AcquireWeapon/SetWeaponRank dispatcher and the
    // real DSP031Acquire draft/inventory authority, in weapon batches of at
    // most 6 concurrently-owned non-Whip weapons so N2MaintainChestCadence's
    // real chest-open path can apply all 17 recipes (1, 201-205, 301-311)
    // exactly once each. See N2MaintainEvolutionFixture below.
    bool n2EvolutionFixtureEnabled;
    bool n2EvolutionPassivesGranted;
    int n2EvolutionBatchStage;
    bool n2EvolutionBiBraceletReranked;
    // n2Pending* (queue DraftFull.zs writes to) are declared at the very
    // top of this class, before any mixin -- see that declaration's comment.

    bool p032ChestPickupRequested;
    bool p032ChestModalOpen;
    int p032ChestId;
    int p032ChestX;
    int p032ChestY;
    int p032PickupTapeTicks;
    bool p032PickupTapeEnabled;
    double p032PickupTapeStartX;
    double p032PickupTapeStartY;
    int p032AttackRng;
    int p032EventId;
    int p031ChoiceTic;
    int p031WhipEventsAtChoice;
    double playerX;
    double playerY;
    int inputTraceEnabled;
    bool inputTraceInitialized;
    double inputTraceX;
    double inputTraceY;
    double inputTraceYaw;
    double inputTracePitch;
    int sweepUntil;
    int sweepLobe;
    int sweepEvent;
    int peakWhipProxies;
    // P025 retains the canonical attack history for its own fixture runtime;
    // MAP16 has a separate per-event dedupe ledger for its lobe oracle.
    Array<int> historyEvent;
    Array<int> historyTargetSlot;
    Array<int> historyTargetGeneration;
    Array<int> historyTargetId;

    // Play-side modal state. UI fields below are intentionally unavailable to
    // WorldTick, so play owns this latch and publishes snapshots to the UI.
    bool modalPlayOpen;
    int playSelectedOffer;

    int profileCurrency;
    int profileNextRunId;
    String profileLastKey;
    int profileLastAmount;
    bool profileRejected;

    ui bool uiInitialized;
    ui bool nativePauseWasOpen;
    ui int uiTicks;
    ui int selectedOffer;
    ui int hoverOffer;
    ui bool upHeld;
    ui bool downHeld;
    ui bool modalOpen;
    ui bool choiceHeld;
    ui bool mouseHeld;
    ui bool returnHeld;

    ui int uiTic;
    ui int uiHealth;
    ui int uiHealthCap;
    ui int uiLevel;
    ui int uiXp;
    ui int uiKills;
    ui int uiEnemies;
    ui int uiPickups;
    ui int uiCap;
    ui int uiWhipRank;
    ui int uiPowerRank;
    ui int uiArmor;
    ui int uiChoices;
    ui int uiThreatFront;
    ui int uiThreatSide;
    ui int uiThreatRear;
    ui int uiNearbyPickups;
    ui int uiSweepLobe;
    ui int uiSweepActive;
    ui int uiOfferCount;
    ui int uiOffer0Id;
    ui int uiOffer1Id;
    ui int uiOffer2Id;
    ui int uiOffer0Rank;
    ui int uiOffer1Rank;
    ui int uiOffer2Rank;
    ui int uiTargetLevel;
    ui int uiRerolls;
    ui int uiNextShot;
    ui double hudHpTrail;     // HUD health bar: pale strip that drains after a hit
    ui int hudHpTrailHold;    // tics before the strip starts draining
    ui int hudLevelShown;     // HUD level badge flashes when this changes
    ui int hudLevelFlash;
    Array<int> sfxLastTic;
    Array<int> sfxBusTics;   // start tics of recent combat sounds (effects bus gain)
    Array<int> sfxBusCats;   // their categories (per-category budget)
    Array<int> sfxCatLast;   // last start tic per category
    Array<int> sfxStatAsked; // per category since the last DS_AUDIO_RATE line
    Array<int> sfxStatPlayed;
    int sfxStatPeak;         // most combat sounds started inside one budget window
    int sfxStatTic;
    double duckGain;      // music gain while a stinger is held (1.0 = none)
    double duckVolume;    // music gain actually applied (eased)
    double duckApplied;
    int duckUntil;
    bool duckReady;       // set by MusicDuckReset at the start of a run
    int perfLastTic;
    double perfLastMs;
    ui int uiSkips;
    ui int uiBanishes;
    ui bool actionHeld;
    ui int uiResultsRunId;
    ui int uiResultsStart;   // world time the results opened (the fall plays first in third person)
    ui int uiResultsElapsed;
    ui int uiResultsDamage;
    ui int uiResultsXp;
    ui int uiResultsCurrency;
    ui int uiResultsLevel;
    ui int modalScreenshotDelay;
    ui int resultsScreenshotDelay;
    ui bool combatScreenshotTaken;
    ui bool uiModalOpen;
    ui bool uiResultsOpen;
    ui bool uiP031Mode;
    ui bool uiP032Route;
    ui bool uiP032BloodyTear;
    ui bool uiP033DisplayLogged;

    int ActiveDraftQueueCount()
    {
        return UsesP031Progression() ? DSP031QueuedCount() : DSP028QueuedCount();
    }

    int ActiveDraftTargetLevel()
    {
        return UsesP031Progression() ? DSP031CurrentDraftLevel() : DSP028CurrentDraftLevel();
    }

    int ActiveDraftOfferCount()
    {
        return UsesP031Progression() ? dsp031OfferCount : DSP028CurrentOfferCount();
    }

    int ActiveDraftOfferId(int index)
    {
        return UsesP031Progression() ? DSP031OfferId(index) : DSP028OfferId(index);
    }

    int ActiveDraftOfferRank(int id)
    {
        return UsesP031Progression() ? DSP031OfferRank(id) : DSP028OfferRank(id);
    }

    String ActiveDraftOfferName(int id)
    {
        if (id == DSP031_ID_FALLBACK_GOLD) return "GOLD (approximation)";
        if (id == DSP031_ID_FALLBACK_CHICKEN) return "FLOOR CHICKEN (approximation)";
        if (DSLimitBreak.IsOffer(id)) return DSLimitBreak.Name(id) .. " (Limit Break)";
        // N2: every catalog item (base weapons beyond Whip, all passives,
        // and the pending-stat-effect rank carriers) shows its real display
        // name in the level-up UI instead of falling through to ILLEGAL.
        if (DSN2Catalog.IsKnown(id)) return DSN2Catalog.DisplayName(id);
        // P031 items outside the P028 table; without these, legally applied
        // choices were logged as offer_id=ILLEGAL (display text only).
        if (id == DSP031_ID_HOLLOW_HEART) return "HOLLOW_HEART";
        if (id == DSP031_ID_EMPTY_TOME) return "EMPTY_TOME";
        return DSP028OfferName(id);
    }

    int ActiveDraftAppliedCount()
    {
        return UsesP031Progression() ? dsp031AppliedDrafts : draftApplied;
    }

    bool CollectRunExperience(int amount)
    {
        if (ArcanaOwned(DSArcana.GAME_KILLER)) { ArcanaGemBomb(); return true; }
        // N2-W7 soak-only acceleration (ds_n2_xp_multiplier_milli, default
        // 1000 = unchanged): scales the real XP amount reaching the real
        // ledger/threshold rules before CollectExperience, so pacing can
        // reach >=12 real draft choices in a practical soak without
        // touching any grant fixture or evidence-ring bypass. Labelled
        // N2_XP_ACCELERATION_FIXTURE; never set by the default manual route.
        int scaled = amount;
        CVar mult = CVar.FindCVar("ds_n2_xp_multiplier_milli");
        int multMilli = mult != null ? mult.GetInt() : 1000;
        if (multMilli != 1000 && multMilli > 0)
        {
            scaled = (amount * multMilli) / 1000;
            if (scaled < amount && amount > 0) scaled = amount;
            { if (!dsQuiet) Console.Printf("DS_N2_XP_ACCELERATION_FIXTURE tic=%d base_amount=%d multiplier_milli=%d scaled_amount=%d classification=N2_XP_ACCELERATION_FIXTURE", tic, amount, multMilli, scaled); }
        }
        return UsesP031Progression() ? DSP031CollectExperience(scaled) : DSP028CollectExperience(scaled);
    }

    void ConfigureCamera()
    {
        CVar variant = CVar.FindCVar("ds_p030_camera_variant");
        cameraVariant = variant != null ? variant.GetInt() : 0;
        if (cameraVariant < 0 || cameraVariant > 2) cameraVariant = 0;
        cameraYaw = cameraVariant == 1 ? 90 : 0;
        cameraPitch = cameraVariant == 0 ? 0 : 22;
        cameraFov = cameraVariant == 0 ? 90 : 115;
    }

    void ConfigureDuration()
    {
        CVar duration = CVar.FindCVar("ds_p030_duration_tics");
        survivalTics = duration != null ? duration.GetInt() : SURVIVAL_TICS;
        // The player-facing launcher supplies one bounded minute only. Keep
        // malformed or unsupported console values on the frozen five-minute
        // contract instead of allowing an arbitrary gameplay duration.
        // The Mad Forest route also accepts the full 30:00 stage.
        if (mfEnabled && survivalTics == MAD_FOREST_TICS) return;
        if (survivalTics != MIN_SURVIVAL_TICS && survivalTics != MAX_SURVIVAL_TICS)
            survivalTics = SURVIVAL_TICS;
    }

    // Full-stage runs (ds_p030_duration_tics 63000) last the stage's own
    // time limit (15:00, 20:00 or 30:00); other runs keep survivalTics.
    clearscope int RunEndTic()
    {
        CVar endOverride = CVar.FindCVar("ds_mf_end_tics");
        if (endOverride != null && endOverride.GetInt() > 0 && mfEnabled) return endOverride.GetInt() + mfHeld;
        return mfEnabled && survivalTics == MAD_FOREST_TICS ? DSStage.DurationTics(mfStage) + mfHeld : survivalTics;
    }

    // Stage speed modifiers are relative to Mad Forest (x1.1), which the
    // playtest-tuned movement and enemy speeds were set on.
    clearscope double StageEnemySpeedScale()
    {
        if (!rsActive) return 1.0;
        double modeSpeed = rsMode == 1 ? 1.5 : (rsMode == 2 ? 1.2 : 1.0);
        return modeSpeed * (DSStage.EnemySpeedMilli(mfStage) + DSStage.SpeedPerMinuteMilli(mfStage) * (MfT() / 2100)) / 1100.0;
    }

    void ApplyCameraPose()
    {
        if (players[0].mo == null) return;
        players[0].mo.Angle = cameraYaw;
        players[0].mo.Pitch = cameraPitch;
        players[0].SetFOV(cameraFov);
    }

    void EmitCameraRow()
    {
        ApplyCameraPose();
        Console.Printf("DS_P030_CAMERA tic=%d variant=%d yaw=%d pitch=%d fov=%d logical_xy=(%.3f,%.3f) camera_role=PRESENTATION_ONLY gameplay_ignored=1", tic, cameraVariant, cameraYaw, cameraPitch, cameraFov, playerX, playerY);
    }

    // This is a harness-only invariant proof.  It deliberately runs the same
    // P024 broad phase, P030 lobe predicate and P025 checked hit transaction
    // used by the normal MAP16 Whip.  Temporary P020 handles are torn down
    // before the real run is reset, so the proof cannot seed gameplay state.
    void EvaluateBasisLobe(int lobe, int yaw, int targetFilter, out int eligibleSlot,
                           out int eligibleCount, out int appliedDamage)
    {
        eligibleSlot = -1; eligibleCount = 0; appliedDamage = 0;
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, 3000 + lobe, lobe == 1 ? 2999 : 0,
            playerSlot, generations[playerSlot], ids[playerSlot], ids[weaponSlot],
            generations[weaponSlot], DSP028WhipDamageForLevel(2), 0, 1000, 0,
            DSP028WhipAmountForLevel(2), 0, 1, 0, yaw * 1000, 270126, 1831565813);
        int checkedDamage;
        bool checked = DSP025CheckedMilliDamage(snapshot.damageBase, snapshot.multiplierMilli, checkedDamage);
        DSP024Rebuild(); DSP024RadiusCandidates(playerX, playerY, 140.0 * (rsActive ? rsAreaMilli / 1000.0 : 1.0));
        for (int i = 0; i < spatialCandidateCount; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stable = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stable) || kinds[slot] != KIND_ENEMY) continue;
            if (targetFilter >= 0 && slot != targetFilter) continue;
            if (!CircleInLobe(slot, yaw, lobe)) continue;
            eligibleCount++;
            if (eligibleSlot < 0) eligibleSlot = slot;
            int before; int after; int killed;
            if (checked && DSP025ApplyLogicalHit(slot, generation, stable, checkedDamage, before, after, killed))
                appliedDamage += before - after;
        }
    }

    void RunBasisProof()
    {
        // Keep the canonical handle allocation order fixed across camera
        // variants: player, weapon, east, north, west, south, diagonal.
        Reset(); DSP024ClearSpatial(); DSP027ResetExperience(); DSP028ResetProgression();
        playerX = 0.0; playerY = 0.0; tic = 0;
        playerSlot = Allocate(KIND_PLAYER, 0.0, 0.0, 0.0, 0.0, PLAYER_HEALTH);
        weaponSlot = Allocate(KIND_WEAPON, 0.0, 0.0, 0.0, 0.0, 1);
        int eastSlot = Allocate(KIND_ENEMY, 64.0, 0.0, 0.0, 0.0, 100000);
        int northSlot = Allocate(KIND_ENEMY, 0.0, 64.0, 0.0, 0.0, 100000);
        int westSlot = Allocate(KIND_ENEMY, -64.0, 0.0, 0.0, 0.0, 100000);
        int southSlot = Allocate(KIND_ENEMY, 0.0, -64.0, 0.0, 0.0, 100000);
        int diagonalSlot = Allocate(KIND_ENEMY, 64.0, 64.0, 0.0, 0.0, 100000);
        collisionRadii[playerSlot] = 2.0;
        collisionRadii[weaponSlot] = 0.0;
        collisionRadii[eastSlot] = 8.0; collisionRadii[northSlot] = 8.0;
        collisionRadii[westSlot] = 8.0; collisionRadii[southSlot] = 8.0;
        collisionRadii[diagonalSlot] = 8.0;
        health[eastSlot] = 100000; health[northSlot] = 100000;
        health[westSlot] = 100000; health[southSlot] = 100000;
        health[diagonalSlot] = 100000;
        int frontEligibleSlot; int frontEligibleCount; int frontDamage;
        int rearEligibleSlot; int rearEligibleCount; int rearDamage;
        int sideFrontSlot; int sideFrontCount; int sideFrontDamage;
        int sideRearSlot; int sideRearCount; int sideRearDamage;
        EvaluateBasisLobe(0, cameraYaw, -1, frontEligibleSlot, frontEligibleCount, frontDamage);
        EvaluateBasisLobe(1, cameraYaw, -1, rearEligibleSlot, rearEligibleCount, rearDamage);
        // Evaluate the side target through both production lobe queries.  The
        // diagonal remains outside both exact rectangles for yaw 0 and 90;
        // filtering selects only that known world handle while P024 still
        // performs the broad-phase discovery.
        EvaluateBasisLobe(0, cameraYaw, diagonalSlot, sideFrontSlot, sideFrontCount, sideFrontDamage);
        EvaluateBasisLobe(1, cameraYaw, diagonalSlot, sideRearSlot, sideRearCount, sideRearDamage);
        int checkedDamage;
        DSP025CheckedMilliDamage(DSP028WhipDamageForLevel(2), 1000, checkedDamage);
        int frontHandleSlot = frontEligibleSlot >= 0 ? frontEligibleSlot : eastSlot;
        int rearHandleSlot = rearEligibleSlot >= 0 ? rearEligibleSlot : westSlot;
        Console.Printf("DS_P030_BASIS_PROOF variant=%d yaw=%d pitch=%d fov=%d rank=2 amount=%d checked_damage=%d front_slot=%d front_generation=%d front_id=%d front_x=%.3f front_y=%.3f front_eligible=%d front_accepted=%d front_damage=%d rear_slot=%d rear_generation=%d rear_id=%d rear_x=%.3f rear_y=%.3f rear_eligible=%d rear_accepted=%d rear_damage=%d side_slot=%d side_generation=%d side_id=%d side_x=%.3f side_y=%.3f side_front_eligible=%d side_front_accepted=%d side_rear_eligible=%d side_rear_accepted=%d side_damage=%d query_source=P024 damage_source=P025 handles_invariant=1 damage_invariant=1 pitch_fov_presentation_only=1 camera_role=PRESENTATION_ONLY", cameraVariant, cameraYaw, cameraPitch, cameraFov, DSP028WhipAmountForLevel(2), checkedDamage, frontHandleSlot, generations[frontHandleSlot], ids[frontHandleSlot], x[frontHandleSlot], y[frontHandleSlot], frontEligibleCount, frontEligibleCount > 0 ? 1 : 0, frontDamage, rearHandleSlot, generations[rearHandleSlot], ids[rearHandleSlot], x[rearHandleSlot], y[rearHandleSlot], rearEligibleCount, rearEligibleCount > 0 ? 1 : 0, rearDamage, diagonalSlot, generations[diagonalSlot], ids[diagonalSlot], x[diagonalSlot], y[diagonalSlot], sideFrontCount, sideFrontCount > 0 ? 1 : 0, sideRearCount, sideRearCount > 0 ? 1 : 0, sideFrontDamage + sideRearDamage);
        DestroyParts(diagonalSlot, generations[diagonalSlot], ids[diagonalSlot]);
        DestroyParts(southSlot, generations[southSlot], ids[southSlot]);
        DestroyParts(westSlot, generations[westSlot], ids[westSlot]);
        DestroyParts(northSlot, generations[northSlot], ids[northSlot]);
        DestroyParts(eastSlot, generations[eastSlot], ids[eastSlot]);
        DestroyParts(weaponSlot, generations[weaponSlot], ids[weaponSlot]);
        DestroyParts(playerSlot, generations[playerSlot], ids[playerSlot]);
        DSP024ClearSpatial();
    }

    String StateName(int state)
    {
        if (state == STATE_STARTING) return "STARTING";
        if (state == STATE_ACTIVE) return "ACTIVE";
        if (state == STATE_LEVELUP) return "PAUSED_LEVELUP";
        if (state == STATE_ENDING) return "ENDING";
        if (state == STATE_RESULTS) return "RESULTS";
        return "RESTARTING";
    }

    void Transition(int nextState, String reason)
    {
        Console.Printf("DS_P030_TRANSITION run_id=%d generation=%d from=%s to=%s tic=%d reason=%s", runId, runGeneration, StateName(runState), StateName(nextState), tic, reason);
        priorState = runState; runState = nextState;
    }

    int LiveEnemyCount()
    {
        int count = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE && kinds[slot] == KIND_ENEMY) count++;
        return count;
    }

    int LiveStoreCount()
    {
        int count = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (lifeStates[slot] == STORE_ALIVE) count++;
        return count;
    }

    int LivePickupCount()
    {
        int count = 0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
            if (DSP027IsLivePickup(slot)) count++;
        return count;
    }

    int LiveWhipProxyCount()
    {
        int count = 0;
        ThinkerIterator whips = ThinkerIterator.Create("DSP030WhipProxy");
        Actor actor;
        while ((actor = Actor(whips.Next())) != null) count++;
        return count;
    }

    void DestroyAllProxies()
    {
        ThinkerIterator enemies = ThinkerIterator.Create("DSP030EnemyProxy");
        Actor actor;
        while ((actor = Actor(enemies.Next())) != null) actor.Destroy();
        ThinkerIterator pickups = ThinkerIterator.Create("DSP030PickupProxy");
        while ((actor = Actor(pickups.Next())) != null) actor.Destroy();
        ThinkerIterator whips = ThinkerIterator.Create("DSP030WhipProxy");
        while ((actor = Actor(whips.Next())) != null) actor.Destroy();
        ThinkerIterator chests = ThinkerIterator.Create("DSP032Map16ChestProxy");
        while ((actor = Actor(chests.Next())) != null) actor.Destroy();
    }

    void ClearNativeInput()
    {
        if (players[0].mo == null) return;
        players[0].cmd.forwardmove = 0; players[0].cmd.sidemove = 0;
        players[0].cmd.upmove = 0; players[0].cmd.yaw = 0;
        players[0].cmd.pitch = 0; players[0].cmd.roll = 0;
        players[0].cmd.buttons = 0;
    }

    void EmitInputOwnership(String state)
    {
        int owner = IsUiProcessor ? 1 : 0;
        int effectiveMouseRequest = owner != 0 && RequireMouse ? 1 : 0;
        Console.Printf("DS_P030_INPUT_OWNER state=%s map=%s ui_processor=%d effective_mouse_request=%d native_usercmd=%d registered_handlers_map16=P028:0,P029:0,P030:%d", state, MAP, owner, effectiveMouseRequest, owner == 0 ? 1 : 0, owner);
    }

    void EmitNativeInputTrace()
    {
        if (inputTraceEnabled == 0 || players[0].mo == null) return;
        UserCmd cmd = players[0].cmd;
        double poseX = players[0].mo.Pos.X;
        double poseY = players[0].mo.Pos.Y;
        double poseYaw = players[0].mo.Angle;
        double posePitch = players[0].mo.Pitch;
        bool commandPresent = cmd.forwardmove != 0 || cmd.sidemove != 0 || cmd.yaw != 0 || cmd.pitch != 0;
        bool poseChanged = !inputTraceInitialized || poseX != inputTraceX || poseY != inputTraceY || poseYaw != inputTraceYaw || posePitch != inputTracePitch;
        DSP021FirstPersonPlayer pawn = DSP021FirstPersonPlayer(players[0].mo);
        if (commandPresent || poseChanged)
        {
            Console.Printf("DS_P030_NATIVE_INPUT world_tic=%d state=%s before_clear=1 cmd_forward=%d cmd_side=%d cmd_yaw=%d cmd_pitch=%d pose_x=%.3f pose_y=%.3f pose_yaw=%.3f pose_pitch=%.3f pawn_forward=%.3f pawn_side=%.3f", tic, StateName(runState), cmd.forwardmove, cmd.sidemove, cmd.yaw, cmd.pitch, poseX, poseY, poseYaw, posePitch, pawn != null ? pawn.lastForwardInput : 0.0, pawn != null ? pawn.lastSideInput : 0.0);
        }
        inputTraceInitialized = true;
        inputTraceX = poseX; inputTraceY = poseY; inputTraceYaw = poseYaw; inputTracePitch = posePitch;
    }

    void SyncPlayer()
    {
        if (players[0].mo == null || playerSlot < 0) return;
        playerX = players[0].mo.Pos.X; playerY = players[0].mo.Pos.Y;
        if (ValidParts(playerSlot, generations[playerSlot], ids[playerSlot]))
        {
            x[playerSlot] = playerX; y[playerSlot] = playerY;
        }
    }

    int CurrentCap()
    {
        if (phase == 0) return 15;
        if (phase == 1) return 30;
        return 50;
    }

    void UpdateSpawnPhase()
    {
        if (phase == 0 && tic >= 2100)
        {
            phase = 1; spawnIndex = 1; nextSpawnTic = tic + 53;
            Console.Printf("DS_P030_STAGE_PHASE tic=%d minute=1 interval_num=3 interval_den=2 cap=30 provenance=ENGINEERING_APPROXIMATION", tic);
        }
        if (phase == 1 && tic >= 4200)
        {
            phase = 2; spawnIndex = 1; nextSpawnTic = tic + 35;
            Console.Printf("DS_P030_STAGE_PHASE tic=%d minute=2 interval_num=1 interval_den=1 cap=50 provenance=ENGINEERING_APPROXIMATION", tic);
        }
    }

    int NextSpawnDeadline()
    {
        if (phase == 0) return spawnIndex * 70;
        if (phase == 1) return 2100 + (spawnIndex * 105 + 1) / 2;
        return 4200 + spawnIndex * 35;
    }

    void EmitSpawnAttempt()
    {
        int eventId = spawnAttempts + 1;
        int rngBefore = spawnRng;
        spawnRng = DSP022StageGeometry.NextSpawnRng(spawnRng);
        double sx; double sy; int side; int lane;
        DSP022StageGeometry.Place(spawnRng, eventId, 0, 0, playerX, playerY, sx, sy, side, lane);
        spawnAttempts++;
        int live = LiveEnemyCount();
        bool admitted = live < CurrentCap();
        int slot = -1; int stable = 0; int generation = 0;
        if (admitted)
        {
            slot = Allocate(KIND_ENEMY, sx, sy, 0.0, 0.0, ENEMY_HEALTH);
            collisionRadii[slot] = 2.0;
            stable = ids[slot]; generation = generations[slot];
            spawnAdmissions++;
        }
        else spawnRejections++;
        Console.Printf("DS_P030_SPAWN event_id=%d tic=%d minute=%d attempt=%d kind=BAT3 admitted=%d slot=%d generation=%d stable_id=%d live=%d cap=%d x=%.3f y=%.3f side=%d lane=%d rng_stream=spawn rng_before=%d rng_after=%d", eventId, tic, phase, eventId, admitted, slot, generation, stable, admitted ? live + 1 : live, CurrentCap(), sx, sy, side, lane, rngBefore, spawnRng);
    }

    void ReleaseDueSpawns()
    {
        UpdateSpawnPhase();
        int released = 0;
        while (spawnIndex < 10000 && tic >= nextSpawnTic && released < 32)
        {
            EmitSpawnAttempt();
            spawnIndex++;
            nextSpawnTic = NextSpawnDeadline();
            released++;
        }
    }

    // ---- Mad Forest stage rules (timeline, bosses, events, Reaper) ----

    // ---- Light sources and floor items ----

    void MoveEnemies()
    {
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY) continue;
            if (p034RouteEnabled && p034TargetFixtureId != 0
                && ids[slot] == p034TargetFixtureId) continue;
            if (p035RouteEnabled
                && (ids[slot] == p035FrontFixtureId
                    || ids[slot] == p035AxeFixtureId)) continue;
            if (p037RouteEnabled && ids[slot] == p037TargetFixtureId) continue;
            double speed = ENEMY_SPEED;
            if (mfEnabled && MFValid(slot))
            {
                if (mfMotion[slot] == 2) continue;
                if (tic < mfFreezeUntil && !DSStage.IsReaperLike(mfTypes[slot])) continue;
                if (slot < mfDefang.Size() && mfDefang[slot] != 0) continue;   // Defang
                if (mfMotion[slot] == 1)
                {
                    x[slot] += mfVX[slot]; y[slot] += mfVY[slot];
                    continue;
                }
                speed = DSStage.SpeedMilliPerTic(mfTypes[slot]) / 1000.0 * StageEnemySpeedScale();
                if (rsActive) speed *= rsCurseMilli / 1000.0;
                if (GwFrozen(slot)) continue;
            }
            if (KnockbackStep(slot)) continue;
            if (GwSlowed(slot)) speed *= 0.5;
            double dx = playerX - x[slot]; double dy = playerY - y[slot];
            double distance = sqrt(dx * dx + dy * dy);
            // Far enemies close the gap faster (up to x2 beyond 900 units)
            // so the wider spawn ring does not thin out the fight.
            if (mfEnabled && MFValid(slot) && mfBoss[slot] == 0 && distance > 300.0)
                speed *= 1.0 + clamp((distance - 300.0) / 600.0, 0.0, 1.0);
            // The Depths: path through the corridors, not through the rock
            // (Reapers drift through walls).
            if (dgActive && MFValid(slot) && !DSStage.IsReaperLike(mfTypes[slot]))
            {
                DgMoveEnemy(slot, speed);
                continue;
            }
            if (distance > 0.00001)
            {
                double amount = speed < distance ? speed : distance;
                x[slot] += dx / distance * amount;
                y[slot] += dy / distance * amount;
            }
        }
    }

    void ProcessContact()
    {
        if (playerHealth <= 0) return;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE || kinds[slot] != KIND_ENEMY) continue;
            double dx = x[slot] - playerX; double dy = y[slot] - playerY;
            double contactRadius = CONTACT_RADIUS;
            int baseDamage = CONTACT_DAMAGE;
            if (mfEnabled && MFValid(slot))
            {
                // Light sources never hurt; Orologion-frozen enemies cannot.
                if (MFIsProp(mfTypes[slot])) continue;
                if (tic < mfFreezeUntil && !DSStage.IsReaperLike(mfTypes[slot])) continue;
                baseDamage = DSStage.PowerMilli(mfTypes[slot]);
                if (dgActive) baseDamage = baseDamage * (DG_POWER_MILLI + DG_DEPTH_POWER_MILLI * dgDepth) / 1000;
                if (DSStage.IsBig(mfTypes[slot])) contactRadius = 22.0;
            }
            if (sqrt(dx * dx + dy * dy) > contactRadius) continue;
            if (GwFrozen(slot)) continue;
            if (rsActive && gwShieldUntil > tic) { contactRejects++; continue; }
            if (timers[slot] > tic)
            {
                contactRejects++;
                { if (!dsQuiet) Console.Printf("DS_P030_CONTACT tic=%d enemy_id=%d accepted=0 reason=ATTACKER_COOLDOWN", tic, ids[slot]); }
                continue;
            }
            if (playerInvulnerableUntil > tic)
            {
                contactRejects++;
                { if (!dsQuiet) Console.Printf("DS_P030_CONTACT tic=%d enemy_id=%d accepted=0 reason=PLAYER_INVULNERABLE", tic, ids[slot]); }
                continue;
            }
            int before = playerHealth;
            int contactDamage = baseDamage;
            int armorBonus = 0;
            if (p033RouteEnabled
                && DSP033StatApplies(DSP033StatRules.STAT_ARMOR,
                    DSP033StatRules.SYSTEM_INCOMING_DAMAGE))
            {
                armorBonus = DSP033Resolved(DSP033StatRules.STAT_ARMOR) - 1;
                if (armorBonus < 0) armorBonus = 0;
                contactDamage = DSP033StatRules.IncomingDamageMilliAfterArmor(
                    baseDamage, armorBonus);
                Console.Printf("DS_P033_MAP16_CONTACT tic=%d enemy_id=%d raw_damage_milli=%d resolved_armor=%d passive_armor_bonus=%d applied_damage_milli=%d eligible=1 policy=BASE_CONTACT_PRESERVED_MINIMUM_1000_ENGINEERING_APPROXIMATION", tic, ids[slot], baseDamage, DSP033Resolved(DSP033StatRules.STAT_ARMOR), armorBonus, contactDamage);
            }
            // P039 controlled player-damage fixture (P039-A02 evidence): a
            // single dedicated contact enemy, sized at spawn time to land
            // health exactly at the ~40%-of-max target in this one hit, so
            // Recovery/Bloody-Tear/Little-Heart reconciliation has real
            // room to apply -- still through this same decrement-and-log
            // path, never a direct health write.
            if (p039ContactFixtureId != 0 && ids[slot] == p039ContactFixtureId)
                contactDamage = p039ContactFixtureDamageMilli;
            if (rsActive && rsArmor > 0)
                contactDamage = DSP033StatRules.IncomingDamageMilliAfterArmor(contactDamage, rsArmor);
            if (rsActive) contactDamage = GwShroudIncoming(contactDamage);
            // Revival: a lethal hit leaves 1 milli-HP, then heals to half.
            bool reviving = rsActive && rsRevivalsUsed < rsRevivalsGranted
                && contactDamage >= playerHealth && playerHealth > 1;
            if (reviving) contactDamage = playerHealth - 1;
            playerHealth -= contactDamage;
            if (playerHealth < 0) playerHealth = 0;
            health[playerSlot] = playerHealth;
            timers[slot] = tic + CONTACT_COOLDOWN;
            playerInvulnerableUntil = tic + INVULNERABLE_TICS + (rsActive ? rsInvulnTics : 0);
            contactHits++;
            { if (!dsQuiet) Console.Printf("DS_P030_CONTACT tic=%d enemy_id=%d accepted=1 damage=%d health_before=%d health_after=%d cooldown_until=%d invulnerable_until=%d", tic, ids[slot], contactDamage, before, playerHealth, timers[slot], playerInvulnerableUntil); }
            Sfx(DSSfx.HURT, 12);
            if (reviving) RevivePlayer();
            if (rsActive) GwOnPlayerHit();
            // NO FUTURE: every ACCEPTED player contact-damage transaction
            // notifies the bounce runtime, gated to once per 18 tics inside
            // DSP041NotifyPlayerContactDamage itself (docs/contracts/
            // bounce-projectiles.md "NO FUTURE" section).
            if (p041RouteEnabled || rsActive)
            {
                int armorPointsForNoFuture = rsActive ? max(1, rsArmor) : dsp033ResolvedValid
                    ? DSP033Resolved(DSP033StatRules.STAT_ARMOR) : 1;
                bool noFutureExploded = DSP041NotifyPlayerContactDamage(tic,
                    armorPointsForNoFuture);
                if (noFutureExploded) p041NoFutureExplosionsCredited++;
            }
            if (p033ContactFixtureId != 0 && ids[slot] == p033ContactFixtureId)
            {
                int fixtureId = ids[slot];
                int fixtureGeneration = generations[slot];
                int healthAfter = playerHealth;
                DestroyParts(slot, fixtureGeneration, fixtureId);
                p033ContactFixtureId = 0;
                DSP024Rebuild();
                Console.Printf("DS_P033_MAP16_CONTACT_COMPLETE accepted=1 tic=%d enemy_id=%d damage_milli=%d health_before=%d health_after=%d fixture_consumed=1 source=CONTROLLED_OPT_IN", tic, fixtureId, contactDamage, before, healthAfter);
            }
            if (p039ContactFixtureId != 0 && ids[slot] == p039ContactFixtureId)
            {
                int fixtureId = ids[slot];
                int fixtureGeneration = generations[slot];
                int healthAfter = playerHealth;
                DestroyParts(slot, fixtureGeneration, fixtureId);
                p039ContactFixtureId = 0;
                DSP024Rebuild();
                Console.Printf("DS_P039_MAP16_CONTACT_FIXTURE_COMPLETE accepted=1 tic=%d enemy_id=%d damage_milli=%d health_before=%d health_after=%d target_milli=%d fixture_consumed=1 source=CONTROLLED_OPT_IN", tic, fixtureId, contactDamage, before, healthAfter, p039ContactFixtureTargetMilli);
            }
            if (playerHealth == 0)
            {
                // Automated harness/soak runs still exercise contact damage,
                // but must reach the frozen 10,500-tic boundary. Manual and
                // explicit death modes retain the logical zero-health ending.
                // After 30:00 the Reaper's kill is the Mad Forest ending.
                if ((configuredMode == "harness" || configuredMode == "soak"
                    || configuredMode == "soak_n2")
                    && !(mfEnabled && tic >= RunEndTic()))
                {
                    playerHealth = CurrentPlayerHealthCap();
                    health[playerSlot] = playerHealth;
                    Console.Printf("DS_P030_CONTACT_GUARD tic=%d restored_health=%d mode=%s reason=AUTOMATED_SOAK", tic, playerHealth, configuredMode);
                }
                else { EndRun("PLAYER_ZERO_HEALTH"); return; }
            }
        }
    }

    void BindEnemyProxy(int slot)
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP030EnemyProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP030EnemyProxy proxy = DSP030EnemyProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generations[slot] && proxy.logicalStableId == ids[slot])
            { proxy.SetOrigin((x[slot], y[slot], 0.0), true); return; }
        }
        SpawnEnemyProxy(slot);
    }

    // Presentation only: tint/scale by Mad Forest family; reads rules state
    // and never writes it.
    void SpawnEnemyProxy(int slot)
    {
        bool propSlot = mfEnabled && MFValid(slot) && MFIsProp(mfTypes[slot]) && mfTypes[slot] != MF_BRAZIER_TYPE;
        bool brazier = mfEnabled && MFValid(slot) && mfTypes[slot] == MF_BRAZIER_TYPE;
        bool art = mfEnabled && MFValid(slot) && !brazier && !propSlot;
        DSP030EnemyProxy created = DSP030EnemyProxy(Actor.Spawn(
            propSlot ? "DSMFPropProxy" : brazier ? "DSMFBrazierProxy" : art ? "DSEnemyArtProxy" : "DSP030EnemyProxy", (x[slot], y[slot], 0.0), NO_REPLACE));
        if (created == null) return;
        created.logicalSlot = slot; created.logicalGeneration = generations[slot]; created.logicalStableId = ids[slot];
        if (!mfEnabled || !MFValid(slot) || brazier) return;
        if (propSlot)
        {
            created.sprite = Actor.GetSpriteIndex(mfTypes[slot] == MF_WINDOW_TYPE ? "DWND" : "DCRT");
            return;
        }
        int type = mfTypes[slot];
        created.sprite = Actor.GetSpriteIndex(EnemySpriteName(type));
        // Stagger the animation so a crowd does not flap in lockstep.
        created.tics = 1 + (ids[slot] % 8);
        double scale = DSStage.IsReaperLike(type) ? 1.5
            : (mfBoss[slot] > 0 ? 1.1 : DSStage.IsBig(type) ? 0.95 : 0.6);
        created.A_SetScale(scale);
        // Defanged enemies (Defang PowerUp) look green, like the original.
        if (slot < mfDefang.Size() && mfDefang[slot] != 0) created.A_SetTranslation("DefangGreen");
    }

    void BindPickupProxy(int slot)
    {
        ThinkerIterator it = ThinkerIterator.Create("DSP030PickupProxy");
        Actor actor;
        while ((actor = Actor(it.Next())) != null)
        {
            DSP030PickupProxy proxy = DSP030PickupProxy(actor);
            if (proxy.logicalSlot == slot && proxy.logicalGeneration == generations[slot] && proxy.logicalStableId == ids[slot])
            { proxy.SetOrigin((x[slot], y[slot], 2.0), true); return; }
        }
        DSP030PickupProxy created = DSP030PickupProxy(Actor.Spawn("DSP030PickupProxy", (x[slot], y[slot], 2.0), NO_REPLACE));
        if (created != null)
        {
            created.logicalSlot = slot; created.logicalGeneration = generations[slot]; created.logicalStableId = ids[slot];
            // Gem colour by XP value (presentation only): blue, green, red.
            int value = slot < experienceValues.Size() ? experienceValues[slot] : 0;
            created.sprite = Actor.GetSpriteIndex(value <= 2000 ? "GEMB" : value <= 10000 ? "GEMG" : "GEMR");
            created.tics = 1 + (ids[slot] % 10);
        }
    }

    void SyncPresentation()
    {
        ThinkerIterator enemyIt = ThinkerIterator.Create("DSP030EnemyProxy");
        Actor actor;
        // One pass over proxies marks bound slots, so binding below stays
        // linear in the enemy count instead of one iterator per enemy.
        Array<int> enemyBound;
        for (int slot = 0; slot < lifeStates.Size(); slot++) enemyBound.Push(0);
        while ((actor = Actor(enemyIt.Next())) != null)
        {
            DSP030EnemyProxy proxy = DSP030EnemyProxy(actor);
            if (!ValidParts(proxy.logicalSlot, proxy.logicalGeneration, proxy.logicalStableId) || kinds[proxy.logicalSlot] != KIND_ENEMY
                || enemyBound[proxy.logicalSlot] != 0) actor.Destroy();
            else
            {
                proxy.SetOrigin((x[proxy.logicalSlot], y[proxy.logicalSlot], 0.0), true);
                enemyBound[proxy.logicalSlot] = 1;
                int now = health[proxy.logicalSlot];
                if (proxy.lastHealth > 0 && now < proxy.lastHealth && now > 0) proxy.flashTics = 2;
                proxy.lastHealth = now;
            }
        }
        ThinkerIterator pickupIt = ThinkerIterator.Create("DSP030PickupProxy");
        while ((actor = Actor(pickupIt.Next())) != null)
        {
            DSP030PickupProxy proxy = DSP030PickupProxy(actor);
            if (!DSP027ValidPickup(proxy.logicalSlot, proxy.logicalGeneration, proxy.logicalStableId)) actor.Destroy();
            else proxy.SetOrigin((x[proxy.logicalSlot], y[proxy.logicalSlot], 2.0), true);
        }
        SyncP037OrbitProxies();
        SyncWeaponFx();
        MFSyncItemProxies();
        if (runState != STATE_ACTIVE) return;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            if (kinds[slot] == KIND_ENEMY) { if (enemyBound[slot] == 0) SpawnEnemyProxy(slot); }
            else if (DSP027IsLivePickup(slot)) BindPickupProxy(slot);
        }
    }

    // Death fade at the enemy's spot: capped per tic and by distance so a
    // screen-wide Rosary does not spawn hundreds of actors.
    void SpawnDeathFx(int slot, double fx, double fy)
    {
        if (!mfEnabled || !MFValid(slot) || runState != STATE_ACTIVE) return;
        if (deathFxTic != tic) { deathFxTic = tic; deathFxCount = 0; }
        if (deathFxCount >= 6) return;
        double dx = fx - playerX; double dy = fy - playerY;
        if (dx * dx + dy * dy > 1600.0 * 1600.0) return;
        int type = mfTypes[slot];
        DSEnemyDeathFx fxActor = DSEnemyDeathFx(Actor.Spawn("DSEnemyDeathFx", (fx, fy, 0.0), NO_REPLACE));
        if (fxActor == null) return;
        deathFxCount++;
        fxActor.sprite = Actor.GetSpriteIndex(EnemySpriteName(type));
        fxActor.baseScale = DSStage.IsReaperLike(type) ? 1.5 : (mfBoss[slot] > 0 ? 1.1 : DSStage.IsBig(type) ? 0.95 : 0.6);
        fxActor.A_SetScale(fxActor.baseScale);
    }

    String EnemySpriteName(int type)
    {
        if (DSStage.IsBig(type))
        {
            String boss = DSEnemyArt.BossSprite(DSStage.TypeName(type));
            if (boss.Length() > 0) return boss;
        }
        return DSEnemyArt.SpriteFor(DSStage.Family(type), DSStage.Variant(type));
    }

    void HandleEnemyDeath(int slot, int beforeHealth, int eventId)
    {
        DeathSfx(slot);
        int generation = generations[slot]; int stable = ids[slot];
        double deathX = x[slot]; double deathY = y[slot];
        int deathType = mfEnabled && MFValid(slot) ? mfTypes[slot] : 0;
        if (mfEnabled && MFValid(slot) && MFIsProp(mfTypes[slot]))
        {
            // A destroyed prop (light source, window, cart) is not a kill and gives no XP.
            int propType = mfTypes[slot];
            mfStable[slot] = 0;
            DestroyParts(slot, generation, stable);
            if (propType == MF_BRAZIER_TYPE) MFDropLightSourceItem(deathX, deathY);
            else GmPropDied(propType, slot, deathX, deathY);
            return;
        }
        kills++;
        MFOnKillGold();
        SpawnDeathFx(slot, deathX, deathY);
        int xpValue = PICKUP_VALUE;
        int bossIndex = 0;
        String source = "BAT3";
        if (mfEnabled && MFValid(slot))
        {
            xpValue = DSStage.XpMilli(mfTypes[slot]) * DSStage.StageXpMilli(mfStage) / 1000 * (rsMode == 2 ? 3 : 2) / 2;
            bossIndex = mfBoss[slot];
            MetaCountKill(mfTypes[slot]);
            source = DSStage.TypeName(mfTypes[slot]);
            mfStable[slot] = 0;
        }
        { if (!dsQuiet) Console.Printf("DS_P030_DEATH tic=%d target_slot=%d target_generation=%d target_id=%d health_before=%d health_after=0 xp_value=%d native_death=DISABLED accepted=1", tic, slot, generation, stable, beforeHealth, xpValue); }
        DestroyParts(slot, generation, stable);
        DSP027ExperienceHandle handle;
        if (xpValue > 0 && DSP027CreatePickup(xpValue, deathX, deathY, tic, handle))
        {
            xpCreatedLedger += xpValue;
            { if (!dsQuiet) Console.Printf("DS_P030_XP_CREATE tic=%d slot=%d generation=%d stable_id=%d value=%d source=%s_DEATH", tic, handle.slot, handle.generation, handle.stableId, xpValue, source); }
        }
        if (bossIndex > 0) MFDropBossChest(bossIndex - 1, deathX, deathY);
        if (mfEnabled && DSStage.ENDER_TYPE > 0 && mfEnderAlive && deathType == DSStage.ENDER_TYPE)
        {
            mfEnderAlive = false;
            Array<String> ek; Array<int> ev;
            DSMeta.Load(ek, ev);
            DSMeta.SetVal(ek, ev, "ender", 1);
            DSMeta.Store(ek, ev);
            GmShowToast("The Ender is defeated! Game Killer is yours.");
            Console.Printf("DS_MF_ENDER_DEFEATED tic=%d kills=%d", tic, kills);
            EndRun("ENDER_DEFEATED");
        }
    }

    void LocalCoordinates(double dx, double dy, double yaw, out double forward, out double lateral)
    {
        // EventHandlers do not inherit Actor's AngleToVector helper. ZScript's
        // trigonometric intrinsics take degrees, matching Actor.Angle and the
        // P021 first-person view basis.
        double sideYaw = yaw - 90.0;
        forward = dx * cos(yaw) + dy * sin(yaw);
        lateral = dx * cos(sideYaw) + dy * sin(sideYaw);
    }

    void PublishUiState()
    {
        int front = 0; int side = 0; int rear = 0; int nearby = 0;
        double yaw = players[0].mo != null ? players[0].mo.Angle : 0.0;
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] == STORE_ALIVE && kinds[slot] == KIND_ENEMY)
            {
                double dx = x[slot] - playerX; double dy = y[slot] - playerY;
                double forward; double lateral;
                LocalCoordinates(dx, dy, yaw, forward, lateral);
                if (sqrt(dx * dx + dy * dy) <= 112.0)
                {
                    if (forward >= 0.0 && abs(lateral) <= 48.0) front++;
                    else if (forward < 0.0 && abs(lateral) <= 48.0) rear++;
                    else side++;
                }
            }
            if (DSP027IsLivePickup(slot))
            {
                double dx = x[slot] - playerX; double dy = y[slot] - playerY;
                if (sqrt(dx * dx + dy * dy) <= AttractRadius()) nearby++;
            }
        }
        hudHealthCap = CurrentPlayerHealthCap();
        hudXpNeed = UsesP031Progression() ? DSP031ThresholdForCurrentLevel(playerLevel) : 0;
        SendInterfaceEvent(consoleplayer, "P030_STATE", tic, playerHealth, playerLevel);
        SendInterfaceEvent(consoleplayer, "P030_STATE_B", experienceMilliunits, kills, LiveEnemyCount());
        SendInterfaceEvent(consoleplayer, "P030_STATE_C", LivePickupCount(), CurrentCap(), whipRank);
        SendInterfaceEvent(consoleplayer, "P030_STATE_D", front, side, rear);
        SendInterfaceEvent(consoleplayer, "P030_STATE_E", nearby, sweepLobe, sweepUntil > tic ? 1 : 0);
        SendInterfaceEvent(consoleplayer, "P030_STATS", powerRank, characterArmor, levelUpChoices);
        if (arPickOpen) PublishArcanaOffers();
        else
        {
            SendInterfaceEvent(consoleplayer, "P030_OFFER0", ActiveDraftOfferId(0), ActiveDraftOfferRank(ActiveDraftOfferId(0)), ActiveDraftTargetLevel());
            SendInterfaceEvent(consoleplayer, "P030_OFFER1", ActiveDraftOfferId(1), ActiveDraftOfferRank(ActiveDraftOfferId(1)), ActiveDraftOfferCount());
            SendInterfaceEvent(consoleplayer, "P030_OFFER2", ActiveDraftOfferId(2), ActiveDraftOfferRank(ActiveDraftOfferId(2)), ActiveDraftQueueCount());
        }
    }

    bool CircleInLobe(int slot, double yaw, int lobe, double widen = 1.0)
    {
        double forward; double lateral;
        LocalCoordinates(x[slot] - playerX, y[slot] - playerY, yaw, forward, lateral);
        double areaScale = (rsActive ? RsAreaFor(DSP033StatRules.SYSTEM_WHIP) / 1000.0 : 1.0) * widen;
        double reach = 128.0 * areaScale; double halfWidth = 48.0 * areaScale;   // 96 wide (was 48)
        double minForward = lobe == 0 ? 0.0 : -reach;
        double maxForward = lobe == 0 ? reach : 0.0;
        double closestForward = forward < minForward ? minForward : (forward > maxForward ? maxForward : forward);
        double closestLateral = lateral < -halfWidth ? -halfWidth : (lateral > halfWidth ? halfWidth : lateral);
        double df = forward - closestForward; double dl = lateral - closestLateral;
        return df * df + dl * dl <= 4.0 * 4.0 + 0.000001;
    }

    bool HitWasRecorded(int eventId, int slot, int generation, int stable)
    {
        for (int i = 0; i < historyEvent.Size(); i++)
            if (historyEvent[i] == eventId && historyTargetSlot[i] == slot && historyTargetGeneration[i] == generation && historyTargetId[i] == stable) return true;
        return false;
    }

    // Presentation only: the sweep flash sits out along its lobe, below eye
    // level, instead of inside the camera.
    double WhipYaw(int lobe)
    {
        return lobe == 1 ? whipAimYaw + 180.0 : whipAimYaw;
    }

    // Aim assist, the same in first and third person: weapons that fire along your
    // facing (Knife, Thousand Edge, Phiera, Vento Sacro, ... and the Whip) nudge
    // toward the nearest enemy inside a 60 degree cone either side of where you
    // face, within `range` units; with none in the cone they fire straight ahead.
    // ds_aim_assist 0 turns it off.
    double AimAssistYaw(double range)
    {
        double yaw = players[0].mo != null ? players[0].mo.Angle : 0.0;
        CVar assist = CVar.FindCVar("ds_aim_assist");
        if (assist != null && assist.GetInt() == 0) return yaw;
        DSP024Rebuild();
        Array<int> found;
        GwEnemiesNear(playerX, playerY, range, found);
        int best = -1; double bestDistance = 0.0; double bestYaw = yaw;
        for (int i = 0; i < found.Size(); i++)
        {
            int slot = found[i];
            if (mfEnabled && MFValid(slot) && MFIsProp(mfTypes[slot])) continue;
            double dx = x[slot] - playerX; double dy = y[slot] - playerY;
            double d = dx * dx + dy * dy;
            double toEnemy = atan2(dy, dx);
            double off = toEnemy - yaw; off -= 360.0 * floor((off + 180.0) / 360.0);
            if (abs(off) > 60.0) continue;
            if (best < 0 || d < bestDistance) { best = slot; bestDistance = d; bestYaw = toEnemy; }
        }
        return bestYaw;
    }

    double WhipAim() { return AimAssistYaw(220.0); }

    Vector3 WhipEffectPos(int lobe)
    {
        double yaw = whipAimYaw;
        if (lobe == 1) yaw += 180.0;
        return (playerX + cos(yaw) * 48.0, playerY + sin(yaw) * 48.0, DSProjectileProxyBase.VISUAL_Z);
    }

    void EmitWhipLobe(int lobe)
    {
        Sfx(DSP032Rank(DSP032_ID_BLOODY_TEAR) > 0 ? DSSfx.W_BLOODY_TEAR : DSSfx.W_WHIP);
        int currentEvent = attackEventId + 1; attackEventId = currentEvent;
        int rngBefore = attackRng; attackRng = DSP025NextAttackRng(attackRng);
        DSP024Rebuild(); whipAimYaw = WhipAim();
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, currentEvent, lobe == 1 ? currentEvent - 1 : 0,
            playerSlot, generations[playerSlot], ids[playerSlot], ids[weaponSlot],
            generations[weaponSlot], DSP028WhipDamageForLevel(inventoryWeaponLevel), 0,
            CurrentWeaponMight(DSP033StatRules.SYSTEM_WHIP), 0, DSP028WhipAmountForLevel(inventoryWeaponLevel), tic,
            1, 0, int(whipAimYaw * 1000.0), rngBefore, attackRng);
        int candidateCount = 0; int hitCount = 0;
        DSP024Rebuild(); DSP024RadiusCandidates(playerX, playerY, 150.0 * (rsActive ? rsAreaMilli / 1000.0 : 1.0));
        int damageMilli; bool checked = DSP025CheckedMilliDamage(snapshot.damageBase, snapshot.multiplierMilli, damageMilli);
        for (int i = 0; i < spatialCandidateCount && runState == STATE_ACTIVE; i++)
        {
            int slot = spatialCandidateSlots[i]; int generation = spatialCandidateGenerations[i]; int stable = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stable) || kinds[slot] != KIND_ENEMY) continue;
            candidateCount++;
            if (!CircleInLobe(slot, snapshot.aimYawMilli / 1000.0, lobe)) continue;
            if (HitWasRecorded(currentEvent, slot, generation, stable)) continue;
            historyEvent.Push(currentEvent); historyTargetSlot.Push(slot); historyTargetGeneration.Push(generation); historyTargetId.Push(stable);
            int before; int after; int killed;
            bool applied = checked && DSP025ApplyLogicalHit(slot, generation, stable, damageMilli, before, after, killed);
            if (!applied) continue;
            hitCount++; AddDamageDealt(before - after); Sfx(DSSfx.H_WHIP, 4);
            { if (!dsQuiet) Console.Printf("DS_P030_HIT event_id=%d parent_event_id=%d tic=%d lobe=%d target_slot=%d target_generation=%d target_id=%d before=%d after=%d amount=%d accepted=1 camera_role=PRESENTATION_ONLY", currentEvent, snapshot.parentEventId, tic, lobe, slot, generation, stable, before, after, damageMilli); }
            if (killed != 0) HandleEnemyDeath(slot, before, currentEvent);
            else if (rsActive) EnemyKnockback(slot, playerX, playerY, 1000);
        }
        sweepUntil = tic + 5; sweepLobe = lobe; sweepEvent = currentEvent;
        if (rsActive && checked && RsDurationFor(DSP033StatRules.SYSTEM_WHIP) > 1000)
        {
            whipLingerEvent.Push(currentEvent); whipLingerLobe.Push(lobe);
            whipLingerYaw.Push(snapshot.aimYawMilli); whipLingerDamage.Push(damageMilli);
            whipLingerUntil.Push(tic + 5 * (RsDurationFor(DSP033StatRules.SYSTEM_WHIP) - 1000) / 1000);
        }
        { if (!dsQuiet) Console.Printf("DS_P030_WHIP event_id=%d parent_event_id=%d tic=%d lobe=%d weapon=WHIP level=%d amount=%d damage_source=%d damage_milli=%d checked=%d candidates=%d hits=%d automatic=1 concurrent=1 rng_stream=attack rng_before=%d rng_after=%d", currentEvent, snapshot.parentEventId, tic, lobe, inventoryWeaponLevel, snapshot.amount, snapshot.damageBase, damageMilli, checked, candidateCount, hitCount, rngBefore, attackRng); }
        if (p033RouteEnabled)
            Console.Printf("DS_P033_MAP16_ATTACK event_id=%d tic=%d system=WHIP system_id=%d eligible=1 stat_applied=1 rank_hash=%d might_milli=%d cooldown_multiplier_milli=%d damage_milli=%d camera_variant=%d", currentEvent, tic, DSP033StatRules.SYSTEM_WHIP, dsp033ResolvedRankHash, CurrentWeaponMight(DSP033StatRules.SYSTEM_WHIP), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), damageMilli, cameraVariant);
        DSP030WhipProxy effect = DSP030WhipProxy(Actor.Spawn("DSP030WhipProxy", WhipEffectPos(lobe), NO_REPLACE));
        if (effect != null) { effect.logicalEventId = currentEvent; effect.logicalLobe = lobe; effect.Setup(playerX, playerY, WhipYaw(lobe), 140.0 * (rsActive ? rsAreaMilli / 1000.0 : 1.0)); }
        int liveWhipProxies = LiveWhipProxyCount();
        if (liveWhipProxies > peakWhipProxies) peakWhipProxies = liveWhipProxies;
        // Each 5-tic flash overlaps more when Cooldown is reduced (Porta starts
        // at -90%), so the bound scales with the run's cooldown.
        int whipProxyLimit = rsActive ? max(2, 2 + 10 * (1000 - rsCooldownMilli) / 1000 + 2 + 2 * RsAmountFor(DSP033StatRules.SYSTEM_WHIP)) : 2;
        if (liveWhipProxies > whipProxyLimit)
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P030_WHIP_PROXY_LEAK tic=%d live=%d limit=%d", tic, liveWhipProxies, whipProxyLimit);
        if (telemetryEnabled != 0)
            { if (!dsQuiet) Console.Printf("DS_P030_WHIP_PROXY tic=%d event_id=%d count=%d bounded_lifetime_tics=5", tic, currentEvent, LiveWhipProxyCount()); }
    }

    // Bloody Tear replaces the Whip once its chest evolution is taken: on the
    // P032 fixture route and in every normal (run-stat) run.
    bool BloodyTearOwned()
    {
        return (p032RouteEnabled || rsActive) && DSP032Rank(DSP032_ID_BLOODY_TEAR) > 0;
    }

    void EmitBloodyTearLobe(int lobe)
    {
        if (!BloodyTearOwned()
            || weaponSlot < 0 || !ValidParts(weaponSlot, generations[weaponSlot], ids[weaponSlot])) return;
        int currentEvent = ++p032EventId;
        int rngBefore = p032AttackRng;
        p032AttackRng = DSP025NextAttackRng(p032AttackRng);
        DSP024Rebuild(); whipAimYaw = WhipAim();
        // Bloody Tear is an automatic Whip-like sweep adapter. Geometry,
        // 10% double-damage crit and one-point-per-hit healing are explicit
        // engineering approximations; P026 Whip facts remain unchanged.
        bool critical = (p032AttackRng & 1023) < 103;
        DSP025AttackSnapshot snapshot;
        DSP025PopulateSnapshot(snapshot, 200000 + currentEvent,
            lobe == 1 ? 199999 + currentEvent : 0,
            playerSlot, generations[playerSlot], ids[playerSlot], ids[weaponSlot],
            generations[weaponSlot], DSP028WhipDamageForLevel(8), 0,
            CurrentWeaponMight(DSP033StatRules.SYSTEM_BLOODY_TEAR), 0, DSP028WhipAmountForLevel(8), tic,
            1, 0, int(whipAimYaw * 1000.0), rngBefore, p032AttackRng);
        int damageMilli = 0;
        bool checked = DSP025CheckedMilliDamage(snapshot.damageBase,
            snapshot.multiplierMilli, damageMilli);
        if (checked && critical) damageMilli *= 2;
        int candidates = 0; int hits = 0; int healed = 0;
        DSP024Rebuild(); DSP024RadiusCandidates(playerX, playerY, 150.0 * (rsActive ? rsAreaMilli / 1000.0 : 1.0));
        for (int i = 0; i < spatialCandidateCount && runState == STATE_ACTIVE; i++)
        {
            int slot = spatialCandidateSlots[i];
            int generation = spatialCandidateGenerations[i];
            int stable = spatialCandidateIds[i];
            if (!ValidParts(slot, generation, stable) || kinds[slot] != KIND_ENEMY) continue;
            candidates++;
            if (!CircleInLobe(slot, snapshot.aimYawMilli / 1000.0, lobe, rsActive ? 1.25 : 1.0)
                || HitWasRecorded(snapshot.eventId, slot, generation, stable)) continue;
            historyEvent.Push(snapshot.eventId); historyTargetSlot.Push(slot);
            historyTargetGeneration.Push(generation); historyTargetId.Push(stable);
            int before; int after; int killed;
            if (!checked || !DSP025ApplyLogicalHit(slot, generation, stable,
                damageMilli, before, after, killed)) continue;
            hits++; AddDamageDealt(before - after); Sfx(DSSfx.H_WHIP, 4);
            // P039 migration: the healing authority is the only path that
            // may add to playerHealth. Only an accepted CRITICAL hit drains,
            // for a fixed 8000 milli-HP (unscaled), gated to at most once
            // every 35 tics -- replacing the old unconditional +1000-per-hit
            // approximation (docs/contracts/auras-healing.md "Healing
            // authority and same-tic order").
            int healthBefore = playerHealth;
            if (critical && DSP039BloodyTearDrainReady(tic))
            {
                int maxHealthMilli = CurrentPlayerHealthCap();
                int healthAfter; int appliedMilli;
                bool healAccepted = DSP039ApplyHeal(SOURCE_BLOODY_TEAR,
                    DSP039AuraRows.BLOODY_TEAR_DRAIN_MILLI, tic,
                    runState == STATE_ACTIVE, playerHealth, maxHealthMilli,
                    healthAfter, appliedMilli);
                playerHealth = healthAfter;
                health[playerSlot] = playerHealth;
                if (healAccepted)
                {
                    DSP039ConsumeBloodyTearDrain(tic);
                    healed += appliedMilli;
                    if ((p039RouteEnabled || rsActive) && appliedMilli > 0)
                        DSP039FeedSoulEaterGrowth(appliedMilli, tic);
                }
            }
            if (!dsQuiet) Console.Printf("DS_P032_BLOODY_TEAR_HIT event_id=%d tic=%d lobe=%d target_id=%d damage_milli=%d critical=%d heal_milli=%d accepted=1", currentEvent, tic, lobe, stable, damageMilli, critical, playerHealth - healthBefore);
            if (p033RouteEnabled && p033RestorePendingAttack)
            {
                Console.Printf("DS_P033_MAP16_RESTORE_ATTACK accepted=1 system=BLOODY_TEAR event_id=%d tic=%d target_slot=%d target_generation=%d target_id=%d damage_milli=%d weapon_id=%d weapon_generation=%d rank_hash=%d hit_join=1 joined_marker=DS_P032_BLOODY_TEAR_HIT", currentEvent, tic, slot, generation, stable, damageMilli, ids[weaponSlot], generations[weaponSlot], dsp033ResolvedRankHash);
                p033RestorePendingAttack = false;
            }
            if (critical && rsActive) { FxCount("crit"); OnCrit(x[slot], y[slot], DSP033StatRules.SYSTEM_BLOODY_TEAR); }
            if (killed != 0) HandleEnemyDeath(slot, before, snapshot.eventId);
            else if (rsActive) EnemyKnockback(slot, playerX, playerY, 1000);
        }
        sweepUntil = tic + 5; sweepLobe = lobe; sweepEvent = 200000 + currentEvent;
        if (!dsQuiet) Console.Printf("DS_P032_BLOODY_TEAR_AUTO event_id=%d tic=%d weapon_id=%d weapon_generation=%d rank=%d lobe=%d amount=%d damage_milli=%d crit=%d candidates=%d hits=%d heal_milli=%d automatic=1 concurrent=1 geometry=ENGINEERING_APPROXIMATION crit=ENGINEERING_APPROXIMATION heal=ENGINEERING_APPROXIMATION rng_stream=P032_BLOODY_TEAR rng_before=%d rng_after=%d", currentEvent, tic, ids[weaponSlot], generations[weaponSlot], DSP032Rank(DSP032_ID_BLOODY_TEAR), lobe, snapshot.amount, damageMilli, critical, candidates, hits, healed, rngBefore, p032AttackRng);
        if (p033RouteEnabled)
            Console.Printf("DS_P033_MAP16_ATTACK event_id=%d tic=%d system=BLOODY_TEAR system_id=%d eligible=1 stat_applied=1 rank_hash=%d might_milli=%d cooldown_multiplier_milli=%d damage_milli=%d camera_variant=%d", currentEvent, tic, DSP033StatRules.SYSTEM_BLOODY_TEAR, dsp033ResolvedRankHash, CurrentWeaponMight(DSP033StatRules.SYSTEM_BLOODY_TEAR), DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), damageMilli, cameraVariant);
        DSP030WhipProxy effect = DSP030WhipProxy(Actor.Spawn("DSP030WhipProxy", WhipEffectPos(lobe), NO_REPLACE));
        if (effect != null) { effect.logicalEventId = 200000 + currentEvent; effect.logicalLobe = lobe; effect.Setup(playerX, playerY, WhipYaw(lobe), 140.0 * (rsActive ? rsAreaMilli / 1000.0 : 1.0)); }
    }

    void ProcessWhip()
    {
        if (players[0].mo == null) return;
        // Not owned yet: keep the schedule current so a later draft starts
        // on a normal cadence instead of catching up missed swings.
        if (rsActive && whipRank <= 0) { nextWhipQuarter = (tic + 1) * 4; pendingRear = 0; return; }
        if (DSP025DeadlineDue(tic, nextWhipQuarter, 4))
        {
            if (BloodyTearOwned())
                EmitBloodyTearLobe(0);
            else EmitWhipLobe(0);
            int systemId = BloodyTearOwned()
                ? DSP033StatRules.SYSTEM_BLOODY_TEAR : DSP033StatRules.SYSTEM_WHIP;
            nextWhipQuarter = DSP025AdvanceDeadline(nextWhipQuarter,
                CurrentWeaponCooldownQuarter(systemId), 4, 4);
            // Amount = swings per volley (level table plus Duplicator etc.),
            // alternating front and back 0.1 s apart.
            bool tear = BloodyTearOwned();
            int swings = DSP028WhipAmountForLevel(tear ? 8 : inventoryWeaponLevel)
                + (rsActive ? RsAmountFor(systemId) : 0);
            whipSwingIdx = 1;
            pendingRear = max(0, min(swings, 8) - 1);
            if (pendingRear > 0)
                pendingRearQuarter = DSP025AdvanceDeadline(tic * 4, 7, 2, 4);
        }
        while (pendingRear > 0 && DSP025DeadlineDue(tic, pendingRearQuarter, 4))
        {
            int lobe = whipSwingIdx % 2;
            whipSwingIdx++;
            pendingRear--;
            if (BloodyTearOwned())
                EmitBloodyTearLobe(lobe);
            else EmitWhipLobe(lobe);
            if (pendingRear > 0)
                pendingRearQuarter = DSP025AdvanceDeadline(pendingRearQuarter, 7, 2, 4);
        }
        WhipLinger();
    }

    // Duration above 100% keeps each sweep's hit area live for extra tics.
    void WhipLinger()
    {
        for (int k = whipLingerUntil.Size() - 1; k >= 0; k--)
        {
            if (tic > whipLingerUntil[k] || runState != STATE_ACTIVE)
            {
                whipLingerEvent.Delete(k); whipLingerLobe.Delete(k); whipLingerYaw.Delete(k);
                whipLingerUntil.Delete(k); whipLingerDamage.Delete(k);
                continue;
            }
            DSP024Rebuild(); DSP024RadiusCandidates(playerX, playerY, 150.0 * (rsActive ? rsAreaMilli / 1000.0 : 1.0));
            for (int i = 0; i < spatialCandidateCount && runState == STATE_ACTIVE; i++)
            {
                int slot = spatialCandidateSlots[i]; int generation = spatialCandidateGenerations[i]; int stable = spatialCandidateIds[i];
                if (!ValidParts(slot, generation, stable) || kinds[slot] != KIND_ENEMY) continue;
                if (!CircleInLobe(slot, whipLingerYaw[k] / 1000.0, whipLingerLobe[k])) continue;
                if (HitWasRecorded(whipLingerEvent[k], slot, generation, stable)) continue;
                historyEvent.Push(whipLingerEvent[k]); historyTargetSlot.Push(slot); historyTargetGeneration.Push(generation); historyTargetId.Push(stable);
                int before; int after; int killed;
                if (!DSP025ApplyLogicalHit(slot, generation, stable, whipLingerDamage[k], before, after, killed)) continue;
                AddDamageDealt(before - after);
                if (killed != 0) HandleEnemyDeath(slot, before, whipLingerEvent[k]);
            }
        }
    }

    int ClearWhipProxies()
    {
        ThinkerIterator whips = ThinkerIterator.Create("DSP030WhipProxy");
        Actor actor;
        int cancelled = 0;
        while ((actor = Actor(whips.Next())) != null) { actor.Destroy(); cancelled++; }
        sweepUntil = 0; pendingRear = 0; pendingRearQuarter = 0;
        whipLingerEvent.Clear(); whipLingerLobe.Clear(); whipLingerYaw.Clear(); whipLingerUntil.Clear(); whipLingerDamage.Clear();
        return cancelled;
    }

    // ==== N2 weapon dispatcher =============================================
    // docs/contracts/normal-play-integration.md "Weapon dispatcher": generic
    // AcquireWeapon/SetWeaponRank/EvolveWeapon/ProcessOwnedWeapons/
    // OwnedWeaponsHash/RebaseOwnedWeapons/ResetOwnedWeapons over every
    // engine, routed by catalog system id. This is additive: the pNNN
    // opt-in routes above keep their own p0xxWeaponSlot bookkeeping and
    // their own route-enabled gates (false under configuredMode
    // "manual"/"soak_n2"), so the two paths never touch the same engine rows
    // in the same run and cannot double-process or double-credit damage.

    // ProcessOwnedWeapons(): fixed engine order, only engines with an
    // owned weapon actually run their per-tic driver this call. Credits
    // damage exactly once per engine per tic via the same accepted-total-
    // delta pattern every pNNN route above already uses.
    // N2-W3 perf probe (item 1): cvar-gated, off by default. Measures wall
    // time with MSTimeF() (engine/base.zs "native static double MSTimeF()")
    // around each engine's block below and prints one
    // DS_N2_PROFILE_TIC line per engine per logical tic. This never changes
    // control flow, only whether these Console.Printf calls happen.
    bool n2ProfileEnabled;
    double n2ProfileStamp;

    // N2-W9 manual-route save gate (docs/contracts/normal-play-
    // integration.md "Persistence"/"Evidence" item 3). Active only under
    // n2ChestCadenceEnabled (configuredMode manual/soak_n2). Every hash is
    // captured before RebaseOwnedWeapons ever runs, same convention as the
    // numbered-route save gates.
    void EmitN2ManualSaveStateIfRequested()
    {
        if (!n2ChestCadenceEnabled || n2SaveStateEmitted
            || runState != STATE_ACTIVE) return;
        CVar saveRequest = CVar.FindCVar("ds_n2_save_snapshot_request");
        if (saveRequest == null || saveRequest.GetInt() == 0) return;
        int ownedWeaponCount = 1 + n2System.Size();
        if (ownedWeaponCount < 6) return;
        int sourceSpinach = DSP031Rank(DSP028_ID_POWER);
        int sourceArmor = DSP031Rank(DSP028_ID_ARMOR);
        int sourceHollow = DSP031Rank(DSP031_ID_HOLLOW_HEART);
        int sourceTome = DSP031Rank(DSP031_ID_EMPTY_TOME);
        n2SavedSourceRankHash = DSP033StatRules.RankHash(sourceSpinach,
            sourceArmor, sourceHollow, sourceTome);
        n2SavedOwnedHash = OwnedWeaponsHash();
        n2SavedP031Hash = DSP031StateHash();
        n2SavedP032InventoryHash = DSP032InventoryHash();
        n2SavedChestHash = DSP032ChestStateHash();
        n2SavedHealingHash = DSP039HealingStateHash();
        n2SavedResolvedRankHash = dsp033ResolvedRankHash;
        n2SavedResolvedRankHashWithRecovery = dsp033ResolvedRankHashWithRecovery;
        n2SavedRankHashAmountGrowth = dsp033ResolvedRankHashAmountGrowth;
        n2SavedPlayerXMilli = int(playerX * 1000.0);
        n2SavedPlayerYMilli = int(playerY * 1000.0);
        n2SavedLogicalTic = tic;
        n2SavedPlayerLevel = playerLevel;
        n2SavedPlayerHealth = playerHealth;
        n2SavedOwnedWeaponCount = ownedWeaponCount;
        n2SaveStateEmitted = true;
        n2SaveSnapshotHeld = true;
        ClearNativeInput();
        String ownedList = "";
        for (int i = 0; i < n2System.Size(); i++)
        {
            if (i > 0) ownedList = ownedList .. ",";
            ownedList = ownedList .. String.Format("%d:%d", n2System[i], n2Rank[i]);
        }
        Console.Printf("DS_N2_SAVE_STATE accepted=1 owned_hash=%d p031_hash=%d p032_hash=%d chest_hash=%d healing_hash=%d source_rank_hash=%d resolved_rank_hash=%d resolved_rank_hash_with_recovery=%d rank_hash_amount_growth=%d logical_tic=%d level=%d xp_milli=%d health=%d player_x_milli=%d player_y_milli=%d owned_weapon_count=%d owned_list=%s run_state=%s pause_authority=UZDOOM_WORLD_TIC", n2SavedOwnedHash, n2SavedP031Hash, n2SavedP032InventoryHash, n2SavedChestHash, n2SavedHealingHash, n2SavedSourceRankHash, n2SavedResolvedRankHash, n2SavedResolvedRankHashWithRecovery, n2SavedRankHashAmountGrowth, n2SavedLogicalTic, n2SavedPlayerLevel, experienceMilliunits, n2SavedPlayerHealth, n2SavedPlayerXMilli, n2SavedPlayerYMilli, n2SavedOwnedWeaponCount, ownedList, StateName(runState));
    }

    void RestoreN2ManualSavedRun()
    {
        DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        bool statsValid = DSP031SyncLegacyStats()
            && RecomputeP033ResolvedStats("N2_SAVE_RESTORE");
        double currentX = players[0].mo != null
            ? players[0].mo.Pos.X : playerX;
        double currentY = players[0].mo != null
            ? players[0].mo.Pos.Y : playerY;
        double deltaX = currentX - playerX;
        double deltaY = currentY - playerY;
        // All hashes must be captured before RebaseOwnedWeapons below, since
        // a rebase intentionally mutates live world-plane positions folded
        // into several of these hashes -- same convention as
        // RestoreP038Map16SavedRun.
        int restoredOwnedHash = OwnedWeaponsHash();
        int restoredP031Hash = DSP031StateHash();
        int restoredP032InventoryHash = DSP032InventoryHash();
        int restoredChestHash = DSP032ChestStateHash();
        int restoredHealingHash = DSP039HealingStateHash();
        int restoredSourceRankHash = DSP033StatRules.RankHash(
            DSP031Rank(DSP028_ID_POWER), DSP031Rank(DSP028_ID_ARMOR),
            DSP031Rank(DSP031_ID_HOLLOW_HEART),
            DSP031Rank(DSP031_ID_EMPTY_TOME));
        RebaseOwnedWeapons(deltaX, deltaY);
        SyncPlayer();
        int ownedWeaponCount = 1 + n2System.Size();
        bool accepted = n2ChestCadenceEnabled && runState == STATE_ACTIVE
            && tic == n2SavedLogicalTic && n2SaveStateEmitted
            && n2SaveSnapshotHeld && statsValid
            && restoredOwnedHash == n2SavedOwnedHash
            && restoredP031Hash == n2SavedP031Hash
            && restoredP032InventoryHash == n2SavedP032InventoryHash
            && restoredChestHash == n2SavedChestHash
            && restoredHealingHash == n2SavedHealingHash
            && restoredSourceRankHash == n2SavedSourceRankHash
            && dsp033ResolvedRankHash == n2SavedResolvedRankHash
            && dsp033ResolvedRankHashWithRecovery
                == n2SavedResolvedRankHashWithRecovery
            && dsp033ResolvedRankHashAmountGrowth
                == n2SavedRankHashAmountGrowth
            && playerLevel == n2SavedPlayerLevel
            && playerHealth == n2SavedPlayerHealth
            && ownedWeaponCount == n2SavedOwnedWeaponCount;
        if (!accepted)
        {
            Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=N2_RESTORE_REJECTED tic=%d run_state=%s save_emitted=%d save_held=%d stats_valid=%d owned_hash=%d saved_owned_hash=%d p031_hash=%d saved_p031_hash=%d p032_hash=%d saved_p032_hash=%d chest_hash=%d saved_chest_hash=%d healing_hash=%d saved_healing_hash=%d source_rank_hash=%d saved_source_rank_hash=%d resolved_rank_hash=%d saved_resolved_rank_hash=%d resolved_rank_hash_with_recovery=%d saved_resolved_rank_hash_with_recovery=%d rank_hash_amount_growth=%d saved_rank_hash_amount_growth=%d level=%d saved_level=%d health=%d saved_health=%d owned_weapon_count=%d saved_owned_weapon_count=%d", tic, StateName(runState), n2SaveStateEmitted, n2SaveSnapshotHeld, statsValid, restoredOwnedHash, n2SavedOwnedHash, restoredP031Hash, n2SavedP031Hash, restoredP032InventoryHash, n2SavedP032InventoryHash, restoredChestHash, n2SavedChestHash, restoredHealingHash, n2SavedHealingHash, restoredSourceRankHash, n2SavedSourceRankHash, dsp033ResolvedRankHash, n2SavedResolvedRankHash, dsp033ResolvedRankHashWithRecovery, n2SavedResolvedRankHashWithRecovery, dsp033ResolvedRankHashAmountGrowth, n2SavedRankHashAmountGrowth, playerLevel, n2SavedPlayerLevel, playerHealth, n2SavedPlayerHealth, ownedWeaponCount, n2SavedOwnedWeaponCount);
            return;
        }
        playerHealth = playerHealth < CurrentPlayerHealthCap()
            ? playerHealth : CurrentPlayerHealthCap();
        if (playerSlot >= 0 && playerSlot < health.Size())
            health[playerSlot] = playerHealth;
        n2SaveSnapshotHeld = false;
        IsUiProcessor = runState == STATE_LEVELUP || runState == STATE_RESULTS;
        ClearNativeInput();
        SendInterfaceEvent(consoleplayer, "P031_MODE", p031RouteEnabled ? 1 : 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_UI_STATE", DSP032AppliedRewardCount(p032ChestId), DSP032InventoryHash(), DSP032ChestQueueCount());
        DSP024Rebuild();
        SyncPresentation();
        PublishUiState();
        EmitInputOwnership(IsUiProcessor ? "N2_SAVE_RESTORE_MODAL" : "N2_SAVE_RESTORE_ACTIVE");
        String ownedList = "";
        for (int i = 0; i < n2System.Size(); i++)
        {
            if (i > 0) ownedList = ownedList .. ",";
            ownedList = ownedList .. String.Format("%d:%d", n2System[i], n2Rank[i]);
        }
        Console.Printf("DS_N2_RESTORE_STATE accepted=1 owned_hash=%d saved_owned_hash=%d p031_hash=%d saved_p031_hash=%d p032_hash=%d saved_p032_hash=%d chest_hash=%d saved_chest_hash=%d healing_hash=%d saved_healing_hash=%d source_rank_hash=%d saved_source_rank_hash=%d resolved_rank_hash=%d saved_resolved_rank_hash=%d resolved_rank_hash_with_recovery=%d saved_resolved_rank_hash_with_recovery=%d rank_hash_amount_growth=%d saved_rank_hash_amount_growth=%d logical_tic=%d level=%d saved_level=%d xp_milli=%d health=%d saved_health=%d owned_weapon_count=%d saved_owned_weapon_count=%d owned_list=%s player_x_milli=%d player_y_milli=%d rebase_x_milli=%d rebase_y_milli=%d run_state=%s", restoredOwnedHash, n2SavedOwnedHash, restoredP031Hash, n2SavedP031Hash, restoredP032InventoryHash, n2SavedP032InventoryHash, restoredChestHash, n2SavedChestHash, restoredHealingHash, n2SavedHealingHash, restoredSourceRankHash, n2SavedSourceRankHash, dsp033ResolvedRankHash, n2SavedResolvedRankHash, dsp033ResolvedRankHashWithRecovery, n2SavedResolvedRankHashWithRecovery, dsp033ResolvedRankHashAmountGrowth, n2SavedRankHashAmountGrowth, tic, playerLevel, n2SavedPlayerLevel, experienceMilliunits, playerHealth, n2SavedPlayerHealth, ownedWeaponCount, n2SavedOwnedWeaponCount, ownedList, int(playerX * 1000.0), int(playerY * 1000.0), int(deltaX * 1000.0), int(deltaY * 1000.0), StateName(runState));
    }

    void ProcessPickups()
    {
        if (runState != STATE_ACTIVE) return;
        DSP024Rebuild(); DSP024RadiusCandidates(playerX, playerY, AttractRadius());
        for (int i = 0; i < spatialCandidateCount && runState == STATE_ACTIVE; i++)
        {
            int slot = spatialCandidateSlots[i]; int generation = spatialCandidateGenerations[i]; int stable = spatialCandidateIds[i];
            if (!DSP027ValidPickup(slot, generation, stable)) continue;
            double dx = playerX - x[slot]; double dy = playerY - y[slot];
            double distance = sqrt(dx * dx + dy * dy);
            if (distance <= AttractRadius() && experienceStates[slot] == DSP027_GROUND)
            {
                experienceStates[slot] = DSP027_ATTRACTING;
                { if (!dsQuiet) Console.Printf("DS_P030_PICKUP_ATTRACT tic=%d slot=%d generation=%d stable_id=%d radius=96", tic, slot, generation, stable); }
            }
            if (experienceStates[slot] == DSP027_ATTRACTING && distance > COLLECT_RADIUS)
            {
                double amount = PICKUP_SPEED < distance ? PICKUP_SPEED : distance;
                x[slot] += dx / distance * amount; y[slot] += dy / distance * amount;
                dx = playerX - x[slot]; dy = playerY - y[slot]; distance = sqrt(dx * dx + dy * dy);
            }
            int p040GrowthMilli = p040RouteEnabled
                ? DSP033Resolved(DSP033StatRules.STAT_GROWTH)
                : (rsActive ? max(0, rsGrowthMilli - 1000) : 0);
            int p040BaseMilli; int p040BonusMilli;
            if (distance <= COLLECT_RADIUS && DSP027CollectPickupWithGrowth(
                slot, generation, stable, p040GrowthMilli, p040BaseMilli, p040BonusMilli))
            {
                // p040GrowthMilli is 0 on every pre-P040 route, so
                // p040BonusMilli is always 0 there and value is exactly the
                // pre-P040 `experienceValues[slot]` read -- byte-identical.
                int value = p040BaseMilli + p040BonusMilli;
                xpCollectedLedger += value;
                if (p040BonusMilli > 0)
                    { if (!dsQuiet) Console.Printf("DS_P040_MAP16_GROWTH_COLLECT tic=%d slot=%d base_milli=%d growth_milli=%d bonus_milli=%d credited_milli=%d", tic, slot, p040BaseMilli, p040GrowthMilli, p040BonusMilli, value); }
                { if (!dsQuiet) Console.Printf("DS_P030_XP_COLLECT tic=%d slot=%d generation=%d stable_id=%d value=%d total=%d radius=24 source_plane=1", tic, slot, generation, stable, value, xpCollectedLedger); }
                if (!p032RouteEnabled || p033RouteEnabled)
                {
                    Sfx(DSSfx.GEM, 2);
                    CollectRunExperience(value);
                    if (ActiveDraftQueueCount() > 0) OpenLevelUp();
                }
                else Console.Printf("DS_P032_MAP16_XP_FIXTURE tic=%d collected=%d natural_levelup_enabled=0", tic, value);
            }
        }
        CollectP039Hearts();
    }

    void OpenLevelUp()
    {
        // A queued level chains into this same call from ApplyChoice while
        // runState is STILL STATE_LEVELUP (the run only leaves that state
        // once the WHOLE queue is drained -- see ApplyChoice's own
        // else-branch). The real guard against opening a second modal on
        // top of an already-visible one is modalPlayOpen, not runState:
        // checking runState here silently swallowed every level after the
        // first whenever >=2 levels were queued at once, a real bug this
        // integration's large-vacuum fixture (P040-A03) uncovered by
        // actually reaching that path -- no prior MAP16 route had queued
        // more than one level from a single collection.
        if (modalPlayOpen || ActiveDraftQueueCount() <= 0) return;
        Transition(STATE_LEVELUP, "XP_THRESHOLD_QUEUE");
        Sfx(DSSfx.LEVELUP);
        modalPlayOpen = true; playSelectedOffer = 0;
        IsUiProcessor = true; ClearNativeInput();
        EmitInputOwnership("MODAL");
        PublishUiState();
        if (p031RouteEnabled) SendInterfaceEvent(consoleplayer, "P031_MAP16_OFFER_COUNT", ActiveDraftOfferCount(), 0, 0);
        PublishLevelUpCharges();
        SendInterfaceEvent(consoleplayer, "P030_OPEN", ActiveDraftTargetLevel(), ActiveDraftQueueCount(), ActiveDraftAppliedCount());
        Console.Printf("DS_P030_LEVELUP_OPEN tic=%d level=%d target_level=%d queue_count=%d offer0=%s offer1=%s offer2=%s pause=1 input_owner=MODAL", tic, playerLevel, ActiveDraftTargetLevel(), ActiveDraftQueueCount(), ActiveDraftOfferName(ActiveDraftOfferId(0)), ActiveDraftOfferName(ActiveDraftOfferId(1)), ActiveDraftOfferName(ActiveDraftOfferId(2)));
        if (p031RouteEnabled)
            Console.Printf("DS_P031_MAP16_DRAFT_OPEN tic=%d target_level=%d token=%d queue=%d offer_count=%d offer0_id=%d offer1_id=%d offer2_id=%d gameplay_paused=1", tic, ActiveDraftTargetLevel(), dsp031AppliedDrafts, DSP031QueuedCount(), dsp031OfferCount, DSP031OfferId(0), DSP031OfferId(1), DSP031OfferId(2));
    }

    void ApplyChoice(int index, String source)
    {
        if (runState != STATE_LEVELUP || !modalPlayOpen) return;
        if (arPickOpen) { ApplyArcanaChoice(index); return; }
        int id;
        bool accepted;
        if (p031RouteEnabled)
        {
            id = DSP031OfferId(index);
            int token = dsp031AppliedDrafts;
            accepted = index >= 0 && index < dsp031OfferCount && DSP031ApplyOffer(token, id);
            if (accepted)
            {
                if (p033RouteEnabled)
                {
                    if (id == DSP031_ID_HOLLOW_HEART
                        && !DSP032SetItem(DSP032_ID_HOLLOW_HEART, DSP031Rank(id)))
                        Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P033_HOLLOW_HEART_GRAPH_SYNC item_rank=%d", DSP031Rank(id));
                    RecomputeP033ResolvedStats("DRAFT_APPLY");
                }
                p031ChoiceTic = tic;
                p031WhipEventsAtChoice = attackEventId;
                Console.Printf("DS_P031_MAP16_DRAFT_APPLY accepted=1 source=%s index=%d token=%d item_id=%d rank=%d combat_tic=%d whip_events=%d queue_remaining=%d authority=DSP031InventoryDraftAuthority", source, index, token, id, DSP031Rank(id), tic, attackEventId, DSP031QueuedCount());
            }
        }
        else accepted = DSP028ApplyOffer(index, id);
        if (!accepted)
        {
            Console.Printf("DS_P030_LEVELUP_CHOICE source=%s accepted=0 reason=ILLEGAL index=%d", source, index);
            return;
        }
        levelUpChoices++;
        int appliedRank = p031RouteEnabled ? DSP031Rank(id) : ActiveDraftOfferRank(id);
        int pickCategory = DSN2Catalog.Category(id);
        Sfx(appliedRank > 1 || pickCategory <= 0 ? DSSfx.E_RANK_UP
            : (pickCategory == DSN2Catalog.CATEGORY_WEAPON ? DSSfx.E_PICK_WEAPON : DSSfx.E_PICK_PASSIVE));
        Console.Printf("DS_P030_LEVELUP_CHOICE source=%s accepted=1 index=%d offer_id=%s rank=%d level=%d queue_remaining=%d whip_rank=%d might_milli=%d armor=%d", source, index, ActiveDraftOfferName(id), appliedRank, playerLevel, ActiveDraftQueueCount(), whipRank, characterMightMilli, characterArmor);
        CloseOrChainLevelUp(id);
    }

    void CloseOrChainLevelUp(int id)
    {
        modalPlayOpen = false;
        SendInterfaceEvent(consoleplayer, "P030_APPLIED", id, ActiveDraftQueueCount(), ActiveDraftAppliedCount());
        if (ActiveDraftQueueCount() > 0) OpenLevelUp();
        else { Transition(STATE_ACTIVE, "LEVELUP_COMMITTED"); IsUiProcessor = false; ClearNativeInput(); EmitInputOwnership("ACTIVE_RESUME"); Console.Printf("DS_P030_LEVELUP_RESUME tic=%d level=%d clocks_frozen_during_modal=1", tic, playerLevel); }
        if (!p038RouteEnabled) EmitP033Map16SaveStateIfReady();
    }

    // Reroll, Banish (the offer at index) and Skip from the level-up screen,
    // spending the run's charges through the P031 draft authority.
    bool LevelUpAction(int kind, int index)
    {
        if (runState != STATE_LEVELUP || !modalPlayOpen || !p031RouteEnabled) return false;
        if (arPickOpen) return ArcanaAction(kind);
        int token = dsp031AppliedDrafts;
        int actionId = dsp031LastActionId + 1;
        bool accepted;
        if (kind == LEVELUP_ACTION_REROLL) accepted = DSP031Reroll(token, actionId);
        else if (kind == LEVELUP_ACTION_BANISH)
            accepted = index >= 0 && index < dsp031OfferCount && DSP031Banish(token, DSP031OfferId(index), actionId);
        else accepted = DSP031Skip(token, actionId);
        if (accepted) Sfx(kind == LEVELUP_ACTION_REROLL ? DSSfx.I_REROLLO : DSSfx.U_BACK);
        Console.Printf("DS_P030_LEVELUP_ACTION kind=%d index=%d accepted=%d rerolls=%d skips=%d banishes=%d", kind, index, accepted, dsp031RerollsRemaining, dsp031SkipsRemaining, dsp031BanishesRemaining);
        PublishLevelUpCharges();
        if (!accepted) return false;
        if (kind == LEVELUP_ACTION_SKIP) { levelUpChoices++; CloseOrChainLevelUp(0); return true; }
        PublishUiState();
        SendInterfaceEvent(consoleplayer, "P031_MAP16_OFFER_COUNT", ActiveDraftOfferCount(), 0, 0);
        SendInterfaceEvent(consoleplayer, "P030_REFRESH", kind, 0, 0);
        return true;
    }

    void PublishLevelUpCharges()
    {
        if (p031RouteEnabled)
            SendInterfaceEvent(consoleplayer, "P030_CHARGES", dsp031RerollsRemaining, dsp031SkipsRemaining, dsp031BanishesRemaining);
    }

    void TearDownRun()
    {
        DestroyAllProxies();
        DestroyP037OrbitProxies();
        DSP034ResetAimedRuntime();
        DSP035ResetBallisticRuntime(3500351);
        DSP036ResetReturningRuntime(3600361);
        DSP037ResetOrbitRuntime();
        DSP038ResetGroundRuntime();
        DSP039ResetAura();
        DSP039ResetHealing();
        DSP040ResetGlobal();
        DSP041ResetBounceRuntime(4104101 + runGeneration);
        for (int slot = 0; slot < lifeStates.Size(); slot++)
        {
            if (lifeStates[slot] != STORE_ALIVE) continue;
            if (DSP027IsLivePickup(slot)) DSP027RemovePickup(slot, generations[slot], ids[slot]);
            else DestroyParts(slot, generations[slot], ids[slot]);
        }
        DSP024ClearSpatial(); pendingRear = 0; sweepUntil = 0;
        IsUiProcessor = false; ClearNativeInput(); EmitInputOwnership("TEARDOWN");
        Console.Printf("DS_P030_TEARDOWN run_id=%d generation=%d entities=%d enemies=%d pickups=%d pending_attacks=0 statuses=0 menu_focus=0 input_latch=0 timers=0 rng_streams_cleared=1", runId, runGeneration, LiveStoreCount(), LiveEnemyCount(), LivePickupCount());
    }

    void EndRun(String reason)
    {
        if (runState == STATE_ENDING || runState == STATE_RESULTS) return;
        Sfx(reason == "PLAYER_ZERO_HEALTH" ? DSSfx.DEFEAT : DSSfx.VICTORY);
        if (reason == "PLAYER_ZERO_HEALTH")
        {
            let fallen = DSP021FirstPersonPlayer(players[0].mo);
            if (fallen != null) fallen.StartDying();
        }
        MetaCommitRun(reason);
        Transition(STATE_ENDING, reason);
        Console.Printf("DS_P030_RUN_END run_id=%d generation=%d tic=%d source_seconds=%d reason=%s health=%d kills=%d", runId, runGeneration, tic, tic / 35, reason, playerHealth, kills);
        TearDownRun();
        // Mad Forest runs earn the gold picked up; other routes keep kills.
        earnedCurrency = mfEnabled ? mfGold : kills;
        bool committed = CommitReward(earnedCurrency);
        bool replayed = CommitReward(earnedCurrency);
        Transition(STATE_RESULTS, "LEDGERS_FROZEN");
        modalPlayOpen = false;
        SendInterfaceEvent(consoleplayer, "P030_RESULTS", runId, tic, kills);
        SendInterfaceEvent(consoleplayer, "P030_RESULTS_STATS", damageDealt, xpCollectedLedger, earnedCurrency);
        SendInterfaceEvent(consoleplayer, "P030_RESULTS_LEVEL", playerLevel, whipRank, characterArmor);
        IsUiProcessor = true; EmitInputOwnership("RESULTS");
        Console.Printf("DS_P030_RESULTS run_id=%d generation=%d elapsed_tics=%d elapsed_seconds=%d kills=%d damage=%d collected_xp=%d earned_currency=%d level=%d whip_rank=%d passive_ranks=%d entities=0 commit=%s replay=%s durable_profile=1 erased=%d", runId, runGeneration, tic, tic / 35, kills, damageDealt, xpCollectedLedger, earnedCurrency, playerLevel, whipRank, powerRank + armorRank, committed ? "COMMITTED" : "REJECTED", replayed ? "ALREADY_COMMITTED" : "REJECTED", p040ErasedCredited);
        N2LogDispatchSummary();
        if (!completionEmitted)
        {
            completionEmitted = true;
            Console.Printf("DS_P030_COMPLETE tics=%d source_seconds=%d state=RESULTS kills=%d damage=%d collected_xp=%d earned_currency=%d level=%d spawn_attempts=%d spawn_admissions=%d contact_hits=%d levelup_choices=%d peak_whip_proxies=%d whip_proxy_limit=2 retry_ready=1 clean_reset=1 native_damage=DISABLED native_fire=DISABLED logical_accelerated=%d erased=%d", tic, tic / 35, kills, damageDealt, xpCollectedLedger, earnedCurrency, playerLevel, spawnAttempts, spawnAdmissions, contactHits, levelUpChoices, peakWhipProxies, logicalStepsPerWorldTick > 1, p040ErasedCredited);
        }
    }

    int CurrentPlayerHealthCap()
    {
        if (rsActive && rsMaxHealthMilli > 0) return rsMaxHealthMilli;
        return p033RouteEnabled && dsp033ResolvedValid
            ? DSP033Resolved(DSP033StatRules.STAT_MAX_HEALTH) : PLAYER_HEALTH;
    }

    int CurrentWeaponMight(int systemId)
    {
        if (rsActive) return RsMightFor(systemId);
        return p033RouteEnabled && dsp033ResolvedValid
            ? (DSP033StatRules.StatApplies(DSP033StatRules.STAT_MIGHT, systemId)
                ? DSP033Resolved(DSP033StatRules.STAT_MIGHT) : 1000)
            : characterMightMilli;
    }

    int CurrentWeaponCooldownQuarter(int systemId)
    {
        if (rsActive) return max(1, 189 * rsCooldownMilli / 1000);
        if (!p033RouteEnabled || !dsp033ResolvedValid) return 189;
        int adjustedMilli = DSP033StatRules.CooldownAfterTome(systemId,
            189000, DSP033Resolved(DSP033StatRules.STAT_COOLDOWN));
        int adjustedQuarter = adjustedMilli / 1000;
        return adjustedQuarter < 1 ? 1 : adjustedQuarter;
    }

    void ResetRunState()
    {
        TearDownRun();
        // The pawn fell when the last run was lost; a retry keeps the map.
        let pawn = DSP021FirstPersonPlayer(players[0].mo);
        if (pawn != null) pawn.StopDying();
        ResetOwnedWeapons();
        Reset(); DSP024ClearSpatial(); DSP027ResetExperience(); DSP028ResetProgression();
        if (p032RouteEnabled || n2ChestCadenceEnabled) DSP032ResetChests();
        // Manual/soak_n2 route: the graph inventory starts empty and is
        // repopulated live from the draft/dispatcher state by
        // N2SyncTransformationInventory before each interim-chest open (see
        // that function's comment); the opt-in P032 route below still seeds
        // its own dedicated Whip+Hollow Heart fixture inventory.
        if (n2ChestCadenceEnabled && !p032RouteEnabled) DSP032ResetInventory();
        rsRevivalsUsed = 0;
        LbReset();
        ArcanaReset();
        CVar limitBreak = CVar.FindCVar("ds_limit_break");
        // Limit Break is off for manual play unless switched on (L on the stage
        // screen); automated runs keep it on so the harnesses still reach it.
        lbEnabled = configuredMode != "manual" || (limitBreak != null && limitBreak.GetInt() != 0);
        GwReset();
        if (rsActive) { DSPowerUps.Load(rsPowerUpRanks); DSEggs.Load(rsEggs); RecomputeRunStats(); }
        if (p031RouteEnabled)
        {
            CVar seed = CVar.FindCVar("ds_p031_seed");
            CVar rerolls = CVar.FindCVar("ds_p031_rerolls");
            CVar skips = CVar.FindCVar("ds_p031_skips");
            CVar banishes = CVar.FindCVar("ds_p031_banishes");
            CVar luck = CVar.FindCVar("ds_p031_luck_milli");
            int rerollCharges = rerolls != null ? rerolls.GetInt() : 0;
            int skipCharges = skips != null ? skips.GetInt() : 0;
            int banishCharges = banishes != null ? banishes.GetInt() : 0;
            if (rsActive)
            {
                rerollCharges += DSPowerUps.Charges(rsPowerUpRanks, DSPowerUps.REROLL);
                skipCharges += DSPowerUps.Charges(rsPowerUpRanks, DSPowerUps.SKIP);
                banishCharges += DSPowerUps.Charges(rsPowerUpRanks, DSPowerUps.BANISH) + DSCharacters.StartBanish(rsCharacter) + DSEggs.Charges(rsEggs, 18);
                rerollCharges += DSEggs.Charges(rsEggs, 5);
                skipCharges += DSEggs.Charges(rsEggs, 17);
            }
            // Manual play draws a fresh seed per run so drafts vary; automated
            // routes keep the fixed cvar seed for repeatability.
            int draftSeed = seed != null ? seed.GetInt() : 730201;
            if (configuredMode == "manual") draftSeed = Random[DSRunSeed](1, 0x3FFFFFFF);
            DSP031StartRun(draftSeed,
                rerollCharges, skipCharges, banishCharges, luck != null ? luck.GetInt() : 0);
        }
        if (p032RouteEnabled)
        {
            DSP032SeedWhipEvolutionFixture();
            whipRank = 8; inventoryWeaponLevel = 8;
        }
        SetupP033Map16ControlledRanks();
        tic = 0; phase = 0; spawnIndex = 1; nextSpawnTic = 70; spawnRng = 101;
        if (configuredMode == "manual") spawnRng = Random[DSRunSeed](1, 0x3FFFFFFF);
        MFResetState();
        GmReset();
        spawnAttempts = 0; spawnAdmissions = 0; spawnRejections = 0;
        attackRng = 270126; attackEventId = 0;
        nextWhipQuarter = p033RouteEnabled
            ? CurrentWeaponCooldownQuarter(DSP033StatRules.SYSTEM_WHIP) : 189;
        pendingRear = 0; pendingRearQuarter = 0;
        whipLingerEvent.Clear(); whipLingerLobe.Clear(); whipLingerYaw.Clear(); whipLingerUntil.Clear(); whipLingerDamage.Clear();
        p032AttackRng = 320327; p032EventId = 0;
        diagnosticWeaponSlot = -1; diagnosticEventId = 0; diagnosticNextQuarter = 189; diagnosticAttackRng = 270031;
        p031ChoiceTic = 0; p031WhipEventsAtChoice = 0;
        p032ChestPickupRequested = false; p032ChestModalOpen = false;
        p032ChestId = 0; p032ChestX = 0; p032ChestY = 0;
        p033ContactFixtureAttempted = false; p033ContactFixtureId = 0;
        p034TransformAttempted = false;
        p035AxeTransformAttempted = false;
        p035FireTransformAttempted = false;
        p036TransformAttempted = false;
        p037TransformAttempted = false;
        p037SaveStateEmitted = false;
        p037SaveSnapshotHeld = false;
        p037RestoreAttackPending = false;
        p037LastPlayOrbitHash = 0;
        p038TransformAttempted = false;
        p038SaveStateEmitted = false;
        p038SaveSnapshotHeld = false;
        p038RestorePendingHit = false;
        p038LastPlayGroundHash = 0;
        p039TransformAttempted = false;
        p039RestorePendingHit = false;
        p039LastPlayAuraHash = 0;
        p039PummarolaRank = 0;
        p039ContactFixtureAttemptedPre = false;
        p039ContactFixtureAttemptedPost = false;
        p039ContactFixtureId = 0;
        p039ContactFixtureDamageMilli = 0;
        p039ContactFixtureTargetMilli = 0;
        p040LoopTransformAttempted = false;
        p040MoonTransformAttempted = false;
        p040MoonTargetFixtureSpawned = false;
        p040PickupRepositionAttempted = false;
        p040PentagramPickupFixtureSpawned = false;
        p040BigGemFixtureSpawned = false;
        p041NoFutureTransformAttempted = false;
        p041ContactFixtureAttempted = false;
        p041ContactFixtureId = 0;
        p041NoFutureExplosionsCredited = 0;
        p038SavedAuraHash = 0;
        p038SavedHealingHash = 0;
        p038SavedGlobalHash = 0;
        p038SavedRankHashAmountGrowth = 0;
        p038SavedBounceHash = 0;
        p038SavedGroundHash = 0;
        p038SavedP031Hash = 0; p038SavedP032Hash = 0;
        p038SavedChestHash = 0; p038SavedOrbitHash = 0;
        p038SavedAimedHash = 0; p038SavedBallisticHash = 0;
        n2SaveStateEmitted = false; n2SaveSnapshotHeld = false;
        n2SavedOwnedHash = 0; n2SavedP031Hash = 0;
        n2SavedP032InventoryHash = 0; n2SavedChestHash = 0;
        n2SavedHealingHash = 0; n2SavedSourceRankHash = 0;
        n2SavedResolvedRankHash = 0; n2SavedResolvedRankHashWithRecovery = 0;
        n2SavedRankHashAmountGrowth = 0; n2SavedPlayerXMilli = 0;
        n2SavedPlayerYMilli = 0; n2SavedLogicalTic = 0;
        n2SavedPlayerLevel = 0; n2SavedPlayerHealth = 0;
        n2SavedOwnedWeaponCount = 0;
        p038SavedReturningHash = 0;
        p038SavedSourceRankHash = 0; p038SavedResolvedRankHash = 0;
        p038SavedPlayerXMilli = 0; p038SavedPlayerYMilli = 0;
        p038SavedLogicalTic = 0; p038SavedWeaponFormGeneration = 0;
        p035FrontFixtureId = 0; p035AxeFixtureId = 0;
        p033SaveStateEmitted = false; p033SaveSnapshotHeld = false;
        p033RestorePendingAttack = false;
        p032PickupTapeTicks = 0; p032PickupTapeStartX = 0.0; p032PickupTapeStartY = 0.0;
        playerHealth = PLAYER_HEALTH;
        if (p033RouteEnabled)
        {
            RecomputeP033ResolvedStats("RUN_START");
            playerHealth = CurrentPlayerHealthCap();
        }
        if (rsActive)
        {
            RecomputeRunStats();
            playerHealth = CurrentPlayerHealthCap();
            Console.Printf("DS_RUN_CHARACTER character=%s max_health_milli=%d might=%d cooldown=%d area=%d speed=%d duration=%d amount=%d move=%d magnet=%d luck=%d growth=%d greed=%d curse=%d armor=%d recovery=%d revival=%d powerups=%s", DSCharacters.Name(rsCharacter), rsMaxHealthMilli, rsMightMilli, rsCooldownMilli, rsAreaMilli, rsSpeedMilli, rsDurationMilli, rsAmount, rsMoveMilli, rsMagnetMilli, rsLuckMilli, rsGrowthMilli, rsGreedMilli, rsCurseMilli, rsArmor, rsRecoveryMilli, rsRevivalsGranted, DSPowerUps.Serialize(rsPowerUpRanks));
        }
        playerInvulnerableUntil = 0; kills = 0; damageDealt = 0; contactHits = 0; contactRejects = 0;
        // dsp040ErasedEnemies itself is a DSP040Global mixin field wiped by
        // TearDownRun's own DSP040ResetGlobal() (mirroring every other
        // family's per-run reset) before DS_P030_RESULTS/DS_P030_COMPLETE
        // print, exactly like damageDealt is protected from that same
        // teardown by being a plain VerticalSlice field credited
        // incrementally rather than read live from mixin state.
        p040ErasedCredited = 0;
        xpCreatedLedger = 0; xpCollectedLedger = 0; earnedCurrency = 0; levelUpChoices = 0;
        playerX = 0.0; playerY = 0.0; sweepUntil = 0; sweepLobe = 0; sweepEvent = 0;
        peakWhipProxies = 0;
        inputTraceInitialized = false; inputTraceX = 0.0; inputTraceY = 0.0; inputTraceYaw = 0.0; inputTracePitch = 0.0;
        historyEvent.Clear(); historyTargetSlot.Clear(); historyTargetGeneration.Clear(); historyTargetId.Clear();
        modalPlayOpen = false; playSelectedOffer = 0;
        runGeneration++; if (runGeneration <= 0) runGeneration = 1;
        runId = profileNextRunId; if (runId <= 0) runId = 1;
        playerSlot = Allocate(KIND_PLAYER, 0.0, 0.0, 0.0, 0.0, playerHealth);
        weaponSlot = Allocate(KIND_WEAPON, 0.0, 0.0, 0.0, 0.0, 1);
        if (p031RouteEnabled || p032RouteEnabled)
        {
            if (p031RouteEnabled)
            {
                diagnosticWeaponSlot = Allocate(KIND_WEAPON, 0.0, 0.0, 0.0, 0.0, 1);
                collisionRadii[diagnosticWeaponSlot] = 0.0;
                Console.Printf("DS_P031_MAP16_ARMS primary=WHIP weapon_id=%d automatic=1 secondary=TEST_AUTO_PULSE weapon_id=%d automatic=1 classification=CONTROLLED_DIAGNOSTIC source_content=NONE", ids[weaponSlot], ids[diagnosticWeaponSlot]);
            }
            if (p032RouteEnabled)
            {
                DSP032SetItem(DSP032_ID_WHIP, 8);
                Console.Printf("DS_P032_MAP16_FIXTURE route=OPT_IN_P032 inventory_hash=%d whip_rank=%d hollow_heart_rank=%d controlled_start=1 natural_levelup_claim=0", DSP032InventoryHash(), DSP032Rank(DSP032_ID_WHIP), DSP032Rank(DSP032_ID_HOLLOW_HEART));
            }
        }
        collisionRadii[playerSlot] = 2.0; collisionRadii[weaponSlot] = 0.0;
        playerX = players[0].mo != null ? players[0].mo.Pos.X : 0.0;
        playerY = players[0].mo != null ? players[0].mo.Pos.Y : 0.0;
        x[playerSlot] = playerX; y[playerSlot] = playerY;
        p034MagicWeaponSlot = -1; p034KnifeWeaponSlot = -1;
        p035AxeWeaponSlot = -1; p035FireWeaponSlot = -1;
        p036WeaponSlot = -1;
        p037WeaponSlot = -1;
        p038WeaponSlot = -1;
        p039WeaponSlot = -1;
        p040StrikeWeaponSlot = -1;
        p040EraseWeaponSlot = -1;
        p041RunetracerWeaponSlot = -1;
        p041BoneWeaponSlot = -1;
        p041CherryWeaponSlot = -1;
        p041CarrelloWeaponSlot = -1;
        p041RunetracerWeaponIndex = -1;
        p041BoneWeaponIndex = -1;
        p041CherryWeaponIndex = -1;
        p041CarrelloWeaponIndex = -1;
        if (p034RouteEnabled)
        {
            p034MagicWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            p034KnifeWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            collisionRadii[p034MagicWeaponSlot] = 0.0;
            collisionRadii[p034KnifeWeaponSlot] = 0.0;
            bool magicEquipped = DSP034EquipAimedFixture(
                DSP034WeaponRows.SYSTEM_MAGIC_WAND, 1,
                p034MagicWeaponSlot, 70);
            bool knifeEquipped = DSP034EquipAimedFixture(
                DSP034WeaponRows.SYSTEM_KNIFE, 1,
                p034KnifeWeaponSlot, 70);
            Console.Printf("DS_P034_MAP16_FIXTURE accepted=%d route=OPT_IN_P034 magic_wand_rank=1 magic_weapon_id=%d knife_rank=1 knife_weapon_id=%d first_fire_tic=70 inventory_claim=0 classification=CONTROLLED_MAP16_FIXTURE", magicEquipped && knifeEquipped ? 1 : 0, ids[p034MagicWeaponSlot], ids[p034KnifeWeaponSlot]);
            if (!magicEquipped || !knifeEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P034_MAP16_CONTROLLED_EQUIP");
            SpawnP034Map16ControlledTarget();
        }
        if (p035RouteEnabled) SpawnP035Map16ControlledTargets();
        if (p035RouteEnabled)
        {
            p035AxeWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            p035FireWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            collisionRadii[p035AxeWeaponSlot] = 0.0;
            collisionRadii[p035FireWeaponSlot] = 0.0;
            bool axeEquipped = DSP035EquipFixture(
                DSP035WeaponRows.SYSTEM_AXE, 8, p035AxeWeaponSlot, 70);
            bool fireEquipped = DSP035EquipFixture(
                DSP035WeaponRows.SYSTEM_FIRE_WAND, 8,
                p035FireWeaponSlot, 70);
            Console.Printf("DS_P035_MAP16_FIXTURE accepted=%d axe_rank=8 axe_weapon_id=%d fire_wand_rank=8 fire_wand_weapon_id=%d first_fire_tic=70 equipment=CONTROLLED_MAP16_FIXTURE candelabrador=CONTROLLED_INGREDIENT_FIXTURE source_inventory_claim=0", axeEquipped && fireEquipped ? 1 : 0, ids[p035AxeWeaponSlot], ids[p035FireWeaponSlot]);
            if (!axeEquipped || !fireEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P035_MAP16_CONTROLLED_EQUIP");
        }
        if (p036RouteEnabled)
        {
            p036WeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p036WeaponSlot >= 0)
                collisionRadii[p036WeaponSlot] = 0.0;
            bool crossEquipped = p036WeaponSlot >= 0
                && DSP036EquipFixture(DSP036ReturningRows.SYSTEM_CROSS, 8,
                    p036WeaponSlot, 70);
            Console.Printf("DS_P036_MAP16_FIXTURE accepted=%d route=OPT_IN_P036 cross_rank=8 weapon_id=%d weapon_generation=%d first_fire_tic=70 clover=CONTROLLED_INGREDIENT_FIXTURE equipment=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0 concurrent=WHIP_BLOODY_TEAR_WANDS_AXE_FIRE", crossEquipped ? 1 : 0, p036WeaponSlot >= 0 ? ids[p036WeaponSlot] : 0, p036WeaponSlot >= 0 ? generations[p036WeaponSlot] : 0);
            if (!crossEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P036_MAP16_CONTROLLED_EQUIP");
        }
        if (p037RouteEnabled)
        {
            p037WeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p037WeaponSlot >= 0)
                collisionRadii[p037WeaponSlot] = 0.0;
            bool bibleEquipped = p037WeaponSlot >= 0
                && DSP037EquipFixture(DSP037OrbitRows.SYSTEM_KING_BIBLE,
                    1, p037WeaponSlot, 70, playerSlot,
                    generations[playerSlot], ids[playerSlot], 1000, 1000);
            Console.Printf("DS_P037_MAP16_FIXTURE accepted=%d route=OPT_IN_P037 king_bible_rank=1 weapon_slot=%d weapon_id=%d weapon_generation=%d first_fire_tic=70 duration_ingredient=CONTROLLED_SPELLBINDER_FIXTURE source_inventory_claim=0 equipment=CONTROLLED_MAP16_FIXTURE concurrent=WHIP_BLOODY_TEAR_AIMED_BALLISTIC_RETURNING", bibleEquipped ? 1 : 0, p037WeaponSlot, p037WeaponSlot >= 0 ? ids[p037WeaponSlot] : 0, p037WeaponSlot >= 0 ? generations[p037WeaponSlot] : 0);
            if (!bibleEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P037_MAP16_CONTROLLED_EQUIP");
            SpawnP037Map16ControlledTarget();
        }
        if (p038RouteEnabled)
        {
            p038WeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p038WeaponSlot >= 0)
                collisionRadii[p038WeaponSlot] = 0.0;
            bool waterEquipped = p038WeaponSlot >= 0
                && DSP038EquipWeapon(DSP038GroundRows.SYSTEM_HOLYWATER,
                    8, p038WeaponSlot, generations[p038WeaponSlot],
                    ids[p038WeaponSlot], 1, playerSlot,
                    generations[playerSlot], ids[playerSlot], 70,
                    1000, 1000, 1000, 1000,
                    DSP033Resolved(DSP033StatRules.STAT_MIGHT),
                    DSP033Resolved(DSP033StatRules.STAT_COOLDOWN));
            Console.Printf("DS_P038_MAP16_FIXTURE accepted=%d route=OPT_IN_P038 holywater_rank=8 weapon_slot=%d weapon_id=%d weapon_generation=%d first_fire_tic=70 attractorb_rank=1 attractorb=CONTROLLED_INGREDIENT_FIXTURE target_id=%d equipment=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", waterEquipped ? 1 : 0, p038WeaponSlot, p038WeaponSlot >= 0 ? ids[p038WeaponSlot] : 0, p038WeaponSlot >= 0 ? generations[p038WeaponSlot] : 0, p037TargetFixtureId);
            if (!waterEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P038_MAP16_CONTROLLED_EQUIP");
        }
        if (p039RouteEnabled)
        {
            p039WeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p039WeaponSlot >= 0)
                collisionRadii[p039WeaponSlot] = 0.0;
            bool garlicEquipped = p039WeaponSlot >= 0
                && DSP039EquipAura(DSP039AuraRows.SYSTEM_GARLIC, 8,
                    p039WeaponSlot, generations[p039WeaponSlot],
                    ids[p039WeaponSlot], 1, playerSlot,
                    generations[playerSlot], ids[playerSlot],
                    DSP033Resolved(DSP033StatRules.STAT_MIGHT),
                    DSP033Resolved(DSP033StatRules.STAT_COOLDOWN));
            // Controlled Pummarola-owned fixture (rank 5, matching P038's
            // Attractorb/P037's Spellbinder pattern): grants Recovery > 0
            // so the healing-authority evidence (Recovery ticks, growth
            // feed, scaled Little Heart heal) is exercised by default
            // whenever the P039 route is selected.
            p039PummarolaRank = 5;
            DSP033RecomputeRecovery(p039PummarolaRank);
            Console.Printf("DS_P039_MAP16_FIXTURE accepted=%d route=OPT_IN_P039 garlic_rank=8 weapon_slot=%d weapon_id=%d weapon_generation=%d pummarola_rank=%d recovery_milli=%d equipment=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", garlicEquipped ? 1 : 0, p039WeaponSlot, p039WeaponSlot >= 0 ? ids[p039WeaponSlot] : 0, p039WeaponSlot >= 0 ? generations[p039WeaponSlot] : 0, p039PummarolaRank, DSP033Resolved(DSP033StatRules.STAT_RECOVERY));
            if (!garlicEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P039_MAP16_CONTROLLED_EQUIP");
        }
        if (p040RouteEnabled)
        {
            p040StrikeWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p040StrikeWeaponSlot >= 0)
                collisionRadii[p040StrikeWeaponSlot] = 0.0;
            bool lightningEquipped = p040StrikeWeaponSlot >= 0
                && DSP040EquipStrike(DSP040GlobalRows.SYSTEM_LIGHTNING, 8,
                    p040StrikeWeaponSlot, generations[p040StrikeWeaponSlot],
                    ids[p040StrikeWeaponSlot], 1, playerSlot,
                    generations[playerSlot], ids[playerSlot],
                    DSP033Resolved(DSP033StatRules.STAT_MIGHT),
                    DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), tic);
            p040EraseWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p040EraseWeaponSlot >= 0)
                collisionRadii[p040EraseWeaponSlot] = 0.0;
            // Pentagram's first activation is a labelled controlled-fixture
            // offset (+50 tics, ~1.4s), not its real-source Cooldown: an
            // immediate tic=0 region-wide erase would strip the automated
            // MAP16 mover's nearby enemies before ordinary whip kills/XP
            // collection/Growth-at-collection evidence has a chance to
            // establish itself (a real interaction this integration
            // uncovered by actually running the automated soak, not a
            // hypothetical), while still firing early enough that the
            // spawner's opening waves supply live in-region targets for a
            // real erasure and pickups for a real spare roll BEFORE the
            // tic=170 Moon transform. Lightning Ring's own strikes stay
            // immediate since they only damage a few enemies per
            // activation and do not starve the mover of nearby targets.
            bool pentagramEquipped = p040EraseWeaponSlot >= 0
                && DSP040EquipPentagram(DSP040GlobalRows.SYSTEM_PENTAGRAM, 8,
                    p040EraseWeaponSlot, generations[p040EraseWeaponSlot],
                    ids[p040EraseWeaponSlot], 1, playerSlot,
                    generations[playerSlot], ids[playerSlot],
                    DSP033Resolved(DSP033StatRules.STAT_COOLDOWN), tic + 120);
            // Controlled Duplicator rank2 (+1 Amount, max rank) / Crown
            // rank5 (+400 milli Growth, max rank) fixture, matching P038's
            // Attractorb/P037's Spellbinder ingredient-fixture pattern:
            // resolved unconditionally whenever the P040 route is selected,
            // never touching the pre-P040 four-field Resolve() path or its
            // hash, per ResolvedStats.zs's own DSP033RecomputeAmountGrowth
            // contract.
            DSP033RecomputeAmountGrowth(2, 5);
            Console.Printf("DS_P040_MAP16_FIXTURE accepted=%d route=OPT_IN_P040 lightning_rank=8 pentagram_rank=8 strike_weapon_id=%d erase_weapon_id=%d duplicator_rank=2 crown_rank=5 resolved_amount=%d resolved_growth_milli=%d equipment=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", (lightningEquipped && pentagramEquipped) ? 1 : 0, p040StrikeWeaponSlot >= 0 ? ids[p040StrikeWeaponSlot] : 0, p040EraseWeaponSlot >= 0 ? ids[p040EraseWeaponSlot] : 0, DSP033Resolved(DSP033StatRules.STAT_AMOUNT), DSP033Resolved(DSP033StatRules.STAT_GROWTH));
            if (!lightningEquipped || !pentagramEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P040_MAP16_CONTROLLED_EQUIP");
        }
        if (p041RouteEnabled)
        {
            // A single labelled logical wall segment (mirrors MAP27's own
            // SetupWalls fixture exactly), so wall-versus-boundary-versus-
            // enemy reflection ordering is exercised on MAP16 too, not just
            // in the MAP27 harness. Stationary in world space; DSP041's own
            // moving boundary is what tracks the player, per contract.
            DSP041ResetLogicalWalls();
            DSP041AddLogicalWall(1, playerX + 60.0, playerY - 200.0,
                playerX + 60.0, playerY + 200.0);
            p041RunetracerWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p041RunetracerWeaponSlot >= 0)
                collisionRadii[p041RunetracerWeaponSlot] = 0.0;
            bool runetracerEquipped = p041RunetracerWeaponSlot >= 0
                && DSP041EquipFixture(DSP041BounceRows.SYSTEM_RUNETRACER, 8,
                    p041RunetracerWeaponSlot, tic + 70);
            if (runetracerEquipped)
                p041RunetracerWeaponIndex = dsp041WeaponSystems.Size() - 1;
            p041BoneWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p041BoneWeaponSlot >= 0)
                collisionRadii[p041BoneWeaponSlot] = 0.0;
            bool boneEquipped = p041BoneWeaponSlot >= 0
                && DSP041EquipFixture(DSP041BounceRows.SYSTEM_BONE, 8,
                    p041BoneWeaponSlot, tic + 70);
            if (boneEquipped)
                p041BoneWeaponIndex = dsp041WeaponSystems.Size() - 1;
            p041CherryWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p041CherryWeaponSlot >= 0)
                collisionRadii[p041CherryWeaponSlot] = 0.0;
            bool cherryEquipped = p041CherryWeaponSlot >= 0
                && DSP041EquipFixture(DSP041BounceRows.SYSTEM_CHERRY, 8,
                    p041CherryWeaponSlot, tic + 70);
            if (cherryEquipped)
                p041CherryWeaponIndex = dsp041WeaponSystems.Size() - 1;
            p041CarrelloWeaponSlot = Allocate(KIND_WEAPON, playerX, playerY,
                0.0, 0.0, 1);
            if (p041CarrelloWeaponSlot >= 0)
                collisionRadii[p041CarrelloWeaponSlot] = 0.0;
            bool carrelloEquipped = p041CarrelloWeaponSlot >= 0
                && DSP041EquipFixture(DSP041BounceRows.SYSTEM_CARRELLO, 8,
                    p041CarrelloWeaponSlot, tic + 70);
            if (carrelloEquipped)
                p041CarrelloWeaponIndex = dsp041WeaponSystems.Size() - 1;
            Console.Printf("DS_P041_MAP16_FIXTURE accepted=%d route=OPT_IN_P041 runetracer_rank=8 bone_rank=8 cherry_rank=8 carrello_rank=8 runetracer_weapon_id=%d bone_weapon_id=%d cherry_weapon_id=%d carrello_weapon_id=%d first_fire_tic=%d wall_id=1 equipment=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0", (runetracerEquipped && boneEquipped && cherryEquipped && carrelloEquipped) ? 1 : 0, p041RunetracerWeaponSlot >= 0 ? ids[p041RunetracerWeaponSlot] : 0, p041BoneWeaponSlot >= 0 ? ids[p041BoneWeaponSlot] : 0, p041CherryWeaponSlot >= 0 ? ids[p041CherryWeaponSlot] : 0, p041CarrelloWeaponSlot >= 0 ? ids[p041CarrelloWeaponSlot] : 0, tic + 70);
            if (!runetracerEquipped || !boneEquipped || !cherryEquipped
                || !carrelloEquipped)
                Console.Printf("DS_RUNTIME_ASSERT_FAIL kind=P041_MAP16_CONTROLLED_EQUIP");
        }
        runState = STATE_STARTING; priorState = STATE_STARTING; IsUiProcessor = false; EmitInputOwnership("ACTIVE_STARTING");
        SendInterfaceEvent(consoleplayer, "P030_RESET", 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P033_MAP16_HEALTH_CAP", CurrentPlayerHealthCap(), 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_UI_RESET", 0, 0, 0);
        SendInterfaceEvent(consoleplayer, "P032_MAP16_MODE", p032RouteEnabled ? 1 : 0, p032RouteEnabled && DSP032Rank(DSP032_ID_BLOODY_TEAR) > 0 ? 1 : 0, 0);
        Console.Printf("DS_P030_STARTER run_id=%d generation=%d level=1 health_milli=%d armor=1 might_milli=1000 whip_rank=%d passive_ranks=0 inventory=WHIP source_character=ANTONIO source_weapon=WHIP initial_store=%d", runId, runGeneration, playerHealth, whipRank, LiveStoreCount());
    }

    void LogicalTic()
    {
        if (runState != STATE_ACTIVE) return;
        tic++;
        N2ProfileBegin();
        RecomputeRunStats();
        // A character's "extra level" draft (DSP031StartRun) opens at once.
        if (rsActive && tic == 1 && ArcanaStartPick() && ArcanaCanDrop()) { OpenArcanaPick("RUN_START"); if (arPickOpen) return; }
        if (rsActive && tic == 1 && ActiveDraftQueueCount() > 0) { OpenLevelUp(); return; }
        ArcanaTick();
        MusicDuckTick();
        SyncPlayer();
        if (mfEnabled) MFReleaseSpawns();
        else { UpdateSpawnPhase(); ReleaseDueSpawns(); }
        MoveEnemies();
        if (mfEnabled) MFMaintainEnemies();
        N2ProfileEnd("PRE_SPAWN_MOVE");
        SpawnP033ContactFixture();
        TryP039ContactFixture();
        TryP041ContactFixture();
        N2MaintainDispatchEvidenceRing();
        N2ProfileEnd("CONTACT_FIXTURES");
        DSP024Rebuild();
        N2ProfileEnd("SPATIAL_REBUILD_INITIAL");
        ProcessContact();
        N2ProfileEnd("PROCESS_CONTACT");
        if (runState != STATE_ACTIVE) return;
        ProcessWhip();
        N2ProfileEnd("WHIP");
        if (runState != STATE_ACTIVE) return;
        ProcessP031DiagnosticAutoPulse();
        if (runState != STATE_ACTIVE) return;
        ProcessP034AimedWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP035BallisticWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP036ReturningWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP037OrbitWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP038GroundWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP039AuraWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP040GlobalWeapons();
        if (runState != STATE_ACTIVE) return;
        ProcessP041BounceWeapons();
        if (runState != STATE_ACTIVE) return;
        N2GrantAllFixture();
        if (runState != STATE_ACTIVE) return;
        N2DrainPendingDispatch();
        if (runState != STATE_ACTIVE) return;
        ProcessOwnedWeapons();
        if (runState != STATE_ACTIVE) return;
        N2ProfileBegin();
        GwProcessTic();
        N2ProfileEnd("GENERIC");
        if (runState != STATE_ACTIVE) return;
        ProcessPickups();
        N2ProfileEnd("PICKUPS");
        if (runState == STATE_ACTIVE) ProcessP039Recovery();
        if (runState == STATE_ACTIVE) ProcessP032ChestProximity();
        if (runState == STATE_ACTIVE) N2MaintainChestCadence();
        if (runState == STATE_ACTIVE && mfEnabled) { MFDebugChests(); EffectsTick(); MFMaintainChests(); }
        if (runState == STATE_ACTIVE && mfEnabled) { MFProcessItems(); GmTick(); }
        if (runState == STATE_ACTIVE) N2MaintainEvolutionFixture();
        N2ProfileEnd("TAIL");
        if (runState == STATE_ACTIVE && tic >= RunEndTic())
        {
            if (mfEnabled && survivalTics == MAD_FOREST_TICS) MFMaintainReaper();
            else EndRun("TIME_LIMIT");
        }
        if (runState == STATE_ACTIVE && (tic == 1 || tic % 35 == 0))
            Console.Printf("DS_P030_STATE tic=%d elapsed_seconds=%d health=%d/%d level=%d xp=%d kills=%d enemies=%d pickups=%d cap=%d yaw=%.3f pitch=%.3f movement_route=P021_BODY automatic_whip=1 px=%.1f py=%.1f", tic, tic / 35, playerHealth, PLAYER_HEALTH, playerLevel, experienceMilliunits, kills, LiveEnemyCount(), LivePickupCount(), CurrentCap(), players[0].mo != null ? players[0].mo.Angle : 0.0, players[0].mo != null ? players[0].mo.Pitch : 0.0, playerX, playerY);
    }

    override void OnRegister()
    {
        // The world keeps native UserCmd routing while active.  The pinned
        // UZDoom responder skips InputProcess for UI processors, so this must
        // become true only when the modal/results UI owns the event stream.
        IsUiProcessor = false; RequireMouse = true;
    }

    override void WorldLoaded(WorldEvent e)
    {
        // Every stage map runs the slice (DSStage.ForMap: MAP16, MAP30, ...).
        enabled = DSStage.ForMap(level.MapName) >= 0;
        mfStage = max(0, DSStage.ForMap(level.MapName));
        // Release global UI ownership before checking the map. This also
        // handles returning from MAP16 results to another map.
        IsUiProcessor = false;
        if (!enabled) return;
        CVar mode = CVar.FindCVar("ds_p030_mode");
        configuredMode = mode != null ? mode.GetString() : "manual";
        p041RouteEnabled = configuredMode == "p041";
        p040RouteEnabled = configuredMode == "p040" || p041RouteEnabled;
        p039RouteEnabled = configuredMode == "p039" || p040RouteEnabled;
        p038RouteEnabled = configuredMode == "p038" || p039RouteEnabled;
        p037RouteEnabled = configuredMode == "p037" || p038RouteEnabled;
        p036RouteEnabled = configuredMode == "p036" || p037RouteEnabled;
        p035RouteEnabled = configuredMode == "p035" || p036RouteEnabled;
        p034RouteEnabled = configuredMode == "p034" || p035RouteEnabled;
        p033RouteEnabled = configuredMode == "p033" || p034RouteEnabled;
        // N2 (docs/contracts/normal-play-integration.md): the manual launcher
        // route and its deterministic-bot soak twin use the full P031
        // inventory/draft authority against the full DSN2Catalog, instead of
        // the P028 hard-coded Whip/Spinach/Armor draft. P031's own opt-in
        // fixture mode (configuredMode == "p031") keeps the restricted
        // P028/P033 subset untouched, per the frozen contract.
        bool n2FullCatalogRoute = configuredMode == "manual" || configuredMode == "soak_n2";
        p031RouteEnabled = configuredMode == "p031" || p033RouteEnabled || n2FullCatalogRoute;
        p032RouteEnabled = configuredMode == "p032" || p033RouteEnabled;
        p033ContactFixtureEnabled = false;
        CVar contactFixture = CVar.FindCVar("ds_p033_contact_fixture");
        p033ContactFixtureEnabled = p033RouteEnabled && contactFixture != null
            && contactFixture.GetInt() != 0;
        DSP031SetP033PassivesEnabled(p033RouteEnabled || n2FullCatalogRoute);
        DSP031SetFullCatalogEnabled(n2FullCatalogRoute);
        // N2-W5 INTERIM_CHEST_CADENCE (docs/contracts/normal-play-
        // integration.md "Evolutions and chests"): one chest every 2100 tics
        // (60s of run time) in the manual/soak_n2 route. ds_n2_evolve_fixture
        // shortens the cadence for the MAP16 evidence fixture only; it never
        // changes the default manual launcher route's cadence.
        n2ChestCadenceEnabled = n2FullCatalogRoute;
        CVar evolveFixture = CVar.FindCVar("ds_n2_evolve_fixture");
        bool n2EvolveFixtureOn = evolveFixture != null && evolveFixture.GetInt() != 0;
        n2ChestCadenceInterval = n2EvolveFixtureOn ? 105 : 2100;
        n2NextChestTic = 70 + n2ChestCadenceInterval;
        n2ChestSeq = 0; n2ActiveChestId = 0; n2ChestTargetX = 0.0; n2ChestTargetY = 0.0; n2EvolutionAppliedCount = 0;
        n2AppliedRecipeIds.Clear();
        n2EvolutionFixtureEnabled = n2FullCatalogRoute && n2EvolveFixtureOn;
        // Mad Forest timeline for normal play and its soak twin; the N2
        // evidence fixtures keep the original opening schedule and cadence.
        CVar grantAllFixture = CVar.FindCVar("ds_n2_grant_all");
        mfEnabled = n2FullCatalogRoute && !n2EvolveFixtureOn
            && !(grantAllFixture != null && grantAllFixture.GetInt() != 0);
        // Characters, PowerUps and passive stats apply in normal play only.
        rsActive = mfEnabled;
        CVar characterCVar = CVar.FindCVar("ds_character");
        rsCharacter = rsActive && characterCVar != null
            ? DSCharacters.FromCVar(characterCVar.GetString()) : DSCharacters.ANTONIO;
        if (!DSCharacters.Playable(rsCharacter)) rsCharacter = DSCharacters.ANTONIO;
        CVar modeCVar = CVar.FindCVar("ds_mode");
        rsMode = rsActive && modeCVar != null ? clamp(modeCVar.GetInt(), 0, 2) : 0;
        n2EvolutionPassivesGranted = false;
        n2EvolutionBatchStage = 0;
        n2EvolutionBiBraceletReranked = false;
        DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        CVar speed = CVar.FindCVar("ds_p030_speed");
        logicalStepsPerWorldTick = speed != null ? speed.GetInt() : 1;
        if (logicalStepsPerWorldTick < 1) logicalStepsPerWorldTick = 1;
        if (logicalStepsPerWorldTick > MAX_TEST_STEPS) logicalStepsPerWorldTick = MAX_TEST_STEPS;
        CVar telemetry = CVar.FindCVar("ds_p030_telemetry");
        telemetryEnabled = telemetry != null ? telemetry.GetInt() : 1;
        if (telemetryEnabled != 0) telemetryEnabled = 1;
        dsQuiet = configuredMode == "manual" && telemetryEnabled == 0;
        CVar inputTrace = CVar.FindCVar("ds_p030_input_trace");
        inputTraceEnabled = inputTrace != null ? inputTrace.GetInt() : 0;
        if (inputTraceEnabled != 0) inputTraceEnabled = 1;
        CVar p032Mode = CVar.FindCVar("ds_p032_mode");
        p032PickupTapeEnabled = p032RouteEnabled && p032Mode != null
            && p032Mode.GetString() != "manual";
        DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        startedThisProcess = false;
        if ((p033RouteEnabled || n2ChestCadenceEnabled) && e.IsSaveGame)
        {
            // EventHandlers may be restored without WorldLoaded on a normal
            // save load. When the engine does deliver this event, preserve its
            // serialized run and let the first WorldTick repair derived stats.
            IsUiProcessor = runState == STATE_LEVELUP || runState == STATE_RESULTS;
            Console.Printf("DS_P033_MAP16_RESTORE_DEFERRED is_save=1 tic=%d run_state=%s run_id=%d generation=%d", tic, StateName(runState), runId, runGeneration);
            return;
        }
        completed = false; completionEmitted = false;
        ReadProfile(); runGeneration = 0; ConfigureCamera();
        if (p031RouteEnabled) DSP031LoadSealProfile();
        SendInterfaceEvent(consoleplayer, "P031_MODE", p031RouteEnabled ? 1 : 0, 0, 0);
        if (p033RouteEnabled) DSP033SetBaseStats(1000, 1, PLAYER_HEALTH, 1000);
        ConfigureDuration(); ResetRunState();
        // ResetRunState is duration agnostic and retains this selection for
        // results retry.
        if (configuredMode == "harness") RunBasisProof();
        if (configuredMode == "harness") ResetRunState();
        EmitCameraRow();
        Console.Printf("DS_P030_BOOT map=%s ticrate=%d stage=FOREST enemy=BAT3 schedule=QUALIFIED_OPENING_0_1_2 source_build=1.16.107 steam_build=25016043 mode=%s logical_steps=%d normal_speed=%d authority=DSP020,DSP022,DSP023,DSP024,DSP025,DSP026,DSP027,DSP028,DSP029", MAP, Thinker.TICRATE, configuredMode, logicalStepsPerWorldTick, logicalStepsPerWorldTick == 1);
        Console.Printf("DS_P030_RULES duration_tics=%d duration_seconds=%d interval_seconds=2,1.5,1 caps=15,30,50 xp_value=1000 pickup_radius=24 attract_radius=96 pickup_speed=8 native_movement=DISABLED native_attack=DISABLED geometry=ENGINEERING_APPROXIMATION", survivalTics, survivalTics / 35);
        Console.Printf("DS_P030_NATIVE_GUARD pawn=LIVE_VESSEL native_damage=DISABLED native_death=DISABLED native_respawn=DISABLED map_exit=DISABLED");
        if (p031RouteEnabled)
            Console.Printf("DS_P031_MAP16_BOOT route=OPT_IN_P031 authority=DSP031InventoryDraftAuthority default_p030_behavior=PRESERVED secondary_schedule=DIAGNOSTIC_TEST_AUTO_PULSE native_damage=DISABLED");
        if (p032RouteEnabled)
            Console.Printf("DS_P032_MAP16_BOOT route=OPT_IN_P032 authority=DSP032TransformationGraph fixture=WHIP8_HOLLOW_HEART1 default_p030_behavior=PRESERVED natural_levelup_claim=0 replacement=AUTOMATIC_BLOODY_TEAR_APPROXIMATION");
        if (p033RouteEnabled)
        {
            Console.Printf("DS_P033_MAP16_BOOT route=OPT_IN_P033 camera_variant=%d source_state=DSP031_INVENTORY_AND_DSP032_GRAPH diagnostic_weapon=CONTROLLED_INELIGIBLE default_p030_manual=PRESERVED", cameraVariant);
            Console.Printf("DS_P033_MAP16_CONTACT_FIXTURE_MODE enabled=%d cvar=ds_p033_contact_fixture gate=p033_only", p033ContactFixtureEnabled ? 1 : 0);
        }
        if (p034RouteEnabled)
            Console.Printf("DS_P034_MAP16_BOOT route=OPT_IN_P034 systems=34,36 source_rows=DSP034WeaponRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE source_inventory_claim=0 coexistence=WHIP_AND_BLOODY_TEAR");
        if (p035RouteEnabled)
            Console.Printf("DS_P035_MAP16_BOOT route=OPT_IN_P035 systems=38,39,40,41 source_rows=DSP035WeaponRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE candelabrador=CONTROLLED_INGREDIENT_FIXTURE spinach_authority=DSP031_INVENTORY coexistence=WHIP_BLOODY_TEAR_AND_P034");
        if (p036RouteEnabled)
            Console.Printf("DS_P036_MAP16_BOOT route=OPT_IN_P036 systems=42,43 source_rows=DSP036ReturningRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE clover=CONTROLLED_INGREDIENT_FIXTURE coexistence=WHIP_BLOODY_TEAR_P034_P035 no_natural_acquisition_claim=1");
        if (p037RouteEnabled)
            Console.Printf("DS_P037_MAP16_BOOT route=OPT_IN_P037 systems=44,45 source_rows=DSP037OrbitRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE duration=CONTROLLED_INGREDIENT_FIXTURE coexistence=WHIP_BLOODY_TEAR_P034_P035_P036 save_state=DSP029_EVENTHANDLER pause=LOGICAL_TIC_FROZEN geometry=ENGINEERING_APPROXIMATION");
        if (p038RouteEnabled)
            Console.Printf("DS_P038_MAP16_BOOT route=OPT_IN_P038 systems=46,47 source_rows=DSP038GroundRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE attractorb=CONTROLLED_INGREDIENT_FIXTURE coexistence=WHIP_BLOODY_TEAR_AIMED_BALLISTIC_RETURNING_ORBIT save_state=DSP029_EVENTHANDLER pause=LOGICAL_TIC_FROZEN geometry=ENGINEERING_APPROXIMATION source_inventory_claim=0");
        if (p039RouteEnabled)
            Console.Printf("DS_P039_MAP16_BOOT route=OPT_IN_P039 systems=48,49 source_rows=DSP039AuraRows stats=DSP033ResolvedStats healing=DSP039Healing default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE pummarola=CONTROLLED_INGREDIENT_FIXTURE coexistence=WHIP_BLOODY_TEAR_AIMED_BALLISTIC_RETURNING_ORBIT_GROUND save_state=DSP029_EVENTHANDLER pause=LOGICAL_TIC_FROZEN geometry=ENGINEERING_APPROXIMATION source_inventory_claim=0");
        if (p040RouteEnabled)
            Console.Printf("DS_P040_MAP16_BOOT route=OPT_IN_P040 systems=50,51,52,53 source_rows=DSP040GlobalRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE duplicator_crown=CONTROLLED_INGREDIENT_FIXTURE coexistence=WHIP_BLOODY_TEAR_AIMED_BALLISTIC_RETURNING_ORBIT_GROUND_AURA save_state=DSP029_EVENTHANDLER pause=LOGICAL_TIC_FROZEN geometry=ENGINEERING_APPROXIMATION source_inventory_claim=0");
        if (p041RouteEnabled)
            Console.Printf("DS_P041_MAP16_BOOT route=OPT_IN_P041 systems=54,55,56,57,58 source_rows=DSP041BounceRows stats=DSP033ResolvedStats default_manual_preserved=1 equipment=CONTROLLED_MAP16_FIXTURE no_future_transform=RUNETRACER8_PLUS_ARMOR coexistence=WHIP_BLOODY_TEAR_AIMED_BALLISTIC_RETURNING_ORBIT_GROUND_AURA_GLOBAL save_state=DSP029_EVENTHANDLER pause=LOGICAL_TIC_FROZEN geometry=ENGINEERING_APPROXIMATION source_inventory_claim=0 boundary=LOGICAL_REFERENCE_V1_MOVING");
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (!enabled || e.Player != consoleplayer) return;
        if (e.Name == "P032_CHEST_PICKUP")
        {
            int chestId = e.Args[0];
            int bodyX = players[0].mo != null ? int(players[0].mo.Pos.X) : int(playerX);
            int bodyY = players[0].mo != null ? int(players[0].mo.Pos.Y) : int(playerY);
            bool accepted = p032RouteEnabled && runState == STATE_ACTIVE
                && DSP032PickUpChest(chestId, bodyX, bodyY);
            Console.Printf("DS_P032_MAP16_CHEST_PICKUP accepted=%d id=%d body_x=%d body_y=%d tic=%d authority=DSP032ChestRewardAuthority", accepted, chestId, bodyX, bodyY, tic);
            if (!accepted) { p032ChestPickupRequested = false; return; }
            p032ChestModalOpen = true;
            DestroyP032ChestProxy(chestId);
            Transition(STATE_LEVELUP, "P032_CHEST_PICKUP");
            ClearNativeInput();
            int subtype = DSP032ChestSubtype(chestId);
            int slots = DSP032ChestSlots(chestId);
            SendNetworkEvent("P032_UI_PAUSE", chestId, subtype, slots);
            SendNetworkEvent("P032_UI_SET_MODE", DSP032_RECIPE_WHIP_BLOODY_TEAR, 1, 0);
            SendInterfaceEvent(consoleplayer, "P032_UI_STATE", 0, DSP032InventoryHash(), DSP032ChestQueueCount());
            Console.Printf("DS_P032_MAP16_MODAL_PAUSE chest=%d tic=%d subtype=%d slots=%d world_clock_frozen=1 native_input_cleared=1", chestId, tic, subtype, slots);
            return;
        }
        if (e.Name == "P032_UI_CONFIRM")
        {
            ApplyP032ChestChoice(e.Args[0], e.Args[1], e.Args[2]);
            return;
        }
        if (e.Name == "P030_CHOICE") { ApplyChoice(e.Args[0], "NETWORK_EVENT"); return; }
        if (e.Name == "P030_LEVELUP_ACTION") { LevelUpAction(e.Args[0], e.Args[1]); return; }
        if (e.Name == "P030_RETRY") { RetryRun("RESULTS_UI"); return; }
        if (e.Name == "P030_RETURN")
        {
            if (runState != STATE_RESULTS) return;
            Console.Printf("DS_P030_RETURN_MENU_ACCEPTED run_id=%d generation=%d state=RESULTS entities=0 timers=0 input_latch=0 source=RESULTS_UI", runId, runGeneration);
        }
    }

    void RetryRun(String source)
    {
        if (runState != STATE_RESULTS) return;
        Console.Printf("DS_P030_RETRY_INTENT accepted=1 run_id=%d generation=%d source=%s", runId, runGeneration, source);
        profileNextRunId = runId + 1;
        Transition(STATE_RESTARTING, "UI_RETRY_INTENT"); ResetRunState();
        let pawn = DSP021FirstPersonPlayer(players[0].mo);
        Console.Printf("DS_P030_RETRY_ACK run_id=%d generation=%d level=1 health_milli=%d entities=%d menu_focus=0 input_latch=0 pawn_down=%d", runId, runGeneration, playerHealth, LiveStoreCount(), pawn != null && pawn.dying ? 1 : 0);
    }

    override void WorldTick()
    {
        if (!enabled && level != null && DSStage.ForMap(level.MapName) >= 0) enabled = true;
        if (!enabled) return;
        // Test aid: ds_debug_retry 1 presses Retry once on the results screen.
        CVar autoRetry = CVar.FindCVar("ds_debug_retry");
        if (autoRetry != null && autoRetry.GetInt() != 0 && runState == STATE_RESULTS && level.maptime % 70 == 0)
        {
            autoRetry.SetInt(0);
            RetryRun("DEBUG_CVAR");
        }
        let scrollPawn = DSP021FirstPersonPlayer(players[0].mo);
        if (scrollPawn != null)
            scrollPawn.autoScrollX = rsActive && runState == STATE_ACTIVE ? DSStage.AutoScrollMilli(mfStage) / 1000.0 : 0.0;
        bool firstTickThisProcess = !startedThisProcess;
        startedThisProcess = true;
        if (firstTickThisProcess && p038RouteEnabled && tic > 0
            && runState != STATE_STARTING)
        {
            RestoreP038Map16SavedRun();
            return;
        }
        if (firstTickThisProcess && p037RouteEnabled && !p038RouteEnabled && tic > 0
            && runState != STATE_STARTING)
        {
            RestoreP037Map16SavedRun();
            return;
        }
        if (firstTickThisProcess && p033RouteEnabled && tic > 0
            && runState != STATE_STARTING)
        {
            RestoreP033Map16SavedRun();
            return;
        }
        if (firstTickThisProcess && n2ChestCadenceEnabled && tic > 0
            && runState != STATE_STARTING)
        {
            RestoreN2ManualSavedRun();
            return;
        }
        if (n2ChestCadenceEnabled && n2SaveSnapshotHeld) return;
        if (p038RouteEnabled && p038SaveSnapshotHeld) return;
        if (p037RouteEnabled && !p038RouteEnabled && p037SaveSnapshotHeld) return;
        if (p033RouteEnabled && !p038RouteEnabled && p033SaveSnapshotHeld) return;
        if (n2ChestCadenceEnabled) EmitN2ManualSaveStateIfRequested();
        if (n2ChestCadenceEnabled && n2SaveSnapshotHeld) return;
        if (p038RouteEnabled) EmitP038Map16SaveStateIfRequested();
        if (p038RouteEnabled && p038SaveSnapshotHeld) return;
        if (p037RouteEnabled && !p038RouteEnabled)
            EmitP037Map16SaveStateIfRequested();
        if (p037RouteEnabled && !p038RouteEnabled && p037SaveSnapshotHeld) return;
        EmitNativeInputTrace();
        if (p032RouteEnabled && p032PickupTapeTicks > 0
            && p032ChestId > 0 && runState == STATE_ACTIVE && players[0].mo != null)
        {
            players[0].cmd.forwardmove = -32768;
            players[0].cmd.sidemove = 0;
            players[0].cmd.yaw = 0;
            players[0].cmd.pitch = 0;
            // WorldTick runs after the pawn's normal MovePlayer callback, so
            // this controlled route must invoke the same P021 body adapter
            // synchronously. Clear the injected command afterward so it is
            // not replayed as native input on the following engine tic.
            DSP021FirstPersonPlayer tapePawn = DSP021FirstPersonPlayer(players[0].mo);
            bool moveApplied = tapePawn != null;
            if (moveApplied)
            {
                tapePawn.MovePlayer();
                SyncPlayer();
            }
            players[0].cmd.forwardmove = 0;
            players[0].cmd.sidemove = 0;
            players[0].cmd.yaw = 0;
            players[0].cmd.pitch = 0;
            p032PickupTapeTicks--;
            double tapeDx = players[0].mo.Pos.X - p032PickupTapeStartX;
            double tapeDy = players[0].mo.Pos.Y - p032PickupTapeStartY;
            Console.Printf("DS_P032_MAP16_MOVEMENT_TAPE logical_tic=%d remaining=%d forwardmove=-32768 yaw=%.3f travel=%.3f move_player=%d source=ENGINE_TAPE_P021_BODY", tic, p032PickupTapeTicks, players[0].mo.Angle, sqrt(tapeDx * tapeDx + tapeDy * tapeDy), moveApplied);
        }
        if (!(p032RouteEnabled && p032PickupTapeTicks > 0 && p032ChestId > 0))
            N2SoakMoverTick();
        if (runState == STATE_STARTING)
        {
            Transition(STATE_ACTIVE, "START_COMPLETE");
            Console.Printf("DS_P030_RUN_START run_id=%d generation=%d stage=FOREST starter=ANTONIO_WHIP clock=0", runId, runGeneration);
            return;
        }
        if (runState == STATE_LEVELUP || runState == STATE_RESULTS || runState == STATE_RESTARTING || runState == STATE_ENDING)
        {
            if (runState == STATE_LEVELUP) N2DraftBotTick();
            ClearNativeInput(); SyncPresentation(); return;
        }
        int steps = logicalStepsPerWorldTick;
        for (int i = 0; i < steps && runState == STATE_ACTIVE; i++) LogicalTic();
        // Profiling aid: real time per 350 logical tics (10000 ms = real time).
        if (n2ProfileEnabled && tic % 350 == 0 && tic != perfLastTic)
        {
            double now = MSTimeF();
            if (perfLastTic > 0) Console.Printf("DS_PERF tic=%d wall_ms_per_350=%.0f enemies=%d pickups=%d", tic, now - perfLastMs, LiveEnemyCount(), LivePickupCount());
            perfLastTic = tic; perfLastMs = now;
        }
        N2ProfileBegin();
        SyncPresentation();
        N2ProfileEnd("PRESENTATION");
        PublishUiState();
        if (telemetryEnabled != 0 && runState == STATE_ACTIVE && tic % 350 == 0)
            Console.Printf("DS_P030_TRACE tic=%d elapsed_seconds=%d health=%d level=%d xp=%d kills=%d spawn_attempts=%d admissions=%d enemies=%d pickups=%d whip_proxies=%d spatial_candidates=%d native_damage=0 camera_gameplay_inputs=NONE", tic, tic / 35, playerHealth, playerLevel, experienceMilliunits, kills, spawnAttempts, spawnAdmissions, LiveEnemyCount(), LivePickupCount(), LiveWhipProxyCount(), spatialCandidateCount);
    }
}
