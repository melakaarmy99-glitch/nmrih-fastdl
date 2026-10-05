if (!("Armored" in N2SE)) {
    N2SE.Armored <- {};
    N2SE.Armored.ModKey <- "armored";

    N2SE.Armored.Config <- {
        helmetModel     = "models/nmr_zombie/national_guard_helmet_phys.mdl",
        helmetLife      = 10.0,
        spawnZOffset    = 10.0,
        followUpWindow  = 0.15,
        meleeThreshold  = 500,

        headBodygroupName   = "head",
        headSeveredVariants = [2, 3],

        headSplitChance  = 50,
        headSplitDelay   = 0.02,
        headRepairRounds = 12,
        headRepairStep   = 0.05,

        velocity = {
            ["9mm"] = 100, ["22lr"] = 100, ["45acp"] = 150, ["357"] = 150,
            ["12gauge"] = 200, ["556"] = 300, ["762mm"] = 300, ["308"] = 400
        },
        variance = {
            ["9mm"] = 15, ["22lr"] = 15, ["45acp"] = 20, ["357"] = 20,
            ["12gauge"] = 25, ["556"] = 30, ["762mm"] = 30, ["308"] = 35
        },
        angularMin = 200.0,
        angularMax = 600.0,
        vzMin = 120.0,
        vzMax = 220.0
    };

    N2SE.Armored.HeadRepairToken <- "";
    N2SE.Armored.SuppressHook    <- {};

    N2SE.Armored.Zidx <- function(e) {
        if (e == null || !e.IsValid()) return -1;
        try { return e.entindex(); } catch (ex) { return -1; }
    };

    N2SE.Armored.FireCode <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); return true; }
        catch (ex) { return false; }
    };

    N2SE.Armored.GetBodygroupVal <- function(z, name) {
        if (z == null || !z.IsValid()) return -1;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return -1; }
        if (bg == -1) return -1;
        try { return z.GetBodygroup(bg); } catch (ex) { return -1; }
    };

    N2SE.Armored.SetBodygroupVal <- function(z, name, idx) {
        if (z == null || !z.IsValid()) return false;
        local bg = -1;
        try { bg = z.FindBodygroupByName(name); } catch (ex) { return false; }
        if (bg == -1) return false;
        try { z.SetBodygroup(bg, idx); return true; } catch (ex) { return false; }
    };

    N2SE.Armored.IsHeadSevered <- function(z) {
        local cur = N2SE.Armored.GetBodygroupVal(z, N2SE.Armored.Config.headBodygroupName);
        foreach (idx in N2SE.Armored.Config.headSeveredVariants) {
            if (cur == idx) return true;
        }
        return false;
    };

    N2SE.Armored.ApplyHeadSevered <- function(z) {
        if (z == null || !z.IsValid()) return false;
        if (N2SE.Armored.IsHeadSevered(z)) return true;
        local v = N2SE.Armored.Config.headSeveredVariants;
        if (v == null || v.len() == 0) return false;
        return N2SE.Armored.SetBodygroupVal(z, N2SE.Armored.Config.headBodygroupName,
            v[RandomInt(0, v.len() - 1)]);
    };

    N2SE.Armored.RepairHead <- function(zidx, token, left) {
        if (zidx <= 0 || left <= 0) return;
        if (token == null || token != N2SE.Armored.HeadRepairToken) return;
        local z = EntIndexToHScript(zidx);
        if (z != null && z.IsValid() && !N2SE.Armored.IsHeadSevered(z)) {
            N2SE.Armored.ApplyHeadSevered(z);
        }
        N2SE.Armored.FireCode("::N2SE.Armored.RepairHead(" + zidx + ",\"" + token + "\"," + (left - 1) + ")",
            N2SE.Armored.Config.headRepairStep);
    };

    N2SE.Armored.DoHeadSplit <- function(zidx) {
        if (zidx <= 0) return;
        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) return;

        local hp = 0;
        try { hp = z.GetHealth(); } catch (ex) {}
        if (hp <= 0) return;

        N2SE.Armored.SuppressHook[zidx] <- true;

        local fired = false;
        try { z.AcceptInput("HeadSplit", "", null, null); fired = true; } catch (ex) {}
        if (!fired) { try { EntFireByHandle(z, "HeadSplit", "", 0, null, null); fired = true; } catch (ex) {} }
        if (!fired) { try { EntFireByHandle(z, "Break",     "", 0, null, null); fired = true; } catch (ex) {} }

        if (zidx in N2SE.Armored.SuppressHook) delete N2SE.Armored.SuppressHook[zidx];

        local hp2 = 0;
        try { if (z != null && z.IsValid()) hp2 = z.GetHealth(); } catch (ex) {}
        if (hp2 > 0) {
            N2SE.Armored.SuppressHook[zidx] <- true;
            try { EntFireByHandle(z, "Break", "", 0, null, null); } catch (ex) {}
            if (zidx in N2SE.Armored.SuppressHook) delete N2SE.Armored.SuppressHook[zidx];
        }

        local token = UniqueString();
        N2SE.Armored.HeadRepairToken = token;
        N2SE.Armored.RepairHead(zidx, token, N2SE.Armored.Config.headRepairRounds);
    };

    N2SE.Armored.HitsNeeded <- function(cal, dmg) {
        if (cal != null) return (cal == "9mm" || cal == "22lr") ? 2 : 1;
        if (dmg >= 350) return 1;
        if (dmg >= 200) return 2;
        return 3;
    };

    N2SE.Armored.DropHelmet <- function(v, atk, cal) {
        local cfg = N2SE.Armored.Config;
        local o = v.GetOrigin() + Vector(0, 0, cfg.spawnZOffset);
        local yaw = v.GetAngles().y;
        if (atk != null && atk.IsValid()) {
            local d = v.GetOrigin() - atk.GetOrigin();
            if (d.Length() > 0.1) yaw = atan2(d.y, d.x) * 57.29578;
        }
        local vel = (cal in cfg.velocity) ? cfg.velocity[cal] : 80;
        local vr  = (cal in cfg.variance) ? cfg.variance[cal] : 10;
        local skin = 0;
        try { skin = v.GetSkin(); } catch (ex) {}

        local color = N2SE.GetRenderColor(v);

        local helmet = null;
        try {
            helmet = SpawnEntityFromTable("prop_physics_override", {
                origin     = o,
                angles     = Vector(0, yaw, 0),
                model      = cfg.helmetModel,
                skin       = skin,
                spawnflags = 518
            });
        } catch (ex) { return; }
        if (helmet == null || !helmet.IsValid()) return;
        try { DispatchSpawn(helmet); } catch (ex) {}

        N2SE.ApplyRenderColor(helmet, color.r, color.g, color.b);

        local rad = yaw * 3.14159265358979 / 180.0;
        local vx = cos(rad) * vel + RandomFloat(-vr, vr);
        local vy = sin(rad) * vel + RandomFloat(-vr, vr);
        local vz = RandomFloat(cfg.vzMin, cfg.vzMax);
        try { helmet.SetAbsVelocity(Vector(vx, vy, vz)); } catch (ex) {
            try { helmet.SetVelocity(Vector(vx, vy, vz)); } catch (ex2) {}
        }

        local avx = RandomFloat(-cfg.angularMax, cfg.angularMax);
        local avy = RandomFloat(-cfg.angularMax, cfg.angularMax);
        local avz = RandomFloat(-cfg.angularMax, cfg.angularMax);
        local av = Vector(avx, avy, avz);
        try { helmet.SetLocalAngularVelocity(av); } catch (ex) {
            try { helmet.SetAngularVelocity(av); } catch (ex2) {}
        }

        try { EntFireByHandle(helmet, "Kill", "", cfg.helmetLife, null, null); } catch (ex) {}
    };

    N2SE.Armored.BreakHelmet <- function(v, atk, cal, split) {
        local hi = v.FindBodygroupByName("helmet");
        if (hi == -1 || v.GetBodygroup(hi) != 0) return;
        v.SetBodygroup(hi, 1);
        N2SE.Armored.DropHelmet(v, atk, cal);
        local sc = v.GetScriptScope();
        if (sc != null && "HelmetHits" in sc) sc.HelmetHits = 0;

        if (split) {
            local zidx = N2SE.Armored.Zidx(v);
            if (zidx > 0) {
                N2SE.Armored.FireCode(
                    "::N2SE.Armored.DoHeadSplit(" + zidx + ")",
                    N2SE.Armored.Config.headSplitDelay);
            }
        }
    };

    N2SE.Armored.OnTakeDamage <- function() {
        if (!N2SE.IsModOn("armored")) return true;
        try {
            local v = self;
            if (v == null || !v.IsValid()) return true;

            local zidx = N2SE.Armored.Zidx(v);
            if (zidx > 0 && (zidx in N2SE.Armored.SuppressHook)) return true;

            if (!("HasArmor" in v)) return true;
            local hasArmor = false;
            try { hasArmor = v.HasArmor(); } catch (ex) {}
            if (!hasArmor) return true;

            local hg = NetProps.GetPropInt(v, "m_LastHitGroup");
            if (hg == null || hg == 0) return true;
            local head = (hg == 1 || hg == 10 || hg == 11);
            local vest = (hg == 2 || hg == 3);
            if (!head && !vest) return true;

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
            if (wc == "") return true;

            local isFirearm = (wc.find("fa_") == 0);
            local cal = isFirearm ? N2SE.cal(wc) : null;
            local dmg = 0;
            try { dmg = di.GetDamage(); } catch (ex) {}

            local hi = -1, vi = -1;
            try { hi = v.FindBodygroupByName("helmet"); } catch (ex) {}
            try { vi = v.FindBodygroupByName("vest"); } catch (ex) {}
            local hasHelmet = (hi != -1 && v.GetBodygroup(hi) == 0);
            local hasVest   = (vi != -1 && v.GetBodygroup(vi) == 0);

            local sc  = v.GetScriptScope();
            local now = Time();

            if (head) {
                if (hasHelmet) {
                    N2SE.PlayImpact(v);
                    local cur = 1;
                    if (sc != null) { cur = (("HelmetHits" in sc) ? sc.HelmetHits : 0) + 1; sc.HelmetHits = cur; }
                    local req = N2SE.Armored.HitsNeeded(cal, dmg);
                    if (cur < req) return false;

                    local hp = 0;
                    try { hp = v.GetHealth(); } catch (ex) {}

                    if (cal == "308") {
                        local willKill = (dmg > 0 && hp > 0 && dmg >= hp);
                        N2SE.Armored.BreakHelmet(v, atk, cal, willKill);
                        if (sc != null) sc.HelmetBreakTime <- now;
                        return willKill ? false : true;
                    }

                    local split = false, overflow = 0;
                    if (cal == "357") {
                        try { local orig = di.GetDamage(); if (orig > 0) overflow = orig * 0.5; } catch (ex) {}
                    }
                    else if (!isFirearm && dmg > N2SE.Armored.Config.meleeThreshold)
                        overflow = dmg - N2SE.Armored.Config.meleeThreshold;

                    N2SE.Armored.BreakHelmet(v, atk, cal, split);
                    if (overflow > 0) N2SE.DealDamage(v, atk, overflow);
                    if (sc != null) sc.HelmetBreakTime <- now;
                    return false;
                }

                if (sc != null && "HelmetBreakTime" in sc) {
                    if (now - sc.HelmetBreakTime < N2SE.Armored.Config.followUpWindow) return false;
                }

                local hp = 0;
                try { hp = v.GetHealth(); } catch (ex) {}
                if (dmg > 0 && hp > 0 && dmg >= hp
                    && !N2SE.Armored.IsHeadSevered(v)
                    && RandomInt(1, 100) <= N2SE.Armored.Config.headSplitChance) {

                    if (zidx > 0) {
                        N2SE.Armored.FireCode("::N2SE.Armored.DoHeadSplit(" + zidx + ")",
                            N2SE.Armored.Config.headSplitDelay);
                    }
                    return false;
                }

                return true;
            }

            if (vest && hasVest) {
                if (isFirearm && N2SE.rifle(cal)) return true;
                return false;
            }
            return true;
        } catch (ex) { return true; }
    };

    N2SE.Armored.OnShoved <- function(p, z) {
        if (!N2SE.IsModOn("armored")) return;
        local hasArmor = false;
        try { hasArmor = z.HasArmor(); } catch (ex) {}
        if (!hasArmor) return;
        local hi = z.FindBodygroupByName("helmet");
        if (hi == -1 || z.GetBodygroup(hi) != 0) return;
        local sc = z.GetScriptScope();
        if (sc == null) return;

        local pid = ("player_id" in p) ? p.player_id : null;
        local atk = null;
        if (pid != null && pid > 0) atk = EntIndexToHScript(pid);

        local isSKS = false;
        if (atk != null && atk.IsValid()) {
            try {
                local w = atk.GetActiveWeapon();
                if (w != null && w.IsValid()) isSKS = N2SE.sks(w.GetClassname());
            } catch (ex) {}
        }

        if (isSKS) {
            N2SE.PlayImpact(z);
            sc.HelmetHits = 0;
            N2SE.Armored.BreakHelmet(z, atk, null, false);
            return;
        }
        local add = RandomInt(1, 2);
        local cur = ("HelmetHits" in sc) ? sc.HelmetHits : 0;
        cur += add;
        sc.HelmetHits = cur;
        N2SE.PlayImpact(z);
        if (cur >= 3) {
            sc.HelmetHits = 0;
            N2SE.Armored.BreakHelmet(z, null, null, false);
        }
    };

    N2SE.Armored.OnSpawn <- function(e) {
        if (!N2SE.IsModOn("armored")) return;
        if (!("HasArmor" in e)) return;
        try { e.ValidateScriptScope(); } catch (ex) { return; }
        local sc = e.GetScriptScope();
        if (sc == null) return;
        if (!("HelmetHits" in sc)) sc.HelmetHits <- 0;
        sc.OnTakeDamage <- N2SE.Armored.OnTakeDamage;
    };

    N2SE.Armored.Init <- function() {
        try { PrecacheModel(N2SE.Armored.Config.helmetModel, true); } catch (ex) {}
    };
}