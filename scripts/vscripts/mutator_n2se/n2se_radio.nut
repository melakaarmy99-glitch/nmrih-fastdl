if (!("__sv_n2se_radio_enabled_registered" in getroottable())) {
    try {
        Convars.RegisterConvar("sv_n2se_radio_enabled", "1",
            "Enable/disable Radio item", 0);
    } catch (ex) {}
    getroottable().__sv_n2se_radio_enabled_registered <- true;
}

if (!("LootManager" in getroottable())) {
    try { IncludeScript("custom_loot/custom_loot", getroottable()); } catch(ex) {}
}
if (!("CCustomItem" in getroottable())) {
    try { IncludeScript("custom_loot/custom_item_base", getroottable()); } catch(ex) {}
}

if (!("RadioTrace" in getroottable())) {
    ::RadioTrace <- function(start, end, mask, ignore) {
        local t = { pos = null, fraction = 1.0, enthit = null, didHit = false };
        local trace = null;
        try { trace = TraceLineComplex(start, end, ignore, mask, 0); }
        catch(e1) {
            try { trace = TraceLineComplex(start, end, ignore, mask); }
            catch(e2) { trace = null; }
        }
        if (trace == null) {
            local tt = { start = start, end = end, mask = mask, ignore = ignore };
            try { TraceLine(tt); trace = tt; } catch(e3) { return t; }
        }
        try { t.didHit = trace.DidHit(); } catch(e) {
            try { t.didHit = trace.didhit; } catch(e2) {}
        }
        try { local v = trace.EndPos(); if (v != null) t.pos = v; } catch(e) {}
        if (t.pos == null) { try { local v = trace.endpos; if (v != null) t.pos = v; } catch(e) {} }
        if (t.pos == null) { try { local v = trace.pos;    if (v != null) t.pos = v; } catch(e) {} }
        try { local v = trace.Fraction(); if (v != null) t.fraction = v; } catch(e) {}
        if (t.fraction == 1.0) { try { local v = trace.fraction; if (v != null) t.fraction = v; } catch(e) {} }
        try { local v = trace.Entity(); if (v != null) t.enthit = v; } catch(e) {}
        if (t.enthit == null) { try { local v = trace.enthit; if (v != null) t.enthit = v; } catch(e) {} }
        if (t.enthit == null) { try { local v = trace.hit;    if (v != null) t.enthit = v; } catch(e) {} }
        return t;
    };
}

if (!("RadioSystem" in getroottable()))
    ::RadioSystem <- {};

RadioSystem.Radius       <- 1024.0;
RadioSystem.Volume       <- 10;
RadioSystem.Loop         <- 0;
RadioSystem.Duration     <- 60.0;
RadioSystem.PeaceRadius  <- 512.0;
RadioSystem.ScanInterval <- 1.0;
RadioSystem.PropModel    <- "models/items/w_radio.mdl";
RadioSystem.PropLinger   <- 10.0;
RadioSystem.PropZOffset  <- 4.0;

RadioSystem.SoundList <- [
    "fm_music/radio1.wav",
    "fm_music/radio2.wav",
    "fm_music/radio3.wav"
];

RadioSystem.State <- {
    counter = 0,
    playing = {}
};

RadioSystem.Log <- function(m) { printl("[Radio] " + m); };

RadioSystem.GetDefaultOrigin <- function() {
    local p = null;
    while ((p = Entities.FindByClassname(p, "player")) != null) {
        if (p.GetHealth() > 0)
            return p.GetOrigin() + Vector(0, 0, 40);
    }
    return Vector(0, 0, 0);
};

RadioSystem.GetGroundPos <- function(origin) {
    local trace = RadioTrace(
        origin + Vector(0, 0, 64),
        origin + Vector(0, 0, -2048),
        33570827, null);
    if (trace.pos != null) return trace.pos;
    return origin;
};

RadioSystem.ApplyRelation <- function(npc, disp) {
    local p = null;
    while ((p = Entities.FindByClassname(p, "player")) != null) {
        try { npc.SetRelationship(p, disp, 1); } catch(ex) {}
    }
};

RadioSystem.ClearEnemy <- function(npc) {
    try { if ("ClearEnemyMemory" in npc) { npc.ClearEnemyMemory(); return; } } catch(ex) {}
    try { if ("SetEnemy" in npc) { npc.SetEnemy(null); return; } } catch(ex) {}
    try { if ("ClearEnemy" in npc) npc.ClearEnemy(); } catch(ex) {}
};

