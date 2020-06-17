#include <sourcemod>
#include <PTaH>

#pragma newdecls required
#pragma semicolon 1

ConVar g_hcvarKickType;
ConVar g_hcvarEnabled;
ConVar g_hcvarReason;

public Plugin myinfo = 
{
	name = "Reserved slots using PTaH and MaxClients Kicker",
	author = "Nano. Merged and fixed luki1412 & Wilczek plugins.",
	description = "Kick non-vips when a vip joins, and prevents players from exceeding the max-slots player limit.",
	version = "1.2",
	url = ""
}

public void OnPluginStart()
{
	g_hcvarEnabled = CreateConVar("sm_reserved_slots_enabled", "1", "Enables/disables this plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hcvarKickType = CreateConVar("sm_reserved_slots_type", "1", "Who gets kicked out: 1 - Highest ping player, 2 - Longest connection time player, 3 - Random player, 4 - Shortest connection time player", FCVAR_NONE, true, 1.0, true, 4.0);
	g_hcvarReason = CreateConVar("sm_reserved_slots_reason", "You were kicked because a VIP joined.", "Reason used when kicking players", FCVAR_NONE);

	AutoExecConfig(true, "ReservedSlots");
	
	PTaH(PTaH_ClientConnectPre, Hook, Hook_OnClientConnect);
}

public Action Hook_OnClientConnect(int iAccountID, const char[] sIp, const char[] sName, char sPassword[128], char rejectReason[255])
{
	if (!GetConVarInt(g_hcvarEnabled))
	{
		return Plugin_Continue;
	}

	if (GetClientCount(false) < GetMaxHumanPlayers())
	{
		return Plugin_Continue;	
	}

	char steamId[64];
	FormatEx(steamId, sizeof steamId, "STEAM_1:%d:%d", iAccountID & 1, iAccountID >>> 1);

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamId);
	if (admin == INVALID_ADMIN_ID)
	{
		return Plugin_Continue;
	}

	if (GetAdminFlag(admin, Admin_Reservation))
	{
		int target = SelectKickClient();
		if (target)
		{
			GetConVarString(g_hcvarReason, rejectReason, sizeof(rejectReason));
			KickClientEx(target, "%s", rejectReason);
		}
	}
	return Plugin_Continue;
}

int SelectKickClient()
{	
	float highestValue;
	int highestValueId;
	
	float highestSpecValue;
	int highestSpecValueId;
	
	bool specFound;
	
	float value;
	
	for (int i = 1; i <= MaxClients; i++)
	{	
		if (!IsClientConnected(i))
		{
			continue;
		}
	
		int flags = GetUserFlagBits(i);
		
		if (IsFakeClient(i) || flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION, false))
		{
			continue;
		}
		
		value = 0.0;
			
		if (IsClientInGame(i))
		{
			switch(GetConVarInt(g_hcvarKickType))
			{
				case 1:
				{
					value = GetClientAvgLatency(i, NetFlow_Outgoing);
				}
				case 2:
				{
					value = GetClientTime(i);
				}
				case 3:
				{
					value = GetRandomFloat(0.0, 100.0);
				}
				case 4:
				{
					value = GetClientTime(i) * -1.0;
				}
			}

			if (IsClientObserver(i))
			{			
				specFound = true;
				
				if (value > highestSpecValue)
				{
					highestSpecValue = value;
					highestSpecValueId = i;
				}
			}
		}
		
		if (value >= highestValue)
		{
			highestValue = value;
			highestValueId = i;
		}
	}
	
	if (specFound)
	{
		return highestSpecValueId;
	}
	
	return highestValueId;
}

public void OnClientPostAdminCheck(int client)
{
	if (!GetConVarInt(g_hcvarEnabled))
	{
		return;
	}

	if (GetClientCount(false) >= GetMaxHumanPlayers())
	{
		if(!GetUserAdmin(client).HasFlag(Admin_Reservation))
		{
			CreateTimer(0.1, OnTimedKickForReject, GetClientUserId(client));
		}
	}
}

public Action OnTimedKickForReject(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	KickClient(client, "Server is full! Try to join later, please.");
	return Plugin_Handled;
}