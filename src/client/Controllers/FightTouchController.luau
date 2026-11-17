--!strict
-- A phone in a fight (owner 2026-11-17, playthrough: "When battle starts, zoom out to the max ... so that players pet and
-- boss/monster is visible on screen" and "Some of the combat buttons overlapps the jump button"; touch screens only):
-- the camera pulls out to Config/CameraLimits FIGHT_ZOOM as the fight begins (once your own camera is back from any
-- intro holding it) into the open space behind you, a wild fight's looking down over you, and Roblox's jump button
-- steps aside while the fight's buttons hold its corner (jumping is off; Dodge is the fight's move), back as the fight
-- ends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CameraLimits = require(Shared:WaitForChild("Config"):WaitForChild("CameraLimits"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local FightTouchController = {}

local player = Players.LocalPlayer
local ZOOM = CameraLimits.FIGHT_ZOOM
local zoomToken = 0
local fighting = false

-- The camera looking down at least `degrees`, facing the same way (Roblox's camera keeps the angle it's given)
local function tilt(degrees: number)
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 or math.deg(math.asin(-look.Y)) >= degrees then
		return
	end
	local angle = math.rad(degrees)
	local direction = flat.Unit * math.cos(angle) - Vector3.new(0, math.sin(angle), 0)
	local focus = camera.Focus.Position
	camera.CFrame = CFrame.lookAt(focus - direction * (camera.CFrame.Position - focus).Magnitude, focus)
end

-- How far the camera can go back from `focus` along `direction` before a wall (a boss arena's edge, a cliff); the
-- fight's characters and monsters don't count, nor anything you can walk through
local function room(focus: Vector3, direction: Vector3, studs: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(focus, direction * studs, params)
	return if hit then (hit.Position - focus).Magnitude - ZOOM.wallMargin else studs
end

-- The camera out to `studs`, short of a wall behind you (in to it, never nearer than FIGHT_ZOOM.nearest, if it's past
-- one already), a wild fight's looking down too: Roblox's camera moves to a zoom limit set past it, so the floor is
-- raised a moment to push it out (or the cap lowered to pull it in), then put back so the player can zoom again.
-- `intro`: a boss's intro takes the camera a moment after the fight starts and hands it back later (BattleController),
-- so this waits for both or the hand-back undoes it
local function zoomOut(studs: number, boss: boolean, intro: boolean)
	zoomToken += 1
	local token = zoomToken
	task.spawn(function()
		local camera = workspace.CurrentCamera
		if intro then
			local taken = os.clock() + ZOOM.introTakes
			while camera.CameraType == Enum.CameraType.Custom and os.clock() < taken do
				task.wait(0.05)
			end
		end
		local deadline = os.clock() + ZOOM.waitSeconds
		while camera.CameraType ~= Enum.CameraType.Custom and os.clock() < deadline do
			task.wait(0.1)
		end
		task.wait() -- the camera settles back into the player's hands first
		if token ~= zoomToken or not fighting then
			return
		end
		if not boss then
			tilt(ZOOM.wildPitch)
		end
		local open = room(camera.Focus.Position, -camera.CFrame.LookVector, studs)
		local floor, cap = player.CameraMinZoomDistance, player.CameraMaxZoomDistance
		local target = math.clamp(math.max(math.min(studs, open), ZOOM.nearest), floor, math.max(floor, cap))
		local now = (camera.CFrame.Position - camera.Focus.Position).Magnitude
		if target > now + 0.5 then
			player.CameraMinZoomDistance = target
			task.wait(ZOOM.holdSeconds)
			if player.CameraMinZoomDistance == target then
				player.CameraMinZoomDistance = floor
			end
		elseif target < now - 0.5 then
			player.CameraMaxZoomDistance = target
			task.wait(ZOOM.holdSeconds)
			if player.CameraMaxZoomDistance == target then
				player.CameraMaxZoomDistance = cap
			end
		end
	end)
end

-- Roblox's touch jump button hides while jumping is off (its controls watch the humanoid's Jumping state)
local function setJump(on: boolean)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, on)
	end
end

function FightTouchController.Start()
	Remotes.BattleStarted.OnClientEvent:Connect(function(payload: unknown)
		if not UserInputService.TouchEnabled then
			return
		end
		fighting = true
		local info = if typeof(payload) == "table" then payload :: any else {}
		local intro = typeof(info.intro) == "number" and info.intro > 0
		setJump(false)
		local boss = info.boss ~= nil
		if info.prologue ~= true then -- the prologue's lair stages its own camera (its pillars would hide the fight)
			zoomOut(if boss then ZOOM.boss else ZOOM.wild, boss, intro)
		end
	end)
	Remotes.BattleEnded.OnClientEvent:Connect(function()
		if not fighting then
			return
		end
		fighting = false
		zoomToken += 1
		setJump(true)
	end)
	player.CharacterAdded:Connect(function()
		fighting = false -- a new character jumps again
		zoomToken += 1
	end)
end

return FightTouchController
