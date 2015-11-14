"use strict";
var gpm = 0
var cpm = 0
var green = "#ACE1AF"
var red = "#FA8072"

function UpdateStats() {
	var prevGpm = gpm
	var prevCpm = cpm
	gpm = Math.round(Players.GetGoldPerMin(Game.GetLocalPlayerID()))
	cpm = Math.round(60 * Players.GetLastHits(Game.GetLocalPlayerID()) / Game.GetDOTATime(false,false) )
	$('#GpmText').text = $.Localize('gpm')+gpm.toString();
	if (gpm > prevGpm )
	{
		$('#GpmText').style.color = green;
	}
	else if (gpm < prevGpm )
	{
		$('#GpmText').style.color = red;
	}

	$('#CpmText').text = $.Localize('cpm')+cpm.toString();
	if (cpm > prevCpm )
	{
		$('#CpmText').style.color = green;
	}
	else if (cpm < prevCpm )
	{
		$('#CpmText').style.color = red;
	}

    $.Schedule(1.0, UpdateStats);
	$.Schedule(0.25, ResetColours);
}

function ResetColours() {
	$('#GpmText').style.color = "white";
	$('#CpmText').style.color = "white";
}

/* Initialization */
(function() {
    UpdateStats();
})();