if (!("Officer" in N2SE)) {
    N2SE.Officer <- {};
    N2SE.Officer.ModKey <- "officer";

    N2SE.Officer.Config <- {
        hatModel = "models/nmr_zombie/w_o_hat.mdl",

        dropZOffset       = 70.0,
        dropVelocity      = 150.0,
        dropVariance      = 30.0,
        dropVzMin         = 120.0,
        dropVzMax         = 220.0,
        dropAngularMax    = 600.0,
        hatDropSpawnflags = 4,
        hatDropLife       = 10.0,

        lootZOffset = 20.0,
        dropGroups = [
            { weight = 100, items = [
                { classname = "fa_glock17",    clip1 = 0, weight = 60 },
                { classname = "ammobox_9mm",              weight = 40 }
            ]}
        ],

        spawnClass  = "npc_nmrih_shamblerzombie",
        runnerClass = "npc_nmrih_runnerzombie",

        runnerChance         = 10,
        spawnDelay           = 3.0,
        spawnMaxAttempts     = 5,

        headSplitChance  = 30,
        headSplitDelay   = 0.02,
        headRepairRounds = 12,
        headRepairStep   = 0.05,

        hatHitSound = "physics/body/body_medium_impact_soft7.wav"
    };

    N2SE.Officer.Models <- [
        {
            path            = "models/nmr_zombie/officer_zombie.mdl",
            match           = "officer_zombie.mdl",
            headBG          = "c_head",
            bodyBG          = "body",
            hatBG           = "hat",
            headVariants    = [0],
            headSevered     = [1, 2],
            bodyVariants    = [0, 1],
            hatVariants     = [0],
            blankHatIndex   = 1,
            forcedHatByHead = null
        },
        {
            path            = "models/nmr_zombie/officer_zombie2.mdl",
            match           = "officer_zombie2.mdl",
            headBG          = "c_head",
            bodyBG          = "body",
            hatBG           = "hat",
            headVariants    = [0, 1],
            headSevered     = [2, 3],
            bodyVariants    = [0, 1],
            hatVariants     = [0],
            blankHatIndex   = 1,
            forcedHatByHead = null
        },
        {
            path            = "models/nmr_zombie/officer_zombie3.mdl",
            match           = "officer_zombie3.mdl",
            headBG          = "c_head",
            bodyBG          = "body",
            hatBG           = "hat",
            headVariants    = [0],
            headSevered     = [1, 2],
            bodyVariants    = [0, 1],
            hatVariants     = [0],
            blankHatIndex   = 1,
            forcedHatByHead = null
        }
    ];

    N2SE.Officer.EntitySet       <- {};
    N2SE.Officer.PendingSpawns   <- {};
    N2SE.Officer.PendingCounter  <- 0;
    N2SE.Officer.HeadRepairToken <- "";

    N2SE.Officer.IsEnabled <- function() {
        return N2SE.IsModOn("officer");
    };

    N2SE.Officer.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Officer.Fire <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); } catch (ex) {}
    };

    N2SE.Officer.GetHP <- function(z) {
        if (z == null || !z.IsValid()) return 0;
        try { return z.GetHealth(); } catch (ex) {
            try { return NetProps.GetPropInt(z, "m_iHealth"); } catch (ex2) { return 0; }
        }
    };

    N2SE.Officer.GetBG <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        if (name == null || name == "") return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Officer.SetBG <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        if (name == null || name == "") return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Officer.GetModelData <- function(z) {
        if (N2SE.Officer.Models == null || N2SE.Officer.Models.len() == 0) return null;
        if (z == null || !z.IsValid()) return N2SE.Officer.Models[0];
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return N2SE.Officer.Models[0]; }
        if (mn == null || mn == "") return N2SE.Officer.Models[0];
        local low = mn.tolower();
        foreach (m in N2SE.Officer.Models) {
            if (low.find(m.match.tolower()) != null) return m;
        }
        return N2SE.Officer.Models[0];
    };

    N2SE.Officer.PickModel <- function() {
        if (N2SE.Officer.Models == null || N2SE.Officer.Models.len() == 0) return null;
        return N2SE.Officer.Models[RandomInt(0, N2SE.Officer.Models.len() - 1)].path;
    };

    N2SE.Officer.IsOfficerModel <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return false; }
        if (mn == null || mn == "") return false;
        local low = mn.tolower();
        foreach (m in N2SE.Officer.Models) {
            if (low.find(m.match.tolower()) != null) return true;
        }
        return false;
    };

    N2SE.Officer.SupportsHeadSplit <- function(z) {
        local md = N2SE.Officer.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null) return false;
        return md.headSevered.len() > 0;
    };

    N2SE.Officer.Mark <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Officer.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Officer.EntitySet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsOfficer <- true;
        } catch (ex) {}
    };

    N2SE.Officer.Unmark <- function(z) {
        if (z == null) return;
        local zidx = N2SE.Officer.Zidx(z);
        if (zidx <= 0) return;
        if (zidx in N2SE.Officer.EntitySet) delete N2SE.Officer.EntitySet[zidx];
    };

    N2SE.Officer.IsOfficer <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Officer.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Officer.EntitySet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsOfficer" in sc) && sc.IsOfficer) return true;
        } catch (ex) {}
        return N2SE.Officer.IsOfficerModel(z);
    };

    N2SE.Officer.PickBG <- function(z, name, variants) {
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

    N2SE.Officer.RandomizeParts <- function(z) {
        if (z == null || !z.IsValid()) return;
        local md = N2SE.Officer.GetModelData(z);
        if (md == null) return;

        N2SE.Officer.PickBG(z, md.bodyBG, md.bodyVariants);

        local headIdx = N2SE.Officer.PickBG(z, md.headBG, md.headVariants);

        local forcedHat = null;
        if (md.forcedHatByHead != null && headIdx >= 0) {
            try {
                if (headIdx in md.forcedHatByHead) {
                    forcedHat = md.forcedHatByHead[headIdx];
                }
            } catch (ex) {}
        }

        if (forcedHat != null) {
            N2SE.Officer.SetBG(z, md.hatBG, forcedHat);
        } else {
            N2SE.Officer.PickBG(z, md.hatBG, md.hatVariants);
        }
    };

    N2SE.Officer.HasHat <- function(z) {
        local md = N2SE.Officer.GetModelData(z);
        if (md == null) return false;
        local cur = N2SE.Officer.GetBG(z, md.hatBG);
        if (cur < 0) return false;
        if (md.blankHatIndex != null && cur == md.blankHatIndex) return false;
        return true;
    };

    N2SE.Officer.IsHeadSevered <- function(z) {
        local md = N2SE.Officer.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        local cur = N2SE.Officer.GetBG(z, md.headBG);
        foreach (idx in md.headSevered) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Officer.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local md = N2SE.Officer.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        if (N2SE.Officer.IsHeadSevered(z)) return false;
        return N2SE.Officer.SetBG(z, md.headBG,
            md.headSevered[RandomInt(0, md.headSevered.len() - 1)]);
    };

    N2SE.Officer.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Officer.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Officer.IsHeadSevered(z)) {
            N2SE.Officer.ApplyHeadSevered(z);
        }
        N2SE.Officer.Fire("::N2SE.Officer.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Officer.Config.headRepairStep);
    };

    N2SE.Officer.PlayHatHitSound <- function(z) {
        if (z == null || !z.IsValid()) return;
        local s = N2SE.Officer.Config.hatHitSound;
        if (s == null || s == "") return;

        try { EmitSoundOn(s, z); return; } catch (ex) {}
        try {
            local p = null;
            try { p = z.GetOrigin() + Vector(0, 0, 65); } catch (ex) { p = z.GetOrigin(); }
            EmitSound(s, p);
        } catch (ex) {}
    };

    N2SE.Officer.ThrowPhysics <- function(ent, yaw) {
        if (ent == null || !ent.IsValid()) return;
        local c = N2SE.Officer.Config;
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

    N2SE.Officer.DropHat <- function(z, atk) {
        if (z == null || !z.IsValid()) return false;
        if (!N2SE.Officer.IsOfficer(z)) return false;

        local cfg = N2SE.Officer.Config;
        if (cfg.hatModel == null || cfg.hatModel == "") return false;

        local baseOrigin = null;
        try { baseOrigin = z.GetOrigin(); } catch (ex) { return false; }
        if (baseOrigin == null) return false;

        local yaw = 0.0;
        try { yaw = z.GetAngles().y; } catch (ex) {}

        if (atk != null && atk.IsValid()) {
            local d = null;
            try { d = z.GetOrigin() - atk.GetOrigin(); } catch (ex) {}
            if (d != null && d.Length() > 0.1) yaw = atan2(d.y, d.x) * 57.29578;
        }

        local skin = 0;
        try { skin = z.GetSkin(); } catch (ex) {}

        local color = N2SE.GetRenderColor(z);
        local angles = Vector(0, yaw, 0);

        local offsets = [ cfg.dropZOffset, cfg.dropZOffset * 0.6, 25.0, 5.0 ];

        foreach (off in offsets) {
            local origin = baseOrigin + Vector(0, 0, off);
            local dropName = "n2se_officer_hat_" + UniqueString();

            local drop = null;
            try {
                drop = SpawnEntityFromTable("prop_physics_override", {
                    model      = cfg.hatModel,
                    skin       = skin,
                    origin     = origin,
                    angles     = angles,
                    spawnflags = cfg.hatDropSpawnflags,
                    targetname = dropName
                });
            } catch (ex) { drop = null; }
            if (drop == null || !drop.IsValid()) continue;

            try { DispatchSpawn(drop); } catch (ex) {}
            if (!drop.IsValid()) continue;

            try { drop.SetSkin(skin); } catch (ex) {}

            N2SE.ApplyRenderColor(drop, color.r, color.g, color.b);
            N2SE.Officer.ThrowPhysics(drop, yaw);

            if (cfg.hatDropLife > 0) {
                try { EntFire(dropName, "Kill", "", cfg.hatDropLife, null); } catch (ex) {}
            }
            return true;
        }

        N2SE.Log("officer DropHat failed for idx=" + N2SE.Officer.Zidx(z));
        return false;
    };

    N2SE.Officer.RetryHatDrop <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Officer.IsOfficer(z)) return;
        N2SE.Officer.DropHat(z, null);
    };

    N2SE.Officer.PickWeighted <- function(items) {
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

    N2SE.Officer.PickGroupWeighted <- function(groups) {
        if (groups == null || groups.len() == 0) return null;
        local total = 0;
        foreach (g in groups) total += (("weight" in g) ? g.weight : 1);
        if (total <= 0) return groups[0];
        local roll = RandomInt(1, total);
        local cum = 0;
        foreach (g in groups) {
            cum += (("weight" in g) ? g.weight : 1);
            if (roll <= cum) return g;
        }
        return groups[0];
    };

    N2SE.Officer.TryDropLootAt <- function(pos, z) {
        if (pos == null) return;
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Officer.IsOfficer(z)) return;

        if (!N2SE.IsLootEnabled()) return;

        local chance = N2SE.GetLootChance();
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance.tointeger()) return;

        local cfg = N2SE.Officer.Config;
        local group = N2SE.Officer.PickGroupWeighted(cfg.dropGroups);
        if (group == null) return;

        local chosen = N2SE.Officer.PickWeighted(group.items);
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

        if ("clip1" in chosen) {
            try { ent.SetClip1(chosen.clip1); } catch (ex) {}
        }
        try { ent.Activate(); } catch (ex) {}
    };

    N2SE.Officer.HandleHatHit <- function(zombie, info) {
        if (zombie == null || !zombie.IsValid()) return "pass";
        if (!N2SE.Officer.IsOfficer(zombie)) return "pass";
        if (!N2SE.Officer.HasHat(zombie)) return "pass";

        local hg = 0;
        try { hg = NetProps.GetPropInt(zombie, "m_LastHitGroup"); } catch (ex) {}
        if (hg != 1 && hg != 10 && hg != 11) return "pass";

        local atk = null;
        if (info != null) {
            try { atk = info.GetAttacker(); } catch (ex) {}
        }

        local md = N2SE.Officer.GetModelData(zombie);
        if (md == null) return "pass";
        local hbg = -1;
        try { hbg = zombie.FindBodygroupByName(md.hatBG); } catch (ex) {}
        if (hbg == -1) return "pass";

        N2SE.Officer.PlayHatHitSound(zombie);

        local dropped = N2SE.Officer.DropHat(zombie, atk);

        local blankIdx = md.blankHatIndex;
        if (blankIdx == null) blankIdx = 0;
        try { zombie.SetBodygroup(hbg, blankIdx); } catch (ex) {}

        if (!dropped) {
            local zidx = N2SE.Officer.Zidx(zombie);
            if (zidx > 0) {
                N2SE.Officer.Fire("::N2SE.Officer.RetryHatDrop(" + zidx + ")", 0.05);
            }
        }

        return "pass";
    };

    N2SE.Officer.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Officer.IsOfficer(z)) return;

        if (!N2SE.Officer.SupportsHeadSplit(z)) return;

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) { try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {} }

        N2SE.Officer.ApplyHeadSevered(z);

        if (!fired) { try { EntFireByHandle(z, "Break", "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) N2SE.SafeKill(z);

        local token = UniqueString();
        N2SE.Officer.HeadRepairToken = token;
        N2SE.Officer.RepairHead(zidx, token, N2SE.Officer.Config.headRepairRounds);
    };

    N2SE.Officer.HookZombie <- function(z) {
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Officer.IsOfficer(z)) return;

        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("OfficerZombieHooked" in sc)) return;
        sc.OfficerZombieHooked <- true;

        local prev = ("OnTakeDamage" in sc) ? sc.OnTakeDamage : null;

        sc.OnTakeDamage <- function() {
            local z = self;
            if (z == null || !z.IsValid()) return true;

            if (!N2SE.Officer.IsEnabled()) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            if (!N2SE.Officer.IsOfficer(z)) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            local di = null;
            try { di = info; } catch (ex) {}

            try { N2SE.Officer.HandleHatHit(z, di); } catch (ex) {}

            if (di != null && N2SE.Officer.SupportsHeadSplit(z)) {
                local hg = 0;
                try { hg = NetProps.GetPropInt(z, "m_LastHitGroup"); } catch (ex) {}
                local isHead = (hg == 1 || hg == 10 || hg == 11);

                if (isHead) {
                    local dmg = 0;
                    try { dmg = di.GetDamage(); } catch (ex) {}
                    local hp = N2SE.Officer.GetHP(z);
                    if (dmg > 0 && hp > 0 && dmg >= hp
                        && RandomInt(1, 100) <= N2SE.Officer.Config.headSplitChance
                        && !N2SE.Officer.IsHeadSevered(z)) {

                        local zidx = N2SE.Officer.Zidx(z);
                        if (zidx > 0) {
                            N2SE.Officer.Fire("::N2SE.Officer.DoHeadSplit(" + zidx + ")",
                                N2SE.Officer.Config.headSplitDelay);
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

    N2SE.Officer.Attach <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return false; }
        if (sc == null || ("OfficerAttached" in sc)) return false;
        sc.OfficerAttached <- true;

        N2SE.Officer.Mark(z);
        N2SE.Officer.RandomizeParts(z);
        N2SE.Officer.HookZombie(z);
        return true;
    };

    N2SE.Officer.CleanupState <- function(zidx) {
        if (zidx == null || zidx <= 0) return;
        if (zidx in N2SE.Officer.EntitySet)     delete N2SE.Officer.EntitySet[zidx];
        if (zidx in N2SE.Officer.PendingSpawns) delete N2SE.Officer.PendingSpawns[zidx];
    };

    N2SE.Officer.SpawnCompanion <- function(pos, angles) {
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Officer.Config;
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

            N2SE.Officer.Mark(zombie);

            try { DispatchSpawn(zombie); } catch (ex) {}
            if (!zombie.IsValid()) { N2SE.Officer.Unmark(zombie); continue; }

            N2SE.Officer.Mark(zombie);

            local hasArmor = false;
            try { if ("HasArmor" in zombie) hasArmor = zombie.HasArmor(); } catch (ex) {}
            if (hasArmor) {
                N2SE.Officer.Unmark(zombie);
                N2SE.SafeKill(zombie);
                continue;
            }

            local model = N2SE.Officer.PickModel();
            if (model != null && model != "") {
                try { zombie.SetModelOverride(model); } catch (ex) {}
            }
            N2SE.Officer.Mark(zombie);

            N2SE.Officer.RandomizeParts(zombie);
            N2SE.Officer.HookZombie(zombie);

            return zombie;
        }

        return null;
    };

    N2SE.Officer.ScheduleCompanion <- function(pos, angles) {
        if (pos == null) return;

        N2SE.Officer.PendingCounter = N2SE.Officer.PendingCounter + 1;
        local id = N2SE.Officer.PendingCounter;
        N2SE.Officer.PendingSpawns[id] <- { pos = pos, angles = angles };
        N2SE.Officer.Fire("::N2SE.Officer.ExecuteDelayedSpawn(" + id + ")",
            N2SE.Officer.Config.spawnDelay);
    };

    N2SE.Officer.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Officer.PendingSpawns)) return;
        local rec = N2SE.Officer.PendingSpawns[id];
        delete N2SE.Officer.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Officer.SpawnCompanion(rec.pos, rec.angles);
    };

    N2SE.Officer.SpawnAtMe <- function() {
        local p = null;
        try { p = Entities.FindByClassnameNearest("player", Vector(0,0,0), 99999); } catch (ex) {}
        if (p == null || !p.IsValid()) return null;

        local pos = null, ang = null;
        try { pos = p.GetOrigin() + p.GetForwardVector() * 100.0; } catch (ex) { return null; }
        try { ang = Vector(0, p.GetAngles().y, 0); } catch (ex) { ang = Vector(0, 0, 0); }

        return N2SE.Officer.SpawnCompanion(pos, ang);
    };

    N2SE.Officer.OnSpawn <- function(e) {
        return;
    };

    N2SE.Officer.OnKilled <- function(p, z) {
        if (z == null) return;
        local zidx = N2SE.Officer.Zidx(z);
        if (zidx <= 0) return;

        local sc = null;
        try { sc = z.GetScriptScope(); } catch (ex) {}

        local isTagged = false;
        if (sc != null && ("IsOfficer" in sc) && sc.IsOfficer) isTagged = true;
        if (!isTagged && (zidx in N2SE.Officer.EntitySet)) isTagged = true;
        if (!isTagged && N2SE.Officer.IsOfficerModel(z)) isTagged = true;

        if (!isTagged) return;

        local atk = null;
        if (p != null && ("killeridx" in p)) {
            local kidx = p.killeridx;
            if (kidx != null && kidx > 0) {
                try { atk = EntIndexToHScript(kidx); } catch (ex) {}
                if (atk != null && !atk.IsValid()) atk = null;
            }
        }

        if (z.IsValid() && N2SE.Officer.HasHat(z)) {
            local dropped = N2SE.Officer.DropHat(z, atk);
            local md = N2SE.Officer.GetModelData(z);
            if (md != null) {
                local blankIdx = md.blankHatIndex;
                if (blankIdx == null) blankIdx = 0;
                N2SE.Officer.SetBG(z, md.hatBG, blankIdx);
            }
            if (!dropped && zidx > 0) {
                N2SE.Officer.Fire("::N2SE.Officer.RetryHatDrop(" + zidx + ")", 0.05);
            }
        }

        if (z.IsValid()) {
            local deathPos = null;
            try { deathPos = z.GetOrigin(); } catch (ex) {}
            if (deathPos != null) N2SE.Officer.TryDropLootAt(deathPos, z);
        }

        N2SE.Officer.CleanupState(zidx);
    };

    N2SE.Officer.Init <- function() {
        foreach (m in N2SE.Officer.Models) {
            if (m == null || m.path == null) continue;
            try { PrecacheModel(m.path, true); } catch (ex) {}
        }
        try { PrecacheModel(N2SE.Officer.Config.hatModel, true); } catch (ex) {}
        try { N2SE.PrecacheAll([N2SE.Officer.Config.hatHitSound]); } catch (ex) {}
    };
}