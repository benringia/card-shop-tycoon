--!strict
-- Finishes an imported sword model file (docs/animations.md "The sword model"): Roblox's FBX importer drops the
-- Blender colours, so this sets each part's colour and material by name and makes the grip the model's PrimaryPart
-- (the game reads where the hand holds it from the model's pivot, the grip's centre). Rewrites the file in place.
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

local roots = roblox.deserializeModel(fs.readFile(FILE))
local model = roots[1]
assert(model and model:IsA("Model"), `{FILE} should hold one Model`)
for _, part in model:GetDescendants() do
	local look = (LOOK :: any)[part.Name]
	if look and part:IsA("BasePart") then
		part.Color = roblox.Color3.fromRGB(look.color[1], look.color[2], look.color[3])
		part.Material = (roblox.Enum.Material :: any)[look.material]
		print(`{part.Name}: {look.material}`)
	end
end
local grip = model:FindFirstChild("Grip")
assert(grip, "the sword needs a part named Grip")
model.PrimaryPart = grip
fs.writeFile(FILE, roblox.serializeModel(roots))
print(`{FILE}: finished (PrimaryPart Grip)`)
