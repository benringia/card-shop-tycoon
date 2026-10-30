--!strict
-- Trees near the camera lean gently in the wind, on this client only (Portal Worlds spec): each tree's canopy (its
-- highest mesh; a one-mesh tree sways whole from its foot) turns a little about a point low in the canopy, moved in one
-- BulkMoveTo a few times a second. Trees stream in and out, so the list is rescanned now and then. Off (trees back at
-- rest) while the extras are off (Util/Extras). Numbers in Config/Ambient SWAY.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ambient = require(Shared:WaitForChild("Config"):WaitForChild("Ambient"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Extras = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("Extras"))

type Swayer = { part: BasePart, pivot: CFrame, offset: CFrame, phase: number }

local TREES = {
	TreeA = true,
	TreeB = true,
	TreeC = true,
	TreeD = true,
	Pine = true,
	PineA = true,
	PineB = true,
	CherryTree = true,
	GiantTree = true,
	SnowPine = true,
}
local ROOTS = { "TownDecor", "PlazaGarden", "Scenery" }
local CANOPY_PIVOT = 0.4 -- of the canopy's height above its bottom: where it turns

local TreeSwayController = {}

local swayers: { [BasePart]: Swayer } = {}

local function register(model: Model)
	local top: MeshPart?, low: MeshPart? = nil, nil
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			if not top or part.Position.Y > top.Position.Y then
				top = part
			end
			if not low or part.Position.Y < low.Position.Y then
				low = part
			end
		end
	end
	if not top or swayers[top] then
		return
	end
	local canopy = top :: MeshPart
	local bottom = canopy.Position.Y - canopy.Size.Y / 2
	local pivotY = if canopy == low then bottom else bottom + canopy.Size.Y * CANOPY_PIVOT
	local pivot = CFrame.new(canopy.Position.X, pivotY, canopy.Position.Z)
	swayers[canopy] = { part = canopy, pivot = pivot, offset = pivot:ToObjectSpace(canopy.CFrame), phase = math.random() * 6 }
end

local function scan()
	for part in swayers do
		if not part:IsDescendantOf(workspace) then
			swayers[part] = nil
		end
	end
	for _, name in ROOTS do
		local root = workspace:FindFirstChild(name)
		if root then
			for _, model in root:GetDescendants() do
				if model:IsA("Model") and TREES[model.Name] then
					register(model)
				end
			end
		end
	end
end

local function restAll()
	local parts, cframes = {}, {}
	for part, swayer in swayers do
		table.insert(parts, part)
		table.insert(cframes, swayer.pivot * swayer.offset)
	end
	workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function TreeSwayController.Start()
	if Place.isFrontier() or Place.isDungeon() then
		return
	end
	local sway = Ambient.SWAY
	local sinceScan, sinceSway = math.huge, 0
	local resting = false
	RunService.Heartbeat:Connect(function(dt)
		sinceScan += dt
		if sinceScan >= sway.SCAN_SECONDS then
			sinceScan = 0
			scan()
		end
		if not Extras.enabled() then
			if not resting then
				restAll()
				resting = true
			end
			return
		end
		resting = false
		sinceSway += dt
		if sinceSway < 1 / sway.HZ then
			return
		end
		sinceSway = 0
		local now = os.clock()
		local camera = workspace.CurrentCamera.CFrame.Position
		local parts, cframes = {}, {}
		for part, swayer in swayers do
			if (swayer.pivot.Position - camera).Magnitude < sway.RANGE then
				local s = now * sway.SPEED + swayer.phase
				table.insert(parts, part)
				table.insert(cframes, swayer.pivot * CFrame.Angles(math.sin(s) * sway.ANGLE, 0, math.cos(s * 0.8) * sway.ANGLE * 0.8) * swayer.offset)
			end
		end
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return TreeSwayController
