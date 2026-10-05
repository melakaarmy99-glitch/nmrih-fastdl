if (!("Patient" in N2SE)) {
    N2SE.Patient <- {};
    N2SE.Patient.ModKey <- "patient";

    N2SE.Patient.Config <- {
        headBodygroupName = "c_head",
        bodyBodygroupName = "body",

        pBodyIndex       = 0,
        doctorBodyIndex  = 2,
        coronerBodyIndex = 3,

        spawnClass  = "npc_nmrih_shamblerzombie",
        runnerClass = "npc_nmrih_runnerzombie",

        runnerChance         = 10,
        spawnDelay           = 3.0,
        spawnMaxAttempts     = 5,

        hpPenalty          = 150,
        hpPenaltyNightmare = 300,

        lootZOffset = 20.0,
        lootItemsCommon = [
            { classname = "item_bandages", weight = 100 }
        ],
        lootItemsDoctor = [
            { classname = "item_bandages",  weight = 60 },
            { classname = "item_pills",     weight = 20 },
            { classname = "item_first_aid", weight = 20 }
        ],

        damageReduction  = 5,
        headSplitChance  = 50,
        headSplitDelay   = 0.02,
        headRepairRounds = 12,
        headRepairStep   = 0.05
    };

    N2SE.Patient.Models <- [
        {
            path         = "models/nmr_zombie/hospital_zombie.mdl",
            match        = "hospital_zombie.mdl",
            headVariants = [0],
            headSevered  = [1, 2],
            bodyVariants = [0, 1, 2, 3]
        },
        {
            path         = "models/nmr_zombie/hospital_zombie2.mdl",
            match        = "hospital_zombie2.mdl",
            headVariants = [0, 1],
            headSevered  = [2, 3],
            bodyVariants = [0, 1, 2, 3]
        },
        {
            path         = "models/nmr_zombie/hospital_zombie3.mdl",
            match        = "hospital_zombie3.mdl",
            headVariants = [0],
            headSevered  = [1, 2],
            bodyVariants = [0, 1, 2, 3]
        }
    ];

    N2SE.Patient.EntitySet       <- {};
    N2SE.Patient.PendingSpawns   <- {};
    N2SE.Patient.PendingCounter  <- 0;
    N2SE.Patient.Generating      <- false;
    N2SE.Patient.HeadRepairToken <- "";

    N2SE.Patient.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Patient.Fire <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); return true; }
        catch (ex) { return false; }
    };

    N2SE.Patient.GetHP <- function(z) {
        if (z == null || !z.IsValid()) return 0;
        try { return z.GetHealth(); } catch (ex) {
            try { return NetProps.GetPropInt(z, "m_iHealth"); } catch (ex2) { return 0; }
        }
    };

    N2SE.Patient.SetHP <- function(z, hp) {
        if (z == null || !z.IsValid()) return;
        try { z.SetHealth(hp); return; } catch (ex) {}
        try { NetProps.SetPropInt(z, "m_iHealth", hp); } catch (ex) {}
    };

    N2SE.Patient.GetBG <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        if (name == null || name == "") return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Patient.SetBG <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        if (name == null || name == "") return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Patient.GetModelData <- function(z) {
        if (N2SE.Patient.Models == null || N2SE.Patient.Models.len() == 0) return null;
        if (z == null || !z.IsValid()) return N2SE.Patient.Models[0];
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return N2SE.Patient.Models[0]; }
        if (mn == null || mn == "") return N2SE.Patient.Models[0];
        local low = mn.tolower();
        foreach (m in N2SE.Patient.Models) {
            if (low.find(m.match.tolower()) != null) return m;
        }
        return N2SE.Patient.Models[0];
    };

    N2SE.Patient.PickModel <- function() {
        if (N2SE.Patient.Models == null || N2SE.Patient.Models.len() == 0) return null;
        return N2SE.Patient.Models[RandomInt(0, N2SE.Patient.Models.len() - 1)].path;
    };

    N2SE.Patient.IsPatientModel <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return false; }
        if (mn == null || mn == "") return false;
        local low = mn.tolower();
        foreach (m in N2SE.Patient.Models) {
            if (low.find(m.match.tolower()) != null) return true;
        }
        return false;
    };

    N2SE.Patient.Mark <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Patient.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Patient.EntitySet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsPatient <- true;
        } catch (ex) {}
    };

    N2SE.Patient.Unmark <- function(z) {
        if (z == null) return;
        local zidx = N2SE.Patient.Zidx(z);
        if (zidx <= 0) return;
        if (zidx in N2SE.Patient.EntitySet) delete N2SE.Patient.EntitySet[zidx];
    };

    N2SE.Patient.IsPatient <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Patient.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Patient.EntitySet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsPatient" in sc) && sc.IsPatient) return true;
        } catch (ex) {}
        return N2SE.Patient.IsPatientModel(z);
    };

    N2SE.Patient.IsDoctor <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (!N2SE.Patient.IsPatient(z)) return false;

        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("PatientIsDoctor" in sc)) {
                return sc.PatientIsDoctor;
            }
        } catch (ex) {}

        local bodyIdx = N2SE.Patient.GetBG(z, N2SE.Patient.Config.bodyBodygroupName);
        if (bodyIdx == N2SE.Patient.Config.doctorBodyIndex) return true;
        if (bodyIdx == N2SE.Patient.Config.coronerBodyIndex) return true;
        return false;
    };

    N2SE.Patient.IsCommonPatient <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (!N2SE.Patient.IsPatient(z)) return false;
        return !N2SE.Patient.IsDoctor(z);
    };

    N2SE.Patient.PickBG <- function(z, name, variants) {
        if (z == null || !z.IsValid()) return -1;
        if (name == null || variants == null || variants.len() == 0) return -1;

        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;

        local maxCount = 0;
        try { maxCount = z.GetBodygroupCount(bg); } catch (ex) {}

        local valid = [];
        foreach (idx in variants) {
            if (maxCount <= 0 || idx < maxCount) valid.append(idx);
        }
        if (valid.len() == 0) return -1;

        local chosen = valid[RandomInt(0, valid.len() - 1)];
        try { z.SetBodygroup(bg, chosen); return chosen; } catch (ex) { return -1; }
    };

    N2SE.Patient.RandomizeParts <- function(z) {
        if (z == null || !z.IsValid()) return -1;
        local md = N2SE.Patient.GetModelData(z);
        if (md == null) return -1;
        local cfg = N2SE.Patient.Config;
        local body = N2SE.Patient.PickBG(z, cfg.bodyBodygroupName, md.bodyVariants);
        N2SE.Patient.PickBG(z, cfg.headBodygroupName, md.headVariants);
        return body;
    };

    N2SE.Patient.ApplyHpPenalty <- function(z, bodyIdx) {
        if (z == null || !z.IsValid()) return;
        if (bodyIdx != N2SE.Patient.Config.pBodyIndex) return;
        local cur = N2SE.Patient.GetHP(z);
        if (cur <= 0) return;
        local penalty = N2SE.IsNightmare() ? N2SE.Patient.Config.hpPenaltyNightmare
                                           : N2SE.Patient.Config.hpPenalty;
        local newHp = cur - penalty;
        if (newHp < 1) newHp = 1;
        N2SE.Patient.SetHP(z, newHp);
    };

    N2SE.Patient.PickWeighted <- function(items) {
        if (items == null || items.len() == 0) return null;
        local total = 0;
        foreach (it in items) total += (("weight" in it) ? it.weight : 1);
        if (total <= 0) return items[0];
        local roll = RandomInt(1, total), cum = 0;
        foreach (it in items) {
            cum += (("weight" in it) ? it.weight : 1);
            if (roll <= cum) return it;
        }
        return items[0];
    };

    N2SE.Patient.TryDropLoot <- function(pos, z) {
        if (pos == null) return;
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Patient.IsPatient(z)) return;

        if (!N2SE.IsLootEnabled()) return;

        local chance = N2SE.GetLootChance();
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance.tointeger()) return;

        local cfg = N2SE.Patient.Config;
        local isDoctor = N2SE.Patient.IsDoctor(z);

        local pool = null;
        if (isDoctor) {
            pool = cfg.lootItemsDoctor;
            if (pool == null || pool.len() == 0) pool = cfg.lootItemsCommon;
        } else {
            pool = cfg.lootItemsCommon;
            if (pool == null || pool.len() == 0) pool = cfg.lootItemsDoctor;
        }

        local chosen = N2SE.Patient.PickWeighted(pool);
        if (chosen == null) return;

        local spawnPos = pos + Vector(0, 0, cfg.lootZOffset);
        local ent = null;
        try {
            ent = SpawnEntityFromTable(chosen.classname, {
                origin = spawnPos,
                angles = Vector(0, RandomFloat(0, 360), 0)
            });
        } catch (ex) { return; }
        if (ent == null || !ent.IsValid()) return;
        try { ent.Activate(); } catch (ex) {}
    };

    N2SE.Patient.IsHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local md = N2SE.Patient.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        local cur = N2SE.Patient.GetBG(z, N2SE.Patient.Config.headBodygroupName);
        foreach (idx in md.headSevered) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Patient.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (N2SE.Patient.IsHeadSevered(z)) return true;
        local md = N2SE.Patient.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        return N2SE.Patient.SetBG(z, N2SE.Patient.Config.headBodygroupName,
            md.headSevered[RandomInt(0, md.headSevered.len() - 1)]);
    };

    N2SE.Patient.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Patient.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Patient.IsHeadSevered(z)) {
            N2SE.Patient.ApplyHeadSevered(z);
        }
        N2SE.Patient.Fire("::N2SE.Patient.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Patient.Config.headRepairStep);
    };

    N2SE.Patient.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Patient.IsPatient(z)) return;

        N2SE.Patient.ApplyHeadSevered(z);

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) { try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) { try { EntFireByHandle(z, "Break",     "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) N2SE.SafeKill(z);

        local token = UniqueString();
        N2SE.Patient.HeadRepairToken = token;
        N2SE.Patient.RepairHead(zidx, token, N2SE.Patient.Config.headRepairRounds);
    };

    N2SE.Patient.HookZombie <- function(z) {
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Patient.IsPatient(z)) return;

        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("PatientZombieHooked" in sc)) return;
        sc.PatientZombieHooked <- true;

        local prev = ("OnTakeDamage" in sc) ? sc.OnTakeDamage : null;

        sc.OnTakeDamage <- function() {
            local z = self;
            if (z == null || !z.IsValid()) return true;

            if (!N2SE.IsModOn("patient")) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            if (!N2SE.Patient.IsPatient(z)) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
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
                    local hp = N2SE.Patient.GetHP(z);
                    if (dmg > 0 && hp > 0 && dmg >= hp
                        && !N2SE.Patient.IsHeadSevered(z)
                        && RandomInt(1, 100) <= N2SE.Patient.Config.headSplitChance) {

                        local zidx = N2SE.Patient.Zidx(z);
                        if (zidx > 0) {
                            N2SE.Patient.ApplyHeadSevered(z);
                            N2SE.Patient.Fire("::N2SE.Patient.DoHeadSplit(" + zidx + ")",
                                N2SE.Patient.Config.headSplitDelay);
                        }
                        return false;
                    }
                }
            }

            if (prev != null) {
                try { return prev(); } catch (ex) { return true; }
            }
            return true;
        };
    };

    N2SE.Patient.AttachPatient <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return false; }
        if (sc == null || ("PatientAttached" in sc)) return false;
        sc.PatientAttached <- true;

        N2SE.Patient.Mark(z);
        local bodyIdx = N2SE.Patient.RandomizeParts(z);
        N2SE.Patient.ApplyHpPenalty(z, bodyIdx);

        sc.PatientIsDoctor <- (bodyIdx == N2SE.Patient.Config.doctorBodyIndex ||
                               bodyIdx == N2SE.Patient.Config.coronerBodyIndex);
        sc.PatientBodyIdx  <- bodyIdx;
        return true;
    };

    N2SE.Patient.SpawnCompanion <- function(pos, angles) {
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Patient.Config;
        local maxAttempts = cfg.spawnMaxAttempts > 0 ? cfg.spawnMaxAttempts : 1;

        for (local attempt = 0; attempt < maxAttempts; attempt++) {
            local cls = (RandomInt(1, 100) <= cfg.runnerChance) ? cfg.runnerClass : cfg.spawnClass;

            N2SE.Patient.Generating = true;
            local z = null;
            try { z = SpawnEntityFromTable(cls, { origin = pos, angles = angles }); }
            catch (ex) { N2SE.Patient.Generating = false; continue; }
            N2SE.Patient.Generating = false;
            if (z == null || !z.IsValid()) continue;

            local zidx = N2SE.Patient.Zidx(z);
            if (zidx > 0) N2SE.Patient.EntitySet[zidx] <- true;

            try {
                z.ValidateScriptScope();
                local sc = z.GetScriptScope();
                if (sc != null) {
                    sc.PatientCompanionSpawned <- true;
                    sc.IsPatient <- true;
                }
            } catch (ex) {}

            try { DispatchSpawn(z); } catch (ex) {}
            if (!z.IsValid()) {
                if (zidx > 0 && (zidx in N2SE.Patient.EntitySet))
                    delete N2SE.Patient.EntitySet[zidx];
                continue;
            }

            local hasArmor = false;
            try { if ("HasArmor" in z) hasArmor = z.HasArmor(); } catch (ex) {}
            if (hasArmor) {
                if (zidx > 0 && (zidx in N2SE.Patient.EntitySet))
                    delete N2SE.Patient.EntitySet[zidx];
                N2SE.SafeKill(z);
                continue;
            }

            local model = N2SE.Patient.PickModel();
            if (model != null && model != "") {
                try { z.SetModelOverride(model); } catch (ex) {}
            }

            N2SE.Patient.AttachPatient(z);
            N2SE.Patient.HookZombie(z);
            return z;
        }

        return null;
    };

    N2SE.Patient.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Patient.PendingSpawns)) return;
        local rec = N2SE.Patient.PendingSpawns[id];
        delete N2SE.Patient.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Patient.SpawnCompanion(rec.pos, rec.angles);
    };

    N2SE.Patient.SpawnAtMe <- function() {
        local p = null;
        try { p = Entities.FindByClassnameNearest("player", Vector(0,0,0), 99999); } catch (ex) {}
        if (p == null || !p.IsValid()) return null;

        local pos = null, ang = null;
        try { pos = p.GetOrigin() + p.GetForwardVector() * 100.0; } catch (ex) { return null; }
        try { ang = Vector(0, p.GetAngles().y, 0); } catch (ex) { ang = Vector(0, 0, 0); }

        return N2SE.Patient.SpawnCompanion(pos, ang);
    };

    N2SE.Patient.OnSpawn <- function(e) {
        return;
    };

    N2SE.Patient.OnKilled <- function(p, z) {
        if (z == null) return;
        local zidx = N2SE.Patient.Zidx(z);
        if (zidx <= 0) return;

        local wasPatient = false;
        if (zidx in N2SE.Patient.EntitySet) wasPatient = true;
        if (!wasPatient && N2SE.Patient.IsPatient(z)) wasPatient = true;

        if (zidx in N2SE.Patient.EntitySet)     delete N2SE.Patient.EntitySet[zidx];
        if (zidx in N2SE.Patient.PendingSpawns) delete N2SE.Patient.PendingSpawns[zidx];
        if (!wasPatient) return;

        local deathPos = null;
        try { deathPos = z.GetOrigin(); } catch (ex) {}
        if (deathPos == null) return;
        if (deathPos.x == 0.0 && deathPos.y == 0.0 && deathPos.z == 0.0) return;

        N2SE.Patient.TryDropLoot(deathPos, z);
    };

    N2SE.Patient.HookPlayer <- function(p) {
        if (!N2SE.IsModOn("patient")) return;
        if (p == null || !p.IsValid()) return;
        local sc = null;
        try { p.ValidateScriptScope(); sc = p.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("PatientPlayerHooked" in sc)) return;
        sc.PatientPlayerHooked <- true;

        local prev = ("OnTakeDamage" in sc) ? sc.OnTakeDamage : null;

        sc.OnTakeDamage <- function() {
            local pl = self;
            if (pl == null || !pl.IsValid()) return true;

            if (!N2SE.IsModOn("patient")) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            local di = null;
            try { di = info; } catch (ex) {}
            if (di != null) {
                local atk = null;
                try { atk = di.GetAttacker(); } catch (ex) {}
                if (atk != null && atk.IsValid()
                    && N2SE.Patient.IsPatient(atk)
                    && !N2SE.Patient.IsDoctor(atk)) {
                    local dmg = 0;
                    try { dmg = di.GetDamage(); } catch (ex) {}
                    if (dmg > 0) {
                        local nd = dmg - N2SE.Patient.Config.damageReduction;
                        if (nd < 0) nd = 0;
                        try { di.SetDamage(nd); } catch (ex) {}
                    }
                }
            }

            if (prev != null) {
                try { return prev(); } catch (ex) { return true; }
            }
            return true;
        };
    };

    N2SE.Patient.HookAllPlayers <- function() {
        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            if (p != null && p.IsValid()) N2SE.Patient.HookPlayer(p);
        }
    };

    N2SE.Patient.OnPlayerSpawn <- function(...) {
        if (vargv.len() < 1 || vargv[0] == null) return;
        local uid = ("userid" in vargv[0]) ? vargv[0].userid : null;
        if (uid == null) return;
        local pl = null;
        try { pl = GetPlayerByUserId(uid); } catch (ex) {}
        if (pl != null && pl.IsValid()) N2SE.Patient.HookPlayer(pl);
    };

    if (!("__patient_events_registered" in getroottable())) {
        try {
            ListenToGameEvent("player_spawn", N2SE.Patient.OnPlayerSpawn, "N2SE_PatientPlayerSpawn");
        } catch (ex) {}
        getroottable().__patient_events_registered <- true;
    }

    N2SE.Patient.Init <- function() {
        foreach (m in N2SE.Patient.Models) {
            if (m == null || m.path == null) continue;
            try { PrecacheModel(m.path, true); } catch (ex) {}
        }
        N2SE.Patient.HookAllPlayers();
    };
}