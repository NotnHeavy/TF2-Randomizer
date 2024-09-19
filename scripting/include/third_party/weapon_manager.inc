//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

#if defined NOTNHEAVY_WEAPON_MANAGER
    #endinput
#endif
#define NOTNHEAVY_WEAPON_MANAGER

#define MAX_SLOTS           9
#define NAME_LENGTH         64
#define ENTITY_NAME_LENGTH  64

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //
//////////////////////////////////////////////////////////////////////////////

#define WEAPONS_LENGTH              5
#define COSMETICS_LENGTH            3

// An individiual definition for an item definition index, for modifying its loadout status.
// This is used for raw definition modifications.
enum struct definition_t
{
    // Definition name per config.
    char m_szName[NAME_LENGTH];

    // Used to identify this definition.
    int m_iItemDef;

    // Data used to modify this definition.
    int m_ClassInformation[view_as<int>(TFClass_Engineer) + 1]; // two-dimensional enum structs still aren't possible, at least with a stable version of sourcepawn, so i'm doing a hack instead
    char m_szClassName[ENTITY_NAME_LENGTH];
    char m_szCWXUID[NAME_LENGTH];
    bool m_bDefault;                                            // Set by config.
    bool m_bActualDefault;                                      // Decided by this plugin.
    bool m_bShowInLoadout;                                      // Set by config or basic item filtering sequence.
    bool m_iAllowedInMedieval;                                  // 1 - allowed, 0 - not allowed, -1 - default to usual behaviour

    // Used to factor whether this is written to loaded config file.
    bool m_bSave;

    // Was this definition automatically configured by this plugin, rather than it being listed in a user's config file?
    bool m_bAutomaticallyConfigured;

    // Configure whether this is allowed for a specific TF2 slot on a specific class.
    void SetSlot(TFClassType class, int slot, bool enabled)
    {
        if (enabled)
            this.m_ClassInformation[view_as<int>(class)] |= (1 << slot);
        else
            this.m_ClassInformation[view_as<int>(class)] &= ~(1 << slot);
    }

    // Get whether this is allowed for a specific TF2 slot on a specific class.
    bool GetSlot(TFClassType class, int slot)
    {
        return !!(this.m_ClassInformation[view_as<int>(class)] & (1 << slot));
    }

    // Is this weapon/wearable allowed on a class?
    bool AllowedOnClass(TFClassType class)
    {
        return !!(this.m_ClassInformation[view_as<int>(class)]);
    }
}

//////////////////////////////////////////////////////////////////////////////
// SLOT CONVERSION                                                          //
//////////////////////////////////////////////////////////////////////////////

// TF2 -> Inventory methodmap
// Use this to convert a TF2 slot to the slot number you press 
// to equip a desired weapon (starting from primary - 0).
// Cosmetics must still be handled separately - they are always 8.
stock int TF2ToLoadout(int tf2slot, any class)
{
    switch (class)
    {
        case TFClass_Engineer:
        {
            switch (tf2slot)
            {
                case 5:
                    return 3;
                case 6:
                    return 4;
                default:
                    return tf2slot;
            }
        }
        case TFClass_Spy:
        {
            switch (tf2slot)
            {
                case 1:
                    return 0;
                case 2:
                    return 2;
                case 4:
                    return 1;
                case 5:
                    return 3;
                case 6:
                    return 4;
                default:
                    return tf2slot;
            }
        }
        default:
        {
            switch (tf2slot)
            {
                case 5:
                    return 3;
                case 6:
                    return 4;
                default:
                    return tf2slot;
            }
        }
    }
}

// Inventory methodmap -> TF2
// Use this to convert a slot number you press to equip a desired 
// weapon (starting from primary - 0) to a TF2 slot.
// Cosmetics must still be handled separately - they are always 8.
stock int LoadoutToTF2(int inventoryslot, any class)
{
    switch (class)
    {
        case TFClass_Engineer:
        {
            switch (inventoryslot)
            {
                case 3:
                    return 5;
                case 4:
                    return 6;
                default:
                    return inventoryslot;
            }
        }
        case TFClass_Spy:
        {
            switch (inventoryslot)
            {
                case 0:
                    return 1;
                case 1:
                    return 4;
                case 2:
                    return 2;
                case 3:
                    return 5;
                case 4:
                    return 6;
                default:
                    return inventoryslot;
            }
        }
        default:
        {
            switch (inventoryslot)
            {
                case 3:
                    return 5;
                case 4:
                    return 6;
                default:
                    return inventoryslot;
            }
        }
    }
}

