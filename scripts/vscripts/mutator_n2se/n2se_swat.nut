if (!("Swat" in N2SE)) {
    N2SE.Swat <- {};
    N2SE.Swat.ModKey <- "swat";

    N2SE.Swat.Config <- {
        runnerChance = 10, spawnDelay = 3.0, spawnMaxAttempts = 5,
        zombieModel = "models/nmr_zombie/swat_zombie.mdl",
        hpMult = 1.0, hpMultNightmare = 1.5,

        shieldChance = 35, shieldChanceNightmare = 70,
        shieldModel = "models/nmr_zombie/swat_riotshield.mdl",
        shieldAttach = "shield",
        shoveWeight = 25.0, shotgunDedupWindow = 0.05, meleeBlockWindow = 0.5,
        immuneCalibers = ["22lr", "9mm", "45acp"],
        hitsToBreak = { ["12gauge"] = 1, ["308"] = 2, ["357"] = 2, ["556"] = 3, ["762mm"] = 3 },
        defaultHits = 3, defaultMeleeHits = 4,
        meleeHitsOverride = {
            ["me_fubar"] = 1, ["me_sledge"] = 1, ["tool_welder"] = 2,
            ["me_axe_fire"] = 2, ["me_pickaxe"] = 1,
            ["me_shovel"] = 3, ["me_spade"] = 3, ["me_etool_pick"] = 3,
            ["me_pipe_lead"] = 3, ["me_machete"] = 3, ["me_crowbar"] = 3,
            ["me_chainsaw"] = 3, ["me_abrasivesaw"] = 3,
            ["me_bat_metal"] = 4, ["me_etool"] = 4, ["me_barricade"] = 4,
            ["me_hatchet"] = 4, ["me_cleaver"] = 4, ["me_wrench"] = 4,
            ["me_kitknife"] = 5, ["me_fists"] = 5
        },

        helmetChance = 45, helmetChanceNightmare = 90,
        helmetModel = "models/nmr_restored/swat/w_swat_helmet.mdl",

        dropZOffset = 70.0, dropVelocity = 150.0, dropVariance = 30.0,
        dropVzMin = 120.0, dropVzMax = 220.0, dropAngularMax = 600.0,
        helmetDropSpawnflags = 4,

        headBodygroupName = "head", helmetBodygroupName = "helmet", validHeadIndex = 0,
        headSeveredVariants = [4, 5],

        headSplitChance  = 30,
        headSplitDelay   = 0.02,
        headRepairRounds = 12,
        headRepairStep   = 0.05,

        lootZOffset = 20.0,
        dropGroups = [
            { weight = 100, items = [
                { classname = "fa_mp5a3", clip1 = 0, weight = 30 },
                { classname = "item_bandages", weight = 40 },
                { classname = "ammobox_9mm", weight = 30 }
            ]}
        ],

        grabbedShoveWindow = 2.0, grabbedShoveNeeded = 2,
        grabbedShoveResetDelay = 10.0, grabbedShoveDedup = 0.15,
        grabbedShovePollRate = 0.05,

        hitSound = "physics/metal/metal_sheet_impact_hard6.wav"
    };

    N2SE.Swat.IN_SHOOVE <- 134217728;

    N2SE.Swat.SwatEntitySet       <- {};
    N2SE.Swat.ShieldEntitySet     <- {};
    N2SE.Swat.MuzzledSet          <- {};
    N2SE.Swat.ZombieShieldMap     <- {};
    N2SE.Swat.ZombieIndexToShield <- {};
    N2SE.Swat.ShieldState         <- {};
    N2SE.Swat.MeleeBlockTable     <- {};
    N2SE.Swat.PendingSpawns       <- {};
    N2SE.Swat.PendingCounter      <- 0;
    N2SE.Swat.GrabbedShove        <- {};
    N2SE.Swat.PlayerPrevShove     <- {};
    N2SE.Swat.PollRunning         <- false;
    N2SE.Swat.HeadRepairToken     <- "";

    N2SE.Swat.HeadWeightsNormal    <- { [0] = 25, [1] = 25, [2] = 25, [3] = 25 };
    N2SE.Swat.HeadWeightsNightmare <- { [0] = 55, [1] = 15, [2] = 15, [3] = 15 };

    N2SE.Swat.Log <- function(m) {};

    N2SE.Swat.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Swat.FireCode <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); return true; }
        catch (ex) { return false; }
    };

    N2SE.Swat.ThrowPhysics <- function(ent, yaw) {
        if (ent == null || !ent.IsValid()) return;
        local c = N2SE.Swat.Config;
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

    N2SE.Swat.GetBodygroupVal <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Swat.SetBodygroupVal <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Swat.GetShieldChance <- function() {
        return N2SE.IsNightmare() ? N2SE.Swat.Config.shieldChanceNightmare : N2SE.Swat.Config.shieldChance;
    };

    N2SE.Swat.GetHelmetChance <- function() {
        return N2SE.IsNightmare() ? N2SE.Swat.Config.helmetChanceNightmare : N2SE.Swat.Config.helmetChance;
    };

    N2SE.Swat.GetHpMult <- function() {
        return N2SE.IsNightmare() ? N2SE.Swat.Config.hpMultNightmare : N2SE.Swat.Config.hpMult;
    };

    N2SE.Swat.MarkSwatEntity <- function(z, muzzled) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Swat.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Swat.SwatEntitySet[zidx] <- true;
        if (muzzled) N2SE.Swat.MuzzledSet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) {
                sc.IsSwat <- true;
                if (muzzled) sc.IsMuzzled <- true;
            }
        } catch (ex) {}
    };

    N2SE.Swat.MarkShieldEntity <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Swat.Zidx(z);
        if (zidx <= 0) return;
        N2SE.Swat.ShieldEntitySet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.HasShield <- true;
        } catch (ex) {}
    };

    N2SE.Swat.IsShieldEntity <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Swat.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Swat.ShieldEntitySet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("HasShield" in sc) && sc.HasShield) return true;
        } catch (ex) {}
        return false;
    };

    N2SE.Swat.MarkMuzzled <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zidx = N2SE.Swat.Zidx(z);
        if (zidx > 0) N2SE.Swat.MuzzledSet[zidx] <- true;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.IsMuzzled <- true;
        } catch (ex) {}
    };

    N2SE.Swat.HasValidHead <- function(z) {
        return N2SE.Swat.GetBodygroupVal(z, N2SE.Swat.Config.headBodygroupName) == N2SE.Swat.Config.validHeadIndex;
    };

    N2SE.Swat.HasHelmet <- function(z) {
        return N2SE.Swat.GetBodygroupVal(z, N2SE.Swat.Config.helmetBodygroupName) == 0;
    };

    N2SE.Swat.HideHelmet <- function(z) {
        if (z == null || !z.IsValid()) return;
        local bg = -1;
        try { bg = z.FindBodygroupByName(N2SE.Swat.Config.helmetBodygroupName); } catch (ex) { return; }
        if (bg == -1) return;
        try { z.SetBodygroup(bg, 1); } catch (ex) {}
    };

    N2SE.Swat.IsMuzzled <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Swat.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Swat.MuzzledSet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsMuzzled" in sc) && sc.IsMuzzled) return true;
        } catch (ex) {}
        return N2SE.Swat.HasValidHead(z);
    };

    N2SE.Swat.IsSwatEntity <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zidx = N2SE.Swat.Zidx(z);
        if (zidx > 0 && (zidx in N2SE.Swat.SwatEntitySet)) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("IsSwat" in sc) && sc.IsSwat) return true;
            local mn = z.GetModelName();
            if (mn != null && mn.find("swat_zombie") != null) return true;
        } catch (ex) {}
        return false;
    };

    N2SE.Swat.IsBitingActivity <- function(act) {
        if (act == null || act == "") return false;
        if (act.find("GRAB") != null) return true;
        if (act.find("EAT")  != null) return true;
        if (act.find("BITE") != null) return true;
        return false;
    };

    N2SE.Swat.IsShotgunClass <- function(wc) {
        return (wc == "fa_870" || wc == "fa_500a" || wc == "fa_superx3" || wc == "fa_sv10");
    };

    N2SE.Swat.IsPenetratingWeapon <- function(wc, cal) {
        if (wc == null || wc.find("fa_") != 0) return false;
        return (cal == "357" || cal == "12gauge");
    };

    N2SE.Swat.GetHelmetHitsRequired <- function(wc, cal, dmg) {
        if (wc == null) return 3;
        if (wc.find("fa_") == 0) {
            if (cal == "9mm" || cal == "22lr") return 2;
            return 1;
        }
        if (dmg >= 400) return 2;
        if (dmg >= 200) return 3;
        return 5;
    };

    N2SE.Swat.GetShieldState <- function(shield) {
        if (shield == null || !shield.IsValid()) return null;
        if (shield in N2SE.Swat.ShieldState) return N2SE.Swat.ShieldState[shield];
        local st = { broken = false, progress = 0.0, lastHit = 0.0 };
        N2SE.Swat.ShieldState[shield] <- st;
        return st;
    };

    N2SE.Swat.IsShieldBroken <- function(shield) {
        if (shield == null || !shield.IsValid()) return true;
        if (shield in N2SE.Swat.ShieldState) return N2SE.Swat.ShieldState[shield].broken;
        return false;
    };

    N2SE.Swat.PlayHitSound <- function(ent) {
        if (ent == null || !ent.IsValid()) return;
        local s = N2SE.Swat.Config.hitSound;
        try { EmitSoundOn(s, ent); return; } catch (ex) {}
        try { EmitSound(s, ent.GetOrigin() + Vector(0, 0, 40)); } catch (ex) {}
    };

    N2SE.Swat.MarkMeleeBlock <- function(atk) {
        if (atk == null || !atk.IsValid()) return;
        local aid = N2SE.Swat.Zidx(atk);
        if (aid > 0) N2SE.Swat.MeleeBlockTable[aid] <- Time();
    };

    N2SE.Swat.ShouldBlockMelee <- function(atk) {
        if (atk == null || !atk.IsValid()) return false;
        local aid = N2SE.Swat.Zidx(atk);
        if (aid <= 0 || !(aid in N2SE.Swat.MeleeBlockTable)) return false;
        return (Time() - N2SE.Swat.MeleeBlockTable[aid]) < N2SE.Swat.Config.meleeBlockWindow;
    };

    N2SE.Swat.PickWeighted <- function(items) {
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

    N2SE.Swat.PickGroupWeighted <- function(groups) {
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

    N2SE.Swat.TryDropLootAt <- function(pos) {
        if (pos == null) return;
        if (pos.x == 0.0 && pos.y == 0.0 && pos.z == 0.0) return;
        if (!N2SE.IsLootEnabled()) return;

        local chance = N2SE.GetLootChance();
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance.tointeger()) return;

        local group = N2SE.Swat.PickGroupWeighted(N2SE.Swat.Config.dropGroups);
        if (group == null) return;

        local chosen = N2SE.Swat.PickWeighted(group.items);
        if (chosen == null) return;

        local spawnPos = pos + Vector(0, 0, N2SE.Swat.Config.lootZOffset);
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

    N2SE.Swat.DropHelmet <- function(z, atk) {
        if (z == null || !z.IsValid()) return;
        local cfg = N2SE.Swat.Config;

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

        local drop = null;
        try {
            drop = SpawnEntityFromTable("prop_physics_override", {
                model      = cfg.helmetModel,
                origin     = origin,
                angles     = Vector(0, yaw, 0),
                spawnflags = cfg.helmetDropSpawnflags
            });
        } catch (ex) { return; }
        if (drop == null || !drop.IsValid()) return;

        try { DispatchSpawn(drop); } catch (ex) {}
        if (!drop.IsValid()) return;

        N2SE.ApplyRenderColor(drop, color.r, color.g, color.b);
        N2SE.Swat.ThrowPhysics(drop, yaw);
    };

    N2SE.Swat.IsHeadSevered <- function(z) {
        local cur = N2SE.Swat.GetBodygroupVal(z, N2SE.Swat.Config.headBodygroupName);
        foreach (idx in N2SE.Swat.Config.headSeveredVariants) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Swat.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (N2SE.Swat.IsHeadSevered(z)) return true;
        local v = N2SE.Swat.Config.headSeveredVariants;
        if (v == null || v.len() == 0) return false;
        return N2SE.Swat.SetBodygroupVal(z, N2SE.Swat.Config.headBodygroupName,
            v[RandomInt(0, v.len() - 1)]);
    };

    N2SE.Swat.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Swat.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Swat.IsHeadSevered(z)) {
            N2SE.Swat.ApplyHeadSevered(z);
        }
        N2SE.Swat.FireCode("::N2SE.Swat.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Swat.Config.headRepairStep);
    };

    N2SE.Swat.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;

        N2SE.Swat.ApplyHeadSevered(z);

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) { try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) { try { EntFireByHandle(z, "Break",     "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) N2SE.SafeKill(z);

        local token = UniqueString();
        N2SE.Swat.HeadRepairToken = token;
        N2SE.Swat.RepairHead(zidx, token, N2SE.Swat.Config.headRepairRounds);
    };

    N2SE.Swat.HandleHelmetHit <- function(zombie, info) {
        if (zombie == null || !zombie.IsValid()) return "pass";
        if (!N2SE.Swat.HasValidHead(zombie) || !N2SE.Swat.HasHelmet(zombie)) return "pass";

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
        try { hbg = zombie.FindBodygroupByName(N2SE.Swat.Config.helmetBodygroupName); } catch (ex) {}
        if (hbg == -1) return "pass";

        N2SE.PlayImpact(zombie);

        if (N2SE.Swat.IsPenetratingWeapon(wc, cal)) {
            zombie.SetBodygroup(hbg, 1);
            N2SE.Swat.DropHelmet(zombie, atk);
            try {
                local sc = zombie.GetScriptScope();
                if (sc != null && ("HelmetHits" in sc)) sc.HelmetHits = 0;
            } catch (ex) {}
            return "pass";
        }

        local sc = null;
        try { zombie.ValidateScriptScope(); sc = zombie.GetScriptScope(); } catch (ex) { return "pass"; }
        if (sc == null) return "pass";
        if (!("HelmetHits" in sc)) sc.HelmetHits <- 0;
        sc.HelmetHits = sc.HelmetHits + 1;

        local req = N2SE.Swat.GetHelmetHitsRequired(wc, cal, dmg);

        if (sc.HelmetHits >= req) {
            zombie.SetBodygroup(hbg, 1);
            N2SE.Swat.DropHelmet(zombie, atk);
            sc.HelmetHits = 0;
        }
        return "absorb";
    };

    N2SE.Swat.OnShieldTakeDamage <- function() {
        if (!N2SE.IsModOn("swat")) return true;
        try {
            local shield = self;
            if (shield == null || !shield.IsValid()) return true;
            local st = N2SE.Swat.GetShieldState(shield);
            if (st == null || st.broken) return true;

            local di = null;
            try { di = info; } catch (ex) {}
            if (di == null) return true;

            local atk = null;
            try { atk = di.GetAttacker(); } catch (ex) {}

            local wpn = null;
            try { wpn = di.GetWeapon(); } catch (ex) {}
            if (wpn == null || !wpn.IsValid()) { try { wpn = di.GetInflictor(); } catch (ex) {} }
            local wc = "";
            if (wpn != null && wpn.IsValid()) { try { wc = wpn.GetClassname(); } catch (ex) {} }
            if (wc == "" && atk != null && atk.IsValid()) {
                try {
                    local w = atk.GetActiveWeapon();
                    if (w != null && w.IsValid()) wc = w.GetClassname();
                } catch (ex) {}
            }

            local hitsNeeded = null;
            local isFirearm = false;

            if (wc.find("fa_") == 0) {
                local cal = null;
                try { cal = N2SE.cal(wc); } catch (ex) {}
                isFirearm = true;
                foreach (c in N2SE.Swat.Config.immuneCalibers) {
                    if (cal == c) return false;
                }
                hitsNeeded = N2SE.Swat.Config.defaultHits;
                if (cal != null && (cal in N2SE.Swat.Config.hitsToBreak))
                    hitsNeeded = N2SE.Swat.Config.hitsToBreak[cal];
            } else if (wc.find("me_") == 0) {
                hitsNeeded = N2SE.Swat.Config.defaultMeleeHits;
                if (wc in N2SE.Swat.Config.meleeHitsOverride)
                    hitsNeeded = N2SE.Swat.Config.meleeHitsOverride[wc];
                N2SE.Swat.MarkMeleeBlock(atk);
            } else {
                return false;
            }

            if (hitsNeeded == null || hitsNeeded <= 0) return false;

            local now = Time();
            if (isFirearm && N2SE.Swat.IsShotgunClass(wc)) {
                if (st.lastHit > 0 && now - st.lastHit < N2SE.Swat.Config.shotgunDedupWindow)
                    return false;
                st.lastHit = now;
            }

            N2SE.Swat.PlayHitSound(shield);

            local hpMult = N2SE.Swat.GetHpMult();
            if (hpMult <= 0) hpMult = 1.0;
            st.progress += (100.0 / hitsNeeded) / hpMult;

            if (st.progress >= 100.0) {
                st.broken = true;
                if (shield.IsValid()) N2SE.SafeKill(shield);
            }
            return false;
        } catch (ex) {
            return true;
        }
    };

    N2SE.Swat.OnZombieTakeDamage <- function() {
        if (!N2SE.IsModOn("swat")) return true;
        local zombie = null;
        try { zombie = self; } catch (ex) {}
        if (zombie == null || !zombie.IsValid()) return true;
        if (!(zombie in N2SE.Swat.ZombieShieldMap)) return true;

        local shield = N2SE.Swat.ZombieShieldMap[zombie];
        if (shield == null || !shield.IsValid() || N2SE.Swat.IsShieldBroken(shield)) return true;

        local di = null;
        try { di = info; } catch (ex) {}
        if (di == null) return true;

        local atk = null;
        try { atk = di.GetAttacker(); } catch (ex) {}
        if (atk == null || !atk.IsValid()) return true;

        local wpn = null;
        try { wpn = di.GetWeapon(); } catch (ex) {}
        if (wpn == null || !wpn.IsValid()) { try { wpn = di.GetInflictor(); } catch (ex) {} }
        local wc = "";
        if (wpn != null && wpn.IsValid()) { try { wc = wpn.GetClassname(); } catch (ex) {} }

        if (wc.find("me_") != 0) return true;
        if (N2SE.Swat.ShouldBlockMelee(atk)) return false;
        return true;
    };

    N2SE.Swat.HookZombie <- function(zombie) {
        if (zombie == null || !zombie.IsValid()) return;
        local sc = null;
        try { zombie.ValidateScriptScope(); sc = zombie.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("SwatZombieHooked" in sc)) return;
        sc.SwatZombieHooked <- true;

        local prev = null;
        if ("OnTakeDamage" in sc) prev = sc.OnTakeDamage;

        sc.OnTakeDamage <- function() {
            local zombie = self;
            if (zombie == null || !zombie.IsValid()) return true;

            if (!N2SE.IsModOn("swat")) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            local di = null;
            try { di = info; } catch (ex) {}

            local blocked = false;
            try { if (!N2SE.Swat.OnZombieTakeDamage()) blocked = true; } catch (ex) {}
            if (blocked) return false;

            local helmetResult = "pass";
            try { helmetResult = N2SE.Swat.HandleHelmetHit(zombie, di); } catch (ex) {}
            if (helmetResult == "absorb") return false;

            if (di != null && !N2SE.Swat.HasHelmet(zombie)) {
                local dmg = 0;
                try { dmg = di.GetDamage(); } catch (ex) {}
                local hp = 0;
                try { hp = zombie.GetHealth(); } catch (ex) {}
                if (dmg > 0 && hp > 0 && dmg >= hp
                    && RandomInt(1, 100) <= N2SE.Swat.Config.headSplitChance
                    && !N2SE.Swat.IsHeadSevered(zombie)) {

                    local zidx = N2SE.Swat.Zidx(zombie);
                    if (zidx > 0) {
                        N2SE.Swat.ApplyHeadSevered(zombie);
                        N2SE.Swat.FireCode("::N2SE.Swat.DoHeadSplit(" + zidx + ")",
                            N2SE.Swat.Config.headSplitDelay);
                    }
                    return false;
                }
            }

            if (prev != null) {
                try { return prev(); } catch (ex) { return true; }
            }
            return true;
        };
    };

    N2SE.Swat.HookShield <- function(shield, zombie) {
        if (shield == null || !shield.IsValid()) return;
        local sc = null;
        try { shield.ValidateScriptScope(); sc = shield.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;

        sc.OnTakeDamage <- N2SE.Swat.OnShieldTakeDamage;

        if (zombie != null && zombie.IsValid()) {
            N2SE.Swat.ZombieShieldMap[zombie] <- shield;
            local zidx = N2SE.Swat.Zidx(zombie);
            if (zidx > 0) N2SE.Swat.ZombieIndexToShield[zidx] <- shield;
            N2SE.Swat.HookZombie(zombie);
        }
    };

    N2SE.Swat.AttachShield <- function(zombie) {
        if (zombie == null || !zombie.IsValid()) return null;
        local cfg = N2SE.Swat.Config;

        local shield = SpawnEntityFromTable("prop_dynamic", {
            model          = cfg.shieldModel,
            origin         = zombie.GetOrigin(),
            angles         = zombie.GetAngles(),
            solid          = 6,
            collisiongroup = 1,
            disableshadows = 1
        });
        if (shield == null || !shield.IsValid()) return null;

        try { DispatchSpawn(shield); } catch (ex) {}
        if (!shield.IsValid()) return null;

        try { shield.SetSolid(6); } catch (ex) {}
        try { if ("SetCollisionGroup" in shield) shield.SetCollisionGroup(1); } catch (ex) {}

        local att = -1;
        try { att = zombie.LookupAttachment(cfg.shieldAttach); } catch (ex) {}
        if (att <= 0) {
            N2SE.SafeKill(shield);
            return null;
        }

        try { shield.SetParent(zombie, cfg.shieldAttach); } catch (ex) {}
        try { shield.SetLocalOrigin(Vector(0, 0, 0)); } catch (ex) {}
        try { shield.SetLocalAngles(Vector(0, 0, 0)); } catch (ex) {}

        N2SE.Swat.HookShield(shield, zombie);
        N2SE.Swat.MarkShieldEntity(zombie);

        local sidx = N2SE.Swat.Zidx(shield);
        local zidx = N2SE.Swat.Zidx(zombie);
        if (sidx > 0 && zidx > 0) {
            N2SE.Swat.FireCode("::N2SE.Swat.SyncShieldColor(" + sidx + "," + zidx + ")", 0.2);
        }
        return shield;
    };

    N2SE.Swat.SyncShieldColor <- function(shieldIdx, zombieIdx) {
        local shield = EntIndexToHScript(shieldIdx);
        local zombie = EntIndexToHScript(zombieIdx);
        if (shield == null || !shield.IsValid()) return;
        if (zombie == null || !zombie.IsValid()) return;

        local zsc = null;
        try { zsc = zombie.GetScriptScope(); } catch (ex) {}
        if (zsc == null || !("IsBlood" in zsc) || !zsc.IsBlood) return;

        local color = N2SE.GetRenderColor(zombie);
        N2SE.ApplyRenderColor(shield, color.r, color.g, color.b);
    };

    N2SE.Swat.PickWeightedHead <- function() {
        local weights = N2SE.IsNightmare()
            ? N2SE.Swat.HeadWeightsNightmare
            : N2SE.Swat.HeadWeightsNormal;
        if (weights == null) return N2SE.Swat.Config.validHeadIndex;

        local total = 0;
        foreach (idx, w in weights) total += w;
        if (total <= 0) return N2SE.Swat.Config.validHeadIndex;

        local roll = RandomInt(1, total);
        local cum = 0;
        foreach (idx, w in weights) {
            cum += w;
            if (roll <= cum) return idx;
        }
        return N2SE.Swat.Config.validHeadIndex;
    };

    N2SE.Swat.RandomizeHead <- function(zombie) {
        if (zombie == null || !zombie.IsValid()) return false;
        local bg = -1;
        try { bg = zombie.FindBodygroupByName(N2SE.Swat.Config.headBodygroupName); } catch (ex) { return false; }
        if (bg == -1) return false;
        local count = 0;
        try { count = zombie.GetBodygroupCount(bg); } catch (ex) { return false; }
        if (count < 1) return false;

        local chosen = N2SE.Swat.PickWeightedHead();
        if (chosen >= count) chosen = count - 1;
        try { zombie.SetBodygroup(bg, chosen); } catch (ex) { return false; }

        if (chosen != N2SE.Swat.Config.validHeadIndex) {
            N2SE.Swat.HideHelmet(zombie);
            return false;
        }

        N2SE.Swat.MarkMuzzled(zombie);
        if (RandomInt(1, 100) > N2SE.Swat.GetHelmetChance()) {
            N2SE.Swat.HideHelmet(zombie);
        }
        return true;
    };

    N2SE.Swat.SpawnCompanion <- function(pos, angles) {
        if (pos == null) return;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Swat.Config;
        local maxAttempts = cfg.spawnMaxAttempts;
        if (maxAttempts < 1) maxAttempts = 1;

        for (local attempt = 0; attempt < maxAttempts; attempt++) {
            local cls = (RandomInt(1, 100) <= cfg.runnerChance)
                ? "npc_nmrih_runnerzombie"
                : "npc_nmrih_basezombie";

            local zombie = null;
            try {
                zombie = SpawnEntityFromTable(cls, { origin = pos, angles = angles });
            } catch (ex) { continue; }
            if (zombie == null || !zombie.IsValid()) continue;

            N2SE.Swat.MarkSwatEntity(zombie, false);
            try { DispatchSpawn(zombie); } catch (ex) {}
            if (!zombie.IsValid()) continue;
            N2SE.Swat.MarkSwatEntity(zombie, false);

            local hasArmor = false;
            try { if ("HasArmor" in zombie) hasArmor = zombie.HasArmor(); } catch (ex) {}
            if (hasArmor) {
                local zidx = N2SE.Swat.Zidx(zombie);
                if (zidx > 0) {
                    if (zidx in N2SE.Swat.SwatEntitySet) delete N2SE.Swat.SwatEntitySet[zidx];
                    if (zidx in N2SE.Swat.MuzzledSet)    delete N2SE.Swat.MuzzledSet[zidx];
                }
                try { N2SE.SafeKill(zombie); } catch (ex) {}
                continue;
            }

            try { zombie.SetModelOverride(cfg.zombieModel); } catch (ex) {}
            N2SE.Swat.MarkSwatEntity(zombie, false);

            N2SE.Swat.RandomizeHead(zombie);
            N2SE.Swat.HookZombie(zombie);

            if (RandomInt(1, 100) <= N2SE.Swat.GetShieldChance()) {
                N2SE.Swat.AttachShield(zombie);
            }

            return zombie;
        }
        return null;
    };

    N2SE.Swat.ScheduleCompanion <- function(pos, angles) {
        if (pos == null) return;

        N2SE.Swat.PendingCounter = N2SE.Swat.PendingCounter + 1;
        local id = N2SE.Swat.PendingCounter;
        N2SE.Swat.PendingSpawns[id] <- { pos = pos, angles = angles };
        N2SE.Swat.FireCode("::N2SE.Swat.ExecuteDelayedSpawn(" + id + ")",
            N2SE.Swat.Config.spawnDelay);
    };

    N2SE.Swat.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Swat.PendingSpawns)) return;
        local rec = N2SE.Swat.PendingSpawns[id];
        delete N2SE.Swat.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Swat.SpawnCompanion(rec.pos, rec.angles);
    };

    N2SE.Swat.OnKilled <- function(p, z) {
        if (z == null) return;

        local zidx = -1;
        try { zidx = N2SE.Swat.Zidx(z); } catch (ex) {}

        if (zidx > 0) {
            local suffix = "_" + zidx;
            local toRemove = [];
            foreach (k, _ in N2SE.Swat.GrabbedShove) {
                if (k.find(suffix) == (k.len() - suffix.length())) toRemove.append(k);
            }
            foreach (k in toRemove) delete N2SE.Swat.GrabbedShove[k];
        }

        if (!N2SE.Swat.IsSwatEntity(z)) return;

        local deathPos = null;
        try { deathPos = z.GetOrigin(); } catch (ex) {}
        if (deathPos != null && deathPos.x == 0.0 && deathPos.y == 0.0 && deathPos.z == 0.0)
            deathPos = null;

        local atk = null;
        if (p != null && ("killeridx" in p)) {
            local kidx = p.killeridx;
            if (kidx != null && kidx > 0) {
                try { atk = EntIndexToHScript(kidx); } catch (ex) {}
                if (atk != null && !atk.IsValid()) atk = null;
            }
        }

        if (zidx > 0 && (zidx in N2SE.Swat.ZombieIndexToShield)) {
            delete N2SE.Swat.ZombieIndexToShield[zidx];
        }

        if (zidx > 0) {
            if (zidx in N2SE.Swat.SwatEntitySet)   delete N2SE.Swat.SwatEntitySet[zidx];
            if (zidx in N2SE.Swat.MuzzledSet)      delete N2SE.Swat.MuzzledSet[zidx];
            if (zidx in N2SE.Swat.ShieldEntitySet) delete N2SE.Swat.ShieldEntitySet[zidx];
        }

        if (z.IsValid()) {
            try {
                if (N2SE.Swat.HasHelmet(z)) {
                    N2SE.Swat.DropHelmet(z, atk);
                    N2SE.Swat.HideHelmet(z);
                }
            } catch (ex) {}
        }

        if (deathPos != null) N2SE.Swat.TryDropLootAt(deathPos);
    };

    N2SE.Swat.OnSpawn <- function(e) {
        return;
    };

    N2SE.Swat.PlayerIsGrabbed <- function(p) {
        if (p == null || !p.IsValid()) return false;
        try { if (p.IsGrabbed()) return true; } catch (ex) {}
        try { if (NetProps.GetPropInt(p, "m_bGrabbed") != 0) return true; } catch (ex) {}
        return false;
    };

    N2SE.Swat.PlayerHoldsShove <- function(p) {
        if (p == null || !p.IsValid()) return false;
        try { return (p.GetButtons() & N2SE.Swat.IN_SHOOVE) != 0; } catch (ex) { return false; }
    };

    N2SE.Swat.GetGrabbingZombie <- function(player) {
        if (player == null || !player.IsValid()) return null;
        if (!N2SE.Swat.PlayerIsGrabbed(player)) return null;

        local pid = N2SE.Swat.Zidx(player);
        if (pid <= 0) return null;

        try {
            if (pid in ::N2SE.GrabTable) {
                local zidx = ::N2SE.GrabTable[pid];
                if (zidx != null && zidx > 0) {
                    local z = EntIndexToHScript(zidx);
                    if (z != null && z.IsValid()) return z;
                }
            }
        } catch (ex) {}

        local pos = null;
        try { pos = player.GetOrigin(); } catch (ex) { return null; }
        if (pos == null) return null;

        local best = null, bestDist = 999.0;
        foreach (zidx, _ in N2SE.Swat.SwatEntitySet) {
            local z = EntIndexToHScript(zidx);
            if (z == null || !z.IsValid()) continue;

            local dist = 999.0;
            try { dist = (z.GetOrigin() - pos).Length(); } catch (ex) { continue; }
            if (dist > 150.0 || dist >= bestDist) continue;

            local act = "";
            try { act = z.GetActivity(); } catch (ex) {}
            if (!N2SE.Swat.IsBitingActivity(act) && dist >= 80.0) continue;

            best = z;
            bestDist = dist;
        }
        return best;
    };

    N2SE.Swat.HandleGrabbedShove <- function(pid, zidx, player) {
        if (pid <= 0 || zidx <= 0) return;

        local key = "" + pid + "_" + zidx;
        local now = Time();
        local cfg = N2SE.Swat.Config;

        local rec = (key in N2SE.Swat.GrabbedShove) ? N2SE.Swat.GrabbedShove[key] : null;

        if (rec != null && (now - rec.lastTime) < cfg.grabbedShoveDedup) return;

        if (rec == null || (now - rec.lastTime) > cfg.grabbedShoveWindow) {
            local fresh = {};
            fresh.count    <- 1;
            fresh.lastTime <- now;
            fresh.token    <- "";
            N2SE.Swat.GrabbedShove[key] <- fresh;
            return;
        }

        rec.count = rec.count + 1;
        rec.lastTime = now;

        if (rec.count >= cfg.grabbedShoveNeeded) {
            delete N2SE.Swat.GrabbedShove[key];

            if (player == null || !player.IsValid()) return;

            local z = EntIndexToHScript(zidx);
            if (z == null || !z.IsValid()) return;

            local ok = false;
            try { if ("GetShoved" in z) { z.GetShoved(player); ok = true; } } catch (ex) {}

            if (!ok && z.IsValid() && player.IsValid()) {
                try { z.AcceptInput("GetShoved", "", player, player); ok = true; } catch (ex) {}
            }

            if (!ok && z.IsValid() && player.IsValid()) {
                try { EntFireByHandle(z, "GetShoved", "", 0, player, player); ok = true; } catch (ex) {}
            }
        }
    };

    N2SE.Swat.PollGrabbedShove <- function() {
        if (!N2SE.Swat.PollRunning) return;
        if (!N2SE.IsModOn("swat")) {
            N2SE.Swat.FireCode("::N2SE.Swat.PollGrabbedShove()", N2SE.Swat.Config.grabbedShovePollRate);
            return;
        }

        for (local i = 1; i <= 32; i++) {
            local p = GetPlayerByIndex(i);
            if (p == null || !p.IsValid() || !p.IsAlive()) {
                if (i in N2SE.Swat.PlayerPrevShove) N2SE.Swat.PlayerPrevShove[i] <- false;
                continue;
            }

            local shovePressed = N2SE.Swat.PlayerHoldsShove(p);

            local prev = false;
            if (i in N2SE.Swat.PlayerPrevShove) prev = N2SE.Swat.PlayerPrevShove[i];
            N2SE.Swat.PlayerPrevShove[i] <- shovePressed;

            if (!shovePressed || prev) continue;

            if (!N2SE.Swat.PlayerIsGrabbed(p)) continue;

            local z = N2SE.Swat.GetGrabbingZombie(p);
            if (z == null || !z.IsValid()) continue;

            if (!(z in N2SE.Swat.ZombieShieldMap)) continue;
            local shield = N2SE.Swat.ZombieShieldMap[z];
            if (shield == null || !shield.IsValid() || N2SE.Swat.IsShieldBroken(shield)) continue;

            local zidx = N2SE.Swat.Zidx(z);
            if (zidx <= 0) continue;

            N2SE.Swat.HandleGrabbedShove(i, zidx, p);
        }

        N2SE.Swat.FireCode("::N2SE.Swat.PollGrabbedShove()",
            N2SE.Swat.Config.grabbedShovePollRate);
    };

    N2SE.Swat.StartGrabbedShovePoll <- function() {
        if (!N2SE.IsModOn("swat")) return;
        if (N2SE.Swat.PollRunning) return;
        N2SE.Swat.PollRunning = true;
        N2SE.Swat.FireCode("::N2SE.Swat.PollGrabbedShove()", 0.1);
    };

    N2SE.Swat.StopGrabbedShovePoll <- function() {
        N2SE.Swat.PollRunning = false;
        N2SE.Swat.PlayerPrevShove.clear();
    };

    N2SE.Swat.OnReset <- function(...) {
        N2SE.Swat.StopGrabbedShovePoll();
        N2SE.Swat.StartGrabbedShovePoll();
    };

    N2SE.Swat.ScheduleGrabbedShoveReset <- function(pid, zidx) {
        if (pid <= 0 || zidx <= 0) return;

        local key = "" + pid + "_" + zidx;
        if (!(key in N2SE.Swat.GrabbedShove)) return;

        local token = UniqueString();
        N2SE.Swat.GrabbedShove[key].token = token;

        N2SE.Swat.FireCode("::N2SE.Swat.DoGrabbedShoveReset(\"" + key + "\",\"" + token + "\")",
            N2SE.Swat.Config.grabbedShoveResetDelay);
    };

    N2SE.Swat.DoGrabbedShoveReset <- function(key, token) {
        if (key == null || !(key in N2SE.Swat.GrabbedShove)) return;
        if (N2SE.Swat.GrabbedShove[key].token != token) return;
        delete N2SE.Swat.GrabbedShove[key];
    };

    N2SE.Swat.OnGrabEnd <- function(...) {
        if (vargv.len() < 1) return;
        local p = vargv[0];
        if (p == null) return;

        local pid = ("player_index" in p) ? p.player_index : null;
        local cid = ("causer_index" in p) ? p.causer_index : null;
        if (pid == null || pid <= 0) return;

        if (cid != null && cid > 0 && cid != pid) {
            N2SE.Swat.ScheduleGrabbedShoveReset(pid, cid);
        } else {
            local prefix = "" + pid + "_";
            local matched = [];
            foreach (k, _ in N2SE.Swat.GrabbedShove) {
                if (k.find(prefix) == 0) matched.append(k);
            }
            foreach (k in matched) {
                local parts = split(k, "_");
                if (parts.len() >= 2) {
                    local zidx = parts[1].tointeger();
                    if (zidx > 0) N2SE.Swat.ScheduleGrabbedShoveReset(pid, zidx);
                }
            }
        }
    };

    if (!("__swat_events_registered" in getroottable())) {
        try {
            ListenToGameEvent("grab_end",          N2SE.Swat.OnGrabEnd, "N2SE_SwatGrabEnd");
            ListenToGameEvent("nmrih_reset_map",   N2SE.Swat.OnReset,   "N2SE_SwatResetMap");
            ListenToGameEvent("nmrih_round_begin", N2SE.Swat.OnReset,   "N2SE_SwatRoundBegin");
        } catch (ex) {}
        getroottable().__swat_events_registered <- true;
    }

    N2SE.Swat.Init <- function() {
        try { PrecacheModel(N2SE.Swat.Config.shieldModel, true); } catch (ex) {}
        try { PrecacheModel(N2SE.Swat.Config.zombieModel, true); } catch (ex) {}
        try { PrecacheModel(N2SE.Swat.Config.helmetModel, true); } catch (ex) {}
        try { N2SE.PrecacheAll([N2SE.Swat.Config.hitSound]); } catch (ex) {}
        N2SE.Swat.StartGrabbedShovePoll();
    };
}