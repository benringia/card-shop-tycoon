--!strict
-- Swappable town props (main town spec, docs/props.md). A slot's model comes from ReplicatedStorage.PropModels
-- (assets/props/<Slot>.rbxm and its variants); a missing, empty, too-big or broken one gets a part-built stand-in,
-- so the town never breaks. Placed props are stripped of scripts, scaled, anchored and stood on the given spot.
-- Shared: the server builds the town and shops with it, the client builds placement ghosts the same way.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local PropFit = require(Shared:WaitForChild("Util"):WaitForChild("PropFit"))
local TownLayout = require(Shared:WaitForChild("Util"):WaitForChild("TownLayout"))

local Props = {}

local STRIPPED = { "LuaSourceContainer", "ProximityPrompt", "ClickDetector", "Sound", "Tool" }
local MIN_HEIGHT = 0.05

local WOOD = Color3.fromRGB(125, 90, 60)
local DARK_WOOD = Color3.fromRGB(95, 65, 45)
local STONE = Color3.fromRGB(150, 145, 140)
local LAMP_GLOW = Color3.fromRGB(255, 220, 150)

local variantCache: { [string]: { Instance } } = {}

-- Free models can carry scripts and noise: none of it may run or play
function Props.strip(root: Instance)
	for _, descendant in root:GetDescendants() do
		for _, className in STRIPPED do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
end

function Props.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function countParts(model: Instance): number
	local count = 0
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

-- A source is a Model, or a lone part (some packs save single MeshParts)
local function isUsable(source: Instance): boolean
	if source:IsA("BasePart") then
		return source.Size.Y >= MIN_HEIGHT
	end
	if not source:IsA("Model") then
		return false
	end
	local parts = countParts(source)
	if parts == 0 or parts > Town.MAX_PROP_PARTS then
		return false
	end
	local ok, _, size = pcall(function()
		return (source :: Model):GetBoundingBox()
	end)
	return ok and size.Y >= MIN_HEIGHT
end

-- Every usable source model for a slot, sorted by name so every server picks the same one
local function getVariants(slot: string): { Instance }
	local cached = variantCache[slot]
	if cached then
		return cached
	end
	local found: { Instance } = {}
	local folder = ReplicatedStorage:FindFirstChild("PropModels")
	if folder then
		for _, child in folder:GetChildren() do
			if TownLayout.isVariant(slot, child.Name, Town.SLOTS) and isUsable(child) then
				table.insert(found, child)
			end
		end
	end
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	variantCache[slot] = found
	return found
end

