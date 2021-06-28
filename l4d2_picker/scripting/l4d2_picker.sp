#include <sourcemod>
#include <builtinvotes>
#include <colors>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "1.0"

// L4D2Team Enum
enum L4D2_Team
{
    L4D2Team_None = 0,
    L4D2Team_Spectator,
    L4D2Team_Survivor,
    L4D2Team_Infected
}

// ConVars
ConVar survivor_limit, z_max_player_zombies;

// Variables
int iFirstPickerClient, iSecoundPickerClient, iFirstAndSecondPicker;
char cChoosePlayers[256];
bool bLeftStartArea, bIsPicking, bJoinPlayer[MAXPLAYERS+1];
Handle hVotePicker;
ArrayList alJoinPlayers;

// Plugins Available
bool bReadyUpAvailable; // readyup

public Plugin myinfo =  
{
    name = "L4D2 Vote Picker",
    author = "PaaNChaN",
    description = "select picker from the players",
    version = PLUGIN_VERSION,
    url = "https://github.com/PaaNChaN/L4D2_Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Picker_IsPicking", Native_IsPicking);
    CreateNative("Picker_IsJoinPlayer", Native_IsJoinPlayer);
    CreateNative("Picker_GetFirstAndSecondPicker", Native_GetFirstAndSecondPicker);
    RegPluginLibrary("l4d2_picker");

    MarkNativeAsOptional("IsInReady");
    return APLRes_Success;
}

public int Native_IsPicking(Handle plugin, int numParams)
{
    return bIsPicking;
}

public int Native_IsJoinPlayer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    return bJoinPlayer[client];
}

public int Native_GetFirstAndSecondPicker(Handle plugin, int numParams)
{
    return iFirstAndSecondPicker;
}

public void OnAllPluginsLoaded()
{
    bReadyUpAvailable = LibraryExists("readyup");
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_picker",    VotePicker_Cmd, "command to specify the picker from the players");
    RegConsoleCmd("sm_pannounce", PickerAnnounce_Cmd, "shows the picker and player in the chat");

    RegAdminCmd("sm_fpicker",     FourcePicker_Cmd, ADMFLAG_BAN);
    RegAdminCmd("sm_forcepicker", FourcePicker_Cmd, ADMFLAG_BAN);

    survivor_limit       = FindConVar("survivor_limit");
    z_max_player_zombies = FindConVar("z_max_player_zombies");

    HookEvent("player_left_start_area", LeftStartArea_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    bLeftStartArea = false;
}

public void LeftStartArea_Event(Event event, const char[] name, bool dontBroadcast)
{
    bLeftStartArea = true;
}

public Action VotePicker_Cmd(int client, int args) 
{
    if (((!bReadyUpAvailable && !bLeftStartArea) || (bReadyUpAvailable && IsInReady())) && IsPlayer(client))
    {
        int iJoinPlayerCount  = GetJoinPlayerCount();
        int iTotalPlayerCount = GetTotalPlayerCount();

        if (iJoinPlayerCount < iTotalPlayerCount)
        {
            CPrintToChat(client, "<Vote:Picker> can't start vote because the number of players is less than %d people.", iTotalPlayerCount);
            return Plugin_Handled;
        }

        int iNumPlayers;
        int[] iPlayers = new int[MaxClients];
        for (int i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || IsFakeClient(i) || (L4D2_Team:GetClientTeam(i) == L4D2Team_Spectator))
            {
                continue;
            }
            
            iPlayers[iNumPlayers++] = i;
        }
    
        if (IsNewBuiltinVoteAllowed())
        {
            char cVoteTitle[32];
            Format(cVoteTitle, sizeof(cVoteTitle), "Choose a Picker?");

            hVotePicker = CreateBuiltinVote(VotePickerActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

            SetBuiltinVoteArgument(hVotePicker, cVoteTitle);
            SetBuiltinVoteInitiator(hVotePicker, client);
            SetBuiltinVoteResultCallback(hVotePicker, VotePickerResultHandler);
            DisplayBuiltinVote(hVotePicker, iPlayers, iNumPlayers, 20);

            CPrintToChatAllEx(client, "<Vote:Picker> {teamcolor}%N{default} initiated a vote.", client);
            FakeClientCommand(client, "Vote Yes");
        }

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action PickerAnnounce_Cmd(int client, int args)
{
    if (bIsPicking)
    {
        ShowPrintChatPickerList(client);
    }
}

public Action FourcePicker_Cmd(int client, int args)
{
    if (((!bReadyUpAvailable && !bLeftStartArea) || (bReadyUpAvailable && IsInReady())) && IsPlayer(client))
    {
        int iJoinPlayerCount  = GetJoinPlayerCount();

        if (iJoinPlayerCount < 2)
        {
            ReplyToCommand(client, "<Vote:Picker> can't start vote because the number of players is less than 2 people.");
            return Plugin_Handled;
        }

        Initialize();
        StartRandomChoosePicker();
    }

    return Plugin_Continue;
}

public int VotePickerActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
            hVotePicker = null;
            CloseHandle(vote);
        }
        case BuiltinVoteAction_Cancel:
        {
            DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
        }
        case BuiltinVoteAction_Select:
        {
            char cItemVal[64];
            char cItemName[64];
            GetBuiltinVoteItem(vote, param2, cItemVal, sizeof(cItemVal), cItemName, sizeof(cItemName));
            CPrintToChatAllEx(param1, "<Vote:Picker> {teamcolor}%N{default} chose {olive}%s.", param1, cItemName);
        }
    }
}

