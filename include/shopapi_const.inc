#if defined _shopapi_const_included
    #endinput
#endif
#define _shopapi_const_included

#define SHOP_MAX_ITEM_CMD_LENGTH 32
#define SHOP_MAX_CATEGORY_NAME_LENGTH 128
#define SHOP_MAX_PLACEHOLDER_LENGTH 32
#define SHOP_MAX_PLACEHOLDER_VAL_LENGTH 128
#define SHOP_MAX_ITEM_NAME_LENGTH 128
#define SHOP_MAX_KEY_LENGTH 32

public stock const ShopCategory: ShopOtherCategory;

enum ItemFlag (<<=1)
{
    IF_None = 1,
    IF_OnlyAlive,
    IF_OnlyDead,
    IF_OnlyCtTeam,
    IF_OnlyTTeam,
    IF_OnlySpectator
};

enum ItemProp
{
    Item_Strkey,
    Item_Name,
    Item_Cost,
    Item_Access = 4,
    Item_Discount,
    Item_Flags,
    Item_Inventory
};

enum BuyState
{
    Buy_NotEnoughMoney,
    Buy_PlayerDead,
    Buy_PlayerAlive,
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