#include <amxmodx>
#include <shopapi>
#include <cstrike>

#pragma semicolon           1
#pragma ctrlchar            '\'

new const PLUGIN[] =        "Shop API";

const ITEMS_ON_PAGE_WITH_PAGINATOR = 7;
const ITEMS_ON_PAGE_WITHOUT_PAGINATOR = 9;

enum any: ItemProperties
{
    ItemStrKey[SHOP_MAX_KEY_LENGTH],
    ItemName[SHOP_MAX_ITEM_NAME_LENGTH],
    ItemCost,
    ItemPlugin,
    ItemAccess,
    bool: ItemInventory,
    bool: ItemDiscounts,
    ItemFlag: ItemFlags
};

new Array: g_pItemsVec, Array: g_pForwardsVec;
new g_iPlayerMenuPage[MAX_PLAYERS + 1], 
Array: g_iPlayerCurrentMenu[MAX_PLAYERS + 1],
g_iPlayerSelectItem[MAX_PLAYERS][ITEMS_ON_PAGE_WITHOUT_PAGINATOR + 1];

public plugin_init()
{
    register_plugin(PLUGIN, SHOPAPI_VERSION_STR, "gamingEx");

    register_clcmd("say /shop",         "CmdHandle_ShopMenu");
    register_clcmd("say_team /shop",    "CmdHandle_ShopMenu");
	
    const MENU_KEYS_ALL = 1023;
    register_menucmd(register_menuid("SHOP_API_MENU"), MENU_KEYS_ALL, "MenuHandle_ShopMenu");
}

public CmdHandle_ShopMenu(const player)
{
    if (!ExecuteEventsHandle(Shop_OpenMenu, false, player)) {
        return PLUGIN_HANDLED;
    }

    CreateMenu(player, g_iPlayerMenuPage[player] = 0);

    return PLUGIN_HANDLED;
}

const KEY_BACK = 7;
const KEY_NEXT = 8;
const KEY_EXIT = 9;
public MenuHandle_ShopMenu(const player, const key)
{
    new bool: bPagination = ArraySize(g_pItemsVec) > ITEMS_ON_PAGE_WITHOUT_PAGINATOR;

    switch (key) {
        case KEY_EXIT: {}
        case KEY_BACK: bPagination ? CreateMenu(player, --g_iPlayerMenuPage[player]) : SelectShopItem(player, g_iPlayerSelectItem[player][key]);
        case KEY_NEXT: bPagination ? CreateMenu(player, ++g_iPlayerMenuPage[player]) : SelectShopItem(player, g_iPlayerSelectItem[player][key]);
        default: SelectShopItem(player, g_iPlayerSelectItem[player][key]);
    }

    MenuDestroy(player);
}

CreateMenu(const player, const page)
{
    new sItemData[ItemProperties];
    g_iPlayerCurrentMenu[player] = CreateMenuItemsStorage();
    
    for (new i; i < ArraySize(g_pItemsVec); i++) {
        if (!ArrayGetArray(g_pItemsVec, i, sItemData)) {
            continue;
        }

        if (!ExecuteEventsHandle(Shop_AddItemToMenu, false, player, i) || !ExecuteEventsHandle(Shop_AddItemToMenu, true, player, i)) {
            continue;
        }
        
        if ((sItemData[ItemFlags] & IF_OnlyCtTeam && cs_get_user_team(player) != CS_TEAM_CT) 
            || (sItemData[ItemFlags] & IF_OnlyTTeam && cs_get_user_team(player) != CS_TEAM_T)
            || (sItemData[ItemFlags] & IF_OnlySpectator && cs_get_user_team(player) != CS_TEAM_SPECTATOR)) {
                continue;
        }

        MenuPushItem(player, i);
    }

    MenuDisplay(player, page);
}