public void VotePickerResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    for (int i = 0; i < num_items; i++)
    {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
        {
            if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
            {
                if (vote == hVotePicker)
                {
                    DisplayBuiltinVotePass(vote, "Choose...");
                    CreateTimer(5.0, StartVotePicker_Timer);
                    return;
                }
            }
        }
    }
}

public Action StartVotePicker_Timer(Handle timer)
{
    int iJoinPlayerCount  = GetJoinPlayerCount();
    int iTotalPlayerCount = GetTotalPlayerCount();

    if (iJoinPlayerCount < iTotalPlayerCount)
    {
        CPrintToChatAll("<Vote:Picker> can't start vote because the number of players is less than %d people.", iTotalPlayerCount);
        return Plugin_Handled;
    }

    Initialize();
    StartRandomChoosePicker();

    return Plugin_Continue;
}

public void Initialize()
{
    bIsPicking = false;
    alJoinPlayers = new ArrayList();
    cChoosePlayers = "";
    iFirstPickerClient = iSecoundPickerClient = iFirstAndSecondPicker = -1;
    
    for (new client = 1; client <= MaxClients; client++)
    {
        bJoinPlayer[client] = false;
    }
}

public void StartRandomChoosePicker()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayer(client))
        {
            bJoinPlayer[client] = true;
            alJoinPlayers.Push(client);
        }
    }

    int iSurPickerClient = GetPickerClient();
    int iInfPickerClient = GetPickerClient();

    StartChoosePlayersPick(iSurPickerClient, iInfPickerClient);
}

public int GetPickerClient()
{
    int iRandomIdx    = GetRandomInt(0, alJoinPlayers.Length - 1);
    int iPickerClient = alJoinPlayers.Get(iRandomIdx);
    alJoinPlayers.Erase(iRandomIdx);

    return iPickerClient;
}

public void StartChoosePlayersPick(int iSurPickerClient, int iInfPickerClient)
{
    JoinPlayersToSpec();
    ChangeClientTeamEx(iSurPickerClient, L4D2Team_Survivor);
    ChangeClientTeamEx(iInfPickerClient, L4D2Team_Infected);

    /*
        0 = 1stPicker: Survivors / 2ndPicker: Infected
        1 = 1stPicker: Infected / 2ndPicker: Survivors
    */
    iFirstAndSecondPicker = GetRandomInt(0, 1);
    iFirstPickerClient    = iFirstAndSecondPicker == 0 ? iSurPickerClient : iInfPickerClient;
    iSecoundPickerClient  = iFirstAndSecondPicker == 0 ? iInfPickerClient : iSurPickerClient;

    for (int i = 0; i < alJoinPlayers.Length; i++)
    {
        int iPlayerClient = alJoinPlayers.Get(i);

        if (IsClientInGame(iPlayerClient) && !IsFakeClient(iPlayerClient))
        {
            char cPlayerName[128];
            GetClientName(iPlayerClient, cPlayerName, sizeof(cPlayerName));

            if (i > 0)
            {
                Format(cPlayerName, sizeof(cPlayerName), ", %s", cPlayerName);
            }

            Format(cChoosePlayers, sizeof(cChoosePlayers), "%s%s", cChoosePlayers, cPlayerName);
        }
    }

    bIsPicking = true;

    CreateTimer(0.5, ShowPrintChatPickerList_Timer);
    CreateTimer(0.5, Picking_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action ShowPrintChatPickerList_Timer(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            ShowPrintChatPickerList(client);
        }
    }
}

