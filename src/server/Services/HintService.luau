--!strict
-- What now? hints' numbers (spec 2026-11-27-what-now-hints-design): the client says when a tip shows, is followed or
-- is closed (Remotes.HintSeen); logged as HintShown, HintDone or HintClosed with the tip's kind, to see whether tips
-- help. The tips themselves are the client's (HintController): nothing here changes the game.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Hints = require(Shared:WaitForChild("Config"):WaitForChild("Hints"))
local HintRules = require(Shared:WaitForChild("Util"):WaitForChild("HintRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local AnalyticsGate = require(ServerUtil:WaitForChild("AnalyticsGate"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local HintService = {}

local EVENTS = { shown = "HintShown", done = "HintDone", closed = "HintClosed" }
local allow = RateLimiter.new(0.5)

function HintService.Start()
	Remotes.HintSeen.OnServerEvent:Connect(function(player: Player, rawKind: unknown, rawOutcome: unknown)
		local kind, outcome = HintRules.readSeen(rawKind, rawOutcome, Hints.ORDER)
		if not kind or not outcome or not allow(player) or not AnalyticsGate.allowed(player) then
			return -- the owner's test save stays out of the numbers
		end
		-- analytics never stops the game (it can't be reached in some Studio sessions)
		pcall(function()
			AnalyticsService:LogCustomEvent(player, EVENTS[outcome], 0, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = kind })
		end)
	end)
end

return HintService
