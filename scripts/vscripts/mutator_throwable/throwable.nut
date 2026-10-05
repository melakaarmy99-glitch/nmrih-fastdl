INFECTION_CHANCE <- 0.5
IRRITANT_RUNNER_CHANCE <- 1.0      
IRRITANT_HOSTILE_DURATION <- 30.0

function IsValidPlayer(p) {
    return p != null && p.GetClassname() == "player" && p.IsAlive();
}

function PlaySoundAtPos(pos, soundPath) {
    local sndEnt = Entities.CreateByClassname("info_target");
    if (!sndEnt) return;
    sndEnt.SetOrigin(pos);
    if ("EmitSound" in sndEnt) sndEnt.EmitSound(soundPath);
    else EntFireByHandle(sndEnt, "PlaySound", soundPath, 0.0, null, null);
    EntFireByHandle(sndEnt, "Kill", "", 2.0, null, null);
}

function CreateParticleEffect(particleName, origin, angles, lifetime = 1.0) {
    if (!particleName || particleName == "") return;
    local particle = SpawnEntityFromTable("info_particle_system", {
        origin = origin,
        angles = angles,
        effect_name = particleName,
        start_active = 1
    });
    if (!particle) return;
    EntFireByHandle(particle, "Kill", "", lifetime, null, null);
}

if ("DispatchParticleEffect" in this) {
    function SafeDispatchParticleEffect(name, pos, ang, entity = null) {
        DispatchParticleEffect(name, pos, ang, entity);
    }
} else {
    function SafeDispatchParticleEffect(name, pos, ang, entity = null) {
        CreateParticleEffect(name, pos, ang, 2.0);
    }
}

function SetEntityGlowBrightPurple(ent) {
    if (!ent || !ent.IsValid()) return;
    try {
        if ("SetGlowable" in ent) ent.SetGlowable(true);
        if ("EnableGlow" in ent) ent.EnableGlow();
        if ("SetGlowColor" in ent) ent.SetGlowColor(255, 0, 255);
        if ("SetGlowDistance" in ent) ent.SetGlowDistance(-1.0);
    } catch(e) { }
}

function RestoreZombieNeutrality(zombie) {
    if (!zombie || !zombie.IsValid()) return;
    if (!("SetRelationship" in zombie)) return;
    local other = null;
    while ((other = Entities.FindByClassname(other, "npc_nmrih*")) != null) {
        if (other == zombie) continue;
        if (!other.IsValid()) continue;
        zombie.SetRelationship(other, 4, 0);
        if ("SetRelationship" in other)
            other.SetRelationship(zombie, 4, 0);
    }
}

function SetZombieHostileToOthers(zombie, duration) {
    if (!zombie || !zombie.IsValid()) return;
    if (!("SetRelationship" in zombie)) return;
    
    local other = null;
    while ((other = Entities.FindByClassname(other, "npc_nmrih*")) != null) {
        if (other == zombie) continue;
        if (!other.IsValid()) continue;
        zombie.SetRelationship(other, 1, 0);
        if ("SetRelationship" in other)
            other.SetRelationship(zombie, 1, 0);
    }
    
    EntFireByHandle(zombie, "RunScriptCode", 
        "if (self && self.IsValid()) RestoreZombieNeutrality(self);", 
        duration, null, null);
}

function SpawnCorrosiveSmokeVisual(pos, duration = 8.0) {
    local smoke = Entities.CreateByClassname("env_smokestack");
    if (!smoke) return;
    smoke.SetOrigin(pos);
    smoke.__KeyValueFromString("SmokeMaterial", "particle/SmokeStack.vmt");
    smoke.__KeyValueFromString("rendercolor", "0 25 0");          
    smoke.__KeyValueFromInt("renderamt", 100);
    smoke.__KeyValueFromFloat("BaseSpread", 50.0);                
    smoke.__KeyValueFromInt("SpreadSpeed", 30);
    smoke.__KeyValueFromFloat("Speed", 60.0);
    smoke.__KeyValueFromFloat("StartSize", 20.0);
    smoke.__KeyValueFromFloat("EndSize", 60.0);
    smoke.__KeyValueFromFloat("Rate", 35.0);
    smoke.__KeyValueFromFloat("JetLength", 60.0);
    smoke.__KeyValueFromInt("WindSpeed", 40);
    smoke.__KeyValueFromFloat("WindAngle", RandomFloat(0, 360));
    smoke.__KeyValueFromFloat("Twist", 45.0);
    smoke.__KeyValueFromFloat("Roll", 35.0);
    DispatchSpawn(smoke);
    smoke.AcceptInput("TurnOn", "", "", 0.0);
    EntFireByHandle(smoke, "TurnOff", "", duration, null, null);
    EntFireByHandle(smoke, "Kill", "", duration + 0.5, null, null);
}

