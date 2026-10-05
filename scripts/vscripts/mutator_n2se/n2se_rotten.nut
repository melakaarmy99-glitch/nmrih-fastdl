if (!("Rotten" in N2SE)) {
    N2SE.Rotten <- {};
    N2SE.Rotten.ModKey <- "gasmask";

    N2SE.Rotten.Config <- {
        model                = "models/nmr_zombie/burned/burn_r.mdl",
        chance               = 2,
        chanceNightmare      = 4,
        health               = 200,
        smokeZOffset         = 15.0,

        spawnClass           = "npc_nmrih_shamblerzombie",
        spawnDelay           = 3.0,
        spawnCooldown        = 6.0,
        spawnMaxAttempts     = 5,

        gasRadius            = 72.0,
        gasDuration          = 15.0,
        gasDurationNightmare = 30.0,
        gasInfectMin         = 15,
        gasInfectMax         = 45,
        maxGasInfected       = 8,

        angryAct             = "ACT_IDLE_ON_FIRE",
        angryCooldown        = 60.0,
        soundPlayTime        = 1.2,
        soundGapTime         = 1.0,
        becomeRunnerRadius   = 1024.0,

        nearbyAlertRadius    = 256.0,
        noiseAlertRadius     = 512.0,
        maxHeightDiff        = 200.0,

        fireCooldownReduce   = 3.0,
        cooldownReduceRadius = 512.0,

        attackDamage         = 5,

        deathSound           = "screamer/rottenhurt1.wav",

        soundList = [
            "screamer/rottensound3.wav",
            "screamer/rottensound2.wav",
            "screamer/rottensound1.wav"
        ],
        runnerAlertSound = "npc/nmr_zomb_runner_male/zomb_runner_male1-alert-15.wav"
    };

    N2SE.Rotten.gasInfectedSet  <- {};
    N2SE.Rotten.NextSpawnTime   <- 0.0;
    N2SE.Rotten.RottenEntitySet <- {};
    N2SE.Rotten.GasSpawnedSet   <- {};
    N2SE.Rotten.PendingSpawns   <- {};
    N2SE.Rotten.PendingCounter  <- 0;

    N2SE.Rotten.ScreamerActive  <- -1;

    N2SE.Rotten.FireCode <- function(code, delay) {
        try { EntFire("worldspawn", "RunScriptCode", code, delay, null); return true; }
        catch (ex) { return false; }
    };

    N2SE.Rotten.GetGasDuration <- function() {
        if (N2SE.IsNightmare()) return N2SE.Rotten.Config.gasDurationNightmare;
        return N2SE.Rotten.Config.gasDuration;
    };

    N2SE.Rotten.GetGasInfectRange <- function() {
        local cfg = N2SE.Rotten.Config;
        if (N2SE.IsNightmare()) {
            return { min = cfg.gasInfectMin * 2, max = cfg.gasInfectMax * 2 };
        }
        return { min = cfg.gasInfectMin, max = cfg.gasInfectMax };
    };

    N2SE.Rotten.CountGasInfected <- function() {
        local n = 0;
        foreach (i, _ in N2SE.Rotten.gasInfectedSet) n++;
        return n;
    };

    N2SE.Rotten.GetAllRottenNear <- function(pos, radius) {
        if (pos == null) return [];
        local list = [];
        local classes = [
            "npc_nmrih_runnerzombie",
            "npc_nmrih_shamblerzombie",
            "npc_nmrih_kidzombie",
            "npc_nmrih_basezombie"
        ];
        foreach (cls in classes) {
            local z = null;
            while ((z = Entities.FindByClassnameWithin(z, cls, pos, radius)) != null) {
                if (!z.IsValid()) continue;
                local sc = null;
                try { sc = z.GetScriptScope(); } catch (ex) {}
                if (sc != null && ("Rotten" in sc) && sc.Rotten) {
                    list.append(z);
                }
            }
        }
        return list;
    };

    N2SE.Rotten.HasPlayerNear <- function(z, radius) {
        if (z == null || !z.IsValid()) return false;
        local zp = null;
        try { zp = z.GetOrigin(); } catch (ex) { return false; }
        if (zp == null) return false;

        local p = null;
        while ((p = Entities.FindByClassnameWithin(p, "player", zp, radius)) != null) {
            if (!p.IsValid() || !p.IsAlive()) continue;
            local pp = null;
            try { pp = p.GetOrigin(); } catch (ex) { continue; }
            if (pp == null) continue;
            if (fabs(zp.z - pp.z) > N2SE.Rotten.Config.maxHeightDiff) continue;
            return true;
        }
        return false;
    };

    N2SE.Rotten.AlertFromNoise <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zsc = null;
        try { zsc = z.GetScriptScope(); } catch (ex) {}
        if (zsc == null) return false;
        if (!("AngryDriver" in zsc)) return false;
        local drv = zsc.AngryDriver;
        if (drv == null || !drv.IsValid()) return false;
        local dsc = null;
        try { dsc = drv.GetScriptScope(); } catch (ex) {}
        if (dsc == null) return false;

        dsc.NoiseAlerted <- true;
        return true;
    };

    N2SE.Rotten.IsRottenEntity <- function(e) {
        if (e == null || !e.IsValid()) return false;
        local zidx = -1;
        try { zidx = e.entindex(); } catch (ex) {}
        if (zidx > 0 && (zidx in N2SE.Rotten.RottenEntitySet)) return true;
        try {
            local sc = e.GetScriptScope();
            if (sc != null && ("Rotten" in sc) && sc.Rotten) return true;
        } catch (ex) {}
        return false;
    };

    N2SE.Rotten.IsScreamerBusy <- function(zidx) {
        if (N2SE.Rotten.ScreamerActive <= 0) return false;
        if (zidx > 0 && N2SE.Rotten.ScreamerActive == zidx) return false;
        local z = EntIndexToHScript(N2SE.Rotten.ScreamerActive);
        if (z == null || !z.IsValid()) return false;
        local zsc = null;
        try { zsc = z.GetScriptScope(); } catch (ex) {}
        if (zsc == null || !("AngryDriver" in zsc)) return false;
        local drv = zsc.AngryDriver;
        if (drv == null || !drv.IsValid()) return false;
        local dsc = null;
        try { dsc = drv.GetScriptScope(); } catch (ex) {}
        if (dsc == null) return false;
        if (!("AngryState" in dsc)) return false;
        return dsc.AngryState == 1;
    };

    N2SE.Rotten.ReleaseScreamerLock <- function(zidx) {
        if (zidx > 0 && N2SE.Rotten.ScreamerActive == zidx)
            N2SE.Rotten.ScreamerActive = -1;
    };

    N2SE.Rotten.PlaySound <- function(z, snd) {
        if (z == null || !z.IsValid()) return false;
        local done = false;
        try { EmitSoundOn(snd, z); done = true; } catch (ex) {}
        if (!done) { try { EmitSound(snd, z.GetOrigin()); done = true; } catch (ex) {} }
        if (!done && "EmitSound" in z) { try { z.EmitSound(snd); done = true; } catch (ex) {} }
        return done;
    };

    N2SE.Rotten.PlayDeathSound <- function(z) {
        if (z == null || !z.IsValid()) return;
        local snd = N2SE.Rotten.Config.deathSound;
        local ok = false;
        try { EmitSoundOn(snd, z); ok = true; } catch (ex) {}
        if (!ok) { try { EmitSound(snd, z.GetOrigin()); } catch (ex) {} }
    };

    N2SE.Rotten.AddSmoke <- function(z) {
        if (z == null || !z.IsValid()) return;
        local uid = UniqueString();
        local smokeName = "n2se_zsmoke_" + uid;
        local o = z.GetOrigin() + Vector(0, 0, N2SE.Rotten.Config.smokeZOffset);

        local smoke = Entities.CreateByClassname("env_smokestack");
        if (smoke == null) return;
        smoke.SetOrigin(o);
        smoke.__KeyValueFromString("targetname", smokeName);
        smoke.__KeyValueFromString("SmokeMaterial", "particle/SmokeStack.vmt");
        smoke.__KeyValueFromString("rendercolor", "128 128 0");
        smoke.__KeyValueFromInt("renderamt", 40);
        smoke.__KeyValueFromFloat("BaseSpread", 12.0);
        smoke.__KeyValueFromInt("SpreadSpeed", 10);
        smoke.__KeyValueFromFloat("Speed", 20.0);
        smoke.__KeyValueFromFloat("StartSize", 15.0);
        smoke.__KeyValueFromFloat("EndSize", 40.0);
        smoke.__KeyValueFromFloat("Rate", 100.0);
        smoke.__KeyValueFromFloat("JetLength", 40.0);
        smoke.__KeyValueFromInt("WindSpeed", 0);
        smoke.__KeyValueFromFloat("WindAngle", RandomFloat(0, 360));
        smoke.__KeyValueFromFloat("Twist", 10.0);
        smoke.__KeyValueFromFloat("Roll", 10.0);

        try { DispatchSpawn(smoke); } catch (ex) {}
        try { smoke.AcceptInput("TurnOn", "", "", 0.0); } catch (ex) {}

        try {
            smoke.ValidateScriptScope();
            local sc = smoke.GetScriptScope();
            if (sc != null) {
                sc.ParentZombie <- z;
                sc.SmokeThink <- function() {
                    local s = self;
                    if (s == null || !s.IsValid()) return -1;
                    local sc2 = null;
                    try { sc2 = s.GetScriptScope(); } catch (ex) { return -1; }
                    if (sc2 == null) return -1;
                    local zz = ("ParentZombie" in sc2) ? sc2.ParentZombie : null;
                    if (zz == null || !zz.IsValid()) { N2SE.SafeKill(s); return -1; }
                    if (!N2SE.IsGasmaskOn()) return 0.3;
                    local oo = zz.GetOrigin() + Vector(0, 0, 15.0);
                    try { s.SetOrigin(oo); } catch (ex) {}
                    try { s.SetAbsOrigin(oo); } catch (ex) {}
                    return 0.03;
                };
                AddThinkToEnt(smoke, "SmokeThink");
            }
        } catch (ex) {}

        try {
            local zsc = z.GetScriptScope();
            if (zsc != null) {
                if (!("SmokeNames" in zsc)) zsc.SmokeNames <- [];
                zsc.SmokeNames.append(smokeName);
            }
        } catch (ex) {}
    };

    N2SE.Rotten.SetupTargetName <- function(z) {
        if (z == null || !z.IsValid()) return;
        local name = "n2se_rotten_" + z.entindex() + "_" + UniqueString();
        try { z.AcceptInput("AddOutput", "targetname " + name, null, null); } catch (ex) {
            try { EntFireByHandle(z, "AddOutput", "targetname " + name, 0, null, null); } catch (ex2) {}
        }
        local sc = z.GetScriptScope();
        if (sc != null) sc.TgtName <- name;
    };

    N2SE.Rotten.CreateAngrySeq <- function(z) {
        if (z == null || !z.IsValid()) return null;
        local zsc = z.GetScriptScope();
        if (zsc == null || !("TgtName" in zsc)) return null;

        if (("RottenSeqName" in zsc) && zsc.RottenSeqName != "") return null;

        local seq = Entities.CreateByClassname("scripted_sequence");
        if (seq == null) return null;

        local seqName = "n2se_angryseq_" + z.entindex() + "_" + UniqueString();

        seq.SetOrigin(z.GetOrigin());
        seq.SetAngles(z.GetAngles());
        seq.__KeyValueFromString("targetname", seqName);
        seq.__KeyValueFromString("m_iszEntity", zsc.TgtName);
        seq.__KeyValueFromInt("m_fMoveTo", 0);
        seq.__KeyValueFromFloat("m_flRadius", 2048.0);
        seq.__KeyValueFromInt("spawnflags", 96);
        seq.__KeyValueFromString("m_iszIdle", "");
        seq.__KeyValueFromString("m_iszEntry", "");
        seq.__KeyValueFromString("m_iszPlay", N2SE.Rotten.Config.angryAct);
        seq.__KeyValueFromString("m_iszPostIdle", "");
        seq.__KeyValueFromInt("m_bLoopActionSequence", 1);

        try { DispatchSpawn(seq); } catch (ex) {}
        if (!seq.IsValid()) return null;

        zsc.RottenSeqName <- seqName;

        return seq;
    };

    N2SE.Rotten.BeginSeqByName <- function(seqName) {
        if (seqName == null || seqName == "") return;
        try { EntFire(seqName, "BeginSequence", "", 0, null); } catch (ex) {}
    };

    N2SE.Rotten.BeginSeqForZombie <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local zsc = null;
        try { zsc = z.GetScriptScope(); } catch (ex) { return false; }
        if (zsc == null) return false;
        if (!("RottenSeqName" in zsc) || zsc.RottenSeqName == "") return false;
        N2SE.Rotten.BeginSeqByName(zsc.RottenSeqName);
        return true;
    };

    N2SE.Rotten.StopSeq <- function(seq) {
        if (seq == null || !seq.IsValid()) return;
        try { seq.AcceptInput("CancelSequence", "", null, null); } catch (ex) {}
        try { seq.AcceptInput("Kill", "", null, null); } catch (ex) {}
    };

    N2SE.Rotten.StopSeqByName <- function(seqName) {
        if (seqName == null || seqName == "") return;
        try { EntFire(seqName, "CancelSequence", "", 0, null); } catch (ex) {}
        try { EntFire(seqName, "Kill", "", 0.05, null); } catch (ex) {}
    };

    N2SE.Rotten.ReleaseSeq <- function(z) {
        if (z == null || !z.IsValid()) return;
        local zsc = null;
        try { zsc = z.GetScriptScope(); } catch (ex) {}
        if (zsc == null) return;
        if (("RottenSeqName" in zsc) && zsc.RottenSeqName != "") {
            N2SE.Rotten.StopSeqByName(zsc.RottenSeqName);
            zsc.RottenSeqName <- "";
        }
        try { NetProps.SetPropFloat(z, "m_flMaxSpeed", -1.0); } catch (ex) {}
    };

    N2SE.Rotten.InterruptAngry <- function(z, reason) {
        if (z == null || !z.IsValid()) return false;
        local zsc = null;
        try { zsc = z.GetScriptScope(); } catch (ex) {}
        if (zsc == null || !("AngryDriver" in zsc)) return false;
        local drv = zsc.AngryDriver;
        if (drv == null || !drv.IsValid()) return false;
        local dsc = null;
        try { dsc = drv.GetScriptScope(); } catch (ex) {}
        if (dsc == null || !("AngryState" in dsc)) return false;
        if (dsc.AngryState != 1) return false;

        dsc.AngryState <- 3;

        local zidx = -1;
        try { zidx = z.entindex(); } catch (ex) {}
        N2SE.Rotten.ReleaseScreamerLock(zidx);
        return true;
    };

    N2SE.Rotten.ReduceCooldown <- function(z, seconds) {
        if (z == null || !z.IsValid()) return false;
        local zsc = null;
        try { zsc = z.GetScriptScope(); } catch (ex) {}
        if (zsc == null) return false;
        if (!("Rotten" in zsc) || !zsc.Rotten) return false;
        if (!("AngryDriver" in zsc)) return false;
        local drv = zsc.AngryDriver;
        if (drv == null || !drv.IsValid()) return false;
        local dsc = null;
        try { dsc = drv.GetScriptScope(); } catch (ex) {}
        if (dsc == null) return false;
        if (!("AngryState" in dsc)) return false;
        if (dsc.AngryState != 2) return false;
        if (!("AngryCooldownEnd" in dsc)) return false;
        dsc.AngryCooldownEnd -= seconds;
        return true;
    };

    N2SE.Rotten.StartAngryThink <- function(z) {
        if (z == null || !z.IsValid()) return;
        local driver = Entities.CreateByClassname("info_target");
        if (driver == null) return;
        driver.SetOrigin(z.GetOrigin());
        try { DispatchSpawn(driver); } catch (ex) {}
        try { driver.ValidateScriptScope(); } catch (ex) { return; }

        local dsc = driver.GetScriptScope();
        if (dsc == null) return;
        dsc.Zombie           <- z;
        dsc.AngryState       <- 0;
        dsc.AngryPhase       <- 0;
        dsc.AngryNextTime    <- 0.0;
        dsc.AngryCooldownEnd <- 0.0;
        dsc.AngrySeq         <- null;
        dsc.TickCount        <- 0;
        dsc.EverScreamed     <- false;
        dsc.NoiseAlerted     <- false;

        dsc.N2SEAngryThink <- function() {
            local d = self;
            if (d == null || !d.IsValid()) return -1;
            local dsc2 = null;
            try { dsc2 = d.GetScriptScope(); } catch (ex) { return -1; }
            if (dsc2 == null) return -1;

            local z2 = dsc2.Zombie;
            if (z2 == null || !z2.IsValid()) {
                local staleIdx = -1;
                try { staleIdx = dsc2.ZombieIdx; } catch (ex) {}
                N2SE.Rotten.ReleaseScreamerLock(staleIdx);
                N2SE.SafeKill(d);
                return -1;
            }

            local zAlive = true;
            try { zAlive = z2.IsAlive(); } catch (ex) {}
            if (!zAlive) {
                local deadIdx = -1;
                try { deadIdx = z2.entindex(); } catch (ex) {}
                N2SE.Rotten.ReleaseScreamerLock(deadIdx);
                N2SE.SafeKill(d);
                return -1;
            }

            if (!N2SE.IsGasmaskOn()) return 0.5;

            local zidxSelf = -1;
            try { zidxSelf = z2.entindex(); } catch (ex) {}
            dsc2.ZombieIdx <- zidxSelf;

            dsc2.TickCount = dsc2.TickCount + 1;

            if (dsc2.AngryState == 2) return 1.0;

            if (dsc2.AngryState == 3) {
                N2SE.Rotten.ReleaseSeq(z2);
                N2SE.Rotten.ReleaseScreamerLock(zidxSelf);
                dsc2.AngryState <- 2;
                return 1.0;
            }

            if (dsc2.AngryState == 0) {
                local activated = false;
                if (dsc2.EverScreamed) activated = true;
                if (!activated && ("NoiseAlerted" in dsc2) && dsc2.NoiseAlerted) activated = true;
                if (!activated) {
                    if (N2SE.Rotten.HasPlayerNear(z2, N2SE.Rotten.Config.nearbyAlertRadius)) {
                        activated = true;
                    }
                }

                if (!activated) return 0.2;

                if (N2SE.Rotten.IsScreamerBusy(zidxSelf)) {
                    return 0.3;
                }

                dsc2.AngryState <- 1;
                dsc2.AngryPhase <- 0;
                dsc2.AngryNextTime <- Time();
                dsc2.EverScreamed <- true;
                dsc2.NoiseAlerted <- false;
                if (zidxSelf > 0) N2SE.Rotten.ScreamerActive = zidxSelf;

                try { NetProps.SetPropFloat(z2, "m_flMaxSpeed", 0.0); } catch (ex) {}
                try { z2.SetAbsVelocity(Vector(0, 0, 0)); } catch (ex) {}
                try { N2SE.Rotten.BeginSeqForZombie(z2); } catch (ex) {}

                return 0.2;
            }

            if (dsc2.AngryState == 1) {
                try { NetProps.SetPropFloat(z2, "m_flMaxSpeed", 0.0); } catch (ex) {}
                try { z2.SetAbsVelocity(Vector(0, 0, 0)); } catch (ex) {}

                local stillAlive = true;
                try { stillAlive = z2.IsAlive(); } catch (ex) {}
                if (!stillAlive) {
                    N2SE.Rotten.ReleaseSeq(z2);
                    N2SE.Rotten.ReleaseScreamerLock(zidxSelf);
                    N2SE.SafeKill(d);
                    return -1;
                }

                if (Time() >= dsc2.AngryNextTime) {
                    if (dsc2.AngryPhase < N2SE.Rotten.Config.soundList.len()) {
                        local snd = N2SE.Rotten.Config.soundList[dsc2.AngryPhase];
                        N2SE.Rotten.PlaySound(z2, snd);
                        dsc2.AngryPhase <- dsc2.AngryPhase + 1;
                        dsc2.AngryNextTime <- Time() + N2SE.Rotten.Config.soundPlayTime + N2SE.Rotten.Config.soundGapTime;
                    } else {
                        local finalAlive = true;
                        try { finalAlive = z2.IsAlive(); } catch (ex) {}
                        if (finalAlive) {
                            N2SE.Rotten.ConvertNearbyShambler(z2);
                        }
                        N2SE.Rotten.ReleaseSeq(z2);
                        N2SE.Rotten.ReleaseScreamerLock(zidxSelf);
                        dsc2.AngryState <- 2;
                        return 1.0;
                    }
                }
                return 0.1;
            }
            return 0.25;
        };

        AddThinkToEnt(driver, "N2SEAngryThink");
        try {
            local zsc = z.GetScriptScope();
            if (zsc != null) zsc.AngryDriver <- driver;
        } catch (ex) {}
    };

    N2SE.Rotten.RestoreHp <- function(zid, hp, maxHp) {
        local z = EntIndexToHScript(zid);
        if (z == null || !z.IsValid()) return;
        try { NetProps.SetPropInt(z, "m_iMaxHealth", maxHp); } catch (ex) {}
        try { NetProps.SetPropInt(z, "m_iHealth", hp); } catch (ex) {}
        try { z.SetHealth(hp); } catch (ex) {}
    };

    N2SE.Rotten.ConvertNearbyShambler <- function(z) {
        if (z == null || !z.IsValid()) return;

        local alive = true;
        try { alive = z.IsAlive(); } catch (ex) {}
        if (!alive) return;

        local pos = z.GetOrigin();
        local candidates = [];
        local e = null;
        while ((e = Entities.FindByClassnameWithin(e, "npc_nmrih_shamblerzombie", pos, N2SE.Rotten.Config.becomeRunnerRadius)) != null) {
            if (!e.IsValid()) continue;
            if (e == z) continue;
            try { if (!e.IsAlive()) continue; } catch (ex) { continue; }
            local esc = null;
            try { esc = e.GetScriptScope(); } catch (ex) {}
            if (esc != null && ("Rotten" in esc) && esc.Rotten) continue;
            candidates.append(e);
        }
        if (candidates.len() == 0) return;
        local pick = candidates[RandomInt(0, candidates.len() - 1)];

        local hpBefore = 0, maxHpBefore = 0;
        try { hpBefore = pick.GetHealth(); } catch (ex) {}
        try { maxHpBefore = NetProps.GetPropInt(pick, "m_iMaxHealth"); } catch (ex) {}
        if (maxHpBefore <= 0) maxHpBefore = hpBefore;
        local pickIdx = pick.entindex();

        local ok = false;
        try { if ("BecomeRunner" in pick) { pick.BecomeRunner(); ok = true; } } catch (ex) {}
        if (!ok) { try { pick.AcceptInput("BecomeRunner", "", null, null); ok = true; } catch (ex) {} }
        if (!ok) { try { EntFireByHandle(pick, "BecomeRunner", "", 0, null, null); ok = true; } catch (ex) {} }

        if (ok) {
            try { EmitSoundOn(N2SE.Rotten.Config.runnerAlertSound, pick); } catch (ex) {
                try { EmitSound(N2SE.Rotten.Config.runnerAlertSound, pick.GetOrigin()); } catch (ex2) {}
            }

            if (hpBefore > 0 && hpBefore != N2SE.Rotten.Config.health) {
                local code = "::N2SE.Rotten.RestoreHp(" + pickIdx + "," + hpBefore + "," + maxHpBefore + ")";
                EntFire("worldspawn", "RunScriptCode", code, 0.15, null);
            }
        }
    };

    N2SE.Rotten.Make <- function(z, fromGas) {
        if (z == null || !z.IsValid()) return;

        local zidx = -1;
        try { zidx = z.entindex(); } catch (ex) {}
        if (zidx > 0) N2SE.Rotten.RottenEntitySet[zidx] <- { fromGas = fromGas };

        if (!fromGas) {
            try { z.SetModelOverride(N2SE.Rotten.Config.model); } catch (ex) {}
            try { NetProps.SetPropInt(z, "m_iMaxHealth", N2SE.Rotten.Config.health); } catch (ex) {}
            try { z.SetHealth(N2SE.Rotten.Config.health); } catch (ex) {}
            N2SE.Rotten.SetupTargetName(z);
            N2SE.Rotten.StartAngryThink(z);
            N2SE.Rotten.CreateAngrySeq(z);
        }

        N2SE.Rotten.AddSmoke(z);
        N2SE.Rotten.BindInterruptOutput(z);
        N2SE.Rotten.HookDeath(z);

        try {
            local sc = z.GetScriptScope();
            if (sc != null) {
                sc.Rotten <- true;
                if (fromGas) sc.GasInfected <- true;
            }
        } catch (ex) {}
        if (fromGas) N2SE.Rotten.gasInfectedSet[z.entindex()] <- true;
    };

    N2SE.Rotten.SpawnGas <- function(pos, infectious) {
        local uid = UniqueString();
        local gasName   = "n2se_gas_"   + uid;
        local smokeName = "n2se_smoke_" + uid;
        local duration  = N2SE.Rotten.GetGasDuration();

        local smoke = Entities.CreateByClassname("env_smokestack");
        if (smoke != null) {
            smoke.SetOrigin(pos);
            smoke.__KeyValueFromString("targetname", smokeName);
            smoke.__KeyValueFromString("SmokeMaterial", "particle/SmokeStack.vmt");
            smoke.__KeyValueFromString("rendercolor", "128 128 0");
            smoke.__KeyValueFromInt("renderamt", 30);
            smoke.__KeyValueFromFloat("BaseSpread", 20.0);
            smoke.__KeyValueFromInt("SpreadSpeed", 12);
            smoke.__KeyValueFromFloat("Speed", 12.0);
            smoke.__KeyValueFromFloat("StartSize", 20.0);
            smoke.__KeyValueFromFloat("EndSize", 45.0);
            smoke.__KeyValueFromFloat("Rate", 100.0);
            smoke.__KeyValueFromFloat("JetLength", 40.0);
            smoke.__KeyValueFromInt("WindSpeed", 5);
            smoke.__KeyValueFromFloat("WindAngle", RandomFloat(0, 360));
            smoke.__KeyValueFromFloat("Twist", 12.0);
            smoke.__KeyValueFromFloat("Roll", 12.0);
            try { DispatchSpawn(smoke); } catch (ex) {}
            try { smoke.AcceptInput("TurnOn", "", "", 0.0); } catch (ex) {}
        }

        local gas = Entities.CreateByClassname("info_target");
        if (gas == null) {
            if (smoke != null) EntFire(smokeName, "Kill", "", 0.5, null);
            return;
        }
        gas.SetOrigin(pos);
        gas.__KeyValueFromString("targetname", gasName);
        try { DispatchSpawn(gas); } catch (ex) {}

        EntFire(smokeName, "TurnOff", "", duration, null);
        EntFire(smokeName, "Kill", "", duration + 0.1, null);
        EntFire(gasName, "Kill", "", duration + 0.2, null);

        try {
            gas.ValidateScriptScope();
            local sc = gas.GetScriptScope();
            if (sc != null) {
                sc.GasPos <- pos;
                sc.LastTick <- Time();
                sc.Infectious <- infectious;

                sc.GasThink <- function() {
                    local g = self;
                    if (g == null || !g.IsValid()) return -1;
                    local sc2 = null;
                    try { sc2 = g.GetScriptScope(); } catch (ex) { return -1; }
                    if (sc2 == null) return -1;
                    if (!sc2.Infectious) return 0.2;

                    if (!N2SE.IsGasmaskOn()) return 0.2;

                    local now = Time();
                    if (now - sc2.LastTick < 1.0) return 0.2;
                    sc2.LastTick = now;
                    local gp = sc2.GasPos;
                    local range = N2SE.Rotten.GetGasInfectRange();

                    local p = null;
                    while ((p = Entities.FindByClassname(p, "player")) != null) {
                        if (!p.IsValid() || !p.IsAlive()) continue;
                        if ((p.GetOrigin() - gp).Length() > 72.0) continue;
                        local already = false;
                        try { if ("IsInfected" in p) already = p.IsInfected(); } catch (ex) {}
                        if (already) continue;
                        local hp = p.GetHealth();
                        local maxHp = 100;
                        try { maxHp = NetProps.GetPropInt(p, "m_iMaxHealth"); } catch (ex) {}
                        if (maxHp <= 0) maxHp = 100;
                        local ratio = hp.tofloat() / maxHp.tofloat();
                        if (ratio < 0) ratio = 0;
                        if (ratio > 1) ratio = 1;
                        local chance = range.min + (1.0 - ratio) * (range.max - range.min);
                        local protected = false;
                        try { protected = ::GasMask.IsProtected(p); } catch(ex) {}
                        if (!protected && RandomInt(1, 100) <= chance.tointeger()) {
                            try { if ("BecomeInfected" in p) p.BecomeInfected(); } catch (ex) {}
                        }
                    }

                    local cnt = N2SE.Rotten.CountGasInfected();
                    if (cnt >= N2SE.Rotten.Config.maxGasInfected) return 0.2;

                    local z = null;
                    while ((z = Entities.FindByClassname(z, "npc_nmrih*")) != null) {
                        if (!z.IsValid() || !z.IsAlive()) continue;
                        local cls = z.GetClassname();
                        if (cls != "npc_nmrih_shamblerzombie"
                            && cls != "npc_nmrih_runnerzombie"
                            && cls != "npc_nmrih_basezombie") continue;
                        if ((z.GetOrigin() - gp).Length() > 72.0) continue;
                        local zsc = null;
                        try { z.ValidateScriptScope(); zsc = z.GetScriptScope(); } catch (ex) { continue; }
                        if (zsc == null) continue;
                        if ("Rotten" in zsc && zsc.Rotten) continue;
                        cnt = N2SE.Rotten.CountGasInfected();
                        if (cnt >= N2SE.Rotten.Config.maxGasInfected) break;
                        N2SE.Rotten.Make(z, true);
                    }
                    return 0.2;
                };
                AddThinkToEnt(gas, "GasThink");
            }
        } catch (ex) {}
    };

    N2SE.Rotten.IsOnCooldown <- function() {
        return Time() < N2SE.Rotten.NextSpawnTime;
    };

    N2SE.Rotten.IsCrawlerCheck <- function(z) {
        if (z == null || !z.IsValid()) return false;
        local isCrawler = false;
        try { if ("IsCrawler" in z) isCrawler = z.IsCrawler(); } catch (ex) {}
        return isCrawler;
    };

    N2SE.Rotten.SpawnRottenAt <- function(pos, angles) {
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);

        local cfg = N2SE.Rotten.Config;
        local maxAttempts = cfg.spawnMaxAttempts;
        if (maxAttempts < 1) maxAttempts = 1;

        for (local attempt = 0; attempt < maxAttempts; attempt++) {
            local z = null;
            try {
                z = SpawnEntityFromTable(cfg.spawnClass, { origin = pos, angles = angles });
            } catch (ex) { continue; }
            if (z == null || !z.IsValid()) continue;

            local zidx = -1;
            try { zidx = z.entindex(); } catch (ex) {}

            try {
                z.ValidateScriptScope();
                local sc = z.GetScriptScope();
                if (sc != null) {
                    sc.Rotten          <- true;
                    sc.RottenChecked   <- true;
                    sc.IsRottenSpawned <- true;
                }
            } catch (ex) {}

            try { DispatchSpawn(z); } catch (ex) {}

            if (N2SE.Rotten.IsCrawlerCheck(z)) {
                if (zidx > 0 && (zidx in N2SE.Rotten.RottenEntitySet))
                    delete N2SE.Rotten.RottenEntitySet[zidx];
                N2SE.SafeKill(z);
                continue;
            }

            local hasArmor = false;
            try { if ("HasArmor" in z) hasArmor = z.HasArmor(); } catch (ex) {}
            if (hasArmor) {
                if (zidx > 0 && (zidx in N2SE.Rotten.RottenEntitySet))
                    delete N2SE.Rotten.RottenEntitySet[zidx];
                N2SE.SafeKill(z);
                continue;
            }

            try { z.SetModelOverride(cfg.model); } catch (ex) {}

            try {
                z.ValidateScriptScope();
                local sc2 = z.GetScriptScope();
                if (sc2 != null) {
                    sc2.Rotten          <- true;
                    sc2.RottenChecked   <- true;
                    sc2.IsRottenSpawned <- true;
                }
            } catch (ex) {}

            N2SE.Rotten.Make(z, false);

            return z;
        }

        return null;
    };

    N2SE.Rotten.ScheduleRotten <- function(pos, angles) {
        if (pos == null) return;

        N2SE.Rotten.PendingCounter = N2SE.Rotten.PendingCounter + 1;
        local id = N2SE.Rotten.PendingCounter;
        N2SE.Rotten.PendingSpawns[id] <- { pos = pos, angles = angles };
        N2SE.Rotten.FireCode("::N2SE.Rotten.ExecuteDelayedSpawn(" + id + ")",
            N2SE.Rotten.Config.spawnDelay);
    };

    N2SE.Rotten.ExecuteDelayedSpawn <- function(id) {
        if (id == null || !(id in N2SE.Rotten.PendingSpawns)) return;
        local rec = N2SE.Rotten.PendingSpawns[id];
        delete N2SE.Rotten.PendingSpawns[id];
        if (rec == null) return;
        N2SE.Rotten.SpawnRottenAt(rec.pos, rec.angles);
    };

    N2SE.Rotten.OnDamagedInterrupt <- function(z, attacker) {
        if (z == null || !z.IsValid()) return;
        N2SE.Rotten.InterruptAngry(z, "damage");
    };

    N2SE.Rotten.BindInterruptOutput <- function(z) {
        if (z == null || !z.IsValid()) return;
        try { z.ValidateScriptScope(); } catch (ex) { return; }
        local sc = z.GetScriptScope();
        if (sc == null) return;
        if ("RottenInterruptHooked" in sc) return;
        sc.RottenInterruptHooked <- true;
        sc.OnRottenInterrupted <- function() {
            N2SE.Rotten.OnDamagedInterrupt(self, activator);
        };
        try { z.ConnectOutput("OnDamagedByPlayer", "OnRottenInterrupted"); } catch (ex) {}
    };

    N2SE.Rotten.HookDeath <- function(z) {
        if (z == null || !z.IsValid()) return;
        try { z.ValidateScriptScope(); } catch (ex) { return; }
        local sc = z.GetScriptScope();
        if (sc == null) return;
        if ("RottenDeathHooked" in sc) return;
        sc.RottenDeathHooked <- true;

        local prev = null;
        if ("OnTakeDamage" in sc) prev = sc.OnTakeDamage;

        sc.OnTakeDamage <- function() {
            local z2 = null;
            try { z2 = self; } catch (ex) {}

            if (!N2SE.IsGasmaskOn()) {
                if (prev != null) {
                    try { return prev(); } catch (ex) { return true; }
                }
                return true;
            }

            local willDie   = false;
            local isRotten  = false;
            local fromGas   = false;
            local origin    = null;
            local zid       = -1;
            local alreadyGas = false;

            if (z2 != null) {
                try {
                    local zsc = null;
                    try { zsc = z2.GetScriptScope(); } catch (ex) {}

                    local zidx2 = -1;
                    try { zidx2 = z2.entindex(); } catch (ex) {}

                    local isRottenFlag = false;
                    if (zsc != null && ("Rotten" in zsc) && zsc.Rotten) isRottenFlag = true;
                    if (!isRottenFlag && zidx2 > 0 && (zidx2 in N2SE.Rotten.RottenEntitySet))
                        isRottenFlag = true;

                    local alreadySpawned = false;
                    if (zidx2 > 0 && (zidx2 in N2SE.Rotten.GasSpawnedSet)) alreadySpawned = true;
                    if (!alreadySpawned && zsc != null && ("RottenGasSpawned" in zsc)
                        && zsc.RottenGasSpawned) alreadySpawned = true;

                    if (isRottenFlag && !alreadySpawned) {
                        isRotten = true;
                        alreadyGas = alreadySpawned;
                        fromGas = ("GasInfected" in zsc) && zsc.GasInfected;
                        zid = zidx2;

                        local di = null;
                        try { di = info; } catch (ex) {}
                        if (di != null) {
                            local dmg = 0;
                            try { dmg = di.GetDamage(); } catch (ex) {}
                            local hp = 0;
                            try { hp = z2.GetHealth(); } catch (ex) {}
                            if (dmg > 0 && hp > 0 && (hp - dmg) <= 0) willDie = true;
                        }
                        origin = z2.GetOrigin();
                    }
                } catch (ex) {}
            }

            local result = true;
            if (prev != null) {
                try { result = prev(); } catch (ex) { result = true; }
            }

            if (willDie && isRotten && !alreadyGas && origin != null) {
                try {
                    if (zid > 0) N2SE.Rotten.GasSpawnedSet[zid] <- true;
                    local zsc = null;
                    try { zsc = z2.GetScriptScope(); } catch (ex) {}
                    if (zsc != null) {
                        zsc.RottenGasSpawned <- true;
                        zsc.RottenDead       <- true;
                    }

                    N2SE.Rotten.ReleaseScreamerLock(zid);
                    if (!fromGas) N2SE.Rotten.PlayDeathSound(z2);

                    if (fromGas) {
                        if (zid in N2SE.Rotten.gasInfectedSet) delete N2SE.Rotten.gasInfectedSet[zid];
                        N2SE.Rotten.SpawnGas(origin, false);
                    } else {
                        N2SE.Rotten.SpawnGas(origin, true);
                    }
                } catch (ex) {}
            }

            return result;
        };
    };

    N2SE.Rotten.OnShoved <- function(p, z) {
        if (!N2SE.IsGasmaskOn()) return;
        N2SE.Rotten.InterruptAngry(z, "shove");
    };

    N2SE.Rotten.OnKilled <- function(p, z) {
        if (z == null) return;

        local zidx0 = -1;
        try { zidx0 = z.entindex(); } catch (ex) {}

        local sc = null;
        try { sc = z.GetScriptScope(); } catch (ex) {}

        if (sc != null) {
            sc.RottenDead <- true;

            if ("AngryDriver" in sc && sc.AngryDriver != null && sc.AngryDriver.IsValid()) {
                local drv = sc.AngryDriver;
                local dsc = null;
                try { dsc = drv.GetScriptScope(); } catch (ex) {}
                if (dsc != null) {
                    try { dsc.AngryState <- 4; } catch (ex) {}
                }
                if (dsc != null && ("AngrySeq" in dsc) && dsc.AngrySeq != null && dsc.AngrySeq.IsValid())
                    N2SE.Rotten.StopSeq(dsc.AngrySeq);
                N2SE.SafeKill(drv);
                sc.AngryDriver = null;
            }

            if ("RottenSeqName" in sc && sc.RottenSeqName != "") {
                N2SE.Rotten.StopSeqByName(sc.RottenSeqName);
                sc.RottenSeqName <- "";
            }

            if ("SmokeNames" in sc) {
                foreach (name in sc.SmokeNames) {
                    EntFire(name, "TurnOff", "", 0, null);
                    EntFire(name, "Kill", "", 0.05, null);
                }
                sc.SmokeNames.clear();
            }
        }

        if (zidx0 > 0 && (zidx0 in N2SE.Rotten.RottenEntitySet))
            delete N2SE.Rotten.RottenEntitySet[zidx0];

        N2SE.Rotten.ReleaseScreamerLock(zidx0);

        local isRottenFlag = false;
        if (sc != null && ("Rotten" in sc) && sc.Rotten) isRottenFlag = true;
        if (!isRottenFlag && zidx0 > 0 && (zidx0 in N2SE.Rotten.RottenEntitySet))
            isRottenFlag = true;
        if (!isRottenFlag) return;

        local alreadySpawned = false;
        if (zidx0 > 0 && (zidx0 in N2SE.Rotten.GasSpawnedSet)) alreadySpawned = true;
        if (!alreadySpawned && sc != null && ("RottenGasSpawned" in sc) && sc.RottenGasSpawned)
            alreadySpawned = true;

        local fromGas = false;
        if (sc != null && ("GasInfected" in sc) && sc.GasInfected) fromGas = true;
        else if (zidx0 > 0 && (zidx0 in N2SE.Rotten.RottenEntitySet)) {
            local info2 = N2SE.Rotten.RottenEntitySet[zidx0];
            if (info2 != null && ("fromGas" in info2)) fromGas = info2.fromGas;
        }

        local pos = null;
        try { pos = z.GetOrigin(); } catch (ex) { return; }
        if (pos == null) return;

        if (!alreadySpawned) {
            if (zidx0 > 0) N2SE.Rotten.GasSpawnedSet[zidx0] <- true;
            if (sc != null) sc.RottenGasSpawned <- true;

            if (!fromGas) N2SE.Rotten.PlayDeathSound(z);

            if (fromGas) {
                if (zidx0 in N2SE.Rotten.gasInfectedSet) delete N2SE.Rotten.gasInfectedSet[zidx0];
                N2SE.Rotten.SpawnGas(pos, false);
            } else {
                N2SE.Rotten.SpawnGas(pos, true);
            }
        }
    };

    N2SE.Rotten.OnSpawn <- function(e) {
        return;
    };

    N2SE.Rotten.HookPlayer <- function(p) {
        if (!N2SE.IsGasmaskOn()) return;
        if (p == null || !p.IsValid()) return;
        local sc = null;
        try { p.ValidateScriptScope(); sc = p.GetScriptScope(); } catch (ex) { return; }
        if (sc == null || ("RottenPlayerHooked" in sc)) return;
        sc.RottenPlayerHooked <- true;

        local prev = ("OnTakeDamage" in sc) ? sc.OnTakeDamage : null;

        sc.OnTakeDamage <- function() {
            local pl = self;
            if (pl == null || !pl.IsValid()) return true;

            if (N2SE.IsGasmaskOn()) {
                local di = null;
                try { di = info; } catch (ex) {}
                if (di != null) {
                    local atk = null;
                    try { atk = di.GetAttacker(); } catch (ex) {}
                    if (atk != null && atk.IsValid() && N2SE.Rotten.IsRottenEntity(atk)) {
                        local cls = "";
                        try { cls = atk.GetClassname(); } catch (ex) {}
                        if (cls.find("npc_nmrih") == 0) {
                            try { di.SetDamage(N2SE.Rotten.Config.attackDamage); } catch (ex) {}
                        }
                    }
                }
            }

            if (prev != null) {
                try { return prev(); } catch (ex) { return true; }
            }
            return true;
        };
    };

    N2SE.Rotten.HookAllPlayers <- function() {
        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            if (p != null && p.IsValid()) N2SE.Rotten.HookPlayer(p);
        }
    };

    N2SE.Rotten.OnPlayerSpawn <- function(...) {
        if (vargv.len() < 1 || vargv[0] == null) return;
        local uid = ("userid" in vargv[0]) ? vargv[0].userid : null;
        if (uid == null) return;
        local pl = null;
        try { pl = GetPlayerByUserId(uid); } catch (ex) {}
        if (pl != null && pl.IsValid()) N2SE.Rotten.HookPlayer(pl);
    };

    if (!("__rotten_player_hook_registered" in getroottable())) {
        try {
            ListenToGameEvent("player_spawn", N2SE.Rotten.OnPlayerSpawn, "N2SE_RottenPlayerSpawn");
        } catch (ex) {}
        getroottable().__rotten_player_hook_registered <- true;
    }

    N2SE.Rotten.CmdSpawn <- function(...) {
        local player = null;
        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            if (p.IsValid() && p.GetHealth() > 0) { player = p; break; }
        }
        if (player == null) return;

        local fwd = player.GetEyeForward();
        fwd.z = 0;
        if (fwd.Length() > 0.1) fwd.Norm();
        local aim = player.GetOrigin() + fwd * 120;

        N2SE.Rotten.SpawnRottenAt(aim, player.GetAngles());
    };

    N2SE.Rotten.Init <- function() {
        try { PrecacheModel(N2SE.Rotten.Config.model, true); } catch (ex) {}
        try { N2SE.PrecacheAll([N2SE.Rotten.Config.deathSound]); } catch (ex) {}
        if ("Convars" in getroottable()) {
            try { Convars.RegisterCommand("spawn_rotten", N2SE.Rotten.CmdSpawn, "Spawn a Rotten Zombie", 0); } catch (ex) {}
        }
        N2SE.Rotten.HookAllPlayers();
    };
}