//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   Players can call a supply drop in objective mode
//  Usage   :   Shoot flare gun in the sky
//  Notes   :   Might look like ass on some maps, idk
//-----------------------------------------------------------------------------

if (GameRules.GetWinState() != 5)
    return;

printcl(50,145,168,"Running "+getstackinfos(1).src+".");
local CONTEXT = "SUPPLY_ANYWHERE";
local TRANSMIT_ALWAYS = 0;
local ENTRY_POINT = "chopper_entryexit_point";
local NPC_CLASS = "npc_supply_chopper";
local SPAWN_DIST = 10000.0; // Magic number
local SPAWN_DIRS = [Vector(1,0,0), Vector(0,1,0), Vector(-1,0,0), Vector(0,-1,0)];
local function vec_mult(v1,v2) {return Vector(v1.x*v2.x,v1.y*v2.y,v1.z*v2.z)};

if ("__SA" in this)
    return;
__SA <- {};
this = __SA;

CONVARS <- 
{
    MAX_USES      = {VAR = "sv_supply_anywhere_max_uses"    , DESCR = "Max amount of supply runs helis will make."                  ,   DEFAULT = 8.0  , MIN = 0.0,    MAX = 1000.0}
    MAX_HELIS     = {VAR = "sv_supply_anywhere_max_helis"   , DESCR = "Max amount of helis that can be active at the same time."    ,   DEFAULT = 2.0  , MIN = 1.0,    MAX = 5.0}
    VOICELINE     = {VAR = "sv_supply_anywhere_voiceline"   , DESCR = "Enable/Disable heli voiceline during drop-off"               ,   DEFAULT = 1.0  , MIN = 0.0,    MAX = 1.0}
}

function HandleConvarChange(var, string_old_val, old_val, string_new_val, new_val)
{
    VAL = min(max(MIN, new_val), MAX);
}

foreach(convar in CONVARS)
{
    convar.VAL <- convar.DEFAULT;
    Convars.RegisterConvar(convar.VAR, convar.DEFAULT.tostring(), convar.DESCR, FCVAR_GAMEDLL);
    Convars.SetChangeCallback(convar.VAR, HandleConvarChange.bindenv(convar));
}

local num_supply_drops = 0;
local all_helis = {};

class CSupplyHeli
{
    function constructor(pos_target)
    {
        if (all_helis.len() > __SA.CONVARS.MAX_HELIS.VAL)
            return null;

        foreach (heli_data in all_helis)
            if ((heli_data.pos_target - pos_target).Length2D() <= 3000.0)
                return null;

        pos_supply = pos_target;
        suppy_dropped = false;
        foreach(dir in SPAWN_DIRS)
        {
            pos_spawn = pos_supply + dir*SPAWN_DIST;
            if ((vec_mult(pos_spawn,dir)).Length() < MAX_COORD_FLOAT)
                break;
        }

        local entry_points = {};
        local entry_point = null;
        while (entry_point = Entities.FindByClassname(entry_point, ENTRY_POINT))
        {
            entry_points[entry_point] <- entry_point.GetOrigin();
            entry_point.SetOrigin(pos_spawn);
        }

        if (!entry_point)
            entry_point = SpawnEntityFromTable(ENTRY_POINT, { origin = pos_spawn});
        me = SpawnEntityFromTable(NPC_CLASS, { targetname = UniqueString("heli"), origin = pos_supply, angles = VectorAngles(pos_supply - pos_spawn)});
        if (entry_points.len() == 0)
            entry_point.Destroy();
        else foreach(entry, old_pos in entry_points)
            entry.SetOrigin(old_pos);

        me.AddEFlags(EFL_IN_SKYBOX);
        me.SetMoveType(MOVETYPE_NOCLIP);
        me.SetSolid(0);
        all_helis[me] <- {pos_target = pos_supply, instance = this};
        me.SetContextThink(HeliThink.getinfos().name, HeliThink.bindenv(this), 0.0);
    }

    function Destroy()
    {
        if (path && path.IsValid())
            path.Destroy();
        try
        {
            me.StopThinkFunction();
            me.Destroy();
            delete all_helis[me];
        }
        catch (error) { }
    }

    function HeliThink(me)
    {
        if (!this || !me || !me.IsValid())
            return null;
        
        if (suppy_dropped)
        {
            if (path)
            {
                if ((me.GetOrigin()-pos_spawn).Length2DSqr() <= 500.0)
                    Destroy();
            }
            else
                FlyAway();
        }
        else if ((me.GetOrigin()-pos_supply).Length2DSqr() <= 400.0)
        {
            if (!voiceline_played)
                PlayVoiceline();

            if (me.GetVelocity().Length2DSqr() <= 1000.0)
                SpawnSupply();
        }

        return 0.0;
    }

    function SupplyThink(supply_drop)
    {
        if (!supply_drop || !supply_drop.IsValid())
            return null;

        if (supply_idle != null)
        {
            if (Time() > supply_idle)
            {
                local supply_ent = SpawnEntityFromTable("item_inventory_box",
                { 
                    origin = supply_drop.GetOrigin(),
                    angles = supply_drop.GetAngles(),
                    spawnflags = 1,
                    model = supply_drop.GetModelName(),
                });
                // set supply drops weight to that of your mum
                supply_ent.SetMass(900000.0);
                supply_ent.SetCollisionGroup(COLLISION_GROUP_DEBRIS);
                supply_ent.GetPhysicsObject().Wake();
                supply_drop.Destroy();
                return null;
            }
        }
        else if (abs(supply_drop.GetVelocity().z) <= 5.0)
            supply_idle = Time()+0.1;
        return 0.0;
    }