function SpawnIrritantEffect(pos, attacker, spawnBullseyeIfNoZombies = false) {
    PlaySoundAtPos(pos, "ceda_jar_explode.wav");
    SafeDispatchParticleEffect("slime_splash_01", pos, Vector(0,0,0), null);
    SafeDispatchParticleEffect("nmrih_suicide_smg_burst_1", pos, Vector(0,0,0), null);
    PlaySoundAtPos(pos, "physics/flesh/zombie_neck_drain_03.wav");
    
    local radius = 128;
    local hasZombie = false;
    local ent = null;
    while ((ent = Entities.FindInSphere(ent, pos, radius)) != null) {
        local cls = ent.GetClassname();
        
        if (cls == "player" && IsValidPlayer(ent)) {
            local dist = (ent.GetOrigin() - pos).Length();
            if (dist <= radius) {
                local alreadyInfected = false;
                if ("IsInfected" in ent) alreadyInfected = ent.IsInfected();
                if (!alreadyInfected && RandomFloat(0,1) < INFECTION_CHANCE) {
                    if ("BecomeInfected" in ent) ent.BecomeInfected();
                }
            }
            continue;
        }
        
        if (cls.find("npc_nmrih") != 0) continue;
        if (!ent.IsAlive()) continue;
        
        hasZombie = true;  
        
        local isRunner = (cls == "npc_nmrih_runnerzombie");
        if (!isRunner && "BecomeRunner" in ent) ent.BecomeRunner();
        SetEntityGlowBrightPurple(ent);
        SetZombieHostileToOthers(ent, IRRITANT_HOSTILE_DURATION);
    }
    
    if (spawnBullseyeIfNoZombies && !hasZombie) {
        local bullseye = Entities.CreateByClassname("npc_bullseye");
        if (bullseye) {
            bullseye.SetOrigin(pos);
            bullseye.__KeyValueFromInt("spawnflags", 196608);
            bullseye.__KeyValueFromInt("rendermode", 1);
            bullseye.__KeyValueFromInt("sleepstate", 0);
            bullseye.__KeyValueFromInt("health", 1000);
            DispatchSpawn(bullseye);
            bullseye.AcceptInput("Activate", "", null, null);
            EntFireByHandle(bullseye, "Kill", "", 8.0, null, null);
        }
    }

    if (attacker && attacker.IsValid() && IsValidPlayer(attacker)) {
        local forgetRadius = 256;
        local zombiesToReset = [];
        local zombie = null;
        while ((zombie = Entities.FindByClassname(zombie, "npc_nmrih*")) != null) {
            if (!zombie.IsAlive()) continue;
            local dist = (zombie.GetOrigin() - attacker.GetOrigin()).Length();
            if (dist <= forgetRadius) {
                try {
                    if ("SetRelationship" in zombie) {
                        zombie.SetRelationship(attacker, 4, 0);
                        zombiesToReset.append(zombie);
                    }
                } catch(e) { }
            }
        }
        if (zombiesToReset.len() > 0) {
            local restoreTimer = Entities.CreateByClassname("logic_timer");
            if (restoreTimer) {
                restoreTimer.SetOrigin(attacker.GetOrigin());
                restoreTimer.ValidateScriptScope();
                local restoreScope = restoreTimer.GetScriptScope();
                restoreScope.attacker <- attacker;
                restoreScope.zombies <- zombiesToReset;
                restoreScope.OnTimer <- function() {
                    if (this.attacker && this.attacker.IsValid() && this.attacker.IsAlive()) {
                        foreach (z in this.zombies) {
                            if (z && z.IsValid() && z.IsAlive()) {
                                try {
                                    z.SetRelationship(this.attacker, 1, 0);
                                } catch(e) { }
                            }
                        }
                    }
                    EntFireByHandle(self, "Kill", "", 0.0, null, null);
                };
                restoreScope.self <- restoreTimer;
                EntFireByHandle(restoreTimer, "AddOutput", "RefireTime 5.0", 0.0, null, null);
                EntFireByHandle(restoreTimer, "Enable", "", 0.0, null, null);
                EntFireByHandle(restoreTimer, "RunScriptCode", "self.GetScriptScope().OnTimer()", 5.0, null, null);
            }
        }
    }
    // ============================================================================
}

