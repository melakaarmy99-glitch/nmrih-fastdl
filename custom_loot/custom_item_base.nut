//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   Base class for usable custom items
//  Usage   :   Example usage see adrenaline pills / syringe
//  Notes   :   
//-----------------------------------------------------------------------------

printcl(50,145,168,"Including "+getstackinfos(1).src+".");
RegisterActivityConstants();
local ITEM_STORAGE = Vector(15000, 15000, 15000);

local ACT_VM_MEDICAL = getconsttable().ACT_VM_MEDICAL;
local ACT_VM_SHOVE = getconsttable().ACT_VM_SHOVE;
local NETPROP_VACCINATED = "_vaccinated";
local NETPROP_INFECTED = "m_flInfectionTime";

local ITEM_STATE = { UNEQUIPPED=0, INVENTORY=1, START_ACTIVE=2, ACTIVE=3, USING=4, DONE=5 }

local function HasFlag(i,f) {return !!(i&f)}

local all_custom_items = [];

class CCustomItem
{
    constructor(pos, angles, _classname)
    {
    	local item_data = ::LootManager.GetCustomItemData(_classname);

    	item_state = ITEM_STATE.UNEQUIPPED;
    	item_base = item_data.base_class_name;
    	item_class = _classname;
    	use_button = item_data.use_button;
    	inventory_item = SpawnEntityFromTable("item_custom", 
		{ 
			origin = pos,
		    model = item_data.world_model,
		    label = item_data.label,
		    icon = item_data.icon,
		    weight = weight,
		});
		viewmodel_item = SpawnEntityFromTable(item_base, { origin = ITEM_STORAGE });
		PrecacheModel(item_data.view_model, false);
		viewmodel_item.SetModel(item_data.view_model);
		viewmodel_item.SetViewModelOverride(item_data.view_model);
		viewmodel_item.SetWorldModelOverride(item_data.world_model);
		viewmodel_item.SetIconOverride(inventory_item.GetIcon());
		viewmodel_item.SetWeightOverride(inventory_item.GetWeight());
		viewmodel_item.SetLabelOverride(inventory_item.GetLabel());
		MoveOffMap(viewmodel_item);

		local scope = viewmodel_item.GetOrCreatePrivateScriptScope();
		scope.instance <- this.weakref(); 
		scope.HandleAnimEvent <- HandleAnimEvent.bindenv(this);
		scope.InputUse <- function() {return caller == EntIndexToHScript(0)};

		scope = inventory_item.GetOrCreatePrivateScriptScope();
		scope.instance <- this; // The only reference. This instance will be garbage collected when script scope is deleted
		scope.OnItemApply <- OnItemActive.bindenv(this);
		scope.OnItemPickup <- OnItemPickup.bindenv(this);
		scope.OnItemDrop <- OnItemDrop;
		scope.UpdateOnRemove <- Destroy.bindenv(this);
		all_custom_items.append(this.weakref());
    }
    function IsUsingActivity() {return viewmodel_item.GetSequenceActivity(viewmodel_item.GetSequence()) == ACT_VM_MEDICAL}
    function IsItemValid() { return viewmodel_item && viewmodel_item.IsValid()}
	function IsItemEquipped() { return viewmodel_item.GetOwner() != null}
    function IsItemActive() { return player.GetActiveWeapon() == viewmodel_item}
	function CheckItem()
	{
		if (!IsItemValid())
		{
			Destroy();
			return null;
		}
		if (!IsItemEquipped())
		{
			OnItemDrop.call(viewmodel_item.GetScriptScope());
			return 0.0
		}
		if (!IsItemActive())
		{
			OnItemInactive();
			return 0.0
		}
		return true;
	}

    function ItemThink(inventory_item)
    {
    	switch (item_state)
    	{
    		case ITEM_STATE.UNEQUIPPED:
    			return null;
			case ITEM_STATE.INVENTORY:
				return null;
			case ITEM_STATE.START_ACTIVE:
				item_state = ITEM_STATE.ACTIVE;
				// leak
			case ITEM_STATE.ACTIVE:
			{
				local is_active = CheckItem()
				if (!is_active)
					return is_active;

				if (ConditionStartUsing())
					StartUsing();
					// leak
				else
					break;
			}
			case ITEM_STATE.USING:
				local is_active = CheckItem()
				if (!is_active)
					return is_active;

				if (!IsUsingActivity())
				{
					item_state = ITEM_STATE.ACTIVE;
				}
				break;
			case ITEM_STATE.DONE:
				local is_active = CheckItem()
				if (!is_active)
					return is_active;

				if (IsActivityFinished())
				{
					Destroy();
					return null;
				}
    	}
    	return 0.0;
    }

