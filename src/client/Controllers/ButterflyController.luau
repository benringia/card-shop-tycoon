--!strict
-- Butterflies (main town only, client side, so they cost the server nothing): a flock round the plaza's healing spring
-- and more at Forest Falls and the east trails' start. Each is a tiny body with two wings that flap; they wander in
-- smooth noise loops round their spot at different heights. Flocks far from the camera stand still, and all of them
-- hide while the extras are off (Util/Extras). Numbers: Config/Town BUTTERFLIES, Config/Ambient BUTTERFLY_RANGE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Ambient = require(Shared:WaitForChild("Config"):WaitForChild("Ambient"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))

type Butterfly = {
	body: Part,
	left: Part,
	right: Part,
	seed: number,
	speed: number,
	radius: number,
	height: number,
	flap: number,
}

local ButterflyController = {}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function piece(parent: Instance, size: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Parent = parent
	return part
end

local function makeButterfly(parent: Instance, index: number, spot: any): Butterfly
	local look = Town.BUTTERFLIES
	local color = rgb(look.COLORS[(index - 1) % #look.COLORS + 1])
	local size = look.SIZE
	local body = piece(parent, Vector3.new(0.12, 0.12, size * 0.6), Color3.fromRGB(40, 30, 45), 0)
	body.Material = Enum.Material.SmoothPlastic
	local wing = Vector3.new(size, 0.04, size * 0.8)
	return {
		body = body,
		left = piece(parent, wing, color, 0.1),
		right = piece(parent, wing, color, 0.1),
		seed = index * 13.37,
		speed = look.SPEED * (0.8 + (index % 5) * 0.1),
		radius = spot.minRadius + (index * 7 % 10) / 10 * (spot.maxRadius - spot.minRadius),
		height = look.MIN_HEIGHT + (index * 3 % 10) / 10 * (look.MAX_HEIGHT - look.MIN_HEIGHT),
		flap = 0,
	}
end

-- Where a butterfly is at time t: a loop round the spring, wobbling in and out and up and down
local function position(fly: Butterfly, centre: Vector3, t: number): Vector3
	local angle = t * fly.speed / fly.radius + fly.seed
	local wobble = math.noise(fly.seed, t * 0.3) * 4
	local radius = fly.radius + wobble
	local height = fly.height + math.noise(fly.seed + 50, t * 0.5) * 2
	return centre + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
end

function ButterflyController.Start()
	if Place.isFrontier() then
		return
	end
	local look = Town.BUTTERFLIES
	local folder = Instance.new("Folder")
	folder.Name = "Butterflies"
	folder.Parent = workspace
	local flocks: { { centre: Vector3, flies: { Butterfly } } } = {}
	local index = 0
	for _, spot in look.SPOTS do
		local flock = { centre = Vector3.new(spot.x, 0, spot.z), flies = {} }
		for _ = 1, spot.count do
			index += 1
			table.insert(flock.flies, makeButterfly(folder, index, spot))
		end
		table.insert(flocks, flock)
	end
	RunService.RenderStepped:Connect(function(dt)
		local enabled = Extras.enabled()
		folder.Parent = if enabled then workspace else nil
		if not enabled then
			return
		end
		local t = os.clock()
		local camera = workspace.CurrentCamera.CFrame.Position
		for _, flock in flocks do
			if (flock.centre - camera).Magnitude <= Ambient.BUTTERFLY_RANGE then
				for _, fly in flock.flies do
					local here = position(fly, flock.centre, t)
					local ahead = position(fly, flock.centre, t + 0.1)
					local facing = CFrame.lookAt(here, ahead)
					fly.flap += dt * look.FLAP_SPEED
					local open = math.rad(10 + 60 * (0.5 + 0.5 * math.sin(fly.flap)))
					local half = look.SIZE / 2
					fly.body.CFrame = facing
					fly.left.CFrame = facing * CFrame.Angles(0, 0, open) * CFrame.new(-half, 0, 0)
					fly.right.CFrame = facing * CFrame.Angles(0, 0, -open) * CFrame.new(half, 0, 0)
				end
			end
		end
	end)
end

return ButterflyController