RadioSystem.ForceHostileToPlayers <- function(npc) {
    if (npc == null || !npc.IsValid()) return;

    RadioSystem.ApplyRelation(npc, 1);

    local best = null;
    local bestDist = 999999.0;
    local p = null;
    while ((p = Entities.FindByClassname(p, "player")) != null) {
        if (p.GetHealth() <= 0) continue;
        local d = (p.GetOrigin() - npc.GetOrigin()).Length();
        if (d < bestDist) { bestDist = d; best = p; }
    }

    if (best != null) {
        try {
            if ("SetEnemy" in npc) npc.SetEnemy(best);
            else if ("SetEnemyEnt" in npc) npc.SetEnemyEnt(best);
        } catch(e) {}

        try {
            if ("SetLastKnownLocation" in npc)
                npc.SetLastKnownLocation(best.GetOrigin());
        } catch(e) {}
    }
};

RadioSystem.ForceTargetToBullseye <- function(npc, mkName) {
    if (npc == null || !npc.IsValid()) return false;

    local target = null;
    try { target = Entities.FindByName(null, mkName); } catch(e) {}
    if (target == null || !target.IsValid()) return false;

    RadioSystem.ApplyRelation(npc, 3);

    try {
        if ("SetEnemy" in npc) npc.SetEnemy(target);
        else if ("SetEnemyEnt" in npc) npc.SetEnemyEnt(target);
    } catch(e) { return false; }

    try {
        if ("SetLastKnownLocation" in npc)
            npc.SetLastKnownLocation(target.GetOrigin());
    } catch(e) {}

    return true;
};

RadioSystem.FindNearbyActiveGen <- function(pos, excludeGen) {
    local best = null;
    local bestDist = 999999.0;
    foreach (g, r in RadioSystem.State.playing) {
        if (g == excludeGen) continue;
        local d = (r.origin - pos).Length();
        if (d > RadioSystem.Radius) continue;
        if (d < bestDist) { bestDist = d; best = r; }
    }
    return best;
};

RadioSystem.ScanGen <- function(gen) {
    if (gen == 0) return;
    if (!(gen in RadioSystem.State.playing)) return;

    local rec = RadioSystem.State.playing[gen];
    local origin = rec.origin;
    local e = null;
    while ((e = Entities.FindByClassname(e, "npc_*")) != null) {
        local cn = e.GetClassname();
        if (cn.len() < 9 || cn.slice(0, 9) != "npc_nmrih") continue;
        if ((e.GetOrigin() - origin).Length() > RadioSystem.PeaceRadius) continue;

        local already = false;
        foreach (n in rec.affected)
            if (n == e) { already = true; break; }
        if (already) continue;

        RadioSystem.ApplyRelation(e, 3);
        RadioSystem.ClearEnemy(e);
        rec.affected.append(e);
    }

    EntFire("worldspawn", "RunScriptCode",
            "RadioSystem.ScanGen(" + gen + ")",
            RadioSystem.ScanInterval, null);
};

RadioSystem.EndGen <- function(gen) {
    if (!(gen in RadioSystem.State.playing)) return;
    local rec = RadioSystem.State.playing[gen];

    delete RadioSystem.State.playing[gen];

    foreach (npc in rec.affected) {
        if (npc == null || !npc.IsValid()) continue;

        local nearby = RadioSystem.FindNearbyActiveGen(npc.GetOrigin(), gen);
        if (nearby != null) {
            if (RadioSystem.ForceTargetToBullseye(npc, nearby.mk)) continue;
        }

        RadioSystem.ForceHostileToPlayers(npc);
    }

    if (rec.snd != "") {
        EntFire(rec.snd, "StopSound", "", 0, null);
        EntFire(rec.snd, "Kill", "", 0.05, null);
    }
    if (rec.mk != "") {
        EntFire(rec.mk, "Kill", "", 0.05, null);
    }
};

