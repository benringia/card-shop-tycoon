--!strict
-- Swappable town props (main town spec, docs/props.md). A slot's model comes from ServerStorage.PropModels
-- (assets/props/<Slot>.rbxm and its variants); a missing, empty, too-big or broken one gets a part-built stand-in,
-- so the town never breaks. Placed props are stripped of scripts, scaled, anchored and stood on the given spot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local TownLayout = require(Shared:WaitForChild("Util"):WaitForChild("TownLayout"))

local Props = {}

local STRIPPED = { "LuaSourceContainer", "ProximityPrompt", "ClickDetector", "Sound", "Tool" }
local MIN_HEIGHT = 0.05

local WOOD = Color3.fromRGB(125, 90, 60)
local DARK_WOOD = Color3.fromRGB(95, 65, 45)
local LEAVES = Color3.fromRGB(100, 165, 90)
local PINE = Color3.fromRGB(60, 125, 80)
local STONE = Color3.fromRGB(150, 145, 140)
local LAMP_GLOW = Color3.fromRGB(255, 220, 150)
local PETALS = { Color3.fromRGB(240, 130, 160), Color3.fromRGB(250, 220, 90), Color3.fromRGB(150, 170, 240) }

local variantCache: { [string]: { Instance } } = {}

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
	local folder = ServerStorage:FindFirstChild("PropModels")
	if folder then
		for _, child in folder:GetChildren() do
			if TownLayout.isVariant(slot, child.Name) and isUsable(child) then
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
	local block, ball, cylinder = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
	if slot == "Tree" then
		addPart(model, cylinder, Vector3.new(height * 0.45, 1.6, 1.6), CFrame.new(0, height * 0.225, 0) * UPRIGHT, WOOD, Enum.Material.Wood)
		addPart(model, ball, Vector3.one * height * 0.6, CFrame.new(0, height * 0.7, 0), LEAVES)
	elseif slot == "Pine" then
		addPart(model, cylinder, Vector3.new(height * 0.3, 1.4, 1.4), CFrame.new(0, height * 0.15, 0) * UPRIGHT, WOOD, Enum.Material.Wood)
		for tier = 0, 2 do
			local width = height * (0.45 - tier * 0.12)
			addPart(model, block, Vector3.new(width, height * 0.22, width), CFrame.new(0, height * (0.35 + tier * 0.2), 0) * CFrame.Angles(0, math.rad(45), 0), PINE)
		end
	elseif slot == "Bush" then
		addPart(model, ball, Vector3.new(height * 1.4, height, height * 1.4), CFrame.new(0, height / 2, 0), LEAVES)
	elseif slot == "Flower" or slot == "Clover" then
		local color = if slot == "Clover" then LEAVES else PETALS[(variant - 1) % #PETALS + 1]
		addPart(model, cylinder, Vector3.new(height, 3, 3), CFrame.new(0, height / 2, 0) * UPRIGHT, color)
	elseif slot == "Rock" then
		addPart(model, block, Vector3.new(height * 1.3, height, height * 1.1), CFrame.new(0, height / 2, 0) * CFrame.Angles(0, math.rad(20), 0), STONE, Enum.Material.Slate)
	elseif slot == "Barrel" then
		addPart(model, cylinder, Vector3.new(height, height * 0.7, height * 0.7), CFrame.new(0, height / 2, 0) * UPRIGHT, WOOD, Enum.Material.Wood)
	elseif slot == "Lamp" then
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
		-- Crate, PlazaDecor, Register, CounterDecor, Shelf and anything new: a plain box
		local box = size or Vector3.new(height, height, height)
		addPart(model, block, box, CFrame.new(0, box.Y / 2, 0), WOOD, Enum.Material.Wood)
	end
	model.WorldPivot = CFrame.new()
	return model
end

-- Clone a source model and size it: to `height`, or (when `fit` is given) to the largest size that fits inside it
local function prepareModel(source: Instance, height: number, fit: Vector3?): Model
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
	for _, descendant in model:GetDescendants() do
		for _, className in STRIPPED do
			if descendant:IsA(className) then
				descendant:Destroy()
				break
			end
		end
	end
	local yaw = model:GetAttribute("YawOffset") -- degrees, for models that don't face -Z
	local turn = CFrame.Angles(0, math.rad(if typeof(yaw) == "number" then yaw else 0), 0)
	local boxCFrame, boxSize = model:GetBoundingBox()
	model.WorldPivot = boxCFrame * CFrame.new(0, -boxSize.Y / 2, 0) * turn
	local ratio = if fit
		then math.min(fit.X / math.max(boxSize.X, MIN_HEIGHT), fit.Y / math.max(boxSize.Y, MIN_HEIGHT), fit.Z / math.max(boxSize.Z, MIN_HEIGHT))
		else height / math.max(boxSize.Y, MIN_HEIGHT)
	model:ScaleTo(model:GetScale() * ratio)
	return model
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
		local ok, model = pcall(prepareModel, source, height, fit)
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

-- A prop scaled to fit inside `size`, bottom centre on `at` (Shelf on a shelf's hitbox)
function Props.fit(slot: string, size: Vector3, at: CFrame, parent: Instance): Model
	return make(slot, at, parent, nil, size)
end

return Props
