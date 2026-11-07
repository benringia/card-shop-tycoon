--!strict
-- Finishes an imported sword model file (docs/animations.md "The sword model", docs/weapons.md): Roblox's FBX importer
-- drops the Blender colours, so this sets each plain part's colour and material by name (textured parts, the Meshy
-- weapons, keep their texture), straightens each mesh's PivotOffset (the importer can turn it; its position, the
-- grip's centre from the FBX origin, is kept) and makes the grip the model's PrimaryPart (the game reads where the hand holds it from the
-- model's pivot: the grip's centre, blade up). Rewrites the file in place.
-- Usage: lune run tools/weapons/finish_sword [file] (default assets/weapons/StarterSword.rbxm)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local FILE = process.args[1] or "assets/weapons/StarterSword.rbxm"

-- The starter sword's look (tools/blender/build_starter_sword.py): steel blade, gold guard and pommel, leather grip
local LOOK = {
	Blade = { color = { 204, 217, 235 }, material = "Metal" },
	Guard = { color = { 235, 179, 71 }, material = "SmoothPlastic" },
	Pommel = { color = { 235, 179, 71 }, material = "SmoothPlastic" },
	Grip = { color = { 92, 56, 36 }, material = "SmoothPlastic" },
}

-- A MeshPart's texture: newer files keep it as TextureContent (a Content), older ones as TextureID
local function textureOf(part: any): string
	local ok, id = pcall(function()
		return part.TextureID
	end)
	if ok and typeof(id) == "string" then
		return id
	end
	local hasContent, content = pcall(function()
		return part.TextureContent
	end)
	return if hasContent and content and content.Uri then content.Uri else ""
end

local roots = roblox.deserializeModel(fs.readFile(FILE))
local model = roots[1]
assert(model and model:IsA("Model"), `{FILE} should hold one Model`)
for _, part in model:GetDescendants() do
	if part:IsA("BasePart") then
		part.PivotOffset = roblox.CFrame.new(part.PivotOffset.Position)
	end
	local look = (LOOK :: any)[part.Name]
	local textured = part:FindFirstChildOfClass("SurfaceAppearance") ~= nil or (part:IsA("MeshPart") and textureOf(part) ~= "")
	if look and part:IsA("BasePart") and not textured then
		part.Color = roblox.Color3.fromRGB(look.color[1], look.color[2], look.color[3])
		part.Material = (roblox.Enum.Material :: any)[look.material]
		print(`{part.Name}: {look.material}`)
	end
end
-- A sword is held by its Grip; a spear by its Shaft (its origin 31% up from the butt, weapons round 2)
local grip = model:FindFirstChild("Grip") or model:FindFirstChild("Shaft")
assert(grip and grip:IsA("BasePart"), "the weapon needs a part named Grip (a sword) or Shaft (a spear)")
model.PrimaryPart = grip
fs.writeFile(FILE, roblox.serializeModel(roots))
print(`{FILE}: finished (PrimaryPart {grip.Name})`)
