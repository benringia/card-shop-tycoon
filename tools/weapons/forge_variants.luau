--!strict
-- The Forge Sword's five element copies (weapons round 1; docs/weapons.md): reads the imported, finished
-- assets/weapons-source/ForgeSword.rbxm (not synced: players only need the five copies) and writes
-- assets/weapons/ForgeSword_<Element>.rbxm for each element, the model renamed and every
-- colour map (SurfaceAppearance ColorMap, a MeshPart's TextureID) swapped for that element's
-- (Config/WeaponLooks FORGE_COLOR_MAPS: the gems tinted). Config/Weapons names those models.
-- Usage: lune run tools/weapons/forge_variants
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local WeaponLooks = require("../../src/shared/Config/WeaponLooks")

local SOURCE = "assets/weapons-source/ForgeSword.rbxm"

for element, colorMap in WeaponLooks.FORGE_COLOR_MAPS :: { [string]: string } do
	local roots = roblox.deserializeModel(fs.readFile(SOURCE))
	local model = roots[1]
	assert(model and model:IsA("Model"), `{SOURCE} should hold one Model`)
	model.Name = `ForgeSword_{element}`
	local swapped = 0
	for _, item in model:GetDescendants() do
		if item:IsA("SurfaceAppearance") then
			local ok = pcall(function()
				local look = item :: any
				look.ColorMap = colorMap
			end)
			if not ok then
				local look = item :: any
				look.ColorMapContent = roblox.Content.fromUri(colorMap)
			end
			swapped += 1
		elseif item:IsA("MeshPart") then
			-- Newer files keep the texture as TextureContent (a Content), older ones as TextureID
			local ok = pcall(function()
				local part = item :: any
				assert(part.TextureID ~= "")
				part.TextureID = colorMap
			end)
			if not ok then
				local part = item :: any
				part.TextureContent = roblox.Content.fromUri(colorMap)
			end
			swapped += 1
		end
	end
	assert(swapped > 0, `{SOURCE} has no colour map to swap`)
	local out = `assets/weapons/ForgeSword_{element}.rbxm`
	fs.writeFile(out, roblox.serializeModel(roots))
	print(`{out}: {swapped} colour maps -> {colorMap}`)
end