    function PlayVoiceline()
    {
        voiceline_played = true;
        if (__SA.CONVARS.VOICELINE.VAL == 0.0)
            return;
        local sound = SpawnEntityFromTable("ambient_generic", { origin = me.GetOrigin(), spawnflags = 48, volstart = 100, health = 100, pitch = 90, radius = 10000, message = "voice/northway_supply_heli/heli_supply_drop_northway_voice_0"+RandomInt(1,7)+".wav", SourceEntityName = me.GetName()});
        EntFireByHandle(sound, "PlaySound", "", 0.0, null, null);
        EntFireByHandle(sound, "Kill", "", 10.0, null, null);
    }

    function SpawnSupply()
    {
        suppy_dropped = true;
        local template = me.FirstMoveChild();
        local attachment = me.LookupAttachment("carry_attachment");
        local supply_ent = SpawnEntityFromTable("prop_physics_override",
        { 
            origin = me.GetAttachmentOrigin(attachment),
            angles = template.GetAngles(),
            model = template.GetModelName(),
        });
        supply_ent.AddEFlags(EFL_NO_GAME_PHYSICS_SIMULATION);
        supply_ent.SetMoveType(MOVETYPE_FLYGRAVITY);
        supply_ent.SetSolid(2);
        supply_ent.SetCollisionGroup(COLLISION_GROUP_DEBRIS);
        supply_ent.SetContextThink(SupplyThink.getinfos().name, SupplyThink.bindenv(this), 1.0);
        template.Destroy();
    }

    function FlyAway()
    {
        path = SpawnEntityFromTable("path_track",{ origin = pos_spawn, targetname = me.GetName()+"_path"+UniqueString("")});
        me.AcceptInput("SetTrack", path.GetName(), me, me);
    }

    me = null;
    pos_supply = null;
    pos_spawn = null;
    suppy_dropped = null;
    supply_idle = null;
    voiceline_played = null;
    path = null;
}

function DidHitSky(trace)
{
    if (!trace.DidHit() || !trace.DidHitWorld())
        return false;;

    local surface = trace.Surface();

    if (!surface)
        return false;

    local properties = surface.SurfaceProps();

    return (properties && properties.GetMaterialChar() == "X");
}

function DidHitPlayableArea(trace)
{
    if (!trace.DidHit() || !trace.DidHitWorld())
        return false;

    return NavMesh.GetNearestNavArea(trace.EndPos(), 64.0, false, false) != null;
}

function FindDropoffPoint(projectile)
{
    if (num_supply_drops >= __SA.CONVARS.MAX_USES.VAL)
        return;

    local pos_start = projectile.GetOrigin();
    local dir = AngleVectors(projectile.GetAngles());
    local trace = TraceLineComplex(pos_start, pos_start + (dir * 8192.0), projectile, MASK_SOLID, COLLISION_GROUP_NONE);
    if (!DidHitSky(trace))
        return;
    
    local pos_end = trace.EndPos();
    pos_end.z-= 60.0;
    trace.Destroy();

    if (pos_end.z - pos_start.z <= 250.0)
        return; // Too close to skybox

    trace = TraceLineComplex(pos_start, pos_start + Vector(0.0, 0.0, 8192.0), projectile, MASK_SOLID, COLLISION_GROUP_NONE);
    if (DidHitSky(trace))
    {
        pos_end = Vector(pos_start.x, pos_start.y, pos_end.z);
        trace.Destroy();
    }
    else
    {
        trace.Destroy();
        trace = TraceLineComplex(pos_end, pos_end - Vector(0.0, 0.0, 8192.0), projectile, MASK_SOLID, COLLISION_GROUP_NONE);
        if (!DidHitPlayableArea(trace))
        {
            trace.Destroy()
            return;
        }
        trace.Destroy()
    }

    CSupplyHeli(pos_end);
    num_supply_drops++;
}

function HandleMapReset(_)
{
    num_supply_drops = 0;
}

function HandleEntitySpawned(entity) 
{
    if (entity.GetClassname() == "flare_projectile")
        __SA.FindDropoffPoint(entity);
}

function HandleEntityDeleted(entity) 
{
    if (entity.GetClassname() != NPC_CLASS)
        return;

    if (!(entity in all_helis))
        return;

    all_helis[entity].instance.Destroy();
}

StopListeningToAllGameEvents(CONTEXT);
ListenToGameEvent("nmrih_reset_map", HandleMapReset, CONTEXT);

Entities.EnableEntityListening();
Hooks.Add( 0, "OnEntitySpawned", HandleEntitySpawned, CONTEXT);
Hooks.Add( 0, "OnEntityDeleted", HandleEntityDeleted, CONTEXT);

local entity = Entities.First();
while (entity = Entities.Next(entity))
    HandleEntitySpawned(entity)

printcl(255,255,0,"Done loading Mutator: "+CONTEXT);