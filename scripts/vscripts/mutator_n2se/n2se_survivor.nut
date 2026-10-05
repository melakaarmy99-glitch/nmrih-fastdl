if (!("Survivor" in N2SE)) {
    N2SE.Survivor <- {};
    N2SE.Survivor.ModKey <- "survivor";

    N2SE.Survivor.Config <- {
        headBodygroupName = "c_head",
        bodyBodygroupName = "body",
        hatBodygroupName  = "headgear",

        models = [
            {
                model      = "models/nmr_zombie/survivor_zombie01.mdl",
                modelMatch = "survivor_zombie01",
                headVariants        = [0],
                headSeveredVariants = [1, 2],
                bodyVariants        = [0],
                body2Index          = -1,
                hatVariants         = [0, 1],
                hatBlankIndex       = 2,
                muzzledHatVariants  = [1]
            },
            {
                model      = "models/nmr_zombie/survivor_zombie02.mdl",
                modelMatch = "survivor_zombie02",
                headVariants        = [0, 1],
                headSeveredVariants = [2, 3],
                bodyVariants        = [0, 1],
                body2Index          = 0,
                hatVariants         = [0, 1],
                hatBlankIndex       = 2,
                muzzledHatVariants  = [1]
            },
            {
                model      = "models/nmr_zombie/survivor_zombie03.mdl",
                modelMatch = "survivor_zombie03",
                headVariants        = [0],
                headSeveredVariants = [1, 2],
                bodyVariants        = [0, 1],
                body2Index          = 0,
                hatVariants         = [0, 1],
                hatBlankIndex       = 2,
                muzzledHatVariants  = [1]
            }
        ],

        spawnClass  = "npc_nmrih_shamblerzombie",
        runnerClass = "npc_nmrih_runnerzombie",

        runnerChance         = 15,
        spawnDelay           = 3.0,
        spawnMaxAttempts     = 5,

        headSplitChance  = 50,
        headSplitDelay   = 0.02,
        headRepairRounds = 12,
        headRepairStep   = 0.05,

        lootZOffset       = 20.0,
        lootDropMin       = 3,
        lootDropMax       = 5,
        lootScatterMin    = 8.0,
        lootScatterMax    = 24.0,

        lootCategories = {
            ammo = [
                { classname = "ammobox_12gauge", weight = 10 },
                { classname = "ammobox_308",     weight = 10 },
                { classname = "ammobox_357",     weight = 10 },
                { classname = "ammobox_45acp",   weight = 10 },
                { classname = "ammobox_762mm",   weight = 10 }
            ],
            item = [
                { classname = "item_bandages", weight = 5 },
                { classname = "item_pills",    weight = 5 }
            ],
            weapon = [
                { classname = "fa_1911",           weight = 3, clip1 = 0 },
                { classname = "fa_sv10",           weight = 3, clip1 = 0 },
                { classname = "fa_sw686",          weight = 3, clip1 = 0 },
                { classname = "fa_winchester1892", weight = 3, clip1 = 0 },
                { classname = "fa_sako85",         weight = 3, clip1 = 0 },
                { classname = "fa_cz858",          weight = 3, clip1 = 0 }
            ],
            explosive = [
                { classname = "exp_molotov", weight = 2 },
                { classname = "exp_tnt",     weight = 2 }
            ]
        }
    };

    N2SE.Survivor.EntitySet       <- {};
    N2SE.Survivor.PendingSpawns   <- {};
    N2SE.Survivor.PendingCounter  <- 0;
    N2SE.Survivor.HeadRepairToken <- "";

    N2SE.Survivor.IsEnabled <- function() {
        return N2SE.IsModOn("survivor");
    };

    N2SE.Survivor.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Survivor.Fire <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); } catch (ex) {}
    };

    N2SE.Survivor.GetHP <- function(z) {
        if (z == null || !z.IsValid()) return 0;
        try { return z.GetHealth(); } catch (ex) {
            try { return NetProps.GetPropInt(z, "m_iHealth"); } catch (ex2) { return 0; }
        }
    };

    N2SE.Survivor.GetBG <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        if (name == null || name == "") return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Survivor.SetBG <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        if (name == null || name == "") return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Survivor.IsSurvivorModel <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return false; }
        if (mn == null || mn == "") return false;
        local lc = mn.tolower();
        foreach (entry in N2SE.Survivor.Config.models) {
            if (entry.modelMatch != null && lc.find(entry.modelMatch.tolower()) != null)
                return true;
        }
        return false;
    };

    N2SE.Survivor.FindEntryByModel <- function(z) {
        if (z == null || !z.IsValid()) return null;
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return null; }
        if (mn == null || mn == "") return null;
        local lc = mn.tolower();
        foreach (entry in N2SE.Survivor.Config.models) {
            if (entry.modelMatch != null && lc.find(entry.modelMatch.tolower()) != null)
                return entry;
        }
        return null;
    };

    N2SE.Survivor.GetEntryForZombie <- function(z) {
        if (z == null || !z.IsValid()) return null;

        local sc = null;
        try { sc = z.GetScriptScope(); } catch (ex) {}
        if (sc != null && ("SurvivorModelIndex" in sc)) {
            local idx = sc.SurvivorModelIndex;
            local entries = N2SE.Survivor.Config.models;
            if (idx != null && idx >= 0 && idx < entries.len()) return entries[idx];
        }

        return N2SE.Survivor.FindEntryByModel(z);
    };

    N2SE.Survivor.IsHooded <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local entry = N2SE.Survivor.GetEntryForZombie(z);
        if (entry == null) return false;
        if (entry.body2Index == null || entry.body2Index < 0) return false;

        local bodyIdx = N2SE.Survivor.GetBG(z, N2SE.Survivor.Config.bodyBodygroupName);
        if (bodyIdx < 0) return false;
        return (bodyIdx == entry.body2Index);
    };

    N2SE.Survivor.Mark <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Survivor.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Survivor.EntitySet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsSurvivor <- true;
        } catch (ex) {}
    };

    N2SE.Survivor.Unmark <- function(z) {
        if (z == null) return;
        local zidx = N2SE.Survivor.Zidx(z);
        if (zidx <= 0) return;
        if (zidx in N2SE.Survivor.EntitySet) delete N2SE.Survivor.EntitySet[zidx];
    };

    N2SE.Survivor.IsSurvivor <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Survivor.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Survivor.EntitySet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsSurvivor" in sc) && sc.IsSurvivor) return true;
        } catch (ex) {}
        return N2SE.Survivor.IsSurvivorModel(z);
    };

    N2SE.Survivor.SetMuzzled <- function(z, muzzled) {
        if (z == null || !z.IsValid()) return;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsMuzzled <- (muzzled ? true : false);
        } catch (ex) {}
    };

    N2SE.Survivor.IsMuzzledHat <- function(entry, hatIdx) {
        if (entry == null) return false;
        if (hatIdx == null || hatIdx < 0) return false;
        local mv = entry.muzzledHatVariants;
        if (mv == null || mv.len() == 0) return false;
        foreach (idx in mv) {
            if (hatIdx == idx) return true;
        }
        return false;
    };

    N2SE.Survivor.ApplyPartsForEntry <- function(z, entry) {
        if (z == null || !z.IsValid()) return;
        if (entry == null) return;

        local bodyIdx = -1;
        if (entry.bodyVariants != null && entry.bodyVariants.len() > 0) {
            bodyIdx = entry.bodyVariants[RandomInt(0, entry.bodyVariants.len() - 1)];
            N2SE.Survivor.SetBG(z, N2SE.Survivor.Config.bodyBodygroupName, bodyIdx);
        }

        if (entry.headVariants != null && entry.headVariants.len() > 0) {
            local hIdx = entry.headVariants[RandomInt(0, entry.headVariants.len() - 1)];
            N2SE.Survivor.SetBG(z, N2SE.Survivor.Config.headBodygroupName, hIdx);
        }

        local finalHatIdx = -1;

        if (entry.body2Index >= 0 && bodyIdx == entry.body2Index) {
            finalHatIdx = entry.hatBlankIndex;
            N2SE.Survivor.SetBG(z, N2SE.Survivor.Config.hatBodygroupName, finalHatIdx);
        } else if (entry.hatVariants != null && entry.hatVariants.len() > 0) {
            finalHatIdx = entry.hatVariants[RandomInt(0, entry.hatVariants.len() - 1)];
            N2SE.Survivor.SetBG(z, N2SE.Survivor.Config.hatBodygroupName, finalHatIdx);
        }

        local muzzled = N2SE.Survivor.IsMuzzledHat(entry, finalHatIdx);
        N2SE.Survivor.SetMuzzled(z, muzzled);
    };

    N2SE.Survivor.RandomizeModel <- function(z) {
        if (z == null || !z.IsValid()) return null;

        local entries = N2SE.Survivor.Config.models;
        if (entries.len() == 0) return null;

        local idx = RandomInt(0, entries.len() - 1);
        local entry = entries[idx];

        try { z.SetModelOverride(entry.model); } catch (ex) {}

        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.SurvivorModelIndex <- idx;
        } catch (ex) {}

        N2SE.Survivor.ApplyPartsForEntry(z, entry);
        return entry;
    };

    N2SE.Survivor.IsHeadSevered <- function(z) {
        local entry = N2SE.Survivor.GetEntryForZombie(z);
        if (entry == null) return false;

        local cur = N2SE.Survivor.GetBG(z, N2SE.Survivor.Config.headBodygroupName);
        local list = entry.headSeveredVariants;
        if (list == null) return false;
        foreach (idx in list) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Survivor.HideHeadgear <- function(z) {
        if (z == null || !z.IsValid()) return;

        local entry = N2SE.Survivor.GetEntryForZombie(z);
        if (entry == null) return;

        local blank = entry.hatBlankIndex;
        if (blank == null || blank < 0) return;

        N2SE.Survivor.SetBG(z, N2SE.Survivor.Config.hatBodygroupName, blank);
        N2SE.Survivor.SetMuzzled(z, false);
    };

    N2SE.Survivor.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;

        local entry = N2SE.Survivor.GetEntryForZombie(z);
        if (entry == null) return false;
        if (N2SE.Survivor.IsHeadSevered(z)) return false;

        local v = entry.headSeveredVariants;
        if (v == null || v.len() == 0) return false;

        N2SE.Survivor.HideHeadgear(z);

        local chosen = v[RandomInt(0, v.len() - 1)];
        return N2SE.Survivor.SetBG(z, N2SE.Survivor.Config.headBodygroupName, chosen);
    };

    N2SE.Survivor.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Survivor.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Survivor.IsHeadSevered(z)) {
            N2SE.Survivor.ApplyHeadSevered(z);
        } else if (z != null && z.IsValid()) {
            N2SE.Survivor.HideHeadgear(z);
        }
        N2SE.Survivor.Fire("::N2SE.Survivor.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Survivor.Config.headRepairStep);
    };

    N2SE.Survivor.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Survivor.IsSurvivor(z)) return;
        if (N2SE.Survivor.IsHooded(z)) return;

        N2SE.Survivor.HideHeadgear(z);
        N2SE.Survivor.ApplyHeadSevered(z);

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {}
        if (!fired) try { EntFireByHandle(z, "Break", "", 0, null, null); fired = true; } catch (ex) {}
        if (!fired) N2SE.SafeKill(z);

        local token = UniqueString();
        N2SE.Survivor.HeadRepairToken = token;
        N2SE.Survivor.RepairHead(zidx, token, N2SE.Survivor.Config.headRepairRounds);
    };

    N2SE.Survivor.PickWeighted <- function(items) {
        if (items == null || items.len() == 0) return null;
        local total = 0;
        foreach (it in items) total += (("weight" in it) ? it.weight : 1);
        if (total <= 0) return items[0];
        local roll = RandomInt(1, total);
        local cum = 0;
        foreach (it in items) {
            cum += (("weight" in it) ? it.weight : 1);
            if (roll <= cum) return it;
        }
        return items[0];
    };

    N2SE.Survivor.ShuffleArray <- function(arr) {
        if (arr == null || arr.len() <= 1) return;
        for (local i = arr.len() - 1; i > 0; i--) {
            local j = RandomInt(0, i);
            local tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
    };

    N2SE.Survivor.SpawnLootItem <- function(chosen, basePos, offset) {
        if (chosen == null) return null;
        if (chosen.classname == null || chosen.classname == "") return null;

        local spawnPos = basePos + offset;

        local ent = null;
        try {
            ent = SpawnEntityFromTable(chosen.classname, {
                origin = spawnPos,
                angles = Vector(0, RandomFloat(0, 360), 0)
            });
        } catch (ex) { return null; }
        if (ent == null || !ent.IsValid()) return null;

        if ("clip1" in chosen) {
            try { ent.SetClip1(chosen.clip1); } catch (ex) {}
        }

        try { ent.Activate(); } catch (ex) {}

        return ent;
    };

    N2SE.Survivor.TryDropLootAt <- function(pos, z) {
        if (pos == null) return;
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Survivor.IsSurvivor(z)) return;

        if (!N2SE.IsLootEnabled()) return;

        local chance = N2SE.GetLootChance();
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance.tointeger()) return;

        local cfg = N2SE.Survivor.Config;

        local categoryPool = [];
        foreach (k, _pool in cfg.lootCategories) {
            categoryPool.append(k);
            if (k == "ammo") categoryPool.append(k);
        }
        if (categoryPool.len() == 0) return;

        N2SE.Survivor.ShuffleArray(categoryPool);

        local count = RandomInt(cfg.lootDropMin, cfg.lootDropMax);
        if (count > categoryPool.len()) count = categoryPool.len();

        local angleStep = 6.28318530718 / count.tofloat();
        local angleBase = RandomFloat(0, 6.28318530718);

        for (local i = 0; i < count; i++) {
            local key = categoryPool[i];
            local pool = cfg.lootCategories[key];
            if (pool == null || pool.len() == 0) continue;

            local chosen = N2SE.Survivor.PickWeighted(pool);
            if (chosen == null) continue;

            local ang = angleBase + i * angleStep + RandomFloat(-0.25, 0.25);
            local dist = RandomFloat(cfg.lootScatterMin, cfg.lootScatterMax);
            local zOff = cfg.lootZOffset + RandomFloat(0.0, 6.0);

            local offset = Vector(cos(ang) * dist, sin(ang) * dist, zOff);

            N2SE.Survivor.SpawnLootItem(chosen, pos, offset);
        }
    };

    N2SE.Survivor.HookZombie <- function(z) {
        if (z == null || !z.IsValid()) return;
        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("SurvivorZombieHooked" in sc)) return;
        sc.SurvivorZombieHooked <- true;

        local prev = ("OnTakeDamage" in sc) ? sc.OnTakeDamage : null;

        sc.OnTakeDamage <- function() {
            local z = self;
            if (z == null || !z.IsValid()) return true;

            if (!N2SE.Survivor.IsEnabled()) {
                if (prev != null) try { return prev(); } catch (ex) { return true; }
                return true;
            }

            if (!N2SE.Survivor.IsSurvivor(z)) {
                if (prev != null) try { return prev(); } catch (ex) { return true; }
                return true;
            }

            if (N2SE.Survivor.IsHooded(z)) {
                if (prev != null) try { return prev(); } catch (ex) { return true; }
                return true;
            }

            local di = null;
            try { di = info; } catch (ex) {}

            if (di != null) {
                local hg = 0;
                try { hg = NetProps.GetPropInt(z, "m_LastHitGroup"); } catch (ex) {}
                local isHead = (hg == 1 || hg == 10 || hg == 11);

                if (isHead) {
                    local dmg = 0;
                    try { dmg = di.GetDamage(); } catch (ex) {}
                    local hp = N2SE.Survivor.GetHP(z);
                    if (dmg > 0 && hp > 0 && dmg >= hp
                        && RandomInt(1, 100) <= N2SE.Survivor.Config.headSplitChance
                        && !N2SE.Survivor.IsHeadSevered(z)) {

                        local zidx = N2SE.Survivor.Zidx(z);
                        if (zidx > 0) {
                            N2SE.Survivor.Fire("::N2SE.Survivor.DoHeadSplit(" + zidx + ")",
                                N2SE.Survivor.Config.headSplitDelay);
                        }
                        return false;
                    }
                }
            }

            if (prev != null) try { return prev(); } catch (ex) { return true; }
            return true;
        };
    };

    N2SE.Survivor.Attach <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return false; }
        if (sc == null || ("SurvivorAttached" in sc)) return false;
        sc.SurvivorAttached <- true;

        N2SE.Survivor.Mark(z);
        N2SE.Survivor.RandomizeModel(z);
        N2SE.Survivor.HookZombie(z);
        return true;
    };

    N2SE.Survivor.CleanupState <- function(zidx) {
        if (zidx == null || zidx <= 0) return;
        if (zidx in N2SE.Survivor.EntitySet)     delete N2SE.Survivor.EntitySet[zidx];
        if (zidx in N2SE.Survivor.PendingSpawns) delete N2SE.Survivor.PendingSpawns[zidx];
    };

    N2SE.Survivor.SpawnCompanion <- function(pos, angles) {
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Survivor.Config;
        local maxAttempts = cfg.spawnMaxAttempts;
        if (maxAttempts < 1) maxAttempts = 1;

        for (local attempt = 0; attempt < maxAttempts; attempt++) {
            local cls = (RandomInt(1, 100) <= cfg.runnerChance)
                ? cfg.runnerClass
                : cfg.spawnClass;

            local zombie = null;
            try {
                zombie = SpawnEntityFromTable(cls, { origin = pos, angles = angles });
            } catch (ex) { continue; }
            if (zombie == null || !zombie.IsValid()) continue;

            N2SE.Survivor.Mark(zombie);

            try { DispatchSpawn(zombie); } catch (ex) {}
            if (!zombie.IsValid()) { N2SE.Survivor.Unmark(zombie); continue; }

            N2SE.Survivor.Mark(zombie);

            local hasArmor = false;
            try { if ("HasArmor" in zombie) hasArmor = zombie.HasArmor(); } catch (ex) {}
            if (hasArmor) {
                N2SE.Survivor.Unmark(zombie);
                N2SE.SafeKill(zombie);
                continue;
            }

            N2SE.Survivor.RandomizeModel(zombie);
            N2SE.Survivor.HookZombie(zombie);

            return zombie;
        }

        return null;
    };

    N2SE.Survivor.ScheduleCompanion <- function(pos, angles) {
        if (pos == null) return;

        N2SE.Survivor.PendingCounter = N2SE.Survivor.PendingCounter + 1;
        local id = N2SE.Survivor.PendingCounter;
        N2SE.Survivor.PendingSpawns[id] <- { pos = pos, angles = angles };
        N2SE.Survivor.Fire("::N2SE.Survivor.ExecuteDelayedSpawn(" + id + ")",
            N2SE.Survivor.Config.spawnDelay);
    };

    N2SE.Survivor.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Survivor.PendingSpawns)) return;
        local rec = N2SE.Survivor.PendingSpawns[id];
        delete N2SE.Survivor.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Survivor.SpawnCompanion(rec.pos, rec.angles);
    };

    N2SE.Survivor.SpawnAtMe <- function() {
        local p = null;
        try { p = Entities.FindByClassnameNearest("player", Vector(0,0,0), 99999); } catch (ex) {}
        if (p == null || !p.IsValid()) return null;

        local pos = null, ang = null;
        try { pos = p.GetOrigin() + p.GetForwardVector() * 100.0; } catch (ex) { return null; }
        try { ang = Vector(0, p.GetAngles().y, 0); } catch (ex) { ang = Vector(0, 0, 0); }

        return N2SE.Survivor.SpawnCompanion(pos, ang);
    };

    N2SE.Survivor.OnSpawn <- function(e) {
        return;
    };

    N2SE.Survivor.OnKilled <- function(p, z) {
        if (z == null) return;
        local zidx = N2SE.Survivor.Zidx(z);
        if (zidx <= 0) return;

        local wasSurvivor = (zidx in N2SE.Survivor.EntitySet) || N2SE.Survivor.IsSurvivorModel(z);

        if (wasSurvivor && z.IsValid()) {
            local deathPos = null;
            try { deathPos = z.GetOrigin(); } catch (ex) {}
            if (deathPos != null) N2SE.Survivor.TryDropLootAt(deathPos, z);
        }

        if (wasSurvivor) N2SE.Survivor.CleanupState(zidx);
    };

    N2SE.Survivor.Init <- function() {
        foreach (entry in N2SE.Survivor.Config.models) {
            try { PrecacheModel(entry.model, true); } catch (ex) {}
        }
    };
}