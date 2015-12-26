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
	self.goldGoal = nil
	self.scoreMethod = nil
	self.forceSameHero = true
	self.botsEnabled = false
	self.forcedHeroName = nil
	self.instantDelivery = true
	self.heroselection = 30
	self.pregame = 60
	self.minLead = 5
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	SetMaxPlayers()
	self.spawnPositions = {}
	self:FindSpawnPositions()
	GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetHeroSelectionTime(self.heroselection)
	GameRules:SetPreGameTime(self.pregame)
	GameRules:SetPostGameTime(60)
	GameRules:SetUseUniversalShopMode(true)
	GameRules:GetGameModeEntity():SetAnnouncerDisabled(true)
	self.countdown = nil
	self.gameJustStarted = true
	self.resolvedVotes = false
	self.setupOnce = false
	self.gameOverTime = math.huge
	self.waitingForCourier = {}
	ListenToGameEvent( "dota_item_purchased", Dynamic_Wrap( Farming, "OnItemPurchased" ), self )
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( Farming, "OnNPCSpawn" ), self )	
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( Farming, 'OnEntityKilled' ), self )
	CustomGameEventManager:RegisterListener("host_settings_changed", function(id, ...) Dynamic_Wrap(self, "OnHostSetting")(self, ...) end)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(Farming,"FilterExecuteOrder"),self)
end

-- Evaluate the state of the game
function Farming:OnThink()	
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		AssignPlayersToTeam()
		if not self.setupOnce then
			self.setupOnce = true
			SendToServerConsole("sv_cheats 1")
			print("sv_cheats 1")
			print("cheats server:", Convars:GetInt("sv_cheats"))
			Timers:CreateTimer(0.1, function() CustomGameEventManager:Send_ServerToAllClients("cheats", {Convars:GetInt("sv_cheats")}) end)
			self:InitialisePlayers()
		end
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_HERO_SELECTION and not self.resolvedVotes then	
		self:AggregateVotes()
	elseif GameRules:State_Get() == DOTA_GAMERULES_STATE_PRE_GAME then	
		if self.forceSameHero and self.forcedHeroName == nil then
			self:DecideForcedHero()
		end
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
	self.finishlineVotes = {}
	self.scoremethodVotes = {}
	self.sameheroVotes = {}
	self.instantdeliveryVotes = {}
	self.botVotes = {}
	for playerID = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) then
			table.insert(self.sortedPlayers, playerID)
			self.sameheroVotes[playerID] = 1
			self.instantdeliveryVotes[playerID] = 1
			self.botVotes[playerID] = 0
		end
	end
end

function Farming:CheckGold()
	local oldLeader = self.sortedPlayers[1]
	CustomGameEventManager:Send_ServerToAllClients( "gold_stats", self:MakeGoldStatsTable())
	table.sort(self.sortedPlayers, function(a,b) return self:ComparePlayerScores(a, b) end)		
	if self:GetScore(self.sortedPlayers[1], nil) >= self.goldGoal then
		EmitAnnouncerSoundForPlayer("announcer_ann_custom_place_01", self.sortedPlayers[1])
		for place = 2, 5 do
			if self.sortedPlayers[place] == nil then
				break
			end
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
	if self.instantDelivery then
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
end

function Farming:OnNPCSpawn(event)
	local spawnedUnit = EntIndexToHScript(event.entindex)
	local  playerID = spawnedUnit:GetPlayerOwnerID()
	-- force each hero to always respawn in the same position
	if spawnedUnit:IsRealHero() then		
		if self.spawnPositions[playerID] == nil and table.getn(self.unusedSpawnPositions) > 0 then
			self.spawnPositions[playerID] = table.remove(self.unusedSpawnPositions)
			Timers:CreateTimer(0.1, function() spawnedUnit:SetAbsOrigin(self.spawnPositions[playerID]) end)
		end
	end
	if spawnedUnit:IsRealHero() and self.forceSameHero then
		Timers:CreateTimer(function() 			
			if self.forcedHeroName ~= nil and self.forcedHeroName ~= spawnedUnit:GetClassname() then
				PlayerResource:ReplaceHeroWith(playerID, self.forcedHeroName, spawnedUnit:GetGold(), 0)
				Timers:CreateTimer(0.1, function() PlayerResource:GetSelectedHeroEntity(playerID):SetAbsOrigin(self.spawnPositions[playerID]) end)
			elseif self.forcedHeroName == nil then
				return 1
			end
		end)
	end
	if spawnedUnit:IsCourier() and table.getn(self.waitingForCourier) > 0 then
		spawnedUnit:SetOwner(PlayerResource:GetSelectedHeroEntity(table.remove(self.waitingForCourier, 1)))
	end
end

function Farming:OnEntityKilled(event)
	local killedUnit = EntIndexToHScript( event.entindex_killed )
	-- force heroes to respawn on their designated spawn positions
	if killedUnit:IsRealHero() then
		local  playerID = killedUnit:GetPlayerOwnerID()
		killedUnit:SetRespawnPosition(self.spawnPositions[playerID])
	end
end

function Farming:OnHostSetting( event )
	self.finishlineVotes[event.player] = event.finish_line
	self.scoremethodVotes[event.player] = event.score_method
	self.sameheroVotes[event.player] = event.same_hero
	self.instantdeliveryVotes[event.player] = event.instant_delivery
	self.botVotes[event.player] = event.bots
