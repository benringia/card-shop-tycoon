--!strict
-- Grid maths shared by the client ghost preview and the server's validation, so both agree.
-- Cells are in plot-local space: x runs across the plot, z runs from the front (street) edge to the back.
-- Anything on a plot with the BlocksPlacement attribute is treated as an obstacle.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local PlotConfig = require(Config:WaitForChild("Plots"))
local PlacementConfig = require(Config:WaitForChild("Placement"))

export type Rect = { x: number, z: number, w: number, d: number }

local GRID = PlacementConfig.GRID_SIZE
local CELLS_X = PlotConfig.WIDTH // GRID
local CELLS_Z = PlotConfig.DEPTH // GRID
local EPSILON = 1e-3

local PlacementGrid = {}

-- Footprint in cells; width and depth swap on 90° and 270° turns
function PlacementGrid.getFootprint(size: Vector3, rotation: number): (number, number)
	local w = math.ceil(size.X / GRID - EPSILON)
	local d = math.ceil(size.Z / GRID - EPSILON)
	if rotation % 2 == 1 then
		return d, w
	end
	return w, d
end

-- Shelf CFrame relative to the plot CFrame (floor centre). Rotation 0 faces the street.
function PlacementGrid.getLocalCFrame(size: Vector3, gridX: number, gridZ: number, rotation: number): CFrame
	local w, d = PlacementGrid.getFootprint(size, rotation)
	local x = -PlotConfig.WIDTH / 2 + (gridX + w / 2) * GRID
	local z = -PlotConfig.DEPTH / 2 + (gridZ + d / 2) * GRID
	local y = (PlotConfig.FLOOR_THICKNESS + size.Y) / 2
	return CFrame.new(x, y, z) * CFrame.Angles(0, rotation * math.pi / 2, 0)
end

-- Cell that centres a w×d footprint on a world position, clamped inside the plot
function PlacementGrid.worldToCell(plotCFrame: CFrame, worldPosition: Vector3, w: number, d: number): (number, number)
	local rel = plotCFrame:PointToObjectSpace(worldPosition)
	local gx = math.round((rel.X + PlotConfig.WIDTH / 2) / GRID - w / 2)
	local gz = math.round((rel.Z + PlotConfig.DEPTH / 2) / GRID - d / 2)
	return math.clamp(gx, 0, CELLS_X - w), math.clamp(gz, 0, CELLS_Z - d)
end

function PlacementGrid.isInBounds(rect: Rect): boolean
	return rect.x >= 0 and rect.z >= 0 and rect.x + rect.w <= CELLS_X and rect.z + rect.d <= CELLS_Z
end

function PlacementGrid.overlaps(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.z < b.z + b.d and b.z < a.z + a.d
end

-- Cells covered by a part, grown by `margin` cells on every side
function PlacementGrid.partToRect(plotCFrame: CFrame, part: BasePart, margin: number): Rect
	local rel = plotCFrame:ToObjectSpace(part.CFrame)
	local size = part.Size
	local halfX = (math.abs(rel.RightVector.X) * size.X + math.abs(rel.UpVector.X) * size.Y + math.abs(rel.LookVector.X) * size.Z) / 2
	local halfZ = (math.abs(rel.RightVector.Z) * size.X + math.abs(rel.UpVector.Z) * size.Y + math.abs(rel.LookVector.Z) * size.Z) / 2

	local minX = math.floor((rel.X - halfX + PlotConfig.WIDTH / 2) / GRID + EPSILON) - margin
	local maxX = math.ceil((rel.X + halfX + PlotConfig.WIDTH / 2) / GRID - EPSILON) + margin
	local minZ = math.floor((rel.Z - halfZ + PlotConfig.DEPTH / 2) / GRID + EPSILON) - margin
	local maxZ = math.ceil((rel.Z + halfZ + PlotConfig.DEPTH / 2) / GRID - EPSILON) + margin

	return { x = minX, z = minZ, w = maxX - minX, d = maxZ - minZ }
end

-- Every obstacle on the plot. Pass ignoreId (a ShelfUid or FixtureId) when moving something
-- so it doesn't block itself.
function PlacementGrid.getBlockedRects(plotModel: Model, plotCFrame: CFrame, ignoreId: string?): { Rect }
	local rects: { Rect } = {}
	for _, instance in plotModel:GetDescendants() do
		if not instance:IsA("BasePart") or not instance:GetAttribute("BlocksPlacement") then
			continue
		end
		local uid = instance:GetAttribute("ShelfUid")
		local id = uid or instance:GetAttribute("FixtureId")
		if id ~= nil and id == ignoreId then
			continue
		end
		-- Shelves may sit side by side; fixed fixtures keep a walking gap
		local margin = if uid ~= nil then 0 else PlacementConfig.RESERVED_MARGIN
		table.insert(rects, PlacementGrid.partToRect(plotCFrame, instance, margin))
	end
	return rects
end

function PlacementGrid.isFree(blocked: { Rect }, size: Vector3, gridX: number, gridZ: number, rotation: number): boolean
	local w, d = PlacementGrid.getFootprint(size, rotation)
	local rect: Rect = { x = gridX, z = gridZ, w = w, d = d }
	if not PlacementGrid.isInBounds(rect) then
		return false
	end
	for _, other in blocked do
		if PlacementGrid.overlaps(rect, other) then
			return false
		end
	end
	return true
end

return PlacementGrid