function PrecacheIrritantResources() {
    local dummy = Entities.CreateByClassname("info_target");
    if (dummy) {
        if ("PrecacheSoundScript" in dummy) {
            dummy.PrecacheSoundScript("physics/flesh/zombie_neck_drain_03.wav");
            dummy.PrecacheSoundScript("ceda_jar_explode.wav");
        }
        EntFireByHandle(dummy, "Kill", "", 0.0, null, null);
    }
    try {
        PrecacheParticleSystem("slime_splash_01");
        PrecacheParticleSystem("nmrih_suicide_smg_burst_1");
    } catch(e) { }
}

::PipeBombMutator <- {
    DEBUG = false

    WORLD_MODEL = "models/weapons/grenade/w_pipebomb.mdl"
    VIEW_MODEL = "models/weapons/grenade/v_pipebomb.mdl"
    ICON = "vgui/item_icons/pipe bomb"
    LABEL = "Pipe Bomb"

    REPLACE_PROBABILITY = 30
    WEAPON_CLASS = "exp_grenade"

    LAUNCH_FORCE = 1500
    ROCKET_MODE = false

    COUNTDOWN_DURATION = 8.4
    FAST_THRESHOLD = 3.0
    BEEP_INTERVAL_INITIAL = 0.8
    BEEP_INTERVAL_FAST = 0.4

    EXPLOSION_DAMAGE = 1000
    EXPLOSION_RADIUS = 256

    EXPL_SOUND   = "explode3.wav"
    BEEP_SOUND   = "beep.wav"
    DEPLOY_SOUND = "physics/metal/metal_barrel/metal_barrel_impact_bullet5.wav"

    SPRITE_MODEL = "sprites/redglow1.vmt"
    BULLSEYE_HEIGHT = 10
    PUNCH_MAX = 40.0

    ARMORED_DROP_CHANCE = 2

    g_WeaponData = {}
}

::PipeBombMutator.Log <- function(msg) {
    if (::PipeBombMutator.DEBUG) printl("[PipeBomb] " + msg)
}

if ("Convars" in getroottable()) {
    Convars.RegisterConvar("sv_pipebomb_replace_probability", "30", "Replace probability for exp_grenade", 0)
    Convars.RegisterConvar("sv_pipebomb_armored_drop_chance",   "2", "Armored zombie drop chance (%)", 0)
}

::PipeBombMutator.Precache <- function() {
    local root = getroottable()
    if ("PrecacheModel" in root) {
        root.PrecacheModel(::PipeBombMutator.WORLD_MODEL, true)
        root.PrecacheModel(::PipeBombMutator.VIEW_MODEL, true)
        root.PrecacheModel(::PipeBombMutator.SPRITE_MODEL, true)
    }
    local dummy = Entities.CreateByClassname("info_target")
    if (dummy) {
        if ("PrecacheSoundScript" in dummy) {
            dummy.PrecacheSoundScript(::PipeBombMutator.BEEP_SOUND)
            dummy.PrecacheSoundScript(::PipeBombMutator.DEPLOY_SOUND)
            dummy.PrecacheSoundScript(::PipeBombMutator.EXPL_SOUND)
        }
        EntFireByHandle(dummy, "Kill", "", 0.0, null, null)
    }
}

::PipeBombMutator.MarkWeapon <- function(weapon) {
    if (!weapon || !weapon.IsValid()) return false
    weapon.ValidateScriptScope()
    weapon.GetScriptScope().isPipeBomb <- true
    try { weapon.SetWorldModelOverride(::PipeBombMutator.WORLD_MODEL) } catch(e) {}
    try { weapon.SetViewModelOverride(::PipeBombMutator.VIEW_MODEL) } catch(e) {}
    try { weapon.SetIconOverride(::PipeBombMutator.ICON) } catch(e) {}
    try { weapon.SetLabelOverride(::PipeBombMutator.LABEL) } catch(e) {}
    return true
}

