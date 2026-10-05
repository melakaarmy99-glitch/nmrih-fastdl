if (!("GasMask" in getroottable())) {
    ::GasMask <- {};

    GasMask.Config <- {
        item_model   = "models/items/gasmask/gasmask_1a.mdl",
        item_icon    = "vgui/item_icons/destinkifier",
        item_label   = "GasMask",
        item_weight  = 120,

        initial_durability   = 100,
        durability_tick_rate = 5.0,
        durability_per_tick  = 3,
        gas_check_radius     = 72.0,
        check_interval       = 0.2
    };

    GasMask.Log <- function(m) { printl("[GasMask] " + m); };

    GasMask.GetOwnerPlayer <- function(itemEnt) {
        local owner = null;
        try { owner = NetProps.GetPropEntity(itemEnt, "m_hOwnerEntity"); } catch(ex) {}
        if (owner != null && owner.GetClassname() == "player") return owner;
        return null;
    };

    GasMask.GetPlayerScope <- function(player) {
        if (!player.IsValid()) return null;
        if (!player.ValidateScriptScope()) return null;
        local scope = player.GetScriptScope();
        if (!("activeGasMask" in scope)) scope.activeGasMask <- null;
        return scope;
    };

    GasMask.SetActive <- function(player, ent) {
        local pscope = GasMask.GetPlayerScope(player);
        if (pscope) pscope.activeGasMask <- ent;
    };

    GasMask.GetActive <- function(player) {
        local pscope = GasMask.GetPlayerScope(player);
        if (pscope && ("activeGasMask" in pscope)) return pscope.activeGasMask;
        return null;
    };

    GasMask.ClearActive <- function(player, ent) {
        local pscope = GasMask.GetPlayerScope(player);
        if (pscope && ("activeGasMask" in pscope) && pscope.activeGasMask == ent) {
            pscope.activeGasMask <- null;
        }
    };

    GasMask.UpdateItemLabel <- function(ent, durability) {
        if (ent == null || !ent.IsValid()) return;
        local maxDur = GasMask.Config.initial_durability;
        local pct = 0;
        if (maxDur > 0) pct = ((durability * 100) / maxDur).tointeger();
        if (pct < 0) pct = 0;
        if (pct > 100) pct = 100;
        local newLabel = GasMask.Config.item_label + " (" + pct + "%)";
        try { ent.SetLabelOverride(newLabel); return; } catch(ex) {}
        try { ent.__KeyValueFromString("Label", newLabel); } catch(ex) {}
    };

    GasMask.SpawnAt <- function(origin, angles) {
        if (origin == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);
        local cfg = GasMask.Config;
        local uid = UniqueString();
        local name = "gasmask_" + uid;

        local ent = SpawnEntityFromTable("item_custom", {
            origin = origin,
            angles = angles,
            model = cfg.item_model,
            targetname = name,
            skin = 0,
            Label = cfg.item_label,
            Weight = cfg.item_weight,
            highlight = 1,
            hoverselect = 0
        });
        if (ent == null || !ent.IsValid()) return null;

        try { ent.SetIcon(cfg.item_icon); } catch(ex) {}

        if (!ent.ValidateScriptScope()) return ent;
        local scope = ent.GetScriptScope();
        scope.carriedPlayer <- null;
        scope.durability    <- cfg.initial_durability;
        scope.gasAccum      <- 0.0;
        scope.lastTick      <- Time();

        scope.GetOwnerPlayer <- function() { return GasMask.GetOwnerPlayer(this.self); };

        scope.OnItemApply <- function() {
            local player = this.GetOwnerPlayer();
            if (!player) return;
            local active = GasMask.GetActive(player);
            if (active == null || !active.IsValid()) {
                GasMask.SetActive(player, this.self);
                this.carriedPlayer <- player;
            }
        };

        scope.OnItemPickup <- function() {
            local player = this.GetOwnerPlayer();
            if (player) {
                this.carriedPlayer <- player;
                local active = GasMask.GetActive(player);
                if (active == null) GasMask.SetActive(player, this.self);
            }
        };

        scope.OnItemDrop <- function() {
            if (this.carriedPlayer != null && this.carriedPlayer.IsValid()) {
                local active = GasMask.GetActive(this.carriedPlayer);
                if (active == this.self) GasMask.ClearActive(this.carriedPlayer, this.self);
            }
            this.carriedPlayer <- null;
        };

        return ent;
    };

    GasMask.IsPlayerInGas <- function(player) {
        local pos = player.GetOrigin();
        local radius = GasMask.Config.gas_check_radius;
        local e = null;
        while ((e = Entities.FindByClassnameWithin(e, "info_target", pos, radius)) != null) {
            if (!e.IsValid()) continue;
            local name = "";
            try { name = e.GetName(); } catch(ex) {}
            if (name != null && name.find("n2se_gas_") == 0) return true;
        }
        return false;
    };

    GasMask.IsProtected <- function(player) {
        if (player == null || !player.IsValid()) return false;
        if (!player.ValidateScriptScope()) return false;
        local psc = player.GetScriptScope();
        if (!("activeGasMask" in psc)) return false;
        local d = psc.activeGasMask;
        if (d == null || !d.IsValid()) return false;
        local ds = null;
        try { ds = d.GetScriptScope(); } catch(ex) {}
        if (ds == null) return false;
        local dur = ("durability" in ds) ? ds.durability : 0;
        return dur > 0;
    };

    GasMask.Running <- false;

    GasMask.Check <- function() {
        if (!GasMask.Running) return;

        local cfg = GasMask.Config;
        local now = Time();

        if (!N2SE.IsGasmaskOn()) {
            EntFire("worldspawn", "RunScriptCode", "GasMask.Check()", cfg.check_interval);
            return;
        }

        for (local i = 1; i <= 32; i++) {
            local player = GetPlayerByIndex(i);
            if (!player || !player.IsValid() || !player.IsAlive()) continue;

            local item = GasMask.GetActive(player);
            if (!item || !item.IsValid()) continue;

            local iscope = null;
            try { iscope = item.GetScriptScope(); } catch(ex) {}
            if (iscope == null) continue;

            local lastTick = ("lastTick" in iscope) ? iscope.lastTick : now;
            local dt = now - lastTick;
            if (dt < 0) dt = 0;
            iscope.lastTick <- now;

            local durability = ("durability" in iscope) ? iscope.durability : cfg.initial_durability;
            if (durability < 0) durability = 0;

            local inGas = GasMask.IsPlayerInGas(player);

            if (inGas && durability > 0) {
                local accum = ("gasAccum" in iscope) ? iscope.gasAccum : 0.0;
                accum += dt;
                if (accum >= cfg.durability_tick_rate) {
                    accum -= cfg.durability_tick_rate;
                    durability -= cfg.durability_per_tick;
                    if (durability < 0) durability = 0;
                    GasMask.UpdateItemLabel(item, durability);
                }
                iscope.gasAccum <- accum;
                iscope.durability <- durability;
            } else if (!inGas) {
                iscope.gasAccum <- 0.0;
            }
        }

        EntFire("worldspawn", "RunScriptCode", "GasMask.Check()", cfg.check_interval);
    };

    GasMask.Start <- function() {
        if (!N2SE.IsGasmaskOn()) return;
        if (GasMask.Running) return;
        GasMask.Running = true;
        GasMask.Log("started");
        EntFire("worldspawn", "RunScriptCode", "GasMask.Check()", 0.1);
    };

    GasMask.Stop <- function() {
        GasMask.Running = false;
        for (local i = 1; i <= 32; i++) {
            local player = GetPlayerByIndex(i);
            if (player && player.IsValid() && player.ValidateScriptScope()) {
                local scope = player.GetScriptScope();
                scope.activeGasMask <- null;
            }
        }
    };

    GasMask.OnReset <- function(...) {
        GasMask.Stop();
        GasMask.Start();
    };

    if (!("__gasmask_events_registered" in getroottable())) {
        ListenToGameEvent("nmrih_reset_map",   GasMask.OnReset, "GasMaskReset");
        ListenToGameEvent("nmrih_round_begin", GasMask.OnReset, "GasMaskRound");
        getroottable().__gasmask_events_registered <- true;
    }

    try { IncludeScript("custom_loot/custom_loot", getroottable()); } catch(ex) {}

    local function CreateGasMaskItem(pos, angles) {
        if (!N2SE.IsGasmaskOn()) return null;
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);
        return GasMask.SpawnAt(pos, angles);
    }

    if ("LootManager" in getroottable()) {
        try {
            getroottable().LootManager.RegisterCustomItem({
                reference    = CreateGasMaskItem,
                label        = GasMask.Config.item_label,
                world_model  = GasMask.Config.item_model,
                view_model   = GasMask.Config.item_model,
                icon         = GasMask.Config.item_icon,
                weight       = GasMask.Config.item_weight,
                loot_table   = {
                    military = 24,
                    medical  = 18,
                    any      = 12,
                    ammo     = 8
                }
            });
            GasMask.Log("registered to LootManager");
        } catch(ex) {
            GasMask.Log("LootManager register err: " + ex);
        }
    }

    try {
        Convars.RegisterCommand("give_gasmask", function(...) {
            if (!N2SE.IsGasmaskOn()) return;
            local player = null;
            while ((player = Entities.FindByClassname(player, "player")) != null) {
                if (player.IsAlive()) {
                    local origin = player.GetOrigin() + Vector(0, 0, 70);
                    GasMask.SpawnAt(origin, Vector(0, 270, 0));
                    return;
                }
            }
        }, "Spawn a GasMask item", 0);
    } catch(ex) {}

    GasMask.Init <- function() {
        if (!N2SE.IsGasmaskOn()) {
            GasMask.Log("disabled by cvar");
            return;
        }
        GasMask.Start();
    };
}