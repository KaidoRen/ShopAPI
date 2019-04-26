#include <amxmodx>
#include <shopapi>
#include <cstrike>

#pragma semicolon           1
#pragma ctrlchar            '\'

new const PLUGIN[] =        "Shop API";
new const LOG_PREFIX[] =    "[ShopAPI]";

const ITEMS_ON_PAGE_WITH_PAGINATOR = 7;
const ITEMS_ON_PAGE_WITHOUT_PAGINATOR = 9;

enum any: ItemProperties
{
    ItemStrKey[SHOP_MAX_KEY_LENGTH],
    ItemName[SHOP_MAX_ITEM_NAME_LENGTH],
    ItemCost,
    ItemPlugin,
    ItemAccess,
    ItemDiscount,
    ItemFlag: ItemFlags,
    bool: ItemInventory
};

enum any: PlayerDataProperties
{
    PlayerCurrentPage,
    PlayerAuthID[MAX_AUTHID_LENGTH],
    PlayerSelectItem[ITEMS_ON_PAGE_WITHOUT_PAGINATOR + 1],
    Array: PlayerCurrentMenu,
    Array: PlayerInventory,
    Trie: PlayerItemData
};

enum any: ForwardProperties
{
    ShopFunc: ForwardFunc,
    bool: ForwardSingle,
    bool: ForwardDisable,
    ForwardHandle,
    ForwardItem,
    ForwardPlugin
};

new Array: g_pItemsVec, Array: g_pForwardsVec, Trie: g_pPlaceholdersAssoc, Trie: g_pPlayersData;
new g_sPlayerData[MAX_PLAYERS + 1][PlayerDataProperties];

public plugin_init()
{
    register_plugin(PLUGIN, SHOPAPI_VERSION_STR, "gamingEx");

    register_clcmd("say /shop",         "CmdHandle_ShopMenu");
    register_clcmd("say_team /shop",    "CmdHandle_ShopMenu");
	
    const MENU_KEYS_ALL = 1023;
    register_menucmd(register_menuid("SHOP_API_MENU"), MENU_KEYS_ALL, "MenuHandle_ShopMenu");

    register_dictionary("shop.txt");

    g_pPlayersData          = TrieCreate();
    g_pPlaceholdersAssoc    = TrieCreate();
    g_pItemsVec             = ArrayCreate(ItemProperties);
    g_pForwardsVec          = ArrayCreate(ForwardProperties);
}

public client_authorized(player, const authid[])
{
    arrayset(g_sPlayerData[player], 0, PlayerDataProperties);
    TrieGetArray(g_pPlayersData, authid, g_sPlayerData[player], PlayerDataProperties);
    copy(g_sPlayerData[player][PlayerAuthID], charsmax(g_sPlayerData[][PlayerAuthID]), authid);
}

public client_disconnected(player)
{
    TrieSetArray(g_pPlayersData, g_sPlayerData[player][PlayerAuthID], g_sPlayerData[player], PlayerDataProperties);
}

public CmdHandle_ShopMenu(const player)
{
    if (!ExecuteEventsHandle(Shop_OpenMenu, false, player)) {
        return PLUGIN_HANDLED;
    }

    CreateMenu(player, g_sPlayerData[player][PlayerCurrentPage] = 0);

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
        case KEY_BACK: bPagination ? CreateMenu(player, --g_sPlayerData[player][PlayerCurrentPage]) : SelectShopItem(player, g_sPlayerData[player][PlayerSelectItem][key]);
        case KEY_NEXT: bPagination ? CreateMenu(player, ++g_sPlayerData[player][PlayerCurrentPage]) : SelectShopItem(player, g_sPlayerData[player][PlayerSelectItem][key]);
        default: SelectShopItem(player, g_sPlayerData[player][PlayerSelectItem][key]);
    }

    MenuDestroy(player);
}