end

function Farming:AggregateVotes()
	local finishline = GetArgMaxVotes(self.finishlineVotes, 0, 1)
	self.goldGoal = 5000 * finishline
	self.scoreMethod = GetArgMaxVotes(self.scoremethodVotes, 0, 1)
	local forceSameHero = GetArgMaxVotes(self.sameheroVotes, nil, nil)
	if forceSameHero == 1 then
		self.forceSameHero = true
	else
		self.forceSameHero = false
	end 	
	local instantDelivery = GetArgMaxVotes(self.instantdeliveryVotes, nil, nil)
	if instantDelivery == 1 then
		self.instantDelivery = true
	else
		self.instantDelivery = false
		GameRules:SetUseUniversalShopMode(false)
	end 
	local botsEnabled = GetArgMaxVotes(self.botVotes, nil, nil)
	if botsEnabled == 1 then
		self.botsEnabled = true
	else
		self.botsEnabled = false
	end 
	CustomGameEventManager:Send_ServerToAllClients( "host_settings_changed", {finishline, self.scoreMethod, forceSameHero, botsEnabled, instantDelivery})
	self:SendOptionNotifications()
	self.resolvedVotes = true
end

function Farming:GetScore(playerID, method)
	if method == nil then
		method = self.scoreMethod
	end
	if method == 1 then
		return PlayerResource:GetTotalEarnedGold(playerID)
	elseif method == 2 then
		return PlayerResource:GetClaimedFarm(playerID, true)
	elseif method == 3 then
		return GetNetWorth(playerID)
	elseif method == 4 then
		return PlayerResource:GetGold(playerID)
	end
end

function Farming:MakeGoldStatsTable()
	local statTable = {}
	for playerID = 0, DOTA_MAX_PLAYERS do
		if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) then
			temp = {}
			for method = 1,4 do
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

function Farming:DecideForcedHero()
	local heroBallots = {}
	for playerID = 0, DOTA_MAX_PLAYERS do
		if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) and PlayerResource:HasSelectedHero(playerID) then
			heroBallots[playerID] = PlayerResource:GetSelectedHeroName(playerID)
		end
	end
	self.forcedHeroName = GetArgMaxVotes(heroBallots, nil, nil)
end

function Farming:SendOptionNotifications()
	Notifications:BottomToAll({text="vote_results", duration=5})
	Timers:CreateTimer(1, function() 
		Notifications:BottomToAll({text="finish_line", duration=29}) 	
		Notifications:BottomToAll({text="gold_"..tostring(self.goldGoal), duration=30, continue=true})	
		Notifications:BottomToAll({text=self:GetScoringString() , duration=30, continue=true})
	end)
	if self.forceSameHero == true then
		Timers:CreateTimer(2, function() Notifications:BottomToAll({text="same_hero" , duration=28}) end)
	end
	if self.instantDelivery == true then
		Timers:CreateTimer(3, function() Notifications:BottomToAll({text="instant_delivery" , duration=27}) end)
	end
end

function Farming:GetScoringString() 
	if self.scoreMethod==1 then
		return '#gold_earned'
	elseif self.scoreMethod==2 then
		return "#gold_creeps"
	elseif self.scoreMethod==3 then
		return "#gold_networth"
	elseif self.scoreMethod==4 then
		return "#gold_held"
	else 
		return ""		
	end
end

function Farming:FilterExecuteOrder(filterTable)
	local units = filterTable["units"]
	local issuer = filterTable["issuer_player_id_const"]
	local order_type = filterTable["order_type"]
	local abilityIndex = filterTable["entindex_ability"]
	local ability = EntIndexToHScript(abilityIndex)
	if units then
		for n,unit_index in pairs(units) do
			local unit = EntIndexToHScript(unit_index)
			local owner_ID = unit:GetPlayerOwnerID()
			if ability ~= nil and ability:GetName() == "item_courier" then
				table.insert(self.waitingForCourier, issuer)
			end
			if PlayerResource:IsValidPlayerID(issuer) and PlayerResource:IsValidPlayerID(owner_ID) then
				if owner_ID ~= issuer then
					return false
				end
			end
		end
	end
	return true
end

function Farming:FindSpawnPositions()
	entities = Entities:FindAllByClassname("info_player_start_goodguys")
	self.unusedSpawnPositions = {}
	for i=1, table.getn(entities) do
		table.insert(self.unusedSpawnPositions, entities[i]:GetAbsOrigin())
	end
end

function SetMaxPlayers()
	if GetMapName() == "across" then
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 3 )
	else
		GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 10 )
	end
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 0 )
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

function GetArgMaxVotes(ballots, ignore, default)
	local freqTable = {}
	for player_id, choice in pairs(ballots) do
		if freqTable[choice] == nil then
			freqTable[choice] = 1
		else
			freqTable[choice] = freqTable[choice] + 1
		end
	end
	local maxVotes = 0
	local argMax = default
	for choice, votes in pairs(freqTable) do
		if votes > maxVotes and choice ~= ignore then
			argMax = choice
			maxVotes = votes
		end
	end
	return argMax
end