//////////////////////////////////////////////////////////////////////////////
// NATIVES                                                                  //
//////////////////////////////////////////////////////////////////////////////

/**
 * Returns whether this plugin is ready or not.
 * 
 * @return  True if this plugin is ready, otherwise false.
 */
native bool WeaponManager_IsPluginReady();

/** 
 * Returns a StringMap of definitions.
 * 
 * @return  All definitions within a StringMap, or INVALID_HANDLE if null. 
 *          This must be deleted when finished.
*/
native StringMap WeaponManager_GetDefinitions();

/**
 * Updates g_Definitions on the plugin's end.
 * 
 * @param definitions   A StringMap containing all the updated definitions.
 */
native void WeaponManager_SetDefinitions(StringMap definitions);

/**
 * Writes all definitions to a config file.
 * 
 * @param cfg   The name of the config file - extension omitted. 
 *              (can be left blank to default to autoexec.cfg).
 * @return      True if succeeded in writing, otherwise false.
 */
native bool WeaponManager_Write(const char[] cfg);

/**
 * Load definitions from a config file.
 * 
 * @param cfg   The name of the config file - extension omitted.
 * @return      True if succeeded in reading, otherwise false.
 */
native bool WeaponManager_Load(const char[] cfg);

/**
 * Re-parses definitions from the currently loaded config file.
 */
native bool WeaponManager_Refresh();

/**
 * Returns the path of the current config file loaded.
 * 
 * @param buffer    The char buffer to store the string in.
 * @param maxlength The maximum length of the buffer (including
 *                  the NUL terminator).
 * @return          The number of bytes written. (UTF-8)
 */
native int WeaponManager_GetLoadedConfig(char[] buffer, int maxlength);

/**
 * Modifies the value of a key-value in the configs/weapon_manager.cfg file.
 * 
 * @param key       The key to modify.
 * @param value     The new value for the desired key.
 * 
 * @return          True if successfully written, otherwise false.
 */
native bool WeaponManager_DispatchGlobalKeyValue(const char[] key, const char[] value);

/**
 * Retrieves the value of a key-value in the configs/weapon_manager.cfg file
 * 
 * @param key       The key to read from
 * @param value     The value of the desired key.
 * @param maxlength The length of the value buffer used.
 * 
 * @return          True if successfully read, otherwise false.
 */
native bool WeaponManager_GetGlobalKeyValue(const char[] key, char[] value, int maxlength);

/**
 * Modifies the value of a key-value in the loaded definitions config file.
 * 
 * @param key       The key to modify.
 * @param value     The new value for the desired key.
 * 
 * @return          True if successfully written, otherwise false.
 */
native bool WeaponManager_DispatchConfigKeyValue(const char[] key, const char[] value);

/**
 * Retrieves the value of a key-value in the loaded definitions config file.
 * 
 * @param key       The key to read from
 * @param value     The value of the desired key.
 * @param maxlength The length of the value buffer used.
 * 
 * @return          True if successfully read, otherwise false.
 */
native bool WeaponManager_GetConfigKeyValue(const char[] key, char[] value, int maxlength);

/**
 * Find a definition_t by name.
 * 
 * @param name      The name of the definition to find.
 * @param def       The definition_t object to write to.
 * 
 * @return          True if found, otherwise false.
 */
native bool WeaponManager_FindDefinition(const char[] name, any[] def);

/**
 * Find a definition_t by item definition index.
 * 
 * @param itemdef   The item definition index of the definition to find.
 * @param def       The definition_t object to write to.
 * 
 * @return          True if found, otherwise false.
 */
native bool WeaponManager_FindDefinitionByItemDef(int itemdef, any[] def);

