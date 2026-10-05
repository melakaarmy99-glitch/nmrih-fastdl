if (!("Blood" in N2SE)) {
    N2SE.Blood <- {};
    N2SE.Blood.ModKey <- "blood";

    N2SE.Blood.Config <- {
        chance         = 12,
        chanceNightmare = 24,
        healthMult = 1.3,
        colorR = 70,
        colorG = 12,
        colorB = 12,

        damageMult = 1.25,

        eyeGlowEnabled     = true,
        eyeGlowModel       = "sprites/redglow3.vmt",
        eyeGlowRenderMode  = 9,
        eyeGlowScale       = 0.001,
        eyeGlowRenderAmt   = 135,

        eyeAttachPoint     = "headshot_squirt",

        eyeGroupOffsetX    = 0.0,
        eyeGroupOffsetY    = -3.0,
        eyeGroupOffsetZ    = 4.0,

        eyeGroupPitch      = 0.0,
        eyeGroupYaw        = 0.0,
        eyeGroupRoll       = 0.0,

        eyeSeparation      = 2.0,

        eyeGlowVisibleDist = 512.0,
        eyeGlowCheckRate   = 0.5,

        bleedVoiceRadius          = 512.0,
        bleedVoiceChance          = 30,
        bleedVoiceChanceNightmare = 60,
        bleedCheckInterval        = 2.0
    };

    N2SE.Blood.ClassOverrides <- {
        ["npc_nmrih_kidzombie"] = {
            healthMult = 2.0,

            eyeGroupOffsetX = 0.0,
            eyeGroupOffsetY = 3.0,
            eyeGroupOffsetZ = -3.0,

            eyeGroupPitch   = 0.0,
            eyeGroupYaw     = 0.0,
            eyeGroupRoll    = 0.0,

            eyeSeparation   = 2.0
        }
    };

    N2SE.Blood.ModelGroups <- {
        ["female"] = [
            "models/nmr_zombie/julie.mdl",
            "models/nmr_zombie/lisa.mdl",
            "models/nmr_zombie/tammy.mdl"
        ],
        ["elderly"] = [
            "models/nmr_zombie/herby.mdl",
            "models/nmr_zombie/berny.mdl",
            "models/nmr_zombie/officezom.mdl"
        ],
        ["swat"] = [
            "models/nmr_zombie/swat_zombie.mdl"
        ],
        ["builder"] = [
            "models/nmr_zombie/c_zombie1.mdl"
        ]
    };

    N2SE.Blood.GroupOverrides <- {
        ["female"] = {
            eyeGroupOffsetX = 0.0,
            eyeGroupOffsetY = -6.0,
            eyeGroupOffsetZ = 3.0,
            eyeGroupPitch   = 0.0,
            eyeGroupYaw     = 0.0,
            eyeGroupRoll    = 0.0,
            eyeSeparation   = 2.0
        },
        ["elderly"] = {
            eyeGroupOffsetX = 0.0,
            eyeGroupOffsetY = -6.0,
            eyeGroupOffsetZ = 4.0,
            eyeGroupPitch   = 0.0,
            eyeGroupYaw     = 0.0,
            eyeGroupRoll    = 0.0,
            eyeSeparation   = 2.0
        },
        ["swat"] = {
            eyeGroupOffsetX = 0.0,
            eyeGroupOffsetY = -4.0,
            eyeGroupOffsetZ = 4.0,
            eyeGroupPitch   = 0.0,
            eyeGroupYaw     = 0.0,
            eyeGroupRoll    = 0.0,
            eyeSeparation   = 2.0
        },
        ["builder"] = {
            eyeGroupOffsetX = 0.0,
            eyeGroupOffsetY = -4.0,
            eyeGroupOffsetZ = 4.0,
            eyeGroupPitch   = 0.0,
            eyeGroupYaw     = 0.0,
            eyeGroupRoll    = 0.0,
            eyeSeparation   = 2.0
        }
    };

    N2SE.Blood.ModelOverrides <- {
        ["officer_zombie.mdl"]   = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -5.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["officer_zombie2.mdl"]  = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -5.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["officer_zombie3.mdl"]  = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -5.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },

        ["fireman_zombie.mdl"]   = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["fireman_zombie2.mdl"]  = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["fireman_zombie3.mdl"]  = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },

        ["hospital_zombie.mdl"]  = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["hospital_zombie2.mdl"] = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["hospital_zombie3.mdl"] = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },

        ["c_zombie01.mdl"]       = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["c_zombie02.mdl"]       = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["c_zombie03.mdl"]       = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },

        ["survivor_zombie01.mdl"] = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["survivor_zombie02.mdl"] = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },
        ["survivor_zombie03.mdl"] = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.0, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 },

        ["swat_zombie.mdl"]      = { eyeGroupOffsetX = 0.0, eyeGroupOffsetY = -4.5, eyeGroupOffsetZ = 4.0, eyeGroupPitch = 0.0, eyeGroupYaw = 0.0, eyeGroupRoll = 0.0, eyeSeparation = 2.0 }
    };

    N2SE.Blood.BloodEntitySet <- {};

    N2SE.Blood.GetSpawnChance <- function() {
        if (N2SE.IsNightmare()) return N2SE.Blood.Config.chanceNightmare;
        return N2SE.Blood.Config.chance;
    };

    N2SE.Blood.GetBleedVoiceChance <- function() {
        if (N2SE.IsNightmare()) return N2SE.Blood.Config.bleedVoiceChanceNightmare;
        return N2SE.Blood.Config.bleedVoiceChance;
    };

    N2SE.Blood.GetDamageMult <- function() {
        return N2SE.Blood.Config.damageMult;
    };

    N2SE.Blood.MarkBloodEntity <- function(e) {
        if (e == null || !e.IsValid()) return;
        local zidx = -1;
        try { zidx = e.entindex(); } catch (ex) {}
        if (zidx > 0) N2SE.Blood.BloodEntitySet[zidx] <- true;
        try {
            local sc = e.GetScriptScope();
            if (sc != null) sc.IsBlood <- true;
        } catch (ex) {}
    };

    N2SE.Blood.IsBloodEntity <- function(e) {
        if (e == null || !e.IsValid()) return false;

        local zidx = -1;
        try { zidx = e.entindex(); } catch (ex) {}
        if (zidx > 0 && (zidx in N2SE.Blood.BloodEntitySet)) return true;

        local sc = null;
        try { sc = e.GetScriptScope(); } catch (ex) {}
        if (sc != null && ("IsBlood" in sc) && sc.IsBlood) return true;

        return false;
    };

    N2SE.Blood.GetEntityModel <- function(e) {
        if (e == null || !e.IsValid()) return "";
        try {
            local m = e.GetModelName();
            if (m != null && m != "") return m;
        } catch (ex) {}
        try {
            local m = NetProps.GetPropString(e, "m_ModelName");
            if (m != null && m != "") return m;
        } catch (ex) {}
        return "";
    };

    N2SE.Blood.FindGroup <- function(modelPath) {
        if (modelPath == "") return null;
        foreach (groupName, patterns in N2SE.Blood.ModelGroups) {
            foreach (pattern in patterns) {
                if (modelPath.find(pattern) != null) return groupName;
            }
        }
        return null;
    };

    N2SE.Blood.GetConfigFor <- function(e) {
        local cfg = {};
        foreach (k, v in N2SE.Blood.Config) cfg[k] <- v;

        if (e == null || !e.IsValid()) return cfg;

        local classname = e.GetClassname();
        local modelPath = N2SE.Blood.GetEntityModel(e);

        if (classname in N2SE.Blood.ClassOverrides) {
            foreach (k, v in N2SE.Blood.ClassOverrides[classname]) cfg[k] <- v;
        }

        if (modelPath != "") {
            local group = N2SE.Blood.FindGroup(modelPath);
            if (group != null && (group in N2SE.Blood.GroupOverrides)) {
                foreach (k, v in N2SE.Blood.GroupOverrides[group]) cfg[k] <- v;
            }
        }

        if (modelPath != "") {
            foreach (pattern, overrides in N2SE.Blood.ModelOverrides) {
                if (modelPath.find(pattern) != null) {
                    foreach (k, v in overrides) cfg[k] <- v;
                    break;
                }
            }
        }

        return cfg;
    };

    N2SE.Blood.ComputeOffset <- function(cfg, side) {
        return Vector(
            cfg.eyeGroupOffsetX + side * (cfg.eyeSeparation * 0.5),
            cfg.eyeGroupOffsetY,
            cfg.eyeGroupOffsetZ
        );
    };

    N2SE.Blood.ComputeAngle <- function(cfg) {
        return Vector(cfg.eyeGroupPitch, cfg.eyeGroupYaw, cfg.eyeGroupRoll);
    };

    N2SE.Blood.SpawnEyeSprite <- function(e, side, cfg) {
        local sprite = SpawnEntityFromTable("env_sprite", {
            model         = cfg.eyeGlowModel,
            rendermode    = cfg.eyeGlowRenderMode,
            scale         = cfg.eyeGlowScale,
            spawnflags    = 1,
            GlowProxySize = 1,
            HDRColorScale = 1,
            renderamt     = cfg.eyeGlowRenderAmt
        });
        if (sprite == null || !sprite.IsValid()) return null;

        try { DispatchSpawn(sprite); } catch (ex) {}

        local attached = false;
        try {
            sprite.SetParent(e, cfg.eyeAttachPoint);
            attached = true;
        } catch (ex) {}
        if (!attached) {
            try {
                EntFireByHandle(sprite, "SetParent", "!activator", 0, e, e);
                EntFireByHandle(sprite, "SetParentAttachment", cfg.eyeAttachPoint, 0.02, e, e);
                attached = true;
            } catch (ex) {}
        }
        if (!attached) {
            try {
                EntFireByHandle(sprite, "SetParent", "!activator", 0, e, e);
                EntFireByHandle(sprite, "SetParentAttachment", "ValveBiped.Bip01_Head1", 0.02, e, e);
                attached = true;
            } catch (ex) {}
        }

        local offset = N2SE.Blood.ComputeOffset(cfg, side);
        local angle  = N2SE.Blood.ComputeAngle(cfg);

        try { sprite.SetLocalOrigin(offset); } catch (ex) {}
        try { sprite.SetLocalAngles(angle); } catch (ex) {}

        return sprite;
    };

    N2SE.Blood.EyeGlowThink <- function() {
        local sprite = self;
        if (sprite == null || !sprite.IsValid()) return -1;

        local sc = null;
        try { sc = sprite.GetScriptScope(); } catch (ex) { return -1; }
        if (sc == null) return -1;

        local cfg = N2SE.Blood.Config;
        local visible = false;
        local spritePos = sprite.GetOrigin();

        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            if (!p.IsValid() || !p.IsAlive()) continue;
            if ((p.GetOrigin() - spritePos).Length() <= cfg.eyeGlowVisibleDist) {
                visible = true;
                break;
            }
        }

        local current = ("IsVisible" in sc) ? sc.IsVisible : true;
        if (visible != current) {
            try { sprite.SetNoDraw(!visible); } catch (ex) {}
            sc.IsVisible <- visible;
        }

        return cfg.eyeGlowCheckRate;
    };

    N2SE.Blood.SpawnEyeGlow <- function(e, cfg) {
        if (!cfg.eyeGlowEnabled) return;

        local sc = null;
        try { sc = e.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;
        if (("EyeGlowL" in sc) && sc.EyeGlowL != null && sc.EyeGlowL.IsValid()) return;

        sc.EyeGlowL <- N2SE.Blood.SpawnEyeSprite(e,  1, cfg);
        sc.EyeGlowR <- N2SE.Blood.SpawnEyeSprite(e, -1, cfg);

        foreach (k in ["EyeGlowL", "EyeGlowR"]) {
            local sprite = sc[k];
            if (sprite == null || !sprite.IsValid()) continue;
            try {
                sprite.ValidateScriptScope();
                local ssc = sprite.GetScriptScope();
                if (ssc != null) {
                    ssc.IsVisible    <- true;
                    ssc.EyeGlowThink <- N2SE.Blood.EyeGlowThink;
                    AddThinkToEnt(sprite, "EyeGlowThink");
                }
            } catch (ex) {}
        }
    };

    N2SE.Blood.ReapplyTransformToEyeGlow <- function(z) {
        if (z == null || !z.IsValid()) return;

        local sc = null;
        try { sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;

        local hasL = ("EyeGlowL" in sc) && sc.EyeGlowL != null && sc.EyeGlowL.IsValid();
        local hasR = ("EyeGlowR" in sc) && sc.EyeGlowR != null && sc.EyeGlowR.IsValid();
        if (!hasL && !hasR) return;

        local cfg = N2SE.Blood.GetConfigFor(z);
        local attach = cfg.eyeAttachPoint;

        foreach (k in ["EyeGlowL", "EyeGlowR"]) {
            if (!(k in sc)) continue;
            local sprite = sc[k];
            if (sprite == null || !sprite.IsValid()) continue;

            local side = (k == "EyeGlowL") ? 1 : -1;

            try { sprite.SetParent(z, attach); } catch (ex) {}
            try { sprite.SetLocalOrigin(N2SE.Blood.ComputeOffset(cfg, side)); } catch (ex) {}
            try { sprite.SetLocalAngles(N2SE.Blood.ComputeAngle(cfg)); } catch (ex) {}
        }
    };

    N2SE.Blood.DestroyEyeGlow <- function(e) {
        if (e == null || !e.IsValid()) return;
        local sc = null;
        try { sc = e.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;

        if ("EyeGlowL" in sc && sc.EyeGlowL != null && sc.EyeGlowL.IsValid())
            N2SE.SafeKill(sc.EyeGlowL);
        if ("EyeGlowR" in sc && sc.EyeGlowR != null && sc.EyeGlowR.IsValid())
            N2SE.SafeKill(sc.EyeGlowR);
        sc.EyeGlowL <- null;
        sc.EyeGlowR <- null;
    };

    N2SE.Blood.Make <- function(e) {
        if (e == null || !e.IsValid()) return;
        local cfg = N2SE.Blood.GetConfigFor(e);

        local sc = null;
        try { sc = e.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;

        local curHp = 0;
        try { curHp = e.GetHealth(); } catch (ex) { return; }
        local curMax = curHp;
        try { curMax = NetProps.GetPropInt(e, "m_iMaxHealth"); } catch (ex) {}
        if (curMax <= 0) curMax = curHp;

        local newHp  = (curHp  * cfg.healthMult).tointeger();
        local newMax = (curMax * cfg.healthMult).tointeger();
        try { NetProps.SetPropInt(e, "m_iMaxHealth", newMax); } catch (ex) {}
        try { e.SetHealth(newHp); } catch (ex) {}

        local applied = false;
        try { e.SetRenderColor(cfg.colorR, cfg.colorG, cfg.colorB); applied = true; } catch (ex) {}
        if (!applied) {
            try {
                local packed = cfg.colorR | (cfg.colorG << 8) | (cfg.colorB << 16) | (255 << 24);
                NetProps.SetPropInt(e, "m_clrRender", packed);
            } catch (ex2) {}
        }

        N2SE.Blood.MarkBloodEntity(e);

        N2SE.Blood.SpawnEyeGlow(e, cfg);
    };

    N2SE.Blood.OnSpawn <- function(e) {
        return;
    };

    N2SE.Blood.OnKilled <- function(p, z) {
        if (z == null || !z.IsValid()) return;

        local zidx = -1;
        try { zidx = z.entindex(); } catch (ex) {}
        if (zidx > 0 && (zidx in N2SE.Blood.BloodEntitySet))
            delete N2SE.Blood.BloodEntitySet[zidx];

        local sc = null;
        try { sc = z.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;
        if (!("IsBlood" in sc) || !sc.IsBlood) return;

        N2SE.Blood.DestroyEyeGlow(z);
    };

    N2SE.Blood.ConvertToRunner <- function(e) {
        if (!N2SE.IsModOn("blood")) return;
        if (e == null || !e.IsValid()) return;

        local hpBefore = 0, maxHpBefore = 0;
        try { hpBefore = e.GetHealth(); } catch (ex) {}
        try { maxHpBefore = NetProps.GetPropInt(e, "m_iMaxHealth"); } catch (ex) {}
        if (maxHpBefore <= 0) maxHpBefore = hpBefore;
        local eIdx = e.entindex();

        local ok = false;
        try { if ("BecomeRunner" in e) { e.BecomeRunner(); ok = true; } } catch (ex) {}
        if (!ok) { try { e.AcceptInput("BecomeRunner", "", null, null); ok = true; } catch (ex) {} }
        if (!ok) { try { EntFireByHandle(e, "BecomeRunner", "", 0, null, null); ok = true; } catch (ex) {} }

        if (!ok) return;

        if (("Rotten" in N2SE) && ("Config" in N2SE.Rotten)) {
            local snd = N2SE.Rotten.Config.runnerAlertSound;
            try { EmitSoundOn(snd, e); } catch (ex) {
                try { EmitSound(snd, e.GetOrigin()); } catch (ex2) {}
            }
        }

        if (hpBefore > 0 && hpBefore != 350
            && ("Rotten" in N2SE) && ("RestoreHp" in N2SE.Rotten)) {
            local code = "::N2SE.Rotten.RestoreHp(" + eIdx + "," + hpBefore + "," + maxHpBefore + ")";
            EntFire("worldspawn", "RunScriptCode", code, 0.15, null);
        }
    };

    N2SE.Blood.ConvertBloodShamblersNear <- function(player) {
        if (!N2SE.IsModOn("blood")) return 0;
        if (player == null || !player.IsValid() || !player.IsAlive()) return 0;

        local cfg = N2SE.Blood.Config;
        local radius = cfg.bleedVoiceRadius;
        local chance = N2SE.Blood.GetBleedVoiceChance();
        local pos = player.GetOrigin();
        local converted = 0;

        local e = null;
        while ((e = Entities.FindByClassnameWithin(e, "npc_nmrih_shamblerzombie", pos, radius)) != null) {
            if (!e.IsValid()) continue;
            try { if (!e.IsAlive()) continue; } catch (ex) { continue; }

            local esc = null;
            try { esc = e.GetScriptScope(); } catch (ex) {}
            if (esc == null) continue;

            if (!("IsBlood" in esc) || !esc.IsBlood) continue;
            if ("Rotten" in esc && esc.Rotten) continue;

            if (RandomInt(1, 100) > chance) continue;

            N2SE.Blood.ConvertToRunner(e);
            converted++;
        }

        return converted;
    };

    N2SE.Blood.BleedRunning <- false;

    N2SE.Blood.CheckBleeding <- function() {
        if (!N2SE.Blood.BleedRunning) return;
        if (!N2SE.IsModOn("blood")) {
            EntFire("worldspawn", "RunScriptCode", "N2SE.Blood.CheckBleeding()", N2SE.Blood.Config.bleedCheckInterval);
            return;
        }

        for (local i = 1; i <= 32; i++) {
            local player = GetPlayerByIndex(i);
            if (!player || !player.IsValid() || !player.IsAlive()) continue;

            local isBleeding = false;
            try { isBleeding = player.IsBleedingOut(); } catch (ex) {}
            if (!isBleeding) continue;

            N2SE.Blood.ConvertBloodShamblersNear(player);
        }

        EntFire("worldspawn", "RunScriptCode", "N2SE.Blood.CheckBleeding()", N2SE.Blood.Config.bleedCheckInterval);
    };

    N2SE.Blood.StartBleedPoll <- function() {
        if (!N2SE.IsModOn("blood")) return;
        if (N2SE.Blood.BleedRunning) return;
        N2SE.Blood.BleedRunning = true;
        EntFire("worldspawn", "RunScriptCode", "N2SE.Blood.CheckBleeding()", 0.5);
    };

    N2SE.Blood.StopBleedPoll <- function() {
        N2SE.Blood.BleedRunning = false;
    };

    N2SE.Blood.OnResetBleedPoll <- function(...) {
        N2SE.Blood.StopBleedPoll();
        N2SE.Blood.StartBleedPoll();
    };

    if (!("__blood_bleedpoll_registered" in getroottable())) {
        ListenToGameEvent("nmrih_reset_map",   N2SE.Blood.OnResetBleedPoll, "N2SE_BleedPollReset");
        ListenToGameEvent("nmrih_round_begin", N2SE.Blood.OnResetBleedPoll, "N2SE_BleedPollRound");
        getroottable().__blood_bleedpoll_registered <- true;
    }

    N2SE.Blood.Init <- function() {
        try { PrecacheModel(N2SE.Blood.Config.eyeGlowModel, true); } catch (ex) {}
        N2SE.Blood.StartBleedPoll();
    };
}