#include <amxmodx>
#include <shopapi>
#include <fakemeta>
#include <cstrike>
#include <hamsandwich>
#include <fun>

#pragma semicolon           1
#pragma ctrlchar            '\'

new const PLUGIN[] =        "Shop API: Stub Plugin";

const ADMIN_FLAG            = ADMIN_LEVEL_H;
const ADMIN_DISCOUNT        = 50;

new const CHAT_PREFIX[]     = "\4[SHOP]\1";

enum ShopItems
{
    ShopItem_Gravity,
    ShopItem_Speed,
    ShopItem_HP,
    ShopItem_HE,
    ShopItem_Deagle,
    ShopItem_Bhop
};

enum ItemParams
{
    ShopItem: ItemID,
    ItemCostCvar,
    any: ItemAmount
};

new any: g_sItemData[ShopItems][ItemParams];

public plugin_init()
{
    register_plugin(PLUGIN, SHOPAPI_VERSION_STR, "gamingEx");

    RegisterHamPlayer(Ham_Spawn, "CBasePlayer_Spawn_Post", .Post = true);
    RegisterHamPlayer(Ham_Killed, "CBasePlayer_Killed_Post", .Post = true);
    RegisterHamPlayer(Ham_Item_PreFrame, "CBasePlayer_ResetMaxSpeed_Pre");
    RegisterHamPlayer(Ham_Player_Jump, "CBasePlayer_Jump_Pre");

    CreateCVars();

    g_sItemData[ShopItem_Gravity][ItemID] = ShopPushItem("Гравитация", get_pcvar_num(g_sItemData[ShopItem_Gravity][ItemCostCvar]), .flags = IF_OnlyAlive, .inventory = true, .strkey = "gravity", .data = ShopItem_Gravity);
    g_sItemData[ShopItem_Speed][ItemID] = ShopPushItem("Скорость", get_pcvar_num(g_sItemData[ShopItem_Speed][ItemCostCvar]), .flags = IF_OnlyAlive, .inventory = true, .strkey = "speed", .data = ShopItem_Speed);
    g_sItemData[ShopItem_HP][ItemID] = ShopPushItem(fmt("%i HP", g_sItemData[ShopItem_HP][ItemAmount]), get_pcvar_num(g_sItemData[ShopItem_HP][ItemCostCvar]), .flags = IF_OnlyAlive, .strkey = "healths", .data = ShopItem_HP);
    g_sItemData[ShopItem_HE][ItemID] = ShopPushItem("Взрывная граната", get_pcvar_num(g_sItemData[ShopItem_HE][ItemCostCvar]), .flags = IF_OnlyAlive, .strkey = "he_grenade", .data = ShopItem_HE);
    g_sItemData[ShopItem_Deagle][ItemID] = ShopPushItem(fmt("Deagle %i патрона", g_sItemData[ShopItem_Deagle][ItemAmount]), get_pcvar_num(g_sItemData[ShopItem_Deagle][ItemCostCvar]), .flags = IF_OnlyAlive, .strkey = "deagle", .data = ShopItem_Deagle);
    g_sItemData[ShopItem_Bhop][ItemID] = ShopPushItem("Распрыжка", get_pcvar_num(g_sItemData[ShopItem_Bhop][ItemCostCvar]), .flags = IF_OnlyAlive, .inventory = true, .strkey = "bhop", .data = ShopItem_Bhop);

    ShopRegisterEvent(Shop_ItemBuy, "Shop_ItemBuyHandle");
}

CreateCVars()
{
    hook_cvar_change(g_sItemData[ShopItem_Gravity][ItemCostCvar] = create_cvar("shop_gravity_cost", "6000"), "CvarChange");
    hook_cvar_change(g_sItemData[ShopItem_Speed][ItemCostCvar] = create_cvar("shop_speed_cost", "6000"), "CvarChange");
    hook_cvar_change(g_sItemData[ShopItem_HP][ItemCostCvar] = create_cvar("shop_hp_cost", "9000"), "CvarChange");
    hook_cvar_change(g_sItemData[ShopItem_HE][ItemCostCvar] = create_cvar("shop_he_cost", "8000"), "CvarChange");
    hook_cvar_change(g_sItemData[ShopItem_Deagle][ItemCostCvar] = create_cvar("shop_deagle_cost", "16000"), "CvarChange");
    hook_cvar_change(g_sItemData[ShopItem_Bhop][ItemCostCvar] = create_cvar("shop_bhop_cost", "10000"), "CvarChange");

    bind_pcvar_float(create_cvar("shop_gravity_amount", "0.4"), g_sItemData[ShopItem_Gravity][ItemAmount]);
    bind_pcvar_float(create_cvar("shop_speed_amount", "400.0"), g_sItemData[ShopItem_Speed][ItemAmount]);
    bind_pcvar_num(create_cvar("shop_hp_amount", "100"), g_sItemData[ShopItem_HP][ItemAmount]);
    bind_pcvar_num(create_cvar("shop_deagle_amount", "3"), g_sItemData[ShopItem_Deagle][ItemAmount]);
}

