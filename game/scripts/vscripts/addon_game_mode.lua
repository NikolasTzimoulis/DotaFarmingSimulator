-- Generated from template

if Farming == nil then
	Farming = class({})
end

function Precache( context )
	--[[
		Precache things we know we'll use.  Possible file types include (but not limited to):
			PrecacheResource( "model", "*.vmdl", context )
			PrecacheResource( "soundfile", "*.vsndevts", context )
			PrecacheResource( "particle", "*.vpcf", context )
			PrecacheResource( "particle_folder", "particles/folder", context )
	]]
end

-- Create the game mode when we activate
function Activate()
	GameRules.AddonTemplate = Farming()
	GameRules.AddonTemplate:InitGameMode()
end

function Farming:InitGameMode()
	print( "Farming Simulator is loaded." )
	self.goldGoal = 100000
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, "GlobalThink", 2 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 5 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 0 )
	GameRules:SetSameHeroSelectionEnabled(true)
	GameRules:SetHeroSelectionTime(15)
	GameRules:SetPreGameTime(15)
	GameRules:SetPostGameTime(30)
	GameRules:SetUseUniversalShopMode(true)
	GameRules:GetGameModeEntity():SetAnnouncerDisabled(true)
	ListenToGameEvent( "dota_item_purchased", Dynamic_Wrap( Farming, "OnItemPurchased" ), self )
end

-- Evaluate the state of the game
function Farming:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:CheckVictoryConditions()
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then
		return nil
	end
	return 1
end
function Farming:CheckVictoryConditions()
	for playerID = 0, DOTA_MAX_PLAYERS do
        if PlayerResource:IsValidPlayerID(playerID) and not PlayerResource:IsBroadcaster(playerID) then
			if PlayerResource:GetTotalEarnedGold(playerID) >= self.goldGoal then
				GameRules:SetCustomVictoryMessage(PlayerResource:GetPlayerName(playerID).." WON!")
				GameRules:SetGameWinner(DOTA_TEAM_GOODGUYS)
			end
		end
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