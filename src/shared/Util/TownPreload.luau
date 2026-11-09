--!strict
-- The town's pictures the loading screen keeps drawn before you walk in (LoadingController's shop step; owner
-- 2026-11-09: "same with in town. make sure models and weapon effects are ready"): every UI icon, the pack fronts, the
-- mascot stickers, the binder covers, the level-up textures, the menus' product pictures, the pack opening's effects
-- (Config/PackFx), the portals' swirl and glow and the town's beam textures (Config/Town) and every weapon's portrait
-- (Config/WeaponLooks: the weapon chip, the Armory, the Forge). Pure (callers pass the configs in), Lune-tested.
local TownPreload = {}

export type Configs = {
	uiIcons: any,
	packs: any,
	hudMascot: any,
	binderCovers: any,
	levelUpFx: any,
	productPictures: any,
	packFx: any,
	town: any,
	weaponLooks: any,
}

local PREFIX = "rbxassetid://"

function TownPreload.images(c: Configs): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: any)
		if typeof(id) == "string" and string.sub(id, 1, #PREFIX) == PREFIX and #id > #PREFIX and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	-- every `texture` anywhere in a table (the town's fountain and lava streams)
	local function textures(value: any)
		if typeof(value) ~= "table" then
			return
		end
		for key, child in value do
			if key == "texture" then
				add(child)
			else
				textures(child)
			end
		end
	end
	for _, id in c.uiIcons do
		add(id)
	end
	for _, pack in c.packs.ById do
		add(pack.art)
	end
	for _, id in c.hudMascot.images do
		add(id)
	end
	for _, cover in c.binderCovers.SETS do
		add(cover.art)
	end
	for _, id in c.levelUpFx.IMAGES do
		add(id)
	end
	for _, pictures in c.productPictures.LOOKS do
		for _, id in pictures do
			add(id)
		end
	end
	for _, id in c.packFx.IMAGES do
		add(id)
	end
	for _, sheet in c.packFx.SHEETS do
		add(sheet.image)
	end
	add(c.town.PORTAL_FX.VORTEX_TEXTURE)
	add(c.town.PORTAL_FX.GLOW_TEXTURE)
	textures(c.town)
	for _, look in c.weaponLooks.WEAPONS do
		add(look.portrait)
	end
	return list
end

return TownPreload