::PipeBombMutator.ReplaceAll <- function() {
    local prob = ::PipeBombMutator.REPLACE_PROBABILITY
    try { prob = Convars.GetInt("sv_pipebomb_replace_probability") } catch(e) {}
    local ent = null
    local count = 0
    while ((ent = Entities.FindByClassname(ent, ::PipeBombMutator.WEAPON_CLASS)) != null) {
        if (!ent.IsValid()) continue
        local scope = ent.GetScriptScope()
        if ("isPipeBomb" in scope && scope.isPipeBomb) continue
        if (RandomInt(1, 100) <= prob) { ::PipeBombMutator.MarkWeapon(ent); count++ }
    }
    if (count > 0) ::PipeBombMutator.Log("Marked " + count + " exp_grenade as Pipe Bomb")
}

::PipeBombMutator.SpawnWeapon <- function(origin, angles) {
    local weapon = Entities.CreateByClassname(::PipeBombMutator.WEAPON_CLASS)
    if (!weapon) {
        ::PipeBombMutator.Log("Failed to create weapon entity for drop")
        return null
    }
    weapon.SetOrigin(origin)
    weapon.SetAngles(angles)
    DispatchSpawn(weapon)
    ::PipeBombMutator.MarkWeapon(weapon)
    ::PipeBombMutator.Log("Spawned Pipe Bomb weapon at " + origin)
    return weapon
}

::PipeBombMutator.OnNPCKilled <- function(params) {
    local zombie = EntIndexToHScript(params.entidx)
    if (!zombie || !zombie.IsValid()) return
    local classname = zombie.GetClassname()
    if (classname.find("npc_nmrih") != 0) return
    local hasArmor = false
    try { hasArmor = zombie.HasArmor() } catch(e) { return }
    if (!hasArmor) return
    local killer = EntIndexToHScript(params.killeridx)
    if (!killer || killer.GetClassname() != "player") return
    local dropProb = ::PipeBombMutator.ARMORED_DROP_CHANCE
    try { dropProb = Convars.GetInt("sv_pipebomb_armored_drop_chance") } catch(e) {}
    if (RandomInt(1, 100) > dropProb) return
    local origin = zombie.GetOrigin()
    local angles = Vector(0, RandomInt(0, 360), 0)
    ::PipeBombMutator.SpawnWeapon(origin, angles)
    ::PipeBombMutator.Log("Armored zombie dropped Pipe Bomb at " + origin)
}

::PipeBombMutator.EmitSoundOnEntity <- function(entity, sound) {
    if (!entity || !entity.IsValid()) return
    if ("EmitSound" in entity) entity.EmitSound(sound)
    else EntFireByHandle(entity, "PlaySound", sound, 0.0, null, null)
}

::PipeBombMutator.CreatePhysicalGrenade <- function(player, origin, angles, forward) {
    local force = ::PipeBombMutator.LAUNCH_FORCE
    local rocketMode = ::PipeBombMutator.ROCKET_MODE
    local countdown = ::PipeBombMutator.COUNTDOWN_DURATION

    local grenade = SpawnEntityFromTable("prop_physics_override", {
        origin = origin,
        angles = angles,
        mass = 25.0,
        model = ::PipeBombMutator.WORLD_MODEL,
        targetname = "pipebomb_phys_" + UniqueString(),
        collisiongroup = 2,
        solid = 6
    })
    if (!grenade) return null

    grenade.__KeyValueFromInt("collisiongroup", 2)
    grenade.__KeyValueFromInt("solid", 6)
    if ("SetCollisionGroup" in grenade) grenade.SetCollisionGroup(2)
    grenade.SetOwner(player)

    grenade.ValidateScriptScope()
    local scope = grenade.GetScriptScope()
    scope.owner <- player
    scope.explodeTime <- Time() + countdown
    scope.mod <- ::PipeBombMutator

    local phys = grenade.GetPhysicsObject()
    if (phys) {
        if (rocketMode) phys.EnableGravity(false)
        phys.ApplyForceCenter(forward * force)
    }

    local spark = Entities.CreateByClassname("env_spark")
    if (spark) {
        spark.__KeyValueFromString("MaxDelay", "0.1")
        spark.__KeyValueFromString("Magnitude", "1")
        spark.__KeyValueFromString("TrailLength", "1")
        spark.__KeyValueFromString("rendercolor", "255 0 0")
        DispatchSpawn(spark)
        spark.SetParent(grenade, "")
        spark.SetLocalOrigin(Vector(0, 0, 8))
        scope.spark <- spark
    }

    local sprite = Entities.CreateByClassname("env_sprite")
    if (sprite) {
        sprite.__KeyValueFromString("model", ::PipeBombMutator.SPRITE_MODEL)
        sprite.__KeyValueFromFloat("scale", 0.6)
        sprite.__KeyValueFromInt("rendermode", 5)
        sprite.__KeyValueFromInt("renderamt", 255)
        sprite.__KeyValueFromString("rendercolor", "255 0 0")
        sprite.__KeyValueFromInt("spawnflags", 0)
        DispatchSpawn(sprite)
        sprite.SetParent(grenade, "")
        sprite.SetLocalOrigin(Vector(0, 0, 8))
        scope.sprite <- sprite
    }

    local bullseye = Entities.CreateByClassname("npc_bullseye")
    if (bullseye) {
        bullseye.__KeyValueFromInt("health", 99999)
        bullseye.__KeyValueFromInt("takedamage", 0)
        bullseye.__KeyValueFromInt("spawnflags", 0)
        bullseye.__KeyValueFromInt("solid", 0)
        DispatchSpawn(bullseye)
        bullseye.SetParent(grenade, "")
        bullseye.SetLocalOrigin(Vector(0, 0, ::PipeBombMutator.BULLSEYE_HEIGHT))
        bullseye.SetLocalAngles(Vector(0, 0, 0))
        scope.bullseye <- bullseye
    }

    ::PipeBombMutator.EmitSoundOnEntity(grenade, ::PipeBombMutator.DEPLOY_SOUND)

    local idx = grenade.entindex()
    EntFireByHandle(grenade, "RunScriptCode",
        "PipeBombMutator.ScheduleBeepByIndex(" + idx + ")",
        0.5, null, null)
    return grenade
}

