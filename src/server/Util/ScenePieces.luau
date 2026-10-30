--!strict
-- Small building blocks for the code-built scenery (SceneryService, PlazaBuild): an invisible anchor part, a plain
-- anchored part, and a scaled copy of one of the town's prop models (ReplicatedStorage.PropModels).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ScenePieces = {}

-- An invisible part to hang effects, lights and sounds on
function ScenePieces.anchor(parent: Instance, name: string, position: Vector3, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size or Vector3.one
	part.Position = position
	part.Parent = parent
	return part
end

function ScenePieces.piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, surface: Enum.Material, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Shape = shape or Enum.PartType.Block
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = surface
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A copy of a prop model (spot.model) scaled to spot.height, turned spot.yaw degrees and stood with its bottom on
-- `ground` at (spot.x, spot.z). Some props are a single mesh part (rocks, roots, lily pads): wrapped in a model.
function ScenePieces.placeModel(parent: Instance, spot: any, label: string, ground: number): Model?
	local models = ReplicatedStorage:FindFirstChild("PropModels")
	local source = models and models:FindFirstChild(spot.model)
	local model: Model
	if source and source:IsA("Model") then
		model = source:Clone()
	elseif source and source:IsA("BasePart") then
		model = Instance.new("Model")
		local part = source:Clone()
		part.Parent = model
		model.PrimaryPart = part
	else
		warn(`[ScenePieces] no prop model {spot.model}`)
		return nil
	end
	model.Name = label
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * spot.height / size.Y)
	model:PivotTo(CFrame.new(spot.x, ground, spot.z) * CFrame.Angles(0, math.rad(spot.yaw or 0), 0))
	local box, boxSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() - Vector3.new(0, box.Position.Y - boxSize.Y / 2 - ground, 0))
	model.Parent = parent
	return model
end

return ScenePieces
