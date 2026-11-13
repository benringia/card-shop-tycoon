--!strict
-- Shop decor pieces' code-built stand-ins (spec 2026-11-14-shop-decor-design; Config/Shelves kind "Decor"): drawn by
-- Util/Props when a piece's slot has no model yet (Town.SLOTS standIn), and finished the same way whether the look is
-- the stand-in or the Blender model (tools/blender/build_decor_props.py, docs/props.md "Decor props"), by its parts'
-- names: Glow and Bulb glow (the Floor Lamp's Bulb also lights), Picture wears the
-- piece's picture, Spin (the Card Pedestal's card) wears the card back and is tagged for DecorSpinController. Each
-- stand-in fills its footprint `size`, bottom centre at the origin, front facing -Z, in the concept sheet's colours.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Decor = require(Config:WaitForChild("Decor"))
local CardDesign = require(Config:WaitForChild("CardDesign"))

local DecorLooks = {}

local BLOCK, BALL, CYLINDER, WEDGE = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder, Enum.PartType.Wedge
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders run along X: this stands one up
local SMOOTH, NEON, WOOD = Enum.Material.SmoothPlastic, Enum.Material.Neon, Enum.Material.Wood

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function add(model: Model, shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or SMOOTH
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- A squashed round shape (a block wearing a sphere mesh): beanbags, leaves, balloons
local function blob(model: Model, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local part = add(model, BLOCK, size, cframe, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A picture on a part's face
local function decal(part: BasePart, image: string, face: Enum.NormalId)
	local sticker = Instance.new("Decal")
	sticker.Texture = image
	sticker.Face = face
	sticker.Parent = part
end

local DRAW: { [string]: (model: Model, w: number, h: number, d: number) -> () } = {
	PottedPlant = function(model, w, h, _d)
		local pot = math.min(w, 2) * 0.7
		add(model, CYLINDER, Vector3.new(h * 0.32, pot, pot), CFrame.new(0, h * 0.16, 0) * UPRIGHT, rgb(250, 190, 205))
		add(model, CYLINDER, Vector3.new(0.12, pot * 0.92, pot * 0.92), CFrame.new(0, h * 0.32, 0) * UPRIGHT, rgb(110, 80, 60))
		for index, offset in { Vector3.new(0, 0.62, 0), Vector3.new(-0.35, 0.5, 0.15), Vector3.new(0.35, 0.52, -0.1), Vector3.new(0.05, 0.78, -0.05) } do
			local leaf = blob(model, Vector3.new(pot * 1.05, h * 0.3, pot * 1.05), CFrame.new(offset.X * w / 2, offset.Y * h, offset.Z * w / 2), rgb(80, 165 + index * 8, 100))
			leaf.Name = "Leaf"
		end
	end,
	StarRug = function(model, w, h, d)
		local across = math.min(w, d) * 0.96
		add(model, CYLINDER, Vector3.new(h * 0.6, across, across), CFrame.new(0, h * 0.3, 0) * UPRIGHT, rgb(250, 230, 200), Enum.Material.Fabric)
		add(model, CYLINDER, Vector3.new(h * 0.62, across * 0.82, across * 0.82), CFrame.new(0, h * 0.31, 0) * UPRIGHT, rgb(150, 205, 235), Enum.Material.Fabric)
		for ray = 0, 4 do
			local angle = math.rad(ray * 72)
			add(model, BLOCK, Vector3.new(across * 0.12, h * 0.66, across * 0.36), CFrame.Angles(0, angle, 0) * CFrame.new(0, h * 0.33, -across * 0.14), rgb(255, 205, 80), Enum.Material.Fabric)
		end
		add(model, CYLINDER, Vector3.new(h * 0.68, across * 0.22, across * 0.22), CFrame.new(0, h * 0.34, 0) * UPRIGHT, rgb(255, 205, 80), Enum.Material.Fabric)
	end,
	FloorLamp = function(model, w, h, _d)
		add(model, CYLINDER, Vector3.new(0.2, w * 0.6, w * 0.6), CFrame.new(0, 0.1, 0) * UPRIGHT, rgb(60, 60, 70), Enum.Material.Metal)
		add(model, CYLINDER, Vector3.new(h * 0.78, 0.16, 0.16), CFrame.new(0, h * 0.39, 0) * UPRIGHT, rgb(60, 60, 70), Enum.Material.Metal)
		add(model, CYLINDER, Vector3.new(h * 0.18, w * 0.75, w * 0.75), CFrame.new(0, h * 0.86, 0) * UPRIGHT, rgb(255, 236, 200), Enum.Material.Fabric)
		local bulb = add(model, BALL, Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, h * 0.75, 0), rgb(255, 225, 160), NEON)
		bulb.Name = "Bulb"
	end,
	Beanbag = function(model, w, h, d)
		blob(model, Vector3.new(w * 0.9, h * 0.72, d * 0.9), CFrame.new(0, h * 0.36, 0), rgb(245, 140, 180), Enum.Material.Fabric)
		blob(model, Vector3.new(w * 0.8, h * 0.8, d * 0.45), CFrame.new(0, h * 0.55, d * 0.22), rgb(240, 125, 170), Enum.Material.Fabric)
	end,
	BalloonBunch = function(model, w, h, _d)
		add(model, BLOCK, Vector3.new(0.5, 0.4, 0.5), CFrame.new(0, 0.2, 0), rgb(120, 120, 135))
		local colors = { rgb(255, 110, 130), rgb(110, 180, 255), rgb(255, 215, 90), rgb(140, 220, 130), rgb(190, 130, 255) }
		local spots = { Vector3.new(0, 0.86, 0), Vector3.new(-0.32, 0.74, 0.1), Vector3.new(0.32, 0.76, -0.1), Vector3.new(-0.15, 0.66, -0.25), Vector3.new(0.18, 0.64, 0.25) }
		for index, spot in spots do
			local at = Vector3.new(spot.X * w, spot.Y * h, spot.Z * w)
			blob(model, Vector3.new(w * 0.42, w * 0.5, w * 0.42), CFrame.new(at), colors[index])
			local length = at.Magnitude
			add(model, BLOCK, Vector3.new(0.04, length, 0.04), CFrame.lookAt(at / 2, at) * CFrame.Angles(math.rad(90), 0, 0), rgb(240, 240, 240))
		end
	end,
	ElementPennants = function(model, w, h, _d)
		local wood = rgb(140, 100, 70)
		for _, x in { -w * 0.45, w * 0.45 } do
			add(model, CYLINDER, Vector3.new(h, 0.2, 0.2), CFrame.new(x, h / 2, 0) * UPRIGHT, wood, WOOD)
		end
		add(model, BLOCK, Vector3.new(w * 0.92, 0.06, 0.06), CFrame.new(0, h * 0.85, 0), rgb(245, 245, 240))
		local flags = { rgb(240, 90, 60), rgb(70, 150, 240), rgb(90, 190, 90), rgb(250, 210, 60), rgb(150, 90, 220) }
		for index, color in flags do
			local x = (index - 3) * w * 0.17
			-- a downward-pointing pennant: a wedge turned so its point hangs below the string
			add(model, WEDGE, Vector3.new(0.08, h * 0.32, w * 0.14), CFrame.new(x, h * 0.85 - h * 0.16, 0) * CFrame.Angles(0, math.rad(90), math.rad(180)), color, Enum.Material.Fabric)
		end
	end,
	BoosterTower = function(model, w, h, d)
		local colors = { rgb(240, 90, 90), rgb(90, 160, 240), rgb(250, 200, 70), rgb(110, 200, 120), rgb(170, 110, 230) }
		local box = h * 0.16
		for level, color in colors do
			local twist = CFrame.Angles(0, math.rad((level % 2) * 14 - 7), 0)
			add(model, BLOCK, Vector3.new(w * 0.8, box * 0.94, d * 0.6), CFrame.new(0, box * (level - 0.5), 0) * twist, color)
		end
		local star = add(model, BALL, Vector3.new(w * 0.42, w * 0.42, w * 0.42), CFrame.new(0, box * 5 + w * 0.26, 0), rgb(255, 215, 90), NEON)
		star.Name = "Glow"
	end,
	PlayTable = function(model, w, h, d)
		local wood = rgb(170, 120, 80)
		local top = h * 0.62
		add(model, CYLINDER, Vector3.new(0.12, w * 0.3, w * 0.3), CFrame.new(0, 0.06, 0) * UPRIGHT, wood, WOOD)
		add(model, CYLINDER, Vector3.new(top, 0.4, 0.4), CFrame.new(0, top / 2, 0) * UPRIGHT, wood, WOOD)
		add(model, CYLINDER, Vector3.new(0.2, w * 0.62, d * 0.62), CFrame.new(0, top, 0) * UPRIGHT, wood, WOOD)
		add(model, CYLINDER, Vector3.new(0.04, w * 0.52, d * 0.52), CFrame.new(0, top + 0.12, 0) * UPRIGHT, rgb(70, 160, 100), Enum.Material.Fabric)
		local cards = { rgb(240, 90, 90), rgb(90, 160, 240), rgb(250, 200, 70), rgb(170, 110, 230) }
		for index, color in cards do
			local spot = CFrame.new((index - 2.5) * w * 0.1, top + 0.16, (index % 2 - 0.5) * d * 0.16) * CFrame.Angles(0, math.rad(index * 23 - 40), 0)
			add(model, BLOCK, Vector3.new(0.45, 0.03, 0.62), spot, color)
		end
		for _, side in { -1, 1 } do
			add(model, CYLINDER, Vector3.new(h * 0.38, w * 0.2, w * 0.2), CFrame.new(side * w * 0.42, h * 0.19, 0) * UPRIGHT, rgb(240, 140, 60))
		end
	end,
	CardFrame = function(model, w, h, d)
		local wood, gold = rgb(150, 104, 70), rgb(240, 190, 70)
		local lean = CFrame.Angles(math.rad(10), 0, 0) -- leans back, the card facing the front and a little up
		local function leg(a: Vector3, b: Vector3)
			add(model, BLOCK, Vector3.new(0.14, 0.14, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), wood, WOOD)
		end
		for _, side in { -1, 1 } do
			leg(Vector3.new(side * w * 0.3, 0, -d * 0.25), Vector3.new(side * w * 0.18, h * 0.95, d * 0.05))
		end
		leg(Vector3.new(0, 0, d * 0.45), Vector3.new(0, h * 0.85, d * 0.08))
		add(model, BLOCK, Vector3.new(w * 0.8, 0.14, 0.4), CFrame.new(0, h * 0.2, -d * 0.12), wood, WOOD)
		local frame = CFrame.new(0, h * 0.58, 0) * lean
		add(model, BLOCK, Vector3.new(w * 0.62, h * 0.72, 0.16), frame, gold, Enum.Material.Metal)
		local picture = add(model, BLOCK, Vector3.new(w * 0.52, h * 0.62, 0.04), frame * CFrame.new(0, 0, -0.1), rgb(255, 255, 255))
		picture.Name = "Picture"
	end,
	DogStandee = function(model, w, h, d)
		add(model, BLOCK, Vector3.new(w * 0.95, h * 0.9, 0.12), CFrame.new(0, h * 0.5, -d * 0.2), rgb(225, 190, 140), Enum.Material.Cardboard)
		local picture = add(model, BLOCK, Vector3.new(w * 0.88, h * 0.84, 0.04), CFrame.new(0, h * 0.5, -d * 0.2 - 0.08), rgb(255, 255, 255))
		picture.Name = "Picture"
		add(model, BLOCK, Vector3.new(w * 0.3, h * 0.6, 0.1), CFrame.new(0, h * 0.3, d * 0.15) * CFrame.Angles(math.rad(25), 0, 0), rgb(200, 165, 120), Enum.Material.Cardboard)
		add(model, BLOCK, Vector3.new(w * 0.95, 0.1, d * 0.5), CFrame.new(0, 0.05, -d * 0.1), rgb(200, 165, 120), Enum.Material.Cardboard)
	end,
	CardPedestal = function(model, w, h, _d)
		local stone = rgb(200, 200, 215)
		add(model, BLOCK, Vector3.new(w * 0.9, h * 0.08, w * 0.9), CFrame.new(0, h * 0.04, 0), stone, Enum.Material.Marble)
		add(model, CYLINDER, Vector3.new(h * 0.42, w * 0.5, w * 0.5), CFrame.new(0, h * 0.29, 0) * UPRIGHT, stone, Enum.Material.Marble)
		add(model, BLOCK, Vector3.new(w * 0.8, h * 0.08, w * 0.8), CFrame.new(0, h * 0.54, 0), stone, Enum.Material.Marble)
		add(model, BLOCK, Vector3.new(w * 0.82, h * 0.02, w * 0.82), CFrame.new(0, h * 0.51, 0), rgb(240, 200, 90), Enum.Material.Metal)
		local glow = add(model, CYLINDER, Vector3.new(0.05, w * 0.6, w * 0.6), CFrame.new(0, h * 0.585, 0) * UPRIGHT, rgb(190, 150, 255), NEON)
		glow.Name = "Glow"
		local card = add(model, BLOCK, Vector3.new(w * 0.5, w * 0.7, 0.05), CFrame.new(0, h * 0.8, 0), rgb(95, 55, 185))
		card.Name = "Spin"
	end,
	PackStatue = function(model, w, h, d)
		add(model, BLOCK, Vector3.new(w, h * 0.12, d), CFrame.new(0, h * 0.06, 0), rgb(120, 110, 140), Enum.Material.Slate)
		add(model, BLOCK, Vector3.new(w * 0.62, h * 0.8, d * 0.24), CFrame.new(0, h * 0.12 + h * 0.4, 0), rgb(255, 200, 70), Enum.Material.Foil)
		local picture = add(model, BLOCK, Vector3.new(w * 0.56, h * 0.7, 0.04), CFrame.new(0, h * 0.12 + h * 0.4, -d * 0.12 - 0.02), rgb(255, 255, 255))
		picture.Name = "Picture"
		for _, y in { h * 0.13 + 0.12, h * 0.92 - 0.12 } do
			add(model, BLOCK, Vector3.new(w * 0.64, 0.24, d * 0.26), CFrame.new(0, y, 0), rgb(240, 240, 250), Enum.Material.Metal)
		end
	end,
}

function DecorLooks.isDecor(slot: string): boolean
	return DRAW[slot] ~= nil
end

-- The stand-in for a decor slot, filling `size`
function DecorLooks.draw(model: Model, slot: string, size: Vector3)
	local draw = DRAW[slot]
	if draw then
		draw(model, size.X, size.Y, size.Z)
	end
end

local function glow(part: BasePart, slot: string)
	local color = Decor.GLOW_COLORS[slot]
	part.Material = Enum.Material.Neon
	if color then
		part.Color = rgb(color[1], color[2], color[3])
	end
	if part:IsA("MeshPart") then
		part.TextureID = "" -- Neon shows the part's colour, not its palette texture
	end
end

local function lamp(bulb: BasePart)
	if bulb:FindFirstChildOfClass("PointLight") then
		return
	end
	local cfg = Decor.LAMP_LIGHT
	local light = Instance.new("PointLight")
	light.Range = cfg.range
	light.Brightness = cfg.brightness
	light.Color = rgb(cfg.color[1], cfg.color[2], cfg.color[3])
	light.Shadows = false
	light.Parent = bulb
end

-- Finishes a placed piece's look, the stand-in's or the model's, by its parts' names
function DecorLooks.finish(visual: Model, slot: string)
	for _, part in visual:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Glow" or part.Name == "Bulb" then
			glow(part, slot)
			if part.Name == "Bulb" then
				lamp(part)
			end
		elseif part.Name == "Picture" and Decor.PICTURES[slot] then
			decal(part, Decor.PICTURES[slot], Enum.NormalId.Front)
		elseif part.Name == "Spin" then
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				decal(part, CardDesign.BACK.IMAGE, face)
			end
			CollectionService:AddTag(part, "DecorSpin")
		end
	end
end

return DecorLooks
