"use strict";

var isHost = Game.GetLocalPlayerInfo().player_has_host_privileges;
var finishLineOptions = ["#finish_5k", "#finish_10k", "#finish_15k", "#finish_20k"];
var scoringOptions = ["#score_earned", "#score_creeps", "#score_networth", "#score_held"];
GameUI.CustomUIConfig().finishLine = 0;
GameUI.CustomUIConfig().scoring = 0;
GameUI.CustomUIConfig().sameHeroEnabled = false;
GameUI.CustomUIConfig().botsEnabled = false;


function OnHostOptionChanged()
{
	for (var i = 0; i < finishLineOptions.length; i++)
	{
		if ($( finishLineOptions[i]) != null )
		{
			GameUI.CustomUIConfig().finishLine = i
		}
	}
	for (var i = 0; i < scoringOptions.length; i++)
	{
		if ($( scoringOptions[i]) != null )
		{
			GameUI.CustomUIConfig().scoring = i
		}
	}
	GameUI.CustomUIConfig().sameHeroEnabled  = $("#same_hero").checked;
	GameUI.CustomUIConfig().botsEnabled  = $("#bots").checked;
	//$.Msg(GameUI.CustomUIConfig().scoring )
	if (isHost)
	{
		GameEvents.SendCustomGameEventToServer( "host_settings_changed", 
		{
			"finish_line": GameUI.CustomUIConfig().finishLine, 
			"score_method": GameUI.CustomUIConfig().scoring,
			"same_hero": GameUI.CustomUIConfig().sameHeroEnabled,
			"bots": GameUI.CustomUIConfig().botsEnabled
		});
	}
}

function OnReceivedHostOptions(event_data)
{
	GameUI.CustomUIConfig().finishLine = event_data[1];
	GameUI.CustomUIConfig().scoring = event_data[2];
	GameUI.CustomUIConfig().sameHeroEnabled = event_data[3]
	GameUI.CustomUIConfig().botsEnabled = event_data[4]
}

function UpdateGoldStats(event_data)
{
	GameUI.CustomUIConfig().goldStats = event_data
}


/* Initialization */
(function() {
	if (isHost)
	{
		$("#HostOptionsContainer").style.visibility = 'visible';
	}
	else
	{
		GameEvents.Subscribe( "host_settings_changed", OnReceivedHostOptions);
	}
	
	if ( Game.GetAllPlayerIDs().length >= Players.GetMaxPlayers())
	{
		$("#BotContainer").style.visibility = 'collapse';
	}
	
	if (Game.GetState() <  DOTA_GameState.DOTA_GAMERULES_STATE_GAME_IN_PROGRESS )
	{
		GameUI.CustomUIConfig().goldStats = {}
		for ( var playerID=0; playerID<= DOTALimits_t.DOTA_MAX_PLAYERS; playerID++ )
		{
			var temp = {}
			for ( var method = 0; method < 4; method++ )
			{
				temp[method] = 0
			}
			GameUI.CustomUIConfig().goldStats[playerID] = temp;
		}
		GameEvents.Subscribe( "gold_stats", UpdateGoldStats);
	}
	
	
})();