SelectShopItem(const player, const item)
{
    new sItemData[ItemProperties];
    ArrayGetArray(g_pItemsVec, item, sItemData);

    if (sItemData[ItemCost] > cs_get_user_money(player)) {
        ExecuteEventsHandle(Shop_ItemBuy, false, player, item, Buy_NotEnoughMoney);
        ExecuteEventsHandle(Shop_ItemBuy, true, player, item, Buy_NotEnoughMoney);
    }
    else if (sItemData[ItemFlags] & IF_OnlyAlive && !is_user_alive(player)) {
        ExecuteEventsHandle(Shop_ItemBuy, false, player, item, Buy_PlayerDead);
        ExecuteEventsHandle(Shop_ItemBuy, true, player, item, Buy_PlayerDead);
    }
    else if (sItemData[ItemFlags] & IF_OnlyDead && is_user_alive(player)) {
        ExecuteEventsHandle(Shop_ItemBuy, false, player, item, Buy_PlayerAlive);
        ExecuteEventsHandle(Shop_ItemBuy, true, player, item, Buy_PlayerAlive);
    }
    else {
        new bSuccess = ExecuteEventsHandle(Shop_ItemBuy, false, player, item, Buy_OK);
        bSuccess && (bSuccess = ExecuteEventsHandle(Shop_ItemBuy, true, player, item, Buy_OK));

        if (bSuccess) {
            cs_set_user_money(player, cs_get_user_money(player) - sItemData[ItemCost]);
        }
    }
}

/**************** API **********************/

enum any: ForwardProperties
{
    ShopFunc: ForwardFunc,
    bool: ForwardSingle,
    bool: ForwardDisable,
    ForwardHandle,
    ForwardItem,
    ForwardPlugin
};

new const LOG_PREFIX[] = "[ShopAPI]";

public plugin_natives()
{
    g_pItemsVec     = ArrayCreate(ItemProperties);
    g_pForwardsVec  = ArrayCreate(ForwardProperties);

    register_native("ShopRegisterEvent",            "NativeHandle_RegisterEvent");
    register_native("ShopRegisterEventFromItem",    "NativeHandle_RegisterEventFromItem");
    register_native("ShopDisableEvent",             "NativeHandle_DisableEvent");
    register_native("ShopEnableEvent",              "NativeHandle_EnableEvent");

    register_native("ShopPushItem",                 "NativeHandle_PushItem");
    register_native("ShopDestroyItem",              "NativeHandle_DestroyItem");
    register_native("ShopGetItemInfo",              "NativeHandle_GetItemInfo");
    register_native("ShopGetItemFlags",             "NativeHandle_GetItemFlags");
    register_native("ShopFindItemByKey",            "NativeHandle_FindItemByKey");
}

public NativeHandle_RegisterEvent(amxx)
{
    enum { param_func = 1, param_handle, param_byplugin };

    new const ShopFunc: iFuncID = ShopFunc: get_param(param_func);
    new sForwardData[ForwardProperties], szHandle[32];

    if (!GetHandle(amxx, param_handle, szHandle, charsmax(szHandle))) {
        log_error(AMX_ERR_NATIVE, "%s Function \"%s\" not found.", LOG_PREFIX, szHandle);
        return INVALID_HANDLE;
    }

    switch (iFuncID) {
        case Shop_OpenMenu: sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL);
        case Shop_ItemBuy: sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL, FP_CELL, FP_CELL);
        case Shop_AddItemToMenu, Shop_ItemEnablePressing: sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL, FP_CELL);

        default: {
            log_error(AMX_ERR_NATIVE, "%s Invalid function id (%i).", LOG_PREFIX, iFuncID);
            return INVALID_HANDLE;
        }
    }

    sForwardData[ForwardFunc]   = iFuncID;
    sForwardData[ForwardPlugin] = get_param(param_byplugin) ? amxx : 0;
    return ArrayPushArray(g_pForwardsVec, sForwardData, sizeof sForwardData);
}

