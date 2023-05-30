#include <sourcemod>
#include <builtinvotes>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define START_PICK_PLAYERS 3

// ConVars
ConVar
    survivor_limit,
    z_max_player_zombies;

// Variables
int
    iFirstPickerClient,
    iSecoundPickerClient,
    iFirstAndSecondPicker;

bool
    bLeftStartArea,
    bIsPicking,
    bPickerStop,
    bJoinPlayer[MAXPLAYERS + 1];

ArrayList
    alPickers,
    alJoinPlayers;

Menu
    pickPlayersMenu;

// Plugins Available
bool
    bReadyUpAvailable; // readyup

public Plugin myinfo =  
{
    name = "L4D2 Vote Picker",
    author = "PaaNChaN",
    description = "select picker from the players",
    version = "1.4",
    url = "https://github.com/PaaNChaN/L4D2_Plugins"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Picker_IsPicking", Native_IsPicking);
    CreateNative("Picker_IsJoinPlayer", Native_IsJoinPlayer);
    CreateNative("Picker_GetFirstAndSecondPicker", Native_GetFirstAndSecondPicker);
    CreateNative("Picker_GetPlayerNumber", Native_GetPlayerNumber);
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

public int Native_GetPlayerNumber(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (IsConnectedInGame(client) && bIsPicking && bJoinPlayer[client])
    {
        int index = alJoinPlayers.FindValue(client) + 1;
        return index;
    }

    return 0;
}

public void OnAllPluginsLoaded()
{
    bReadyUpAvailable = LibraryExists("readyup");
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_picker", VotePicker_Cmd, "command to specify the picker from the players");

    RegAdminCmd("sm_fpicker",     FourcePicker_Cmd, ADMFLAG_BAN);
    RegAdminCmd("sm_forcepicker", FourcePicker_Cmd, ADMFLAG_BAN);
    RegAdminCmd("sm_pstop",       PickerStop_Cmd,   ADMFLAG_BAN);

    survivor_limit       = FindConVar("survivor_limit");
    z_max_player_zombies = FindConVar("z_max_player_zombies");

    HookEvent("player_left_start_area", LeftStartArea_Event, EventHookMode_PostNoCopy);
    HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
}

public void OnClientDisconnect(int client)
{
    if (bIsPicking && !bPickerStop)
    {
        if (client == iFirstPickerClient || client == iSecoundPickerClient)
        {
            CPrintToChatAll("<{olive}Picker{default}> Picker has been disconnect ({green}%N{default})", client);
            bPickerStop = true;
        }
    }
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    bLeftStartArea = false;
}

public void LeftStartArea_Event(Event event, const char[] name, bool dontBroadcast)
{
    bLeftStartArea = true;
}

public void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int team   = event.GetInt("team");

    if (!client || IsFakeClient(client)) return;
    if (team == L4D2Team_None) return;
    if (!bIsPicking) return;
    if (iFirstPickerClient != client && iSecoundPickerClient != client) return;

    DataPack dp;
    CreateTimer(0.5, Timer_PlayerTeamEvent, dp);
    dp.WriteCell(client);
    dp.WriteCell(team);
}

public Action Timer_PlayerTeamEvent(Handle timer, DataPack dp)
{
    dp.Reset();

    int client = dp.ReadCell();
    int team   = dp.ReadCell();

    int FirstPickerTeam   = iFirstAndSecondPicker == 0 ? L4D2Team_Survivor : L4D2Team_Infected;
    int SecoundPickerTeam = iFirstAndSecondPicker == 0 ? L4D2Team_Infected : L4D2Team_Survivor;

    if (team == L4D2Team_Spectator)
    {
        CPrintToChat(client, "<{olive}Picker{default}> the picker can't move to the spectators until the pick is finished.");
        MoveToTeam(client, client == iFirstPickerClient ? FirstPickerTeam : SecoundPickerTeam);
    }

    return Plugin_Stop;
}

