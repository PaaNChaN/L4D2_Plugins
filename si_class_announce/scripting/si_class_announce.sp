#include <sourcemod>
#include <colors>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.4"

public Plugin myinfo =
{
    name = "Special Infected Class Announce [Translations Ver]",
    author = "Tabun, Forgetest, PaaNChaN",
    description = "Report what SI classes are up when the round starts.",
    version = PLUGIN_VERSION,
    url = "none"
}

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

#define TEAM_SPECTATOR			1
#define TEAM_SURVIVOR			2
#define TEAM_INFECTED			3

#define MAXSPAWNS               8

#define CHAT_FLAG        (1 << 0)
#define HINT_FLAG        (1 << 1)

static const char g_csSIClassName[][] =
{
    "",
    "Smoker",
    "(Boomer)",
    "Hunter",
    "(Spitter)",
    "Jockey",
    "Charger",
    "",
    ""
};

Handle
	g_hAddFooterTimer;
	
ConVar
	g_hCvarFooter,
	g_hCvarPrint;
	
bool
	g_bRoundStarted,
	g_bAllowFooter,
	g_bMessagePrinted;

public void OnPluginStart()
{
	g_hCvarFooter	= CreateConVar(	"si_announce_ready_footer",
									"1",
									"Enable si class string be added to readyup panel as footer (if available).",
									FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	g_hCvarPrint	= CreateConVar(	"si_announce_print",
									"1",
									"Decide where the plugin prints the announce. (0: Disable, 1: Chat, 2: Hint, 3: Chat and Hint)",
									FCVAR_NOTIFY, true, 0.0, true, 3.0);
									
	HookEvent("round_start", view_as<EventHook>(Event_RoundStart), EventHookMode_PostNoCopy);
	HookEvent("round_end", view_as<EventHook>(Event_RoundEnd), EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam);

	LoadTranslations("si_class_announce.phrases");
}

public void OnMapEnd()
{
	g_bRoundStarted = false;
}

void ProcessReadyupFooter()
{
	if( GetFeatureStatus(FeatureType_Native, "AddStringToReadyFooter") == FeatureStatus_Available )
	{
		g_hAddFooterTimer = CreateTimer(7.0, UpdateReadyUpFooter, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void Event_RoundStart()
{
	g_bMessagePrinted = false;
	g_bRoundStarted = true;
	
	if (g_hCvarFooter.BoolValue)
	{
		g_bAllowFooter = true;
		ProcessReadyupFooter();
	}
	else
	{
		g_bAllowFooter = false;
	}
}

public void Event_RoundEnd()
{
	g_bRoundStarted = false;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bAllowFooter) return;
	
	if (!g_bRoundStarted) return;
	
	if (g_hAddFooterTimer != null) return;
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client) return;
	
	if (event.GetInt("team") == TEAM_INFECTED)
	{
		g_hAddFooterTimer = CreateTimer(1.0, UpdateReadyUpFooter, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action UpdateReadyUpFooter(Handle timer)
{
	g_hAddFooterTimer = null;
	
	if (!IsInfectedTeamFullAlive() || !g_bAllowFooter)
		return;
	
	// get currently active SI classes
	int iSpawns;
	int iSpawnClass[MAXSPAWNS];

	GetSpawnClass(iSpawns, iSpawnClass);

	char msg[65];
	if (ProcessSIString(iSpawns, iSpawnClass, msg, sizeof(msg), true))
		g_bAllowFooter = !(AddStringToReadyFooter(msg) != -1);
}

public void OnRoundIsLive()
{
	if (g_hCvarPrint.IntValue == 0)
		return;
	
	// get currently active SI classes
	int iSpawns;
	int iSpawnClass[MAXSPAWNS];

	GetSpawnClass(iSpawns, iSpawnClass);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientShowAnnounceSI(client))
		{
			// announce SI classes up now
			char msg[128];

			if (ProcessSIString(iSpawns, iSpawnClass, msg, sizeof(msg), false, client))
			{
				AnnounceSIClasses(msg, client);
			}
		}
	}

	g_bMessagePrinted = true;
}

public void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{
	// if no readyup, use this as the starting event
	if (!g_bMessagePrinted) {

		// get currently active SI classes
		int iSpawns;
		int iSpawnClass[MAXSPAWNS];

		GetSpawnClass(iSpawns, iSpawnClass);

		for (int client = 1; client <= MaxClients; client++)
		{			
			if (IsClientShowAnnounceSI(client))
			{
				// announce SI classes up now
				char msg[128];

				if (ProcessSIString(iSpawns, iSpawnClass, msg, sizeof(msg), false, client) && g_hCvarPrint.IntValue != 0)
				{
					AnnounceSIClasses(msg, client);
				}
			}
		}
			
		// no matter printed or not, we won't bother the game since survivor leaves saferoom.
		g_bMessagePrinted = true;
	}
}

#define COLOR_PARAM "%s{red}%T{default}"
#define NORMA_PARAM "%s%T"
#define NORMA_FOOTER_PARAM "%s%s"

bool ProcessSIString(int iSpawns, const int[] iSpawnClass, char[] msg, int maxlength, bool footer, int client = 0)
{	
	// found nothing :/
	if (!iSpawns) {
		return false;
	}

	int printFlags = g_hCvarPrint.IntValue;
	char cFormat[32];

 	if (!client && footer) {
 		strcopy(msg, maxlength, "SI: ");
 		strcopy(cFormat, sizeof(cFormat), NORMA_FOOTER_PARAM);
 	} else {
 		Format(msg, maxlength, "%T", "Print_Title", client);
 		strcopy(cFormat, sizeof(cFormat), (printFlags & CHAT_FLAG) ? COLOR_PARAM : NORMA_PARAM);
 	}
	
	// format classes, according to amount of spawns found
	for (int i = 0; i < iSpawns; i++) {
		if (i) StrCat(msg, maxlength, ", ");
		
		Format(	msg,
				maxlength,
				cFormat,
				msg,
				g_csSIClassName[iSpawnClass[i]],
				client
		);
	}
	
	return true;
}

void AnnounceSIClasses(const char[] Message, int client)
{
	char temp[128];
	
	int printFlags = g_hCvarPrint.IntValue;
	if (printFlags & HINT_FLAG)
	{
		strcopy(temp, sizeof temp, Message);
		CRemoveTags(temp, sizeof temp);
	}
	
	if (printFlags & CHAT_FLAG) CPrintToChat(client, Message);
	if (printFlags & HINT_FLAG) PrintHintText(client, temp);
}

stock bool IsInfectedTeamFullAlive()
{
	static ConVar cMaxZombies;
	if (!cMaxZombies) cMaxZombies = FindConVar("z_max_player_zombies");
	
	int players = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsPlayerAlive(i)) players++;
	}
	return players == cMaxZombies.IntValue;
}

void GetSpawnClass(int &iSpawns, int[] iSpawnClass)
{	
	for (int i = 1; i <= MaxClients && iSpawns < MAXSPAWNS; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i)) { continue; }
		
		iSpawnClass[iSpawns] = GetEntProp(i, Prop_Send, "m_zombieClass");
		
		if (iSpawnClass[iSpawns] != ZC_WITCH && iSpawnClass[iSpawns] != ZC_TANK)
			iSpawns++;
	}
}

stock bool IsClientShowAnnounceSI(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) != TEAM_INFECTED && (!IsFakeClient(client) || IsClientSourceTV(client));
}