public NativeHandle_RegisterEventFromItem(amxx)
{
    enum { param_func = 1, param_item, param_handle };

    new const ShopFunc: iFuncID = ShopFunc: get_param(param_func);
    new sForwardData[ForwardProperties], szHandle[32];

    if (!GetHandle(amxx, param_handle, szHandle, charsmax(szHandle))) {
        log_error(AMX_ERR_NATIVE, "%s Function \"%s\" not found.", LOG_PREFIX, szHandle);
        return INVALID_HANDLE;
    }

    if (0 > (sForwardData[ForwardItem] = get_param(param_item)) >= ArraySize(g_pItemsVec)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, sForwardData[ForwardItem]);
        return INVALID_HANDLE;
    }

    switch (iFuncID) {
        case Shop_ItemBuy: sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL, FP_CELL, FP_CELL);
        case Shop_AddItemToMenu, Shop_ItemEnablePressing: sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL, FP_CELL);

        default: {
            log_error(AMX_ERR_NATIVE, "%s Invalid function id (%i) for single item.", LOG_PREFIX, iFuncID);
            return INVALID_HANDLE;
        }
    }

    sForwardData[ForwardFunc] = iFuncID;
    sForwardData[ForwardSingle] = true;
    return ArrayPushArray(g_pForwardsVec, sForwardData);
}

public bool: NativeHandle_DisableEvent(amxx)
{
    enum { param_forward = 1 };
    return ToggleState(get_param(param_forward), false);
}

public bool: NativeHandle_EnableEvent(amxx)
{
    enum { param_forward = 1 };
    return ToggleState(get_param(param_forward), true);
}

public NativeHandle_PushItem(amxx)
{
    enum { param_name = 1, param_cost, param_access, param_flags, param_discounts, param_inventory, param_key };

    new sItemData[ItemProperties];

    if (!get_string(param_name, sItemData[ItemName], charsmax(sItemData[ItemName]))) {
        log_error(AMX_ERR_NATIVE, "%s Item name can't be empty.", LOG_PREFIX);
        return INVALID_HANDLE;
    }

    sItemData[ItemPlugin]       = amxx;
    sItemData[ItemCost]         = get_param(param_cost);
    sItemData[ItemAccess]       = get_param(param_access);
    sItemData[ItemFlags]        = ItemFlag: get_param(param_flags);
    sItemData[ItemInventory]    = bool: get_param(param_inventory);
    sItemData[ItemDiscounts]    = bool: get_param(param_discounts);

    if (get_string(param_key, sItemData[ItemStrKey], charsmax(sItemData[ItemStrKey])) 
        && ArrayFindString(g_pItemsVec, sItemData[ItemStrKey]) != INVALID_HANDLE) {
            log_error(AMX_ERR_NATIVE, "%s The string key must be unique (\"%s\" already exists).", LOG_PREFIX, sItemData[ItemStrKey]);
            return INVALID_HANDLE;
    }

    return ArrayPushArray(g_pItemsVec, sItemData);
}

public NativeHandle_DestroyItem(amxx)
{
    enum { param_item = 1 };
    ArrayDeleteItem(g_pItemsVec, get_param(param_item));
}

public bool: NativeHandle_GetItemInfo(amxx)
{
    enum { param_item = 1, param_namebuffer, param_namelen, param_cost, param_access, param_keybuffer, param_keylen };

    new sItemData[ItemProperties];
    if (!ArrayGetArray(g_pItemsVec, get_param(param_item), sItemData)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, get_param(param_item));
        return false;
    }

    set_string(param_namebuffer,    sItemData[ItemName],    get_param(param_namelen));
    set_param_byref(param_cost,     sItemData[ItemCost]);
    set_param_byref(param_access,   sItemData[ItemAccess]);
    set_string(param_keybuffer,     sItemData[ItemStrKey],  get_param(param_keylen));

    return true;
}

