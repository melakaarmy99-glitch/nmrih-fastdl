//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   Adds scriptable loot tables to random_spawners, zombie drops and supply drops.
//  Usage   :   Include this file before the round starts. All logic is executed on round start.
//              Won't do anything if round already started or if still in practice time.
//
//              Call LootManager.RegisterCustomItem(item_data), preferably when mutators are loaded, to add a new item.
//              "item_data" needs to be a table containing at least the key "reference". 
//              "reference" should be a reference to the class to be instantiated, or your callback function.
//   
//              Call LootManager.RegisterPool(pool_name, add_to) to define a custom item pool.
//              For example usage for both of these functions see stamina items or https://steamcommunity.com/sharedfiles/filedetails/?id=3257013215
//
//  Notes   :   This mutator will disable default spawning of all random_spawners and zombie drops and replace it with
//              items from the corresponding pools inside "item_pools" found inside "item_defaults.nut".
//              Custom items can't be inside these item pools: supply_medical, supply_weapon_rare, supply_weapon, supply_ammo.
//              That's because of a technical limitation. The item_custom entity can't be added to supply drops.
//              Type "script LootManager.PrintItemPools()" in console to print all available pools with their spawn chances.
//-----------------------------------------------------------------------------

if ("LootManager" in getroottable())
    return;
this = (LootManager <- {});

printcl(50,145,168,"Including "+getstackinfos(1).src+".");

local VERSION = "1.135";
local CONTEXT = "CUSTOM_LOOT";
local SPAWNER = "random_spawner";
local SUPPLY_BOX = "item_inventory_box";
local SPAWNER_CONTROLLER = "random_spawner_controller";

local FL_REMOVE_EMPTY_BOX = 1<<0;
local FL_DISABLE_ITEM_MOTION = 1<<0;
local FL_DONT_SPAWN = 1<<1;
local FL_TOSS_ME_ABOUT = 1<<2;
local sv_random_spawner_vel = Convars.GetFloat("sv_random_spawner_vel");
local sv_random_spawner_ang_vel = Convars.GetFloat("sv_random_spawner_ang_vel");

RulesetManager.ApplyCvars("sv_ng_zombie_loot 0");
local custom_items = {};
random_spawners <- {};
random_spawner_limits <- {};
local random_spawner_controller = ::Entities.FindByClassname(null, SPAWNER_CONTROLLER);
if (random_spawner_controller)
{
    random_spawner_controller.GetSpawnLimits(random_spawner_limits);
    foreach (class_name, amount in random_spawner_limits)
        random_spawner_limits[class_name] <- { max = amount, spawned = 0};
}

IncludeScript(CONTEXT+"/item_defaults", this);

local function HasFlag(i,f) {return !!(i&f)}
local TossAbout = function(entity)
{
    local velocity = Vector( RandomFloat(-1.0, 1.0), RandomFloat(-1.0, 1.0), RandomFloat(-1.0, 1.0));
    entity.SetAbsAngles( velocity * 360.0);
    local phys = entity.GetPhysicsObject();
    phys.ApplyForceCenter(velocity * sv_random_spawner_vel);
    phys.ApplyTorqueCenter(velocity * sv_random_spawner_ang_vel);
}

function SpawnFromClassname(pos, angles, class_name, no_motion = false, toss_about = false, fill_percentage = 100)
{
    local type = item_pools[class_name].type;

    switch (type)
    {
        case POOL_TYPE.AMMO:
            return SpawnAmmo(pos, angles, class_name, no_motion, toss_about, fill_percentage);
        case POOL_TYPE.WEAPON:
            return SpawnWeapon(pos, angles, class_name, no_motion, toss_about, fill_percentage);
        case POOL_TYPE.ITEM_CUSTOM:
            return SpawnCustom(pos, angles, class_name);
    }
}

function SpawnWeapon(pos, angles, class_name, no_motion, toss_about, fill_percentage)
{
    local weapon = SpawnEntityFromTable(class_name, {origin = pos, angles = angles});
    if (!weapon)
        return weapon;

    local max = weapon.GetMaxClip1();
    if (max > 0)
        weapon.SetClip1(fill_percentage * 0.01 * max);

    if (no_motion)
        weapon.GetPhysicsObject().Sleep();
    else if (toss_about)
        TossAbout(weapon);
    return weapon;
}

