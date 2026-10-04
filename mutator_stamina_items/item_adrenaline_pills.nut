//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   Defines a stamina booster item.
//  Usage   :   
//  Notes   :   
//-----------------------------------------------------------------------------

printcl(50,145,168,"Including "+getstackinfos(1).src+".");
local EVENT_WEAPON_MELEE_HIT = 3001;
local CONTEXT = "refreshstamina";
local STAMINA_GIVER_ENT = "info_teleport_destination";

CONVARS.PILLS_WEIGHT 	<- 		{VAR = "sv_adrenaline_pills_weight" 	, DESCR = "Inventory weight of the adrenaline pills item"	,   DEFAULT = 30.0  , MIN = 5.0,    MAX = 1000.0};
CONVARS.PILLS_OVERDOSE	<- 		{VAR = "sv_adrenaline_pills_overdose" 	, DESCR = "Allow/Disallow multi-usage of adrenaline pills"	,   DEFAULT = 1.0   , MIN = 0.0,    MAX = 1.0};
CONVARS.PILLS_DAMAGE	<- 		{VAR = "sv_adrenaline_pills_damage" 	, DESCR = "Overdose damage"									,   DEFAULT = 1.0   , MIN = 1.0,    MAX = 100.0};
CONVARS.PILLS_DURATION	<- 		{VAR = "sv_adrenaline_pills_duration" 	, DESCR = "Time in seconds the adrenaline pill boost lasts"	,   DEFAULT = 120.0 , MIN = 5.0,    MAX = 640.0};

local __RefreshStamina = function(stamina_giver) 
{ 
	if (!player || !player.IsValid() || !player.IsAlive() || Time() > boost_end)
	{
		EntFireByHandle(stamina_giver, "Kill", "", 0.0, null, null);
		DestroyDamageInfo(damage_info);
		getroottable().rawdelete(this.__vname);
		return null;
	}
	player.SetStamina(125.0); 
	if ((hurt_chance > 0) && (RandomInt(0, 8) < hurt_chance))
	{
		player.TakeDamage(damage_info);
		__SI.FadeScreen(GetPlayerByIndex(1), 1.0, Vector(255,255,255), 3.0, false);
	}

	return 1.0;
}

class item_adrenaline_pills extends LootManager.CCustomItem</ name="item_adrenaline_pills" /> 
{
	function constructor(pos, angles)
	{
		weight = __SI.CONVARS.PILLS_WEIGHT.VAL;
		allow_multiuse = __SI.CONVARS.PILLS_OVERDOSE.VAL > 0.0;
		boost_duration = __SI.CONVARS.PILLS_DURATION.VAL;
		damage = __SI.CONVARS.PILLS_DAMAGE.VAL;
		base.constructor(pos, angles, getclass().getattributes(null).name);
	}

	function OnItemUse()
    {
    	if (!base.OnItemUse())
    		return;

		local stamina_giver = GetStaminaGiver();
    	if (stamina_giver && stamina_giver.GetScriptScope())
    	{
    		stamina_giver.GetScriptScope().boost_end += boost_duration;
    		stamina_giver.GetScriptScope().hurt_chance++;
    		return;
    	}

    	stamina_giver = SpawnEntityFromTable(STAMINA_GIVER_ENT, { targetname = CONTEXT, origin = player.GetOrigin()});
    	stamina_giver.SetParent(player, "");
    	local scope = stamina_giver.GetOrCreatePrivateScriptScope();
    	scope.boost_end <- Time() + boost_duration;
    	scope.player <- player;
    	scope.hurt_chance <- 0;
    	scope.damage_info <- CreateDamageInfo(player, player, Vector(0,0,0), Vector(0,0,0), damage*10, DMG_POISON);
    	stamina_giver.SetContextThink(CONTEXT, __RefreshStamina.bindenv(scope), 0.0);
    }

    function GetStaminaGiver()
    {
    	local stamina_giver = player.FirstMoveChild();
    	while (stamina_giver)
    	{
    		if (stamina_giver.GetName() == CONTEXT)
    			break;

    		stamina_giver = stamina_giver.NextMovePeer();
    	}
    	return stamina_giver;
    }

    function ConditionStartUsing()
    {
    	if (!base.ConditionStartUsing())
    		return false;

    	return allow_multiuse || (!allow_multiuse && GetStaminaGiver() == null);
    }

    function ConditionApplyEffect(event)
    {
    	if (!base.ConditionApplyEffect(event))
    		return false;
    	
    	return (event.GetEvent() == EVENT_WEAPON_MELEE_HIT && event.GetCycle() > 0.7)
    }

    boost_duration = null;
    allow_multiuse = null;
    weight = null;
    damage = null;
}

LootManager.RegisterCustomItem
({
	reference		= item_adrenaline_pills
	base_class_name	= "item_pills"
	world_model 	= "models/items/adrenaline/w_item_adrenaline_pills.mdl"
	view_model 		= "models/items/adrenaline/v_item_adrenaline_pills.mdl"
	label 			= "RX Adrenaline Pills"
	icon 			= "vgui/item_icons/item_adrenaline_pills"
	use_button		= IN.ATTACK
	loot_table		= 
	{ 
		boosters = 100.0
	}
});