local function addPart(model: Model, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Cylinders run along X: this stands one up
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Stand-ins built around the origin, bottom at y = 0, front facing -Z
local function buildFallback(slot: string, height: number, size: Vector3?, variant: number): Model
	local model = Instance.new("Model")
	local block, cylinder = Enum.PartType.Block, Enum.PartType.Cylinder
	if slot == "Lamp" then
		addPart(model, cylinder, Vector3.new(height * 0.9, 0.5, 0.5), CFrame.new(0, height * 0.45, 0) * UPRIGHT, DARK_WOOD, Enum.Material.Wood)
		local head = addPart(model, block, Vector3.new(1.4, height * 0.1, 1.4), CFrame.new(0, height * 0.95, 0), LAMP_GLOW, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = LAMP_GLOW
		light.Range = 16
		light.Brightness = 1
		light.Parent = head
	elseif slot == "Bench" then
		addPart(model, block, Vector3.new(5, 0.4, 1.6), CFrame.new(0, height * 0.5, 0), WOOD, Enum.Material.Wood)
		addPart(model, block, Vector3.new(5, height * 0.5, 0.3), CFrame.new(0, height * 0.75, 0.7), WOOD, Enum.Material.Wood)
		for _, x in { -2.2, 2.2 } do
			addPart(model, block, Vector3.new(0.3, height * 0.5, 1.4), CFrame.new(x, height * 0.25, 0), DARK_WOOD, Enum.Material.Wood)
		end
	elseif slot == "Fence" then
		local length = Town.LAYOUT.FENCE_SECTION
		for _, x in { -length / 2 + 0.25, length / 2 - 0.25 } do
			addPart(model, block, Vector3.new(0.5, height, 0.5), CFrame.new(x, height / 2, 0), DARK_WOOD, Enum.Material.Wood)
		end
		for _, y in { height * 0.4, height * 0.8 } do
			addPart(model, block, Vector3.new(length, 0.35, 0.25), CFrame.new(0, y, 0), WOOD, Enum.Material.Wood)
		end
	elseif slot == "Portal" then
		local width = height * 0.85
		for _, x in { -width / 2, width / 2 } do
			addPart(model, block, Vector3.new(1.5, height, 1.5), CFrame.new(x, height / 2, 0), STONE, Enum.Material.Slate)
		end
		addPart(model, block, Vector3.new(width + 1.5, 1.5, 1.5), CFrame.new(0, height - 0.75, 0), STONE, Enum.Material.Slate)
	else
		-- Register, CounterDecor, Shelf and anything new: a plain box
		local box = size or Vector3.new(height, height, height)
		addPart(model, block, box, CFrame.new(0, box.Y / 2, 0), WOOD, Enum.Material.Wood)
	end
	model.WorldPivot = CFrame.new()
	return model
end

local function toSize(vector: Vector3): PropFit.Size
	return { x = vector.X, y = vector.Y, z = vector.Z }
end

-- Stretches a model of plain straight blocks to fill `fit` exactly, in its pivot's space. False (model untouched)
-- when any part is a mesh, a non-block shape or turned at an angle: those can only scale evenly.
local function stretch(model: Model, boxSize: Vector3, fit: Vector3, yaw: number): boolean
	local parts: { Part } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if not descendant:IsA("Part") or descendant.Shape ~= Enum.PartType.Block then
				return false
			end
			table.insert(parts, descendant)
		elseif descendant:IsA("SpecialMesh") or descendant:IsA("Decal") or descendant:IsA("Texture") then
			return false
		end
	end
	local pivot = model.WorldPivot
	local relatives: { CFrame } = {}
	for index, part in parts do
		local relative = pivot:ToObjectSpace(part.CFrame)
		if not PropFit.isAxisAligned({ toSize(relative.RightVector), toSize(relative.UpVector), toSize(relative.LookVector) }) then
			return false
		end
		relatives[index] = relative
	end
	local sx, sy, sz = PropFit.stretchFactors(toSize(boxSize), toSize(fit), yaw)
	local scale = Vector3.new(sx, sy, sz)
	for index, part in parts do
		local relative = relatives[index]
		-- How much each of the part's own axes grows, given where it points in pivot space
		local function grow(axis: Vector3): number
			return (axis * scale).Magnitude
		end
		part.Size = Vector3.new(part.Size.X * grow(relative.RightVector), part.Size.Y * grow(relative.UpVector), part.Size.Z * grow(relative.LookVector))
		part.CFrame = pivot * (CFrame.new(relative.Position * scale) * relative.Rotation)
	end
	return true
end

-- Clone a source model and size it: to `height`, or (when `fit` is given) to the largest size that fits inside it
local function prepareModel(source: Instance, height: number, fit: Vector3?, slotYaw: number?, canStretch: boolean, roll: number?): Model
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	else
		model = Instance.new("Model")
		local part = source:Clone()
		part.Parent = model
		local yaw = source:GetAttribute("YawOffset")
		if yaw ~= nil then
			model:SetAttribute("YawOffset", yaw)
		end
	end
	Props.strip(model)
	local yaw = PropFit.resolveYaw(model:GetAttribute("YawOffset"), slotYaw) -- degrees, for models that don't face -Z
	-- Measure along world axes: some packs save a tipped pivot (Z-up exports), which would lay the model down
	model.PrimaryPart = nil
	model.WorldPivot = CFrame.new(model:GetPivot().Position)
	if roll and roll ~= 0 then
		-- Stand the model up first (e.g. a landscape board turned portrait), then measure it upright
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, 0, math.rad(roll)))
		model.WorldPivot = CFrame.new(model:GetPivot().Position)
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	model.WorldPivot = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0) * CFrame.Angles(0, math.rad(yaw), 0)
	if fit and canStretch and stretch(model, boxSize, fit, yaw) then
		return model
	end
	local ratio = if fit
		then PropFit.fitRatio({ x = boxSize.X, y = boxSize.Y, z = boxSize.Z }, { x = fit.X, y = fit.Y, z = fit.Z }, yaw)
		else height / math.max(boxSize.Y, MIN_HEIGHT)
	model:ScaleTo(model:GetScale() * ratio)
	return model
