--!strict
-- Hides the roof of the shop you're standing in, on this client only, so the camera can see inside; roofs show
-- from the street (main town spec). Main game only. Plots stream in and out, so roofs are looked up every tick.
-- A hidden part casts no shadow, so inside a shop this client's lighting dims a little instead (indoor shade).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local TownController = {}

local SHADE_TWEEN = TweenInfo.new(Town.INDOOR_SHADE.SECONDS)

local shaded = false
local outdoorExposure = 0

-- Dims this client's lighting while it stands in a shop, back to normal outside
local function setShade(inside: boolean)
	if inside == shaded then
		return
	end
	if inside then
		outdoorExposure = Lighting.ExposureCompensation
	end
	shaded = inside
	local exposure = if inside then outdoorExposure + Town.INDOOR_SHADE.EXPOSURE else outdoorExposure
	TweenService:Create(Lighting, SHADE_TWEEN, { ExposureCompensation = exposure }):Play()
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
	local inAnyShop = false
	for _, plot in plots:GetChildren() do
		local roof = plot:FindFirstChild("Roof")
		local floor = plot:FindFirstChild("Floor")
		if roof and roof:IsA("BasePart") then
			local inside = root ~= nil and floor ~= nil and floor:IsA("BasePart") and isInside(floor, root.Position)
			roof.LocalTransparencyModifier = if inside then 1 else 0
			inAnyShop = inAnyShop or inside
		end
	end
	setShade(inAnyShop)
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
