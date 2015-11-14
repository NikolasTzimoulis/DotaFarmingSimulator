require("libraries/timers")

if Farming == nil then
	Farming = class({})
end

function Precache( context )
	PrecacheResource("soundfile", "soundevents/voscripts/game_sounds_vo_announcer.vsndevts", context)
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = Farming()
	GameRules.AddonTemplate:InitGameMode()
end

function Farming:InitGameMode()
	print( "Farming Simulator is loaded." )
	self.goldGoal = 10000
	self.pregame = 30
	self.minLead = 10
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 5 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 0 )
	GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetHeroSelectionTime(30)
	GameRules:SetPreGameTime(self.pregame)
	GameRules:SetPostGameTime(60)
	GameRules:SetUseUniversalShopMode(true)
	GameRules:GetGameModeEntity():SetAnnouncerDisabled(true)
	self.countdown = nil
	self.gameJustStarted = true
	self.gameOverTime = math.huge
	ancient = Entities:FindByName( nil, "dota_badguys_fort" )
	ancient:AddNewModifier(ancient, nil, "modifier_invulnerable", {duration = -1}) 
	ListenToGameEvent( "dota_item_purchased", Dynamic_Wrap( Farming, "OnItemPurchased" ), self )
end

-- Evaluate the state of the game
function Farming:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS and self.gameJustStarted then
		self.gameJustStarted = false
		self:InitialisePlayers()
		Timers:CreateTimer(5, function() 
			self:CheckGold() 
			return 1
		end)
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then
		if self.countdown == nil then
			self.countdown = 4
			EmitAnnouncerSound("announcer_ann_custom_mode_25")
			Timers:CreateTimer(self.pregame-4, function()			
				if self.countdown == 4 then 
					EmitAnnouncerSound("announcer_ann_custom_countdown_03")
					self.countdown = 3
					return 1
				elseif self.countdown == 3 then
					EmitAnnouncerSound("announcer_ann_custom_countdown_02")
					self.countdown = 2
					return 1
				elseif self.countdown == 2 then
					EmitAnnouncerSound("announcer_ann_custom_countdown_01")
					self.countdown = 1
					return 1
				elseif self.countdown == 1 then
					EmitAnnouncerSound("announcer_ann_custom_begin")
					return nil
				end
			end)
		end
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME and Time() > self.gameOverTime + 2 then
		self.gameOverTime = math.huge
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_end_10", self.sortedPlayers[1]) 
		for place = 2, 5 do
			if self.sortedPlayers[place] == nil then
				break
			end
			EmitAnnouncerSoundForPlayer("announcer_ann_custom_defeated_26", self.sortedPlayers[place])
		end
	end
	return 1
end

function Farming:InitialisePlayers()
	self.sortedPlayers = {}
	for playerID = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) then
			table.insert(self.sortedPlayers, playerID)
		end
	end
end

function Farming:CheckGold()
	local oldLeader = self.sortedPlayers[1]
	table.sort(self.sortedPlayers, function(a,b) return ComparePlayerScores(a, b) end)
	if PlayerResource:GetTotalEarnedGold(self.sortedPlayers[1]) >= self.goldGoal then
		GameRules:SetCustomVictoryMessage(PlayerResource:GetPlayerName(self.sortedPlayers[1]).." WON!")
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_place_01", self.sortedPlayers[1])
		for place = 2, 5 do
			if self.sortedPlayers[place] == nil then
				break
			end
			EmitAnnouncerSoundForPlayer("announcer_ann_custom_place_0"..tostring(place), self.sortedPlayers[place])
		end
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		self.gameOverTime = Time()
	elseif olderLeader ~= self.sortedPlayers[1] and PlayerResource:GetTotalEarnedGold(self.sortedPlayers[1]) - PlayerResource:GetTotalEarnedGold(oldLeader) >= self.minLead then
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_team_alerts_01", self.sortedPlayers[1])
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_team_alerts_03", oldLeader)
	end
end

function Farming:OnItemPurchased(event)
	hero = PlayerResource:GetSelectedHeroEntity(event.PlayerID)
	-- transfer item if possible
	for slot =  DOTA_STASH_SLOT_1, DOTA_STASH_SLOT_6 do
		item = hero:GetItemInSlot(slot)
		if item ~= nil then
			itemName = item:GetAbilityName()
			if itemName == event.itemname then
				item:RemoveSelf()
				hero:AddItem(CreateItem(itemName, hero, hero))
				break
			end
		end
	end
	-- any items left in the stash after this are put on the ground
	for slot =  DOTA_STASH_SLOT_1, DOTA_STASH_SLOT_6 do
		item = hero:GetItemInSlot(slot)
		if item ~= nil then
			itemName = item:GetAbilityName()
			item:RemoveSelf()
			CreateItemOnPositionSync(hero:GetOrigin(), CreateItem(itemName, hero, hero)) 			
		end
	end
end

function ComparePlayerScores(playerID1, playerID2)
	return PlayerResource:GetTotalEarnedGold(playerID1) > PlayerResource:GetTotalEarnedGold(playerID2) 
end