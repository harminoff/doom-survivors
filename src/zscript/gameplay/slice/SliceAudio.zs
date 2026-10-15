// Sound effects for DSP030VerticalSlice. The sounds, their names and settings come from
// tools/audio/sound_table.py; tools/audio/sfx_mix.py makes the files, SNDINFO and the
// DSSfx table (SliceAudioTable.zs). Presentation only: playing a sound never changes game state.
// Only normal play (rsActive) makes sound.
//
// The mix in a crowd (how horde games keep it readable): every sound has a category
// (DSSfx.CAT). The four combat categories (weapon fire, hits, deaths, pickups) are
//  - rate-limited per category: at most CAT_MAX starts inside a BUDGET_WINDOW and at least
//    CAT_GAP tics apart, whatever the individual sound; extra starts are dropped (a hit
//    texture does not need every hit, and 163 distinct sounds would otherwise each get
//    their own voices);
//  - compressed as a bus (BusGain): the more combat sounds started recently, the quieter
//    each new one;
//  - ducked under what the player must notice: while a feedback sound or a stinger holds
//    the music duck, combat sounds play at FOCUS_GAIN.
// Loudness is baked into the files by role (hits quietest, then deaths, pickups, weapons,
// feedback, stingers), so S_StartSound only applies these gains. Loud feedback sounds and
// the stingers also duck the music, like a sidechain compressor: the music drops by DUCK
// for HOLD tics, then eases back over DUCK_RELEASE tics.
// Every RATE_TICS a DS_AUDIO_RATE line reports asked/played starts per category.

// For the weapon engine mixins, which are also compiled into standalone fixture runtimes
// that have no Sfx: plays through the run's slice handler when there is one.
class DSSound
{
    play static void Weapon(int system, int gapTics = 4)
    {
        let slice = DSP030VerticalSlice(EventHandler.Find("DSP030VerticalSlice"));
        if (slice != null) slice.WeaponSfx(system, gapTics);
    }

    play static void Sfx(int id, int gapTics = 0)
    {
        let slice = DSP030VerticalSlice(EventHandler.Find("DSP030VerticalSlice"));
        if (slice != null) slice.Sfx(id, gapTics);
    }
}

