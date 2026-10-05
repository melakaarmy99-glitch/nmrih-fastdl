if (!("Builder" in N2SE)) {
    N2SE.Builder <- {};
    N2SE.Builder.ModKey <- "builder";

    N2SE.Builder.Config <- {
        helmetChance          = 40,
        helmetChanceNightmare = 80,
        helmetBodygroupName   = "c_helmet",
        headBodygroupName     = "c_head",
        bodyBodygroupName     = "c_body",
        blankHelmetIndex      = 1,

        helmetModel           = "models/nmr_zombie/w_c_helmet.mdl",

        spawnClass            = "npc_nmrih_shamblerzombie",
        runnerClass           = "npc_nmrih_runnerzombie",

        runnerChance          = 10,
        spawnDelay            = 3.0,
        spawnMaxAttempts      = 5,

        dropZOffset           = 60.0,
        dropVelocity          = 150.0,
        dropVariance          = 30.0,
        dropVzMin             = 120.0,
        dropVzMax             = 220.0,
        dropAngularMax        = 600.0,
        helmetDropLife        = 10.0,
        helmetDropSpawnflags  = 4,

        penetratingCalibers   = ["308", "357", "12gauge"],
        shotgunClasses        = ["fa_870", "fa_500a", "fa_superx3", "fa_sv10"],
        meleeDamageThreshold  = 360,

        lootItems             = ["me_wrench", "tool_barricade"],
        lootZOffset           = 20.0,

        headSplitChance       = 50,
        headSplitDelay        = 0.02,
        headRepairRounds      = 12,
        headRepairStep        = 0.05,

        hitSound              = "physics/metal/metal_sheet_impact_hard6.wav"
    };

    N2SE.Builder.Models <- [
        {
            path           = "models/nmr_zombie/c_zombie01.mdl",
            match          = "c_zombie01.mdl",
            headVariants   = [0],
            headSevered    = [1, 2],
            bodyVariants   = [0],
            helmetVariants = [0, 1]
        },
        {
            path           = "models/nmr_zombie/c_zombie02.mdl",
            match          = "c_zombie02.mdl",
            headVariants   = [0, 1],
            headSevered    = [2, 3],
            bodyVariants   = [0],
            helmetVariants = [0, 1]
        },
        {
            path           = "models/nmr_zombie/c_zombie03.mdl",
            match          = "c_zombie03.mdl",
            headVariants   = [0],
            headSevered    = [1, 2],
            bodyVariants   = [0],
            helmetVariants = [0, 1]
        }
    ];

    N2SE.Builder.EntitySet       <- {};
    N2SE.Builder.HelmetGoneSet   <- {};
    N2SE.Builder.PendingSpawns   <- {};
    N2SE.Builder.PendingCounter  <- 0;
    N2SE.Builder.HeadRepairToken <- "";

    N2SE.Builder.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Builder.FireCode <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); return true; }
        catch (ex) { return false; }
    };

    N2SE.Builder.GetBodygroupVal <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        if (name == null || name == "") return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Builder.SetBodygroupVal <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        if (name == null || name == "") return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Builder.GetModelData <- function(z) {
        if (N2SE.Builder.Models == null || N2SE.Builder.Models.len() == 0) return null;
        if (z == null || !z.IsValid()) return N2SE.Builder.Models[0];
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return N2SE.Builder.Models[0]; }
        if (mn == null || mn == "") return N2SE.Builder.Models[0];
        local low = mn.tolower();
        foreach (m in N2SE.Builder.Models) {
            if (low.find(m.match.tolower()) != null) return m;
        }
        return N2SE.Builder.Models[0];
    };

    N2SE.Builder.PickModel <- function() {
        if (N2SE.Builder.Models == null || N2SE.Builder.Models.len() == 0) return null;
        return N2SE.Builder.Models[RandomInt(0, N2SE.Builder.Models.len() - 1)].path;
    };

    N2SE.Builder.HasHelmetBodygroup <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(N2SE.Builder.Config.helmetBodygroupName); } catch (ex) { return false; }
        return bg != -1;
    };

    N2SE.Builder.HasHelmet <- function(z) {
        local cur = N2SE.Builder.GetBodygroupVal(z, N2SE.Builder.Config.helmetBodygroupName);
        if (cur < 0) return false;
        return cur != N2SE.Builder.Config.blankHelmetIndex;
    };

    N2SE.Builder.HideHelmet <- function(z) {
        if (z == null || !z.IsValid()) return;
        local bg = -1;
        try { bg = z.FindBodygroupByName(N2SE.Builder.Config.helmetBodygroupName); } catch (ex) { return; }
        if (bg == -1) return;
        try { z.SetBodygroup(bg, N2SE.Builder.Config.blankHelmetIndex); } catch (ex) {}
    };

    N2SE.Builder.GetHelmetChance <- function() {
        return N2SE.IsNightmare() ? N2SE.Builder.Config.helmetChanceNightmare
                                  : N2SE.Builder.Config.helmetChance;
    };

    N2SE.Builder.CheckHasArmor <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local has = false;
        try { if ("HasArmor" in z) has = z.HasArmor(); } catch (ex) {}
        return has;
    };

    N2SE.Builder.IsBuilderModel <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return false; }
        if (mn == null || mn == "") return false;
        local low = mn.tolower();
        foreach (m in N2SE.Builder.Models) {
            if (low.find(m.match.tolower()) != null) return true;
        }
        return false;
    };

    N2SE.Builder.MarkBuilder <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Builder.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Builder.EntitySet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsBuilder <- true;
        } catch (ex) {}
    };

    N2SE.Builder.Unmark <- function(z) {
        if (z == null) return;
        local zidx = N2SE.Builder.Zidx(z);
        if (zidx <= 0) return;
        if (zidx in N2SE.Builder.EntitySet) delete N2SE.Builder.EntitySet[zidx];
    };

    N2SE.Builder.IsBuilder <- function(z) {
        if (z == null || !z.IsValid()) return false;

        local zidx = N2SE.Builder.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Builder.EntitySet)) return true;

        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsBuilder" in sc) && sc.IsBuilder) return true;
        } catch (ex) {}

        return N2SE.Builder.IsBuilderModel(z);
    };

    N2SE.Builder.PlayHitSound <- function(ent) {
        if (ent == null || !ent.IsValid()) return;
        local s = N2SE.Builder.Config.hitSound;
        try { EmitSoundOn(s, ent); return; } catch (ex) {}
        try { EmitSound(s, ent.GetOrigin() + Vector(0, 0, 40)); } catch (ex) {}
    };

    N2SE.Builder.ThrowPhysics <- function(ent, yaw) {
        if (ent == null || !ent.IsValid()) return;
        local c = N2SE.Builder.Config;
        local rad = yaw * 0.017453292519943295;
        local vx = cos(rad) * c.dropVelocity + RandomFloat(-c.dropVariance, c.dropVariance);
        local vy = sin(rad) * c.dropVelocity + RandomFloat(-c.dropVariance, c.dropVariance);
        local vz = RandomFloat(c.dropVzMin, c.dropVzMax);
        try { ent.SetAbsVelocity(Vector(vx, vy, vz)); }
        catch (ex) { try { ent.SetVelocity(Vector(vx, vy, vz)); } catch (ex) {} }

        local am = c.dropAngularMax;
        local av = Vector(RandomFloat(-am, am), RandomFloat(-am, am), RandomFloat(-am, am));
        try { ent.SetLocalAngularVelocity(av); }
        catch (ex) { try { ent.SetAngularVelocity(av); } catch (ex) {} }
    };

    N2SE.Builder.DropHelmet <- function(z, atk) {
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Builder.IsBuilder(z)) return;

        local cfg = N2SE.Builder.Config;

        local origin = null;
        try { origin = z.GetOrigin() + Vector(0, 0, cfg.dropZOffset); } catch (ex) { return; }

        local yaw = 0.0;
        try { yaw = z.GetAngles().y; } catch (ex) {}

        if (atk != null && atk.IsValid()) {
            local d = null;
            try { d = z.GetOrigin() - atk.GetOrigin(); } catch (ex) {}
            if (d != null && d.Length() > 0.1) yaw = atan2(d.y, d.x) * 57.29578;
        }

        local color = N2SE.GetRenderColor(z);

        local dropName = "n2se_builder_helmet_" + UniqueString();

        local drop = null;
        try {
            drop = SpawnEntityFromTable("prop_physics_override", {
                model      = cfg.helmetModel,
                origin     = origin,
                angles     = Vector(0, yaw, 0),
                spawnflags = cfg.helmetDropSpawnflags,
                targetname = dropName
            });
        } catch (ex) { return; }
        if (drop == null || !drop.IsValid()) return;

        try { DispatchSpawn(drop); } catch (ex) {}
        if (!drop.IsValid()) return;

        N2SE.ApplyRenderColor(drop, color.r, color.g, color.b);
        N2SE.Builder.ThrowPhysics(drop, yaw);

        if (cfg.helmetDropLife > 0) {
            try { EntFire(dropName, "Kill", "", cfg.helmetDropLife, null); } catch (ex) {}
        }
    };

    N2SE.Builder.TryDropLootAt <- function(pos, z) {
        if (pos == null) return;
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Builder.IsBuilder(z)) return;

        if (!N2SE.IsLootEnabled()) return;

        local chance = N2SE.GetLootChance();
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance.tointeger()) return;

        local cfg = N2SE.Builder.Config;
        local items = cfg.lootItems;
        if (items == null || items.len() == 0) return;

        local chosen = items[RandomInt(0, items.len() - 1)];
        if (chosen == null || chosen == "") return;

        local spawnPos = pos + Vector(0, 0, cfg.lootZOffset);

        local ent = null;
        try {
            ent = SpawnEntityFromTable(chosen, {
                origin = spawnPos,
                angles = Vector(0, RandomFloat(0, 360), 0)
            });
        } catch (ex) { return; }
        if (ent == null || !ent.IsValid()) return;

        try { ent.Activate(); } catch (ex) {}
    };

    N2SE.Builder.IsPenetratingCaliber <- function(cal) {
        if (cal == null) return false;
        foreach (c in N2SE.Builder.Config.penetratingCalibers) {
            if (cal == c) return true;
        }
        return false;
    };

    N2SE.Builder.IsShotgunClass <- function(wc) {
        if (wc == null) return false;
        foreach (c in N2SE.Builder.Config.shotgunClasses) {
            if (wc == c) return true;
        }
        return false;
    };

    N2SE.Builder.IsHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local md = N2SE.Builder.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        local cur = N2SE.Builder.GetBodygroupVal(z, N2SE.Builder.Config.headBodygroupName);
        foreach (idx in md.headSevered) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Builder.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (N2SE.Builder.IsHeadSevered(z)) return true;
        local md = N2SE.Builder.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        return N2SE.Builder.SetBodygroupVal(z, N2SE.Builder.Config.headBodygroupName,
            md.headSevered[RandomInt(0, md.headSevered.len() - 1)]);
    };

    N2SE.Builder.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Builder.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Builder.IsHeadSevered(z)) {
            N2SE.Builder.ApplyHeadSevered(z);
        }
        N2SE.Builder.FireCode("::N2SE.Builder.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Builder.Config.headRepairStep);
    };

    N2SE.Builder.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Builder.IsBuilder(z)) return;

        N2SE.Builder.ApplyHeadSevered(z);

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) { try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) { try { EntFireByHandle(z, "Break",     "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) N2SE.SafeKill(z);

        local token = UniqueString();
        N2SE.Builder.HeadRepairToken = token;
        N2SE.Builder.RepairHead(zidx, token, N2SE.Builder.Config.headRepairRounds);
    };

    N2SE.Builder.HandleHelmetHit <- function(zombie, info) {
        if (zombie == null || !zombie.IsValid()) return "pass";
        if (!N2SE.Builder.IsBuilder(zombie)) return "pass";
        if (!N2SE.Builder.HasHelmet(zombie)) return "pass";

        local hg = 0;
        try { hg = NetProps.GetPropInt(zombie, "m_LastHitGroup"); } catch (ex) {}
        if (hg != 1 && hg != 10 && hg != 11) return "pass";

        local zidx0 = N2SE.Builder.Zidx(zombie);
        if (zidx0 > 0 && (zidx0 in N2SE.Builder.HelmetGoneSet)) return "pass";

        local atk = null;
        local wc = "";
        local cal = null;
        local dmg = 0;

        if (info != null) {
            try { atk = info.GetAttacker(); } catch (ex) {}
            local wpn = null;
            try { wpn = info.GetWeapon(); } catch (ex) {}
            if (wpn == null || !wpn.IsValid()) { try { wpn = info.GetInflictor(); } catch (ex) {} }
            if (wpn != null && wpn.IsValid()) { try { wc = wpn.GetClassname(); } catch (ex) {} }
            try { dmg = info.GetDamage(); } catch (ex) {}
        }

        if (wc == "" && atk != null && atk.IsValid()) {
            try {
                local w = atk.GetActiveWeapon();
                if (w != null && w.IsValid()) wc = w.GetClassname();
            } catch (ex) {}
        }

        if (wc.find("fa_") == 0) { try { cal = N2SE.cal(wc); } catch (ex) {} }

        local hbg = -1;
        try { hbg = zombie.FindBodygroupByName(N2SE.Builder.Config.helmetBodygroupName); } catch (ex) {}
        if (hbg == -1) return "pass";

        N2SE.PlayImpact(zombie);
        N2SE.Builder.PlayHitSound(zombie);

        zombie.SetBodygroup(hbg, N2SE.Builder.Config.blankHelmetIndex);
        N2SE.Builder.DropHelmet(zombie, atk);

        if (zidx0 > 0) N2SE.Builder.HelmetGoneSet[zidx0] <- true;

        local penetrate = false;

        if (wc.find("fa_") == 0) {
            if (N2SE.Builder.IsPenetratingCaliber(cal) || N2SE.Builder.IsShotgunClass(wc)) {
                penetrate = true;
            }
        }

        if (wc.find("me_") == 0 && dmg > N2SE.Builder.Config.meleeDamageThreshold) {
            penetrate = true;
        }

        if (wc == "") penetrate = true;

        return penetrate ? "pass" : "absorb";
    };

    N2SE.Builder.HookZombie <- function(zombie) {
        if (zombie == null || !zombie.IsValid()) return;
        if (!N2SE.Builder.IsBuilder(zombie)) return;

        local sc = null;
        try { zombie.ValidateScriptScope(); sc = zombie.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("BuilderZombieHooked" in sc)) return;
        sc.BuilderZombieHooked <- true;

        local prev = null;
        if ("OnTakeDamage" in sc) prev = sc.OnTakeDamage;

        sc.OnTakeDamage <- function() {
            local zombie = self;
            if (zombie == null || !zombie.IsValid()) return true;

            if (!N2SE.IsModOn("builder")) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            if (!N2SE.Builder.IsBuilder(zombie)) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            local di = null;
            try { di = info; } catch (ex) {}

            local helmetResult = "pass";
            try { helmetResult = N2SE.Builder.HandleHelmetHit(zombie, di); } catch (ex) {}
            if (helmetResult == "absorb") return false;

            if (di != null && !N2SE.Builder.HasHelmet(zombie)) {
                local hg = 0;
                try { hg = NetProps.GetPropInt(zombie, "m_LastHitGroup"); } catch (ex) {}
                local isHead = (hg == 1 || hg == 10 || hg == 11);

                if (isHead) {
                    local dmg = 0;
                    try { dmg = di.GetDamage(); } catch (ex) {}
                    local hp = 0;
                    try { hp = zombie.GetHealth(); } catch (ex) {}
                    if (dmg > 0 && hp > 0 && dmg >= hp
                        && RandomInt(1, 100) <= N2SE.Builder.Config.headSplitChance
                        && !N2SE.Builder.IsHeadSevered(zombie)) {

                        local zidx = N2SE.Builder.Zidx(zombie);
                        if (zidx > 0) {
                            N2SE.Builder.ApplyHeadSevered(zombie);
                            N2SE.Builder.FireCode("::N2SE.Builder.DoHeadSplit(" + zidx + ")",
                                N2SE.Builder.Config.headSplitDelay);
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

    N2SE.Builder.PickFromVariants <- function(zombie, name, variants) {
        if (zombie == null || !zombie.IsValid()) return false;
        if (name == null || variants == null || variants.len() == 0) return false;

        local bg = -1;
        try { bg = zombie.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;

        local maxCount = 0;
        try { maxCount = zombie.GetBodygroupCount(bg); } catch (ex) { maxCount = 0; }

        local valid = [];
        foreach (idx in variants) {
            if (maxCount <= 0 || idx < maxCount) valid.append(idx);
        }
        if (valid.len() == 0) return false;

        local chosen = valid[RandomInt(0, valid.len() - 1)];
        try { zombie.SetBodygroup(bg, chosen); } catch (ex) { return false; }
        return true;
    };

    N2SE.Builder.RandomizeBody <- function(zombie) {
        local md = N2SE.Builder.GetModelData(zombie);
        if (md == null) return false;
        return N2SE.Builder.PickFromVariants(zombie,
            N2SE.Builder.Config.bodyBodygroupName,
            md.bodyVariants);
    };

    N2SE.Builder.RandomizeHead <- function(zombie) {
        local md = N2SE.Builder.GetModelData(zombie);
        if (md == null) return false;
        return N2SE.Builder.PickFromVariants(zombie,
            N2SE.Builder.Config.headBodygroupName,
            md.headVariants);
    };

    N2SE.Builder.RandomizeHelmet <- function(zombie) {
        if (zombie == null || !zombie.IsValid()) return false;
        local bg = -1;
        try { bg = zombie.FindBodygroupByName(N2SE.Builder.Config.helmetBodygroupName); } catch (ex) { return false; }
        if (bg == -1) return false;

        if (RandomInt(1, 100) > N2SE.Builder.GetHelmetChance()) {
            N2SE.Builder.HideHelmet(zombie);
            return false;
        }
        try { zombie.SetBodygroup(bg, 0); } catch (ex) {}
        return true;
    };

    N2SE.Builder.PickBuilderClass <- function() {
        local cfg = N2SE.Builder.Config;
        if (cfg.runnerChance > 0 && RandomInt(1, 100) <= cfg.runnerChance) {
            return cfg.runnerClass;
        }
        return cfg.spawnClass;
    };

    N2SE.Builder.AttachBuilder <- function(zombie) {
        if (zombie == null || !zombie.IsValid()) return false;

        local sc = null;
        try { zombie.ValidateScriptScope(); sc = zombie.GetScriptScope(); } catch (ex) { return false; }
        if (sc == null) return false;
        if ("BuilderAttached" in sc) return false;
        sc.BuilderAttached <- true;

        N2SE.Builder.MarkBuilder(zombie);
        N2SE.Builder.HookZombie(zombie);
        N2SE.Builder.RandomizeBody(zombie);
        N2SE.Builder.RandomizeHead(zombie);
        N2SE.Builder.RandomizeHelmet(zombie);
        return true;
    };

    N2SE.Builder.SpawnCompanion <- function(pos, angles) {
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Builder.Config;
        local maxAttempts = cfg.spawnMaxAttempts;
        if (maxAttempts < 1) maxAttempts = 1;

        for (local attempt = 0; attempt < maxAttempts; attempt++) {
            local cls = N2SE.Builder.PickBuilderClass();

            local zombie = null;
            try {
                zombie = SpawnEntityFromTable(cls, { origin = pos, angles = angles });
            } catch (ex) { continue; }
            if (zombie == null || !zombie.IsValid()) continue;

            local zidx = N2SE.Builder.Zidx(zombie);
            if (zidx > 0) N2SE.Builder.EntitySet[zidx] <- true;

            try { DispatchSpawn(zombie); } catch (ex) {}
            if (!zombie.IsValid()) {
                if (zidx > 0 && (zidx in N2SE.Builder.EntitySet))
                    delete N2SE.Builder.EntitySet[zidx];
                continue;
            }

            if (N2SE.Builder.CheckHasArmor(zombie)) {
                if (zidx > 0 && (zidx in N2SE.Builder.EntitySet))
                    delete N2SE.Builder.EntitySet[zidx];
                N2SE.SafeKill(zombie);
                continue;
            }

            local model = N2SE.Builder.PickModel();
            if (model != null && model != "") {
                try { zombie.SetModelOverride(model); } catch (ex) {}
            }

            if (zidx > 0) N2SE.Builder.EntitySet[zidx] <- true;

            N2SE.Builder.AttachBuilder(zombie);
            return zombie;
        }

        return null;
    };

    N2SE.Builder.ScheduleCompanion <- function(pos, angles) {
        if (pos == null) return;

        N2SE.Builder.PendingCounter = N2SE.Builder.PendingCounter + 1;
        local id = N2SE.Builder.PendingCounter;
        N2SE.Builder.PendingSpawns[id] <- { pos = pos, angles = angles };
        N2SE.Builder.FireCode("::N2SE.Builder.ExecuteDelayedSpawn(" + id + ")",
            N2SE.Builder.Config.spawnDelay);
    };

    N2SE.Builder.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Builder.PendingSpawns)) return;
        local rec = N2SE.Builder.PendingSpawns[id];
        delete N2SE.Builder.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Builder.SpawnCompanion(rec.pos, rec.angles);
    };

    N2SE.Builder.OnSpawn <- function(e) {
        if (!N2SE.IsModOn("builder")) return;
        if (e == null || !e.IsValid()) return;

        local sc = null;
        try { e.ValidateScriptScope(); sc = e.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;

        local zidx = N2SE.Builder.Zidx(e);
        if (zidx > 0 && (zidx in N2SE.Builder.EntitySet)) return;
        if ("IsBuilder" in sc && sc.IsBuilder) return;

        if (N2SE.Builder.IsBuilderModel(e)) {
            N2SE.Builder.AttachBuilder(e);
        }
    };

    N2SE.Builder.OnKilled <- function(p, z) {
        if (z == null) return;
        local zidx = N2SE.Builder.Zidx(z);
        if (zidx <= 0) return;

        local wasBuilder = N2SE.Builder.IsBuilder(z);
        if (!wasBuilder) return;

        if (zidx in N2SE.Builder.EntitySet)     delete N2SE.Builder.EntitySet[zidx];
        if (zidx in N2SE.Builder.HelmetGoneSet) delete N2SE.Builder.HelmetGoneSet[zidx];

        local deathPos = null;
        try { deathPos = z.GetOrigin(); } catch (ex) {}
        if (deathPos == null) return;
        if (deathPos.x == 0.0 && deathPos.y == 0.0 && deathPos.z == 0.0) return;

        N2SE.Builder.TryDropLootAt(deathPos, z);
    };

    N2SE.Builder.OnShoved <- function(p, z) {
        if (!N2SE.IsModOn("builder")) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Builder.IsBuilder(z)) return;
        if (!N2SE.Builder.HasHelmet(z)) return;
        N2SE.Builder.HandleHelmetHit(z, null);
    };

    N2SE.Builder.Init <- function() {
        foreach (m in N2SE.Builder.Models) {
            if (m == null || m.path == null) continue;
            try { PrecacheModel(m.path, true); } catch (ex) {}
        }
        try { PrecacheModel(N2SE.Builder.Config.helmetModel, true); } catch (ex) {}
        try { N2SE.PrecacheAll([N2SE.Builder.Config.hitSound]); } catch (ex) {}
    };
}