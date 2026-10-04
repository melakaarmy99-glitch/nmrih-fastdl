//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   Defines a stamina booster item.
//  Usage   :   
//  Notes   :   
//-----------------------------------------------------------------------------

printcl(50,145,168,"Including "+getstackinfos(1).src+".");
local EVENT_WEAPON_MELEE_HIT = 3001;
local SOUND_USE = "NMRPlayer.SkillshotStart";
local BOOST_GIVER_ENT = "info_teleport_destination";
local CONTEXT = "giveboost";

CONVARS.SYRINGE_WEIGHT		<- 		{VAR = "sv_adrenaline_syringe_weight" 	, DESCR = "Inventory weight of the adrenaline syringe item"	,   DEFAULT = 25.0  , MIN = 5.0,    MAX = 1000.0};
CONVARS.SYRINGE_OVERDOSE	<- 		{VAR = "sv_adrenaline_syringe_overdose" , DESCR = "Allow/Disallow multi-usage of adrenaline syringe",   DEFAULT = 1.0   , MIN = 0.0,    MAX = 1.0};
CONVARS.SYRINGE_DAMAGE		<- 		{VAR = "sv_adrenaline_syringe_damage" 	, DESCR = "Syringe overdose damage"							,   DEFAULT = 5.0   , MIN = 1.0,    MAX = 100.0};
CONVARS.SYRINGE_DURATION	<- 		{VAR = "sv_adrenaline_syringe_duration" , DESCR = "Time in seconds the syringe boost lasts"			,   DEFAULT = 35.0 	, MIN = 5.0,    MAX = 640.0};
CONVARS.SYRINGE_BOOST		<- 		{VAR = "sv_adrenaline_syringe_boost" 	, DESCR = "Movement speed boost percentage"					,   DEFAULT = 0.05 	, MIN = 0.05,   MAX = 2.0};

local __UpdateBoost = function(boost_giver) 
{ 
	if (!player || !player.IsValid() || !player.IsAlive() || Time() > boost_end)
	{
		try { player.SetSpeedModifier(1.0) } catch (error) { }
		EntFireByHandle(boost_giver, "Kill", "", 0.0, null, null);
		DestroyDamageInfo(damage_info);
		getroottable().rawdelete(this.__vname);
		return null;
	}

	local boost_diff = boost_amount - old_boost_amount;
	if (boost_diff > 0)
		old_boost_amount = boost_amount;

	if (player.IsSprinting())
	{
		if (!was_sprinting)
		{
			was_sprinting = true;
			player.SetSpeedModifier( player.GetSpeedModifier() + boost_amount);
		}
	}
	else if (was_sprinting)
	{
		was_sprinting = false;
		player.SetSpeedModifier( player.GetSpeedModifier() - boost_amount + boost_diff);
	}
	
	if ((hurt_chance > 0) && Time() > next_hurt_time)
	{
		next_hurt_time = Time() + 1.0;
		if (RandomInt(0, 6) < hurt_chance)
		{
			player.TakeDamage(damage_info);
			__SI.FadeScreen(GetPlayerByIndex(1), 1.0, Vector(255,255,255), 3.0);
		}
	}
	return 0.0;
}

class item_adrenaline_syringe extends LootManager.CCustomItem</ name="item_adrenaline_syringe" /> 
{
	function constructor(pos, angles)
	{
		weight = 			__SI.CONVARS.SYRINGE_WEIGHT.VAL;
		boost_duration = 	__SI.CONVARS.SYRINGE_DURATION.VAL;
		allow_multiuse = 	__SI.CONVARS.SYRINGE_OVERDOSE.VAL > 0.0;
		damage = 			__SI.CONVARS.SYRINGE_DAMAGE.VAL;
    	boost_amount = 		__SI.CONVARS.SYRINGE_BOOST.VAL;

		base.constructor(pos, angles, getclass().getattributes(null).name);
	}

	function OnItemUse()
    {
    	if (!base.OnItemUse())
    		return;

    	local boost_giver = GetBoostGiver();
    	if (boost_giver && boost_giver.GetScriptScope())
    	{
    		local scope = boost_giver.GetScriptScope();
    		scope.boost_end += boost_duration;
    		scope.old_boost_amount = scope.boost_amount;
    		scope.boost_amount += boost_amount;
    		scope.hurt_chance++;
    		return;
    	}

    	boost_giver = SpawnEntityFromTable(BOOST_GIVER_ENT, { targetname = CONTEXT, origin = player.GetOrigin()});
    	boost_giver.SetParent(player, "");
    	local scope = boost_giver.GetOrCreatePrivateScriptScope();
    	scope.boost_end <- Time() + boost_duration;
    	scope.player <- player;
    	scope.hurt_chance <- 0;
    	scope.next_hurt_time <- Time() + 2.0;
    	scope.was_sprinting <- false;
    	scope.boost_amount <- boost_amount;
    	scope.old_boost_amount <- boost_amount;
    	scope.damage_info <- CreateDamageInfo(player, player, Vector(0,0,0), Vector(0,0,0), damage, DMG_POISON); 

    	player.SetStamina(130.0);
    	player.PrecacheSoundScript(SOUND_USE);
    	EmitSoundOnClient(SOUND_USE, player, GetPlayerByUserId(player.GetUserID()));
    	__SI.FadeScreen(player, 2.0, Vector(0.0,200.0,10.0), 10.0);
    	boost_giver.SetContextThink(CONTEXT, __UpdateBoost.bindenv(scope), 0.0);
    }

    function GetBoostGiver()
    {
    	local boost_giver = player.FirstMoveChild();
    	while (boost_giver)
    	{
    		if (boost_giver.GetName() == CONTEXT)
    			break;

    		boost_giver = boost_giver.NextMovePeer();
    	}
    	return boost_giver;
    }

    function ConditionStartUsing()
    {
    	if (!base.ConditionStartUsing())
    		return false;

    	return allow_multiuse || (!allow_multiuse && GetBoostGiver() == null);
    }

    function ConditionApplyEffect(event)
    {
    	if (!base.ConditionApplyEffect(event))
    		return false;

    	return (event.GetEvent() == EVENT_WEAPON_MELEE_HIT && event.GetCycle() > 0.6)
    }

    weight = null;
    damage = null;
    boost_duration = null;
    boost_amount = null;
    allow_multiuse = null;
}

LootManager.RegisterCustomItem
({
	reference		= item_adrenaline_syringe
	base_class_name	= "item_gene_therapy"
	world_model 	= "models/items/adrenaline/w_item_adrenaline_syringe.mdl"
	view_model 		= "models/items/adrenaline/v_item_adrenaline_syringe.mdl"
	label 			= "Adrenaline Shot"
	icon 			= "vgui/item_icons/item_adrenaline_syringe"
	use_button		= IN.ATTACK
	loot_table		= 
	{ 
		boosters = 100.0
	}
})