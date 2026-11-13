--!strict
-- Reading your binder in the world (owner 2026-11-13: "Opening the binder should also show the character opening a
-- binder, so that other players know you are opening a binder"; Config/BinderPose): a client says its binder opened
-- or closed (Remotes.BinderShown), and the player's ReadingBinder attribute tells every client to pose them holding
-- an open binder (BinderPoseController). Showing it is refused mid-fight and rate-limited; putting it away always
-- goes through; it's cleared when their character goes and when a fight starts. Cosmetic only: nothing else reads it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BinderPose = require(Shared:WaitForChild("Config"):WaitForChild("BinderPose"))
local BinderPoseRules = require(Shared:WaitForChild("Util"):WaitForChild("BinderPoseRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local BattleService = require(Services:WaitForChild("BattleService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

local BinderReadService = {}

local ATTRIBUTE = "ReadingBinder"
local showLimit = RateLimiter.new(BinderPose.COOLDOWN)

local function onShown(player: Player, show: unknown)
	if not BinderPoseRules.canShow(show, BattleService.IsFighting(player)) then
		return
	end
	if show == true then
		if not showLimit(player) then
			return
		end
		player:SetAttribute(ATTRIBUTE, true)
	else
		player:SetAttribute(ATTRIBUTE, nil)
	end
end

local function watch(player: Player)
	player.CharacterRemoving:Connect(function()
		player:SetAttribute(ATTRIBUTE, nil)
	end)
end

function BinderReadService.Start()
	Remotes.BinderShown.OnServerEvent:Connect(onShown)
	Players.PlayerAdded:Connect(watch) -- not saved state: only the character's pose (CLAUDE.md "Player data")
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- a fight starting puts it away (the binder can't stay open over a fight)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				if player:GetAttribute(ATTRIBUTE) == true and BattleService.IsFighting(player) then
					player:SetAttribute(ATTRIBUTE, nil)
				end
			end
		end
	end)
end

return BinderReadService
