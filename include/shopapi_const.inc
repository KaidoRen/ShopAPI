#if defined _shopapi_const_included
    #endinput
#endif
#define _shopapi_const_included

enum (<<=1)
{
    IF_None = 1,
    IF_OnlyAlive,
    IF_OnlyDead,
    IF_OnlyCtTeam,
    IF_OnlyTTeam
};

enum BuyState
{
    Buy_NotEnoughMoney,
    Buy_PlayerDead,
    But_PlayerAlive,
    Buy_Successful
};

enum ShopFunc
{
    /*
    * Description:        Called when the shop menu is opened
    * Handle params:      (const player)
    * Hook params:        (const ShopFunc: funcid, const handle[])
    */
    Shop_OpenMenu,

    /*
    * Description:        Called when buying any item
    * Handle params:      (const player, const item, BuyState: buyState)
    * Hook params:        (const ShopFunc: funcid, const handle[])
    */
    Shop_ItemsBuy,

    /*
    * Description:        Called when buying the specified item
    * Handle params:      (const player, const item, BuyState: buyState)
    * Hook params:        (const ShopFunc: funcid, const item, const handle[])
    */
    Shop_ItemBuy
};