end

-- True when assets/props holds a usable model for this slot (no stand-in needed)
function Props.hasModel(slot: string): boolean
	return #getVariants(slot) > 0
end

-- The size a slot's model will have before scaling (first variant, turned by its yaw), or nil with no model
function Props.getSourceSize(slot: string): Vector3?
	local source = getVariants(slot)[1]
	if not source then
		return nil
	end
	local info = Town.SLOTS[slot]
	local ok, model = pcall(prepareModel, source, 1, nil, if info then (info :: any).yaw else nil, false, if info then (info :: any).roll else nil)
	if not ok then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local scale = model:GetScale()
	model:Destroy()
	return size / scale
end

-- Paints the parts a prop marks for its owner's colour ("COLOUR ME")
function Props.tint(model: Model, color: Color3)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and PropFit.isTintPart(descendant.Name) then
			descendant.Color = color
			if descendant:IsA("UnionOperation") then
				descendant.UsePartColor = true
			end
		end
	end
end

local function finish(model: Model, slot: string, at: CFrame, parent: Instance): Model
	local collide = Town.SLOTS[slot] ~= nil and Town.SLOTS[slot].collide
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = collide
			descendant.CanTouch = false
			descendant.CanQuery = collide
		end
	end
	model.Name = slot
	model:PivotTo(at)
	model.Parent = parent
	return model
end

local function make(slot: string, at: CFrame, parent: Instance, variant: number?, fit: Vector3?): Model
	local info = Town.SLOTS[slot]
	local height = if info then info.height else 1
	local index = variant or 1
	local variants = getVariants(slot)
	if #variants > 0 then
		local source = variants[(index - 1) % #variants + 1]
		local ok, model = pcall(prepareModel, source, height, fit, if info then (info :: any).yaw else nil, info ~= nil and (info :: any).stretch == true, if info then (info :: any).roll else nil)
		if ok then
			return finish(model, slot, at, parent)
		end
		warn(`[Props] {source.Name} failed to load, using the stand-in: {model}`)
	end
	return finish(buildFallback(slot, height, fit, index), slot, at, parent)
end

-- A prop `Town.SLOTS[slot].height` tall with its bottom centre on `at`. variant picks among the slot's files.
function Props.place(slot: string, at: CFrame, parent: Instance, variant: number?): Model
	return make(slot, at, parent, variant, nil)
end

-- The slot's model fitted onto a part that moves (a delivery box someone carries): unanchored, weightless and
-- welded to the part. Nil (the part keeps its own look) when the slot has no model.
function Props.weldFit(slot: string, part: BasePart): Model?
	if not Props.hasModel(slot) then
		return nil
	end
	local model = make(slot, part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0), part, nil, part.Size)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	return model
end

-- A prop scaled to fit inside `size`, bottom centre on `at` (Shelf on a shelf's hitbox, counter props)
function Props.fit(slot: string, size: Vector3, at: CFrame, parent: Instance, variant: number?): Model
	return make(slot, at, parent, variant, size)
end

-- The models replicate to every client: the Lune test keeps scripts out of assets/props, and the server strips
-- the source folder once at start as a second layer
if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild("PropModels")
	if folder then
		Props.strip(folder)
	end
end

return Props
