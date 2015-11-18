"use strict";

(function()
{
	if ( ScoreboardUpdater_InitializeScoreboard === null ) { $.Msg( "WARNING: This file requires shared_scoreboard_updater.js to be included." ); }

	var scoreboardConfig =
	{
		"teamXmlName" : "file://{resources}/layout/custom_game/multiteam_end_screen_team.xml",
		"playerXmlName" : "file://{resources}/layout/custom_game/multiteam_end_screen_player.xml",
	};

	var endScoreboardHandle = ScoreboardUpdater_InitializeScoreboard( scoreboardConfig, $( "#TeamsContainer" ) );
	$.GetContextPanel().SetHasClass( "endgame", 1 );
	
	var teamInfoList = [Game.GetTeamDetails(2)] //ScoreboardUpdater_GetSortedTeamInfoList2( endScoreboardHandle );
	var playerInfoList = ScoreboardUpdater_GetSortedTeamInfoList( endScoreboardHandle );
	var delay = 0.2;
	var delay_per_panel = 1 / playerInfoList.length;
	for ( var playerInfo of playerInfoList )
	{
		var teamPanel = ScoreboardUpdater_GetTeamPanel( endScoreboardHandle, playerInfo.player_id );
		teamPanel.SetHasClass( "team_endgame", false );
		var callback = function( panel )
		{
			return function(){ panel.SetHasClass( "team_endgame", 1 ); }
		}( teamPanel );
		$.Schedule( delay, callback )
		delay += delay_per_panel;
	}
	

	var winningPlayerId = playerInfoList[0].player_id;
	//var winningTeamDetails = Game.GetTeamDetails( winningTeamId );
	var endScreenVictory = $( "#EndScreenVictory" );
	if ( endScreenVictory )
	{
		//endScreenVictory.SetDialogVariable( "winning_team_name", $.Localize( playerInfoList[0].player_name ) );
		$( "#EndScreenVictory" ).text = playerInfoList[0].player_name + $.Localize("#custom_end_screen_victory_message");
		if ( GameUI.CustomUIConfig().team_colors )
		{
			var teamColor = GetPlayerColour(winningPlayerId);
			teamColor = teamColor.replace( ";", "" );
			endScreenVictory.style.color = teamColor + ";";
		}
	}

	var winningTeamLogo = $( "#WinningTeamLogo" );
	if ( winningTeamLogo )
	{
		var logo_xml = GameUI.CustomUIConfig().team_logo_large_xml;
		if ( logo_xml )
		{
			//winningTeamLogo.SetAttributeInt( "team_id", winningTeamId );
			winningTeamLogo.BLoadLayout( logo_xml, false, false );
		}
	}
})();