public ItemFlag: NativeHandle_GetItemFlags(amxx)
{
    enum { param_item = 1, param_buffer };

    new sItemData[ItemProperties];
    if (!ArrayGetArray(g_pItemsVec, get_param(param_item), sItemData)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, get_param(param_item));
        return IF_None;
    }

    set_param_byref(param_buffer, _:sItemData[ItemFlags]);
    return sItemData[ItemFlags];
}

public NativeHandle_FindItemByKey(amxx)
{
    enum { param_key = 1 };

    new szStringKey[32];
    get_string(param_key, szStringKey, charsmax(szStringKey));

    return ArrayFindString(g_pItemsVec, szStringKey);
}

/**************** END API ******************/

/**************** UTILS ********************/

stock GetHandle(amxx, param, buffer[], len)
{
    if (!get_string(param, buffer, len)) {
        log_error(AMX_ERR_NATIVE, "%s Function can't be empty.", LOG_PREFIX);
        return false;
    }

    if (get_func_id(buffer, amxx) == INVALID_HANDLE) {
        log_error(AMX_ERR_NATIVE, "%s Function %s not found.", LOG_PREFIX, buffer);
        return false;
    }

    return true;
}

stock bool: ToggleState(forwardid, const bool: forwardstate)
{
    if (0 > forwardid >= ArraySize(g_pForwardsVec)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid forward id (%i).", LOG_PREFIX, forwardid);
        return false;
    }

    new sForwardData[ForwardProperties];
    ArrayGetArray(g_pForwardsVec, forwardid, sForwardData);
    sForwardData[ForwardDisable] = forwardstate;
    
    return bool: ArraySetArray(g_pForwardsVec, forwardid, sForwardData);
}

stock bool: ExecuteEventsHandle(ShopFunc: func, bool: single, any: ...)
{
    enum { param_player = 2, param_item, param_state };

    new sForwardData[ForwardProperties], sItemData[ItemProperties], iIter, iResponse, bool: bState = true;

    if (numargs() > param_item) {
        ArrayGetArray(g_pItemsVec, getarg(param_item), sItemData);
    }

    while (iIter < ArraySize(g_pForwardsVec)) {
        ArrayGetArray(g_pForwardsVec, iIter++, sForwardData);

        if (sForwardData[ForwardDisable] || sForwardData[ForwardFunc] != func || sForwardData[ForwardSingle] != single) {
            continue;
        }

        if (sForwardData[ForwardPlugin] && sForwardData[ForwardPlugin] != sItemData[ItemPlugin]) {
            continue;
        }

        if (single && getarg(param_item) != sForwardData[ForwardItem]) {
            continue;
        }
        
        switch (func) {
            case Shop_OpenMenu: ExecuteForward(sForwardData[ForwardHandle], iResponse, getarg(param_player)); 
            case Shop_ItemBuy: ExecuteForward(sForwardData[ForwardHandle], iResponse, getarg(param_player), getarg(param_item), getarg(param_state));
            case Shop_AddItemToMenu, Shop_ItemEnablePressing: ExecuteForward(sForwardData[ForwardHandle], iResponse, getarg(param_player), getarg(param_item));
        }

        if (iResponse == SHOP_HANDLED) {
            bState = false;
        }

        if (iResponse == SHOP_BREAK) {
            return false;
        }
    }

    return bState;
}

stock RemoveColorSymbols(buffer[], const len)
{
    replace_all(buffer, len, "\\w", "");
    replace_all(buffer, len, "\\y", "");
    replace_all(buffer, len, "\\r", "");
    replace_all(buffer, len, "\\d", "");
}

/**************** END UTILS ****************/

/**************** MENU SYSTEM **************/

stock Array: CreateMenuItemsStorage()
{
    return ArrayCreate();
}

stock MenuPushItem(player, item)
{
    ArrayPushCell(g_iPlayerCurrentMenu[player], item);
}

