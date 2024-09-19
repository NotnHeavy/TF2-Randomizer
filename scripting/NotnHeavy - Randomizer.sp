//////////////////////////////////////////////////////////////////////////////
// MADE BY NOTNHEAVY. USES GPL-3, AS PER REQUEST OF SOURCEMOD               //
//////////////////////////////////////////////////////////////////////////////

// This uses my Weapon Manager plugin:
// https://github.com/NotnHeavy/TF2-Weapon-Manager

// This also uses nosoop's TF2 Econ Data plugin:
// https://github.com/nosoop/SM-TFEconData

#pragma semicolon true 
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#include <third_party/tf_econ_data>
#include <third_party/weapon_manager>

#define PLUGIN_NAME "NotnHeavy - Randomizer"

//////////////////////////////////////////////////////////////////////////////
// PLUGIN INFO                                                              //
//////////////////////////////////////////////////////////////////////////////

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "NotnHeavy",
    description = "Yet another TF2 randomizer plugin which takes advantage of my Weapon Manager plugin!",
    version = "1.0.1",
    url = "none"
};

//////////////////////////////////////////////////////////////////////////////
// GLOBALS                                                                  //
//////////////////////////////////////////////////////////////////////////////

enum struct allowed_t
{
    StringMap map;
    StringMapSnapshot snapshot;
}
static allowed_t g_AllowedNames[view_as<int>(TFClass_Engineer) + 1][WEAPONS_LENGTH];

static StringMap g_Definitions;
static StringMapSnapshot g_DefinitionsSnapshot;

//////////////////////////////////////////////////////////////////////////////
// INITIALISATION                                                           //
//////////////////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
    // Load translations file for SM errors.
    LoadTranslations("common.phrases");

    // Print to server.
    PrintToServer("--------------------------------------------------------\n\"%s\" has loaded.\n--------------------------------------------------------", PLUGIN_NAME);
}

public void OnAllPluginsLoaded()
{
    OnLoadDefinitions();
}

//////////////////////////////////////////////////////////////////////////////
// WEAPON DEFINITION MANIPULATION                                           //
//////////////////////////////////////////////////////////////////////////////