extend class DSP030VerticalSlice
{
    const BUDGET_WINDOW = 10;      // tics (~0.3 s)
    const FOCUS_GAIN = 0.45;       // combat sounds while feedback / a stinger is held (-7 dB)
    const RATE_TICS = 350;
    //                              WEAPON HIT DEATH PICKUP
    // (tuned with tools/audio/mix_check.py: a late-game crowd averages ~7 combat voices,
    // the combat bus sits at the music's level, feedback stands out by 6+ LU)
    static const int CAT_MAX[] = {  3,     2,  2,    1 };
    static const int CAT_GAP[] = {  2,     4,  4,    3 };

    void Sfx(int id, int gapTics = 0)
    {
        if (!rsActive || id < 0 || id >= DSSfx.SFX_COUNT) return;
        while (sfxLastTic.Size() < DSSfx.SFX_COUNT) sfxLastTic.Push(-100000);
        while (sfxCatLast.Size() < DSSfx.CAT_COUNT) { sfxCatLast.Push(-100000); sfxStatAsked.Push(0); sfxStatPlayed.Push(0); }
        int now = level.maptime;
        int cat = DSSfx.CAT[id];
        AudioRateReport(now);
        sfxStatAsked[cat]++;
        if (now - sfxLastTic[id] < gapTics) return;
        double gain = 1.0;
        if (cat < DSSfx.COMBAT_CATS)
        {
            if (now - sfxCatLast[cat] < CAT_GAP[cat]) return;
            int inWindow = 0; int total = 0;
            for (int i = sfxBusTics.Size() - 1; i >= 0; i--)
            {
                if (now - sfxBusTics[i] >= BUDGET_WINDOW) { sfxBusTics.Delete(i); sfxBusCats.Delete(i); continue; }
                total++;
                if (sfxBusCats[i] == cat) inWindow++;
            }
            if (inWindow >= CAT_MAX[cat]) return;
            gain = BusGain(total);
            if (now < duckUntil) gain *= FOCUS_GAIN;
            sfxBusTics.Push(now); sfxBusCats.Push(cat); sfxCatLast[cat] = now;
            sfxStatPeak = max(sfxStatPeak, total + 1);
        }
        sfxLastTic[id] = now;
        sfxStatPlayed[cat]++;
        S_StartSound(DSSfx.NAMES[id], CHAN_AUTO, CHANF_UI, gain, ATTN_NONE);
        if (DSSfx.DUCK[id] < 1.0)
        {
            duckGain = min(duckReady && duckGain < 1.0 && now < duckUntil ? duckGain : 1.0, DSSfx.DUCK[id]);
            duckUntil = max(duckUntil, now + DSSfx.HOLD[id]);
        }
    }

    // Effects bus compressor: the more combat sounds started in the budget window, the
    // quieter the next one, so a crowd stays a texture under the music.
    // 0 recent = full level, 3 = -4.1 dB, 6 = -6.0 dB, floor 0.35 (-9 dB).
    double BusGain(int recent)
    {
        return max(0.35, 1.0 / sqrt(1.0 + 0.5 * recent));
    }

    void AudioRateReport(int now)
    {
        if (now - sfxStatTic < RATE_TICS) return;
        if (sfxStatTic > 0)
        {
            String line = "";
            for (int c = 0; c < DSSfx.CAT_COUNT; c++)
                line = line .. String.Format(" c%d=%d/%d", c, sfxStatPlayed[c], sfxStatAsked[c]);
            Console.Printf("DS_AUDIO_RATE tic=%d window_peak=%d played/asked:%s", now, sfxStatPeak, line);
        }
        for (int c = 0; c < sfxStatAsked.Size(); c++) { sfxStatAsked[c] = 0; sfxStatPlayed[c] = 0; }
        sfxStatPeak = 0; sfxStatTic = now;
    }

    // One volley of a weapon (its own sound, DSSfx.ForWeapon). The gap keeps a weapon
    // with a very short cooldown from machine-gunning.
    void WeaponSfx(int system, int gapTics = 4)
    {
        Sfx(DSSfx.ForWeapon(system), gapTics);
    }

    // An enemy dying: props have their own breaking sounds, bosses and the Reaper
    // stingers, elites a heavier crunch, everything else the sound of its family.
    void DeathSfx(int slot)
    {
        if (!mfEnabled || !MFValid(slot)) { Sfx(DSSfx.DEATH, 3); return; }
        int type = mfTypes[slot];
        if (MFIsProp(type))
        {
            Sfx(type == MF_BRAZIER_TYPE ? DSSfx.D_BRAZIER : (type == MF_WINDOW_TYPE ? DSSfx.D_WINDOW : DSSfx.D_CART), 3);
            return;
        }
        if (DSStage.IsReaperLike(type)) { Sfx(DSSfx.D_REAPER, 10); return; }
        if (mfBoss[slot] > 0 || DSStage.Variant(type) == 3) { Sfx(DSSfx.D_BOSS, 10); return; }
        if (DSStage.Variant(type) == 1) { Sfx(DSSfx.D_ELITE, 6); return; }
        Sfx(DSSfx.ForFamily(DSStage.Family(type)), 3);
    }

    // Eases the music toward the ducked gain while a stinger is held, then back to full.
    void MusicDuckTick()
    {
        if (!duckReady) return;
        int now = level.maptime;
        double target = now < duckUntil ? duckGain : 1.0;
        double step = (1.0 - min(duckGain, 0.99)) / DSSfx.DUCK_RELEASE;
        if (duckVolume > target) duckVolume = max(target, duckVolume - step * 3.0);   // quick attack
        else if (duckVolume < target) duckVolume = min(target, duckVolume + step);       // slow release
        if (now >= duckUntil && duckVolume >= 1.0) duckGain = 1.0;
        if (abs(duckVolume - duckApplied) > 0.004) { SetMusicVolume(duckVolume); duckApplied = duckVolume; }
    }

    void MusicDuckReset()
    {
        duckGain = 1.0; duckVolume = 1.0; duckUntil = 0; duckApplied = 1.0; duckReady = true;
        sfxBusTics.Clear(); sfxBusCats.Clear(); sfxStatTic = 0;
        SetMusicVolume(1.0);
        // A SNDINFO entry whose file is missing plays silence without any warning,
        // so each run start reports the effects that did not load.
        int missing = 0;
        for (int i = 0; i < DSSfx.SFX_COUNT; i++)
        {
            if (S_GetLength(DSSfx.NAMES[i]) > 0) continue;
            missing++;
            Console.Printf("DS_AUDIO_MISSING sound=%s", DSSfx.NAMES[i]);
        }
        Console.Printf("DS_AUDIO_CHECK sounds=%d missing=%d", DSSfx.SFX_COUNT, missing);
    }
}