public Action VotePicker_Cmd(int client, int args) 
{
    if (((!bReadyUpAvailable && !bLeftStartArea) || (bReadyUpAvailable && IsInReady())) && IsPlayer(client))
    {
        if (GetJoinPlayersCount() < START_PICK_PLAYERS)
        {
            CPrintToChat(client, "<{olive}Picker{default}> can't start vote because there are less than %d players.", START_PICK_PLAYERS);
            return Plugin_Handled;
        }

        int iNumPlayers;
        int[] iPlayers = new int[MaxClients];
        for (int i = 1; i <= MaxClients; i++)
        {
            if (!IsConnectedInGame(i) || (GetClientTeam(i) == L4D2Team_Spectator))
            {
                continue;
            }
            
            iPlayers[iNumPlayers++] = i;
        }
    
        if (IsNewBuiltinVoteAllowed())
        {
            char cVoteTitle[32];
            Format(cVoteTitle, sizeof(cVoteTitle), "Choose a Picker?");

            Handle hVotePicker = CreateBuiltinVote(VotePickerActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

            SetBuiltinVoteArgument(hVotePicker, cVoteTitle);
            SetBuiltinVoteInitiator(hVotePicker, client);
            SetBuiltinVoteResultCallback(hVotePicker, VotePickerResultHandler);
            DisplayBuiltinVote(hVotePicker, iPlayers, iNumPlayers, 20);

            CPrintToChatAllEx(client, "<{olive}Picker{default}> {teamcolor}%N{default} initiated a vote.", client);
            FakeClientCommand(client, "Vote Yes");
        }

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public Action FourcePicker_Cmd(int client, int args)
{
    if (((!bReadyUpAvailable && !bLeftStartArea) || (bReadyUpAvailable && IsInReady())))
    {
        if (GetJoinPlayersCount() < START_PICK_PLAYERS)
        {
            CPrintToChat(client, "<{olive}Picker{default}> can't start vote because there are less than %d players.", START_PICK_PLAYERS);
            return Plugin_Handled;
        }

        Initialize();
        StartRandomChoosePicker();
    }

    return Plugin_Continue;
}

public Action PickerStop_Cmd(int client, int args)
{
    if (bIsPicking && !bPickerStop)
    {
        bPickerStop = true;
        CPrintToChatAll("<{olive}Picker{default}> stopped the picker by admin ({green}%N{default})", client);
    }

    return Plugin_Handled;
}

public void VotePickerActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
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
            CPrintToChatAllEx(param1, "<{olive}Picker{default}> {teamcolor}%N{default} chose {olive}%s.", param1, cItemName);
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
                DisplayBuiltinVotePass(vote, "Picker Start!!!");
                CreateTimer(5.0, StartVotePicker_Timer);
                return;
            }
        }
    }
}

public Action StartVotePicker_Timer(Handle timer)
{
    if (GetJoinPlayersCount() < START_PICK_PLAYERS)
    {
        CPrintToChatAll("<{olive}Picker{default}> can't start vote because there are less than %d players.", START_PICK_PLAYERS);
        return Plugin_Handled;
    }

    Initialize();
    StartRandomChoosePicker();

    return Plugin_Continue;
}

public void Initialize()
{
    bIsPicking = bPickerStop = false;
    alJoinPlayers = new ArrayList();
    alPickers = new ArrayList();
    iFirstPickerClient = iSecoundPickerClient = iFirstAndSecondPicker = -1;
    
    for (int client = 1; client <= MaxClients; client++)
    {
        bJoinPlayer[client] = false;
    }
}

public void StartRandomChoosePicker()
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsConnectedInGame(client) && IsPlayer(client))
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
    alPickers.Push(iPickerClient);
    alJoinPlayers.Erase(iRandomIdx);

    return iPickerClient;
}

public void StartChoosePlayersPick(int iSurPickerClient, int iInfPickerClient)
{
    JoinPlayersToSpec();
    MoveToTeam(iSurPickerClient, L4D2Team_Survivor);
    MoveToTeam(iInfPickerClient, L4D2Team_Infected);

    /*
        0 = 1stPicker: Survivors / 2ndPicker: Infected
        1 = 1stPicker: Infected / 2ndPicker: Survivors
    */
    iFirstAndSecondPicker = GetRandomInt(0, 1);
    iFirstPickerClient    = iFirstAndSecondPicker == 0 ? iSurPickerClient : iInfPickerClient;
    iSecoundPickerClient  = iFirstAndSecondPicker == 0 ? iInfPickerClient : iSurPickerClient;

    bIsPicking = true;

    CreateTimer(0.5, StartPick_Timer);
}

