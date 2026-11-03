--!strict
-- Shop level-ups beyond the cash (spec 2026-11-04-round4-design sections 8-9): the pack every PACK_EVERY levels
-- (Config/Levels PACK_ITEM, a Bag item) and opening those packs from the Bag (remote OpenBagPack). EconomyService
-- pays the cash and calls OnLevelUp; this service never changes cash or XP.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local Levels = require(Config:WaitForChild("Levels"))
local Items = require(Config:WaitForChild("Items"))
local ItemRules = require(Util:WaitForChild("ItemRules"))
local LevelUpRules = require(Util:WaitForChild("LevelUpRules"))
local Place = require(Util:WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

local LevelUpService = {}

local allowOpen = RateLimiter.new(Levels.PACK_OPEN_COOLDOWN)
-- PackService runs only in the main game; required there in Start
local PackService: { OpenItemPack: (player: Player, productId: string) -> boolean }? = nil

local function onLevelUp(player: Player, from: number, to: number)
	local packs = LevelUpRules.rewards(Levels, from, to).packs
	if packs > 0 then
		ItemService.GiveItem(player, Levels.PACK_ITEM, packs)
	end
end

-- A Bag pack: only in the main game (PackService and the opening stage live there), never mid-fight
local function onOpenBagPack(player: Player, itemId: unknown)
	if not allowOpen(player) then
		return
	end
	local productId = ItemRules.openablePack(Items, itemId)
	if not productId then
		return
	end
	if BattleService.IsFighting(player) then
		Remotes.Notify:FireClient(player, "Open it after the fight.", true)
		return
	end
	if not ItemService.TakeItem(player, itemId :: string, 1) then
		return
	end
	if not PackService or not PackService.OpenItemPack(player, productId) then
		ItemService.GiveItem(player, itemId :: string, 1) -- not a pack after all: give it back
	end
end

function LevelUpService.Start()
	EconomyService.OnLevelUp(onLevelUp)
	if not Place.isFrontier() and not Place.isDungeon() then
		PackService = require(Services:WaitForChild("PackService")) :: any
		Remotes.OpenBagPack.OnServerEvent:Connect(onOpenBagPack)
	end
end

return LevelUpService
