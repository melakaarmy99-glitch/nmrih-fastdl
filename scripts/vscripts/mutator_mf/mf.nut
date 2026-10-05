(function() {
    if (GameRules.GetWinState() != 5) return;

    local CONFIG = {
        cvar_enabled = "sv_militaryflashlight_enabled",
        cvar_replace_chance = "sv_militaryflashlight_chance",

        item_model   = "models/militaryflashlight/militaryflashlight.mdl",
        item_icon    = "vgui/item_icons/militaryflashlight",
        item_label   = "Fulton MX-991",
        item_weight  = 100,

        light_fov    = 90,
        light_nearz  = 4.0,
        light_farz   = 750.0,
        light_color  = "255 215 155 100",

        sound_on  = "weapons/tools/flashlight/flashlight_on2.wav",
        sound_off = "weapons/tools/flashlight/flashlight_off2.wav",

        flashlight_button = 16777216,
        replace_cooldown = 2.0
    };

    local DEBUG_PREFIX = "[MilitaryFlashlight] ";

    if (!("__sv_militaryflashlight_enabled_registered" in getroottable())) {
        Convars.RegisterConvar(CONFIG.cvar_enabled, "1", "Enable/disable the military flashlight system (1 = enabled, 0 = disabled)", 0);
        getroottable().__sv_militaryflashlight_enabled_registered <- true;
    }

    if (Convars.GetFloat(CONFIG.cvar_enabled) <= 0.0) {
        printl(DEBUG_PREFIX + "Disabled by cvar. Not loading.");
        return;
    }

    if (!("__sv_militaryflashlight_chance_registered" in getroottable())) {
        Convars.RegisterConvar(CONFIG.cvar_replace_chance, "0.30", "Chance to replace old maglite items", 0);
        getroottable().__sv_militaryflashlight_chance_registered <- true;
    }

    local function GetPlayerButtons(player) {
        if ("GetButtons" in player) return player.GetButtons();
        if ("GetPropInt" in NetProps) return NetProps.GetPropInt(player, "m_nButtons");
        if ("GetButtonMask" in player) return player.GetButtonMask();
        return 0;
    }

    local function GetOwnerPlayer(itemEnt) {
        local owner = NetProps.GetPropEntity(itemEnt, "m_hOwnerEntity");
        if (owner != null && owner.GetClassname() == "player") return owner;
        return null;
    }

    local function GetPlayerScope(player) {
        if (!player.IsValid()) return null;
        if (!player.ValidateScriptScope()) return null;
        local scope = player.GetScriptScope();
        if (!("activeMilitaryFlashlight" in scope)) {
            scope.activeMilitaryFlashlight <- null;
        }
        return scope;
    }

    local function SetActiveFlashlight(player, flashlightEnt) {
        local pscope = GetPlayerScope(player);
        if (pscope == null) return;
        pscope.activeMilitaryFlashlight <- flashlightEnt;
    }

    local function GetActiveFlashlight(player) {
        local pscope = GetPlayerScope(player);
        if (pscope == null) return null;
        if ("activeMilitaryFlashlight" in pscope) return pscope.activeMilitaryFlashlight;
        return null;
    }

    local function ClearActiveFlashlight(player, flashlightEnt) {
        local pscope = GetPlayerScope(player);
        if (pscope == null) return;
        if ("activeMilitaryFlashlight" in pscope && pscope.activeMilitaryFlashlight == flashlightEnt) {
            pscope.activeMilitaryFlashlight <- null;
        }
    }

    local function ForceCloseFlashlight(flashlightEnt) {
        if (flashlightEnt == null || !flashlightEnt.IsValid()) return;
        if (!flashlightEnt.ValidateScriptScope()) return;
        local fscope = flashlightEnt.GetScriptScope();
        if ("lightOn" in fscope && fscope.lightOn) {
            fscope.lightOn <- false;
            if ("currentLight" in fscope && fscope.currentLight != null) {
                EntFire(fscope.currentLight, "Kill", "", 0.0, null);
                fscope.currentLight <- null;
            }
            if ("carriedPlayer" in fscope && fscope.carriedPlayer != null && fscope.carriedPlayer.IsValid()) {
                EmitSoundOn(CONFIG.sound_off, fscope.carriedPlayer);
            }
        }
    }

    local function CloseOtherLights(player, excludeEnt) {
        local ent = null;
        while ((ent = Entities.FindByClassname(ent, "item_custom")) != null) {
            if (ent == excludeEnt || !ent.IsValid()) continue;
            if (ent.GetModelName() != CONFIG.item_model) continue;
            local owner = GetOwnerPlayer(ent);
            if (owner != player) continue;
            ForceCloseFlashlight(ent);
        }
    }

    local function CreateEyeAttachedLight(player, lightName) {
        local light = SpawnEntityFromTable("env_projectedtexture", {
            targetname = lightName,
            origin = player.EyePosition(),
            angles = player.EyeAngles(),
            FarZ = CONFIG.light_farz,
            NearZ = CONFIG.light_nearz,
            FOV = CONFIG.light_fov,
            enableshadows = 1,
            shadowquality = 0,
            lightcolor = CONFIG.light_color,
            lightworld = 1,
            CameraSpace = 0
        });

        local viewModel = NetProps.GetPropEntity(player, "m_hViewModel");
        if (viewModel != null && viewModel.IsValid()) {
            light.FollowEntity(viewModel, true);
            light.SetLocalOrigin(Vector(0, 0, 0));
            light.SetLocalAngles(Vector(0, 0, 0));
        }
        else {
            if (light.ValidateScriptScope()) {
                local scope = light.GetScriptScope();
                scope.playerRef <- player;
                scope.lightRef  <- light;
                scope.UpdateLight <- function() {
                    if (!this.playerRef || !this.playerRef.IsValid()) {
                        EntFire(this.lightRef.GetName(), "Kill", "", 0.0, null);
                        return -1;
                    }
                    this.lightRef.SetOrigin(this.playerRef.EyePosition());
                    this.lightRef.SetAngles(this.playerRef.EyeAngles());
                    return 0.0;
                };
                AddThinkToEnt(light, "UpdateLight");
            }
        }
        return light;
    }

    local function SpawnMagliteAt(origin, angles) {
        local uid = UniqueString();
        local magName = "maglite_" + uid;

        local maglite = SpawnEntityFromTable("item_custom", {
            origin = origin,
            angles = angles,
            model = CONFIG.item_model,
            targetname = magName,
            skin = 0,
            Label = CONFIG.item_label,
            Weight = CONFIG.item_weight,
            highlight = 1,
            hoverselect = 0
        });
        maglite.SetIcon(CONFIG.item_icon);
        maglite.PrecacheSoundScript(CONFIG.sound_on);
        maglite.PrecacheSoundScript(CONFIG.sound_off);

        if (maglite.ValidateScriptScope()) {
            local scope = maglite.GetScriptScope();
            scope.soundOn       <- CONFIG.sound_on;
            scope.soundOff      <- CONFIG.sound_off;
            scope.lightOn       <- false;
            scope.currentLight  <- null;
            scope.carriedPlayer <- null;
            scope.lastButtonState <- false;

            scope.GetOwnerPlayer <- function() {
                return GetOwnerPlayer(this.self);
            };

            scope.DestroyLight <- function() {
                if (this.currentLight != null) {
                    EntFire(this.currentLight, "Kill", "", 0.0, null);
                    this.currentLight <- null;
                }
            };

            scope.ToggleFlashlight <- function() {
                local player = this.GetOwnerPlayer();
                if (!player) return;

                local active = GetActiveFlashlight(player);
                if (active != this.self) return;

                if (this.lightOn) {
                    this.DestroyLight();
                    EmitSoundOn(this.soundOff, player);
                    this.lightOn <- false;
                }
                else {
                    CloseOtherLights(player, this.self);
                    this.DestroyLight();
                    local lightName = "maglite_light_" + UniqueString();
                    CreateEyeAttachedLight(player, lightName);
                    this.currentLight <- lightName;
                    EmitSoundOn(this.soundOn, player);
                    this.lightOn <- true;
                }
            };

            scope.OnItemApply <- function() {
                local player = this.GetOwnerPlayer();
                if (!player) return;

                local active = GetActiveFlashlight(player);
                if (active == null || !active.IsValid()) {
                    SetActiveFlashlight(player, this.self);
                }
                else if (active == this.self) {
                    this.ToggleFlashlight();
                }
            };

            scope.OnItemPickup <- function() {
                local player = this.GetOwnerPlayer();
                if (player) {
                    this.carriedPlayer <- player;
                    this.lastButtonState <- false;
                    if (this.lightOn) {
                        this.DestroyLight();
                        this.lightOn <- false;
                        EmitSoundOn(this.soundOff, player);
                    }

                    local active = GetActiveFlashlight(player);
                    if (active == null) {
                        SetActiveFlashlight(player, this.self);
                    }
                }
            };

            scope.OnItemDrop <- function() {
                if (this.lightOn) {
                    this.DestroyLight();
                    this.lightOn <- false;
                    if (this.carriedPlayer != null && this.carriedPlayer.IsValid())
                        EmitSoundOn(this.soundOff, this.carriedPlayer);
                }
                if (this.carriedPlayer != null && this.carriedPlayer.IsValid()) {
                    local active = GetActiveFlashlight(this.carriedPlayer);
                    if (active == this.self) {
                        ClearActiveFlashlight(this.carriedPlayer, this.self);
                    }
                }
                this.carriedPlayer <- null;
                this.lastButtonState <- false;
            };

            scope.PostItemPickupThink <- function() {
                local player = this.carriedPlayer;
                if (!player || !player.IsValid()) {
                    player = this.GetOwnerPlayer();
                    if (player) this.carriedPlayer <- player;
                    else return;
                }

                local active = GetActiveFlashlight(player);
                if (active != this.self) return;

                local buttons = GetPlayerButtons(player);
                local xPressed = (buttons & CONFIG.flashlight_button) != 0;
                if (xPressed && !this.lastButtonState) {
                    this.ToggleFlashlight();
                }
                this.lastButtonState <- xPressed;
            };

            scope.PreItemPickupThink <- function() {};
        }

        return maglite;
    }

    local lastReplaceTime = 0.0;

    local function ReplaceAllMaglites() {
        if (Convars.GetFloat(CONFIG.cvar_enabled) <= 0.0) return;

        local curTime = Time();
        if (curTime - lastReplaceTime < CONFIG.replace_cooldown) return;
        lastReplaceTime = curTime;

        local chance = Convars.GetFloat(CONFIG.cvar_replace_chance);
        if (chance <= 0.0) return;

        local ent = null;
        while ((ent = Entities.FindByClassname(ent, "item_maglite")) != null) {
            if (RandomFloat(0.0, 1.0) < chance) {
                local origin = ent.GetOrigin();
                local angles = ent.GetAngles();
                local oldName = ent.GetName();
                EntFireByHandle(ent, "Kill", "", 0.0, null, null);
                local newMag = SpawnMagliteAt(origin, angles);
                if (oldName != "" && newMag)
                    newMag.__KeyValueFromString("targetname", oldName);
            }
        }
    }

    IncludeScript("custom_loot/custom_loot", getroottable());
    if ("LootManager" in getroottable()) {
        local function CreateMilitaryFlashlightItem(pos, angles) {
            if (Convars.GetFloat(CONFIG.cvar_enabled) <= 0.0) {
                printl(DEBUG_PREFIX + "Dropped item suppressed (cvar disabled).");
                return null;
            }
            return SpawnMagliteAt(pos, angles);
        }
        getroottable().LootManager.RegisterCustomItem({
            reference = CreateMilitaryFlashlightItem,
            label = CONFIG.item_label,
            world_model = CONFIG.item_model,
            view_model = CONFIG.item_model,
            icon = CONFIG.item_icon,
            weight = CONFIG.item_weight,
            loot_table = {
                ng_drop = 5,
                military = 8,
                any = 3
            }
        });
    }

    StopListeningToAllGameEvents("MilitaryFlashlight_Events");
    ListenToGameEvent("nmrih_reset_map", function(event = null) { ReplaceAllMaglites(); }, "MilitaryFlashlight_Events");
    ListenToGameEvent("nmrih_round_begin", function(event = null) { ReplaceAllMaglites(); }, "MilitaryFlashlight_Events");

    Convars.RegisterCommand("give_military_flashlight", function(...) {
        if (Convars.GetFloat(CONFIG.cvar_enabled) <= 0.0) {
            printl(DEBUG_PREFIX + "Command ignored (cvar disabled).");
            return;
        }
        local player = null;
        while ((player = Entities.FindByClassname(player, "player")) != null) {
            if (player.IsAlive()) {
                local origin = player.GetOrigin() + Vector(0, 0, 70);
                SpawnMagliteAt(origin, Vector(0, 270, 0));
                return;
            }
        }
    }, "Spawn a military flashlight item", 0);

    printl(DEBUG_PREFIX + "Script loaded successfully.");
})();