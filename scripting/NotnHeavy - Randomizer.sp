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

#include <tf_econ_data>
#include <weapon_manager>

#define PLUGIN_NAME "NotnHeavy - Randomizer"

//////////////////////////////////////////////////////////////////////////////
// PLUGIN INFO                                                              //
//////////////////////////////////////////////////////////////////////////////

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = "NotnHeavy",
    description = "Yet another TF2 randomizer plugin which takes advantage of my Weapon Manager plugin!",
    version = "1.0",
    url = "none"
};

//////////////////////////////////////////////////////////////////////////////
// OSTYPE                                                                   //
//////////////////////////////////////////////////////////////////////////////

enum OSType
{
    OSTYPE_WINDOWS,
    OSTYPE_LINUX
};
static OSType g_eOS;

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

static Handle SDKCall_CTFWearableDemoShield_DoSpecialAction;

static DynamicDetour DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed;

static int CUtlVector_m_Size;

static any CTFPlayerShared_UpdateChargeMeter_ClassCheck;
static int CTFPlayerShared_UpdateChargeMeter_OldBuffer[6];

static ConVar tf_max_charge_speed;

static int g_PlayerShield[MAXPLAYERS + 1];

static Handle sync;

//////////////////////////////////////////////////////////////////////////////
// INITIALISATION                                                           //
//////////////////////////////////////////////////////////////////////////////

public void OnPluginStart()
{
    // Load translations file for SM errors.
    LoadTranslations("common.phrases");

    // Load gamedata.
    GameData config = LoadGameConfigFile(PLUGIN_NAME);
    if (!config)
        SetFailState("Failed to load gamedata from \"%s\".", PLUGIN_NAME);

    // Set up SDKCalls.
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(config, SDKConf_Signature, "CTFWearableDemoShield::DoSpecialAction()");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    SDKCall_CTFWearableDemoShield_DoSpecialAction = EndPrepSDKCall();

    // Set up detours.
    DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed = DynamicDetour.FromConf(config, "CTFPlayer::TeamFortress_CalculateMaxSpeed()");
    DHooks_CTFPlayer_TeamFortress_CalculateMaxSpeed.Enable(Hook_Pre, CTFPlayer_TeamFortress_CalculateMaxSpeed);

    // Set offsets.
    CUtlVector_m_Size = config.GetOffset("CUtlVector::m_Size");

    // Get the OS type.
    g_eOS = view_as<OSType>(config.GetOffset("OSType"));

    // Patch CTFPlayerShared::UpdateChargeMeter() so that no class checks take place.
    any address = config.GetMemSig("CTFPlayerShared::UpdateChargeMeter()");
    address += config.GetOffset("CTFPlayerShared::UpdateChargeMeter()::ClassCheck");
    if (g_eOS == OSTYPE_WINDOWS)
    {
        // Just NOP the JZ instruction on Windows.
        for (int i = 0; i < 6; ++i)
        {
            CTFPlayerShared_UpdateChargeMeter_OldBuffer[i] = LoadFromAddress(address + i, NumberType_Int8);
            StoreToAddress(address + i, 0x90, NumberType_Int8);
        }
    }
    else
    {
        // For some reason Linux is a lot more complicated.
        // Change the CALL instruction to a MOV EAX, 1 and cache the remaining byte.
        static char MOV_EAX_1[] = "\xB8\x01\x00\x00\x00";
        for (int i = 0; i < sizeof(MOV_EAX_1) - 1; ++i)
        {
            CTFPlayerShared_UpdateChargeMeter_OldBuffer[i] = LoadFromAddress(address + i, NumberType_Int8);
            StoreToAddress(address + i, MOV_EAX_1[i], NumberType_Int8);
        }
        CTFPlayerShared_UpdateChargeMeter_OldBuffer[5] = LoadFromAddress(address + 5, NumberType_Int8);
    }
    CTFPlayerShared_UpdateChargeMeter_ClassCheck = address;

    // Delete the gamedata handle.
    delete config;

    // Call OnClientPutInServer().
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
            OnClientPutInServer(i);
    }

    // Set up ConVars.
    tf_max_charge_speed = FindConVar("tf_max_charge_speed");

    // Set up the HUD text synchroniser.
    sync = CreateHudSynchronizer();

    // Print to server.
    PrintToServer("--------------------------------------------------------\n\"%s\" has loaded.\n--------------------------------------------------------", PLUGIN_NAME);
}