public Action Picking_Timer(Handle timer)
{
    int iJoinPlayerCount  = GetJoinPlayerCount();
    int iTotalPlayerCount = GetTotalPlayerCount();

    if (iJoinPlayerCount != iTotalPlayerCount)
    {
        return Plugin_Continue;
    }
    
    Initialize();

    return Plugin_Stop;
}

public void ShowPrintChatPickerList(int client)
{
    if (IsClientInGame(iFirstPickerClient))
    {
        CPrintToChatEx(
            client,
            iFirstPickerClient,
            "<{olive}Picker{default}> 1st Picker (%s): {teamcolor}%N", 
            GetStrTeamName(iFirstPickerClient),
            iFirstPickerClient
        );
    }

    if (IsClientInGame(iSecoundPickerClient))
    {
        CPrintToChatEx(
            client,
            iSecoundPickerClient,
            "<{olive}Picker{default}> 2nd Picker (%s): {teamcolor}%N", 
            GetStrTeamName(iSecoundPickerClient),
            iSecoundPickerClient
        );
    }

    if (strlen(cChoosePlayers) > 0)
    {
        CPrintToChat(client, "<{olive}Picker{default}> ChoosePlayers: {green}%s{default}", cChoosePlayers);
    }
}

public void JoinPlayersToSpec()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            ChangeClientTeamEx(client, L4D2Team_Spectator);
        }
    }
}

stock bool ChangeClientTeamEx(int client, L4D2_Team team)
{
    if (L4D2_Team:GetClientTeam(client) == team)
    {
        return true;
    }

    if (team != L4D2Team_Survivor)
    {
        ChangeClientTeam(client, _:team);
        return true;
    }
    else
    {
        int bot = FindSurvivorBot();
        if (bot > 0)
        {
            int flags = GetCommandFlags("sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags & ~FCVAR_CHEAT);
            FakeClientCommand(client, "sb_takecontrol");
            SetCommandFlags("sb_takecontrol", flags);
            return true;
        }
    }

    return false;
}

stock int FindSurvivorBot()
{
    for (new client = 1; client <= MaxClients; client++)
    {
        if(IsClientInGame(client) && IsFakeClient(client) && L4D2_Team:GetClientTeam(client) == L4D2Team_Survivor)
        {
            return client;
        }
    }

    return -1;
}

stock int GetTotalPlayerCount()
{
    return survivor_limit.IntValue + z_max_player_zombies.IntValue;
}

stock int GetJoinPlayerCount()
{
    return GetTeamHumanCount(L4D2Team_Survivor) + GetTeamHumanCount(L4D2Team_Infected);
}

stock int GetTeamHumanCount(L4D2_Team team)
{
    int humans = 0;
    
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client) && L4D2_Team:GetClientTeam(client) == team)
        {
            humans++;
        }
    }
    
    return humans;
}

stock bool IsPlayer(int client)
{
    L4D2_Team team = L4D2_Team:GetClientTeam(client);
    return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}

stock char GetStrTeamName(int client)
{
    char strTeamName[10];

    switch (L4D2_Team:GetClientTeam(client))
    {
        case L4D2Team_Spectator:
            strTeamName = "Spectator";
        case L4D2Team_Survivor:
            strTeamName = "Survivor";
        case L4D2Team_Infected:
            strTeamName = "Infected";
    }

    return strTeamName;
}
