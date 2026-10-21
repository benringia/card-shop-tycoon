--!strict
-- Hides the roof of the shop you're standing in, on this client only, so the camera can see inside; roofs show
-- from the street (main town spec). Main game only. Plots stream in and out, so roofs are looked up every tick.
-- A hidden part casts no shadow, so a stand-in roof sits further toward the sun: its shadow lands on the shop,
-- keeping the shade inside, while it stays up out of the camera's view.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local TownController = {}

local shadeCaster: Part? = nil

-- Puts the stand-in roof up toward the sun from `roof`, or removes it when no roof is hidden
local function setShade(roof: BasePart?)
	if not roof then
		if shadeCaster then
			shadeCaster:Destroy()
			shadeCaster = nil
		end
		return
	end
	local caster = shadeCaster
	if not caster then
		local created = Instance.new("Part")
		created.Name = "RoofShade"
		created.Anchored = true
		created.CanCollide = false
		created.CanQuery = false
		created.CanTouch = false
		created.CastShadow = true
		created.Parent = workspace
		shadeCaster = created
		caster = created
	end
	caster.Size = roof.Size
	caster.Color = roof.Color
	caster.CFrame = roof.CFrame + Lighting:GetSunDirection() * Town.ROOF_SHADE_LIFT
end

local function isInside(floor: BasePart, position: Vector3): boolean
	local localPosition = floor.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= floor.Size.X / 2 and math.abs(localPosition.Z) <= floor.Size.Z / 2
end

local function update()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hidden: BasePart? = nil
	for _, plot in plots:GetChildren() do
		local roof = plot:FindFirstChild("Roof")
		local floor = plot:FindFirstChild("Floor")
		if roof and roof:IsA("BasePart") then
			local inside = root ~= nil and floor ~= nil and floor:IsA("BasePart") and isInside(floor, root.Position)
			roof.LocalTransparencyModifier = if inside then 1 else 0
			if inside then
				hidden = roof
			end
		end
	end
	setShade(hidden)
end

function TownController.Start()
	task.spawn(function()
		while true do
			update()
			task.wait(Town.ROOF_CHECK_SECONDS)
		end
	end)
end

return TownController
