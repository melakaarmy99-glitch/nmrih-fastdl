if (!("IEDBombSystem" in getroottable())) {
    ::IEDBombSystem <- {
        ITEM_MODEL     = "models/props/objectives/cj_ied.mdl"
        TRAP_MODEL     = "models/props/objectives/cj_ied.mdl"
        ITEM_LABEL     = "Improvised Explosive Device"
        ITEM_ICON      = "vgui/item_icons/bomb"
        ITEM_WEIGHT    = 200

        COUNTDOWN_DURATION  = 16.4
        FAST_THRESHOLD      = 3.0
        BEEP_INTERVAL_INITIAL = 0.8
        BEEP_INTERVAL_FAST  = 0.4

        EXPL_DAMAGE     = 1200
        EXPL_RADIUS     = 256
        EXPL_SOUND      = "weapons/firearms/exp_frag/frag_explode3.wav"
        PUNCH_MAX       = 40.0

        SOUND_BEEP      = "hl1/fvox/blip.wav"
        SOUND_CLUSTER   = "weapons/firearms/exp_molotov/molotov_explode_nofire.wav"
        SOUND_MOLOTOV   = "weapons/firearms/exp_molotov/molotov_explode_01.wav"
        DEPLOY_SOUND    = "physics/metal/metal_barrel/metal_barrel_impact_bullet5.wav"

        INTERACT_RADIUS = 48.0
        PLACE_HOLD_TIME = 1.0

        g_ActiveTraps   = []
        g_PreviewData   = []
        g_ThinkEntity   = null
        g_Initialized   = false

        TrapData = class {
            trapEnt = null
            bullseye = null
            sparkEnt = null
            spriteEnt = null
            detonateTime = 0.0
            hasDetonated = false
            attackerUserId = 0
        }

        PreviewData = class {
            playerEnt = null
            previewEnt = null
            itemEnt = null
            progressEnt = null
            hintEnt = null
        }

        function GetPlayerByUserId(userId) {
            if (userId == 0) return null
            local player = null
            while ((player = Entities.FindByClassname(player, "player")) != null) {
                if (player.GetUserID() == userId) return player
            }
            return null
        }

        function PrecacheSingleSound(soundPath) {
            local dummy = Entities.CreateByClassname("info_target")
            if (dummy) {
                if ("PrecacheSoundScript" in dummy) dummy.PrecacheSoundScript(soundPath)
                else if ("PrecacheSound" in dummy) dummy.PrecacheSound(soundPath)
                EntFireByHandle(dummy, "Kill", "", 0.0, null, null)
            } else {
                local root = getroottable()
                if ("PrecacheSoundScript" in root) root.PrecacheSoundScript(soundPath)
                else if ("PrecacheSound" in root) root.PrecacheSound(soundPath)
            }
        }

        function PrecacheModels() {
            local root = getroottable()
            if ("PrecacheModel" in root) {
                root.PrecacheModel(this.ITEM_MODEL, true)
                root.PrecacheModel(this.TRAP_MODEL, true)
                root.PrecacheModel("sprites/redglow1.vmt", true)
            }
        }

        function DoPrecache() {
            this.PrecacheModels()
            this.PrecacheSingleSound(this.DEPLOY_SOUND)
            this.PrecacheSingleSound(this.SOUND_BEEP)
            this.PrecacheSingleSound(this.SOUND_CLUSTER)
            this.PrecacheSingleSound(this.SOUND_MOLOTOV)
            this.PrecacheSingleSound(this.EXPL_SOUND)
        }

        function EmitSoundOnEntity(entity, soundPath) {
            if (!entity || !entity.IsValid()) return
            if ("EmitSound" in entity) entity.EmitSound(soundPath)
            else EntFireByHandle(entity, "PlaySound", soundPath, 0.0, null, null)
        }

        function _EnsurePlayerTargetname(player) {
            local name = player.GetName()
            if (!name || name == "") {
                name = "IEDBomb_Player_" + player.GetUserID()
                player.__KeyValueFromString("targetname", name)
            }
            return name
        }

        function SpawnIEDTrapItem(origin, angles) {
            local uid = UniqueString()
            local item = SpawnEntityFromTable("item_custom", {
                origin = origin,
                angles = angles,
                model = ::IEDBombSystem.ITEM_MODEL,
                targetname = "ied_item_" + uid,
                skin = 0,
                Label = ::IEDBombSystem.ITEM_LABEL,
                Weight = ::IEDBombSystem.ITEM_WEIGHT,
                highlight = 1,
                hoverselect = 0
            })
            if (!item) {
                printl("[IED Bomb] ERROR: Failed to create item_custom!")
                return null
            }
            item.SetIcon(::IEDBombSystem.ITEM_ICON)
            try {
                if ("SetGlowEnabled" in item) item.SetGlowEnabled(true)
                if ("SetGlowColor" in item) item.SetGlowColor(255, 69, 0, 255)
            } catch(e) {}

            item.ValidateScriptScope()
            local scope = item.GetScriptScope()
            scope.self <- item
            scope.mod <- ::IEDBombSystem

            scope.GetOwnerPlayer <- function() {
                local owner = NetProps.GetPropEntity(this.self, "m_hOwnerEntity")
                if (owner != null && owner.GetClassname() == "player") return owner
                return null
            }

            scope.OnItemApply <- function() {
                local player = this.GetOwnerPlayer()
                if (!player || !player.IsAlive()) return

                foreach (data in mod.g_PreviewData) {
                    if (data.playerEnt == player) return
                }

                local previewEnt = Entities.CreateByClassname("prop_dynamic_override")
                if (!previewEnt) return
                previewEnt.SetModel(mod.TRAP_MODEL)
                previewEnt.__KeyValueFromInt("rendermode", 1)
                previewEnt.__KeyValueFromInt("renderamt", 100)
                previewEnt.__KeyValueFromInt("solid", 0)
                DispatchSpawn(previewEnt)

                local yaw = player.GetAngles().y
                local rad = yaw * 3.14159 / 180.0
                local forward = Vector(cos(rad), sin(rad), 0)
                local spawnPos = player.GetOrigin() + forward * 50.0
                local modelAngles = Vector(0, yaw - 90.0, 0)
                previewEnt.SetOrigin(spawnPos)
                previewEnt.SetAngles(modelAngles)

                this.self.__KeyValueFromInt("rendermode", 1)
                this.self.__KeyValueFromInt("renderamt", 0)
                this.self.__KeyValueFromInt("solid", 0)

                local hint = Entities.CreateByClassname("env_instructor_hint")
                local hintEnt = null
                if (hint) {
                    hint.__KeyValueFromString("hint_caption", "Hold E to place IED, Jump to cancel")
                    hint.__KeyValueFromString("hint_icon_onscreen", "icon_tip")
                    hint.__KeyValueFromString("hint_icon_offscreen", "icon_tip")
                    hint.__KeyValueFromInt("hint_timeout", 3)
                    hint.__KeyValueFromInt("hint_nooffscreen", 1)
                    hint.__KeyValueFromFloat("hint_range", 0)
                    hint.__KeyValueFromInt("hint_forcecaption", 1)
                    hint.__KeyValueFromString("hint_color", "255 255 255")
                    hint.__KeyValueFromInt("hint_static", 0)
                    hint.__KeyValueFromInt("hint_target_pos", 2)
                    hint.__KeyValueFromString("hint_target", mod._EnsurePlayerTargetname(player))
                    hint.__KeyValueFromString("hint_replace_key", "IEDBomb_Place_" + player.GetUserID())
                    hint.__KeyValueFromInt("hint_instance_type", 2)
                    hint.__KeyValueFromInt("hint_local_player_only", 1)
                    DispatchSpawn(hint)
                    hintEnt = hint
                }

                local pData = mod.PreviewData()
                pData.playerEnt = player
                pData.previewEnt = previewEnt
                pData.itemEnt = this.self
                pData.hintEnt = hintEnt
                mod.g_PreviewData.append(pData)

                if (hintEnt) {
                    EntFireByHandle(hintEnt, "ShowHint", mod._EnsurePlayerTargetname(player), 0.0, null, null)
                }
            }
            return item
        }

        function CancelPreview(pData) {
            if (pData.progressEnt && pData.progressEnt.IsValid()) {
                EntFireByHandle(pData.progressEnt, "Kill", "", 0.0, null, null)
                pData.progressEnt = null
            }
            if (pData.hintEnt && pData.hintEnt.IsValid()) {
                EntFireByHandle(pData.hintEnt, "EndHint", "", 0.0, null, null)
                EntFireByHandle(pData.hintEnt, "Kill", "", 0.1, null, null)
                pData.hintEnt = null
            }
            if (pData.itemEnt && pData.itemEnt.IsValid()) {
                pData.itemEnt.__KeyValueFromInt("rendermode", 0)
                pData.itemEnt.__KeyValueFromInt("renderamt", 255)
                pData.itemEnt.__KeyValueFromInt("solid", 6)
            }
            if (pData.previewEnt && pData.previewEnt.IsValid()) {
                EntFireByHandle(pData.previewEnt, "Kill", "", 0.0, null, null)
            }
            for (local i = g_PreviewData.len() - 1; i >= 0; i--) {
                if (g_PreviewData[i] == pData) {
                    g_PreviewData.remove(i)
                    break
                }
            }
        }

        function PlacePreviewTrap(pData) {
            local player = pData.playerEnt
            if (!player || !player.IsValid() || !player.IsAlive()) {
                CancelPreview(pData)
                return
            }
            local success = this.SpawnTrapFromPlayer(player)
            if (success) {
                local currentWeight = NetProps.GetPropInt(player, "_carriedWeight")
                local newWeight = currentWeight - this.ITEM_WEIGHT
                if (newWeight < 0) newWeight = 0
                NetProps.SetPropInt(player, "_carriedWeight", newWeight)

                if (pData.itemEnt && pData.itemEnt.IsValid()) {
                    EntFireByHandle(pData.itemEnt, "Kill", "", 0.0, null, null)
                }
            }
            if (pData.progressEnt && pData.progressEnt.IsValid()) {
                EntFireByHandle(pData.progressEnt, "Kill", "", 0.0, null, null)
                pData.progressEnt = null
            }
            if (pData.hintEnt && pData.hintEnt.IsValid()) {
                EntFireByHandle(pData.hintEnt, "EndHint", "", 0.0, null, null)
                EntFireByHandle(pData.hintEnt, "Kill", "", 0.1, null, null)
                pData.hintEnt = null
            }
            if (pData.previewEnt && pData.previewEnt.IsValid()) {
                EntFireByHandle(pData.previewEnt, "Kill", "", 0.0, null, null)
            }
            for (local i = g_PreviewData.len() - 1; i >= 0; i--) {
                if (g_PreviewData[i] == pData) {
                    g_PreviewData.remove(i)
                    break
                }
            }
        }

        function UpdatePreview(pData) {
            local player = pData.playerEnt
            if (!player || !player.IsValid() || !player.IsAlive()) {
                CancelPreview(pData)
                return
            }
            local previewEnt = pData.previewEnt
            if (!previewEnt || !previewEnt.IsValid()) {
                CancelPreview(pData)
                return
            }
            if ((player.GetButtons() & 2) != 0) {
                CancelPreview(pData)
                return
            }

            local yaw = player.GetAngles().y
            local rad = yaw * 3.14159 / 180.0
            local forward = Vector(cos(rad), sin(rad), 0)
            local spawnPos = player.GetOrigin() + forward * 50.0
            local modelAngles = Vector(0, yaw - 90.0, 0)
            previewEnt.SetOrigin(spawnPos)
            previewEnt.SetAngles(modelAngles)

            local isUsing = (player.GetButtons() & 32) != 0

            if (isUsing) {
                if (!pData.progressEnt || !pData.progressEnt.IsValid()) {
                    local progress = Entities.CreateByClassname("logic_progress")
                    if (progress) {
                        progress.SetStatic(false)
                        progress.SetLength(this.PLACE_HOLD_TIME)
                        progress.SetBroadcast(false)
                        progress.SetInvert(false)
                        progress.SetProgressColor(255, 165, 0)

                        progress.ValidateScriptScope()
                        local scope = progress.GetScriptScope()
                        scope.mod <- this
                        scope.pData <- pData
                        scope.OnComplete <- function() {
                            mod.PlacePreviewTrap(pData)
                        }
                        progress.ConnectOutput("OnComplete", "OnComplete")
                        pData.progressEnt = progress
                        progress.StartProgress(player)
                    }
                }
            } else {
                if (pData.progressEnt && pData.progressEnt.IsValid()) {
                    EntFireByHandle(pData.progressEnt, "Kill", "", 0.0, null, null)
                    pData.progressEnt = null
                }
            }
        }

        function UpdatePreviews() {
            for (local i = g_PreviewData.len() - 1; i >= 0; i--) {
                UpdatePreview(g_PreviewData[i])
            }
        }

        function SpawnTrapFromPlayer(player) {
            if (!player || !player.IsValid() || !player.IsAlive()) return false

            local yaw = player.GetAngles().y
            local rad = yaw * 3.14159 / 180.0
            local forward = Vector(cos(rad), sin(rad), 0)
            local spawnPos = player.GetOrigin() + forward * 50.0
            local modelAngles = Vector(0, yaw - 90.0, 0)

            local trapEnt = Entities.CreateByClassname("prop_dynamic_override")
            if (!trapEnt) return false
            trapEnt.SetModel(this.TRAP_MODEL)
            trapEnt.SetOrigin(spawnPos)
            trapEnt.SetAngles(modelAngles)
            trapEnt.SetSolid(6)
            trapEnt.SetMoveType(0)
            trapEnt.SetHealth(1)
            trapEnt.SetTakeDamage(2)
            trapEnt.__KeyValueFromInt("minhealthdmg", 1)
            trapEnt.__KeyValueFromFloat("physdamagescale", 1.0)
            trapEnt.__KeyValueFromFloat("ExplodeDamage", 0)
            trapEnt.__KeyValueFromInt("ExplodeRadius", 0)
            DispatchSpawn(trapEnt)

            this.EmitSoundOnEntity(trapEnt, this.DEPLOY_SOUND)

            local spark = Entities.CreateByClassname("env_spark")
            if (spark) {
                spark.__KeyValueFromString("MaxDelay", "0.1")
                spark.__KeyValueFromString("Magnitude", "1")
                spark.__KeyValueFromString("TrailLength", "1")
                spark.__KeyValueFromString("rendercolor", "255 0 0")
                DispatchSpawn(spark)
                spark.SetParent(trapEnt, "")
                spark.SetLocalOrigin(Vector(6, 4, 8))
            }

            local sprite = Entities.CreateByClassname("env_sprite")
            if (sprite) {
                sprite.__KeyValueFromString("model", "sprites/redglow1.vmt")
                sprite.__KeyValueFromFloat("scale", 0.6)
                sprite.__KeyValueFromInt("rendermode", 5)
                sprite.__KeyValueFromInt("renderamt", 255)
                sprite.__KeyValueFromString("rendercolor", "255 0 0")
                sprite.__KeyValueFromInt("spawnflags", 0)
                DispatchSpawn(sprite)
                sprite.SetParent(trapEnt, "")
                sprite.SetLocalOrigin(Vector(6, 4, 8))
                sprite.AcceptInput("HideSprite", "", "", 0.0)
            }

            local bullseye = Entities.CreateByClassname("npc_bullseye")
            if (bullseye) {
                bullseye.__KeyValueFromInt("health", 99999)
                bullseye.__KeyValueFromInt("takedamage", 0)
                bullseye.__KeyValueFromInt("spawnflags", 0)
                bullseye.__KeyValueFromInt("solid", 0)
                DispatchSpawn(bullseye)
                bullseye.SetParent(trapEnt, "")
                bullseye.SetLocalOrigin(Vector(0, 0, 45))
                bullseye.SetLocalAngles(Vector(0,0,0))
            }

            trapEnt.ValidateScriptScope()
            local tScope = trapEnt.GetScriptScope()
            tScope.mod <- this
            tScope.OnBreak <- function() {
                mod.DestroyTrapByEntity(this.self)
            }
            trapEnt.ConnectOutput("OnBreak", "OnBreak")

            local data = this.TrapData()
            data.trapEnt = trapEnt
            data.bullseye = bullseye
            data.sparkEnt = spark
            data.spriteEnt = sprite
            data.detonateTime = Time() + this.COUNTDOWN_DURATION
            data.hasDetonated = false
            data.attackerUserId = player.GetUserID()

            this.g_ActiveTraps.append(data)
            this.StartCountdown(data)
            return true
        }

        function StartCountdown(data) {
            this.ScheduleBeepAndSpark(data)
        }

        function ScheduleBeepAndSpark(data) {
            if (!data.trapEnt || !data.trapEnt.IsValid()) return
            if (data.hasDetonated) return

            local remaining = data.detonateTime - Time()
            if (remaining <= 0) {
                this.DetonateTrap(data)
                return
            }

            this.EmitSoundOnEntity(data.trapEnt, this.SOUND_BEEP)

            if (data.sparkEnt && data.sparkEnt.IsValid()) {
                EntFireByHandle(data.sparkEnt, "SparkOnce", "", 0.0, null, null)
            }

            if (data.spriteEnt && data.spriteEnt.IsValid()) {
                data.spriteEnt.AcceptInput("ToggleSprite", "", "", 0.0)
            }

            local nextDelay = remaining <= this.FAST_THRESHOLD ? this.BEEP_INTERVAL_FAST : this.BEEP_INTERVAL_INITIAL
            local idx = data.trapEnt.entindex()
            EntFireByHandle(data.trapEnt, "RunScriptCode",
                "IEDBombSystem.ScheduleBeepByIndex(" + idx + ")",
                nextDelay, null, null)
        }

        function ScheduleBeepByIndex(idx) {
            foreach (data in this.g_ActiveTraps) {
                if (data.trapEnt && data.trapEnt.IsValid() && data.trapEnt.entindex() == idx) {
                    this.ScheduleBeepAndSpark(data)
                    return
                }
            }
        }

        function DetonateTrap(data) {
            if (data.hasDetonated) return
            data.hasDetonated = true

            local pos = data.trapEnt.GetOrigin()
            local attacker = this.GetPlayerByUserId(data.attackerUserId)

            if (RandomFloat(0, 1) < 0.5) {
                this.EmitSoundOnEntity(data.trapEnt, this.SOUND_CLUSTER)
                this.EmitSoundOnEntity(data.trapEnt, this.SOUND_MOLOTOV)

                local molotov = Entities.CreateByClassname("molotov_projectile")
                if (molotov) {
                    if (attacker && attacker.IsValid()) molotov.SetOwner(attacker)
                    local velocity = Vector(
                        rand() * 100.0 - 50.0,
                        rand() * 100.0 - 50.0,
                        100.0 + rand() * 100.0
                    )
                    molotov.SetOrigin(pos + Vector(0, 0, 20))
                    molotov.SetVelocity(velocity)
                    DispatchSpawn(molotov)
                } else {
                    printl("[IED Bomb] ERROR: Could not create molotov_projectile!")
                }
            } else {
                this.DoExplosion(pos, attacker)
            }

            if (data.sparkEnt && data.sparkEnt.IsValid()) {
                EntFireByHandle(data.sparkEnt, "Kill", "", 0.0, null, null)
                data.sparkEnt = null
            }
            if (data.spriteEnt && data.spriteEnt.IsValid()) {
                EntFireByHandle(data.spriteEnt, "Kill", "", 0.0, null, null)
                data.spriteEnt = null
            }
            if (data.bullseye && data.bullseye.IsValid()) {
                EntFireByHandle(data.bullseye, "Kill", "", 0.0, null, null)
                data.bullseye = null
            }
            if (data.trapEnt && data.trapEnt.IsValid()) {
                EntFireByHandle(data.trapEnt, "Kill", "", 0.0, null, null)
                data.trapEnt = null
            }

            for (local i = this.g_ActiveTraps.len() - 1; i >= 0; i--) {
                if (this.g_ActiveTraps[i] == data) {
                    this.g_ActiveTraps.remove(i)
                    break
                }
            }
        }

        function DoExplosion(pos, attacker) {
            local exp = Entities.CreateByClassname("env_explosion")
            if (exp) {
                exp.__KeyValueFromInt("iMagnitude", this.EXPL_DAMAGE)
                exp.__KeyValueFromInt("iRadiusOverride", this.EXPL_RADIUS)
                exp.SetOrigin(pos)
                if (attacker && attacker.IsValid() && attacker.GetClassname()=="player") {
                    exp.SetOwner(attacker)
                    if (NetProps.HasProp(exp, "m_hAttacker"))
                        NetProps.SetPropEntity(exp, "m_hAttacker", attacker)
                }
                exp.AcceptInput("Explode", "", "", 0.0)
                EntFireByHandle(exp, "Kill", "", 0.1, null, null)
            }

            local sndEnt = Entities.CreateByClassname("info_target")
            if (sndEnt) {
                sndEnt.SetOrigin(pos)
                if ("PrecacheSoundScript" in sndEnt) sndEnt.PrecacheSoundScript(this.EXPL_SOUND)
                if ("EmitSoundOn" in this) EmitSoundOn(this.EXPL_SOUND, sndEnt)
                else if ("EmitSound" in sndEnt) sndEnt.EmitSound(this.EXPL_SOUND)
                EntFireByHandle(sndEnt, "Kill", "", 2.0, null, null)
            }

            local p = null
            while ((p = Entities.FindByClassname(p, "player")) != null) {
                if (!p.IsAlive()) continue
                local dist = (p.GetOrigin() - pos).Length()
                if (dist < this.EXPL_RADIUS) {
                    local f = 1.0 - dist / this.EXPL_RADIUS
                    p.ViewPunch(Vector(f * this.PUNCH_MAX * 0.8,
                                       f * this.PUNCH_MAX * RandomFloat(-0.6, 0.6),
                                       f * this.PUNCH_MAX * RandomFloat(-0.3, 0.3)))
                }
            }
        }

        function DestroyTrapByEntity(trapEnt) {
            foreach (data in this.g_ActiveTraps) {
                if (data.trapEnt == trapEnt) {
                    this.DetonateTrap(data)
                    return
                }
            }
        }

        function UpdateAllTraps() {
            this.UpdatePreviews()
            for (local i = this.g_ActiveTraps.len() - 1; i >= 0; i--) {
                local data = this.g_ActiveTraps[i]
                if (!data.trapEnt || !data.trapEnt.IsValid()) {
                    this.g_ActiveTraps.remove(i)
                }
            }
            return -1  
        }

        function StartGlobalThink() {
            if (this.g_ThinkEntity && this.g_ThinkEntity.IsValid()) return
            local ent = Entities.CreateByClassname("logic_script")
            if (!ent) return
            ent.ValidateScriptScope()
            local scope = ent.GetScriptScope()
            scope.mod <- this
            scope.UpdateTraps <- function() { return mod.UpdateAllTraps() }
            AddThinkToEnt(ent, "UpdateTraps")
            this.g_ThinkEntity = ent
        }

        function GiveItemToPlayer(player = null) {
            if (!player) {
                player = null
                while ((player = Entities.FindByClassname(player, "player")) != null) {
                    if (player.IsAlive()) break
                }
            }
            if (!player) return false
            local origin = player.GetOrigin() + Vector(0, 0, 70)
            local angles = Vector(0, player.GetAngles().y, 0)
            this.SpawnIEDTrapItem(origin, angles)
            return true
        }

        function OnMapReset(eventData) {
            for (local i = g_PreviewData.len() - 1; i >= 0; i--) {
                CancelPreview(g_PreviewData[i])
            }
            g_PreviewData.clear()

            foreach (data in this.g_ActiveTraps) {
                if (data.trapEnt && data.trapEnt.IsValid()) {
                    EntFireByHandle(data.trapEnt, "Kill", "", 0.0, null, null)
                }
                if (data.sparkEnt && data.sparkEnt.IsValid()) {
                    EntFireByHandle(data.sparkEnt, "Kill", "", 0.0, null, null)
                }
                if (data.spriteEnt && data.spriteEnt.IsValid()) {
                    EntFireByHandle(data.spriteEnt, "Kill", "", 0.0, null, null)
                }
                if (data.bullseye && data.bullseye.IsValid()) {
                    EntFireByHandle(data.bullseye, "Kill", "", 0.0, null, null)
                }
            }
            this.g_ActiveTraps.clear()

            if (this.g_ThinkEntity && this.g_ThinkEntity.IsValid()) {
                this.g_ThinkEntity.StopThinkFunction()
                this.g_ThinkEntity.Kill()
                this.g_ThinkEntity = null
            }
            EntFireByHandle(Entities.CreateByClassname("logic_script"), "RunScriptCode", "IEDBombSystem.StartGlobalThink();", 0.5, null, null)
        }

        function OnRoundBegin(eventData) {
            if (!this.g_ThinkEntity || !this.g_ThinkEntity.IsValid()) {
                this.StartGlobalThink()
            }
        }

        function Initialize() {
            if (this.g_Initialized) return
            this.g_Initialized = true

            this.DoPrecache()

            if ("ListenToGameEvent" in getroottable()) {
                ListenToGameEvent("nmrih_reset_map", ::IEDBombSystem_OnMapReset, "IEDBombMapReset")
                ListenToGameEvent("nmrih_round_begin", ::IEDBombSystem_OnRoundBegin, "IEDBombRoundBegin")
            }

            this.StartGlobalThink()

            try {
                IncludeScript("custom_loot/custom_loot", getroottable())
                if ("LootManager" in getroottable() && LootManager && ("RegisterCustomItem" in LootManager)) {
                    LootManager.RegisterCustomItem({
                        reference = ::IEDBombSystem.SpawnIEDTrapItem,
                        label = this.ITEM_LABEL,
                        world_model = this.ITEM_MODEL,
                        view_model = this.ITEM_MODEL,
                        icon = this.ITEM_ICON,
                        weight = this.ITEM_WEIGHT,
                        loot_table = {
                            item = 8,
                            ng_drop = 2,
                            military = 2
                        }
                    })
                    printl("[IED Bomb] LootManager registration successful.")
                } else {
                    printl("[IED Bomb] LootManager not found, skipping loot integration.")
                }
            } catch(e) {
                printl("[IED Bomb] LootManager registration failed: " + e)
            }

            printl("[IED Bomb] Fully initialized.")
        }
    }
}

::IEDBombSystem_OnMapReset <- function(eventData) { ::IEDBombSystem.OnMapReset(eventData) }
::IEDBombSystem_OnRoundBegin <- function(eventData) { ::IEDBombSystem.OnRoundBegin(eventData) }

::IEDBombSystem.Initialize()

::SpawnIED <- function() {
    ::IEDBombSystem.GiveItemToPlayer()
}