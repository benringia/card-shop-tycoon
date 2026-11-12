--!strict
-- A boss chest (spec 2026-11-11-boss-chests-design; Config/BossChests LOOK, MODEL): the Blender model
-- (ReplicatedStorage.PackModels.Chest: Body and Lid, tools/blender/build_chest.py) scaled to the width asked, or, until
-- it's imported, a stand-in built from parts (a wooden box with gold bands and a lock). Either way the lid swings on
-- the body's top back edge. Its front faces -Z (the pack opening's stage camera looks along +Z). Client-only, anchored;
-- `place` puts every part from the chest's pivot and its lid's angle, so the controller can wobble, lift and open it in
-- one call a frame. A light inside shows once the lid is up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossChests = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("BossChests"))

local ChestModel = {}

local LIGHT_BRIGHTNESS = 0.6 -- the light inside at full open (4 washed the whole chest out to yellow)
local GLOW_OPACITY = 0.4 -- the glowing slab inside at full open (the stage's bloom spreads it)

export type Chest = {
	model: Model,
	parts: { { part: BasePart, offset: CFrame, lid: boolean, color: Color3 } },
	hinge: CFrame, -- the hinge line in the chest's own space
	lid: number, -- radians open
	light: PointLight,
	glow: BasePart,
}

type Colors = { wood: Color3, woodDark: Color3, trim: Color3 }

local function block(model: Model, name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- The light inside: a glow slab under the lid and its PointLight (hidden until the lid opens)
local function inside(model: Model, size: Vector3): (Part, PointLight)
	local glow = block(model, "Glow", size, Color3.new(1, 1, 1), Enum.Material.Neon)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Range = size.X * 1.6
	light.Brightness = 0
	light.Shadows = false
	light.Parent = glow
	return glow, light
end

-- The Blender model scaled to `width` (its body's width); nil while it isn't imported
local function fromModel(parent: Instance, width: number): Chest?
	local folder = ReplicatedStorage:FindFirstChild("PackModels")
	local template = if folder then folder:FindFirstChild(BossChests.MODEL) else nil
	local body = if template then template:FindFirstChild("Body", true) else nil
	local lid = if template then template:FindFirstChild("Lid", true) else nil
	if not body or not body:IsA("BasePart") or not lid or not lid:IsA("BasePart") then
		return nil
	end
	local scale = width / body.Size.X
	-- The template's frame: its body's bottom middle as imported (axis-aligned, front -Z)
	local base = CFrame.new(body.Position - Vector3.new(0, body.Size.Y / 2, 0))
	local model = Instance.new("Model")
	model.Name = "BossChest"
	local parts = {}
	for _, source in { body, lid } do
		local part = source:Clone()
		for _, child in part:GetDescendants() do
			if child:IsA("LuaSourceContainer") then
				child:Destroy()
			end
		end
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = source.Size * scale
		local offset = base:ToObjectSpace(source.CFrame)
		part.Parent = model
		table.insert(parts, { part = part :: BasePart, offset = CFrame.new(offset.Position * scale) * offset.Rotation, lid = source == lid, color = part.Color })
	end
	local top = body.Size.Y * scale
	local glow, light = inside(model, Vector3.new(width * 0.85, width * 0.02, body.Size.Z * scale * 0.7))
	table.insert(parts, { part = glow :: BasePart, offset = CFrame.new(0, top + width * 0.01, 0), lid = false, color = glow.Color })
	model.Parent = parent
	-- The hinge: the body's top back edge (+Z is its back)
	return { model = model, parts = parts, hinge = CFrame.new(0, top, body.Size.Z * scale / 2), lid = 0, light = light, glow = glow }
end

-- A chest `width` studs wide; its pivot is the middle of its bottom
function ChestModel.new(parent: Instance, width: number, colors: Colors): Chest
	local made = fromModel(parent, width)
	if made then
		return made
	end
	local model = Instance.new("Model")
	model.Name = "BossChest"
	local w = width
	local depth, boxHeight, lidHeight = w * 0.62, w * 0.5, w * 0.24
	local parts = {}
	local function add(part: BasePart, at: CFrame, lid: boolean)
		table.insert(parts, { part = part, offset = at, lid = lid, color = part.Color })
	end
	local band = w * 0.08
	-- The box, its rim and gold bands round the sides and the front
	add(block(model, "Box", Vector3.new(w, boxHeight, depth), colors.wood), CFrame.new(0, boxHeight / 2, 0), false)
	add(block(model, "Base", Vector3.new(w * 1.04, w * 0.06, depth * 1.04), colors.woodDark), CFrame.new(0, w * 0.03, 0), false)
	for _, x in { -0.32, 0.32 } do
		add(block(model, "Band", Vector3.new(band, boxHeight * 1.01, depth * 1.03), colors.trim, Enum.Material.Metal), CFrame.new(w * x, boxHeight / 2, 0), false)
	end
	add(block(model, "Rim", Vector3.new(w * 1.02, w * 0.05, depth * 1.02), colors.trim, Enum.Material.Metal), CFrame.new(0, boxHeight - w * 0.025, 0), false)
	-- The glow inside (shown as the lid opens) and its light
	local glow, light = inside(model, Vector3.new(w * 0.9, w * 0.02, depth * 0.88))
	add(glow, CFrame.new(0, boxHeight - w * 0.03, 0), false)

	-- The lid: a slab with its own bands, the lock's top on its front edge; hinged at the top back edge (+Z)
	local hinge = CFrame.new(0, boxHeight, depth / 2)
	local lidAt = CFrame.new(0, boxHeight + lidHeight / 2, 0)
	add(block(model, "Lid", Vector3.new(w * 1.04, lidHeight, depth * 1.06), colors.wood), lidAt, true)
	add(block(model, "LidTop", Vector3.new(w * 0.94, lidHeight * 0.35, depth * 0.94), colors.woodDark), lidAt * CFrame.new(0, lidHeight * 0.6, 0), true)
	for _, x in { -0.32, 0.32 } do
		add(block(model, "LidBand", Vector3.new(band, lidHeight * 1.04, depth * 1.08), colors.trim, Enum.Material.Metal), lidAt * CFrame.new(w * x, 0, 0), true)
	end
	-- The lock on the front (-Z), half on the box, half on the lid
	add(block(model, "Lock", Vector3.new(w * 0.16, w * 0.2, w * 0.06), colors.trim, Enum.Material.Metal), CFrame.new(0, boxHeight - w * 0.06, -depth / 2 - w * 0.03), false)
	add(block(model, "Hasp", Vector3.new(w * 0.1, w * 0.12, w * 0.05), colors.trim, Enum.Material.Metal), lidAt * CFrame.new(0, -lidHeight * 0.1, -depth * 0.53 - w * 0.02), true)
	model.Parent = parent
	return { model = model, parts = parts, hinge = hinge, lid = 0, light = light, glow = glow }
end

-- Every part from `pivot` (the middle of the chest's bottom) and the lid's angle
function ChestModel.place(chest: Chest, pivot: CFrame)
	local lidTurn = chest.hinge * CFrame.Angles(chest.lid, 0, 0) * chest.hinge:Inverse()
	for _, entry in chest.parts do
		entry.part.CFrame = if entry.lid then pivot * lidTurn * entry.offset else pivot * entry.offset
	end
end

-- The light inside: `amount` 0 (off) to 1 (full) in `color`
function ChestModel.light(chest: Chest, color: Color3, amount: number)
	chest.glow.Color = color
	chest.glow.Transparency = 1 - GLOW_OPACITY * amount
	chest.light.Color = color
	chest.light.Brightness = LIGHT_BRIGHTNESS * amount
end

-- The whole chest darker by `amount` (the ones not picked), 0 = as built: a textured model through its
-- SurfaceAppearance's tint, the stand-in through its colours
function ChestModel.dim(chest: Chest, amount: number)
	local shade = Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), amount)
	for _, entry in chest.parts do
		if entry.part == chest.glow then
			continue
		end
		local look = entry.part:FindFirstChildOfClass("SurfaceAppearance")
		if look then
			local tinted: any = look
			pcall(function()
				tinted.Color = shade
			end)
		else
			entry.part.Color = entry.color:Lerp(Color3.new(0, 0, 0), amount)
		end
	end
end

return ChestModel