CreateMenu(const player, const page)
{
    new sItemData[ItemProperties];
    g_sPlayerData[player][PlayerCurrentMenu] = CreateMenuItemsStorage();
    
    for (new i; i < ArraySize(g_pItemsVec); i++) {
        if (!GetItemData(player, i, sItemData)) {
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

#define GET_COST_WITH_DISCOUNT(%0,%1) %0 - %0 * %1 / 100
SelectShopItem(const player, const item)
{
    new sItemData[ItemProperties];
    if (!GetItemData(player, item, sItemData)) {
        log_error(AMX_ERR_NOTFOUND, "%s Invalid item id (%i)", LOG_PREFIX, item);
        return;
    }

    new const iCost = sItemData[ItemDiscount] ? GET_COST_WITH_DISCOUNT(sItemData[ItemCost], sItemData[ItemDiscount]) : sItemData[ItemCost];

    if (iCost > cs_get_user_money(player)) {
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
            cs_set_user_money(player, cs_get_user_money(player) - iCost);

            if (sItemData[ItemInventory]) {
                if (!g_sPlayerData[player][PlayerInventory]) {
                    g_sPlayerData[player][PlayerInventory] = ArrayCreate();
                }

                ArrayPushCell(g_sPlayerData[player][PlayerInventory], item);
            }
        }
    }
}

/**************** API **********************/

#define CHECK_PLAYER(%0) \
    if (!(0 < %0 <= MaxClients)) { \
        log_error(AMX_ERR_NATIVE, "%s Player out of range (%i)", LOG_PREFIX, %0); \
        return any: PLUGIN_CONTINUE; \
    }

public plugin_natives()
{
    // (ForwardNatives)
    {
        register_native("ShopRegisterEvent",            "NativeHandle_RegisterEvent");
        register_native("ShopRegisterEventFromItem",    "NativeHandle_RegisterEventFromItem");
        register_native("ShopDisableEvent",             "NativeHandle_DisableEvent");
        register_native("ShopEnableEvent",              "NativeHandle_EnableEvent");
    }

    // (ItemNatives)
    {
        register_native("ShopPushItem",                 "NativeHandle_PushItem");
        register_native("ShopDestroyItem",              "NativeHandle_DestroyItem");
        register_native("ShopGetItemInfo",              "NativeHandle_GetItemInfo");
        register_native("ShopSetItemInfo",              "NativeHandle_SetItemInfo");
        register_native("ShopGetItemFlags",             "NativeHandle_GetItemFlags");
        register_native("ShopFindItemByKey",            "NativeHandle_FindItemByKey");
    }

    // (PlayerNatives)
    {
        register_native("ShopHasUserItem",              "NativeHandle_HasUserItem");
        register_native("ShopRemoveUserItem",           "NativeHandle_RemoveUserItem");
        register_native("ShopClearUserInventory",       "NativeHandle_ClearUserInventory");
    }

    // (Placeholders)
    {
        register_native("ShopSetPlaceholderInt",        "NativeHandle_SetPlaceholderInt");
        register_native("ShopSetPlaceholderFloat",      "NativeHandle_SetPlaceholderFloat");
        register_native("ShopSetPlaceholderString",     "NativeHandle_SetPlaceholderString");
    }
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
    enum { param_name = 1, param_cost, param_access, param_flags, param_discount, param_inventory, param_key };

    new sItemData[ItemProperties];

    if (!get_string(param_name, sItemData[ItemName], charsmax(sItemData[ItemName]))) {
        log_error(AMX_ERR_NATIVE, "%s Item name can't be empty.", LOG_PREFIX);
        return INVALID_HANDLE;
    }

    sItemData[ItemPlugin]       = amxx;
    sItemData[ItemCost]         = get_param(param_cost);
    sItemData[ItemAccess]       = get_param(param_access);
    sItemData[ItemDiscount]     = get_param(param_discount);
    sItemData[ItemFlags]        = ItemFlag: get_param(param_flags);
    sItemData[ItemInventory]    = bool: get_param(param_inventory);

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

    new const iItem = get_param(param_item);
    ArrayDeleteItem(g_pItemsVec, iItem);

    new sPlayers[MAX_PLAYERS], iPlayers;
    get_players(sPlayers, iPlayers, "dh");

    for (new i; i < iPlayers; i++) {
        TrieDeleteKey(g_sPlayerData[sPlayers[i]][PlayerItemData], fmt("%i", iItem));
    }
}

public bool: NativeHandle_GetItemInfo(amxx)
{
    enum { param_player = 1, param_item, param_namebuffer, param_namelen, param_cost, param_costwithdiscount, param_discount, param_access, param_keybuffer, param_keylen };

    new const iPlayer = get_param(param_player), iItem = get_param(param_item);

    if (iPlayer) {
        CHECK_PLAYER(iPlayer)
    }
    
    new sItemData[ItemProperties];
    if (!GetItemData(iPlayer, iItem, sItemData)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, iItem);
        return false;
    }

    new const iCost = sItemData[ItemDiscount] && get_param(param_costwithdiscount) ? GET_COST_WITH_DISCOUNT(sItemData[ItemCost], sItemData[ItemDiscount]) : sItemData[ItemCost];
    set_string(param_namebuffer,    sItemData[ItemName],    get_param(param_namelen));
    set_param_byref(param_cost,     iCost);
    set_param_byref(param_discount, sItemData[ItemDiscount]);
    set_param_byref(param_access,   sItemData[ItemAccess]);
    set_string(param_keybuffer,     sItemData[ItemStrKey],  get_param(param_keylen));

    return true;
}

public bool: NativeHandle_SetItemInfo(amxx, params)
{
    enum { param_player = 1, param_item, param_prop, param_value, param_vargs };

    new const iPlayer = get_param(param_player), iItem = get_param(param_item);

    if (iPlayer) {
        CHECK_PLAYER(iPlayer)

        !g_sPlayerData[iPlayer][PlayerItemData] && (g_sPlayerData[iPlayer][PlayerItemData] = TrieCreate());
    }

    new sItemData[ItemProperties];
    if (!GetItemData(iPlayer, iItem, sItemData)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, iItem);
        return false;
    }

    if (params < param_value) {
        log_error(AMX_ERR_NATIVE, "%s Missing new value", LOG_PREFIX);
        return false;
    }

    if (!GetModifiedItemData(param_prop, param_value, param_vargs, sItemData)) {
        return false;
    }

    new bool: bSuccess;
    !iPlayer && (bSuccess = bool: ArraySetArray(g_pItemsVec, iItem, sItemData));
    iPlayer && (bSuccess = bool: TrieSetArray(g_sPlayerData[iPlayer][PlayerItemData], fmt("%i", iItem), sItemData, ItemProperties));

    return bSuccess;
}

