#if defined _shopapi_included
    #endinput
#endif
#define _shopapi_included

#include <shopapi_version>
#include <shopapi_const>

enum
{
    SHOP_HANDLED = 1,   // skip real function
    SHOP_CONTINUE,      // take no action
    SHOP_BREAK          // skip all other forwards and real function
};

enum ShopEvent
{
    INVALID_SHOPEVENT = -1
};

enum ShopItem
{
    INVALID_SHOPITEM = -1
};

/**
* Registers an event
*
* @param func           The function to hook
* @param handle         The forward to call
* @param this           Only for items created by the current plugin
*
* @return               Returns a event handle. Use ShopDisableEvent/ShopEnableEvent to toggle the forward
*/
native ShopEvent: ShopRegisterEvent(const ShopFunc: func, const handle[], const bool: this = true);


/**
* Registers an event for single item
*
* @param func           The function to hook
* @param item           Item id
* @param handle         The forward to call
*
* @return               Returns a event handle. Use ShopDisableEvent/ShopEnableEvent to toggle the forward
*/
native ShopEvent: ShopRegisterEventFromItem(const ShopFunc: func, const ShopItem: item, const handle[]);

/**
* Enable calling a function when an event is triggered.
*
* @param event          The event to enable
*
*/
native bool: ShopEnableEvent(ShopEvent: event);

/**
* Disable calling a function when an event is triggered.
*
* @param event          The event to disable
*
*/
native bool: ShopDisableEvent(ShopEvent: event);

/**
* Creating a new item.
*
* @param name           Item name
* @param cost           Item cost
* @param access         Item access
* @param flags          Item flags
* @param discounts      Enable discounts for this item
* @param inventory      Save item in inventory
* @param strkey         Unique key to search for the item
*
* @return               Index of the new item
* @error                -1 if creation failed
*/
native ShopItem: ShopPushItem(const name[], const cost, const access = ADMIN_USER, const ItemFlag: flags = IF_None, const bool: discounts = true, const bool: inventory = false, const strkey[32] = "");

/**
* Delete item.
*
* @param name           Item id
*
* @noreturn
*/
native ShopDestroyItem(const ShopItem: item);

/**
* Retrieves info about a item.
*
* @param name           Item id
* @param cost           Item cost
* @param name           Item name buffer
* @param namelen        Item name buffer len
* @param strkey         Item string key buffer
* @param keylen         Item string key buffer len
*
* @return               Item exists (true/false)
*/
native bool: ShopGetItemInfo(const ShopItem: item, const name[] = "", const namelen = 0, const &cost = 0, const &access = 0, const strkey[] = "", const keylen = 0);

/**
 * Get item flags.
 *
 * @param item          Item id
 * @param flags         Variable to store flags to
 *
 * @return              Item flags or always IF_None flag
 */
 native ItemFlag: ShopGetItemFlags(const ShopItem: item, &flags = 0);

/**
 * Find item by string key.
 *
 * @param strkey
 *
 * @return              Item id
 * @error               -1 if can't find
 */
native ShopItem: ShopFindItemByKey(strkey[32]);