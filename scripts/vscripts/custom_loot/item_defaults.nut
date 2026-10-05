//-----------------------------------------------------------------------------
//              DURKHAZ 2024
//  Purpose :   
//  Usage   :   
//  Notes   :   
//-----------------------------------------------------------------------------

printcl(50,145,168,"Including "+getstackinfos(1).src+".");
function NormalizePool(pool, max_chance = 100.0)
{
    if (pool.len() == 0)
        return;

    local sum_chance = 0.0;
    foreach(chance in pool)
        sum_chance+=chance;

    if (sum_chance < 100.0)
    {
        pool.rest <- 100.0-sum_chance;
        sum_chance = 100.0;
    }

    foreach(name, chance in pool)
        pool[name] = (chance / sum_chance) * max_chance
}

labels <- 
{ 
    item_bandages =
    {
        brazilian = "Bandagens"
        czech = "Obvazy"
        english = "Bandages"
        finnish = "Sideharso"
        french = "Bandages"
        german = "Bandagen"
        greek = "Επίδεσμοι"
        hungarian = "Kötszerek"
        italian = "Bende"
        japanese = "包帯"
        korean = "붕대"
        koreana = "붕대"
        russian = "Бинты"
        schinese = "绷带"
        spanish = "Vendajes"
        swedish = "Bandage"
        tchinese = "繃帶"
        turkish = "Bandaj"
        ukrainian = "Бинти"
    }
    item_pills = 
    {
        brazilian = "Pílulas Phalanx"
        czech = "Pilulky"
        english = "Phalanx Pills"
        finnish = "Phalanx-pillerit"
        french = "Pillules Phalanx"
        german = "Phalanx Tabletten"
        greek = "Χάπια"
        hungarian = "Phalanx tabletták"
        italian = "Pillole Phalax"
        japanese = "ピル"
        korean = "팔랑크스 알약"
        koreana = "팔랑크스 알약"
        russian = "Таблетки Phalanx"
        schinese = "Phalanx 药片"
        spanish = "Píldoras Phalanx"
        swedish = "Phalanx Piller"
        tchinese = "斐蘭克斯膠囊"
        turkish = "Phalanx Hapları"
        ukrainian = "Піґулки Phalanx"
    }
    item_first_aid =
    {
        brazilian = "Kit Médico"
        czech = "Lékárnička"
        english = "First Aid Kit"
        finnish = "Ensiapupakkaus"
        french = "Kit de Premiers Secours"
        german = "Erste Hilfe Kasten"
        greek = "Πρώτες βοήθειες"
        hungarian = "Mentőláda"
        italian = "Kit di pronto soccorso"
        japanese = "救急キット"
        korean = "치료 키트"
        koreana = "치료 키트"
        russian = "Аптечка"
        schinese = "急救包"
        spanish = "Kit de primeros auxilios"
        swedish = "Första hjälpen kit"
        tchinese = "醫療包"
        turkish = "İlk Yardım Çantası"
        ukrainian = "Аптечка"
    }
    item_gene_therapy =
    {
        brazilian = "Terapia de genes"
        czech = "Genová terapie"
        english = "Gene Therapy"
        finnish = "Geeniterapia"
        french = "Thérapie Génique"
        german = "Gene Therapy"
        greek = "Gene Therapy"
        hungarian = "Gene Therapy"
        italian = "Terapia genica"
        japanese = "Gene Therapy"
        korean = "유전자 치료주사기"
        koreana = "유전자 치료주사기"
        russian = "Вакцина"
        schinese = "基因治疗针"
        spanish = "Terapia de Genes"
        swedish = "Gene Therapy"
        tchinese = "基因治療劑"
        turkish = "Gen Tedavisi"
        ukrainian = "Gene Therapy"
    }
}
weight_order <-
[
    "fa_glock17"
    "fa_m92fs" 
    "fa_mkiii" 
    "fa_sw686" 
    "fa_1911" 
    "fa_1022" 
    "fa_1022_25mag" 
    "fa_sks" 
    "fa_sako85" 
    "fa_cz858" 
    "fa_jae700" 
    "fa_fnfal" 
    "fa_870" 
    "fa_superx3" 
    "fa_sv10" 
    "fa_500a" 
    "fa_winchester1892" 
    "fa_mac10" 
    "fa_mp5a3" 
    "fa_m16a4" 
    "fa_m16a4_carryhandle" 
    "me_chainsaw" 
    "me_abrasivesaw" 
    "bow_deerhunter" 
    "me_axe_fire" 
    "me_bat_metal" 
    "me_crowbar" 
    "me_etool" 
    "me_fubar" 
    "me_hatchet" 
    "me_kitknife" 
    "me_machete" 
    "me_pipe_lead" 
    "me_shovel" 
    "me_sledge" 
    "me_wrench" 
    "exp_grenade" 
    "exp_molotov" 
    "exp_tnt" 
    "item_maglite" 
    "tool_extinguisher" 
    "tool_welder" 
    "tool_barricade" 
    "tool_flare_gun" 
    "item_walkietalkie" 
    "item_pills" 
    "item_first_aid" 
    "item_gene_therapy" 
    "item_bandages" 
    "ammobox_9mm" 
    "ammobox_45acp" 
    "ammobox_357" 
    "ammobox_12gauge" 
    "ammobox_22lr" 
    "ammobox_308" 
    "ammobox_556" 
    "ammobox_762mm" 
    "ammobox_arrow" 
    "ammobox_board" 
    "ammobox_fuel" 
    "ammobox_flare" 
    "any" 
    "firearm" 
    "handgun" 
    "rifle" 
    "shotgun" 
    "machinegun" 
    "military" 
    "melee" 
    "explosive" 
    "ammo" 
    "item" 
    "fa_sks_nobayo" 
    "fa_sako85_ironsights" 
    "me_pickaxe" 
    "me_cleaver" 
];

