--!strict
-- PvP from the stands: players near the arena who aren't fighting get the fight's events (Remotes.ArenaWatch) and see
-- the creatures' charges and attacks like the fighters do (Util/FightFx), with no HUD. The server sends the fight's
-- markers with a watcher's first events and says when the fight ends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local FightFx = require(ClientUtil:WaitForChild("FightFx"))
local CreatureController = require(Controllers:WaitForChild("CreatureController"))

local ArenaWatchController = {}

local markers: { [string]: BasePart } = {}
local dispatcher: FightFx.Dispatcher? = nil

local function stop()
	if dispatcher then
		dispatcher.destroy()
		dispatcher = nil
	end
	markers = {}
end

local function markerFor(id: string): BasePart?
	local marker = markers[id]
	return if marker and marker.Parent then marker else nil
end

function ArenaWatchController.Start()
	Remotes.ArenaWatch.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.ended then
			stop()
			return
		end
		if typeof(payload.markers) == "table" then
			markers = {}
			for id, marker in payload.markers do
				if typeof(id) == "string" and typeof(marker) == "Instance" and marker:IsA("BasePart") then
					markers[id] = marker
				end
			end
		end
		if not dispatcher then
			dispatcher = FightFx.new({
				marker = markerFor,
				creature = CreatureController.GetFightView,
				setCharging = CreatureController.SetCharging,
				pose = CreatureController.Pose,
				dash = CreatureController.Dash,
			})
		end
		local current = dispatcher :: FightFx.Dispatcher
		if typeof(payload.events) == "table" then
			local ok, err = pcall(current.onEvents, payload.events)
			if not ok then
				warn("[ArenaWatchController] fight effect failed:", err)
			end
		end
	end)
	Players.LocalPlayer.CharacterRemoving:Connect(stop)
end

return ArenaWatchController
