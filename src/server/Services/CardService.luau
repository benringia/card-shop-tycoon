--!strict
-- Each player's cards: fresh stacks { [cardId] = { normal, foil } } of untouched copies, and raised
-- beasts { [beastId] = Beast } with their own level, XP and stars. A fresh copy becomes a beast the
-- first time it gains XP. Cards on display leave here while shown (PlacementService holds them).
-- The client gets { stacks, beasts } on every change. Saved through DataService.
-- (DESIGN.md calls this CollectionService; renamed to avoid clashing with Roblox's own service.)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Collection = require(Config:WaitForChild("Collection"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

export type Owned = { normal: number, foil: number }
export type PullResult = { cardId: string, foil: boolean }
export type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number }
export type XpTarget = string | { cardId: string, foil: boolean }

type Inventory = { stacks: { [string]: Owned }, beasts: { [string]: Beast } }

local CardService = {}

local inventories: { [Player]: Inventory } = {}
local allowRequest = RateLimiter.new(Collection.REQUEST_COOLDOWN)

local function sync(player: Player)
	local inventory = inventories[player]
	if inventory then
		Remotes.CollectionChanged:FireClient(player, { stacks = inventory.stacks, beasts = inventory.beasts })
	end
end

local function getOwned(stacks: { [string]: Owned }, cardId: string): Owned
	local owned = stacks[cardId]
	if not owned then
		owned = { normal = 0, foil = 0 }
		stacks[cardId] = owned
	end
	return owned
end

-- Removes one fresh copy without syncing; returns false if there is none
local function takeFreshCopy(inventory: Inventory, cardId: string, foil: boolean): boolean
	local owned = inventory.stacks[cardId]
	if not owned then
		return false
	end
	if foil then
		if owned.foil <= 0 then
			return false
		end
		owned.foil -= 1
	else
		if owned.normal <= 0 then
			return false
		end
		owned.normal -= 1
	end
	return true
end

-- Adds a batch of fresh copies (a pack, a purchase, cards coming back off display) and syncs once
function CardService.AddFresh(player: Player, results: { PullResult })
	local inventory = inventories[player]
	if not inventory then
		return
	end
	for _, result in results do
		if Cards.ById[result.cardId] then
			local owned = getOwned(inventory.stacks, result.cardId)
			if result.foil then
				owned.foil += 1
			else
				owned.normal += 1
			end
		end
	end
	sync(player)
end

function CardService.TakeFresh(player: Player, cardId: string, foil: boolean): boolean
	local inventory = inventories[player]
	if not inventory or not takeFreshCopy(inventory, cardId, foil) then
		return false
	end
	sync(player)
	return true
end

-- Adds a raised beast. Keeps its ID unless that ID is already used, then gives it a new one.
function CardService.AddBeast(player: Player, beast: Beast): Beast
	local inventory = inventories[player]
	if not inventory then
		return beast
	end
	if inventory.beasts[beast.id] then
		beast = table.clone(beast)
		beast.id = HttpService:GenerateGUID(false)
	end
	inventory.beasts[beast.id] = beast
	sync(player)
	return beast
end

function CardService.TakeBeast(player: Player, beastId: string): Beast?
	local inventory = inventories[player]
	local beast = if inventory then inventory.beasts[beastId] else nil
	if not inventory or not beast then
		return nil
	end
	inventory.beasts[beastId] = nil
	sync(player)
	return beast
end

function CardService.GetBeast(player: Player, beastId: string): Beast?
	local inventory = inventories[player]
	return if inventory then inventory.beasts[beastId] else nil
end

function CardService.GetBeasts(player: Player): { [string]: Beast }
	local inventory = inventories[player]
	return if inventory then inventory.beasts else {}
end

function CardService.GetStacks(player: Player): { [string]: Owned }
	local inventory = inventories[player]
	return if inventory then inventory.stacks else {}
end

-- Returns a card to the binder the way it left: as its beast, or as a fresh copy
function CardService.GiveCard(player: Player, cardId: string, foil: boolean, beast: Beast?)
	if beast then
		CardService.AddBeast(player, beast)
	else
		CardService.AddFresh(player, { { cardId = cardId, foil = foil } })
	end
end

-- The only way beasts gain XP. A fresh-card target splits one copy off its stack into a new beast.
-- Returns the beast, or nil if the player doesn't have the target.
function CardService.AddXP(player: Player, target: XpTarget, amount: number): Beast?
	local inventory = inventories[player]
	if not inventory then
		return nil
	end
	local beast: Beast?
	if typeof(target) == "string" then
		beast = inventory.beasts[target]
	elseif Cards.ById[target.cardId] and takeFreshCopy(inventory, target.cardId, target.foil) then
		local newBeast: Beast = {
			id = HttpService:GenerateGUID(false),
			cardId = target.cardId,
			foil = target.foil,
			level = 1,
			xp = 0,
			stars = BeastRules.START_STARS,
		}
		inventory.beasts[newBeast.id] = newBeast
		beast = newBeast
	end
	if not beast then
		return nil
	end
	beast.level, beast.xp = BeastRules.applyXp(beast.level, beast.xp, amount)
	sync(player)
	return beast
end

function CardService.IsLoaded(player: Player): boolean
	return inventories[player] ~= nil
end

local function readCount(value: unknown): number
	return if typeof(value) == "number" and value == value and value > 0 then math.floor(value) else 0
end

-- Unknown card IDs, bad counts and invalid beasts in saved data are dropped or clamped
local function load(player: Player, data: PlayerData)
	local stacks: { [string]: Owned } = {}
	for cardId, saved in data.cards do
		if Cards.ById[cardId] and typeof(saved) == "table" then
			local owned = { normal = readCount(saved.normal), foil = readCount(saved.foil) }
			if owned.normal + owned.foil > 0 then
				stacks[cardId] = owned
			end
		end
	end

	local beasts: { [string]: Beast } = {}
	for beastId, saved in data.beasts do
		local clean = BeastRules.sanitize(saved)
		if typeof(beastId) == "string" and clean then
			beasts[beastId] = {
				id = beastId,
				cardId = clean.cardId,
				foil = clean.foil,
				level = clean.level,
				xp = clean.xp,
				stars = clean.stars,
			}
		end
	end

	inventories[player] = { stacks = stacks, beasts = beasts }
	sync(player)
end

local function save(player: Player, data: PlayerData)
	local inventory = inventories[player]
	if not inventory then
		return
	end
	local cards = {}
	for cardId, owned in inventory.stacks do
		if owned.normal + owned.foil > 0 then
			cards[cardId] = { normal = owned.normal, foil = owned.foil }
		end
	end
	local beasts = {}
	for beastId, beast in inventory.beasts do
		beasts[beastId] = { cardId = beast.cardId, foil = beast.foil, level = beast.level, xp = beast.xp, stars = beast.stars }
	end
	data.cards = cards
	data.beasts = beasts
end

function CardService.Start()
	DataService.Register({
		name = "CardService",
		load = load,
		save = save,
		unload = function(player: Player)
			inventories[player] = nil
		end,
	})

	Remotes.RequestCollection.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sync(player)
		end
	end)
end

return CardService