RadioSystem.Clear <- function() {
    local gens = RadioSystem.State.playing.keys();
    foreach (g in gens) {
        local rec = RadioSystem.State.playing[g];
        foreach (npc in rec.affected) {
            if (npc != null && npc.IsValid())
                RadioSystem.ForceHostileToPlayers(npc);
        }
        if (rec.snd != "") {
            EntFire(rec.snd, "StopSound", "", 0, null);
            EntFire(rec.snd, "Kill", "", 0.05, null);
        }
        if (rec.mk != "") {
            EntFire(rec.mk, "Kill", "", 0.05, null);
        }
        if (rec.prop != "") {
            EntFire(rec.prop, "Kill", "", 0, null);
        }
        delete RadioSystem.State.playing[g];
    }
};

RadioSystem.PlaySound <- function(sound, origin = null, propPos = null) {
    if (origin == null) origin = RadioSystem.GetDefaultOrigin();

    RadioSystem.State.counter = RadioSystem.State.counter + 1;
    local gen = RadioSystem.State.counter;

    local idx = gen.tostring();
    local sndName  = "radio_snd_"  + idx;
    local mkName   = "radio_mk_"   + idx;
    local propName = "radio_prop_" + idx;

    local ent = SpawnEntityFromTable("ambient_generic", {
        targetname = sndName,
        message    = sound,
        radius     = RadioSystem.Radius.tostring(),
        health     = RadioSystem.Volume.tostring(),
        spawnflags = RadioSystem.Loop,
        origin     = origin
    });
    if (ent == null) return null;

    local marker = SpawnEntityFromTable("npc_bullseye", {
        targetname = mkName,
        origin     = origin + Vector(0, 0, 70),
        spawnflags = 131072
    });
    if (marker != null) {
        try { marker.SetSolid(0); } catch(ex) {}
        try { marker.AcceptInput("Wake", "", null, null); } catch(ex) {}
    }

    local groundPos;
    if (propPos != null)
        groundPos = propPos;
    else
        groundPos = RadioSystem.GetGroundPos(origin) + Vector(0, 0, RadioSystem.PropZOffset);

    local prop = SpawnEntityFromTable("prop_dynamic", {
        targetname     = propName,
        model          = RadioSystem.PropModel,
        origin         = groundPos,
        angles         = "0 0 0",
        solid          = 0,
        disableshadows = 0
    });
    if (prop != null) {
        try { prop.SetSolid(0); } catch(ex) {}
    }

    RadioSystem.State.playing[gen] <- {
        snd      = sndName,
        mk       = mkName,
        prop     = propName,
        origin   = origin,
        affected = []
    };

    EntFire(sndName, "PlaySound", "", 0.1, null);

    EntFire("worldspawn", "RunScriptCode",
            "RadioSystem.EndGen(" + gen + ")",
            RadioSystem.Duration, null);

    if (prop != null)
        EntFire(propName, "Kill", "", RadioSystem.Duration + RadioSystem.PropLinger, null);

    RadioSystem.ScanGen(gen);
    return ent;
};

RadioSystem.PlayRandom <- function(origin = null, propPos = null) {
    local list = RadioSystem.SoundList;
    local s = list[RandomInt(0, list.len() - 1)];
    return RadioSystem.PlaySound(s, origin, propPos);
};

::Radio1_Play <- function(origin = null) { return RadioSystem.PlaySound(RadioSystem.SoundList[0], origin); };
::Radio2_Play <- function(origin = null) { return RadioSystem.PlaySound(RadioSystem.SoundList[1], origin); };
::Radio3_Play <- function(origin = null) { return RadioSystem.PlaySound(RadioSystem.SoundList[2], origin); };
::Radio_Stop  <- function() { RadioSystem.Clear(); };

if (!("RadioPreview" in getroottable()))
    ::RadioPreview <- {};

RadioPreview.active         <- false;
RadioPreview.ent            <- null;
RadioPreview.owner          <- null;
RadioPreview.lastShoveState <- false;

RadioPreview.ComputeGroundPos <- function(player) {
    if (player == null || !player.IsValid()) return null;

    local pOrigin = player.GetOrigin();

    local gTrace = RadioTrace(
        pOrigin + Vector(0, 0, 16),
        pOrigin + Vector(0, 0, -4096),
        33570827, player);

    local groundBase;
    if (gTrace.pos != null) groundBase = gTrace.pos;
    else groundBase = pOrigin;

    local yaw = player.GetAngles().y;
    local rad = yaw * 3.14159265 / 180.0;
    local forward = Vector(cos(rad), sin(rad), 0);
    local pos = groundBase + forward * 50.0;

    local oTrace = RadioTrace(
        pos + Vector(0, 0, 32),
        pos + Vector(0, 0, -128),
        33570827, player);

    if (oTrace.pos != null) pos = oTrace.pos;

    return pos;
};