function SpawnAmmo(pos, angles, class_name, no_motion, toss_about, fill_percentage)
{
    local ammo = SpawnEntityFromTable("item_ammo_box", { origin = pos, angles = angles });
    if (!ammo)
        return ammo;

    ammo.SetAmmoType(class_name);
    ammo.SetAmmoCount(fill_percentage * 0.01 * ammo.GetMaxAmmo());

    if (no_motion)
        ammo.GetPhysicsObject().Sleep();
    else if (toss_about)
        TossAbout(ammo);
    return ammo;
}

function SpawnCustom(pos, angles, class_name)
{
    local custom_item = custom_items[class_name].reference(pos, angles);
    if (!custom_item)
        return;
    if ("inventory_item" in custom_item)
        return custom_item.inventory_item;
    return custom_item;
}

function ReduceToClassname(spawner_data)
{
    //steps through pools until there's just one classname left
    local type = spawner_data.type;
    local pool = spawner_data.pool;
    local pool_name;
    while (true)
    {
        local new_pool_name = RollFromPool(pool);
        if (!new_pool_name || new_pool_name == pool_name)
            break; // prevent recursive self reference
        pool_name = new_pool_name;
        type = item_pools[pool_name].type;
        pool = item_pools[pool_name].pool;
    }
    return pool.len() == 0 ? null : pool_name;
}

function ShuffleArray(a)
{
    if (a.len() <= 1)
        return a;
    local j, k;
    local n = a.len()-1;
    for (local i = n; i != 0; i--)
    {
        j = RandomInt(0,i);
        k = a[j];
        a[j] = a[i]; 
        a[i] = k;
    }
    return a;
}

function RollFromPool(pool)
{
    local rnd = RandomInt(0,100);
    local sum_percentage = 0;
    local yikes_bro;

    local keys = ShuffleArray(pool.keys());

    foreach(key in keys)
        if ((sum_percentage+=pool[key]) >= rnd)
            return key;

    return (sum_percentage < 99.0) ? null : keys[0]; // workaround for FP-imprecision
}

function RollFromPool_old(pool)
{
    local rnd = RandomInt(0,100);
    local sum_percentage = 0;
    local yikes_bro;

    foreach(pool_name, percentage in pool)
    {
        yikes_bro = pool_name;
        if ((sum_percentage+=percentage) >= rnd)
            return pool_name;
    }
    return (sum_percentage < 99.0) ? null : yikes_bro; // workaround for FP-imprecision
}

function TriggerRandomSpawner(spawner_data)
{
    local class_name = ReduceToClassname(spawner_data);
    if (!class_name)
        return false;

    local limiter;
    if (class_name in random_spawner_limits)
    {
        limiter = random_spawner_limits[class_name];
        if (limiter.spawned >= limiter.max)
            return false;
    }

    local no_motion = false;
    local toss_about = false;
    if ("spawnflags" in spawner_data)
    {
        no_motion = HasFlag(FL_DISABLE_ITEM_MOTION, spawner_data.spawnflags)
        toss_about = HasFlag(FL_TOSS_ME_ABOUT, spawner_data.spawnflags)
    }

    local success = SpawnFromClassname(spawner_data.origin, spawner_data.angles, class_name, no_motion, toss_about, RandomInt(spawner_data.AmmoFillPctMin, spawner_data.AmmoFillPctMax));
    if (success && limiter)
        limiter.spawned++;

    return success;
}

local ProcessInputSpawn = function()
{
    if (!(ID in LootManager.random_spawners))
    {
        error(self.GetName()+" missing spawner data!");
        return false;
    }
    LootManager.TriggerRandomSpawner(LootManager.random_spawners[ID]);
    return false;
}