public Action StartPick_Timer(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsConnectedInGame(client))
        {
            ShowPrintChatPickerList(client);
        }
    }

    for (int i = 0; i < alPickers.Length; i++)
    {
        int iPickerClient = alPickers.Get(i);

        if (IsConnectedInGame(iPickerClient))
        {
            CPrintToChat(iPickerClient, "<{olive}Picker{default}> select choose players from the menu.");
        }
    }

    Menu_Initialize();
    CreateTimer(0.5, Picking_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Stop;
}

public void ShowPrintChatPickerList(int client)
{
    if (alJoinPlayers.Length > 0)
    {
        CPrintToChat(client, "<{olive}Picker{default}> Choose Players:");

        for (int i = 0; i < alJoinPlayers.Length; i++)
        {
            int iPClient = alJoinPlayers.Get(i);

            if (IsConnectedInGame(iPClient))
            {
                CPrintToChat(client, "{lightgreen}%d{default}: {green}%N{default}", i + 1, iPClient);
            }
        }
    }

    for (int i = 0; i < alPickers.Length; i++)
    {
        int iPickerClient = alPickers.Get(i);

        if (IsConnectedInGame(iPickerClient))
        {
            int clientTeam = GetClientTeam(iPickerClient);

            CPrintToChatEx(
                client,
                iPickerClient,
                "<{olive}Picker{default}> %s Picker (%s): {teamcolor}%N",
                iPickerClient == iFirstPickerClient ? "1st" : "2nd",
                L4D2_TeamName[clientTeam],
                iPickerClient
            );
        }
    }
}

public void Menu_Initialize()
{
    pickPlayersMenu = new Menu(Menu_PickPlayersHandler, MENU_ACTIONS_ALL);
    pickPlayersMenu.ExitButton = false;

    ShowHideCmdToPicker(false);
    MenuAddItemPlayers();
    MenuDisplayToPicker();
}

public Action Picking_Timer(Handle timer)
{
    if (CheckStopPicking())
    {
        PickerStop();
        return Plugin_Stop;
    }

    MenuAddItemPlayers();
    MenuDisplayToPicker();
    
    return Plugin_Continue;
}

public bool CheckStopPicking()
{
    int iJoinPlayerCount  = GetJoinPlayersCount();
    int iTotalPlayerCount = GetTotalPlayersCount();

    int iGamePlayersCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsConnectedInGame(i) && bJoinPlayer[i]) iGamePlayersCount++;
    }

    int iConnectedPickPlayers = 0;
    for (int i = 0; i < alJoinPlayers.Length; i++)
    {
        int iPClient = alJoinPlayers.Get(i);
        if (IsConnectedInGame(iPClient)) iConnectedPickPlayers++;
    }

    if (bPickerStop)
    {
        return true;
    }

    if (iJoinPlayerCount == iTotalPlayerCount)
    {
        return true;
    }

    if (iConnectedPickPlayers == 0)
    {
        return true;
    }

    if (iJoinPlayerCount < iTotalPlayerCount && iJoinPlayerCount == iGamePlayersCount)
    {
        return true;
    }

    return false;
}

public void MenuAddItemPlayers()
{
    pickPlayersMenu.RemoveAllItems();

    char clientId[30];
    char clientName[256];

    for (int i = 0; i < alJoinPlayers.Length; i++)
    {
        int iPClient = alJoinPlayers.Get(i);

        if (IsConnectedInGame(iPClient) && GetClientTeam(iPClient) == L4D2Team_Spectator)
        {
            IntToString(iPClient, clientId, sizeof(clientId));
            GetClientName(iPClient, clientName, sizeof(clientName));
            pickPlayersMenu.AddItem(clientId, clientName);
        }
    }
}

