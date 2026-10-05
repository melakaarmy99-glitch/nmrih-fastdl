
local CONTEXT = "SHOVE_SOUND"

function ZombieShoved( params )
{
	local player = EntIndexToHScript( params.player_id )
	if ( !player )
		return

	local zombie = EntIndexToHScript( params.zombie_id )
	if ( !zombie )
		return

	local weapon = player.GetActiveWeapon()
	if ( !weapon )
		return

	// Zippo and grenades do damage
	local noShoveDamage = [ "me_fists", "item_bandages", "item_first_aid", "item_gene_therapy", "item_maglite", "item_pills" ]
	foreach ( className in noShoveDamage )
	{
		if ( weapon.GetClassname() == className )
			return
	}

	local soundIndex = RandomInt( 7, 12 )
	//printl( "soundIndex: " + soundIndex )

	local sound = SpawnEntityFromTable( "ambient_generic",
	{
		origin = zombie.GetOrigin(),
		spawnflags = 0,
		volstart = 1000,
		health = 1000,
		radius = 50000,
		message = "mutator_shove_sound/rifle_swing_hit_infected" + soundIndex + ".wav"
	} )

	sound.Activate()
	EntFireByHandle( sound, "Kill", "", 2.0, null, null )
}

ListenToGameEvent( "zombie_shoved", ZombieShoved, CONTEXT )

printcl( 255, 255, 0, "Done loading Mutator: " + CONTEXT )
