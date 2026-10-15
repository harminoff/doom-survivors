// Visuals for the weapons that have no projectile proxy in normal play:
// the Garlic/Soul Eater aura, Holy Water/La Borra fields and the King Bible
// orbit sprites (tools/art/weapon_art.py). Presentation only; it reads engine
// state and never changes it. Strike bolts and the Pentagram flash are spawned
// from GlobalRuntime.zs through DSWeaponFx.Burst.
extend class DSP030VerticalSlice
{
    static Color FxTint(int system)
    {
        switch (system)
        {
        case 46: return Color(80, 160, 255);
        case 47: return Color(210, 70, 40);
        case 48: return Color(255, 190, 225);
        case 49: return Color(255, 60, 80);
        }
        return Color(200, 200, 255);
    }

    static String OrbitSprite(int system) { return system == 45 ? "WVES" : "WBIB"; }

    // Keeps one persistent effect per key, moving it and dropping any that
    // were not refreshed since the last sync.
    void FxKeep(int key, String spr, double px, double py, double z, double size, bool flat, Color tint, double alpha)
    {
        for (int i = 0; i < fxKeys.Size(); i++)
        {
            if (fxKeys[i] != key) continue;
            if (fxActors[i] == null) break;
            fxActors[i].SetOrigin((px, py, z), true);
            fxActors[i].A_SetScale(size / 32.0);
            if (tint.a != 0 || tint.r != 0 || tint.g != 0 || tint.b != 0) fxActors[i].SetShade(tint);   // state colours (ready / resting) change over time
            fxSeen[i] = fxStamp;
            return;
        }
        DSWeaponFx f = DSWeaponFx.Make(spr, px, py, z, size, size, flat, tint, alpha, 0);
        for (int i = 0; i < fxKeys.Size(); i++)
            if (fxKeys[i] == key) { fxActors[i] = f; fxSeen[i] = fxStamp; return; }
        fxKeys.Push(key); fxActors.Push(f); fxSeen.Push(fxStamp);
    }

    void SyncWeaponFx()
    {
        fxStamp++;
        if (rsActive && runState == STATE_ACTIVE) GmSyncActors();
        if (rsActive && runState == STATE_ACTIVE)
        {
            for (int i = 0; i < dsp039AuraActive.Size(); i++)
            {
                if (dsp039AuraActive[i] == 0) continue;
                int sys = dsp039AuraSystem[i];
                double r = DSP039AuraRows.RadiusMilliUnits(sys, dsp039AuraRank[i]) / 1000.0
                    * dsp039AuraAreaAdjustmentMilli[i] / 1000.0;
                if (r > 8.0) FxKeep(1000 + i, "WRNG", playerX, playerY, 1.0, r * 2.0, true, FxTint(sys), 0.35);
            }
            // Little Hearts dropped by Soul Eater kills.
            for (int i = 0; i < dsp039HeartActive.Size(); i++)
                if (dsp039HeartActive[i] != 0)
                    FxKeep(600000 + dsp039HeartId[i], "WPRF", dsp039HeartX[i], dsp039HeartY[i], 8.0, 14.0, false, Color(0, 0, 0, 0), 1.0);
            if (ArcanaOwned(DSArcana.BLOOD_ASTRONOMIA))
                FxKeep(4000, "WRNG", playerX, playerY, 1.2, BloodAstronomiaRadius() * 2.0, true, Color(220, 40, 70), 0.3);
            for (int i = 0; i < dsp037MemberActive.Size(); i++)
            {
                if (dsp037MemberActive[i] == 0) continue;
                FxKeep(3000 + i, OrbitSprite(dsp037MemberSystemIds[i]), dsp037MemberX[i], dsp037MemberY[i],
                    34.0, 24.0, false, Color(0, 0, 0, 0), 1.0);
            }
            // Peachone / Ebony Wings / Vandalier birds circling the player
            // (their hits land as bombs on the ring; see PairedRuntime.zs).
            for (int i = 0; i < dsp042WeaponSystems.Size(); i++)
            {
                int sys = dsp042WeaponSystems[i];
                if (sys != DSP042PairedRows.SYSTEM_PEACHONE && sys != DSP042PairedRows.SYSTEM_EBONY
                    && sys != DSP042PairedRows.SYSTEM_VANDALIER) continue;
                for (int b = 0; b < 2; b++)
                {
                    bool ccw = sys == DSP042PairedRows.SYSTEM_EBONY || (sys == DSP042PairedRows.SYSTEM_VANDALIER && b == 1);
                    double a = (ccw ? -tic : tic) * 4.0 + b * 180.0 + i * 37.0;
                    String spr = sys == DSP042PairedRows.SYSTEM_VANDALIER ? "WBRW"
                        : (sys == DSP042PairedRows.SYSTEM_EBONY ? "WBRK" : "WBRD");
                    double r = DSP042PairedRows.BIRD_ORBIT_RADIUS;
                    FxKeep(5000 + i * 4 + b, spr, playerX + cos(a) * r, playerY + sin(a) * r, 40.0, 22.0, false, Color(0, 0, 0, 0), 1.0);
                }
            }
            for (int i = 0; i < dsp038FieldActive.Size(); i++)
            {
                if (dsp038FieldActive[i] == 0 || dsp038FieldRadius[i] < 4.0) continue;
                FxKeep(2000 + dsp038FieldId[i], "WRNG", dsp038FieldX[i], dsp038FieldY[i], 1.0,
                    dsp038FieldRadius[i] * 2.0, true, FxTint(dsp038FieldSystem[i]), 0.55);
            }
        }
        for (int i = fxKeys.Size() - 1; i >= 0; i--)
        {
            if (fxActors[i] != null && fxSeen[i] == fxStamp) continue;
            if (fxActors[i] != null) fxActors[i].Destroy();
            fxKeys.Delete(i); fxActors.Delete(i); fxSeen.Delete(i);
        }
    }
}
