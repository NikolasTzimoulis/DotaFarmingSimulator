"use strict";

var goal = "#gold_5000"

var humanTime = function(time) {
    time = Math.floor(time);
    var minutes = Math.floor(time / 60);
    var seconds = time - (minutes * 60);

    if (seconds < 10)
        seconds = '0' + seconds;

    return minutes + ':' + seconds;
};

function UpdateProgressBar() {
    var goldGoal = (GameUI.CustomUIConfig().finishLine+1)*5000
	var gold = 0
	if (GameUI.CustomUIConfig().goldStats != null && GameUI.CustomUIConfig().scoring != null)
	{
		gold = GameUI.CustomUIConfig().goldStats[Game.GetLocalPlayerID()][GameUI.CustomUIConfig().scoring]
	}
    var progressPercent = Math.floor((gold / goldGoal) * 10000) / 100;
	var eta = Math.round((goldGoal-gold) / (gold/Game.GetDOTATime(false,false)));
	$('#ETAText').text = eta >= 0 && eta < 60000 ? ($.Localize('eta') +  humanTime(eta)) : '';
	 
    $('#ProgressBarPercentage').style.width = progressPercent + '%';

	goal = "#gold_"+((GameUI.CustomUIConfig().finishLine+1)*5000).toString()
    $('#ProgressBarText').text = $.Localize('progress')+$.Localize(goal)+$.Localize(GetScoringString(GameUI.CustomUIConfig().scoring));

    $.Schedule(1.0, UpdateProgressBar);
	//$.Msg(GameUI.CustomUIConfig().scoring)
}

function GetScoringString(id) {
	if (id==0)
		return '#gold_earned';
	else if (id==1)
		return "#gold_creeps";
	else if (id==2)
		return "#gold_networth";
	else if (id==3)
		return "#gold_held";
	else return "";		
}


/* Initialization */
(function() {
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_TOP_HEROES, false );     //Heroes and team score at the top of the HUD.
	GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_COURIER, false );      //Courier controls.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_PROTECT, false );      //Glyph.
	GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_ENDGAME, false );      //Endgame scoreboard.    
	GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_FLYOUT_SCOREBOARD, true );      //Lefthand flyout scoreboard.
	GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_TOP_TIMEOFDAY, true );      //Time of day (clock).    
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_ACTION_PANEL, true );     //Hero actions UI.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_ACTION_MINIMAP, true );     //Minimap.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_PANEL, true );      //Entire Inventory UI
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_SHOP, true );     //Shop portion of the Inventory.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_ITEMS, true );      //Player items.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_QUICKBUY, true );     //Quickbuy.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_INVENTORY_GOLD, true );     //Gold display.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_SHOP_SUGGESTEDITEMS, true );      //Suggested items shop panel.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_HERO_SELECTION_TEAMS, true );     //Hero selection Radiant and Dire player lists.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_HERO_SELECTION_GAME_NAME, true );     //Hero selection game mode name display.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_HERO_SELECTION_CLOCK, true );     //Hero selection clock.    
	GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_TOP_MENU_BUTTONS, true );     //Top-left menu buttons in the HUD.
    GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_TOP_BAR_BACKGROUND, true );     //Top-left menu buttons in the HUD.
	GameUI.SetDefaultUIEnabled( DotaDefaultUIElement_t.DOTA_DEFAULT_UI_ELEMENT_COUNT, false );     

    UpdateProgressBar();
})();