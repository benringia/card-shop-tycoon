--!strict
-- The ONLY place cash, XP and level change. Other services call these functions.
-- Values are mirrored to player attributes (Cash, XP, Level) so client UI can read them.
-- Loaded from and saved to the player's profile through DataService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EconomyConfig = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Levels = require(Shared:WaitForChild("Config"):WaitForChild("Levels"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local LevelUpRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelUpRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local DataService = require((script.Parent :: Instance):WaitForChild("DataService"))

type PlayerData = DataService.PlayerData

type Wallet = {
	cash: number,
	xp: number,
	level: number,
}

local EconomyService = {}

local wallets: { [Player]: Wallet } = {}
local levelUpHandlers: { (player: Player, from: number, to: number) -> () } = {}

-- Cash is dollars with cents, so round every change to avoid float drift
local function roundCents(amount: number): number
	return math.round(amount * 100) / 100
end

-- Rejects NaN, negatives, zero and infinity
local function isValidAmount(amount: number): boolean
	return amount == amount and amount > 0 and amount < math.huge
end

local function sync(player: Player, wallet: Wallet)
	player:SetAttribute("Cash", wallet.cash)
	player:SetAttribute("XP", wallet.xp)
	player:SetAttribute("Level", wallet.level)
end

local function readNumber(value: unknown, default: number): number
	return if typeof(value) == "number" and value == value and value >= 0 and value < math.huge then value else default
end

local function load(player: Player, data: PlayerData)
	local xp = math.floor(readNumber(data.xp, 0))
	local wallet: Wallet = {
		cash = roundCents(readNumber(data.cash, EconomyConfig.STARTING_CASH)),
		xp = xp,
		-- Derived from XP so a bad saved level can't stick
		level = math.max(EconomyConfig.STARTING_LEVEL, LevelRules.getLevelForXp(xp)),
	}
	wallets[player] = wallet
	sync(player, wallet)
end

local function save(player: Player, data: PlayerData)
	local wallet = wallets[player]
	if not wallet then
		return -- never loaded: keep what's saved
	end
	data.cash = wallet.cash
	data.xp = wallet.xp
	data.level = wallet.level
end

function EconomyService.GetCash(player: Player): number
	local wallet = wallets[player]
	return if wallet then wallet.cash else 0
end

function EconomyService.GetLevel(player: Player): number
	local wallet = wallets[player]
	return if wallet then wallet.level else 0
end

function EconomyService.AddCash(player: Player, amount: number): boolean
	local wallet = wallets[player]
	if not wallet or not isValidAmount(amount) then
		return false
	end
	wallet.cash = roundCents(wallet.cash + amount)
	sync(player, wallet)
	return true
end

-- Called after a level-up (from, to), once per AddXP that crossed one or more levels; never on load
function EconomyService.OnLevelUp(handler: (player: Player, from: number, to: number) -> ())
	table.insert(levelUpHandlers, handler)
end

-- Adds XP and levels the shop up when it crosses a threshold (can skip several levels at once). Each level gained
-- pays its cash reward (Config/Levels, Util/LevelUpRules); the pack and the effect are LevelUpService's.
function EconomyService.AddXP(player: Player, amount: number): boolean
	local wallet = wallets[player]
	if not wallet or not isValidAmount(amount) then
		return false
	end
	wallet.xp += math.floor(amount)

	local oldLevel = wallet.level
	local newLevel = LevelRules.getLevelForXp(wallet.xp)
	if newLevel > oldLevel then
		wallet.level = newLevel
		wallet.cash = roundCents(wallet.cash + LevelUpRules.rewards(Levels, oldLevel, newLevel).cash)
	end
	sync(player, wallet)
	-- One message per level gained, so skipped levels still announce their unlocks
	for level = oldLevel + 1, newLevel do
		Remotes.LevelUp:FireClient(player, level)
	end
	if newLevel > oldLevel then
		for _, handler in levelUpHandlers do
			task.spawn(handler, player, oldLevel, newLevel)
		end
	end
	return true
end

-- Studio testing only (DevService /setxp): sets XP to any total, down as well as up, and the level from it; no
-- rewards, no level-up messages
function EconomyService.SetXPForTesting(player: Player, xp: number)
	local wallet = wallets[player]
	if not wallet or xp ~= xp or xp < 0 or xp == math.huge then
		return
	end
	wallet.xp = math.floor(xp)
	wallet.level = math.max(EconomyConfig.STARTING_LEVEL, LevelRules.getLevelForXp(wallet.xp))
	sync(player, wallet)
end

-- Takes the cash only if the player can afford it
function EconomyService.TrySpend(player: Player, amount: number): boolean
	local wallet = wallets[player]
	if not wallet or not isValidAmount(amount) or wallet.cash < amount then
		return false
	end
	wallet.cash = roundCents(wallet.cash - amount)
	sync(player, wallet)
	return true
end

function EconomyService.Start()
	DataService.Register({
		name = "EconomyService",
		load = load,
		save = save,
		unload = function(player: Player)
			wallets[player] = nil
		end,
	})
end

return EconomyService
