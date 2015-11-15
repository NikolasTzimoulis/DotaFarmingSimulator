"use strict";

var isHost = Game.GetLocalPlayerInfo().player_has_host_privileges;
var finishLineOptions = ["#finish_5k", "#finish_10k", "#finish_15k", "#finish_20k"];
GameUI.CustomUIConfig().finishLine = 0;


function OnDropDownChanged()
{
	for (var i = 0; i < finishLineOptions.length; i++)
	{
		if ($( finishLineOptions[i]) != null )
		{
			GameUI.CustomUIConfig().finishLine = i
		}
	}
	if (isHost)
	{
		GameEvents.SendCustomGameEventToServer( "set_setting", {"setting": "finish_line", "value": GameUI.CustomUIConfig().finishLine});
	}
}


/* Initialization */
(function() {
	if (isHost)
	{
		$("#HostOptionsContainer").style.visibility = 'visible';
	}
})();