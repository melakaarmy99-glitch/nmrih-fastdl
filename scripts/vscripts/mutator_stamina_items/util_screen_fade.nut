printcl(50,145,168,"Including "+getstackinfos(1).src+".");

local __EndFadeScreen = function(screen_fade)
{
	getroottable().rawdelete(this.__vname);
	screen_fade.Destroy();
}

local __FadeInScreen = function(screen_fade)
{
	screen_fade.ClearSpawnFlags();
	screen_fade.__KeyValueFromFloat("renderamt", 0.0); 
	screen_fade.AcceptInput("fade", "", player, null);
	screen_fade.SetContextThink(UniqueString(""), __EndFadeScreen.bindenv(this), duration);
}

function FadeScreen(player, duration, color, alpha, modulate = false)
{
	local screen_fade = SpawnEntityFromTable("env_fade", 
    { 
        renderamt = alpha,
        spawnflags = 12 + (modulate ? 2 : 0)
    });
    local scope = screen_fade.GetOrCreatePrivateScriptScope();
    scope.player <- player;
    scope.duration <- duration;
	screen_fade.SetParent(player, "");
	screen_fade.__KeyValueFromVector("rendercolor",color);
	screen_fade.__KeyValueFromFloat("duration", duration);
	screen_fade.AcceptInput("fade", "", player, null);

	//EntFireByHandle(screen_fade,"fade","",0,player,null);
	screen_fade.SetContextThink(UniqueString(""), __FadeInScreen.bindenv(scope), duration + 0.5);
}