RadioPreview.Start <- function(player) {
    if (player == null || !player.IsValid()) return;
    RadioPreview.Stop();

    local initialPos = RadioPreview.ComputeGroundPos(player);
    if (initialPos == null) initialPos = player.GetOrigin();

    local ent = SpawnEntityFromTable("prop_dynamic", {
        model          = "models/items/w_radio.mdl",
        origin         = initialPos + Vector(0, 0, RadioSystem.PropZOffset),
        solid          = 0,
        spawnflags     = 16,
        disableshadows = 1,
        rendermode     = 2,
        renderamt      = 120
    });
    if (ent == null) return;
    try { ent.SetSolid(0); } catch(e) {}
    try { ent.SetCollisionGroup(1); } catch(e) {}

    RadioPreview.ent    = ent;
    RadioPreview.owner  = player;
    RadioPreview.active = true;

    EntFire("worldspawn", "RunScriptCode", "RadioPreview.Tick()", 0.02, null);
};

RadioPreview.Stop <- function() {
    RadioPreview.active = false;
    if (RadioPreview.ent != null && RadioPreview.ent.IsValid())
        try { EntFireByHandle(RadioPreview.ent, "Kill", "", 0, null, null); } catch(e) {}
    RadioPreview.ent   = null;
    RadioPreview.owner = null;
};

RadioPreview.GetPos <- function() {
    if (RadioPreview.active && RadioPreview.ent != null && RadioPreview.ent.IsValid())
        return RadioPreview.ent.GetOrigin();
    return null;
};

RadioPreview.Tick <- function() {
    if (!RadioPreview.active) return;

    local ent = RadioPreview.ent;
    if (ent == null || !ent.IsValid()) { RadioPreview.active = false; return; }

    local player = RadioPreview.owner;
    if (player == null || !player.IsValid()) { RadioPreview.active = false; return; }

    local buttons = 0;
    try { buttons = player.GetButtons(); } catch(e) {
        try { buttons = player.GetButtonPressed(); } catch(e2) {}
    }

    local shovePressed = ((buttons & 134217728) != 0) || ((buttons & 2048) != 0);

    if (shovePressed && !RadioPreview.lastShoveState)
        RadioPreview.DoShove(player);
    RadioPreview.lastShoveState = shovePressed;

    local finalPos = RadioPreview.ComputeGroundPos(player);
    if (finalPos == null) finalPos = player.GetOrigin();

    ent.SetOrigin(finalPos + Vector(0, 0, RadioSystem.PropZOffset));
    try { ent.SetAngles(0, player.GetAngles().y - 90.0, 0); } catch(e) {}

    EntFire("worldspawn", "RunScriptCode", "RadioPreview.Tick()", 0.02, null);
};

RadioPreview.TryShoveNPC <- function(npc, player) {
    local methods = ["GetShoved", "Shove", "OnShoved", "NPCCanBeShoved"];
    foreach (m in methods) {
        local has = false;
        try { has = (m in npc); } catch(e) {}
        if (!has) continue;

        try { npc[m](player); return true; } catch(e1) {}
        try { npc[m](); return true; } catch(e2) {}
    }
    return false;
};

RadioPreview.DoShove <- function(player) {
    if (player == null || !player.IsValid()) return;

    local ang   = player.EyeAngles();
    local pitch = ang.x * (3.14159265 / 180.0);
    local yaw   = ang.y * (3.14159265 / 180.0);
    local dir   = Vector(cos(yaw) * cos(pitch),
                         sin(yaw) * cos(pitch),
                         -sin(pitch));

    local start    = player.EyePosition();
    local totalLen = 40.0;
    local end      = start + dir * totalLen;

    local previewEnt = RadioPreview.ent;
    local ignoreEnt  = player;
    local hit        = null;

    for (local i = 0; i < 3; i++) {
        local trace = RadioTrace(start, end, 1174421507, ignoreEnt);

        local h = trace.enthit;
        if (h != null && typeof(h) != "instance") h = null;

        local frac = trace.fraction;
        if (frac == null) frac = 1.0;

        if (h == null) { hit = null; break; }

        if (previewEnt != null && h == previewEnt) {
            start     = start + dir * (totalLen * frac + 8.0);
            ignoreEnt = previewEnt;
            continue;
        }

        hit = h;
        break;
    }

    if (hit == null || !hit.IsValid()) return;

    local cn = hit.GetClassname();
    if (cn.len() < 9 || cn.slice(0, 9) != "npc_nmrih") return;

    RadioPreview.TryShoveNPC(hit, player);
};

