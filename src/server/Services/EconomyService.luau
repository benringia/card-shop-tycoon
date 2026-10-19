--!strict
-- The ONLY place cash, XP and level change. Other services call these functions.
-- Values are mirrored to player attributes (Cash, XP, Level) so client UI can read them.
-- No saving yet: DataService will load and store these later.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))

type Wallet = {
	cash: number,
	xp: number,
	level: number,
}

local EconomyService = {}

local wallets: { [Player]: Wallet } = {}

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

local function setup(player: Player)
	if wallets[player] then
		return
	end
	local wallet: Wallet = {
		cash = EconomyConfig.STARTING_CASH,
		xp = 0,
		level = EconomyConfig.STARTING_LEVEL,
	}
	wallets[player] = wallet
	sync(player, wallet)
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

-- Level-ups from XP come with the levels system
function EconomyService.AddXP(player: Player, amount: number): boolean
	local wallet = wallets[player]
	if not wallet or not isValidAmount(amount) then
		return false
	end
	wallet.xp += math.floor(amount)
	sync(player, wallet)
	return true
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
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		wallets[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return EconomyService
