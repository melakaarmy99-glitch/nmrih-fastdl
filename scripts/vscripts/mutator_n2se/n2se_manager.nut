if (!("Manager" in N2SE)) {
    N2SE.Manager <- {};
    N2SE.Manager.Handlers <- {};
    N2SE.GrabTable <- {};

    N2SE.Manager.Register <- function(classname, handler) {
        if (!(classname in N2SE.Manager.Handlers))
            N2SE.Manager.Handlers[classname] <- [];
        N2SE.Manager.Handlers[classname].append(handler);
    };

    N2SE.Manager.IsHandlerEnabled <- function(h) {
        if (h == null) return false;
        if (!("ModKey" in h)) return true;
        local key = h.ModKey;
        if (key == null || key == "") return true;
        if (key == "gasmask") return N2SE.IsGasmaskOn();
        return N2SE.IsModOn(key);
    };

    N2SE.Manager.Dispatch <- function(e) {
        if (e == null || !e.IsValid()) return;
        local cls = e.GetClassname();

        if (cls.find("npc_nmrih") == 0) {
            if ("Spawner" in N2SE && ("OnZombieSpawned" in N2SE.Spawner)) {
                try { N2SE.Spawner.OnZombieSpawned(e); } catch (ex) {}
            }
        }

        if (!(cls in N2SE.Manager.Handlers)) return;
        foreach (h in N2SE.Manager.Handlers[cls]) {
            if (!N2SE.Manager.IsHandlerEnabled(h)) continue;
            if ("OnSpawn" in h) {
                try { h.OnSpawn(e); } catch (ex) { N2SE.Log("handler OnSpawn err: " + ex); }
            }
        }
    };

    N2SE.Manager.DispatchShoved <- function(p, z) {
        local cls = z.GetClassname();
        if (!(cls in N2SE.Manager.Handlers)) return;
        foreach (h in N2SE.Manager.Handlers[cls]) {
            if (!N2SE.Manager.IsHandlerEnabled(h)) continue;
            if ("OnShoved" in h) {
                try { h.OnShoved(p, z); } catch (ex) { N2SE.Log("handler OnShoved err: " + ex); }
            }
        }
    };

    N2SE.Manager.DispatchKilled <- function(p, z) {
        local cls = z.GetClassname();
        if (!(cls in N2SE.Manager.Handlers)) return;
        foreach (h in N2SE.Manager.Handlers[cls]) {
            if ("OnKilled" in h) {
                try { h.OnKilled(p, z); } catch (ex) { N2SE.Log("handler OnKilled err: " + ex); }
            }
        }
    };

    N2SE.Manager.OnEntitySpawned <- function(...) {
        if (vargv.len() < 1) return;
        local e = vargv[0];
        if (e == null || !e.IsValid()) return;
        if (e.GetClassname() == "player") { N2SE.HookPlayer(e); return; }
        N2SE.Manager.Dispatch(e);
    };

    N2SE.Manager.OnZombieShoved <- function(...) {
        if (vargv.len() < 1) return;
        local p = vargv[0];
        if (p == null) return;
        local zid = ("zombie_id" in p) ? p.zombie_id : null;
        if (zid == null || zid <= 0) return;
        local z = EntIndexToHScript(zid);
        if (z == null || !z.IsValid()) return;
        N2SE.Manager.DispatchShoved(p, z);
    };

    N2SE.Manager.OnNPCKilled <- function(...) {
        if (vargv.len() < 1) return;
        local p = vargv[0];
        if (p == null) return;
        local zid = ("entidx" in p) ? p.entidx : null;
        if (zid == null || zid <= 0) return;
        local z = EntIndexToHScript(zid);
        if (z == null || !z.IsValid()) return;
        N2SE.Manager.DispatchKilled(p, z);
    };

    N2SE.Manager.ReduceRottenCooldownsNear <- function(player, radius, seconds, tag) {
        if (player == null || !player.IsValid() || !player.IsAlive()) return 0;
        if (!N2SE.IsGasmaskOn()) return 0;
        if (!("Rotten" in N2SE)) return 0;
        if (!("GetAllRottenNear" in N2SE.Rotten)) return 0;

        local pos = null;
        try { pos = player.GetOrigin(); } catch (ex) { return 0; }
        if (pos == null) return 0;

        local list = N2SE.Rotten.GetAllRottenNear(pos, radius);
        local reduced = 0;
        foreach (z in list) {
            if (!z.IsValid()) continue;
            if (N2SE.Rotten.ReduceCooldown(z, seconds)) reduced++;
        }

        if (reduced > 0) {
            N2SE.Log(tag + ": reduced cooldown for " + reduced + " rottens");
        }
        return reduced;
    };

    N2SE.Manager.ResolvePlayerByUserId <- function(uid) {
        if (uid == null) return null;
        local player = null;
        try { player = GetPlayerByUserId(uid); } catch (ex) {}
        if (player != null && player.IsValid()) return player;

        local pl = null;
        while ((pl = Entities.FindByClassname(pl, "player")) != null) {
            if (!pl.IsValid()) continue;
            try { if (pl.GetUserID() == uid) return pl; } catch (ex) {}
        }
        return null;
    };

    N2SE.Manager.OnVoiceCommand <- function(...) {
        if (vargv.len() < 1) return;
        local p = vargv[0];
        if (p == null) return;

        local uid = ("userid" in p) ? p.userid : null;
        if (uid == null) return;

        local player = N2SE.Manager.ResolvePlayerByUserId(uid);
        if (player == null || !player.IsValid()) return;

        local sec = 5.0;
        local rad = 512.0;
        try { sec = N2SE.Rotten.Config.voiceCooldownReduce; } catch (ex) {}
        try { rad = N2SE.Rotten.Config.cooldownReduceRadius; } catch (ex) {}

        N2SE.Manager.ReduceRottenCooldownsNear(player, rad, sec, "voice cmd");
    };

    N2SE.Manager.OnWeaponFired <- function(...) {
        if (vargv.len() < 1) return;
        local p = vargv[0];
        if (p == null) return;

        local pid = ("player_id" in p) ? p.player_id : null;
        if (pid == null || pid <= 0) return;

        local player = EntIndexToHScript(pid);
        if (player == null || !player.IsValid()) return;

        if (!N2SE.IsGasmaskOn()) return;
        if (!("Rotten" in N2SE)) return;

        local pos = null;
        try { pos = player.GetOrigin(); } catch (ex) { return; }
        if (pos == null) return;

        local noiseRadius = 512.0;
        local cdRadius    = 512.0;
        local sec         = 5.0;
        try { noiseRadius = N2SE.Rotten.Config.noiseAlertRadius; }    catch (ex) {}
        try { cdRadius    = N2SE.Rotten.Config.cooldownReduceRadius; } catch (ex) {}
        try { sec         = N2SE.Rotten.Config.fireCooldownReduce; }  catch (ex) {}

        if ("GetAllRottenNear" in N2SE.Rotten && "AlertFromNoise" in N2SE.Rotten) {
            local list = N2SE.Rotten.GetAllRottenNear(pos, noiseRadius);
            foreach (z in list) {
                if (!z.IsValid()) continue;
                N2SE.Rotten.AlertFromNoise(z);
            }
        }

        N2SE.Manager.ReduceRottenCooldownsNear(player, cdRadius, sec, "weapon fired");
    };

    N2SE.Manager.FindNearestZombieNear <- function(pos, radius) {
        local classes = [
            "npc_nmrih_runnerzombie",
            "npc_nmrih_shamblerzombie",
            "npc_nmrih_kidzombie",
            "npc_nmrih_basezombie"
        ];
        local best = null;
        local bestDist = radius;
        foreach (cls in classes) {
            local z = null;
            while ((z = Entities.FindByClassnameWithin(z, cls, pos, radius)) != null) {
                if (z == null || !z.IsValid()) continue;
                local alive = true;
                try { alive = z.IsAlive(); } catch (ex) {}
                if (!alive) continue;
                local d = 0.0;
                try { d = (z.GetOrigin() - pos).Length(); } catch (ex) { continue; }
                if (d < bestDist) {
                    bestDist = d;
                    best = z;
                }
            }
        }
        return best;
    };

    N2SE.Manager.GrabPollRunning  <- false;
    N2SE.Manager.GrabPollInterval <- 0.1;

    N2SE.Manager.PollGrab <- function() {
        if (!N2SE.Manager.GrabPollRunning) return;
        if (!N2SE.IsMaster()) {
            EntFire("worldspawn", "RunScriptCode", "N2SE.Manager.PollGrab()", N2SE.Manager.GrabPollInterval);
            return;
        }

        for (local i = 1; i <= 32; i++) {
            local player = GetPlayerByIndex(i);
            if (player == null || !player.IsValid() || !player.IsAlive()) continue;

            local pid = -1;
            try { pid = player.entindex(); } catch (ex) { continue; }
            if (pid <= 0) continue;

            local grabbed = false;
            try { grabbed = player.IsGrabbed(); } catch (ex) {
                try { grabbed = NetProps.GetPropInt(player, "m_bGrabbed") != 0; } catch (ex2) {}
            }

            if (grabbed) {
                local pos = null;
                try { pos = player.GetOrigin(); } catch (ex) { continue; }
                local z = N2SE.Manager.FindNearestZombieNear(pos, 150.0);
                if (z != null) {
                    local zidx = -1;
                    try { zidx = z.entindex(); } catch (ex) { continue; }
                    local prev = (pid in N2SE.GrabTable) ? N2SE.GrabTable[pid] : -1;
                    N2SE.GrabTable[pid] <- zidx;

                    if (prev != zidx) {
                        local cls = "";
                        try { cls = z.GetClassname(); } catch (ex) {}
                        local act = "";
                        try { act = z.GetActivity(); } catch (ex) {}
                        N2SE.Log("grab START: player=" + pid + " zombie=" + zidx
                            + " cls=" + cls + " act=" + act);
                    }
                }
            } else {
                if (pid in N2SE.GrabTable) {
                    N2SE.Log("grab STOP: player=" + pid);
                    delete N2SE.GrabTable[pid];
                }
            }
        }

        EntFire("worldspawn", "RunScriptCode", "N2SE.Manager.PollGrab()", N2SE.Manager.GrabPollInterval);
    };

    N2SE.Manager.StartGrabPoll <- function() {
        if (!N2SE.IsMaster()) return;
        if (N2SE.Manager.GrabPollRunning) return;
        N2SE.Manager.GrabPollRunning = true;
        N2SE.Log("grab poll started");
        EntFire("worldspawn", "RunScriptCode", "N2SE.Manager.PollGrab()", 0.1);
    };

    N2SE.Manager.StopGrabPoll <- function() {
        N2SE.Manager.GrabPollRunning = false;
        N2SE.GrabTable.clear();
    };

    N2SE.Manager.OnResetGrabPoll <- function(...) {
        N2SE.Manager.StopGrabPoll();
        N2SE.Manager.StartGrabPoll();
    };

    N2SE.Manager.OnGrabEnd <- function(...) {
        if (vargv.len() < 1) return;
        local p = vargv[0];
        if (p == null) return;

        local pid = ("player_index" in p) ? p.player_index : null;
        local cid = ("causer_index" in p) ? p.causer_index : null;
        if (pid == null) return;

        if (pid in N2SE.GrabTable) delete N2SE.GrabTable[pid];

        N2SE.Log("grab_end: player_index=" + pid + " causer_index=" + cid);
    };

    N2SE.Manager.OnPlayerSpawn <- function(...) {
        if (vargv.len() < 1) return;
        local data = vargv[0];
        if (data == null) return;
        local uid = ("userid" in data) ? data.userid : null;
        if (uid == null) return;
        local pl = null;
        try { pl = GetPlayerByUserId(uid); } catch (ex) {}
        if (pl != null && pl.IsValid()) {
            N2SE.HookPlayer(pl);
        }
    };

    if (!("__n2se_grabpoll_events_registered" in getroottable())) {
        ListenToGameEvent("nmrih_reset_map",   N2SE.Manager.OnResetGrabPoll, "N2SE_GrabPollReset");
        ListenToGameEvent("nmrih_round_begin", N2SE.Manager.OnResetGrabPoll, "N2SE_GrabPollRound");
        getroottable().__n2se_grabpoll_events_registered <- true;
    }

    N2SE.Manager.CleanupRunning  <- false;
    N2SE.Manager.CleanupInterval <- 10.0;

    N2SE.Manager.GetCleanupDistance <- function() {
        local d = 2500.0;
        try { d = Convars.GetFloat("sv_n2se_cleanup_distance"); } catch (ex) {}
        if (d <= 0) d = 2500.0;
        return d;
    };

    N2SE.Manager.MarkExtraSpawned <- function(z) {
        if (z == null || !z.IsValid()) return;
        try {
            z.ValidateScriptScope();
            local sc = z.GetScriptScope();
            if (sc != null) sc.N2SE_ExtraSpawned <- true;
        } catch (ex) {}
    };

    N2SE.Manager.IsExtraSpawned <- function(z) {
        if (z == null || !z.IsValid()) return false;
        try {
            local sc = z.GetScriptScope();
            if (sc != null && ("N2SE_ExtraSpawned" in sc) && sc.N2SE_ExtraSpawned) return true;
        } catch (ex) {}
        return false;
    };

    N2SE.Manager.IsFarFromAllPlayers <- function(pos, radius) {
        if (pos == null) return false;
        local any = false;
        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            if (!p.IsValid() || !p.IsAlive()) continue;
            local pp = null;
            try { pp = p.GetOrigin(); } catch (ex) { continue; }
            if (pp == null) continue;
            any = true;
            if ((pos - pp).Length() <= radius) return false;
        }
        return any;
    };

    N2SE.Manager.CleanupTablesFor <- function(zidx) {
        if (zidx <= 0) return;
        try {
            if ("Swat" in N2SE) {
                if (zidx in N2SE.Swat.SwatEntitySet)       delete N2SE.Swat.SwatEntitySet[zidx];
                if (zidx in N2SE.Swat.MuzzledSet)          delete N2SE.Swat.MuzzledSet[zidx];
                if (zidx in N2SE.Swat.ShieldEntitySet)     delete N2SE.Swat.ShieldEntitySet[zidx];
                if (zidx in N2SE.Swat.ZombieIndexToShield) delete N2SE.Swat.ZombieIndexToShield[zidx];
            }
        } catch (ex) {}
        try {
            if ("Builder" in N2SE) {
                if (zidx in N2SE.Builder.EntitySet)     delete N2SE.Builder.EntitySet[zidx];
                if (zidx in N2SE.Builder.HelmetGoneSet) delete N2SE.Builder.HelmetGoneSet[zidx];
            }
        } catch (ex) {}
        try {
            if ("Patient" in N2SE) {
                if (zidx in N2SE.Patient.EntitySet) delete N2SE.Patient.EntitySet[zidx];
            }
        } catch (ex) {}
        try {
            if ("Fireman" in N2SE) {
                if (zidx in N2SE.Fireman.EntitySet)             delete N2SE.Fireman.EntitySet[zidx];
                if (zidx in N2SE.Fireman.PendingTankExplosions) delete N2SE.Fireman.PendingTankExplosions[zidx];
            }
        } catch (ex) {}
        try {
            if ("Officer" in N2SE) {
                if (zidx in N2SE.Officer.EntitySet) delete N2SE.Officer.EntitySet[zidx];
            }
        } catch (ex) {}
        try {
            if ("Rotten" in N2SE) {
                if (zidx in N2SE.Rotten.RottenEntitySet) delete N2SE.Rotten.RottenEntitySet[zidx];
                if (zidx in N2SE.Rotten.GasSpawnedSet)   delete N2SE.Rotten.GasSpawnedSet[zidx];
                if (zidx in N2SE.Rotten.gasInfectedSet)  delete N2SE.Rotten.gasInfectedSet[zidx];
            }
        } catch (ex) {}
    };

    N2SE.Manager.KillExtraZombie <- function(zidx) {
        if (zidx <= 0) return false;

        local z = EntIndexToHScript(zidx);
        if (z == null || !z.IsValid()) {
            N2SE.Manager.CleanupTablesFor(zidx);
            return false;
        }

        try {
            if ("Swat" in N2SE) {
                if (zidx in N2SE.Swat.ZombieIndexToShield) {
                    local shield = N2SE.Swat.ZombieIndexToShield[zidx];
                    if (shield != null && shield.IsValid()) N2SE.SafeKill(shield);
                }
                if (z in N2SE.Swat.ZombieShieldMap) {
                    local shield2 = N2SE.Swat.ZombieShieldMap[z];
                    if (shield2 != null && shield2.IsValid()) N2SE.SafeKill(shield2);
                    delete N2SE.Swat.ZombieShieldMap[z];
                }
            }
        } catch (ex) {}

        try {
            local zsc = null;
            try { zsc = z.GetScriptScope(); } catch (ex) {}
            if (zsc != null) {
                if ("AngryDriver" in zsc && zsc.AngryDriver != null && zsc.AngryDriver.IsValid()) {
                    N2SE.SafeKill(zsc.AngryDriver);
                    zsc.AngryDriver = null;
                }
                if ("RottenSeqName" in zsc && zsc.RottenSeqName != "") {
                    if ("Rotten" in N2SE && "StopSeqByName" in N2SE.Rotten) {
                        try { N2SE.Rotten.StopSeqByName(zsc.RottenSeqName); } catch (ex) {}
                    }
                    zsc.RottenSeqName <- "";
                }
                if ("SmokeNames" in zsc) {
                    foreach (name in zsc.SmokeNames) {
                        EntFire(name, "TurnOff", "", 0, null);
                        EntFire(name, "Kill", "", 0.05, null);
                    }
                    zsc.SmokeNames.clear();
                }
            }
        } catch (ex) {}

        try {
            if ("Rotten" in N2SE && "ReleaseScreamerLock" in N2SE.Rotten) {
                N2SE.Rotten.ReleaseScreamerLock(zidx);
            }
        } catch (ex) {}

        N2SE.SafeKill(z);
        N2SE.Manager.CleanupTablesFor(zidx);
        return true;
    };

    N2SE.Manager.CleanupModules <- function() {
        if (!N2SE.Manager.CleanupRunning) return;
        if (!N2SE.IsMaster()) {
            EntFire("worldspawn", "RunScriptCode",
                "::N2SE.Manager.CleanupModules()", N2SE.Manager.CleanupInterval);
            return;
        }

        local radius = N2SE.Manager.GetCleanupDistance();

        local candidateSet = {};
        try {
            if ("Swat" in N2SE) {
                foreach (zidx, _ in N2SE.Swat.SwatEntitySet) candidateSet[zidx] <- true;
            }
        } catch (ex) {}
        try {
            if ("Builder" in N2SE) {
                foreach (zidx, _ in N2SE.Builder.EntitySet) candidateSet[zidx] <- true;
            }
        } catch (ex) {}
        try {
            if ("Patient" in N2SE) {
                foreach (zidx, _ in N2SE.Patient.EntitySet) candidateSet[zidx] <- true;
            }
        } catch (ex) {}
        try {
            if ("Fireman" in N2SE) {
                foreach (zidx, _ in N2SE.Fireman.EntitySet) candidateSet[zidx] <- true;
            }
        } catch (ex) {}
        try {
            if ("Officer" in N2SE) {
                foreach (zidx, _ in N2SE.Officer.EntitySet) candidateSet[zidx] <- true;
            }
        } catch (ex) {}
        try {
            if ("Rotten" in N2SE) {
                foreach (zidx, _ in N2SE.Rotten.RottenEntitySet) candidateSet[zidx] <- true;
            }
        } catch (ex) {}

        local killed = 0;
        local stale  = 0;

        foreach (zidx, _ in candidateSet) {
            local z = EntIndexToHScript(zidx);
            if (z == null || !z.IsValid()) {
                N2SE.Manager.CleanupTablesFor(zidx);
                stale++;
                continue;
            }

            if (!N2SE.Manager.IsExtraSpawned(z)) continue;

            local zp = null;
            try { zp = z.GetOrigin(); } catch (ex) { continue; }
            if (zp == null) continue;

            if (N2SE.Manager.IsFarFromAllPlayers(zp, radius)) {
                if (N2SE.Manager.KillExtraZombie(zidx)) killed++;
            }
        }

        try {
            if ("Swat" in N2SE) {
                local deadKeys = [];
                foreach (z, _shield in N2SE.Swat.ZombieShieldMap) {
                    if (z == null || !z.IsValid()) deadKeys.append(z);
                }
                foreach (z in deadKeys) delete N2SE.Swat.ZombieShieldMap[z];
            }
        } catch (ex) {}

        if (killed > 0 || stale > 0) {
            N2SE.Log("cleanup: killed=" + killed + " stale=" + stale
                + " radius=" + radius);
        }

        EntFire("worldspawn", "RunScriptCode",
            "::N2SE.Manager.CleanupModules()", N2SE.Manager.CleanupInterval);
    };

    N2SE.Manager.StartCleanup <- function() {
        if (!N2SE.IsMaster()) return;
        if (N2SE.Manager.CleanupRunning) return;
        N2SE.Manager.CleanupRunning = true;
        N2SE.Log("cleanup poll started");
        EntFire("worldspawn", "RunScriptCode",
            "::N2SE.Manager.CleanupModules()", 5.0);
    };

    N2SE.Manager.StopCleanup <- function() {
        N2SE.Manager.CleanupRunning = false;
    };

    N2SE.Manager.OnResetCleanup <- function(...) {
        N2SE.Manager.StopCleanup();
        N2SE.Manager.StartCleanup();
    };

    if (!("__n2se_cleanup_events_registered" in getroottable())) {
        ListenToGameEvent("nmrih_reset_map",   N2SE.Manager.OnResetCleanup, "N2SE_CleanupReset");
        ListenToGameEvent("nmrih_round_begin", N2SE.Manager.OnResetCleanup, "N2SE_CleanupRound");
        getroottable().__n2se_cleanup_events_registered <- true;
    }

    N2SE.Manager.Init <- function() {
        try { Hooks.Add(0, "OnEntitySpawned", N2SE.Manager.OnEntitySpawned, "N2SE_S"); }
        catch (ex) {
            try { Hooks.Add(getroottable(), "OnEntitySpawned", N2SE.Manager.OnEntitySpawned, "N2SE_S2"); }
            catch (ex2) { N2SE.Log("hook fail: " + ex2); }
        }
        if ("ListenToGameEvent" in getroottable()) {
            ListenToGameEvent("zombie_shoved",        N2SE.Manager.OnZombieShoved, "N2SE_Shoved");
            ListenToGameEvent("npc_killed",           N2SE.Manager.OnNPCKilled,    "N2SE_Killed");
            ListenToGameEvent("player_voice_command", N2SE.Manager.OnVoiceCommand, "N2SE_Voice");
            ListenToGameEvent("weapon_fired",         N2SE.Manager.OnWeaponFired,  "N2SE_Fire");
            ListenToGameEvent("grab_end",             N2SE.Manager.OnGrabEnd,      "N2SE_GrabEnd");
            ListenToGameEvent("player_spawn",         N2SE.Manager.OnPlayerSpawn,  "N2SE_PlayerSpawn");
        }
        try { Entities.EnableEntityListening(); } catch (ex) {}

        N2SE.Manager.StartGrabPoll();
        N2SE.Manager.StartCleanup();
    };
}