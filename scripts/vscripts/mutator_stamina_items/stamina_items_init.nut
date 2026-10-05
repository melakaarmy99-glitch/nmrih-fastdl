//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   This is run by the mutator. Requires custom loot library to work
//  Usage   :   
//  Notes   :   Defines an item pool "boosters" that contain the syringe and pills
//              
//-----------------------------------------------------------------------------

printcl(50,145,168,"Running "+getstackinfos(1).src+".");
IncludeScript("custom_loot/custom_loot", this);

local CONTEXT = "MUTATOR_STAMINA_ITEMS";
if ("__SI" in this)
    return;
this = (__SI <- {});

CONVARS <- {};
LootManager.RegisterPool("boosters", 
{
    rest = 5
    ng_drop_rest = 2
    item_walkietalkie = 100
})

IncludeScript(CONTEXT+"/util_screen_fade", this);
IncludeScript(CONTEXT+"/item_adrenaline_pills", this);
IncludeScript(CONTEXT+"/item_adrenaline_syringe", this);

// Debug Console Commands
if (Convars.GetInt("developer") > 0)
{
    function HandleCmdSyringe(u)
    {
        local player = GetPlayerByIndex(1);
        local item = __SI.item_adrenaline_syringe(player.GetOrigin(), Vector());
        item.inventory_item.AcceptInput("Use", "", player, null);
    }

    function HandleCmdPills(u)
    {
        local player = GetPlayerByIndex(1);
        local item = __SI.item_adrenaline_pills(player.GetOrigin(), Vector());
        item.inventory_item.AcceptInput("Use", "", player, null);
    }

    CONCOMMANDS <-
    {
        SYRINGE =    {CMD = "give_syringe"  , FUNC = HandleCmdSyringe    , DESCR = "Debug give Syringe"},
        PILLS   =    {CMD = "give_pills"    , FUNC = HandleCmdPills      , DESCR = "Debug give Pills"},
    };

    foreach(concmd in CONCOMMANDS)
        Convars.RegisterCommand(concmd.CMD, concmd.FUNC, concmd.DESCR, FCVAR_GAMEDLL)
}

// Console Vars
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

printcl(255,255,0,"Done loading Mutator: "+CONTEXT);