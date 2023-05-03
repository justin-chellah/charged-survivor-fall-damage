#include <sourcemod>
#include <sdkhooks>

#define REQUIRE_EXTENSIONS
#include <dhooks>

#define TEAM_ZOMBIE 3

#define GAMEDATA_FILE	"charged_survivor_fall_damage"

enum ZombieClassType
{
	Zombie_Common = 0,
	Zombie_Smoker,
	Zombie_Boomer,
	Zombie_Hunter,
	Zombie_Spitter,
	Zombie_Jockey,
	Zombie_Charger,
	Zombie_Witch,
	Zombie_Tank,
	Zombie_Survivor,
};

ConVar fall_speed_fatal = null;
ConVar fall_speed_safe = null;

DynamicHook g_hDHook_CMultiplayRules_FlPlayerFallDamage = null;

ZombieClassType GetZombieClass( int iClient )
{
	return view_as< ZombieClassType >( GetEntProp( iClient, Prop_Send, "m_zombieClass" ) );
}

// NOTE: This is how the game calculates fall damage
float FallingDamageForSpeed( float flFallVelocity )
{
	return ( flFallVelocity / ( fall_speed_fatal.FloatValue - fall_speed_safe.FloatValue ) * ( flFallVelocity / ( fall_speed_fatal.FloatValue - fall_speed_safe.FloatValue ) ) ) * 100.0;
}

public MRESReturn DHook_CMultiplayRules_FlPlayerFallDamage( Handle hParams )
{
	int iClient = DHookGetParam( hParams, 1 );

	if ( GetClientTeam( iClient ) == TEAM_ZOMBIE && GetZombieClass( iClient ) == Zombie_Charger )
	{
		int iVictim = GetEntPropEnt( iClient, Prop_Send, "m_carryVictim" );

		if ( iVictim == INVALID_ENT_REFERENCE )
		{
			iVictim = GetEntPropEnt( iClient, Prop_Send, "m_pummelVictim" );
		}

		if ( iVictim != INVALID_ENT_REFERENCE )
		{
			float flFallDamage = FallingDamageForSpeed( GetEntPropFloat( iClient, Prop_Send, "m_flFallVelocity" ) );

			SDKHooks_TakeDamage( iVictim, 0/* = world */, iClient, flFallDamage, DMG_FALL );

			if ( flFallDamage > 0.0 )
			{
				const bool bForce = false;

				Event hEvent = CreateEvent( "player_falldamage", bForce );

				if ( hEvent )
				{
					hEvent.SetInt( "userid", GetClientUserId( iVictim ) );
					hEvent.SetFloat( "damage", flFallDamage );
					hEvent.SetInt( "priority", 4 );	// HLTV event priority, not transmitted
					hEvent.Fire();
				}
			}
		}
	}

	return MRES_Ignored;
}

public void OnMapStart()
{
	g_hDHook_CMultiplayRules_FlPlayerFallDamage.HookGamerules( Hook_Pre, DHook_CMultiplayRules_FlPlayerFallDamage );
}

public void OnPluginStart()
{
	GameData hGameData = new GameData( GAMEDATA_FILE );

	if ( hGameData == null )
	{
		SetFailState( "Unable to load gamedata file \"" ... GAMEDATA_FILE ... "\"" );
	}

	int nOffset = hGameData.GetOffset( "CMultiplayRules::FlPlayerFallDamage" );

	if ( nOffset == -1 )
	{
		delete hGameData;

		SetFailState( "Unable to find gamedata offset entry for \"CMultiplayRules::FlPlayerFallDamage\"" );
	}

	delete hGameData;

	fall_speed_fatal = FindConVar( "fall_speed_fatal" );
	fall_speed_safe = FindConVar( "fall_speed_safe" );

	g_hDHook_CMultiplayRules_FlPlayerFallDamage = new DynamicHook( nOffset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore );
	g_hDHook_CMultiplayRules_FlPlayerFallDamage.AddParam( HookParamType_CBaseEntity );
}

public Plugin myinfo =
{
	name = "[L4D2] Charged Survivor Fall Damage",
	author = "Justin \"Sir Jay\" Chellah",
	description = "Allows applying fall damage to charged survivor players so that there's the possibility of making instant kills",
	version = "1.0.0",
	url = "https://justin-chellah.com"
};