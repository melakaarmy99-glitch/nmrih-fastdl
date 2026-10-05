if (!("Fireman" in N2SE)) {
    N2SE.Fireman <- {};
    N2SE.Fireman.ModKey <- "fireman";

    N2SE.Fireman.Config <- {
        headBodygroupName   = "f_head",
        bodyBodygroupName   = "Body",
        helmetBodygroupName = "helmet",

        tankBodyIndex   = 0,
        noTankBodyIndex = 1,
        tankHitGroup    = 8,
        blankHelmetIndex = 2,

        tankExplosionDamage = 1500,
        tankExplosionRadius = 128,
        tankExplosionSound  = "weapons/explode3.wav",

        tankLeakSound = "explosivegasleak.wav",
        tankLeakDelay = 2.0,

        spawnClass  = "npc_nmrih_shamblerzombie",
        runnerClass = "npc_nmrih_runnerzombie",

        runnerChance         = 10,
        spawnDelay           = 3.0,
        spawnMaxAttempts     = 5,

        headSplitChance  = 50,
        headSplitDelay   = 0.02,
        headRepairRounds = 12,
        headRepairStep   = 0.05,

        helmetModel        = "models/nmr_zombie/w_f_helmet.mdl",
        helmetModelGoggles = "models/nmr_zombie/w_f_helmet_goggles.mdl",

        dropZOffset          = 70.0,
        dropVelocity         = 150.0,
        dropVariance         = 30.0,
        dropVzMin            = 120.0,
        dropVzMax            = 220.0,
        dropAngularMax       = 600.0,
        helmetDropSpawnflags = 4,
        helmetDropLife       = 10.0,

        helmetPenetratingCalibers = ["308"],
        helmetBreakingCalibers    = ["357"],

        shotgunClasses    = ["fa_870", "fa_500a", "fa_superx3", "fa_sv10"],
        helmetShotgunHits = 3,

        helmetHitsLowCaliber = 2,
        helmetHitsDefault    = 1,

        helmetMeleeHigh = 1,
        helmetMeleeMid  = 2,
        helmetMeleeLow  = 4,

        meleeHighThreshold = 350,
        meleeMidThreshold  = 200,

        hitSound = "physics/metal/metal_sheet_impact_hard6.wav",

        fireImmune   = true,
        DMG_BURN     = 8,
        DMG_SLOWBURN = 2097152,

        lootItem    = "me_axe_fire",
        lootZOffset = 20.0,

        impactParticle = "impact_metal_extras_2",
        impactSounds   = [
            "physics/metal/metal_solid_impact_bullet1.wav",
            "physics/metal/metal_solid_impact_bullet2.wav",
            "physics/metal/metal_solid_impact_bullet3.wav",
            "physics/metal/metal_solid_impact_bullet4.wav",
            "physics/metal/metal_solid_impact_bullet5.wav"
        ]
    };

    N2SE.Fireman.Models <- [
        {
            path           = "models/nmr_zombie/fireman_zombie.mdl",
            match          = "fireman_zombie.mdl",
            headVariants   = [0],
            headSevered    = [1, 2],
            bodyVariants   = [0, 1],
            helmetVariants = [0, 1, 2]
        },
        {
            path           = "models/nmr_zombie/fireman_zombie2.mdl",
            match          = "fireman_zombie2.mdl",
            headVariants   = [0, 1],
            headSevered    = [2, 3],
            bodyVariants   = [0, 1],
            helmetVariants = [0, 1, 2]
        },
        {
            path           = "models/nmr_zombie/fireman_zombie3.mdl",
            match          = "fireman_zombie3.mdl",
            headVariants   = [0],
            headSevered    = [1, 2],
            bodyVariants   = [0, 1],
            helmetVariants = [0, 1, 2]
        }
    ];

    N2SE.Fireman.EntitySet              <- {};
    N2SE.Fireman.PendingSpawns          <- {};
    N2SE.Fireman.PendingCounter         <- 0;
    N2SE.Fireman.HeadRepairToken        <- "";
    N2SE.Fireman.PendingTankExplosions  <- {};

    N2SE.Fireman.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Fireman.Fire <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); return true; }
        catch (ex) { return false; }
    };

    N2SE.Fireman.GetHP <- function(z) {
        if (z == null || !z.IsValid()) return 0;
        try { return z.GetHealth(); } catch (ex) {
            try { return NetProps.GetPropInt(z, "m_iHealth"); } catch (ex2) { return 0; }
        }
    };

    N2SE.Fireman.GetBG <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        if (name == null || name == "") return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Fireman.SetBG <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        if (name == null || name == "") return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Fireman.GetModelData <- function(z) {
        if (N2SE.Fireman.Models == null || N2SE.Fireman.Models.len() == 0) return null;
        if (z == null || !z.IsValid()) return N2SE.Fireman.Models[0];
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return N2SE.Fireman.Models[0]; }
        if (mn == null || mn == "") return N2SE.Fireman.Models[0];
        local low = mn.tolower();
        foreach (m in N2SE.Fireman.Models) {
            if (low.find(m.match.tolower()) != null) return m;
        }
        return N2SE.Fireman.Models[0];
    };

    N2SE.Fireman.PickModel <- function() {
        if (N2SE.Fireman.Models == null || N2SE.Fireman.Models.len() == 0) return null;
        return N2SE.Fireman.Models[RandomInt(0, N2SE.Fireman.Models.len() - 1)].path;
    };

    N2SE.Fireman.IsFiremanModel <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local mn = "";
        try { mn = z.GetModelName(); } catch (ex) { return false; }
        if (mn == null || mn == "") return false;
        local low = mn.tolower();
        foreach (m in N2SE.Fireman.Models) {
            if (low.find(m.match.tolower()) != null) return true;
        }
        return false;
    };

    N2SE.Fireman.PlayImpact <- function(e) {
        if (e == null || !e.IsValid()) return;
        local cfg = N2SE.Fireman.Config;
        local p = e.GetOrigin() + Vector(0, 0, 65);
        local s = cfg.impactSounds[RandomInt(0, cfg.impactSounds.len() - 1)];
        try { EmitSoundOn(s, e); } catch (ex) { try { EmitSound(s, p); } catch (ex2) {} }
        try { DispatchParticleEffect(cfg.impactParticle, p, Vector(0, 0, 0)); } catch (ex) {}
    };

    N2SE.Fireman.PlayHitSound <- function(ent) {
        if (ent == null || !ent.IsValid()) return;
        local s = N2SE.Fireman.Config.hitSound;
        try { EmitSoundOn(s, ent); return; } catch (ex) {}
        try { EmitSound(s, ent.GetOrigin() + Vector(0, 0, 40)); } catch (ex) {}
    };

    N2SE.Fireman.PlaySoundAt <- function(snd, pos) {
        if (snd == null || pos == null) return;

        local carrier = null;
        try { carrier = Entities.CreateByClassname("info_target"); } catch (ex) {}
        if (carrier != null) {
            try { carrier.SetOrigin(pos); } catch (ex) {}
            try { DispatchSpawn(carrier); } catch (ex) {}

            local ok = false;
            try { EmitSoundOn(snd, carrier); ok = true; } catch (ex) {}
            if (!ok) {
                try { EmitSound(snd, pos); } catch (ex) {}
            }

            try { EntFireByHandle(carrier, "Kill", "", 3.0, null, null); } catch (ex) {}
            return;
        }

        try { EmitSound(snd, pos); } catch (ex) {}
    };

    N2SE.Fireman.IsShotgunClass <- function(wc) {
        if (wc == null) return false;
        foreach (c in N2SE.Fireman.Config.shotgunClasses) {
            if (wc == c) return true;
        }
        return false;
    };

    N2SE.Fireman.Mark <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Fireman.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Fireman.EntitySet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsFireman <- true;
        } catch (ex) {}
    };

    N2SE.Fireman.Unmark <- function(z) {
        if (z == null) return;
        local zidx = N2SE.Fireman.Zidx(z);
        if (zidx <= 0) return;
        if (zidx in N2SE.Fireman.EntitySet) delete N2SE.Fireman.EntitySet[zidx];
    };

    N2SE.Fireman.IsFireman <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Fireman.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Fireman.EntitySet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsFireman" in sc) && sc.IsFireman) return true;
        } catch (ex) {}
        return N2SE.Fireman.IsFiremanModel(z);
    };

    N2SE.Fireman.PickBG <- function(z, name, variants) {
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

    N2SE.Fireman.RandomizeParts <- function(z) {
        if (z == null || !z.IsValid()) return;
        local md = N2SE.Fireman.GetModelData(z);
        if (md == null) return;
        local cfg = N2SE.Fireman.Config;
        N2SE.Fireman.PickBG(z, cfg.bodyBodygroupName,   md.bodyVariants);
        N2SE.Fireman.PickBG(z, cfg.headBodygroupName,   md.headVariants);
        N2SE.Fireman.PickBG(z, cfg.helmetBodygroupName, md.helmetVariants);
    };

    N2SE.Fireman.HasHelmet <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local cfg = N2SE.Fireman.Config;
        local cur = N2SE.Fireman.GetBG(z, cfg.helmetBodygroupName);
        if (cur < 0) return false;
        return cur != cfg.blankHelmetIndex;
    };

    N2SE.Fireman.GetHelmetDropModel <- function(z) {
        if (z == null || !z.IsValid()) return N2SE.Fireman.Config.helmetModel;
        local cfg = N2SE.Fireman.Config;
        local cur = N2SE.Fireman.GetBG(z, cfg.helmetBodygroupName);
        if (cur == 1) return cfg.helmetModelGoggles;
        return cfg.helmetModel;
    };

    N2SE.Fireman.IsHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local md = N2SE.Fireman.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        local cfg = N2SE.Fireman.Config;
        local cur = N2SE.Fireman.GetBG(z, cfg.headBodygroupName);
        foreach (idx in md.headSevered) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Fireman.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (N2SE.Fireman.IsHeadSevered(z)) return false;
        local md = N2SE.Fireman.GetModelData(z);
        if (md == null) return false;
        if (md.headSevered == null || md.headSevered.len() == 0) return false;
        local cfg = N2SE.Fireman.Config;
        return N2SE.Fireman.SetBG(z, cfg.headBodygroupName,
            md.headSevered[RandomInt(0, md.headSevered.len() - 1)]);
    };

    N2SE.Fireman.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Fireman.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Fireman.IsHeadSevered(z)) {
            N2SE.Fireman.ApplyHeadSevered(z);
        }
        N2SE.Fireman.Fire("::N2SE.Fireman.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Fireman.Config.headRepairStep);
    };

    N2SE.Fireman.ThrowPhysics <- function(ent, yaw) {
        if (ent == null || !ent.IsValid()) return;
        local c = N2SE.Fireman.Config;
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

    N2SE.Fireman.DropHelmet <- function(z, atk, modelOverride) {
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Fireman.IsFireman(z)) return;

        local cfg = N2SE.Fireman.Config;

        local model = modelOverride;
        if (model == null || model == "") {
            model = N2SE.Fireman.GetHelmetDropModel(z);
        }
        if (model == null || model == "") return;

        local origin = null;
        try { origin = z.GetOrigin() + Vector(0, 0, cfg.dropZOffset); } catch (ex) { return; }

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

        local dropName = "n2se_fireman_helmet_" + UniqueString();

        local drop = null;
        try {
            drop = SpawnEntityFromTable("prop_physics_override", {
                model      = model,
                skin       = skin,
                origin     = origin,
                angles     = Vector(0, yaw, 0),
                spawnflags = cfg.helmetDropSpawnflags,
                targetname = dropName
            });
        } catch (ex) { return; }
        if (drop == null || !drop.IsValid()) return;

        try { DispatchSpawn(drop); } catch (ex) {}
        if (!drop.IsValid()) return;

        try { drop.SetSkin(skin); } catch (ex) {}

        N2SE.ApplyRenderColor(drop, color.r, color.g, color.b);
        N2SE.Fireman.ThrowPhysics(drop, yaw);

        if (cfg.helmetDropLife > 0) {
            try { EntFire(dropName, "Kill", "", cfg.helmetDropLife, null); } catch (ex) {}
        }
    };

    N2SE.Fireman.IsFullPenetratingCaliber <- function(cal) {
        if (cal == null) return false;
        foreach (c in N2SE.Fireman.Config.helmetPenetratingCalibers) {
            if (cal == c) return true;
        }
        return false;
    };

    N2SE.Fireman.IsBreakingCaliber <- function(cal) {
        if (cal == null) return false;
        foreach (c in N2SE.Fireman.Config.helmetBreakingCalibers) {
            if (cal == c) return true;
        }
        return false;
    };

    N2SE.Fireman.GetHelmetHitsRequired <- function(wc, cal, dmg) {
        local cfg = N2SE.Fireman.Config;
        if (wc == null) return 3;
        if (wc.find("fa_") == 0) {
            if (cal == "9mm" || cal == "22lr") return cfg.helmetHitsLowCaliber;
            return cfg.helmetHitsDefault;
        }
        if (dmg >= cfg.meleeHighThreshold) return cfg.helmetMeleeHigh;
        if (dmg >= cfg.meleeMidThreshold)  return cfg.helmetMeleeMid;
        return cfg.helmetMeleeLow;
    };

    N2SE.Fireman.HandleHelmetHit <- function(zombie, info) {
        if (zombie == null || !zombie.IsValid()) return "pass";
        if (!N2SE.Fireman.IsFireman(zombie)) return "pass";
        if (!N2SE.Fireman.HasHelmet(zombie)) return "pass";

        local hg = 0;
        try { hg = NetProps.GetPropInt(zombie, "m_LastHitGroup"); } catch (ex) {}
        if (hg != 1 && hg != 10 && hg != 11) return "pass";

        local atk = null, wc = "", cal = null, dmg = 0;
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
        try { hbg = zombie.FindBodygroupByName(N2SE.Fireman.Config.helmetBodygroupName); } catch (ex) {}
        if (hbg == -1) return "pass";

        N2SE.Fireman.PlayImpact(zombie);
        N2SE.Fireman.PlayHitSound(zombie);

        local dropModel = N2SE.Fireman.GetHelmetDropModel(zombie);
        local isFirearm = (wc.find("fa_") == 0);

        if (isFirearm && N2SE.Fireman.IsFullPenetratingCaliber(cal)) {
            zombie.SetBodygroup(hbg, N2SE.Fireman.Config.blankHelmetIndex);
            N2SE.Fireman.DropHelmet(zombie, atk, dropModel);
            try {
                local sc = zombie.GetScriptScope();
                if (sc != null && ("FiremanHelmetHits" in sc)) sc.FiremanHelmetHits = 0;
            } catch (ex) {}
            return "pass";
        }

        if (isFirearm && N2SE.Fireman.IsBreakingCaliber(cal)) {
            zombie.SetBodygroup(hbg, N2SE.Fireman.Config.blankHelmetIndex);
            N2SE.Fireman.DropHelmet(zombie, atk, dropModel);
            try {
                local sc = zombie.GetScriptScope();
                if (sc != null && ("FiremanHelmetHits" in sc)) sc.FiremanHelmetHits = 0;
            } catch (ex) {}
            return "absorb";
        }

        if (isFirearm && N2SE.Fireman.IsShotgunClass(wc)) {
            local sc = null;
            try { zombie.ValidateScriptScope(); sc = zombie.GetScriptScope(); } catch (ex) { return "absorb"; }
            if (sc == null) return "absorb";
            if (!("FiremanHelmetHits" in sc)) sc.FiremanHelmetHits <- 0;
            sc.FiremanHelmetHits = sc.FiremanHelmetHits + 1;

            if (sc.FiremanHelmetHits >= N2SE.Fireman.Config.helmetShotgunHits) {
                zombie.SetBodygroup(hbg, N2SE.Fireman.Config.blankHelmetIndex);
                N2SE.Fireman.DropHelmet(zombie, atk, dropModel);
                sc.FiremanHelmetHits = 0;
            }
            return "absorb";
        }

        local sc2 = null;
        try { zombie.ValidateScriptScope(); sc2 = zombie.GetScriptScope(); } catch (ex) { return "pass"; }
        if (sc2 == null) return "pass";
        if (!("FiremanHelmetHits" in sc2)) sc2.FiremanHelmetHits <- 0;
        sc2.FiremanHelmetHits = sc2.FiremanHelmetHits + 1;

        local req = N2SE.Fireman.GetHelmetHitsRequired(wc, cal, dmg);

        if (sc2.FiremanHelmetHits >= req) {
            zombie.SetBodygroup(hbg, N2SE.Fireman.Config.blankHelmetIndex);
            N2SE.Fireman.DropHelmet(zombie, atk, dropModel);
            sc2.FiremanHelmetHits = 0;
        }

        return "absorb";
    };

    N2SE.Fireman.IsFireDamage <- function(info) {
        if (info == null) return false;
        local cfg = N2SE.Fireman.Config;

        local dt = 0;
        try { dt = info.GetDamageType(); } catch (ex) {}
        if (dt == null || dt == 0) return false;

        if ((dt & cfg.DMG_BURN)     != 0) return true;
        if ((dt & cfg.DMG_SLOWBURN) != 0) return true;
        return false;
    };

    N2SE.Fireman.ExplodeAt <- function(pos, sourceEnt) {
        if (pos == null) return;
        local cfg = N2SE.Fireman.Config;

        local sndPlayed = false;
        if (sourceEnt != null && sourceEnt.IsValid()) {
            try { EmitSoundOn(cfg.tankExplosionSound, sourceEnt); sndPlayed = true; } catch (ex) {}
        }
        if (!sndPlayed) {
            N2SE.Fireman.PlaySoundAt(cfg.tankExplosionSound, pos);
        }

        local exp = null;
        try {
            exp = SpawnEntityFromTable("env_explosion", {
                origin          = pos,
                iMagnitude      = cfg.tankExplosionDamage,
                iRadiusOverride = cfg.tankExplosionRadius,
                spawnflags      = 0
            });
        } catch (ex) { return; }

        if (exp != null && exp.IsValid()) {
            try { DispatchSpawn(exp); } catch (ex) {}
            try { exp.AcceptInput("Explode", "", null, null); } catch (ex) {
                try { EntFireByHandle(exp, "Explode", "", 0, null, null); } catch (ex2) {}
            }
            try { EntFireByHandle(exp, "Kill", "", 0.5, null, null); } catch (ex) {}
        }
    };

    N2SE.Fireman.DetonateTank <- function(zidx) {
        if (zidx == null || zidx <= 0) return;

        local rec = null;
        if (zidx in N2SE.Fireman.PendingTankExplosions) {
            rec = N2SE.Fireman.PendingTankExplosions[zidx];
            delete N2SE.Fireman.PendingTankExplosions[zidx];
        }

        local z = EntIndexToHScript(zidx);

        if (z != null && z.IsValid() && N2SE.Fireman.IsFireman(z)) {
            local sc = null;
            try { sc = z.GetScriptScope(); } catch (ex) {}
            if (sc != null && ("FiremanTankExploded" in sc) && sc.FiremanTankExploded) return;
            if (sc != null) sc.FiremanTankExploded <- true;

            N2SE.Fireman.SetBG(z, N2SE.Fireman.Config.bodyBodygroupName,
                N2SE.Fireman.Config.noTankBodyIndex);

            local pos = null;
            try { pos = z.GetOrigin() + Vector(0, 0, 40); } catch (ex) {}
            if (pos == null && rec != null) pos = rec.pos;
            if (pos == null) return;

            N2SE.Fireman.ExplodeAt(pos, z);
            return;
        }

        local pos = null;
        if (rec != null) {
            if (("deathPos" in rec) && rec.deathPos != null) pos = rec.deathPos;
            else pos = rec.pos;
        }
        if (pos == null) return;

        N2SE.Fireman.ExplodeAt(pos, null);
    };

    N2SE.Fireman.HandleTankHit <- function(zombie, info) {
        if (zombie == null || !zombie.IsValid()) return;
        if (!N2SE.Fireman.IsFireman(zombie)) return;

        local sc = null;
        try { sc = zombie.GetScriptScope(); } catch (ex) {}
        if (sc == null) return;

        if (("FiremanTankExploded" in sc) && sc.FiremanTankExploded) return;
        if (("FiremanTankLeaking" in sc) && sc.FiremanTankLeaking) return;

        local bodyIdx = N2SE.Fireman.GetBG(zombie, N2SE.Fireman.Config.bodyBodygroupName);
        if (bodyIdx != N2SE.Fireman.Config.tankBodyIndex) return;

        local zidx = N2SE.Fireman.Zidx(zombie);
        if (zidx <= 0) return;

        N2SE.Fireman.PlayImpact(zombie);
        N2SE.Fireman.PlayHitSound(zombie);

        sc.FiremanTankLeaking <- true;

        local pos = null;
        try { pos = zombie.GetOrigin() + Vector(0, 0, 40); } catch (ex) {}
        if (pos != null) {
            N2SE.Fireman.PendingTankExplosions[zidx] <- { pos = pos, deathPos = null };
        }

        try { EmitSoundOn(N2SE.Fireman.Config.tankLeakSound, zombie); } catch (ex) {
            try { EmitSound(N2SE.Fireman.Config.tankLeakSound,
                zombie.GetOrigin() + Vector(0, 0, 65)); } catch (ex2) {}
        }

        N2SE.Fireman.Fire("::N2SE.Fireman.DetonateTank(" + zidx + ")",
            N2SE.Fireman.Config.tankLeakDelay);
    };

    N2SE.Fireman.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Fireman.IsFireman(z)) return;

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) { try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {} }

        N2SE.Fireman.ApplyHeadSevered(z);

        if (!fired) { try { EntFireByHandle(z, "Break", "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) N2SE.SafeKill(z);

        local token = UniqueString();
        N2SE.Fireman.HeadRepairToken = token;
        N2SE.Fireman.RepairHead(zidx, token, N2SE.Fireman.Config.headRepairRounds);
    };

    N2SE.Fireman.TryDropLootAt <- function(pos, z) {
        if (pos == null) return;
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Fireman.IsFireman(z)) return;

        if (!N2SE.IsLootEnabled()) return;

        local chance = N2SE.GetLootChance();
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance.tointeger()) return;

        local cfg = N2SE.Fireman.Config;
        local item = cfg.lootItem;
        if (item == null || item == "") return;

        local spawnPos = pos + Vector(0, 0, cfg.lootZOffset);

        local ent = null;
        try {
            ent = SpawnEntityFromTable(item, {
                origin = spawnPos,
                angles = Vector(0, RandomFloat(0, 360), 0)
            });
        } catch (ex) { return; }
        if (ent == null || !ent.IsValid()) return;

        try { ent.Activate(); } catch (ex) {}
    };

    N2SE.Fireman.HookZombie <- function(z) {
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Fireman.IsFireman(z)) return;

        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("FiremanZombieHooked" in sc)) return;
        sc.FiremanZombieHooked <- true;

        local prev = ("OnTakeDamage" in sc) ? sc.OnTakeDamage : null;

        sc.OnTakeDamage <- function() {
            local z = self;
            if (z == null || !z.IsValid()) return true;

            if (!N2SE.IsModOn("fireman")) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            if (!N2SE.Fireman.IsFireman(z)) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            local di = null;
            try { di = info; } catch (ex) {}

            if (N2SE.Fireman.Config.fireImmune && N2SE.Fireman.IsFireDamage(di)) {
                try { di.SetDamage(0); } catch (ex) {}
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            if (di != null) {
                local hg = 0;
                try { hg = NetProps.GetPropInt(z, "m_LastHitGroup"); } catch (ex) {}

                if (hg == N2SE.Fireman.Config.tankHitGroup) {
                    try { N2SE.Fireman.HandleTankHit(z, di); } catch (ex) {}
                }
            }

            local helmetResult = "pass";
            try { helmetResult = N2SE.Fireman.HandleHelmetHit(z, di); } catch (ex) {}
            if (helmetResult == "absorb") return false;

            if (di != null) {
                local hg = 0;
                try { hg = NetProps.GetPropInt(z, "m_LastHitGroup"); } catch (ex) {}
                local isHead = (hg == 1 || hg == 10 || hg == 11);

                if (isHead) {
                    local dmg = 0;
                    try { dmg = di.GetDamage(); } catch (ex) {}
                    local hp = N2SE.Fireman.GetHP(z);
                    if (dmg > 0 && hp > 0 && dmg >= hp
                        && RandomInt(1, 100) <= N2SE.Fireman.Config.headSplitChance
                        && !N2SE.Fireman.IsHeadSevered(z)) {

                        local zidx = N2SE.Fireman.Zidx(z);
                        if (zidx > 0) {
                            N2SE.Fireman.Fire("::N2SE.Fireman.DoHeadSplit(" + zidx + ")",
                                N2SE.Fireman.Config.headSplitDelay);
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

    N2SE.Fireman.Attach <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return false; }
        if (sc == null || ("FiremanAttached" in sc)) return false;
        sc.FiremanAttached <- true;

        N2SE.Fireman.Mark(z);
        N2SE.Fireman.RandomizeParts(z);
        N2SE.Fireman.HookZombie(z);
        return true;
    };

    N2SE.Fireman.CleanupState <- function(zidx) {
        if (zidx == null || zidx <= 0) return;
        if (zidx in N2SE.Fireman.EntitySet)     delete N2SE.Fireman.EntitySet[zidx];
        if (zidx in N2SE.Fireman.PendingSpawns) delete N2SE.Fireman.PendingSpawns[zidx];
    };

    N2SE.Fireman.SpawnCompanion <- function(pos, angles) {
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Fireman.Config;
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

            N2SE.Fireman.Mark(zombie);

            try { DispatchSpawn(zombie); } catch (ex) {}
            if (!zombie.IsValid()) { N2SE.Fireman.Unmark(zombie); continue; }

            N2SE.Fireman.Mark(zombie);

            local hasArmor = false;
            try { if ("HasArmor" in zombie) hasArmor = zombie.HasArmor(); } catch (ex) {}
            if (hasArmor) {
                N2SE.Fireman.Unmark(zombie);
                N2SE.SafeKill(zombie);
                continue;
            }

            local model = N2SE.Fireman.PickModel();
            if (model != null && model != "") {
                try { zombie.SetModelOverride(model); } catch (ex) {}
            }
            N2SE.Fireman.Mark(zombie);

            N2SE.Fireman.RandomizeParts(zombie);
            N2SE.Fireman.HookZombie(zombie);

            return zombie;
        }

        return null;
    };

    N2SE.Fireman.ScheduleCompanion <- function(pos, angles) {
        if (pos == null) return;

        N2SE.Fireman.PendingCounter = N2SE.Fireman.PendingCounter + 1;
        local id = N2SE.Fireman.PendingCounter;
        N2SE.Fireman.PendingSpawns[id] <- { pos = pos, angles = angles };
        N2SE.Fireman.Fire("::N2SE.Fireman.ExecuteDelayedSpawn(" + id + ")",
            N2SE.Fireman.Config.spawnDelay);
    };

    N2SE.Fireman.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Fireman.PendingSpawns)) return;
        local rec = N2SE.Fireman.PendingSpawns[id];
        delete N2SE.Fireman.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Fireman.SpawnCompanion(rec.pos, rec.angles);
    };

    N2SE.Fireman.SpawnAtMe <- function() {
        local p = null;
        try { p = Entities.FindByClassnameNearest("player", Vector(0,0,0), 99999); } catch (ex) {}
        if (p == null || !p.IsValid()) return null;

        local pos = null, ang = null;
        try { pos = p.GetOrigin() + p.GetForwardVector() * 100.0; } catch (ex) { return null; }
        try { ang = Vector(0, p.GetAngles().y, 0); } catch (ex) { ang = Vector(0, 0, 0); }

        return N2SE.Fireman.SpawnCompanion(pos, ang);
    };

    N2SE.Fireman.OnSpawn <- function(e) {
        return;
    };

    N2SE.Fireman.OnKilled <- function(p, z) {
        if (z == null) return;
        local zidx = N2SE.Fireman.Zidx(z);
        if (zidx <= 0) return;

        local sc = null;
        try { sc = z.GetScriptScope(); } catch (ex) {}

        local isTagged = false;
        if (sc != null && ("IsFireman" in sc) && sc.IsFireman) isTagged = true;
        if (!isTagged && (zidx in N2SE.Fireman.EntitySet)) isTagged = true;
        if (!isTagged && N2SE.Fireman.IsFiremanModel(z)) isTagged = true;

        if (!isTagged) return;

        local atk = null;
        if (p != null && ("killeridx" in p)) {
            local kidx = p.killeridx;
            if (kidx != null && kidx > 0) {
                try { atk = EntIndexToHScript(kidx); } catch (ex) {}
                if (atk != null && !atk.IsValid()) atk = null;
            }
        }

        local deathPos = null;
        try { deathPos = z.GetOrigin(); } catch (ex) {}
        if (deathPos != null && deathPos.x == 0.0 && deathPos.y == 0.0 && deathPos.z == 0.0)
            deathPos = null;

        if (zidx in N2SE.Fireman.PendingTankExplosions) {
            if (deathPos != null) {
                N2SE.Fireman.PendingTankExplosions[zidx].deathPos <- deathPos;
            }
        }

        if (z.IsValid() && N2SE.Fireman.HasHelmet(z)) {
            local dropModel = N2SE.Fireman.GetHelmetDropModel(z);
            N2SE.Fireman.SetBG(z, N2SE.Fireman.Config.helmetBodygroupName,
                N2SE.Fireman.Config.blankHelmetIndex);
            N2SE.Fireman.DropHelmet(z, atk, dropModel);
        }

        if (z.IsValid() && deathPos != null) {
            N2SE.Fireman.TryDropLootAt(deathPos, z);
        }

        N2SE.Fireman.CleanupState(zidx);
    };

    N2SE.Fireman.OnShoved <- function(p, z) {
        if (!N2SE.IsModOn("fireman")) return;
        if (z == null || !z.IsValid()) return;
        if (!N2SE.Fireman.IsFireman(z)) return;
        if (!N2SE.Fireman.HasHelmet(z)) return;

        local hg = 0;
        try { hg = NetProps.GetPropInt(z, "m_LastHitGroup"); } catch (ex) {}
        if (hg != 1 && hg != 10 && hg != 11) return;

        N2SE.Fireman.PlayImpact(z);
        N2SE.Fireman.PlayHitSound(z);

        local hbg = -1;
        try { hbg = z.FindBodygroupByName(N2SE.Fireman.Config.helmetBodygroupName); } catch (ex) {}
        if (hbg == -1) return;

        local sc = null;
        try { z.ValidateScriptScope(); sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;
        if (!("FiremanHelmetHits" in sc)) sc.FiremanHelmetHits <- 0;
        sc.FiremanHelmetHits = sc.FiremanHelmetHits + 1;

        if (sc.FiremanHelmetHits >= N2SE.Fireman.Config.helmetMeleeLow) {
            z.SetBodygroup(hbg, N2SE.Fireman.Config.blankHelmetIndex);
            N2SE.Fireman.DropHelmet(z, null, N2SE.Fireman.GetHelmetDropModel(z));
            sc.FiremanHelmetHits = 0;
        }
    };

    N2SE.Fireman.Init <- function() {
        foreach (m in N2SE.Fireman.Models) {
            if (m == null || m.path == null) continue;
            try { PrecacheModel(m.path, true); } catch (ex) {}
        }
        try { PrecacheModel(N2SE.Fireman.Config.helmetModel, true); } catch (ex) {}
        try { PrecacheModel(N2SE.Fireman.Config.helmetModelGoggles, true); } catch (ex) {}
        try { N2SE.PrecacheAll(N2SE.Fireman.Config.impactSounds); } catch (ex) {}
        try {
            N2SE.PrecacheAll([
                N2SE.Fireman.Config.hitSound,
                N2SE.Fireman.Config.tankLeakSound,
                N2SE.Fireman.Config.tankExplosionSound
            ]);
        } catch (ex) {}
    };
}