--!strict
-- The 3D pack, deck box and display box (UI project 3, docs/packs.md), cloned from ReplicatedStorage.PackModels
-- (assets/packs, built by tools/blender/build_pack.py, build_deckbox.py, build_displaybox.py). Each model holds
-- Looks/<look>/<MeshPart name> SurfaceAppearances (one look per pack type, Config/Packs `look`; scripts can't swap a
-- SurfaceAppearance's maps), and each clone gets its pack's look. Every model's pivot is its bottom centre, front
-- facing -Z. Without the models (before the import) each gives a plain stand-in made of parts, so nothing breaks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = (script.Parent :: Instance).Parent:WaitForChild("Config")
local Packs = require(Config:WaitForChild("Packs"))

export type Detail = "High" | "Low"

local STAND_IN_ART = Color3.fromRGB(245, 150, 50)
local CARDBOARD = Color3.fromRGB(196, 152, 102)
local DISPLAY_PACKS = 6 -- the most packs a display box shows (Packs1..Packs6)

local PackModels = {}

local function source(name: string): Model?
	local folder = ReplicatedStorage:FindFirstChild("PackModels")
	local model = if folder then folder:FindFirstChild(name) else nil
	return if model and model:IsA("Model") then model else nil
end

-- Gives each MeshPart its look from Looks/<look> and drops the Looks folder from the clone
local function dress(model: Model, look: string?)
	local looks = model:FindFirstChild("Looks")
	local chosen = if looks and look then looks:FindFirstChild(look) else nil
	if chosen then
		for _, appearance in chosen:GetChildren() do
			local part = model:FindFirstChild(appearance.Name)
			if part and part:IsA("MeshPart") and appearance:IsA("SurfaceAppearance") then
				for _, old in part:GetChildren() do
					if old:IsA("SurfaceAppearance") then
						old:Destroy()
					end
				end
				local copy = appearance:Clone()
				copy.Name = "Look"
				copy.Parent = part
			end
		end
	end
	if looks then
		looks:Destroy()
	end
end

-- Keeps only the named parts (and their children); the rest of the model's parts go
local function keep(model: Model, names: { string })
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and not table.find(names, child.Name) then
			child:Destroy()
		end
	end
end

local function standInPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, art: string?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if art then
		local front = Instance.new("Decal")
		front.Face = Enum.NormalId.Front
		front.Texture = art
		front.Parent = part
	end
	part.Parent = model
	return part
end

local function standIn(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.WorldPivot = CFrame.new()
	return model
end

local function lookOf(packId: string): (string?, Packs.Pack?)
	local pack = Packs.ById[packId]
	return if pack then pack.look else nil, pack
end

-- The booster pack: High = Body (open at the top) and the tear Strip, for the opening and menus; Low = one closed Body
function PackModels.pack(packId: string, detail: Detail): Model
	local look, pack = lookOf(packId)
	local found = source("Pack")
	if found then
		local model = found:Clone()
		dress(model, look)
		if detail == "High" then
			keep(model, { "Body", "Strip" })
		else
			keep(model, { "BodyLow" })
			local low = model:FindFirstChild("BodyLow")
			if low then
				low.Name = "Body"
			end
		end
		return model
	end
	local model = standIn("Pack")
	local art = if pack then pack.art else nil
	local color = if pack then pack.color else STAND_IN_ART
	if detail == "High" then
		standInPart(model, "Body", Vector3.new(0.64, 0.9, 0.08), CFrame.new(0, 0.45, 0), color, art)
		standInPart(model, "Strip", Vector3.new(0.64, 0.1, 0.06), CFrame.new(0, 0.95, 0), color, nil)
	else
		standInPart(model, "Body", Vector3.new(0.64, 1, 0.08), CFrame.new(0, 0.5, 0), color, art)
	end
	return model
end

-- The deck box: Box and its Lid
function PackModels.deckBox(packId: string): Model
	local look, pack = lookOf(packId)
	local found = source("DeckBox")
	if found then
		local model = found:Clone()
		dress(model, look)
		return model
	end
	local model = standIn("DeckBox")
	local color = if pack then pack.color else STAND_IN_ART
	standInPart(model, "Box", Vector3.new(0.55, 0.64, 0.4), CFrame.new(0, 0.32, 0), color, if pack then pack.art else nil)
	standInPart(model, "Lid", Vector3.new(0.57, 0.16, 0.42), CFrame.new(0, 0.72, 0), Color3.fromRGB(235, 190, 80), nil)
	return model
end

-- An open display box showing `packs` packs (0 to 6), filling from the front
function PackModels.displayBox(packId: string, packs: number): Model
	local look, pack = lookOf(packId)
	local shown = math.clamp(math.floor(packs), 0, DISPLAY_PACKS)
	local found = source("DisplayBox")
	if found then
		local model = found:Clone()
		dress(model, look)
		keep(model, if shown > 0 then { "Tray", `Packs{shown}` } else { "Tray" })
		return model
	end
	local model = standIn("DisplayBox")
	standInPart(model, "Tray", Vector3.new(0.79, 0.36, 1.01), CFrame.new(0, 0.18, 0), CARDBOARD, nil)
	local color = if pack then pack.color else STAND_IN_ART
	for index = 1, shown do
		standInPart(model, `Pack{index}`, Vector3.new(0.61, 0.95, 0.05), CFrame.new(0, 0.5, -0.4 + (index - 1) * 0.14), color, if pack then pack.art else nil)
	end
	return model
end

return PackModels
