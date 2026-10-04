//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   Example script that replaces walkie talkies with medkits, that only spawn 50% of the time
//  Usage   :   
//  Notes   :   walkie talkie entities placed manually by the map will still spawn
//-----------------------------------------------------------------------------

IncludeScript("custom_loot/custom_loot", null);

LootManager.item_pools.item_walkietalkie.pool = 
{
	nothing = 50,
	item_first_aid = 50
}