--!strict
-- Bakes each weapon model's glow map into it (weapon glow, owner 2026-11-06; docs/weapons.md): every MeshPart gets a
-- SurfaceAppearance named "Glow" holding its own colour map and the model's emissive mask (Config/WeaponLooks
-- GLOW_MAPS; the Forge Sword's five copies share ForgeSword's). A game script can't set those (PluginSecurity), so they
-- live in the files; Util/WeaponLook sets the strength and tint by the weapon's level. Run it again after re-importing a
-- model or running forge_variants (it replaces its own "Glow" each time).
-- Usage: lune run tools/weapons/add_glow_maps
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local WeaponLooks = require("../../src/shared/Config/WeaponLooks")

local MODELS = {
	SunforgedBlade = "SunforgedBlade",
	VerdantBlade = "VerdantBlade",
	PrismBlade = "PrismBlade",
	ForgeSword_Ember = "ForgeSword",
	ForgeSword_Tide = "ForgeSword",
	ForgeSword_Bloom = "ForgeSword",
	ForgeSword_Volt = "ForgeSword",
	ForgeSword_Shade = "ForgeSword",
}

-- A MeshPart's colour map: newer files keep it as TextureContent (a Content), older ones as TextureID
local function textureOf(part: any): string?
	local ok, content = pcall(function()
		return part.TextureContent
	end)
	if ok and content and content.Uri and content.Uri ~= "" then
		return content.Uri
	end
	local okId, id = pcall(function()
		return part.TextureID
	end)
	return if okId and id ~= "" then id else nil
end

for file, mapName in MODELS do
	local mask = (WeaponLooks.GLOW_MAPS :: any)[mapName]
	assert(mask, `no glow map for {mapName}`)
	local path = `assets/weapons/{file}.rbxm`
	local roots = roblox.deserializeModel(fs.readFile(path))
	local model = roots[1]
	assert(model and model:IsA("Model"), `{path} should hold one Model`)
	local baked = 0
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			local colorMap = textureOf(part)
			assert(colorMap, `{path}: {part.Name} has no colour map`)
			local old = part:FindFirstChild("Glow")
			if old then
				old:Destroy()
			end
			local look = roblox.Instance.new("SurfaceAppearance") :: any
			look.Name = "Glow"
			look.ColorMapContent = roblox.Content.fromUri(colorMap)
			look.EmissiveMaskContent = roblox.Content.fromUri(mask)
			look.EmissiveStrength = 0 -- Util/WeaponLook sets it by level
			look.EmissiveTint = roblox.Color3.new(1, 1, 1)
			look.Parent = part
			baked += 1
		end
	end
	assert(baked > 0, `{path} has no MeshPart`)
	fs.writeFile(path, roblox.serializeModel(roots))
	print(`{path}: {baked} parts -> {mask}`)
end
