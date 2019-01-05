#include <amxmodx>
#include <shopapi>
#include <fakemeta>
#include <cstrike>

#pragma semicolon           1
#pragma ctrlchar            '\'

new const PLUGIN[] =        "Shop API: Stub Plugin";

const MIN_COST              = 10;
const GAMEDLL_MAXMONEY      = 16000;

const Float: GRAVITY_AMOUNT = 0.4;
const Float: HEALTH_AMOUNT  = 100.0;
const Float: SPEED_AMOUNT   = 400.0;

new const CHAT_PREFIX[]     = "\4[SHOP]\1";

enum ShopItems
{
    SI_Gravity,
    SI_Speed,
    SI_HP
};

enum ItemParams
{
    ShopItem: ItemID,
    ItemCost
};

new g_iItems[ShopItems][ItemParams];

public plugin_init()
{
    register_plugin(PLUGIN, SHOPAPI_VERSION_STR, "gamingEx");

    CreateCVars();

    g_iItems[SI_Gravity][ItemID]    = ShopPushItem("Гравитация",  g_iItems[SI_Gravity][ItemCost],   .flags = IF_OnlyAlive);
    g_iItems[SI_Speed][ItemID]      = ShopPushItem("Скорость",    g_iItems[SI_Speed][ItemCost],     .flags = IF_OnlyAlive);
    g_iItems[SI_HP][ItemID]         = ShopPushItem("100 HP",      g_iItems[SI_HP][ItemCost],        .flags = IF_OnlyAlive);

    ShopRegisterEvent(Shop_ItemBuy, "Shop_ItemBuyHandle");
}

CreateCVars()
{
    new const iMaxCost = cvar_exists("mp_maxmoney") ? get_cvar_num("mp_maxmoney") : GAMEDLL_MAXMONEY;
    bind_pcvar_num(create_cvar("shop_gravity_cost", "6000", FCVAR_NONE, "Cost of gravity", true, float(MIN_COST), true, float(iMaxCost)), g_iItems[SI_Gravity][ItemCost]);
    bind_pcvar_num(create_cvar("shop_speed_cost", "6000", FCVAR_NONE, "Cost of speed", true, float(MIN_COST), true, float(iMaxCost)), g_iItems[SI_Speed][ItemCost]);
    bind_pcvar_num(create_cvar("shop_hp_cost", "6000", FCVAR_NONE, "Cost of hp", true, float(MIN_COST), true, float(iMaxCost)), g_iItems[SI_HP][ItemCost]);
}

public Shop_ItemBuyHandle(const player, const ShopItem: item, const BuyState: buyState)
{
    new szName[SHOP_MAX_ITEM_NAME_LENGTH], iCost;
    ShopGetItemInfo(item, szName, charsmax(szName), iCost);

    switch (buyState) {
        case Buy_NotEnoughMoney: {
            client_print_color(player, print_team_default, "%s Для покупки не хватает\4 %i\1$.", CHAT_PREFIX, iCost - cs_get_user_money(player));
        }

        case Buy_OK: {
            if (item == g_iItems[SI_Gravity][ItemID]) {
                set_pev(player, pev_gravity, GRAVITY_AMOUNT);
                client_print_color(player, print_team_default, "%s Вы купили предмет\4 %s\1 за\4 %i\1.", CHAT_PREFIX, szName, iCost);
            }
            else if (item == g_iItems[SI_Speed][ItemID]) {
                set_pev(player, pev_maxspeed, SPEED_AMOUNT);
                client_print_color(player, print_team_default, "%s Вы купили предмет\4 %s\1 за\4 %i\1.", CHAT_PREFIX, szName, iCost);
            }
            else if (item == g_iItems[SI_HP][ItemID]) {
                set_pev(player, pev_health, HEALTH_AMOUNT);
                client_print_color(player, print_team_default, "%s Вы купили предмет\4 %s\1 за\4 %i\1.", CHAT_PREFIX, szName, iCost);
            }
        }
    }
}