#if defined _shopapi_const_included
    #endinput
#endif
#define _shopapi_const_included

#define SHOP_MAX_ITEM_NAME_LENGTH 128
#define SHOP_MAX_KEY_LENGTH 32

enum ItemFlag (<<=1)
{
    IF_None = 1,
    IF_OnlyAlive,
    IF_OnlyDead,
    IF_OnlyCtTeam,
    IF_OnlyTTeam,
    IF_OnlySpectator
};

enum BuyState
{
    Buy_NotEnoughMoney,
    Buy_PlayerDead,
    But_PlayerAlive,
    Buy_OK
};

enum ShopFunc
{
    /*
    * Description:          Called when the shop menu is opened
    * Handle params:        (const player)
    */
    Shop_OpenMenu,

    /*
    * Description:          Called before adding an items to the menu
    * Handle params:        (const player, const ShopItem: item)
    */
    Shop_AddItemToMenu,

    /*
    * Description:          Called before enable pressing for item
    * Handle params:        (const player, const ShopItem: item)
    */
    Shop_ItemEnablePressing,

    /*
    * Description:          Called when buying any item
    * Handle params:        (const player, const ShopItem: item, BuyState: buyState)
    */
    Shop_ItemBuy,
};