public ItemFlag: NativeHandle_GetItemFlags(amxx)
{
    enum { param_player = 1, param_item, param_buffer };

    new const iPlayer = get_param(param_player), iItem = get_param(param_item);

    if (iPlayer) {
        CHECK_PLAYER(iPlayer)
    }

    new sItemData[ItemProperties];
    if (!GetItemData(iPlayer, iItem, sItemData)) {
        log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, iItem);
        return IF_None;
    }

    set_param_byref(param_buffer, any: sItemData[ItemFlags]);
    return sItemData[ItemFlags];
}

public NativeHandle_FindItemByKey(amxx)
{
    enum { param_key = 1 };

    new szStringKey[32];
    get_string(param_key, szStringKey, charsmax(szStringKey));

    return ArrayFindString(g_pItemsVec, szStringKey);
}

public bool: NativeHandle_HasUserItem(amxx)
{
    enum { param_player = 1, param_item };

    new const iPlayer = get_param(param_player);

    CHECK_PLAYER(iPlayer)
    
    return FindItemInInventory(iPlayer, get_param(param_item)) > INVALID_HANDLE;
}

public bool: NativeHandle_RemoveUserItem(amxx)
{
    enum { param_player = 1, param_item };

    new const iPlayer = get_param(param_player);

    CHECK_PLAYER(iPlayer)

    new const iFindItem = FindItemInInventory(iPlayer, get_param(param_item));

    if (iFindItem <= INVALID_HANDLE) {
        return false;
    }

    ArrayDeleteItem(g_sPlayerData[iPlayer][PlayerInventory], iFindItem);
    return true;
}

