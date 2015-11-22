require("libraries/timers")
require("libraries/notifications")

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
	self.goldGoal = 5000
	self.scoreMethod = 0
	self.forceSameHero = false
	self.botsEnabled = false
	self.firstPlayerID = nil
	self.heroselection = 30
	self.pregame = 60
	self.minLead = 5
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 10 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 0 )
	GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetHeroSelectionTime(self.heroselection)
	GameRules:SetPreGameTime(self.pregame)
	GameRules:SetPostGameTime(60)
	GameRules:SetUseUniversalShopMode(true)
	GameRules:GetGameModeEntity():SetAnnouncerDisabled(true)
	self.countdown = nil
	self.gameJustStarted = true
	self.sentOptionNotifications = false
	self.startingGold = 650
	self.gameOverTime = math.huge
	ListenToGameEvent( "dota_item_purchased", Dynamic_Wrap( Farming, "OnItemPurchased" ), self )
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( Farming, "OnPlayerSpawn" ), self )	
	CustomGameEventManager:RegisterListener("host_settings_changed", function(id, ...) Dynamic_Wrap(self, "OnHostSetting")(self, ...) end)
end

-- Evaluate the state of the game
function Farming:OnThink()
	if self.forceSameHero and self.firstPlayerID == nil then
		self:FindFirstSelectedHero()
	end		
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		AssignPlayersToTeam()
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION and not self.sentOptionNotifications then	
		self:SendOptionNotifications()
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then	
		if self.countdown == nil then
			if self.botsEnabled then
				EnableBots()
			end
			EmitAnnouncerSound("announcer_ann_custom_mode_25")
			self.countdown = 4
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
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS and self.gameJustStarted then
		self.gameJustStarted = false
		self:InitialisePlayers()
		Timers:CreateTimer(function() 
			self:CheckGold() 
			return 1
		end)
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME and Time() > self.gameOverTime + 2 then
		self.gameOverTime = math.huge
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_end_10", self.sortedPlayers[1]) 
		for place = 2, DOTA_MAX_PLAYERS do
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
	CustomGameEventManager:Send_ServerToAllClients( "gold_stats", self:MakeGoldStatsTable())
	table.sort(self.sortedPlayers, function(a,b) return self:ComparePlayerScores(a, b) end)		
	if self:GetScore(self.sortedPlayers[1], nil) >= self.goldGoal then
		--GameRules:SetCustomVictoryMessage(PlayerResource:GetPlayerName(self.sortedPlayers[1]).." WON!")
		--PlayerResource:SetCameraTarget(self.sortedPlayers[1], PlayerResource:GetSelectedHeroEntity(self.sortedPlayers[1]))
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_place_01", self.sortedPlayers[1])
		for place = 2, 5 do
			if self.sortedPlayers[place] == nil then
				break
			end
			--PlayerResource:SetCameraTarget(self.sortedPlayers[place], PlayerResource:GetSelectedHeroEntity(self.sortedPlayers[1]))
			EmitAnnouncerSoundForPlayer("announcer_ann_custom_place_0"..tostring(place), self.sortedPlayers[place])
		end
		GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
		self.gameOverTime = Time()
	elseif PlayerResource:GetTotalEarnedGold(self.sortedPlayers[1]) - PlayerResource:GetTotalEarnedGold(oldLeader) >= self.minLead then
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
		local item = hero:GetItemInSlot(slot)
		if item ~= nil then
			itemName = item:GetAbilityName()
			item:RemoveSelf()
			CreateItemOnPositionSync(hero:GetOrigin(), CreateItem(itemName, hero, hero)) 			
		end
	end
end

function Farming:OnPlayerSpawn(event)
	local spawnedUnit = EntIndexToHScript(event.entindex)
	if spawnedUnit:IsRealHero() then
		local playerID = spawnedUnit:GetPlayerOwnerID()
		local heroName = spawnedUnit:GetClassname()
		if self.firstPlayerID ~= nil and playerID == self.firstPlayerID then
			self.forceSameHero = heroName
			self.startingGold = PlayerResource:GetGold(playerID)
		end
		Timers:CreateTimer(function() 
			if type(self.forceSameHero) == "string" and self.forceSameHero ~= heroName then
				PlayerResource:ReplaceHeroWith(playerID, self.forceSameHero, self.startingGold, 0)
			elseif self.forceSameHero then
				return 0.1
			end
		end)
	end
