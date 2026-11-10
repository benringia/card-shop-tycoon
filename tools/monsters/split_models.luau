--!strict
-- Splits a saved folder of finished monster and boss models (imported in Studio, finished by Claude through the Studio
-- MCP, the folder saved once by the owner, e.g. assets/props-import/FrontierModels.rbxm) into one
-- assets/monsters/<Model name>.rbxm per model, as MonsterController finds them (species names like "Frost Wisp", boss
-- ids like "frostTyrant"). Each model is written as it is.
-- Usage: lune run tools/monsters/split_models <folder.rbxm> [out folder, default assets/monsters]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local FILE = process.args[1]
local OUT = process.args[2] or "assets/monsters"
assert(FILE, "usage: lune run tools/monsters/split_models <folder.rbxm> [out folder]")

local roots = roblox.deserializeModel(fs.readFile(FILE))
local count = 0
for _, root in roots do
	local models = if root:IsA("Model") and root:FindFirstChildWhichIsA("MeshPart") then { root } else root:GetChildren()
	for _, model in models do
		if model:IsA("Model") then
			model.Parent = nil
			local path = `{OUT}/{model.Name}.rbxm`
			fs.writeFile(path, roblox.serializeModel({ model }))
			print(`{path}`)
			count += 1
		end
	end
end
assert(count > 0, `{FILE} holds no models`)