::PipeBombMutator.ScheduleBeepByIndex <- function(idx) {
    local ent = EntIndexToHScript(idx)
    if (!ent || !ent.IsValid()) return
    local scope = ent.GetScriptScope()
    if (!scope || ("exploded" in scope)) return
    local remaining = scope.explodeTime - Time()
    if (remaining <= 0) {
        ::PipeBombMutator.ExplodeGrenade(ent)
        return
    }
    ::PipeBombMutator.EmitSoundOnEntity(ent, ::PipeBombMutator.BEEP_SOUND)
    if (scope.spark && scope.spark.IsValid()) EntFireByHandle(scope.spark, "SparkOnce", "", 0.0, null, null)
    if (scope.sprite && scope.sprite.IsValid()) {
        scope.sprite.AcceptInput("ShowSprite", "", "", 0.0)
        EntFireByHandle(scope.sprite, "HideSprite", "", 0.15, null, null)
    }
    local interval = remaining <= ::PipeBombMutator.FAST_THRESHOLD ? ::PipeBombMutator.BEEP_INTERVAL_FAST : ::PipeBombMutator.BEEP_INTERVAL_INITIAL
    EntFireByHandle(ent, "RunScriptCode",
        "PipeBombMutator.ScheduleBeepByIndex(" + idx + ")",
        interval, null, null)
}

::PipeBombMutator.ExplodeGrenade <- function(grenade) {
    local scope = grenade.GetScriptScope()
    if ("exploded" in scope) return
    scope.exploded <- true
    local pos = grenade.GetOrigin()
    local owner = scope.owner

    ::PipeBombMutator.DoExplosionInternal(pos, owner)

    if ("spark" in scope && scope.spark && scope.spark.IsValid())
        EntFireByHandle(scope.spark, "Kill", "", 0.0, null, null)
    if ("sprite" in scope && scope.sprite && scope.sprite.IsValid())
        EntFireByHandle(scope.sprite, "Kill", "", 0.0, null, null)
    if ("bullseye" in scope && scope.bullseye && scope.bullseye.IsValid())
        EntFireByHandle(scope.bullseye, "Kill", "", 0.0, null, null)
    EntFireByHandle(grenade, "Kill", "", 0.1, null, null)
}