POOL_TYPE <- {AMMO=0, WEAPON=1, ITEM_CUSTOM=2, POOL_SPAWNER=3, POOL_STANDARD=4, POOL_NO_CUSTOM=5, POOL_CUSTOM=6};

item_pools <- 
{
    any                 = {pool = {}}
    firearm             = {pool = {}}
    handgun             = {pool = [0, 1, 2, 3, 4]}
    rifle               = {pool = [5, 6, 7, 8, 9, 10, 11, 16, 72, 73]}
    shotgun             = {pool = [12, 13, 14, 15]}
    machinegun          = {pool = [17]}
    military            = {pool = [18, 19, 20]}
    melee               = {pool = {}}
    explosive           = {pool = {}}
    ammo                = {pool = {}}
    item                = {pool = {}}
    supply_medical      = {pool = [45, 46, 47, 48],     type = POOL_TYPE.POOL_NO_CUSTOM}
    supply_weapon_rare  = {pool = [21, 22],             type = POOL_TYPE.POOL_NO_CUSTOM}
    supply_weapon       = {pool = {},                   type = POOL_TYPE.POOL_NO_CUSTOM}
    supply_ammo         = {pool = {},                   type = POOL_TYPE.POOL_NO_CUSTOM}
    ng_drop             = {pool = {ng_drop_rest = 66, ammobox_9mm = 15 ammobox_556 = 10, item_bandages = 5, fa_m92fs = 3, exp_grenade = 1}}
    ng_drop_rest        = {pool = {}}
    rest                = {pool = {}}
};


foreach(key, item in item_pools)
{
    if (type(item.pool) == "array")
    {
        local weight = 100.0 / item.pool.len();
        local pool = clone item.pool;
        item_pools[key].pool = {};
        foreach (id in pool)
            item_pools[key].pool[weight_order[id]] <- weight;
    }
    
    if ("type" in item_pools[key])
        continue;

    item_pools[key].type <- POOL_TYPE.POOL_STANDARD;
}

foreach(item in weight_order)
{
    if (item in item_pools)
        continue;

    item_pools.any.pool[item] <- -1;
    local prefix = item.slice(0, 2);
    switch (prefix)
    {
        case "it":
            item_pools.item.pool[item] <- -1;
            break;
        case "me":
            item_pools.melee.pool[item] <- -1;
            item_pools.supply_weapon.pool[item] <- -1;
            break;
        case "fa":
            item_pools.firearm.pool[item] <- -1;
            item_pools.supply_weapon.pool[item] <- -1;
            break;
        case "ex":
            item_pools.explosive.pool[item] <- -1;
            break;
        case "am":
            item_pools.ammo.pool[item] <- -1;
            break;
        case "bo":
            item_pools.supply_weapon.pool[item] <- -1;
            break;
    }
    item_pools[item] <- {type = (item.find("ammobox") != null ? POOL_TYPE.AMMO : POOL_TYPE.WEAPON), pool = {}};
    item_pools[item].pool[item] <- 100;
}

delete item_pools.ammo.pool[weight_order[58]];
item_pools.supply_ammo.pool = clone item_pools.ammo.pool;

foreach(class_name, weight in item_pools.supply_weapon_rare.pool)
{
    delete item_pools.supply_weapon.pool[class_name];
    delete item_pools.melee.pool[class_name];
}

foreach(key, item in item_pools)
{
    local weight = 100.0 / item.pool.len();
    foreach(name, chance in item.pool)
    {
        if (chance > 0)
            break;
        item.pool[name] = weight;
    }
}

item_pools.nothing <- {pool = {}, type = POOL_TYPE.POOL_NO_CUSTOM};