    function DestroyItem(item)
    {
    	if (!item || !item.IsValid())
    		return;
    	local scope = item.GetScriptScope();
        if (scope)
            getroottable().rawdelete(scope.__vname);

        if (item.GetOwner())
        	HideItem(item);

    	item.Destroy();
    }

    function Destroy()
    {
		DestroyItem(inventory_item);
		DestroyItem(viewmodel_item);

		local pos = all_custom_items.find(this);
		if (pos != null)
			all_custom_items.remove(pos);

		if (blocking_item && blocking_item.IsValid() && fake_blocking_item && fake_blocking_item.IsValid())
			BlockerToReal();
    }

    function ConditionStartUsing()
    {
    	return IsPressingUseBotton();
    }

    function ConditionApplyEffect(event)
    {
    	return item_state == ITEM_STATE.USING;
    }

    function HandleAnimEvent()
    {
    	if (event.GetEvent() == ACT_VM_SHOVE)
    		return true;

    	if (ConditionApplyEffect(event))
    		OnItemUse();
    	return false;
    }

    function IsActivityFinished()
    {
    	return viewmodel_item.GetSequenceActivity(viewmodel_item.GetSequence()) != ACT_VM_MEDICAL;
    }

    function IsPressingUseBotton()
    {
    	local buttons = player.GetButtonPressed();
    	return HasFlag(buttons, use_button);
    }

    function StopForceButton(player)
    {
    	player.UnforceButtons(use_button);
    	foreach(prop, value in restore_state)
    	{
    		if (type(value) == "integer")
    			NetProps.SetPropInt(player, prop, value);
    		else
    			NetProps.SetPropFloat(player, prop, value);
    	}
    }

    function StartUsing()
    {
    	restore_state = {};
    	if (player.IsVaccinated())
    	{
    		restore_state._vaccinated <- NetProps.GetPropInt(player, NETPROP_VACCINATED);
    		NetProps.SetPropInt(player, NETPROP_VACCINATED, -1);
    	}

    	if (!player.IsInfected())
    	{
    		restore_state.m_flInfectionTime <- NetProps.GetPropFloat(player, NETPROP_INFECTED);
    		NetProps.SetPropFloat(player, NETPROP_INFECTED, 0.0);
    	}
    	player.ForceButtons(use_button);
    	viewmodel_item.SendWeaponAnim(ACT_VM_MEDICAL);
    	player.SetContextThink(StopForceButton.getinfos().name, StopForceButton.bindenv(this), 0.1);
    	item_state = ITEM_STATE.USING;
    }
    /*
    function ForceActivity()
    {
    	return false;
    	local activity = viewmodel_item.GetSequenceActivity(viewmodel_item.GetSequence());
    	if (activity == ACT_VM_IDLE || activity == ACT_VM_WALK)
    	{
    		return true;
    		printl("ForceAnim");
    		player.DisableButtons(IN.SPEED);
    		player.EnableSprint(false);
    		viewmodel_item.ResetSequenceInfo();
    		viewmodel_item.SetCycle(0);
    		viewmodel_item.SendWeaponAnim(ACT_VM_MEDICAL);
    		
    	}
    	return false;
    }
	*/
    function OnItemUse()
    {
    	if (!CheckItem())
    		return false;

    	item_state = ITEM_STATE.DONE;
    	return true;
    }

    function OnItemPickup()
    {
    	if (item_state != ITEM_STATE.UNEQUIPPED)
    		return;

    	foreach (custom_item in all_custom_items)
    		if (custom_item.player == inventory_item.GetOwner() && !custom_item.CanEquipAnother(item_class))
    		{
    			inventory_item.DropItem();
    			return;
    		}

    	item_state = ITEM_STATE.INVENTORY;
    	player = inventory_item.GetOwner();
    }

    function OnItemDrop()
    {
    	local self = self;
    	this = instance;

    	if (self == inventory_item && item_state != ITEM_STATE.INVENTORY)
    		return;

    	if (item_state == ITEM_STATE.DONE)
    	{
    		Destroy();
    		return;
    	}

    	if (self == viewmodel_item)
    	{
    		local origin = viewmodel_item.GetOrigin();
    		local velocity = GetPhysVelocity(viewmodel_item.GetPhysicsObject());
    		// todo: why not HideItem() ????
    		MoveOffMap(viewmodel_item);

    		inventory_item.SetOrigin(origin);
    		inventory_item.GetPhysicsObject().EnableMotion(true);
    		inventory_item.GetPhysicsObject().ApplyForceCenter(velocity*5.0);
    	}

		item_state = ITEM_STATE.UNEQUIPPED;
    	last_player = player;
    	player = null;
    	inventory_item.StopThinkFunction();
    }