public void OnAllPluginsLoaded()
{
    OnLoadDefinitions();
}

public void OnPluginEnd()
{
    // Revert the CTFPlayerShared::UpdateChargeMeter() patch.
    for (int i = 0; i < sizeof(CTFPlayerShared_UpdateChargeMeter_OldBuffer); ++i)
        StoreToAddress(CTFPlayerShared_UpdateChargeMeter_ClassCheck, CTFPlayerShared_UpdateChargeMeter_OldBuffer[i], NumberType_Int8);
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

public void OnClientPutInServer(int client)
{
    g_PlayerShield[client] = INVALID_ENT_REFERENCE;
}

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

// Find out whether the user has a shield or not.
public void WeaponManager_OnLoadoutConstructionPost(int client, bool spawn)
{
    // Walk through their wearables to see if they have a shield.
    any m_hMyWearables = view_as<any>(GetEntityAddress(client)) + FindSendPropInfo("CTFPlayer", "m_hMyWearables");
    for (int index = 0, size = LoadFromAddress(m_hMyWearables + CUtlVector_m_Size, NumberType_Int32); index < size; ++index)
    {
        // Get the wearable.
        int handle = LoadFromAddress(LoadFromAddress(m_hMyWearables, NumberType_Int32) + index * 4, NumberType_Int32);
        int wearable = EntRefToEntIndex(handle | (1 << 31));
        if (wearable == INVALID_ENT_REFERENCE)
            continue;

        // Check if the wearable is about to be removed.
        if (GetEntityFlags(wearable) & FL_KILLME)
            continue;
        
        // Check if this is a shield.
        char classname[64];
        GetEntityClassname(wearable, classname, sizeof(classname));
        if (strcmp(classname, "tf_wearable_demoshield") != 0)
            continue;

        // Store a reference to the shield.
        g_PlayerShield[client] = EntIndexToEntRef(wearable);

        // Finish.
        break;
    }
}

// Walk through the player's actions and check if they are using their attack3 bind.
// If so, check if they have a shield and trigger its charge mechanism.
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    // Is the player holding their attack3 bind?
    if (buttons & IN_ATTACK3 && IsPlayerAlive(client) && IsValidEntity(g_PlayerShield[client]))
        SDKCall(SDKCall_CTFWearableDemoShield_DoSpecialAction, g_PlayerShield[client], client);
    return Plugin_Continue;
}

// If the player has a shield and they are not Demoman, show their charge.
public void OnGameFrame()
{
    // Walk through each client.
    for (int i = 1; i <= MaxClients; ++i)
    {
        // Check if the client is in-game and that they have a shield.
        if (IsClientInGame(i) && TF2_GetPlayerClass(i) != TFClass_DemoMan && IsValidEntity(g_PlayerShield[i]))
        {
            // Get the player's charge meter and display it.
            float charge = GetEntPropFloat(i, Prop_Send, "m_flChargeMeter");
            SetHudTextParams(0.05, 0.05, 0.5, 255, 255, 255, 0, 0, 6.0, 0.0, 0.0);
            ShowSyncHudText(i, sync, "Recharge: %i%", RoundToFloor(charge));
        }
    }
}

//////////////////////////////////////////////////////////////////////////////
// DHOOKS                                                                   //
//////////////////////////////////////////////////////////////////////////////

// Pre-call CTFPlayer::TeamFortress_CalculateMaxSpeed().
// If the player is charging and they are not a Demoman, set their speed to be the
// max charge speed.
static MRESReturn CTFPlayer_TeamFortress_CalculateMaxSpeed(int client, DHookReturn returnValue, DHookParam parameters)
{
    if (IsClientInGame(client) && TF2_GetPlayerClass(client) != TFClass_DemoMan && TF2_IsPlayerInCondition(client, TFCond_Charging))
    {
        returnValue.Value = tf_max_charge_speed.FloatValue;
        return MRES_Supercede;
    }
    return MRES_Ignored;
}