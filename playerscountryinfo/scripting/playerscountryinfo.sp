#include <sourcemod>
#include <colors>
#include <geoip>

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =  
{
    name = "Players Country Info",
    author = "PaaNChaN",
    description = "show players country in chat",
    version = PLUGIN_VERSION,
    url = "https://github.com/PaaNChaN/L4D2_Plugins"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_country", ShowPlayersCountry_Cmd, "show players country");
}

public Action ShowPlayersCountry_Cmd(int client, int args) 
{
    CPrintToChat(client, "<{olive}PCI{default}> List of Players Country:");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            char cIpAdrress[32];
            char cCountryCode[3];

            GetClientIP(i, cIpAdrress, sizeof(cIpAdrress));

            if(!GeoipCode2(cIpAdrress, cCountryCode))
            {
                Format(cCountryCode, sizeof(cCountryCode), "Unk");
            }

            CPrintToChatEx(client, i, "{teamcolor}%N{default}: {olive}%s", i, cCountryCode);
        }
    }
}