function InterceptSpawner(random_spawner)
{
    local is_dormant = HasFlag(random_spawner.GetSpawnFlags(), FL_DONT_SPAWN);
    local has_name = random_spawner.GetName().len() != 0;
    local spawner_data = {};
    if (has_name)
    {
        random_spawners[random_spawner.GetScriptId()] <- {};
        spawner_data = random_spawners[random_spawner.GetScriptId()];

        local scope = random_spawner.GetOrCreatePrivateScriptScope();
        scope.ID <- random_spawner.GetScriptId();
        scope.Inputinputspawn <- ProcessInputSpawn.bindenv(scope);
        scope.InputInputSpawn <- ProcessInputSpawn.bindenv(scope);
        //SpawnPlaceholder(random_spawner);
    }
 
    ParseSpawner(random_spawner, spawner_data);

    if (!is_dormant)
        if (!TriggerRandomSpawner(spawner_data))
            EntFireByHandle(random_spawner, "Kill", "", 0.0, null, null);
}

function ParseSpawner(random_spawner, spawner_data)
{
    spawner_data.origin <- random_spawner.GetOrigin();
    spawner_data.angles <- random_spawner.GetAngles();
    spawner_data.spawnflags <- random_spawner.GetSpawnFlags();
    spawner_data.AmmoFillPctMin <- ::NetProps.GetPropInt(random_spawner, "m_iAmmoFillPctMin");
    spawner_data.AmmoFillPctMax <- ::NetProps.GetPropInt(random_spawner, "m_iAmmoFillPctMax");
    spawner_data.pool <- {};
    spawner_data.type <- POOL_TYPE.POOL_SPAWNER;
    local added_weights = 0;
    for (local i = 0; i <= 75; i++)
    {
        local weight = ::NetProps.GetPropInt(random_spawner, "m_iSpawnWeights["+i+"]");
        added_weights+=weight;
        if (weight > 0)
            spawner_data.pool[weight_order[i]] <- weight;
    }
    if (added_weights < 100)
        spawner_data.pool.rest <- 100-added_weights;
}

local InterceptNGDrop = function(zombie)
{
    local class_name = LootManager.ReduceToClassname(LootManager.item_pools.ng_drop);
    if (class_name)
        SpawnFromClassname(zombie.GetOrigin() + Vector(0,0,40), Vector() ,class_name);
}

local InterceptCrate = function(crate)
{
    // bool is flipped in version 1135, but will be fixed in the next update. 
    // Timebomb thois to avoid having to re-fix it in the future
    local timebomb = Version.GetBuildNumber() > 1135;
    
    // we only change vanilla crates
    if (was_modified)
        return null;

    if (remove_empty)
        self.AllowEmpty(timebomb);

    self.RemoveAllItems();

    while (self.AddItem(LootManager.ReduceToClassname(LootManager.item_pools.supply_ammo))) { }
    while (self.AddItem(LootManager.ReduceToClassname(LootManager.item_pools.supply_medical))) { }

    local rate_weapon_chance = Convars.GetFloat("sv_rare_weapon_chance") * (2.0 / LootManager.item_pools.supply_weapon.pool.len());
    local class_name;
    do 
    {
        class_name = LootManager.ReduceToClassname(RandomFloat(0, 1) < rate_weapon_chance ? LootManager.item_pools.supply_weapon_rare : LootManager.item_pools.supply_weapon);
    }
    while (self.AddItem(class_name))

    if (remove_empty)
        self.AllowEmpty(!timebomb);
}

local SetModified = function()
{
    was_modified = true; 
    return true
}

function HandleEntityCreated(entity) 
{
    switch (entity.GetClassname())
    {
        case SPAWNER:
            entity.SetDisallowInitialSpawn(true);
            break;
        case SUPPLY_BOX:
        {
            local scope = entity.GetOrCreatePrivateScriptScope();
            scope.was_modified <- false;
            scope.InputAddItem <- SetModified.bindenv(scope);
            scope.InputRemoveAllItems <- SetModified.bindenv(scope);
            scope.InterceptCrate <- InterceptCrate.bindenv(scope);
            break;
        }
    }
}