::PipeBombMutator.DoExplosionInternal <- function(pos, attacker) {
    local damage = ::PipeBombMutator.EXPLOSION_DAMAGE
    local radius = ::PipeBombMutator.EXPLOSION_RADIUS

    local exp = Entities.CreateByClassname("env_explosion")
    if (exp) {
        exp.__KeyValueFromInt("iMagnitude", damage)
        exp.__KeyValueFromInt("iRadiusOverride", radius)
        exp.SetOrigin(pos)
        if (attacker && attacker.IsValid()) {
            exp.SetOwner(attacker)
            if (NetProps.HasProp(exp, "m_hAttacker"))
                NetProps.SetPropEntity(exp, "m_hAttacker", attacker)
        }
        exp.AcceptInput("Explode", "", "", 0.0)
        EntFireByHandle(exp, "Kill", "", 0.1, null, null)
    }

    local snd = Entities.CreateByClassname("info_target")
    if (snd) {
        snd.SetOrigin(pos)
        ::PipeBombMutator.EmitSoundOnEntity(snd, ::PipeBombMutator.EXPL_SOUND)
        EntFireByHandle(snd, "Kill", "", 2.0, null, null)
    }

    local p = null
    while ((p = Entities.FindByClassname(p, "player")) != null) {
        if (!p.IsAlive()) continue
        local dist = (p.GetOrigin() - pos).Length()
        if (dist < radius) {
            local f = 1.0 - dist / radius
            p.ViewPunch(Vector(f * ::PipeBombMutator.PUNCH_MAX * 0.8,
                               f * ::PipeBombMutator.PUNCH_MAX * RandomFloat(-0.6, 0.6),
                               f * ::PipeBombMutator.PUNCH_MAX * RandomFloat(-0.3, 0.3)))
        }
    }

    local zombie = null
    while ((zombie = Entities.FindByClassname(zombie, "npc_nmrih*")) != null) {
        if (!zombie.IsAlive()) continue
        local dist = (zombie.GetOrigin() - pos).Length()
        if (dist < radius) {
            try {
                if ("GetShoved" in zombie) {
                    zombie.GetShoved(attacker)
                }
            } catch(e) { }
        }
    }
}

::PipeBombMutator.OnEntitySpawned <- function(entity) {
    if (entity.GetClassname() != "grenade_projectile") return
    local owner = entity.GetOwner()
    if (!owner || !owner.IsPlayer()) return
    local weapon = owner.GetActiveWeapon()
    if (!weapon || weapon.GetClassname() != ::PipeBombMutator.WEAPON_CLASS) return
    local scope = weapon.GetScriptScope()
    if (!("isPipeBomb" in scope) || !scope.isPipeBomb) return
    local forward = owner.GetEyeForward()
    local origin = owner.EyePosition() + forward * 20.0
    local angles = owner.EyeAngles()
    local physNade = ::PipeBombMutator.CreatePhysicalGrenade(owner, origin, angles, forward)
    if (physNade) {
        EntFireByHandle(entity, "Kill", "", 0.0, null, null)
        ::PipeBombMutator.Log("Replaced grenade_projectile with Pipe Bomb")
    }
}

::PipeBombMutator.OnMapReset <- function(_) { ::PipeBombMutator.ReplaceAll() }
::PipeBombMutator.OnRoundBegin <- function(_) { ::PipeBombMutator.ReplaceAll() }

::GivePipeBomb <- function() {
    local player = null
    while ((player = Entities.FindByClassname(player, "player")) != null) {
        if (player.IsAlive()) break
    }
    if (!player) { printl("[PipeBomb] No alive player!"); return }
    local weapon = Entities.CreateByClassname("exp_grenade")
    weapon.SetOrigin(player.EyePosition() + player.GetEyeForward() * 20)
    weapon.SetAngles(Vector(0,0,0))
    DispatchSpawn(weapon)
    ::PipeBombMutator.MarkWeapon(weapon)
    printl("[PipeBomb] Gave Pipe Bomb to " + player)
}

::VomitJarMutator <- {
    DEBUG = false

    WORLD_MODEL = "models/weapons/exp_molotov/w_bile_flask.mdl"
    VIEW_MODEL = "models/weapons/exp_molotov/v_bile_flask.mdl"
    ICON = "vgui/item_icons/vomitjar"
    LABEL = "Vomit Jar"

    REPLACE_PROBABILITY = 30
    WEAPON_CLASS = "exp_molotov"
    PROJECTILE_CLASS = "molotov_projectile"

    PHYS_BOTTLE_LIFETIME = 8.0
    LAUNCH_SPEED         = 5000.0
    SPAWN_OFFSET         = 70.0      
}

::VomitJarMutator.Log <- function(msg) {
    if (::VomitJarMutator.DEBUG) printl("[VomitJar] " + msg)
}

if ("Convars" in getroottable()) {
    Convars.RegisterConvar("sv_vomitjar_replace_probability", "30", "Replace probability for exp_molotov", 0)
}