public NativeHandle_ClearUserInventory(amxx, params)
{
    enum { param_player = 1, param_except };

    new const iPlayer = get_param(param_player);

    CHECK_PLAYER(iPlayer)

    if (params < param_except) {
        ArrayClear(g_sPlayerData[iPlayer][PlayerInventory]);
    }
    else {
        new Array: iArrayCopy = ArrayCreate(), bool: bFind, iItem;
        for (new i = param_except; i <= params; i++) {
            iItem = get_param_byref(i);

            if (FindItemInInventory(iPlayer, iItem) == INVALID_HANDLE) {
                log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i, param #%i). Item not found in player inventory.", LOG_PREFIX, iItem, i);
                return false;
            }

            bFind = true;
            ArrayPushCell(iArrayCopy, iItem);
        }

        ArrayDestroy(g_sPlayerData[iPlayer][PlayerInventory]);

        if (bFind) {
            g_sPlayerData[iPlayer][PlayerInventory] = iArrayCopy;
            return true;
        }

        ArrayDestroy(iArrayCopy);
    }

    return true;
}

public NativeHandle_SetPlaceholderInt(amxx)
{
    enum { param_placeholder = 1, param_value }

    new szPlaceholder[SHOP_MAX_PLACEHOLDER_LENGTH];
    if (!get_string(param_placeholder, szPlaceholder, charsmax(szPlaceholder))) {
        return PLUGIN_CONTINUE;
    }

    return TrieSetString(g_pPlaceholdersAssoc, fmt(":%s", szPlaceholder), fmt("%s", get_param(param_value)));
}

public NativeHandle_SetPlaceholderFloat(amxx)
{
    enum { param_placeholder = 1, param_value }

    new szPlaceholder[SHOP_MAX_PLACEHOLDER_LENGTH];
    if (!get_string(param_placeholder, szPlaceholder, charsmax(szPlaceholder))) {
        return PLUGIN_CONTINUE;
    }

    return TrieSetString(g_pPlaceholdersAssoc, fmt(":%s", szPlaceholder), fmt("%d", get_param_f(param_value)));
}

