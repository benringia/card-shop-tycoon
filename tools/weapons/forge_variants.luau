--!strict
-- The Forge Sword's five element copies (weapons round 1; docs/weapons.md): reads the imported, finished
-- assets/weapons/ForgeSword.rbxm and writes ForgeSword_<Element>.rbxm for each element, the model renamed and every
-- colour map (SurfaceAppearance ColorMap, a MeshPart's TextureID) swapped for that element's
-- (Config/WeaponLooks FORGE_COLOR_MAPS: the gems tinted). Config/Weapons names those models.
-- Usage: lune run tools/weapons/forge_variants
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local WeaponLooks = require("../../src/shared/Config/WeaponLooks")

local SOURCE = "assets/weapons/ForgeSword.rbxm"

for element, colorMap in WeaponLooks.FORGE_COLOR_MAPS :: { [string]: string } do
	local roots = roblox.deserializeModel(fs.readFile(SOURCE))
	local model = roots[1]
	assert(model and model:IsA("Model"), `{SOURCE} should hold one Model`)
	model.Name = `ForgeSword_{element}`
	local swapped = 0
	for _, item in model:GetDescendants() do
		if item:IsA("SurfaceAppearance") then
			local ok = pcall(function()
				(item :: any).ColorMap = colorMap
			end)
			if not ok then
				(item :: any).ColorMapContent = roblox.Content.fromUri(colorMap)
			end
			swapped += 1
		elseif item:IsA("MeshPart") and (item :: any).TextureID ~= "" then
			(item :: any).TextureID = colorMap
			swapped += 1
		end
	end
	assert(swapped > 0, `{SOURCE} has no colour map to swap`)
	local out = `assets/weapons/ForgeSword_{element}.rbxm`
	fs.writeFile(out, roblox.serializeModel(roots))
	print(`{out}: {swapped} colour maps -> {colorMap}`)
end
