#include <amxmodx>
#include <shopapi>

#pragma semicolon           1
#pragma ctrlchar            '\'

new const PLUGIN[] =        "Shop API";

enum any: ItemProperties
{
    ItemStrKey[64],
    ItemName[32],
    ItemPrice,
    ItemAccess,
    ItemFlags,
    bool: ItemInventory,
    bool: ItemDiscounts
};

public plugin_init()
{
    register_plugin(PLUGIN, SHOPAPI_VERSION_STR, "gamingEx");
}

/**************** API **********************/

enum any: ForwardProperties
{
    ShopFunc: ForwardFunc,
    ForwardOptionalParam,
    ForwardHandle,
    bool: ForwardDisable
};

new Array: g_pItemsVec, Array: g_pForwardsVec;
new const KEY_PREFIX[] = "SHOPITEM_", LOG_PREFIX[] = "[ShopAPI]";

public plugin_natives()
{
    g_pItemsVec     = ArrayCreate(ItemProperties);
    g_pForwardsVec  = ArrayCreate(ForwardProperties);

    register_native("ShopRegisterEvent",    "NativeHandle_RegisterEvent");
    register_native("ShopDisableEvent",     "NativeHandle_DisableEvent");
    register_native("ShopEnableEvent",      "NativeHandle_EnableEvent");

    register_native("ShopPushItem",         "NativeHandle_PushItem");
    register_native("ShopDestroyItem",      "NativeHandle_DestroyItem");
    register_native("ShopGetItemInfo",      "NativeHandle_GetItemInfo");
    register_native("ShopFindItemByKey",    "NativeHandle_FindItemByKey");
}

public NativeHandle_RegisterEvent(amxx, params)
{
    enum { param_func = 1 };

    new const ShopFunc: iFuncID = ShopFunc: get_param(param_func);
    new sForwardData[ForwardProperties], szHandle[32];

    switch (iFuncID) {
        case Shop_OpenMenu: {
            if (!GetHandle(amxx, 2, szHandle, charsmax(szHandle))) {
                return INVALID_HANDLE;
            }

            sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL);
        }
        case Shop_ItemsBuy: {
            if (!GetHandle(amxx, 2, szHandle, charsmax(szHandle))) {
                return INVALID_HANDLE;
            }

            sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL, FP_CELL, FP_CELL);
        }

        case Shop_ItemBuy: {
            if (0 > (sForwardData[ForwardOptionalParam] = get_param(2)) >= ArraySize(g_pItemsVec)) {
                log_error(AMX_ERR_NATIVE, "%s Invalid item id (%i).", LOG_PREFIX, sForwardData[ForwardOptionalParam]);
                return INVALID_HANDLE;
            }

            if (!GetHandle(amxx, 3, szHandle, charsmax(szHandle))) {
                return INVALID_HANDLE;
            }

            sForwardData[ForwardHandle] = CreateOneForward(amxx, szHandle, FP_CELL, FP_CELL, FP_CELL);
        }

        default: {
            log_error(AMX_ERR_NATIVE, "%s Invalid function id (%i).", LOG_PREFIX, iFuncID);
            return INVALID_HANDLE;
        }
    }

    sForwardData[ForwardFunc]   = iFuncID;
    return ArrayPushArray(g_pForwardsVec, sForwardData);
}

public bool: NativeHandle_DisableEvent(amxx, params)
{
    enum { param_forward = 1 };
    return ToggleState(get_param(param_forward), false);
}

public bool: NativeHandle_EnableEvent(amxx, params)
{
    enum { param_forward = 1 };
    return ToggleState(get_param(param_forward), true);
}

public NativeHandle_PushItem(amxx, params)
{
    enum { param_name = 1, param_price, param_access, param_flags, param_discounts, param_inventory, param_key };

    new sItemData[ItemProperties];

    if (!get_string(param_name, sItemData[ItemName], charsmax(sItemData[ItemName]))) {
        log_error(AMX_ERR_NATIVE, "%s Item name can't be empty.", LOG_PREFIX);
        return INVALID_HANDLE;
    }

    sItemData[ItemPrice]        = get_param(param_price);
    sItemData[ItemAccess]       = get_param(param_access);
    sItemData[ItemFlags]        = get_param(param_flags);
    sItemData[ItemInventory]    = bool: get_param(param_inventory);
    sItemData[ItemDiscounts]    = bool: get_param(param_discounts);

    copy(sItemData[ItemStrKey], charsmax(sItemData[ItemStrKey]), KEY_PREFIX);
    if (get_string(param_key, sItemData[ItemStrKey][strlen(KEY_PREFIX)], charsmax(sItemData[ItemStrKey])) 
        && ArrayFindString(g_pItemsVec, sItemData[ItemStrKey]) != INVALID_HANDLE) {
            log_error(AMX_ERR_NATIVE, "%s The string key must be unique (\"%s\" already exists).", LOG_PREFIX, sItemData[ItemStrKey][strlen(KEY_PREFIX)]);
            return INVALID_HANDLE;
    }

    return ArrayPushArray(g_pItemsVec, sItemData);
}

public NativeHandle_DestroyItem(amxx, params)
{
    enum { param_item = 1 };
    ArrayDeleteItem(g_pItemsVec, get_param(param_item));
}

public bool: NativeHandle_GetItemInfo(amxx, params)
{
    enum { param_item = 1, param_price, param_access, param_namebuffer, param_namelen, param_keybuffer, param_keylen, param_flags };

    new sItemData[ItemProperties];
    if (!ArrayGetArray(g_pItemsVec, get_param(param_item), sItemData)) {
        log_error(AMX_ERR_NATIVE, "%s Item %i was deleted or not yet created.", LOG_PREFIX, get_param(param_item));
        return false;
    }

    set_param_byref(param_access,   sItemData[ItemAccess]);
    set_param_byref(param_price,    sItemData[ItemPrice]);
    set_param_byref(param_flags,    sItemData[ItemFlags]);
    set_string(param_namebuffer,    sItemData[ItemName],    get_param(param_namelen));
    set_string(param_keybuffer,     sItemData[ItemStrKey],  get_param(param_keylen));

    return true;
}

public NativeHandle_FindItemByKey(amxx, params)
{
    enum { param_key = 1 };

    new szStringKey[32];
    get_string(param_key, szStringKey, charsmax(szStringKey));

    return ArrayFindString(g_pItemsVec, fmt("%s%s", KEY_PREFIX, szStringKey));
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

stock bool: ExecuteForwardEx(ShopFunc: func, any: ...)
{
    new sForwardData[ForwardProperties], iIter, iResponse, bool: bState = true;
    while (iIter < ArraySize(g_pForwardsVec)) {
        ArrayGetArray(g_pForwardsVec, iIter++, sForwardData);

        if (sForwardData[ForwardDisable] || sForwardData[ForwardFunc] != func) {
            continue;
        }
        
        switch (func) {
            case Shop_OpenMenu: {
                enum { param_player = 1 }
                ExecuteForward(sForwardData[ForwardHandle], iResponse, getarg(param_player));
            }

            case Shop_ItemBuy, Shop_ItemsBuy: {
                enum { param_player = 1, param_item, param_state };
                ExecuteForward(sForwardData[ForwardHandle], iResponse, getarg(param_player), getarg(param_item), getarg(param_state));
            }
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

/**************** END UTILS ****************/