public void ShowHideCmdToPicker(bool flag)
{
    if (bReadyUpAvailable)
    {
        for (int i = 0; i < alPickers.Length; i++)
        {
            int iPickerClient = alPickers.Get(i);

            if (IsConnectedInGame(iPickerClient))
            {
                FakeClientCommand(iPickerClient, flag ? "sm_show" : "sm_hide");
            }
        }
    }
}

public void MenuDisplayToPicker()
{
    for (int i = 0; i < alPickers.Length; i++)
    {
        int iPickerClient = alPickers.Get(i);

        if (IsConnectedInGame(iPickerClient))
        {
            pickPlayersMenu.SetTitle("Select Players (%s Picker):", iPickerClient == iFirstPickerClient ? "1st" : "2nd");
            pickPlayersMenu.Display(iPickerClient, 1);
        }
    }
}

public int Menu_PickPlayersHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char cPClient[20];
        menu.GetItem(param2, cPClient, sizeof(cPClient));
        int iPClient = StringToInt(cPClient);

        int ltPickerTeam   = GetClientTeam(param1);
        int ltPlayerTeam   = GetClientTeam(iPClient);
        int iTeamMaxHumans = GetTeamMaxHumans(ltPickerTeam);

        if (iTeamMaxHumans > 0 && GetTeamHumanCount(ltPickerTeam) >= iTeamMaxHumans)
        {
            CPrintToChat(
                param1,
                "<{olive}Picker{default}> {blue}%s{default} team is full.",
                L4D2_TeamName[ltPickerTeam]
            );
        }
        else if (!IsConnectedInGame(iPClient))
        {
            CPrintToChat(
                param1,
                "<{olive}Picker{default}> the picked player isn't connected to the server."
            );
        }
        else if (ltPlayerTeam == L4D2Team_Survivor || ltPlayerTeam == L4D2Team_Infected)
        {
            CPrintToChat(
                param1,
                "<{olive}Picker{default}> {green}%N{default} has already been picked.",
                iPClient
            );
        }
        else
        {
            CPrintToChatAllEx(
                param1,
                "<{olive}Picker{default}> {green}%N{default} was picked by {teamcolor}%N{default} (%s)",
                iPClient,
                param1,
                L4D2_TeamName[ltPickerTeam]
            );

            MoveToTeam(iPClient, ltPickerTeam);
        }
    }

    return 0;
}

public void PickerStop()
{
    CPrintToChatAll("<{olive}Picker{default}> end of picker...");
    delete pickPlayersMenu;
    ShowHideCmdToPicker(true);
    Initialize();
}

public void JoinPlayersToSpec()
{
    for (int i = 0; i < alJoinPlayers.Length; i++)
    {
        int client = alJoinPlayers.Get(i);

        if (IsConnectedInGame(client))
        {
            MoveToTeam(client, L4D2Team_Spectator);
        }
    }
}

public void MoveToTeam(int client, int team)
{
    if (GetClientTeam(client) == team)
    {
        return;
    }

    if (team != L4D2Team_Survivor)
    {
        ChangeClientTeam(client, team);
    }
    else
    {
        FakeClientCommand(client, "jointeam 2");
    }
}

stock int GetTotalPlayersCount()
{
    return survivor_limit.IntValue + z_max_player_zombies.IntValue;
}

stock int GetJoinPlayersCount()
{
    return GetTeamHumanCount(L4D2Team_Survivor) + GetTeamHumanCount(L4D2Team_Infected);
}

stock int GetTeamMaxHumans(int team)
{
    switch (team)
    {
        case L4D2Team_Survivor:
        {
            return survivor_limit.IntValue;
        }
        case L4D2Team_Infected:
        {
            return z_max_player_zombies.IntValue;
        }
    }

    return 0;
}

stock int GetTeamHumanCount(int team)
{
    int humans = 0;
    
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsConnectedInGame(client) && GetClientTeam(client) == team)
        {
            humans++;
        }
    }
    
    return humans;
}

stock bool IsConnectedInGame(int client)
{
    return (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client));
}

stock bool IsPlayer(int client)
{
    int team = GetClientTeam(client);
    return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}