/**
 * Force a player to immediately equip a new weapon according to a definition
 * (by name), which will not persist after resuply (unless specified). 
 * You can choose to persist later otherwise by using 
 * WeaponManager_ForcePersistDefinition() with the matching definition.
 *
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param client    The client's entindex to use.
 * @param slot      The slot this definition should be equipped in.
 * @param name      The name of the definition to use.
 * @param persist   Whether this weapon should persist.
 * 
 * @return          True if equipped, otherwise false.
 * @error           The definition is not allowed for the class & slot combo.
 */
native bool WeaponManager_EquipDefinition(int client, int slot, const char[] name, bool persist = false);

/**
 * Force a player to equip a new weapon according to a definition (by name) 
 * after resupply. This weapon will persist until unequipped through the
 * loadout menu, or through natives.
 *
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param client    The client's entindex to use.
 * @param class     The class this definition should be equipped for.
 * @param slot      The slot this definition should be equipped in.
 * @param name      The name of the definition to use.
 * 
 * @return          True if equipped, otherwise false.
 * @error           The definition is not allowed for the class & slot combo.
 */
native bool WeaponManager_ForcePersistDefinition(int client, TFClassType class, int slot, const char[] name);

/**
 * Unequip whatever definition is in a certain slot for a certain class of a
 * specific client, meaning they will no longer have a custom weapon equipped
 * after resupply.
 *
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param client    The client's entindex to use.
 * @param class     The class to remove the definition from.
 * @param slot      The slot to remove the definition from.
 */
native void WeaponManager_RemovePersistedDefinition(int client, TFClassType class, int slot);

/**
 * Returns whether a specific definition is allowed for a certain class of a 
 * specific slot.
 * 
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param name      The definition to check
 * @param class     The class to check.
 * @param slot      The slot to check.
 * 
 * @return          True if the item definition index is allowed, otherwise false.
 */
native void WeaponManager_DefinitionAllowed(const char[] name, TFClassType class, int slot);

/**
 * Returns whether a specific item definition index is allowed for a certain class
 * of a specific slot.
 * 
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param itemdef   The item definition index to check
 * @param class     The class to check.
 * @param slot      The slot to check.
 * 
 * @return          True if the item definition index is allowed, otherwise false.
 */
native void WeaponManager_DefinitionAllowedByItemDef(int itemdef, TFClassType class, int slot);

/**
 * Retrieve the first weapon found in a specific slot.
 * 
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param client    The client's entindex to use.
 * @param slot      The slot to retrieve the weapon from.
 * 
 * @return          The first found weapon's entindex, or INVALID_ENT_REFERENCE if not found 
 *                  or client/slot is incorrect.
 */
native int WeaponManager_GetWeapon(int client, int slot);

/**
 * Retrieve a client's slot's replacement weapon.
 * 
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param client    The client's entindex to use.
 * @param slot      The slot to retrieve the weapon from.
 * 
 * @return          The first found weapon's entindex, or INVALID_ENT_REFERENCE if not found 
 *                  or client/slot is incorrect.
 */
native int WeaponManager_GetReplacementWeapon(int client, int slot);

/**
 * Retrieve a client's slot's fake slot replacement weapon. These weapons are used
 * to allow a client to equip a weapon in another slot, as they will otherwise be equipped
 * in their internal slot.
 * 
 * Use the slot corresponding to what key you typically use to equip this weapon
 * (starting from 0 for primary).
 * 
 * @param client    The client's entindex to use.
 * @param slot      The slot to retrieve the weapon from.
 * 
 * @return          The first found weapon's entindex, or INVALID_ENT_REFERENCE if not found 
 *                  or client/slot is incorrect.
 */
native int WeaponManager_GetFakeSlotReplacementWeapon(int client, int slot);

/**
 * Returns the internal TF2 slot of a weapon entity.
 * 
 * @param weapon    The weapon's entindex to use.
 * @param class     The class to use when getting the internal slot of the weapon's itemdef
 *                  (if it is not in a custom slot).
 * 
 * @return          The TF2 slot (use tf_item_constants.inc) of the weapon, or -1
 *                  (INVALID_ITEM_DEF_INDEX).
 */
native int WeaponManager_GetSlotOfWeapon(int weapon, TFClassType class);