function HandleEntityDeleted(entity) 
{
    switch (entity.GetClassname())
    {
        case SPAWNER:
        {
            local id = entity.GetScriptId();
            if (id in LootManager.random_spawners)
                delete LootManager.random_spawners[id];
        }
        // Leak
        case SUPPLY_BOX:
        {
            local scope = entity.GetScriptScope();
            if (scope)
                getroottable().rawdelete(scope.__vname);
            break;
        }
    }
}

function HandleEntitySpawned(entity) 
{
    local class_name = entity.GetClassname();
    switch (class_name)
    {
        case SPAWNER:
            LootManager.InterceptSpawner(entity);
            return;
        case SUPPLY_BOX:
        {
            local scope = entity.GetScriptScope();
            scope.remove_empty <- HasFlag(FL_REMOVE_EMPTY_BOX, entity.GetSpawnFlags());
            entity.SetContextThink("InterceptCrate", InterceptCrate.bindenv(scope), 2.0);
            return;
        }
    }
    //if (!(class_name in LootManager.item_pools))
    //    return;
}

function HandleNPCKilled(params) 
{
    local killed_npc = EntIndexToHScript(params.entidx);
    if (!("HasArmor" in killed_npc) || !killed_npc.HasArmor())
        return;

    InterceptNGDrop(killed_npc);
}

StopListeningToAllGameEvents(CONTEXT);
::Hooks.Remove(CONTEXT);

::Entities.EnableEntityListening();
ListenToGameEvent("npc_killed", HandleNPCKilled.bindenv(this), CONTEXT);
::Hooks.Add( 0, "OnEntitySpawned", HandleEntitySpawned, CONTEXT);
::Hooks.Add( 0, "OnEntityCreated", HandleEntityCreated, CONTEXT);
::Hooks.Add( 0, "OnEntityDeleted", HandleEntityDeleted, CONTEXT);


local AddToPool = function(class_name, chance, pool)
{
    pool[class_name] <- chance;
    NormalizePool(pool);
}

// Interface

function RegisterPool(pool_name, add_to)
{
    if (pool_name in item_pools)
        return;

    item_pools[pool_name] <- {pool = {}}
    item_pools[pool_name].type <- (pool_name in add_to) ? POOL_TYPE.ITEM_CUSTOM : POOL_TYPE.POOL_CUSTOM;

    foreach(other_pool_name, chance in add_to)
    {
        if (!(other_pool_name in item_pools))
            continue;

        AddToPool(pool_name, chance, item_pools[other_pool_name].pool)
    }
}

function RegisterCustomItem(item_data)
{
    local class_name;

    switch (type(item_data.reference))
    {
        case "class":
            class_name = item_data.reference.getattributes(null).name;
            item_data.class_name <- class_name;
            break;
        case "function":
            class_name = item_data.reference.getinfos().name;
            item_data.class_name <- class_name;
            if (class_name)
                break;
        default:
            error(class_name + " can't be registered!")
            return;
    }

    if (class_name in custom_items)
    {
        error(class_name + " is already registered!")
        return;
    }
    custom_items[class_name] <- item_data;
    local loot_table = {};
    loot_table[item_data.class_name] <- 100.0;
    RegisterPool(item_data.class_name, loot_table);

    if (!("loot_table" in item_data))
        return;
    foreach (pool_name, chance in item_data.loot_table)
    {
        if (!(pool_name in item_pools))
            continue;

        if (item_pools[pool_name].type == POOL_TYPE.POOL_NO_CUSTOM)
        {
            error(item_data.class_name +" can't be part of "+pool_name+". Skipping.");
            continue;
        }
        AddToPool(item_data.class_name, chance, item_pools[pool_name].pool);
    }
}

function PrintItemPools()
{
    __DumpScope(0, LootManager.item_pools);
}

function PrintVersion()
{
    printl(CONTEXT +" "+ VERSION);
}

function GetCustomItemData(class_name)
{
    if (!(class_name in custom_items))
        return null;
    return custom_items[class_name];
}

IncludeScript(CONTEXT+"/custom_item_base", this);

printcl(255,255,0,"Done loading library: "+CONTEXT +" "+ VERSION);