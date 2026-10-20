--!strict
-- Each player's cards: plain stacks { [cardId] = { [grade] = { normal, foil } } } of untouched copies,
-- and levelled cards { [beastId] = Beast } with their own level, XP, stars and grade. A plain copy
-- becomes its own card (keeping its grade) the first time it gains XP or a star. Cards on display leave here while shown (PlacementService holds them).
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
export type Stacks = { [string]: { [string]: Owned } } -- cardId -> grade -> counts
export type PullResult = { cardId: string, foil: boolean, grade: string }
export type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
export type XpTarget = string | { cardId: string, foil: boolean, grade: string }

type Inventory = { stacks: Stacks, beasts: { [string]: Beast } }

local CardService = {}

local inventories: { [Player]: Inventory } = {}
local allowRequest = RateLimiter.new(Collection.REQUEST_COOLDOWN)

local function sync(player: Player)
	local inventory = inventories[player]
	if inventory then
		Remotes.CollectionChanged:FireClient(player, { stacks = inventory.stacks, beasts = inventory.beasts })
	end
end

local function getOwned(stacks: Stacks, cardId: string, grade: string): Owned
	local byGrade = stacks[cardId]
	if not byGrade then
		byGrade = {}
		stacks[cardId] = byGrade
	end
	local owned = byGrade[grade]
	if not owned then
		owned = { normal = 0, foil = 0 }
		byGrade[grade] = owned
	end
	return owned
end

-- Removes one plain copy without syncing; returns false if there is none
local function takeFreshCopy(inventory: Inventory, cardId: string, foil: boolean, grade: string): boolean
	local byGrade = inventory.stacks[cardId]
	local owned = if byGrade then byGrade[grade] else nil
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

-- Adds a batch of plain copies (a pack, a purchase, cards coming back off display) and syncs once
function CardService.AddFresh(player: Player, results: { PullResult })
	local inventory = inventories[player]
	if not inventory then
		return
	end
	for _, result in results do
		if Cards.ById[result.cardId] then
			local grade = if BeastRules.isGrade(result.grade) then result.grade else BeastRules.DEFAULT_GRADE
			local owned = getOwned(inventory.stacks, result.cardId, grade)
			if result.foil then
				owned.foil += 1
			else
				owned.normal += 1
			end
		end
	end
	sync(player)
end

-- Takes one plain copy of exactly this card, foil and grade
function CardService.TakeFresh(player: Player, cardId: string, foil: boolean, grade: string): boolean
	local inventory = inventories[player]
	if not inventory or not takeFreshCopy(inventory, cardId, foil, grade) then
		return false
	end
	sync(player)
	return true
end

-- Adds a levelled card. Keeps its ID unless that ID is already used, then gives it a new one.
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

function CardService.GetStacks(player: Player): Stacks
	local inventory = inventories[player]
	return if inventory then inventory.stacks else {}
end

-- Returns a card to the binder the way it left: as its beast, or as a plain copy
function CardService.GiveCard(player: Player, cardId: string, foil: boolean, grade: string, beast: Beast?)
	if beast then
		CardService.AddBeast(player, beast)
	else
		CardService.AddFresh(player, { { cardId = cardId, foil = foil, grade = grade } })
	end
end

-- The only way beasts gain XP. A plain-card target splits one copy off its stack into a new beast.
-- Returns the beast, or nil if the player doesn't have the target.
function CardService.AddXP(player: Player, target: XpTarget, amount: number): Beast?
	local inventory = inventories[player]
	if not inventory then
		return nil
	end
	local beast: Beast?
	if typeof(target) == "string" then
		beast = inventory.beasts[target]
	elseif Cards.ById[target.cardId] and takeFreshCopy(inventory, target.cardId, target.foil, target.grade) then
		local newBeast: Beast = {
			id = HttpService:GenerateGUID(false),
			cardId = target.cardId,
			foil = target.foil,
			level = 1,
			xp = 0,
			stars = BeastRules.START_STARS,
			grade = target.grade,
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
	local stacks: Stacks = {}
	local savedCards: any = if typeof(data.cards) == "table" then data.cards else {}
	for cardId, byGrade in savedCards do
		if Cards.ById[cardId] and typeof(byGrade) == "table" then
			for _, grade in BeastRules.GRADES do
				local saved = byGrade[grade]
				if typeof(saved) == "table" then
					local normal, foil = readCount(saved.normal), readCount(saved.foil)
					if normal + foil > 0 then
						local owned = getOwned(stacks, cardId, grade)
						owned.normal, owned.foil = normal, foil
					end
				end
			end
		end
	end

	local beasts: { [string]: Beast } = {}
	local savedBeasts: any = if typeof(data.beasts) == "table" then data.beasts else {}
	for beastId, saved in savedBeasts do
		local clean = BeastRules.sanitize(saved)
		if typeof(beastId) == "string" and clean then
			beasts[beastId] = {
				id = beastId,
				cardId = clean.cardId,
				foil = clean.foil,
				level = clean.level,
				xp = clean.xp,
				stars = clean.stars,
				grade = clean.grade,
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
	for cardId, byGrade in inventory.stacks do
		for grade, owned in byGrade do
			if owned.normal + owned.foil > 0 then
				cards[cardId] = cards[cardId] or {}
				cards[cardId][grade] = { normal = owned.normal, foil = owned.foil }
			end
		end
	end
	local beasts = {}
	for beastId, beast in inventory.beasts do
		beasts[beastId] = {
			cardId = beast.cardId,
			foil = beast.foil,
			level = beast.level,
			xp = beast.xp,
			stars = beast.stars,
			grade = beast.grade,
		}
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