::VomitJarMutator.Precache <- function() {
    local root = getroottable()
    if ("PrecacheModel" in root) {
        root.PrecacheModel(::VomitJarMutator.WORLD_MODEL, true)
        root.PrecacheModel(::VomitJarMutator.VIEW_MODEL, true)
    }
    PrecacheIrritantResources();
    ::VomitJarMutator.Log("Precached models and Irritant resources")
}

::VomitJarMutator.MarkWeapon <- function(weapon) {
    if (!weapon || !weapon.IsValid()) return false
    weapon.ValidateScriptScope()
    weapon.GetScriptScope().isVomitJar <- true
    try { weapon.SetWorldModelOverride(::VomitJarMutator.WORLD_MODEL) } catch(e) {}
    try { weapon.SetViewModelOverride(::VomitJarMutator.VIEW_MODEL) } catch(e) {}
    try { weapon.SetIconOverride(::VomitJarMutator.ICON) } catch(e) {}
    try { weapon.SetLabelOverride(::VomitJarMutator.LABEL) } catch(e) {}
    ::VomitJarMutator.Log("Marked weapon as Vomit Jar: " + weapon)
    return true
}

::VomitJarMutator.ReplaceAll <- function() {
    local prob = ::VomitJarMutator.REPLACE_PROBABILITY
    try { prob = Convars.GetInt("sv_vomitjar_replace_probability") } catch(e) {}
    local ent = null
    local count = 0
    while ((ent = Entities.FindByClassname(ent, ::VomitJarMutator.WEAPON_CLASS)) != null) {
        if (!ent.IsValid()) continue
        local scope = ent.GetScriptScope()
        if ("isVomitJar" in scope && scope.isVomitJar) continue
        if (RandomInt(1, 100) <= prob) {
            ::VomitJarMutator.MarkWeapon(ent)
            count++
        }
    }
    if (count > 0) ::VomitJarMutator.Log("Marked " + count + " exp_molotov as Vomit Jar")
}

::VomitJarMutator.CreatePhysicalBottle <- function(player, origin, angles, forward) {
    local bottle = SpawnEntityFromTable("prop_physics_override", {
        origin = origin,
        angles = angles,
        mass = 1.0,
        model = ::VomitJarMutator.WORLD_MODEL,
        targetname = "vomitjar_phys_" + UniqueString(),
        collisiongroup = 2,
        solid = 6
    })
    if (!bottle) return null

    bottle.SetOwner(player)
    bottle.ValidateScriptScope()
    local scope = bottle.GetScriptScope()
    scope.owner <- player
    scope.spawnTime <- Time()
    scope.triggered <- false
    scope.mod <- ::VomitJarMutator

    scope.VPhysicsCollision <- function() {
        if (this.triggered) return true
        this.triggered = true

        local pos = self.GetOrigin()
        SpawnCorrosiveSmokeVisual(pos, 8.0);
        SpawnIrritantEffect(pos, this.owner, true);

        EntFireByHandle(self, "Kill", "", 0.0, null, null)
        return true
    }

    scope.TimeoutCheck <- function() {
        if (this.triggered) return -1
        if (Time() - this.spawnTime >= this.mod.PHYS_BOTTLE_LIFETIME) {
            local pos = self.GetOrigin()
            SpawnCorrosiveSmokeVisual(pos, 8.0);
            SpawnIrritantEffect(pos, this.owner, true);
            this.triggered = true
            EntFireByHandle(self, "Kill", "", 0.0, null, null)
            return -1
        }
        return 0.5
    }
    AddThinkToEnt(bottle, "TimeoutCheck")

    local phys = bottle.GetPhysicsObject()
    if (phys) {
        phys.ApplyForceCenter(forward * ::VomitJarMutator.LAUNCH_SPEED)
    }

    ::VomitJarMutator.Log("Created physical Vomit Jar bottle")
    return bottle
}

::VomitJarMutator.OnEntityCreated <- function(entity) {
    if (entity.GetClassname() != ::VomitJarMutator.PROJECTILE_CLASS) return

    local owner = null
    try {
        owner = entity.GetOwner()
    } catch(e) { return }
    if (!owner || !owner.IsPlayer()) return

    local weapon = owner.GetActiveWeapon()
    if (!weapon || weapon.GetClassname() != ::VomitJarMutator.WEAPON_CLASS) return

    local scope = weapon.GetScriptScope()
    if (!("isVomitJar" in scope) || !scope.isVomitJar) return

    local forward = owner.GetEyeForward()
    local origin = owner.EyePosition() + forward * ::VomitJarMutator.SPAWN_OFFSET
    local angles = owner.EyeAngles()

    EntFireByHandle(entity, "Kill", "", 0.0, null, null)

    local bottle = ::VomitJarMutator.CreatePhysicalBottle(owner, origin, angles, forward)
    if (bottle) {
        ::VomitJarMutator.Log("OnEntityCreated: Replaced molotov_projectile with Vomit Jar bottle")
    } else {
        ::VomitJarMutator.Log("OnEntityCreated: Failed to create Vomit Jar bottle")
    }
}

