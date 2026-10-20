--!strict
-- Studio-only chat commands for testing: /cash <amount>, /xp <amount>, /level <level>, /testpack,
-- /beastxp <amount> (XP for your best raised beast, or your rarest fresh card).
-- Does nothing outside Studio, so live players never get these commands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Levels = require(Config:WaitForChild("Levels"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local CardService = require(Services:WaitForChild("CardService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PackService = require(Services:WaitForChild("PackService"))

type CommandHandler = (player: Player, text: string) -> ()

local DevService = {}

local function parseAmount(text: string): number?
	local amount = tonumber(string.match(text, "%s+(%S+)") or "")
	if amount == nil or amount ~= amount or amount <= 0 or amount == math.huge then
		return nil
	end
	return amount
end

local function addCommand(folder: Instance, alias: string, handler: CommandHandler)
	local command = Instance.new("TextChatCommand")
	command.Name = "Dev" .. alias
	command.PrimaryAlias = "/" .. alias
	command.Parent = folder

	command.Triggered:Connect(function(textSource: TextSource, text: string)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if player then
			handler(player, text)
		end
	end)
end

-- Wraps an economy function so the command reads its amount from the chat text
local function withAmount(apply: (player: Player, amount: number) -> ...any): CommandHandler
	return function(player: Player, text: string)
		local amount = parseAmount(text)
		if amount then
			apply(player, amount)
		end
	end
end

local function jumpToLevel(player: Player, level: number)
	local required = Levels.XP_REQUIRED[math.floor(level)]
	if not required then
		return
	end
	local current = player:GetAttribute("XP")
	local missing = required - (if typeof(current) == "number" then current else 0)
	if missing > 0 then
		EconomyService.AddXP(player, missing)
	end
end

-- Highest-rarity raised beast (then highest level); otherwise the rarest fresh copy, foil first
local function pickXpTarget(player: Player): CardService.XpTarget?
	local best: CardService.Beast? = nil
	local bestScore = -1
	for _, beast in CardService.GetBeasts(player) do
		local tier = Rarities.Tiers[Cards.ById[beast.cardId].rarity]
		local score = (if tier then tier.order else 0) * 100 + beast.level
		if score > bestScore then
			best, bestScore = beast, score
		end
	end
	if best then
		return best.id
	end
	local stacks = CardService.GetStacks(player)
	for index = #Cards.List, 1, -1 do
		local card = Cards.List[index]
		local owned = stacks[card.id]
		if owned and owned.foil > 0 then
			return { cardId = card.id, foil = true }
		elseif owned and owned.normal > 0 then
			return { cardId = card.id, foil = false }
		end
	end
	return nil
end

local function grantBeastXp(player: Player, amount: number)
	local target = pickXpTarget(player)
	local beast = if target then CardService.AddXP(player, target, amount) else nil
	if not beast then
		Remotes.Notify:FireClient(player, "No card in your binder to give XP to.", true)
		return
	end
	local card = Cards.ById[beast.cardId]
	Remotes.Notify:FireClient(player, `{card.name} is now {BeastRules.describeGrowth(beast.level, beast.stars)}`, false)
end

function DevService.Start()
	if not RunService:IsStudio() then
		return
	end

	local folder = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	addCommand(folder, "cash", withAmount(EconomyService.AddCash))
	addCommand(folder, "xp", withAmount(EconomyService.AddXP))
	addCommand(folder, "level", withAmount(jumpToLevel))
	addCommand(folder, "beastxp", withAmount(grantBeastXp))
	addCommand(folder, "testpack", function(player)
		PackService.OpenTestPack(player)
	end)
	print("[DevService] Studio commands enabled: /cash <amount>, /xp <amount>, /level <level>, /beastxp <amount>, /testpack")
end

return DevService
