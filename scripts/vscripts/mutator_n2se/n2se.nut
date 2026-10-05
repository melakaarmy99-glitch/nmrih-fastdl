if (!("N2SE" in getroottable())) {
    ::N2SE <- {
        debug = true,
        D_NU = 3,
        REL_PRIORITY = 99,
        DMG_INFECT = 65536
    };

    if (!("__sv_n2se_enabled_registered" in getroottable())) {
        Convars.RegisterConvar("sv_n2se_enabled", "1",
            "Master switch for N2SE (0=disable all, 1=enable)", 0);
        getroottable().__sv_n2se_enabled_registered <- true;
    }

    if (!("__sv_n2se_module_enabled_registered" in getroottable())) {
        Convars.RegisterConvar("sv_n2se_armored_enabled",  "1", "Enable Armored (National Guard) zombies", 0);
        Convars.RegisterConvar("sv_n2se_blood_enabled",    "1", "Enable Blood zombies", 0);
        Convars.RegisterConvar("sv_n2se_swat_enabled",     "1", "Enable SWAT zombies", 0);
        Convars.RegisterConvar("sv_n2se_builder_enabled",  "1", "Enable Builder zombies", 0);
        Convars.RegisterConvar("sv_n2se_patient_enabled",  "1", "Enable Patient zombies", 0);
        Convars.RegisterConvar("sv_n2se_fireman_enabled",  "1", "Enable Fireman zombies", 0);
        Convars.RegisterConvar("sv_n2se_officer_enabled",  "1", "Enable Officer zombies", 0);
        Convars.RegisterConvar("sv_n2se_survivor_enabled", "1", "Enable Survivor zombies", 0);
        getroottable().__sv_n2se_module_enabled_registered <- true;
    }

    if (!("__sv_gasmask_enabled_registered" in getroottable())) {
        Convars.RegisterConvar("sv_gasmask_enabled", "1",
            "Enable/disable GasMask and Rotten", 0);
        getroottable().__sv_gasmask_enabled_registered <- true;
    }

    if (!("__sv_n2se_spawner_registered" in getroottable())) {
        Convars.RegisterConvar("sv_n2se_spawn_chance", "8",
            "Base chance (%) for a zombie to roll a special type", 0);
        Convars.RegisterConvar("sv_n2se_spawn_chance_nightmare", "24",
            "Base chance (%) on Nightmare difficulty", 0);
        Convars.RegisterConvar("sv_n2se_loot_enabled", "1",
            "Enable/disable loot drops from special zombies (0=off, 1=on)", 0);
        Convars.RegisterConvar("sv_n2se_loot_chance", "8",
            "Loot drop chance (%) for special zombies", 0);
        Convars.RegisterConvar("sv_n2se_cleanup_distance", "2500",
            "Distance (units) beyond which extra N2SE spawns get removed. 0=disable.", 0);
        getroottable().__sv_n2se_spawner_registered <- true;
    }

    N2SE.IsMaster <- function() {
        try { return Convars.GetFloat("sv_n2se_enabled") > 0.0; }
        catch (ex) { return true; }
    };

    N2SE.IsModOn <- function(name) {
        if (!N2SE.IsMaster()) return false;
        try { return Convars.GetFloat("sv_n2se_" + name + "_enabled") > 0.0; }
        catch (ex) { return true; }
    };

    N2SE.IsGasmaskOn <- function() {
        if (!N2SE.IsMaster()) return false;
        try { return Convars.GetFloat("sv_gasmask_enabled") > 0.0; }
        catch (ex) { return false; }
    };

    N2SE.IsLootEnabled <- function() {
        try { return Convars.GetFloat("sv_n2se_loot_enabled") > 0.0; }
        catch (ex) { return true; }
    };

    N2SE.GetLootChance <- function() {
        local c = 8.0;
        try { c = Convars.GetFloat("sv_n2se_loot_chance"); }
        catch (ex) {}
        if (c < 0.0) c = 0.0;
        return c;
    };

    N2SE.IsNightmare <- function() {
        local diff = Convars.GetStr("sv_difficulty");
        return diff != null && diff.tolower() == "nightmare";
    };

    N2SE.Log <- function(m) { if (N2SE.debug) printl("[N2SE] " + m); };

    N2SE.SafeKill <- function(e) {
        if (e == null || !e.IsValid()) return;
        try { e.AcceptInput("Kill", "", null, null); return; } catch (ex) {}
        try { e.Destroy(); return; } catch (ex) {}
        try { EntFireByHandle(e, "Kill", "", 0, null, null); return; } catch (ex) {}
    };

    N2SE.Calibers <- {
        ["fa_m92fs"] = "9mm", ["fa_glock17"] = "9mm", ["fa_mkiii"] = "22lr",
        ["fa_1911"] = "45acp", ["fa_sw686"] = "357",
        ["fa_fnfal"] = "308", ["fa_sako85"] = "308", ["fa_sako85_ironsights"] = "308",
        ["fa_cz858"] = "762mm", ["fa_sks"] = "762mm", ["fa_sks_nobayo"] = "762mm",
        ["fa_winchester1892"] = "357", ["fa_m16a4"] = "556", ["fa_m16a4_carryhandle"] = "556",
        ["fa_1022"] = "22lr", ["fa_1022_25mag"] = "22lr", ["fa_jae700"] = "308",
        ["fa_mp5a3"] = "9mm", ["fa_mac10"] = "45acp",
        ["fa_sv10"] = "12gauge", ["fa_500a"] = "12gauge", ["fa_superx3"] = "12gauge", ["fa_870"] = "12gauge"
    };

    N2SE.cal   <- function(wc) { return (wc in N2SE.Calibers) ? N2SE.Calibers[wc] : null; };
    N2SE.rifle <- function(c) { return c != null && (c == "308" || c == "762mm" || c == "556"); };
    N2SE.sks   <- function(wc) { return wc == "fa_sks" || wc == "fa_sks_nobayo"; };

    N2SE.impactSounds <- [
        "physics/metal/metal_solid_impact_bullet1.wav",
        "physics/metal/metal_solid_impact_bullet2.wav",
        "physics/metal/metal_solid_impact_bullet3.wav",
        "physics/metal/metal_solid_impact_bullet4.wav",
        "physics/metal/metal_solid_impact_bullet5.wav"
    ];
    N2SE.impactParticle <- "impact_metal_extras_2";

    N2SE.PlayImpact <- function(v) {
        local p = v.GetOrigin() + Vector(0, 0, 65);
        local s = N2SE.impactSounds[RandomInt(0, N2SE.impactSounds.len() - 1)];
        try { EmitSoundOn(s, v); } catch (ex) { try { EmitSound(s, p); } catch (ex2) {} }
        try { DispatchParticleEffect(N2SE.impactParticle, p, Vector(0, 0, 0)); } catch (ex) {}
    };

    N2SE.HeadSplit <- function(v) {
        try { v.AcceptInput("HeadSplit", "", null, null); return; } catch (ex) {}
        try { EntFireByHandle(v, "HeadSplit", "", 0, null, null); } catch (ex) {}
    };

    N2SE.DealDamage <- function(v, atk, d) {
        if (d <= 0) return;
        try {
            local di = CreateDamageInfo(atk, atk, Vector(0,0,0), v.GetOrigin(), d, 0);
            if (di) { v.TakeDamage(di); DestroyDamageInfo(di); }
        } catch (ex) {}
    };

    N2SE.GetRenderColor <- function(e) {
        local cR = 255, cG = 255, cB = 255;
        if (e == null || !e.IsValid()) return { r = cR, g = cG, b = cB };
        try {
            local packed = NetProps.GetPropInt(e, "m_clrRender");
            if (packed != 0) {
                cR = packed & 0xFF;
                cG = (packed >> 8) & 0xFF;
                cB = (packed >> 16) & 0xFF;
            }
        } catch (ex) {}
        return { r = cR, g = cG, b = cB };
    };

    N2SE.ApplyRenderColor <- function(e, r, g, b) {
        if (e == null || !e.IsValid()) return;
        try { e.SetRenderColor(r, g, b); return; } catch (ex) {}
        try {
            local packed = r | (g << 8) | (b << 16) | (255 << 24);
            NetProps.SetPropInt(e, "m_clrRender", packed);
        } catch (ex2) {}
    };

    N2SE.HookPlayer <- function(p) {
        if (p == null || !p.IsValid()) return;
        try { p.ValidateScriptScope(); } catch (ex) { return; }
        local sc = null;
        try { sc = p.GetScriptScope(); } catch (ex) { return; }
        if (sc == null) return;
        if ("N2SEHooked" in sc) return;
        sc.N2SEHooked <- true;

        if (!("N2SEBiteImmune" in sc)) sc.N2SEBiteImmune <- false;
        if (!("N2SEBiteImmuneSource" in sc)) sc.N2SEBiteImmuneSource <- -1;

        local prev = null;
        if ("OnTakeDamage" in sc) prev = sc.OnTakeDamage;

        sc.OnTakeDamage <- function() {
            try {
                local selfScope = null;
                try { selfScope = self.GetScriptScope(); } catch (ex) {}
                if (selfScope != null
                    && ("N2SEBiteImmune" in selfScope)
                    && selfScope.N2SEBiteImmune) {
                    local di = null;
                    try { di = info; } catch (ex) {}
                    if (di != null) {
                        local atk = null;
                        try { atk = di.GetAttacker(); } catch (ex) {}
                        if (atk != null && atk.IsValid()) {
                            local cls = "";
                            try { cls = atk.GetClassname(); } catch (ex) {}
                            if (cls.find("npc_nmrih") == 0) {
                                local act = "";
                                try { act = atk.GetActivity(); } catch (ex) {}
                                local isBite = false;
                                if (act != null && act != "") {
                                    if (act.find("GRAB") != null) isBite = true;
                                    if (act.find("EAT")  != null) isBite = true;
                                    if (act.find("BITE") != null) isBite = true;
                                }
                                if (isBite) return false;
                            }
                        }
                    }
                }
            } catch (ex) {}

            try {
                local di = null;
                try { di = info; } catch (ex) {}
                if (di != null) {
                    local atk = null;
                    try { atk = di.GetAttacker(); } catch (ex) {}
                    if (atk != null && atk.IsValid()) {
                        local cls = "";
                        try { cls = atk.GetClassname(); } catch (ex) {}
                        if (cls.find("npc_nmrih") == 0) {
                            local act = "";
                            try { act = atk.GetActivity(); } catch (ex) {}
                            local isBite = false;
                            if (act != null && act != "") {
                                if (act.find("GRAB") != null) isBite = true;
                                if (act.find("EAT")  != null) isBite = true;
                                if (act.find("BITE") != null) isBite = true;
                            }
                            if (isBite) {
                                local aid = -1;
                                try { aid = atk.entindex(); } catch (ex) {}
                                local isMuzzled = false;
                                if (aid > 0) {
                                    try {
                                        if (aid in ::N2SE.Swat.MuzzledSet) isMuzzled = true;
                                    } catch (ex) {}
                                }
                                if (!isMuzzled) {
                                    try {
                                        local asc = atk.GetScriptScope();
                                        if (asc != null && ("IsMuzzled" in asc) && asc.IsMuzzled) isMuzzled = true;
                                    } catch (ex) {}
                                }
                                if (!isMuzzled) {
                                    try {
                                        local hb = atk.FindBodygroupByName("head");
                                        if (hb >= 0 && atk.GetBodygroup(hb) == 0) isMuzzled = true;
                                    } catch (ex) {}
                                }
                                if (isMuzzled) return false;
                            }
                        }
                    }
                }
            } catch (ex) {}

            try {
                local di = null;
                try { di = info; } catch (ex) {}
                if (di != null) {
                    local atk = null;
                    try { atk = di.GetAttacker(); } catch (ex) {}
                    if (atk != null && atk.IsValid()) {
                        local cls = "";
                        try { cls = atk.GetClassname(); } catch (ex) {}
                        if (cls.find("npc_nmrih") == 0) {
                            local isBlood = false;
                            try { isBlood = ::N2SE.Blood.IsBloodEntity(atk); } catch (ex) {}
                            if (isBlood) {
                                local orig = 0;
                                try { orig = di.GetDamage(); } catch (ex) {}
                                local mult = 1.25;
                                try { mult = ::N2SE.Blood.GetDamageMult(); } catch (ex) {}
                                try { di.SetDamage(orig * mult); } catch (ex) {}
                            }
                        }
                    }
                }
            } catch (ex) {}

            try {
                local di = null;
                try { di = info; } catch (ex) {}
                if (di != null) {
                    local atk = null;
                    try { atk = di.GetAttacker(); } catch (ex) {}
                    if (atk != null && atk.IsValid()) {
                        local asc = null;
                        try { asc = atk.GetScriptScope(); } catch (ex) {}
                        if (asc != null && ("GasInfected" in asc) && asc.GasInfected) {
                            try {
                                local dt = di.GetDamageType();
                                di.SetDamageType(dt | N2SE.DMG_INFECT);
                            } catch (ex) {}
                        }
                    }
                }
            } catch (ex) {}

            if (prev != null) {
                try { return prev(); } catch (ex) { return true; }
            }
            return true;
        };
    };

    N2SE.PrecacheAll <- function(sounds) {
        local dummy = Entities.CreateByClassname("info_target");
        if (dummy == null) return;
        dummy.SetOrigin(Vector(0, 0, 0));
        try { DispatchSpawn(dummy); } catch (ex) {}
        local hasScript = ("PrecacheSoundScript" in dummy);
        local hasSound  = ("PrecacheSound" in dummy);
        foreach (s in sounds) {
            local ok = false;
            if (hasScript) { try { dummy.PrecacheSoundScript(s); ok = true; } catch (ex) {} }
            if (!ok && hasSound) { try { dummy.PrecacheSound(s); ok = true; } catch (ex) {} }
        }
        N2SE.SafeKill(dummy);
    };

    IncludeScript("mutator_n2se/n2se_manager");
    IncludeScript("mutator_n2se/n2se_armored");
    IncludeScript("mutator_n2se/n2se_rotten");
    IncludeScript("mutator_n2se/n2se_blood");
    IncludeScript("mutator_n2se/n2se_swat");
    IncludeScript("mutator_n2se/n2se_builder");
    IncludeScript("mutator_n2se/n2se_patient");
    IncludeScript("mutator_n2se/n2se_fireman");
    IncludeScript("mutator_n2se/n2se_officer");
    IncludeScript("mutator_n2se/n2se_survivor");
    IncludeScript("mutator_n2se/n2se_radio");
    IncludeScript("mutator_n2se/gasmask");

    N2SE.Spawner <- {};
    N2SE.Spawner.ModKey <- "spawner";

    N2SE.Spawner.Config <- {
        spawnChanceDefault   = 8.0,
        spawnChanceNightmare = 24.0,
        spawnDelay           = 3.0,
        typeWeights = {
            swat     = 6,
            fireman  = 9,
            builder  = 12,
            officer  = 15,
            patient  = 15,
            survivor = 8,
            rotten   = 3
        }
    };

    N2SE.Spawner.Pending    <- {};
    N2SE.Spawner.Counter    <- 0;
    N2SE.Spawner.Generating <- false;

    N2SE.Spawner.GetSpawnChance <- function() {
        local cv = N2SE.IsNightmare()
            ? "sv_n2se_spawn_chance_nightmare"
            : "sv_n2se_spawn_chance";
        try {
            local v = Convars.GetFloat(cv);
            if (v >= 0.0) return v;
        } catch (ex) {}
        return N2SE.IsNightmare()
            ? N2SE.Spawner.Config.spawnChanceNightmare
            : N2SE.Spawner.Config.spawnChanceDefault;
    };

    N2SE.Spawner.IsTypeEnabled <- function(key) {
        if (key == "rotten") return N2SE.IsGasmaskOn();
        return N2SE.IsModOn(key);
    };

    N2SE.Spawner.HasRolled <- function(z) {
        if (z == null || !z.IsValid()) return true;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("N2SE_SpawnRolled" in sc) && sc.N2SE_SpawnRolled) return true;
        } catch (ex) {}
        return false;
    };

    N2SE.Spawner.MarkRolled <- function(z) {
        if (z == null || !z.IsValid()) return;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.N2SE_SpawnRolled <- true;
        } catch (ex) {}
    };

    N2SE.Spawner.PickType <- function() {
        local pool = [];
        local total = 0;
        foreach (key, w in N2SE.Spawner.Config.typeWeights) {
            if (!N2SE.Spawner.IsTypeEnabled(key)) continue;
            if (w <= 0) continue;
            pool.append({ key = key, w = w });
            total += w;
        }
        if (total <= 0 || pool.len() == 0) return null;

        local roll = RandomInt(1, total);
        local cum  = 0;
        foreach (p in pool) {
            cum += p.w;
            if (roll <= cum) return p.key;
        }
        return pool[0].key;
    };

    N2SE.Spawner.IsRottenEntity <- function(z) {
        if (z == null || !z.IsValid()) return false;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("Rotten" in sc) && sc.Rotten) return true;
        } catch (ex) {}
        if (("Rotten" in N2SE) && ("IsRottenEntity" in N2SE.Rotten)) {
            try { return N2SE.Rotten.IsRottenEntity(z); } catch (ex) {}
        }
        return false;
    };

    N2SE.Spawner.ApplyBloodChance <- function(z) {
        if (z == null || !z.IsValid()) return;
        if (!N2SE.IsModOn("blood")) return;
        if (!("Blood" in N2SE)) return;
        if (!("Make" in N2SE.Blood)) return;
        if (!("GetSpawnChance" in N2SE.Blood)) return;

        if (N2SE.Spawner.IsRottenEntity(z)) return;

        local isBlood = false;
        if ("IsBloodEntity" in N2SE.Blood) {
            try { isBlood = N2SE.Blood.IsBloodEntity(z); } catch (ex) {}
        }
        if (isBlood) return;

        local chance = 0;
        try { chance = N2SE.Blood.GetSpawnChance(); } catch (ex) { return; }
        if (chance <= 0) return;
        if (RandomInt(1, 100) > chance) return;

        try { N2SE.Blood.Make(z); } catch (ex) {}
    };

    N2SE.Spawner.SpawnNew <- function(key, pos, angles) {
        if (key == "swat"     && "Swat"     in N2SE) return N2SE.Swat.SpawnCompanion(pos, angles);
        if (key == "builder"  && "Builder"  in N2SE) return N2SE.Builder.SpawnCompanion(pos, angles);
        if (key == "patient"  && "Patient"  in N2SE) return N2SE.Patient.SpawnCompanion(pos, angles);
        if (key == "fireman"  && "Fireman"  in N2SE) return N2SE.Fireman.SpawnCompanion(pos, angles);
        if (key == "officer"  && "Officer"  in N2SE) return N2SE.Officer.SpawnCompanion(pos, angles);
        if (key == "survivor" && "Survivor" in N2SE) return N2SE.Survivor.SpawnCompanion(pos, angles);
        if (key == "rotten"   && "Rotten"   in N2SE) return N2SE.Rotten.SpawnRottenAt(pos, angles);
        return null;
    };

    N2SE.Spawner.OnZombieSpawned <- function(e) {
        if (e == null || !e.IsValid()) return;
        if (!N2SE.IsMaster()) return;
        if (N2SE.Spawner.Generating) return;

        local cls = "";
        try { cls = e.GetClassname(); } catch (ex) { return; }
        if (cls.find("npc_nmrih") != 0) return;

        if (N2SE.Spawner.HasRolled(e)) return;

        N2SE.Spawner.MarkRolled(e);

        N2SE.Spawner.ApplyBloodChance(e);

        local chance = N2SE.Spawner.GetSpawnChance();
        if (chance <= 0.0) return;
        if (RandomFloat(0.0, 100.0) > chance) return;

        local key = N2SE.Spawner.PickType();
        if (key == null) return;

        local pos = null, ang = null;
        try { pos = e.GetOrigin(); } catch (ex) { return; }
        try { ang = e.GetAngles(); } catch (ex) {}
        if (pos == null) return;

        N2SE.Spawner.ScheduleCompanion(key, pos, ang);
    };

    N2SE.Spawner.ScheduleCompanion <- function(key, pos, angles) {
        N2SE.Spawner.Counter = N2SE.Spawner.Counter + 1;
        local id = N2SE.Spawner.Counter;
        N2SE.Spawner.Pending[id] <- { key = key, pos = pos, angles = angles };
        try {
            EntFire("worldspawn", "RunScriptCode",
                "::N2SE.Spawner.ExecuteDelayedSpawn(" + id + ")",
                N2SE.Spawner.Config.spawnDelay, null);
        } catch (ex) {}
    };

    N2SE.Spawner.ExecuteDelayedSpawn <- function(id) {
        if (!(id in N2SE.Spawner.Pending)) return;
        local rec = N2SE.Spawner.Pending[id];
        delete N2SE.Spawner.Pending[id];
        if (rec == null) return;

        N2SE.Spawner.Generating = true;
        local z = null;
        try { z = N2SE.Spawner.SpawnNew(rec.key, rec.pos, rec.angles); }
        catch (ex) {}
        N2SE.Spawner.Generating = false;

        if (z != null && z.IsValid()) {
            N2SE.Spawner.MarkRolled(z);
            N2SE.Spawner.ApplyBloodChance(z);
            if (("Manager" in N2SE) && ("MarkExtraSpawned" in N2SE.Manager)) {
                try { N2SE.Manager.MarkExtraSpawned(z); } catch (ex) {}
            }
        }
    };

    local toCache = [];
    foreach (s in N2SE.impactSounds) toCache.append(s);
    if (N2SE.IsGasmaskOn() && ("Rotten" in N2SE) && ("Config" in N2SE.Rotten)) {
        foreach (s in N2SE.Rotten.Config.soundList) toCache.append(s);
        toCache.append(N2SE.Rotten.Config.runnerAlertSound);
    }
    if (N2SE.IsModOn("fireman") && ("Fireman" in N2SE) && ("Config" in N2SE.Fireman)) {
        foreach (s in N2SE.Fireman.Config.impactSounds) toCache.append(s);
        toCache.append(N2SE.Fireman.Config.hitSound);
        toCache.append(N2SE.Fireman.Config.tankLeakSound);
        toCache.append(N2SE.Fireman.Config.tankExplosionSound);
    }
    N2SE.PrecacheAll(toCache);

    if (N2SE.IsModOn("armored")) {
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Armored);
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Armored);
    }
    if (N2SE.IsGasmaskOn()) {
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Rotten);
    }
    if (N2SE.IsModOn("blood")) {
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Blood);
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Blood);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Blood);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Blood);
    }
    if (N2SE.IsModOn("swat")) {
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Swat);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Swat);
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Swat);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Swat);
    }
    if (N2SE.IsModOn("builder")) {
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Builder);
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Builder);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Builder);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Builder);
    }
    if (N2SE.IsModOn("patient")) {
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Patient);
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Patient);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Patient);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Patient);
    }
    if (N2SE.IsModOn("fireman")) {
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Fireman);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Fireman);
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Fireman);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Fireman);
    }
    if (N2SE.IsModOn("officer")) {
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Officer);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Officer);
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Officer);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Officer);
    }
    if (N2SE.IsModOn("survivor")) {
        N2SE.Manager.Register("npc_nmrih_shamblerzombie", N2SE.Survivor);
        N2SE.Manager.Register("npc_nmrih_kidzombie",      N2SE.Survivor);
        N2SE.Manager.Register("npc_nmrih_runnerzombie",   N2SE.Survivor);
        N2SE.Manager.Register("npc_nmrih_basezombie",     N2SE.Survivor);
    }

    if (N2SE.IsMaster()) N2SE.Manager.Init();
    if (N2SE.IsModOn("armored"))  N2SE.Armored.Init();
    if (N2SE.IsGasmaskOn()) {
        N2SE.Rotten.Init();
        if (("GasMask" in getroottable()) && ("Init" in GasMask)) GasMask.Init();
    }
    if (N2SE.IsModOn("blood"))    N2SE.Blood.Init();
    if (N2SE.IsModOn("swat"))     N2SE.Swat.Init();
    if (N2SE.IsModOn("builder"))  N2SE.Builder.Init();
    if (N2SE.IsModOn("patient"))  N2SE.Patient.Init();
    if (N2SE.IsModOn("fireman"))  N2SE.Fireman.Init();
    if (N2SE.IsModOn("officer"))  N2SE.Officer.Init();
    if (N2SE.IsModOn("survivor")) N2SE.Survivor.Init();

    local e = null;
    while ((e = Entities.FindByClassname(e, "npc_nmrih_runnerzombie")) != null) { N2SE.Spawner.MarkRolled(e); N2SE.Manager.Dispatch(e); }
    e = null;
    while ((e = Entities.FindByClassname(e, "npc_nmrih_shamblerzombie")) != null) { N2SE.Spawner.MarkRolled(e); N2SE.Manager.Dispatch(e); }
    e = null;
    while ((e = Entities.FindByClassname(e, "npc_nmrih_kidzombie")) != null) { N2SE.Spawner.MarkRolled(e); N2SE.Manager.Dispatch(e); }
    e = null;
    while ((e = Entities.FindByClassname(e, "npc_nmrih_basezombie")) != null) { N2SE.Spawner.MarkRolled(e); N2SE.Manager.Dispatch(e); }
    e = null;
    while ((e = Entities.FindByClassname(e, "player")) != null) N2SE.HookPlayer(e);

    N2SE.Log("NMRIH2 STYLE ZOMBIE EXPANSION loaded.");
}