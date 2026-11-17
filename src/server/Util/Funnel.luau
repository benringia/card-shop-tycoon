--!strict
-- Logs a step of the new player's onboarding funnel (Config/Funnel ONBOARDING) to Roblox Analytics by its name, numbered
-- by its place there; once per player per server (Roblox counts each player once per step anyway; this keeps repeats off
-- the wire). Analytics never stops the game: it can't be reached in some Studio sessions.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FunnelConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Funnel"))

local Funnel = {}

local logged: { [Player]: { [string]: boolean } } = {}

function Funnel.step(player: Player, name: string)
	local index = table.find(FunnelConfig.ONBOARDING, name)
	if not index then
		return
	end
	local done = logged[player]
	if not done then
		done = {}
		logged[player] = done
	end
	if done[name] then
		return
	end
	done[name] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, name)
	end)
end

-- Every shop level in Config/Funnel LEVELS passed on the way from `from` to `to`
function Funnel.levels(player: Player, from: number, to: number)
	for _, level in FunnelConfig.LEVELS do
		if level > from and level <= to then
			Funnel.step(player, `Level{level}`)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	logged[player] = nil
end)

return Funnel