public NativeHandle_SetPlaceholderString(amxx)
{
    enum { param_placeholder = 1, param_value, param_vargs }

    new szPlaceholder[SHOP_MAX_PLACEHOLDER_LENGTH], szValue[SHOP_MAX_PLACEHOLDER_VAL_LENGTH];
    if (!get_string(param_placeholder, szPlaceholder, charsmax(szPlaceholder)) || !vdformat(szValue, charsmax(szValue), param_value, param_vargs)) {
        return PLUGIN_CONTINUE;
    }

    return TrieSetString(g_pPlaceholdersAssoc, fmt(":%s", szPlaceholder), fmt("%s", szValue));
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

stock bool: ToggleState(const forwardid, const bool: forwardstate)
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

stock FindItemInInventory(const player, const item)
{
    new const Array: pInventory = g_sPlayerData[player][PlayerInventory];

    if (!pInventory) {
        return INVALID_HANDLE;
    }

    return ArrayFindValue(pInventory, item);
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

stock RemoveColorSymbols(buffer[])
{
    replace_all(buffer, SHOP_MAX_ITEM_NAME_LENGTH - 1, "\\w", "");
    replace_all(buffer, SHOP_MAX_ITEM_NAME_LENGTH - 1, "\\y", "");
    replace_all(buffer, SHOP_MAX_ITEM_NAME_LENGTH - 1, "\\r", "");
    replace_all(buffer, SHOP_MAX_ITEM_NAME_LENGTH - 1, "\\d", "");
}

stock GetItemData(player, item, buffer[ItemProperties])
{
    new bool: bSuccess;
    player && g_sPlayerData[player][PlayerItemData] && (bSuccess = TrieGetArray(g_sPlayerData[player][PlayerItemData], fmt("%i", item), buffer, ItemProperties));
    !bSuccess && (bSuccess = bool: ArrayGetArray(g_pItemsVec, item, buffer, ItemProperties));

    return bSuccess;
}

stock GetModifiedItemData(param_prop, param_value, param_vargs, buffer[])
{
    new iProp = get_param(param_prop);

    switch (iProp) {
        case Item_Name, Item_Strkey: {
            /* Enumerations ItemProperties and ItemProp differ in numbering. This line calculates the difference to get the desired result. */
            iProp = (iProp == any: Item_Name ? SHOP_MAX_KEY_LENGTH : 0);
            if (!vdformat(buffer[iProp], (iProp == any: ItemName ? SHOP_MAX_ITEM_NAME_LENGTH : SHOP_MAX_KEY_LENGTH) - 1, param_value, param_vargs)) {
                log_error(AMX_ERR_NATIVE, "%s New value cannot be empty", LOG_PREFIX);
                return false;
            }
        }

        case Item_Cost..Item_Inventory: {
            /* Enumerations ItemProperties and ItemProp differ in numbering. This line calculates the difference to get the desired result. */
            iProp += any: ItemCost - Item_Cost;
            buffer[iProp] = get_param_byref(param_value);
        }

        default: {
            log_error(AMX_ERR_NATIVE, "%s This property does not exist", LOG_PREFIX);
            return false;
        }
    }

    return true;
}

/**************** END UTILS ****************/

/**************** MENU SYSTEM **************/

stock Array: CreateMenuItemsStorage()
{
    return ArrayCreate();
}

stock MenuPushItem(player, item)
{
    ArrayPushCell(g_sPlayerData[player][PlayerCurrentMenu], item);
}

#define DisableItem(%0,%1,%2) %0    &= ~(1 << %1); RemoveColorSymbols(%2)
stock MenuDisplay(const player, page)
{
    if (page < 0) {
        return;
    }

    new szMenu[512], bitsKeys = MENU_KEY_0, iStart, iEnd, iCost,
    iIter, iPages, iItem, iItems = ArraySize(g_sPlayerData[player][PlayerCurrentMenu]), sItemData[ItemProperties],
    iItemsOnPage = iItems > ITEMS_ON_PAGE_WITHOUT_PAGINATOR ? ITEMS_ON_PAGE_WITH_PAGINATOR : ITEMS_ON_PAGE_WITHOUT_PAGINATOR;
    
    if ((iStart = page * iItemsOnPage) >= iItems) {
        iStart = page = g_sPlayerData[player][PlayerCurrentPage] = 0;
    }

    if ((iEnd = iStart + iItemsOnPage) > iItems) {
        iEnd = iItems;
    }

    GetLocalizeTitle(szMenu, charsmax(szMenu), player, cs_get_user_money(player));

    if ((iPages = iItems / iItemsOnPage + (iItems % iItemsOnPage ? 1 : 0)) > 1) {
        add(szMenu, charsmax(szMenu), fmt("\\R%i/%i", page + 1, iPages));
    }

    add(szMenu, charsmax(szMenu), "\n\n");

    !iItems && add(szMenu, charsmax(szMenu), fmt("%L", player, "SHOP_NO_AVAILABLE_ITEMS"));

    while (iStart < iEnd) {
        GetItemData(player, iItem = ArrayGetCell(g_sPlayerData[player][PlayerCurrentMenu], iStart++), sItemData);

        iCost = sItemData[ItemDiscount] ? GET_COST_WITH_DISCOUNT(sItemData[ItemCost], sItemData[ItemDiscount]) : sItemData[ItemCost];

        if (~get_user_flags(player) & sItemData[ItemAccess]) {
            DisableItem(bitsKeys, iIter, sItemData[ItemName]);
            add(szMenu, charsmax(szMenu), fmt("\\d[%i] %s \\r *\n", iIter + 1, sItemData[ItemName]));
        }
        else if (sItemData[ItemInventory] && FindItemInInventory(player, iItem) > INVALID_HANDLE) {
            DisableItem(bitsKeys, iIter, sItemData[ItemName]);
            add(szMenu, charsmax(szMenu), fmt("\\d[%i] %s \\r [+]\n", iIter + 1, sItemData[ItemName]));
        }
        else if (!ExecuteEventsHandle(Shop_ItemEnablePressing, false, player, iItem) || !ExecuteEventsHandle(Shop_ItemEnablePressing, true, player, iItem)) {
            DisableItem(bitsKeys, iIter, sItemData[ItemName]);
            !sItemData[ItemDiscount] && add(szMenu, charsmax(szMenu), fmt("\\d[%i] %s \\R$%i\n", iIter + 1, sItemData[ItemName], iCost));
            sItemData[ItemDiscount] && add(szMenu, charsmax(szMenu), fmt("\\d[%i] %s \\R(-%i%%) $%i\n", iIter + 1, sItemData[ItemName], sItemData[ItemDiscount], iCost));
        }
        else {
            bitsKeys |= (1 << iIter); // EnableItem
            !sItemData[ItemDiscount] && add(szMenu, charsmax(szMenu), fmt("\\y[\\r%i\\y] \\w%s\\w \\R$%i\n", iIter + 1, sItemData[ItemName], iCost));
            sItemData[ItemDiscount] && add(szMenu, charsmax(szMenu), fmt("\\y[\\r%i\\y] \\w%s \\y\\R(-%i%%) \\w$%i\n", iIter + 1, sItemData[ItemName], sItemData[ItemDiscount], iCost));
        }

        iStart == iEnd && add(szMenu, charsmax(szMenu), "\n");

        g_sPlayerData[player][PlayerSelectItem][iIter++] = iItem;
    }

    if (iItems > iItemsOnPage) {
        page ? (bitsKeys |= MENU_KEY_8) : (bitsKeys &= ~MENU_KEY_8);
        add(szMenu, charsmax(szMenu), fmt("%s %L\n", page ? "\\y[\\r8\\y]\\w" : "\\d[8]", player, "SHOP_BACK_MENU"));
        iEnd < iItems ? (bitsKeys |= MENU_KEY_9) : (bitsKeys &= ~MENU_KEY_9);
        add(szMenu, charsmax(szMenu), fmt("%s %L\n", iEnd < iItems ? "\\y[\\r9\\y]\\w" : "\\d[9]", player, "SHOP_NEXT_MENU"));
    }

    add(szMenu, charsmax(szMenu), fmt("%s\\y[\\r0\\y]\\w %L", iPages > 1 ? "" : "\n\n", player, "SHOP_EXIT_MENU"));

    show_menu(player, bitsKeys, szMenu, -1, "SHOP_API_MENU");
}

stock GetLocalizeTitle(string[], const len, const player, const money)
{
    new szName[MAX_NAME_LENGTH];
    get_user_name(player, szName, charsmax(szName));

    copy(string, len, fmt("%L", player, "SHOP_MENU_TITLE"));
    replace_stringex(string, len, ":name", fmt("%s", szName), .caseSensitive = false);
    replace_stringex(string, len, ":money", fmt("%i", money), .caseSensitive = false);

    new szPlaceholder[SHOP_MAX_PLACEHOLDER_LENGTH], szValue[SHOP_MAX_PLACEHOLDER_VAL_LENGTH],
    TrieIter: pPlaceholder = TrieIterCreate(g_pPlaceholdersAssoc);
    while (!TrieIterEnded(pPlaceholder)) {
        if (TrieIterGetKey(pPlaceholder, szPlaceholder, charsmax(szPlaceholder)) && TrieIterGetString(pPlaceholder, szValue, charsmax(szValue))) {
            replace_stringex(string, len, szPlaceholder, szValue, .caseSensitive = false);
        }

        TrieIterNext(pPlaceholder);
    }

    TrieIterDestroy(pPlaceholder);
}

stock MenuDestroy(player)
{
    ArrayDestroy(g_sPlayerData[player][PlayerCurrentMenu]);
}

/**************** END MENU SYSTEM **********/