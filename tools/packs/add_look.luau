--!strict
-- Adds a new set's look to the 3D pack models (docs/packs.md "A new set's look"): a copy of an existing
-- Looks/<from> folder named <look>, each SurfaceAppearance's colour map swapped for the new set's uploaded texture
-- (the seals' metal and roughness maps kept: they are the same for every set). Scripts in the game can't swap a
-- SurfaceAppearance's maps, so the look is baked into the saved models here.
-- Usage: lune run tools/packs/add_look <look> <pack texture id> <display box texture id> [from = FirstSpark]
--   e.g. lune run tools/packs/add_look Frontier rbxassetid://131638783541831 rbxassetid://97900181239583
-- Pack.rbxm: Body, BodyLow, Strip wear the pack texture. DisplayBox.rbxm: Packs1..6 the pack texture, Tray the display
-- box atlas. Running it again replaces that look.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local LOOK, PACK_TEXTURE, DISPLAY_TEXTURE = process.args[1], process.args[2], process.args[3]
local FROM = process.args[4] or "FirstSpark"
assert(LOOK and PACK_TEXTURE and DISPLAY_TEXTURE, "usage: lune run tools/packs/add_look <look> <pack texture id> <display box texture id> [from]")
assert(string.match(PACK_TEXTURE, "^rbxassetid://%d+$") and string.match(DISPLAY_TEXTURE, "^rbxassetid://%d+$"), "texture ids look like rbxassetid://123")

-- Which texture each MeshPart's look wears, per model file
local MODELS = {
	["assets/packs/Pack.rbxm"] = { Body = PACK_TEXTURE, BodyLow = PACK_TEXTURE, Strip = PACK_TEXTURE },
	["assets/packs/DisplayBox.rbxm"] = {
		Packs1 = PACK_TEXTURE,
		Packs2 = PACK_TEXTURE,
		Packs3 = PACK_TEXTURE,
		Packs4 = PACK_TEXTURE,
		Packs5 = PACK_TEXTURE,
		Packs6 = PACK_TEXTURE,
		Tray = DISPLAY_TEXTURE,
	},
}

for path, textures in MODELS do
	local roots = roblox.deserializeModel(fs.readFile(path))
	local model = roots[1]
	assert(model and model:IsA("Model"), `{path}: no model`)
	local looks = model:FindFirstChild("Looks")
	assert(looks, `{path}: no Looks folder`)
	local source = looks:FindFirstChild(FROM)
	assert(source, `{path}: no Looks/{FROM} to copy`)
	local old = looks:FindFirstChild(LOOK)
	if old then
		old:Destroy()
	end
	local look = source:Clone()
	look.Name = LOOK
	local done = 0
	for _, appearance in look:GetChildren() do
		local texture = textures[appearance.Name]
		if appearance:IsA("SurfaceAppearance") and texture then
			(appearance :: any).ColorMapContent = roblox.Content.fromUri(texture)
			done += 1
		end
	end
	for name in textures do
		assert(look:FindFirstChild(name), `{path}: Looks/{FROM} has no {name}`)
	end
	look.Parent = looks
	fs.writeFile(path, roblox.serializeModel(roots))
	print(`{path}: Looks/{LOOK} with {done} appearance(s)`)
end