end

function Farming:OnHostSetting( event )
	self.goldGoal = 5000*(event.finish_line+1)
	self.scoreMethod = event.score_method
	if event.same_hero == 1 then
		self.forceSameHero = true
	else
		self.forceSameHero = false
	end
	if event.bots == 1 then
		self.botsEnabled = true
	else
		self.botsEnabled = false
	end
	CustomGameEventManager:Send_ServerToAllClients( "host_settings_changed", {event.finish_line, event.score_method, event.same_hero, event.bots})
end

function Farming:GetScore(playerID, method)
	if method == nil then
		method = self.scoreMethod
	end
	if method == 0 then
		return PlayerResource:GetTotalEarnedGold(playerID)
	elseif method == 1 then
		return PlayerResource:GetClaimedFarm(playerID, true)
	elseif method == 2 then
		return GetNetWorth(playerID)
	elseif method == 3 then
		return PlayerResource:GetGold(playerID)
	end
end

function Farming:MakeGoldStatsTable()
	local statTable = {}
	for playerID = 0, DOTA_MAX_PLAYERS do
		if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) then
			temp = {}
			for method = 0,3 do
				temp[method] = self:GetScore(playerID, method)
			end
			statTable[playerID] = temp
		end
	end
	return statTable
end

function Farming:ComparePlayerScores(playerID1, playerID2)
	return self:GetScore(playerID1, nil) > self:GetScore(playerID2, nil) 
end

function GetNetWorth(playerID)
	local worth = PlayerResource:GetGold(playerID)
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if IsValidEntity(hero) then
		for slot = DOTA_ITEM_SLOT_1, DOTA_STASH_SLOT_6 do
			local item = hero:GetItemInSlot(slot)
			if item ~= nil then
				worth = worth + item:GetCost()
			end
		end
	end
	return worth
end

function Farming:FindFirstSelectedHero()
	for playerID = 0, DOTA_MAX_PLAYERS do
		if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) and PlayerResource:HasSelectedHero(playerID) then
			self.firstPlayerID = playerID
			break
		end
	end
end

function Farming:SendOptionNotifications()
	Notifications:BottomToAll({text="finish_line", duration=30.0})
	Notifications:BottomToAll({text="gold_"..tostring(self.goldGoal), duration=30.0, continue=true})	
	Notifications:BottomToAll({text=self:GetScoringString() , duration=30.0, continue=true})
	if self.forceSameHero == true then
		Notifications:BottomToAll({text="same_hero" , duration=30.0})
	end
	self.sentOptionNotifications = true
end

function Farming:GetScoringString() 
	if self.scoreMethod==0 then
		return '#gold_earned'
	elseif self.scoreMethod==1 then
		return "#gold_creeps"
	elseif self.scoreMethod==2 then
		return "#gold_networth"
	elseif self.scoreMethod==3 then
		return "#gold_held"
	else 
		return ""		
	end
end

function EnableBots()
	SendToServerConsole("sv_cheats 1;dota_bot_populate")
	GameRules:GetGameModeEntity():SetBotThinkingEnabled(true)
	GameRules:GetGameModeEntity():SetBotsInLateGame(false)
	GameRules:GetGameModeEntity():SetBotsMaxPushTier(0)
	GameRules:GetGameModeEntity():SetBotsAlwaysPushWithHuman(false)
	for _, hero in pairs( HeroList:GetAllHeroes() ) do
		hero:SetBotDifficulty(4)
	end
end

function AssignPlayersToTeam()
	for playerID = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) then
			PlayerResource:SetCustomTeamAssignment(playerID, DOTA_TEAM_GOODGUYS)
		end
	end
end