static void OnLoadDefinitions()
{
    // Skip if not ready.
    if (!WeaponManager_IsPluginReady())
        return;

    // Get the default definition lists.
    g_Definitions = WeaponManager_GetDefinitions();
    g_DefinitionsSnapshot = g_Definitions.Snapshot();

    // Reset each StringMap.
    for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; ++class)
    {
        for (int i = 0; i < WEAPONS_LENGTH; ++i)
        {
            delete g_AllowedNames[class][i].map;
            delete g_AllowedNames[class][i].snapshot;
            g_AllowedNames[class][i].map = new StringMap();
        }
    }

    // Walk through each definition and modify their slot information.
    for (int i = 0, size = g_DefinitionsSnapshot.Length; i < size; ++i)
    {
        // Get the definition.
        definition_t def;
        char buffer[64];
        g_DefinitionsSnapshot.GetKey(i, buffer, sizeof(buffer));
        g_Definitions.GetArray(buffer, def, sizeof(def));

        // Skip if this definition does not have a valid item definition index.
        if (def.m_iItemDef == TF_ITEMDEF_DEFAULT)
            continue;

        // SKip if this definition is CWX.
        if (strlen(def.m_szCWXUID) > 0)
            continue;
        
        // Skip if this definition is a wearable.
        if (TF2Econ_GetItemDefaultLoadoutSlot(def.m_iItemDef) == 8)
            continue;

        // Modify this definition to be available for every single slot.
        for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; ++class)
        {
            // Set the slot.
            for (int slot = 0; slot < ((class == TFClass_Spy || class == TFClass_Engineer) ? WEAPONS_LENGTH : 3); ++slot)
            {
                // If this is Spy, don't really bother with the sapper/PDA slots.
                if ((class == TFClass_Spy && (slot == 1 || slot == 3 || slot == 4) && TF2Econ_GetItemLoadoutSlot(def.m_iItemDef, class) != LoadoutToTF2(slot, class)))
                {
                    def.SetSlot(class, LoadoutToTF2(slot, class), false);
                    g_AllowedNames[class][slot].map.Remove(def.m_szName);
                }
                else
                {
                    def.SetSlot(class, LoadoutToTF2(slot, class), true);
                    g_AllowedNames[class][slot].map.SetValue(def.m_szName, true);

                    // Check for things like medieval mode.
                    if (!WeaponManager_MedievalMode_DefinitionAllowedByItemDef(def.m_iItemDef, class))
                    {
                        def.SetSlot(class, LoadoutToTF2(slot, class), false);
                        g_AllowedNames[class][slot].map.Remove(def.m_szName);
                        continue;
                    }

                    // Block sappers and PDAs if they're outside their actual slots.
                    if ((slot != 1 && class != TFClass_Spy && strcmp(def.m_szClassName, "tf_weapon_sapper") == 0)
                        || (slot != 1 && class != TFClass_Spy && strcmp(def.m_szClassName, "tf_weapon_builder") == 0)
                        || (slot != 3 && class != TFClass_Engineer && strcmp(def.m_szClassName, "tf_weapon_pda_engineer_build") == 0)
                        || (slot != 4 && class != TFClass_Engineer && strcmp(def.m_szClassName, "tf_weapon_pda_engineer_destroy") == 0))
                    {
                        def.SetSlot(class, LoadoutToTF2(slot, class), false);
                        g_AllowedNames[class][slot].map.Remove(def.m_szName);
                        continue;
                    }
                }
            }
        }

        // Place it back into our string map.
        def.m_bSave = true;
        g_Definitions.SetArray(buffer, def, sizeof(def));
        
        // Cache each snapshot.
        for (TFClassType class = TFClass_Scout; class <= TFClass_Engineer; ++class)
        {
            for (int slot = 0; slot < WEAPONS_LENGTH; ++slot)
                g_AllowedNames[class][slot].snapshot = g_AllowedNames[class][slot].map.Snapshot();
        }
    }

    // Emplace the new definitions list back on Weapon Manager's side.
    g_DefinitionsSnapshot = g_Definitions.Snapshot();
    WeaponManager_SetDefinitions(g_Definitions);
    PrintToServer("[NotnHeavy - Randomizer]: Emplaced new definitions list successfully!");
}

//////////////////////////////////////////////////////////////////////////////
// FORWARDS                                                                 //
//////////////////////////////////////////////////////////////////////////////

// Weapon Manager has just parsed its definitions.
public void WeaponManager_OnDefinitionsLoaded(bool pluginstart)
{
    OnLoadDefinitions();
}

// Randomize a player's loadout if they have just spawned.
public Action WeaponManager_OnLoadoutConstruction(int client, bool spawn)
{
    // Skip if the player has already spawned.
    if (!spawn)
        return Plugin_Continue;

    // Go through each slot.
    // The code is designed like this in the case that this plugin loops thousands
    // of times, otherwise there will be heap/stack overflows.
    //
    // Maybe in the future I should split g_Definitions in the Weapon Manager
    // plugin to g_WeaponDefinitions and g_WearableDefinitions.
    TFClassType class = TF2_GetPlayerClass(client);
    int limit = ((class == TFClass_Spy || class == TFClass_Engineer) ? 5 : 3);
    for (int i = 0; i < limit; ++i)
    {
        // Skip this slot if there is nothing to equip.
        if (!g_AllowedNames[class][i].snapshot || g_AllowedNames[class][i].snapshot.Length == 0)
            continue;

        // Randomly pick a definition from g_DefinitionsSnapshot that supports at least one class as a weapon.
        definition_t def;
        char buffer[64];
        int index = GetRandomInt(0, g_AllowedNames[class][i].snapshot.Length - 1);
        g_AllowedNames[class][i].snapshot.GetKey(index, buffer, sizeof(buffer));
        g_Definitions.GetArray(buffer, def, sizeof(def));

        // Finish search for this slot.
        WeaponManager_ForcePersistDefinition(client, class, i, def.m_szName);
    }

    // Continue.
    return Plugin_Continue;
}