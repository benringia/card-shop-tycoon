--!strict
-- Finishes an imported effect model file (assets/fx-models, docs/weapons.md "The Grim Reaper"): makes the named part
-- its PrimaryPart (the game moves the model by its pivot: the part's PivotOffset, the FBX origin) and straightens every
-- part's PivotOffset (the importer can turn it; its position is kept). Rewrites the file in place.
-- Usage: lune run tools/weapons/finish_fx_model <file> <part name>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local FILE = process.args[1]
local PART = process.args[2]
assert(FILE and PART, "usage: lune run tools/weapons/finish_fx_model <file> <part name>")

local roots = roblox.deserializeModel(fs.readFile(FILE))
local model = roots[1]
assert(model and model:IsA("Model"), `{FILE} should hold one Model`)
local primary = model:FindFirstChild(PART)
assert(primary and primary:IsA("BasePart"), `{FILE} has no part {PART}`)
for _, part in model:GetDescendants() do
	if part:IsA("BasePart") then
		part.PivotOffset = roblox.CFrame.new(part.PivotOffset.Position)
	end
end
model.PrimaryPart = primary
fs.writeFile(FILE, roblox.serializeModel(roots))
print(`{FILE}: finished (PrimaryPart {PART})`)
