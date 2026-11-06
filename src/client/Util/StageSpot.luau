--!strict
-- Puts a client-only stage (the binder, the card view, the pack opening) right above the player (Config/Stages,
-- Util/StageRules): the first height whose box holds nothing of the world, so the camera never leaves the light Roblox
-- keeps round it. A far stage made the shop look lit like the open air for ~20 s after it closed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stages = require(Shared:WaitForChild("Config"):WaitForChild("Stages"))
local StageRules = require(Shared:WaitForChild("Util"):WaitForChild("StageRules"))

local StageSpot = {}

-- The boxes stages hold now, by stage: a stage's own parts can't be found by a box query (CanQuery off), and the card
-- view opens over the binder
local claimed: { [string]: { centre: Vector3, size: Vector3 } } = {}

local function overlaps(centre: Vector3, size: Vector3, other: { centre: Vector3, size: Vector3 }): boolean
	local gap = (centre - other.centre):Abs() * 2
	local reach = size + other.size
	return gap.X < reach.X and gap.Y < reach.Y and gap.Z < reach.Z
end

-- The player's feet, or the camera's focus without a character
local function base(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.Focus.Position else nil
end

-- Whether a box of `size` round `centre` is clear: no part (but `exclude`) and no terrain under its middle or corners
local function clear(centre: Vector3, size: Vector3, exclude: { Instance }): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclude
	overlap.RespectCanCollide = false
	if #workspace:GetPartBoundsInBox(CFrame.new(centre), size, overlap) > 0 then
		return false
	end
	-- Terrain isn't counted as a part there: rays down through the box find a hill or a cliff
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { workspace.Terrain }
	local half = size / 2
	for _, corner in { Vector2.zero, Vector2.new(1, 1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(-1, -1) } do
		local top = centre + Vector3.new(corner.X * half.X, half.Y, corner.Y * half.Z)
		if workspace:Raycast(top, Vector3.new(0, -size.Y, 0), rays) then
			return false
		end
	end
	return true
end

-- Where `stage`'s centre goes: straight above the player at a clear height, else `far`. The box the stage needs clear
-- is `size`, its middle `offset` from the stage's centre; `ignore`: the stage's own parts. The stage holds that box
-- (other stages keep out of it) until release(stage)
function StageSpot.near(stage: string, size: Vector3, offset: Vector3, far: Vector3, ignore: { Instance }): Vector3
	claimed[stage] = nil
	local from = base()
	local spot = far
	if from then
		local exclude = table.clone(ignore)
		table.insert(exclude, workspace.Terrain)
		local character = Players.LocalPlayer.Character
		if character then
			table.insert(exclude, character)
		end
		local picked = StageRules.pick({ x = from.X, y = from.Y, z = from.Z }, Stages.LIFTS, function(at)
			local centre = Vector3.new(at.x, at.y, at.z) + offset
			for _, other in claimed do
				if overlaps(centre, size, other) then
					return false
				end
			end
			return clear(centre, size, exclude)
		end, { x = far.X, y = far.Y, z = far.Z })
		spot = Vector3.new(picked.x, picked.y, picked.z)
	end
	claimed[stage] = { centre = spot + offset, size = size }
	return spot
end

function StageSpot.release(stage: string)
	claimed[stage] = nil
end

-- Moves every part under `container` the way the stage moves, from `from` to `to`
function StageSpot.shift(container: Instance, from: CFrame, to: CFrame)
	if from == to then
		return
	end
	local delta = to * from:Inverse()
	for _, part in container:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = delta * part.CFrame
		end
	end
end

return StageSpot
