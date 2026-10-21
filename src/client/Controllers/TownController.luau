--!strict
-- Hides the roof of the shop you're standing in, on this client only, so the camera can see inside; roofs show
-- from the street (main town spec). Main game only. Plots stream in and out, so roofs are looked up every tick.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Town = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Town"))

local TownController = {}

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
	for _, plot in plots:GetChildren() do
		local roof = plot:FindFirstChild("Roof")
		local floor = plot:FindFirstChild("Floor")
		if roof and roof:IsA("BasePart") then
			local inside = root ~= nil and floor ~= nil and floor:IsA("BasePart") and isInside(floor, root.Position)
			roof.LocalTransparencyModifier = if inside then 1 else 0
		end
	end
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
