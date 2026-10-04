if (!("PingSystem" in getroottable()))
{
    ::PingSystem <- {}

    ::PingSystem.IN_USE <- 0x20
    ::PingSystem.IN_VOICECMD <- 0x80000000
    ::PingSystem.TRACE_MASK <- 0x4600400B
    ::PingSystem.TRACE_RANGE <- 3000.0
    ::PingSystem.GLOW_DURATION <- 5.0
    ::PingSystem.CIRCLE_RADIUS <- 9.0
    ::PingSystem.CIRCLE_SEGMENTS <- 10
    ::PingSystem.GLOW_PREFIXES <- [
        "prop_",
        "item_",
        "me_",
        "fa_",
        "tool_",
        "bow_",
        "npc_nmrih_",
        "exp_"
    ]
    ::PingSystem.WeaponDisplayNames <- {
        "bow_deerhunter"        : "PSE D. Hunt.",
        "exp_grenade"           : "Grenade",
        "exp_molotov"           : "Molotov",
        "exp_tnt"               : "TNT",
        "fa_500a"               : "Moss. 500a",
        "fa_870"                : "Rem. 870",
        "fa_1022"               : "Ruger 10/22",
        "fa_1022_25mag"         : "Ruger 10/22 (25rd Mag)",
        "fa_1911"               : "Colt 1911",
        "fa_cz858"              : "CZ858",
        "fa_glock17"            : "Glock",
        "fa_fnfal"              : "FN FAL",
        "fa_jae700"             : "JAE 700",
        "fa_m16a4"              : "M16A4",
        "fa_m16a4_carryhandle"  : "M16A4 (Carry Handle)",
        "fa_m92fs"              : "M92FS",
        "fa_mac10"              : "Mac-10",
        "fa_mkiii"              : "Ruger MKiii",
        "fa_mp5a3"              : "MP5A3",
        "fa_sako85"             : "Sako 85",
        "fa_sako85_ironsights"  : "Sako 85 (Ironsights)",
        "fa_sks"                : "SKS",
        "fa_sks_nobayo"         : "SKS (No Bayonet)",
        "fa_superx3"            : "Super X3",
        "fa_sv10"               : "SV10",
        "fa_sw686"              : "S&W 686",
        "fa_winchester1892"     : "Win. 1892",
        "item_bandages"         : "Bandages",
        "item_maglite"          : "Maglite",
        "item_pills"            : "Pills",
        "item_first_aid"        : "First Aid",
        "item_walkietalkie"     : "Walkie Talkie",
        "item_inventory_box"    : "Supply Crate",
        "me_axe_fire"           : "Fire Axe",
        "me_bat_metal"          : "Baseball Bat",
        "me_chainsaw"           : "Chainsaw",
        "me_abrasivesaw"        : "Abrasive Saw",
        "me_crowbar"            : "Crowbar",
        "me_hatchet"            : "Hatchet",
        "me_kitknife"           : "Kit Knife",
        "me_etool"              : "E-Tool",
        "me_fubar"              : "Fubar",
        "me_machete"            : "Machete",
        "me_pipe_lead"          : "Lead Pipe",
        "me_shovel"             : "Shovel",
        "me_sledge"             : "Sledge",
        "me_wrench"             : "Wrench",
        "tool_barricade"        : "Barr. Tool",
        "tool_extinguisher"     : "Fire Exting.",
        "tool_flare_gun"        : "Flare Gun",
        "tool_welder"           : "Welder",
        "npc_nmrih_shamblerzombie" : "Shambler",
        "npc_nmrih_runnerzombie"   : "Runner",
        "npc_nmrih_kidzombie"      : "KidZombie"
    }
    ::PingSystem.AmmoIDToName <- {
        [52] = "9mm",
        [53] = "45acp",
        [54] = "357",
        [55] = "12gauge",
        [56] = "22lr",
        [57] = "308",
        [58] = "556",
        [59] = "762mm",
        [60] = "arrow",
        [61] = "board",
        [62] = "fuel",
        [63] = "flare",
    }
    ::PingSystem.WeaponAmmoIndexMap <- {
        "fa_m92fs" : 1,
        "fa_glock17" : 1,
        "fa_mkiii" : 5,
        "fa_1911" : 2,
        "fa_sw686" : 3,
        "fa_fnfal" : 6,
        "fa_sako85" : 6,
        "fa_sako85_ironsights" : 6,
        "fa_cz858" : 8,
        "fa_sks" : 8,
        "fa_sks_nobayo" : 8,
        "fa_winchester1892" : 3,
        "fa_m16a4" : 7,
        "fa_m16a4_carryhandle" : 7,
        "fa_1022" : 5,
        "fa_1022_25mag" : 5,
        "fa_jae700" : 6,
        "fa_mp5a3" : 1,
        "fa_mac10" : 2,
        "fa_sv10" : 4,
        "fa_500a" : 4,
        "fa_superx3" : 4,
        "fa_870" : 4,
        "me_chainsaw" : 62,
        "me_abrasivesaw" : 62,
        "tool_flare_gun" : 63
    }
    ::PingSystem.AmmoIndexToName <- {
        [1] = "9mm",
        [2] = "45acp",
        [3] = "357",
        [4] = "12gauge",
        [5] = "22lr",
        [6] = "308",
        [7] = "556",
        [8] = "762mm",
        [62] = "Fuel",
        [63] = "Flare"
    }
    ::PingSystem.activePings <- []
    ::PingSystem.voiceActivePings <- []
    ::PingSystem.LastButtons <- {}
    ::PingSystem.LastPingTime <- {}
    ::PingSystem.LastVoiceTime <- {}
    ::PingSystem.running <- false
    ::PingSystem._initialized <- false
    ::PingSystem._mapResetListener <- null
    ::PingSystem._roundBeginListener <- null
    ::PingSystem._voiceListener <- null

    ::PingSystem.HueToRGB <- function(v1, v2, vH)
    {
        if (vH < 0) vH += 1.0
        if (vH > 1) vH -= 1.0
        if ((6.0 * vH) < 1.0) return v1 + (v2 - v1) * 6.0 * vH
        if ((2.0 * vH) < 1.0) return v2
        if ((3.0 * vH) < 2.0) return v1 + (v2 - v1) * ((2.0 / 3.0) - vH) * 6.0
        return v1
    }

    ::PingSystem.HSLToRGB <- function(h, s, l)
    {
        local r, g, b
        if (s == 0)
        {
            r = g = b = l * 255
        }
        else
        {
            local hue = h / 360.0
            local v2 = (l < 0.5) ? (l * (1.0 + s)) : ((l + s) - (l * s))
            local v1 = 2.0 * l - v2
            r = 255 * ::PingSystem.HueToRGB(v1, v2, hue + (1.0 / 3.0))
            g = 255 * ::PingSystem.HueToRGB(v1, v2, hue)
            b = 255 * ::PingSystem.HueToRGB(v1, v2, hue - (1.0 / 3.0))
        }
        return [r.tointeger(), g.tointeger(), b.tointeger()]
    }

    ::PingSystem.RandomReadableColor <- function()
    {
        local h = RandomFloat(0.0, 360.0)
        if (h >= 212.0 && h <= 283.0)
        {
            if (h < 246.0) h -= 71.0
            else h += 71.0
        }
        return ::PingSystem.HSLToRGB(h, 1.0, 0.5)
    }

    ::PingSystem.GetPlayerEyePosition <- function(player)
    {
        return player.EyePosition()
    }

    ::PingSystem.IsGlowableClassname <- function(classname)
    {
        foreach (prefix in ::PingSystem.GLOW_PREFIXES)
            if (classname.find(prefix) != null) return true
        return false
    }

    ::PingSystem.GetAmmoDisplayName <- function(entity)
    {
        local ammoName = "Unknown"
        try {
            local ammoIndex = null
            if ("GetWeaponID" in entity) ammoIndex = entity.GetWeaponID()
            else if ("GetAmmoIndex" in entity) ammoIndex = entity.GetAmmoIndex()
            else if ("GetWeaponType" in entity) ammoIndex = entity.GetWeaponType()
            if (ammoIndex != null && (ammoIndex in ::PingSystem.AmmoIDToName))
                ammoName = ::PingSystem.AmmoIDToName[ammoIndex]
        } catch(e) {}

        if (ammoName == "Unknown") {
            try {
                local model = entity.GetModelName().tolower()
                local keywords = [
                    ["12gauge","12g","12ga","shotgun"],
                    ["fuel","gascan","gas","gasoline"],
                    ["9mm","9 mm"],
                    ["45acp","45"],
                    ["357"],
                    ["22lr","22"],
                    ["308"],
                    ["556"],
                    ["762mm","762"],
                    ["arrow","arrow_box"],
                    ["flare","flares"],
                    ["board"]
                ]
                local names = ["12gauge","fuel","9mm","45acp","357","22lr","308","556","762mm","arrow","flare","board"]
                for (local i=0; i<keywords.len(); i++) {
                    foreach (k in keywords[i]) {
                        if (model.find(k) != null) { ammoName = names[i]; break }
                    }
                    if (ammoName != "Unknown") break
                }
                if (ammoName == "Unknown") {
                    local start = model.find("ammo_")
                    if (start != null) {
                        local sub = model.slice(start + 5)
                        local end = sub.find(".mdl")
                        if (end != null) ammoName = sub.slice(0, end)
                    }
                }
            } catch(e) {}
        }
        return ammoName
    }

    ::PingSystem.GetWeaponDisplayName <- function(classname, entity = null)
    {
        if (entity != null && entity.IsValid()) {
            local entClass = entity.GetClassname()
            if (entClass.find("ammo") != null || entClass.find("item_ammo") == 0) {
                local ammoName = ::PingSystem.GetAmmoDisplayName(entity)
                if (ammoName != "Unknown")
                    return ammoName
                else
                    return null
            }
        }

        if (classname in ::PingSystem.WeaponDisplayNames)
            return ::PingSystem.WeaponDisplayNames[classname]

        foreach (key, value in ::PingSystem.WeaponDisplayNames)
            if (classname.find(key) != null)
                return value

        return null
    }

    ::PingSystem.GetWeaponClipAmmo <- function(weaponEnt)
    {
        if (!weaponEnt || !weaponEnt.IsValid()) return 0
        local ammo = 0
        try {
            if ("GetClip1" in weaponEnt) ammo = weaponEnt.GetClip1()
            else if ("NetProps" in getroottable()) ammo = NetProps.GetPropInt(weaponEnt, "m_iClip1")
        } catch (e) {}
        return ammo
    }

    ::PingSystem.ApplyGlow <- function(entity, rgb)
    {
        if (!entity.IsGlowable()) entity.SetGlowable(true)
        entity.SetGlowDistance(-1)
        local colorStr = format("%d %d %d", rgb[0], rgb[1], rgb[2])
        entity.KeyValueFromString("glowcolor", colorStr)
        entity.AcceptInput("EnableGlow", "", null, null)
    }

    ::PingSystem.RemoveGlow <- function(entity)
    {
        if (!entity || !entity.IsValid()) return
        if ("DisableGlow" in entity)
            entity.DisableGlow()
        else
            entity.AcceptInput("DisableGlow", "", null, null)
    }

    ::PingSystem.EnsureEntityName <- function(entity)
    {
        if (!entity || !entity.IsValid()) return null
        local name = entity.GetName()
        if (name && name != "") return name
        name = "ping_target_" + entity.entindex() + "_" + UniqueString()
        entity.__KeyValueFromString("targetname", name)
        return name
    }

    ::PingSystem.CreateInstructorHint <- function(target, player, rgbColor, displayName = null, usePointsAt = true, iconOverride = null)
    {
        local targetName = null
        local tempEntity = null
        local iconName = iconOverride ? iconOverride : "icon_interact"

        if (typeof(target) == "instance")
        {
            targetName = ::PingSystem.EnsureEntityName(target)
            local classname = target.GetClassname()
            if (!iconOverride && classname.find("npc_nmrih") == 0)
                iconName = "icon_skull"
        }
        else
        {
            tempEntity = Entities.CreateByClassname("info_target_instructor_hint")
            if (!tempEntity) return null
            tempEntity.__KeyValueFromString("targetname", "ping_point_" + UniqueString())
            tempEntity.SetAbsOrigin(target)
            DispatchSpawn(tempEntity)
            targetName = tempEntity.GetName()
        }

        if (!targetName) return null

        local caption
        if (usePointsAt)
        {
            caption = player.GetPlayerName() + " Points At"
            if (displayName != null && displayName != "")
                caption += " " + displayName
        }
        else
        {
            caption = player.GetPlayerName() + ": " + (displayName != null ? displayName : "")
        }

        local hint = Entities.CreateByClassname("env_instructor_hint")
        if (!hint) return null

        hint.__KeyValueFromString("hint_target", targetName)
        hint.__KeyValueFromString("hint_caption", caption)
        hint.__KeyValueFromString("hint_color", format("%d %d %d", rgbColor[0], rgbColor[1], rgbColor[2]))
        hint.__KeyValueFromInt("hint_timeout", ::PingSystem.GLOW_DURATION.tointeger())
        hint.__KeyValueFromFloat("hint_range", ::PingSystem.TRACE_RANGE)
        hint.__KeyValueFromString("hint_icon_onscreen", iconName)
        hint.__KeyValueFromString("hint_icon_offscreen", iconName)
        hint.__KeyValueFromInt("hint_forcecaption", 1)
        hint.__KeyValueFromInt("hint_nooffscreen", 0)
        hint.__KeyValueFromInt("hint_static", 0)
        hint.__KeyValueFromInt("hint_target_pos", 2)
        hint.__KeyValueFromInt("hint_allow_nodraw_target", 1)
        hint.__KeyValueFromString("hint_replace_key", "ping_" + targetName)
        hint.__KeyValueFromString("hint_start_sound", "ui/hint.wav")
        DispatchSpawn(hint)

        for (local p = null; p = Entities.FindByClassname(p, "player"); )
            if (p.IsValid())
                EntFireByHandle(hint, "ShowHint", "!activator", 0.05, p, null)

        return { hint = hint, tempEntity = tempEntity }
    }

    ::PingSystem.CreateWorldMarker <- function(pos, normal, rgbColor)
    {
        local radius = ::PingSystem.CIRCLE_RADIUS
        local segments = ::PingSystem.CIRCLE_SEGMENTS
        local angleStep = 2.0 * PI / segments

        local n = normal
        n.Norm()
        local helper = (abs(n.x) < 0.9) ? Vector(1,0,0) : Vector(0,1,0)
        local tangent1 = n.Cross(helper)
        tangent1.Norm()
        local tangent2 = n.Cross(tangent1)
        tangent2.Norm()

        local pointEntities = []
        local baseName = "ping_circle_" + UniqueString()
        for (local i = 0; i < segments; i++)
        {
            local angle = i * angleStep
            local offset = tangent1 * (radius * cos(angle)) + tangent2 * (radius * sin(angle))
            local pointPos = pos + offset
            local pt = Entities.CreateByClassname("info_target")
            pt.__KeyValueFromString("targetname", baseName + "_" + i)
            pt.SetAbsOrigin(pointPos)
            DispatchSpawn(pt)
            pointEntities.append(pt)
        }

        local beamEnts = []
        local colorStr = format("%d %d %d", rgbColor[0], rgbColor[1], rgbColor[2])
        for (local i = 0; i < segments; i++)
        {
            local startPt = pointEntities[i]
            local endPt = pointEntities[(i + 1) % segments]
            local beam = Entities.CreateByClassname("env_beam")
            if (beam)
            {
                beam.__KeyValueFromString("LightningStart", startPt.GetName())
                beam.__KeyValueFromString("LightningEnd", endPt.GetName())
                beam.__KeyValueFromString("texture", "sprites/laserbeam.spr")
                beam.__KeyValueFromString("rendercolor", colorStr)
                beam.__KeyValueFromInt("life", ::PingSystem.GLOW_DURATION.tointeger())
                beam.__KeyValueFromFloat("BoltWidth", 1.0)
                beam.__KeyValueFromInt("NoiseAmplitude", 0)
                beam.__KeyValueFromInt("spawnflags", 1)
                DispatchSpawn(beam)
                beam.AcceptInput("TurnOn", "", null, null)
                beamEnts.append(beam)
            }
        }

        return { points = pointEntities, beams = beamEnts }
    }

    ::PingSystem.DoPing <- function(player)
    {
        local allowDead = true
        if ("Convars" in getroottable())
            allowDead = Convars.GetBool("sv_ping_allow_dead")

        if (!allowDead && !player.IsAlive())
            return

        local maxActive = 5
        if ("Convars" in getroottable())
            maxActive = Convars.GetInt("sv_ping_max_active")

        if (::PingSystem.activePings.len() >= maxActive)
            return

        local cooldown = 2.0
        if ("Convars" in getroottable())
            cooldown = Convars.GetFloat("sv_ping_cooldown")

        local playerIdx = player.entindex()
        local now = Time()
        local lastTime = (playerIdx in ::PingSystem.LastPingTime) ? ::PingSystem.LastPingTime[playerIdx] : 0.0
        if (now - lastTime < cooldown)
            return
        ::PingSystem.LastPingTime[playerIdx] <- now

        local start = ::PingSystem.GetPlayerEyePosition(player)
        local forward = player.GetEyeForward()
        local end = start + forward * ::PingSystem.TRACE_RANGE

        local trace = TraceLineComplex(start, end, player, ::PingSystem.TRACE_MASK, 0)
        if (!trace.DidHit()) return

        local hitEntity = trace.Entity()
        local rgbColor = ::PingSystem.RandomReadableColor()

        local allowNPCs = true
        if ("Convars" in getroottable())
            allowNPCs = Convars.GetBool("sv_ping_allow_npcs")

        if (hitEntity && hitEntity.IsValid())
        {
            local classname = hitEntity.GetClassname()

            if (classname == "player")
            {
                local targetName = hitEntity.GetPlayerName()
                local displayName = targetName
                local showHealth = false
                if ("Convars" in getroottable())
                    showHealth = Convars.GetBool("sv_ping_show_health")
                if (showHealth)
                {
                    local hp = 0
                    try {
                        if ("GetHealth" in hitEntity) hp = hitEntity.GetHealth()
                        else if ("NetProps" in getroottable()) hp = NetProps.GetPropInt(hitEntity, "m_iHealth")
                    } catch(e) {}
                    if (hp > 0)
                        displayName = targetName + " [HP: " + hp + "]"
                }
                ::PingSystem.ApplyGlow(hitEntity, rgbColor)
                local hintData = ::PingSystem.CreateInstructorHint(hitEntity, player, rgbColor, displayName)
                ::PingSystem.activePings.append({
                    glowEntity = hitEntity,
                    hintEntity = hintData ? hintData.hint : null,
                    expireTime = Time() + ::PingSystem.GLOW_DURATION
                })
                return
            }

            if (classname.find("npc_nmrih") == 0 && !allowNPCs)
                return

            if (::PingSystem.IsGlowableClassname(classname))
            {
                local displayName = ::PingSystem.GetWeaponDisplayName(classname, hitEntity)

                if (displayName != null && (classname.find("fa_") == 0 || classname == "me_chainsaw" || classname == "me_abrasivesaw" || classname == "tool_flare_gun"))
                {
                    local ammo = ::PingSystem.GetWeaponClipAmmo(hitEntity)
                    if (ammo >= 0)
                    {
                        if (classname == "me_chainsaw" || classname == "me_abrasivesaw")
                            displayName = displayName + " (Fuel " + ammo + ")"
                        else if (classname == "tool_flare_gun")
                            displayName = displayName + " (Flare " + ammo + ")"
                        else
                            displayName = displayName + " (" + ammo + ")"
                    }
                }

                if (classname.find("npc_nmrih") == 0)
                {
                    local showHealth = false
                    if ("Convars" in getroottable())
                        showHealth = Convars.GetBool("sv_ping_show_health")
                    if (showHealth)
                    {
                        local hp = 0
                        try {
                            if ("GetHealth" in hitEntity) hp = hitEntity.GetHealth()
                            else if ("NetProps" in getroottable()) hp = NetProps.GetPropInt(hitEntity, "m_iHealth")
                        } catch(e) {}
                        if (hp > 0)
                            displayName = displayName + " [HP: " + hp + "]"
                    }
                }

                ::PingSystem.ApplyGlow(hitEntity, rgbColor)
                local hintData = ::PingSystem.CreateInstructorHint(hitEntity, player, rgbColor, displayName)

                local found = false
                foreach (ping in ::PingSystem.activePings)
                {
                    if ("glowEntity" in ping && ping.glowEntity == hitEntity)
                    {
                        ping.expireTime = Time() + ::PingSystem.GLOW_DURATION
                        if (ping.hintEntity && ping.hintEntity.IsValid())
                            ping.hintEntity.Destroy()
                        ping.hintEntity = hintData ? hintData.hint : null
                        found = true
                        break
                    }
                }
                if (!found)
                {
                    ::PingSystem.activePings.append({
                        glowEntity = hitEntity,
                        hintEntity = hintData ? hintData.hint : null,
                        expireTime = Time() + ::PingSystem.GLOW_DURATION
                    })
                }
                return
            }
        }

        local hitPos = trace.EndPos()
        local hitNormal = trace.Plane().normal
        local marker = ::PingSystem.CreateWorldMarker(hitPos, hitNormal, rgbColor)
        local hintData = ::PingSystem.CreateInstructorHint(hitPos, player, rgbColor, null)

        ::PingSystem.activePings.append({
            markerPoints = marker.points,
            markerBeams = marker.beams,
            hintEntity = hintData ? hintData.hint : null,
            tempEntity = hintData ? hintData.tempEntity : null,
            expireTime = Time() + ::PingSystem.GLOW_DURATION
        })
    }

    ::PingSystem.CleanupExpiredPings <- function()
    {
        local now = Time()
        for (local i = ::PingSystem.activePings.len() - 1; i >= 0; i--)
        {
            local ping = ::PingSystem.activePings[i]
            if (now >= ping.expireTime)
            {
                if ("glowEntity" in ping && ping.glowEntity.IsValid())
                    ::PingSystem.RemoveGlow(ping.glowEntity)
                if ("hintEntity" in ping && ping.hintEntity && ping.hintEntity.IsValid())
                    ping.hintEntity.Destroy()
                if ("tempEntity" in ping && ping.tempEntity && ping.tempEntity.IsValid())
                    ping.tempEntity.Destroy()
                if ("markerPoints" in ping)
                    foreach (p in ping.markerPoints) if (p.IsValid()) p.Destroy()
                if ("markerBeams" in ping)
                    foreach (b in ping.markerBeams) if (b.IsValid()) b.Destroy()
                ::PingSystem.activePings.remove(i)
            }
        }

        for (local i = ::PingSystem.voiceActivePings.len() - 1; i >= 0; i--)
        {
            local ping = ::PingSystem.voiceActivePings[i]
            if (now >= ping.expireTime)
            {
                if ("glowEntity" in ping && ping.glowEntity.IsValid())
                    ::PingSystem.RemoveGlow(ping.glowEntity)
                if ("hintEntity" in ping && ping.hintEntity && ping.hintEntity.IsValid())
                    ping.hintEntity.Destroy()
                if ("tempEntity" in ping && ping.tempEntity && ping.tempEntity.IsValid())
                    ping.tempEntity.Destroy()
                if ("markerPoints" in ping)
                    foreach (p in ping.markerPoints) if (p.IsValid()) p.Destroy()
                if ("markerBeams" in ping)
                    foreach (b in ping.markerBeams) if (b.IsValid()) b.Destroy()
                ::PingSystem.voiceActivePings.remove(i)
            }
        }
    }

    ::PingSystem.Check <- function()
    {
        if (!::PingSystem.running) return
        if (!Convars.GetBool("sv_ping_enabled")) return

        local player = null
        while ((player = Entities.FindByClassname(player, "player")) != null)
        {
            if (!player.IsValid()) continue
            local buttons = player.GetButtons()
            local idx = player.entindex()
            local oldButtons = (idx in ::PingSystem.LastButtons) ? ::PingSystem.LastButtons[idx] : 0
            local want = (buttons & ::PingSystem.IN_VOICECMD) && (buttons & ::PingSystem.IN_USE)
            local was = (oldButtons & ::PingSystem.IN_VOICECMD) && (oldButtons & ::PingSystem.IN_USE)
            if (want && !was) ::PingSystem.DoPing(player)
            ::PingSystem.LastButtons[idx] <- buttons
        }

        ::PingSystem.CleanupExpiredPings()
        EntFire("worldspawn", "RunScriptCode", "::PingSystem.Check()", 0.1)
    }

    ::PingSystem.OnVoiceCommand <- function(params)
    {
        if (!("Convars" in getroottable())) return
        if (!Convars.GetBool("sv_ping_voice_enabled")) return

        local userid = params.userid
        local command = params.command
        local player = GetPlayerByUserId(userid)
        if (!player || !player.IsValid()) return

        local voiceCooldown = 5.0
        if ("Convars" in getroottable())
            voiceCooldown = Convars.GetFloat("sv_ping_voice_cooldown")
        local now = Time()
        local playerIdx = player.entindex()
        local lastVoice = (playerIdx in ::PingSystem.LastVoiceTime) ? ::PingSystem.LastVoiceTime[playerIdx] : 0.0
        if (now - lastVoice < voiceCooldown)
            return
        ::PingSystem.LastVoiceTime[playerIdx] <- now

        local maxVoice = 3
        if ("Convars" in getroottable())
            maxVoice = Convars.GetInt("sv_ping_voice_max_active")
        if (::PingSystem.voiceActivePings.len() >= maxVoice)
            return

        local rgbColor = ::PingSystem.RandomReadableColor()

        switch (command)
        {
            case 0:
            {
                local weapon = player.GetActiveWeapon()
                if (weapon && weapon.IsValid())
                {
                    local weaponClass = weapon.GetClassname()
                    if (weaponClass in ::PingSystem.WeaponAmmoIndexMap)
                    {
                        local ammoIndex = ::PingSystem.WeaponAmmoIndexMap[weaponClass]
                        local ammoName = ::PingSystem.AmmoIndexToName[ammoIndex]
                        local clipAmmo = ::PingSystem.GetWeaponClipAmmo(weapon)
                        local reserveAmmo = 0
                        try {
                            reserveAmmo = player.GetAmmoCount(ammoIndex)
                        } catch(e) {}
                        local msg = format("Need %s: %d/%d", ammoName, clipAmmo, reserveAmmo)
                        ::PingSystem.ApplyGlow(player, rgbColor)
                        local hintData = ::PingSystem.CreateInstructorHint(player, player, rgbColor, msg, false, "icon_alert")
                        ::PingSystem.voiceActivePings.append({
                            glowEntity = player,
                            hintEntity = hintData ? hintData.hint : null,
                            expireTime = Time() + ::PingSystem.GLOW_DURATION
                        })
                    }
                }
                break
            }
            case 1:
            {
                ::PingSystem.ApplyGlow(player, rgbColor)
                local hintData = ::PingSystem.CreateInstructorHint(player, player, rgbColor, "Follow Me!", false, "icon_run")
                ::PingSystem.voiceActivePings.append({
                    glowEntity = player,
                    hintEntity = hintData ? hintData.hint : null,
                    expireTime = Time() + ::PingSystem.GLOW_DURATION
                })
                break
            }
            case 2:
            {
                ::PingSystem.ApplyGlow(player, rgbColor)
                local hintData = ::PingSystem.CreateInstructorHint(player, player, rgbColor, "Help!", false, "icon_alert")
                ::PingSystem.voiceActivePings.append({
                    glowEntity = player,
                    hintEntity = hintData ? hintData.hint : null,
                    expireTime = Time() + ::PingSystem.GLOW_DURATION
                })
                break
            }
            case 4:
            {
                local pos = player.GetOrigin()
                local normal = Vector(0,0,1)
                local marker = ::PingSystem.CreateWorldMarker(pos, normal, rgbColor)
                local hintData = ::PingSystem.CreateInstructorHint(pos, player, rgbColor, "Stop Here!", false, "icon_caution")
                ::PingSystem.voiceActivePings.append({
                    markerPoints = marker.points,
                    markerBeams = marker.beams,
                    hintEntity = hintData ? hintData.hint : null,
                    tempEntity = hintData ? hintData.tempEntity : null,
                    expireTime = Time() + ::PingSystem.GLOW_DURATION
                })
                break
            }
            case 8:
            {
                local health = 0
                try {
                    if ("GetHealth" in player) health = player.GetHealth()
                    else if ("NetProps" in getroottable()) health = NetProps.GetPropInt(player, "m_iHealth")
                } catch(e) {}
                if (health > 0 && health < 50)
                {
                    ::PingSystem.ApplyGlow(player, rgbColor)
                    local msg = "Needs Healing! HP: " + health
                    local hintData = ::PingSystem.CreateInstructorHint(player, player, rgbColor, msg, false, "icon_alert")
                    ::PingSystem.voiceActivePings.append({
                        glowEntity = player,
                        hintEntity = hintData ? hintData.hint : null,
                        expireTime = Time() + ::PingSystem.GLOW_DURATION
                    })
                }
                break
            }
            case 9:
            {
                local pos = player.GetOrigin()
                local hintData = ::PingSystem.CreateInstructorHint(pos, player, rgbColor, "threw a grenade!", false, "icon_caution")
                ::PingSystem.voiceActivePings.append({
                    hintEntity = hintData ? hintData.hint : null,
                    tempEntity = hintData ? hintData.tempEntity : null,
                    expireTime = Time() + 3.0
                })
                break
            }
        }
    }

    ::PingSystem.OnPingCommand <- function(name, ...)
    {
        local player = null
        if ("GetCommandClient" in Convars)
            player = Convars.GetCommandClient()
        if (!player)
        {
            foreach (arg in vargv)
            {
                if (typeof(arg) == "instance" && arg.IsValid() && arg.GetClassname() == "player")
                {
                    player = arg
                    break
                }
            }
        }
        if (!player)
        {
            player = Entities.FindByClassname(null, "player")
            if (!player || !player.IsValid()) return
        }
        ::PingSystem.DoPing(player)
    }

    ::PingSystem.Start <- function()
    {
        if (::PingSystem.running) return
        ::PingSystem.running = true

        if (!::PingSystem._initialized)
        {
            ::PingSystem._initialized = true
            if ("Convars" in getroottable())
            {
                Convars.RegisterConvar("sv_ping_enabled", "1", "Enable/disable the Ping System", 0)
                Convars.RegisterConvar("sv_ping_max_active", "5", "Maximum number of active pings", 0)
                Convars.RegisterConvar("sv_ping_cooldown", "2.0", "Cooldown between pings per player", 0)
                Convars.RegisterConvar("sv_ping_allow_npcs", "1", "Allow pinging NPCs", 0)
                Convars.RegisterConvar("sv_ping_allow_dead", "1", "Allow dead players to ping", 0)
                Convars.RegisterConvar("sv_ping_voice_enabled", "1", "Enable voice command pings", 0)
                Convars.RegisterConvar("sv_ping_voice_cooldown", "5.0", "Cooldown between voice pings per player", 0)
                Convars.RegisterConvar("sv_ping_voice_max_active", "3", "Maximum number of active voice pings", 0)
                Convars.RegisterConvar("sv_ping_show_health", "0", "Show health of NPCs and players in pings", 0)
            }
            if ("ListenToGameEvent" in getroottable())
            {
                ::PingSystem._mapResetListener = ListenToGameEvent("nmrih_reset_map", ::PingSystem.OnReset, "PingSystemMapReset")
                ::PingSystem._roundBeginListener = ListenToGameEvent("nmrih_round_begin", ::PingSystem.OnReset, "PingSystemRoundBegin")
                ::PingSystem._voiceListener = ListenToGameEvent("player_voice_command", ::PingSystem.OnVoiceCommand, "PingSystemVoice")
            }
            if ("Convars" in getroottable() && "RegisterCommand" in Convars)
                Convars.RegisterCommand("sm_ping", ::PingSystem.OnPingCommand, "Trigger a ping", 0)

            if ("PrecacheSound" in getroottable())
                PrecacheSound("ui/hint.wav")
        }

        printl("[PingSystem] Loaded.")
        EntFire("worldspawn", "RunScriptCode", "::PingSystem.Check()", 0.1)
    }

    ::PingSystem.Stop <- function()
    {
        ::PingSystem.running = false
        foreach (ping in ::PingSystem.activePings)
        {
            if ("glowEntity" in ping && ping.glowEntity.IsValid())
                ::PingSystem.RemoveGlow(ping.glowEntity)
            if ("hintEntity" in ping && ping.hintEntity && ping.hintEntity.IsValid())
                ping.hintEntity.Destroy()
            if ("tempEntity" in ping && ping.tempEntity && ping.tempEntity.IsValid())
                ping.tempEntity.Destroy()
            if ("markerPoints" in ping)
                foreach (p in ping.markerPoints) if (p.IsValid()) p.Destroy()
            if ("markerBeams" in ping)
                foreach (b in ping.markerBeams) if (b.IsValid()) b.Destroy()
        }
        ::PingSystem.activePings.clear()

        foreach (ping in ::PingSystem.voiceActivePings)
        {
            if ("glowEntity" in ping && ping.glowEntity.IsValid())
                ::PingSystem.RemoveGlow(ping.glowEntity)
            if ("hintEntity" in ping && ping.hintEntity && ping.hintEntity.IsValid())
                ping.hintEntity.Destroy()
            if ("tempEntity" in ping && ping.tempEntity && ping.tempEntity.IsValid())
                ping.tempEntity.Destroy()
            if ("markerPoints" in ping)
                foreach (p in ping.markerPoints) if (p.IsValid()) p.Destroy()
            if ("markerBeams" in ping)
                foreach (b in ping.markerBeams) if (b.IsValid()) b.Destroy()
        }
        ::PingSystem.voiceActivePings.clear()

        if (::PingSystem._mapResetListener != null && "Remove" in ::PingSystem._mapResetListener)
            ::PingSystem._mapResetListener.Remove()
        if (::PingSystem._roundBeginListener != null && "Remove" in ::PingSystem._roundBeginListener)
            ::PingSystem._roundBeginListener.Remove()
        if (::PingSystem._voiceListener != null && "Remove" in ::PingSystem._voiceListener)
            ::PingSystem._voiceListener.Remove()
        ::PingSystem._mapResetListener = null
        ::PingSystem._roundBeginListener = null
        ::PingSystem._voiceListener = null
    }

    ::PingSystem.OnReset <- function(...)
    {
        ::PingSystem.Stop()
        ::PingSystem.Start()
    }

    ::PingSystem.Start()
}
else
{
    if (!::PingSystem.running) ::PingSystem.Start()
}