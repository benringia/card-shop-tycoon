--!strict
-- Studio-only chat commands for testing: /cash <amount>, /xp <amount>, /level <level>.
-- Does nothing outside Studio, so live players never get these commands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Levels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Levels"))

local Services = script.Parent :: Instance
local EconomyService = require(Services:WaitForChild("EconomyService"))

type CommandHandler = (player: Player, amount: number) -> ...any

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
		local amount = parseAmount(text)
		if player and amount then
			handler(player, amount)
		end
	end)
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

function DevService.Start()
	if not RunService:IsStudio() then
		return
	end

	local folder = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	addCommand(folder, "cash", EconomyService.AddCash)
	addCommand(folder, "xp", EconomyService.AddXP)
	addCommand(folder, "level", jumpToLevel)
	print("[DevService] Studio commands enabled: /cash <amount>, /xp <amount>, /level <level>")
end

return DevService