::VomitJarMutator.OnMapReset <- function(_) { ::VomitJarMutator.ReplaceAll() }
::VomitJarMutator.OnRoundBegin <- function(_) { ::VomitJarMutator.ReplaceAll() }

::SpawnVomitJar <- function(origin = null, angles = null) {
    if (!origin) {
        local player = null
        while ((player = Entities.FindByClassname(player, "player"))) {
            if (player.IsAlive()) {
                origin = player.EyePosition() + player.GetEyeForward() * ::VomitJarMutator.SPAWN_OFFSET
                angles = Vector(0, player.GetAngles().y, 0)
                break
            }
        }
        if (!origin) {
            ::VomitJarMutator.Log("No alive player found to spawn Vomit Jar")
            return null
        }
    }
    local weapon = Entities.CreateByClassname(::VomitJarMutator.WEAPON_CLASS)
    if (!weapon) {
        ::VomitJarMutator.Log("Failed to create weapon entity")
        return null
    }
    weapon.SetOrigin(origin)
    weapon.SetAngles(angles)
    DispatchSpawn(weapon)
    ::VomitJarMutator.MarkWeapon(weapon)
    ::VomitJarMutator.Log("Spawned Vomit Jar at " + origin)
    return weapon
}

::GiveVomitJar <- function(player = null) {
    if (!player) {
        local pl = null
        while ((pl = Entities.FindByClassname(pl, "player"))) {
            if (pl.IsAlive()) { player = pl; break }
        }
        if (!player) {
            ::VomitJarMutator.Log("No alive player found to give Vomit Jar")
            return false
        }
    }
    local forward = player.GetEyeForward()
    local origin = player.EyePosition() + forward * ::VomitJarMutator.SPAWN_OFFSET
    local angles = Vector(0, player.GetAngles().y, 0)
    local weapon = ::SpawnVomitJar(origin, angles)
    if (weapon && weapon.IsValid()) {
        ::VomitJarMutator.Log("Vomit Jar spawned in front of player")
        return true
    }
    return false
}

::VomitJar_SetDebug <- function(enable) {
    ::VomitJarMutator.DEBUG = enable
    ::VomitJarMutator.Log("Debug mode " + (enable ? "ON" : "OFF"))
}

::PipeBombMutator.Precache()
if ("ListenToGameEvent" in getroottable()) {
    ListenToGameEvent("nmrih_reset_map", ::PipeBombMutator.OnMapReset, "PipeBombMapReset")
    ListenToGameEvent("nmrih_round_begin", ::PipeBombMutator.OnRoundBegin, "PipeBombRoundBegin")
    ListenToGameEvent("npc_killed", ::PipeBombMutator.OnNPCKilled, "PipeBombNPCKilled")
    ::PipeBombMutator.Log("Pipe Bomb events registered")
}
if ("Hooks" in getroottable()) {
    Hooks.Add(getroottable(), "OnEntitySpawned", ::PipeBombMutator.OnEntitySpawned, "PipeBombSpawnHook")
}

::VomitJarMutator.Precache()
if ("EnableEntityListening" in Entities) {
    Entities.EnableEntityListening()
    ::VomitJarMutator.Log("Entity listening enabled")
}
if ("Hooks" in getroottable()) {
    Hooks.Add(getroottable(), "OnEntityCreated", ::VomitJarMutator.OnEntityCreated, "VomitJarEntityCreatedHook")
}
if ("ListenToGameEvent" in getroottable()) {
    ListenToGameEvent("nmrih_reset_map", ::VomitJarMutator.OnMapReset, "VomitJarMapReset")
    ListenToGameEvent("nmrih_round_begin", ::VomitJarMutator.OnRoundBegin, "VomitJarRoundBegin")
    ::VomitJarMutator.Log("Vomit Jar events registered")
}

::PipeBombMutator.ReplaceAll()
::VomitJarMutator.ReplaceAll()

printl("[Mutators] Loaded.")