    function OnItemInactive(new_active_item = null)
    {
    	if (item_state == ITEM_STATE.DONE)
    	{
    		Destroy();
    		return;
    	}
    	if (item_state < ITEM_STATE.START_ACTIVE)
    		return;

    	HideItem(viewmodel_item);
    	EquipItem(inventory_item, false);

    	if (blocking_item && blocking_item.IsValid())
    		BlockerToReal(new_active_item == blocking_item);
    	item_state = ITEM_STATE.INVENTORY;
    }

    function OnItemActive()
    {
    	local check_blocking_item = player.FindWeapon(item_base, 0);
		if (check_blocking_item)
			BlockerToFake(check_blocking_item);

    	item_state = ITEM_STATE.START_ACTIVE;
		HideItem(inventory_item);
		EquipItem(viewmodel_item);

    	inventory_item.SetContextThink(ItemThink.getinfos().name, ItemThink.bindenv(this), 0.0);
    	/*
    	local player = inventory_item.GetOwner();
		blocking_item = player.FindWeapon("item_pills", 0);
		if (blocking_item)
			BlockerToFake(player, blocking_item);

		viewmodel_item.SetOrigin(player.EyePosition());
		viewmodel_item.AcceptInput("Use", "", player, player);
		player.EquipWeapon(viewmodel_item);
		HideItem(player, inventory_item);
		viewmodel_item.SetContextThink(UseWeaponThink.getinfos().name, UseWeaponThink.bindenv(this), 0.1);
		*/
    } 

    function BlockerToFake(item)
    {
    	blocking_item = item;
    	HideItem(blocking_item);
    	local language = Convars.GetClientConvarValue(player.entindex(), "cl_language");
    	if (!language && language.len() <= 2)
    		language = "english";

		fake_blocking_item = SpawnEntityFromTable("item_custom", 
		{ 
			origin = player.GetOrigin(),
		    model = blocking_item.GetWorldModel(),
		    label = ::LootManager.labels[blocking_item.GetClassname()][language],
		    icon = "vgui/item_icons/"+blocking_item.GetClassname(),
		    weight = blocking_item.GetWeight(),
		});
		fake_blocking_item.AcceptInput("Use", "", player, EntIndexToHScript(0));
		local scope = fake_blocking_item.GetOrCreatePrivateScriptScope();
		scope.instance <- this.weakref();
		scope.ignore_events <- false;
		scope.InputUse <- function() {return caller == EntIndexToHScript(0)};
		scope.OnItemApply <- OnBlockerFakeItemActive;
		scope.OnItemDrop <- OnBlockerFakeItemDrop;
    }

    function BlockerToReal(do_equip = false)
    {
    	//printl(format("%s -> %s",getstackinfos(2).func, getstackinfos(1).func));
    	fake_blocking_item.GetScriptScope().ignore_events = true;
    	HideItem(fake_blocking_item);
    	EquipItem(blocking_item, do_equip);
    	DestroyItem(fake_blocking_item);
    	fake_blocking_item = null;
    	blocking_item = null;
    }

    function OnBlockerFakeItemActive()
    {
    	local self = self;
    	this = instance;
    	OnItemInactive(blocking_item);
    }

    function OnBlockerFakeItemDrop()
    {
    	local self = self;
    	this = instance;

    	if (fake_blocking_item.GetScriptScope().ignore_events)
    	{
    		fake_blocking_item.GetScriptScope().ignore_events = false;
    		return;
    	}

	    local origin = fake_blocking_item.GetOrigin();
		local velocity = GetPhysVelocity(fake_blocking_item.GetPhysicsObject());

		DestroyItem(fake_blocking_item);
		fake_blocking_item = null;
		blocking_item.SetOrigin(origin);
		blocking_item.GetPhysicsObject().EnableMotion(true);
		blocking_item.GetPhysicsObject().ApplyForceCenter(velocity*5.0);
    }

    function EquipItem(item, do_equip = true)
    {
    	item.GetPhysicsObject().EnableMotion(true);
    	item.SetOrigin(player.EyePosition());
		item.AcceptInput("Use", "", player, EntIndexToHScript(0));

		if (do_equip)
			player.EquipWeapon(item);
    }

    function HideItem(item)
    {
    	local ply = player ? player : last_player;

    	if (item.GetClassname() == "item_custom")
    		item.DropItem();
    	else if (ply)
    		ply.DropWeapon(item);

    	MoveOffMap(item);
    }

    function MoveOffMap(item)
    {
    	item.SetOrigin(ITEM_STORAGE);
		item.GetPhysicsObject().EnableMotion(false);
    }

    function CanEquipAnother(class_name)
    {
    	return (item_class != class_name);
    }

    use_button = null;
    item_class = null;
    restore_state = null;
    item_base = null;
    player = null;
    last_player = null;

    item_state = null;
    inventory_item = null;
    viewmodel_item = null;

    fake_blocking_item = null;
    blocking_item = null;
}