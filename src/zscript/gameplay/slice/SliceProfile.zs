// Durable profile (gold and run cursor) read/commit.
// Part of DSP030VerticalSlice (fields and core lifecycle live in
// gameplay/VerticalSlice.zs).

extend class DSP030VerticalSlice
{
    int HashProfile(int totalCurrency, int nextRun, int amount, int keyRun)
    {
        int hash = 216613626;
        hash = hash * 31 + PROFILE_SCHEMA;
        hash = hash * 31 + totalCurrency;
        hash = hash * 31 + nextRun;
        hash = hash * 31 + amount;
        hash = hash * 31 + keyRun;
        return hash;
    }

    int RunIdFromKey(String key)
    {
        if (key.IndexOf("run:") != 0 || key.IndexOf(":results") < 5) return 0;
        return key.Mid(4, key.IndexOf(":results") - 4).ToInt();
    }

    bool ParseProfile(String payload, out int totalCurrency, out int nextRun,
                      out String lastKey, out int lastAmount)
    {
        totalCurrency = 0; nextRun = 1; lastKey = ""; lastAmount = 0;
        if (payload.Length() == 0) return true;
        Array<String> parts;
        payload.Split(parts, ";");
        if (parts.Size() != 6 || parts[0] != "v1"
            || parts[1].IndexOf("currency=") != 0
            || parts[2].IndexOf("next_run_id=") != 0
            || parts[3].IndexOf("last_key=") != 0
            || parts[4].IndexOf("last_amount=") != 0
            || parts[5].IndexOf("hash=") != 0) return false;
        totalCurrency = parts[1].Mid(9).ToInt();
        nextRun = parts[2].Mid(12).ToInt();
        lastKey = parts[3].Mid(9);
        lastAmount = parts[4].Mid(12).ToInt();
        int keyRun = RunIdFromKey(lastKey);
        int storedHash = parts[5].Mid(5).ToInt();
        if (totalCurrency < 0 || nextRun < 1 || lastAmount < 0) return false;
        if (lastKey.Length() == 0 && lastAmount != 0) return false;
        // A run that picks up no gold commits last_amount=0; that is valid.
        if (lastKey.Length() > 0 && keyRun <= 0) return false;
        String expected = String.Format("v1;currency=%d;next_run_id=%d;last_key=%s;last_amount=%d;hash=%d", totalCurrency, nextRun, lastKey, lastAmount, storedHash);
        return expected == payload && storedHash == HashProfile(totalCurrency, nextRun, lastAmount, keyRun);
    }

    String SerializeProfile(int totalCurrency, int nextRun, String lastKey, int lastAmount)
    {
        int keyRun = RunIdFromKey(lastKey);
        int hash = HashProfile(totalCurrency, nextRun, lastAmount, keyRun);
        return String.Format("v1;currency=%d;next_run_id=%d;last_key=%s;last_amount=%d;hash=%d", totalCurrency, nextRun, lastKey, lastAmount, hash);
    }

    void ReadProfile()
    {
        profileCurrency = 0; profileNextRunId = 1; profileLastKey = "";
        profileLastAmount = 0; profileRejected = false;
        CVar payload = CVar.FindCVar("ds_p030_profile_payload");
        String text = payload != null ? payload.GetString() : "";
        int total; int next; String key; int amount;
        if (!ParseProfile(text, total, next, key, amount))
        {
            profileRejected = true;
            Console.Printf("DS_P030_PROFILE_REJECT reason=MALFORMED_OR_HASH_MISMATCH partial_apply=0");
            return;
        }
        profileCurrency = total; profileNextRunId = next;
        profileLastKey = key; profileLastAmount = amount;
        Console.Printf("DS_P030_PROFILE_READ accepted=1 currency=%d next_run_id=%d last_key=%s last_amount=%d", profileCurrency, profileNextRunId, profileLastKey.Length() > 0 ? profileLastKey : "NONE", profileLastAmount);
    }

    bool CommitReward(int amount)
    {
        if (amount < 0) return false;
        String key = String.Format("run:%d:results", runId);
        CVar payload = CVar.FindCVar("ds_p030_profile_payload");
        String text = payload != null ? payload.GetString() : "";
        int total; int next; String last; int lastAmount;
        if (!ParseProfile(text, total, next, last, lastAmount))
        {
            Console.Printf("DS_P030_REWARD_REJECT key=%s amount=%d reason=MALFORMED_PROFILE partial_apply=0", key, amount);
            return false;
        }
        if (last == key)
        {
            if (lastAmount != amount)
            {
                Console.Printf("DS_P030_REWARD_REJECT key=%s amount=%d prior_amount=%d reason=SAME_KEY_AMOUNT_CHANGED partial_apply=0", key, amount, lastAmount);
                return false;
            }
            profileCurrency = total; profileNextRunId = next;
            profileLastKey = last; profileLastAmount = lastAmount;
            Console.Printf("DS_P030_REWARD_COMMIT key=%s amount=%d balance=%d disposition=ALREADY_COMMITTED changed=0", key, amount, total);
            return true;
        }
        if (last.Length() > 0 && last != profileLastKey)
        {
            Console.Printf("DS_P030_REWARD_REJECT key=%s amount=%d reason=PROFILE_CURSOR_CHANGED partial_apply=0", key, amount);
            return false;
        }
        int nextTotal = total + amount;
        if (nextTotal < total) return false;
        if (payload == null) return false;
        String nextPayload = SerializeProfile(nextTotal, runId + 1, key, amount);
        payload.SetString(nextPayload);
        if (!CVar.SaveConfig())
        {
            payload.SetString(text);
            Console.Printf("DS_P030_REWARD_REJECT key=%s amount=%d reason=SAVE_FAILED partial_apply=0", key, amount);
            return false;
        }
        profileCurrency = nextTotal; profileNextRunId = runId + 1;
        profileLastKey = key; profileLastAmount = amount;
        Console.Printf("DS_P030_REWARD_COMMIT key=%s amount=%d balance=%d disposition=COMMITTED changed=1 save_config=1", key, amount, profileCurrency);
        return true;
    }
}