/**
 * Returns whether a specific definition is allowed for a certain class of a 
 * specific slot for Medieval mode.
 * 
 * @param name      The definition to check
 * @param class     The class to check.
 * 
 * @return          True if the item definition index is allowed, otherwise false.
 */
native void WeaponManager_MedievalMode_DefinitionAllowed(const char[] name, TFClassType class);

/**
 * Returns whether a specific item definition index is allowed for a certain class
 * of a specific slot for Medieval mode.
 * 
 * @param itemdef   The item definition index to check
 * @param class     The class to check.
 * 
 * @return          True if the item definition index is allowed, otherwise false.
 */
native void WeaponManager_MedievalMode_DefinitionAllowedByItemDef(int itemdef, TFClassType class);

/**
 * Get the max ammo of a weapon.
 * 
 * @param weapon    The weapon to get the max ammo of.
 * 
 * @return          The max ammo of the weapon.
 */
native float WeaponManger_GetMaxAmmo(int weapon);

/**
 * Get the classname of an entity. Please use this in the WeaponManager forwards,
 * as the weapon's details are faked internally to avoid TF2 quirks.
 * 
 * @param weapon    The weapon to use.
 * @param classname The classname buffer.
 * @param maxlength The size of the classname buffer.
 */
native void WeaponManager_GetWeaponClassname(int weapon, char[] classname, int maxlength);

/**
 * Get the item definition index of an entity. Please use this in the WeaponManager 
 * forwards, as the weapon's details are faked internally to avoid TF2 quirks.
 * 
 * @param weapon    The weapon to use.
 * 
 * @return          The item definition index of the weapon.
 */
native int WeaponManager_GetWeaponItemDefinitionIndex(int weapon);

//////////////////////////////////////////////////////////////////////////////
// FORWARDS                                                                 //
//////////////////////////////////////////////////////////////////////////////

/**
 * Called when g_Definitions is reset, either on plugin start or
 * through loading a new config.
 * 
 * @param pluginstart   True if this is called when this plugin
 *                      has loaded for the first time.
 * @param mapstart      True if this is called when this map has
 *                      loaded for the first time (always true if
 *                      pluginstart is true).
 */
forward void WeaponManager_OnDefinitionsLoaded(bool pluginstart, bool mapstart);

/**
 * Called immediately before the player's loadout is reconstructed.
 * 
 * @param client        The client whose loadout is being reconstructed.
 * @param spawn         True if the player has just spawned
 * 
 * @return              If Plugin_Handled or Plugin_Stop, do not go through
 *                      loadout construction.
 */
forward Action WeaponManager_OnLoadoutConstruction(int client, bool spawn);

/**
 * Called immediately after the player's loadout is reconstructed.
 * 
 * @param client        The client whose loadout is being reconstructed.
 * @param spawn         True if the player has just spawned
 */
forward void WeaponManager_OnLoadoutConstructionPost(int client, bool spawn);

/**
 * Called a frame after a weapon is spawned and given to a player.
 * 
 * @param client        The client who has been assigned a weapon.
 * @param weapon        The weapon.
 * @param isCWX         Is this a custom weapon using CWX?
 * @param isFake        Is this a fake slot replacement entity?
 */
forward void WeaponManager_OnWeaponSpawnPost(int client, int weapon, bool isCWX, bool isFake);

/**
 * Called when retrieving the max ammo of a specific ammo type of a player.
 * 
 * @param client        The client being observed.
 * @param type          The primary ammo type.
 * @param class         The class of the player.
 * @param weapon        The weapon entity that has been calculated by 
 *                      Weapon Manager, or -1 if it failed.
 * @param maxAmmo       The max ammo.
 * 
 * @return              If Plugin_Changed, return the max ammo set by
 *                      the programmer instead.
 */
forward Action WeaponManager_OnGetMaxAmmo(int client, int type, TFClassType class, int weapon, int& maxAmmo);

//////////////////////////////////////////////////////////////////////////////
// PLUGIN INFO                                                              //
//////////////////////////////////////////////////////////////////////////////

public SharedPlugin __pl_notnheavy___attribute_manager = 
{
	name = "NotnHeavy - Weapon Manager",
	file = "NotnHeavy - Weapon Manager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};