#define DisableItem(%0,%1,%2) %0    &= ~(1 << %1); RemoveColorSymbols(%2, charsmax(%2))
stock MenuDisplay(const player, page)
{
    if (page < 0) {
        return;
    }

    new szMenu[512], bitsKeys = MENU_KEY_0, iStart, iEnd,
    iIter, iPages, iItem, iItems = ArraySize(g_iPlayerCurrentMenu[player]), sItemData[ItemProperties],
    iItemsOnPage = iItems > ITEMS_ON_PAGE_WITHOUT_PAGINATOR ? ITEMS_ON_PAGE_WITH_PAGINATOR : ITEMS_ON_PAGE_WITHOUT_PAGINATOR;

    if ((iStart = page * iItemsOnPage) >= iItems) {
        iStart = page = g_iPlayerMenuPage[player] = 0;
    }

    if ((iEnd = iStart + iItemsOnPage) > iItems) {
        iEnd = iItems;
    }

    formatex(szMenu, charsmax(szMenu), "AMXX Shop\nВаши деньги: \\r%i\\w$", cs_get_user_money(player));

    if ((iPages = iItems / iItemsOnPage + (iItems % iItemsOnPage ? 1 : 0)) > 1) {
        add(szMenu, charsmax(szMenu), fmt("\\R%i/%i", page + 1, iPages));
    }

    add(szMenu, charsmax(szMenu), "\n\n");

    if (!iItems) {
        add(szMenu, charsmax(szMenu), "\\dИзвините, но доступных для Вас\nтоваров пока нет :(");
    }

    while (iStart < iEnd) {
        ArrayGetArray(g_pItemsVec, iItem = ArrayGetCell(g_iPlayerCurrentMenu[player], iStart++), sItemData);

        if (~get_user_flags(player) & sItemData[ItemAccess]) {
            DisableItem(bitsKeys, iIter, sItemData[ItemName]);
            add(szMenu, charsmax(szMenu), fmt("\\d[%i] %s \\r *\\R$%i\n", iIter + 1, sItemData[ItemName], sItemData[ItemCost]));
        }
        else if (!ExecuteEventsHandle(Shop_ItemEnablePressing, false, player, iItem) || !ExecuteEventsHandle(Shop_ItemEnablePressing, true, player, iItem)) {
            DisableItem(bitsKeys, iIter, sItemData[ItemName]);
            add(szMenu, charsmax(szMenu), fmt("\\d[%i] %s \\r \\R$%i\n", iIter + 1, sItemData[ItemName], sItemData[ItemCost]));
        }
        else {
            bitsKeys |= (1 << iIter); // EnableItem
            add(szMenu, charsmax(szMenu), fmt("\\y[\\r%i\\y] \\w%s\\w \\R$%i\n", iIter + 1, sItemData[ItemName], sItemData[ItemCost]));
        }

        if (iStart == iEnd) {
            add(szMenu, charsmax(szMenu), "\n");
        }

        g_iPlayerSelectItem[player][iIter++] = iItem;
    }

    if (iItems > iItemsOnPage) {
        page ? (bitsKeys |= MENU_KEY_8) : (bitsKeys &= ~MENU_KEY_8);
        add(szMenu, charsmax(szMenu), fmt("%s Назад\n", page ? "\\y[\\r8\\y]\\w" : "\\d[8]"));
        iEnd < iItems ? (bitsKeys |= MENU_KEY_9) : (bitsKeys &= ~MENU_KEY_9);
        add(szMenu, charsmax(szMenu), fmt("%s Далее\n", iEnd < iItems ? "\\y[\\r9\\y]\\w" : "\\d[9]"));
    }

    add(szMenu, charsmax(szMenu), fmt("%s\\y[\\r0\\y]\\w Выход", iPages > 1 ? "" : "\n\n"));

    show_menu(player, bitsKeys, szMenu, -1, "SHOP_API_MENU");
}

stock MenuDestroy(player)
{
    ArrayDestroy(g_iPlayerCurrentMenu[player]);
}

/**************** END MENU SYSTEM **********/