public CvarChange(pCvar, const szOldValue[], const szNewValue[])
{
    new const iCost = str_to_num(szNewValue);
    for (new ShopItems: i = ShopItem_Gravity; i <= ShopItem_Bhop; i++) {
        if (pCvar == g_sItemData[i][ItemCostCvar] && ShopSetItemInfo(SHOP_GLOBAL_INFO, g_sItemData[i][ItemID], Item_Cost, iCost)) {
            break;
        }
    }
}

public client_putinserver(player)
{
    if (get_user_flags(player) & ADMIN_FLAG) {
        ShopSetItemInfo(player, g_sItemData[ShopItem_Gravity][ItemID], Item_Discount, ADMIN_DISCOUNT);
    }
}

public Shop_ItemBuyHandle(const player, const ShopItem: item, const BuyState: buyState)
{
    new const szName[SHOP_MAX_ITEM_NAME_LENGTH], iCost;
    ShopGetItemInfo(player, item, szName, charsmax(szName), iCost);

    if (buyState == Buy_NotEnoughMoney) {
        // For purchase is missing N$
        client_print_color(player, print_team_default, "%s Для покупки не хватает\4 %i\1$.", CHAT_PREFIX, iCost - cs_get_user_money(player));
    }
    else if (buyState == Buy_PlayerAlive || buyState == Buy_PlayerDead) {
        // You must be alive or dead to purchase this item
        client_print_color(player, print_team_default, "%s Для покупки этого предмета нужно быть %s.", CHAT_PREFIX, buyState == Buy_PlayerAlive ? "мертвым" : "живым");
    }
    else if (buyState == Buy_AccessDenied) {
        // Not enough rights for this item
        client_print_color(player, print_team_default, "%s Недостаточно прав для этого предмета.", CHAT_PREFIX, iCost - cs_get_user_money(player));
    }
    else if (buyState == Buy_OK) {
        // Successfully purchase
        client_print_color(player, print_team_default, "%s Вы купили предмет\4 %s\1 за\4 %i\1.", CHAT_PREFIX, szName, iCost);

        switch (ShopGetItemCustomData(item)) {
            case ShopItem_Gravity: set_pev(player, pev_gravity, g_sItemData[ShopItem_Gravity][ItemAmount]);
            case ShopItem_Speed: set_pev(player, pev_maxspeed, g_sItemData[ShopItem_Speed][ItemAmount]);
            case ShopItem_HP: set_pev(player, pev_health, float(g_sItemData[ShopItem_HP][ItemAmount]));
            case ShopItem_HE: give_item(player, "weapon_hegrenade");
            case ShopItem_Deagle: {
                if (user_has_weapon(player, CSW_DEAGLE)) {
                    // Deagle already exists
                    client_print_color(player, print_team_default, "%s Покупка невозможна, у вас уже есть этот предмет.", CHAT_PREFIX);
                    return SHOP_HANDLED;
                }

                cs_set_weapon_ammo(give_item(player, "weapon_deagle"), g_sItemData[ShopItem_Deagle][ItemAmount]);
            }
        }
    }

    return SHOP_CONTINUE;
}

public CBasePlayer_Spawn_Post(const player)
{
    if (!is_user_alive(player) || !ShopHasUserItem(player, g_sItemData[ShopItem_Gravity][ItemID])) {
        return HAM_IGNORED;
    }

    set_pev(player, pev_gravity, g_sItemData[ShopItem_Gravity][ItemAmount]);

    return HAM_IGNORED;
}

public CBasePlayer_Killed_Post(const player)
{
    ShopClearUserInventory(player, g_sItemData[ShopItem_Bhop][ItemID]);
}

public CBasePlayer_ResetMaxSpeed_Pre(const player)
{
    if (is_user_alive(player) && ShopHasUserItem(player, g_sItemData[ShopItem_Speed][ItemID])) {
        return HAM_SUPERCEDE;
    }

    return HAM_IGNORED;
}

public CBasePlayer_Jump_Pre(const player)
{
	if (!ShopHasUserItem(player, g_sItemData[ShopItem_Bhop][ItemID])) {
        return HAM_IGNORED;
    }
	
	new const bitsFlags = pev(player, pev_flags);
	
	if (bitsFlags & FL_WATERJUMP || pev(player, pev_waterlevel) >= 2 || ~bitsFlags & FL_ONGROUND) {
		return HAM_IGNORED;
    }

	new Float: flVelocity[3]; pev(player, pev_velocity, flVelocity);
	
	flVelocity[2] = 250.0;
	
	set_pev(player, pev_velocity, flVelocity);
	set_pev(player, pev_gaitsequence, 6);
	set_pev(player, pev_fuser2, 0.0);
	
	return HAM_IGNORED;
}