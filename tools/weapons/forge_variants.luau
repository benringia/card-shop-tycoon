--!strict
-- A Forge weapon's five element copies (the Forge Sword, weapons round 1; the Forge Spear, round 2; docs/weapons.md):
-- reads the imported, finished assets/weapons-source/<Model>.rbxm (not synced: players only need the five copies) and
-- writes assets/weapons/<Model>_<Element>.rbxm for each element, the model renamed and every colour map
-- (SurfaceAppearance ColorMap, a MeshPart's TextureID) swapped for that element's (Config/WeaponLooks
-- FORGE_COLOR_MAPS[<Model>]: the gems tinted). Config/Weapons names those models.
-- Usage: lune run tools/weapons/forge_variants [ForgeSword | ForgeSpear] (default ForgeSword)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local WeaponLooks = require("../../src/shared/Config/WeaponLooks")

local MODEL = process.args[1] or "ForgeSword"
local SOURCE = `assets/weapons-source/{MODEL}.rbxm`
local maps = (WeaponLooks.FORGE_COLOR_MAPS :: { [string]: { [string]: string } })[MODEL]
assert(maps and next(maps), `no FORGE_COLOR_MAPS for {MODEL} in Config/WeaponLooks`)

for element, colorMap in maps do
	local roots = roblox.deserializeModel(fs.readFile(SOURCE))
	local model = roots[1]
	assert(model and model:IsA("Model"), `{SOURCE} should hold one Model`)
	model.Name = `{MODEL}_{element}`
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
	local out = `assets/weapons/{MODEL}_{element}.rbxm`
	fs.writeFile(out, roblox.serializeModel(roots))
	print(`{out}: {swapped} colour maps -> {colorMap}`)
end