try { PrecacheModel("models/items/w_radio.mdl"); } catch(ex) {}
try { PrecacheModel("models/items/v_radio.mdl"); } catch(ex) {}
try { PrecacheEntityFromTable({ classname = "item_pills" }); } catch(ex) {}

if (!("CRadioItem" in getroottable())) {
    class CRadioItem extends CCustomItem
    {
        weight = 120;

        constructor(pos, angles) {
            base.constructor(pos, angles, "CreateRadioItem");
        }

        function OnItemActive()
        {
            base.OnItemActive();
            if ("RadioPreview" in getroottable())
                RadioPreview.Start(player);
        }

        function OnItemInactive(new_active_item = null)
        {
            if ("RadioPreview" in getroottable())
                RadioPreview.Stop();
            base.OnItemInactive(new_active_item);
        }

        function OnItemDrop()
        {
            if ("RadioPreview" in getroottable())
                RadioPreview.Stop();
            base.OnItemDrop();
        }

        function Destroy()
        {
            if ("RadioPreview" in getroottable())
                RadioPreview.Stop();
            base.Destroy();
        }

        function StartUsing()
        {
            if (!("RadioPreview" in getroottable())) return;

            local pos = RadioPreview.GetPos();
            RadioPreview.Stop();
            if (pos == null) return;

            if ("RadioSystem" in getroottable())
                RadioSystem.PlayRandom(pos + Vector(0, 0, 40), pos);

            if (player != null && player.IsValid()) {
                try {
                    local cw = NetProps.GetPropInt(player, "_carriedWeight");
                    cw = cw - 120;
                    if (cw < 0) cw = 0;
                    NetProps.SetPropInt(player, "_carriedWeight", cw);
                } catch(e) {}
            }

            if (inventory_item != null && inventory_item.IsValid())
                try { EntFireByHandle(inventory_item, "Kill", "", 0, null, null); } catch(e) {}
            if (viewmodel_item != null && viewmodel_item.IsValid())
                try { EntFireByHandle(viewmodel_item, "Kill", "", 0, null, null); } catch(e) {}

            item_state = 5;
        }

        function OnItemUse()
        {
            return false;
        }
    }
}

if (!("CreateRadioItem" in getroottable())) {
    function CreateRadioItem(pos, angles) {
        if (!("N2SE" in getroottable())) return null;
        if (!N2SE.IsModOn("radio")) return null;
        if (pos == null) return null;
        if (angles == null) angles = Vector(0, 0, 0);
        return CRadioItem(pos, angles);
    }
}

if ("LootManager" in getroottable() && !("__radio_registered" in getroottable())) {
    try {
        LootManager.RegisterCustomItem({
            reference       = CreateRadioItem,
            base_class_name = "item_pills",
            use_button      = 1,
            world_model     = "models/items/w_radio.mdl",
            view_model      = "models/items/v_radio.mdl",
            label           = "Radio",
            icon            = "vgui/item_icons/radio",
            weight          = 120,
            loot_table      = {
                military = 8,
                any      = 6
            }
        });
        getroottable().__radio_registered <- true;
        printl("[RadioItem] registered to LootManager");
    } catch(ex) {
        printl("[RadioItem] register err: " + ex);
    }
}

try {
    Convars.RegisterCommand("give_radio", function(...) {
        if (!("N2SE" in getroottable())) return;
        if (!N2SE.IsModOn("radio")) return;
        local p = null;
        while ((p = Entities.FindByClassname(p, "player")) != null) {
            if (p.IsAlive()) {
                CreateRadioItem(p.GetOrigin() + Vector(0, 0, 70), Vector(0, 270, 0));
                return;
            }
        }
    }, "Spawn a Radio item", 0);
} catch(ex) {}

printl("[Radio] n2se_radio loaded");