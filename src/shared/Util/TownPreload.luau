--!strict
-- The town's pictures the loading screen keeps drawn before you walk in (LoadingController's shop step; owner
-- 2026-11-09: "same with in town. make sure models and weapon effects are ready"): every UI icon, the pack fronts, the
-- mascot stickers, the binder covers, the level-up textures, the menus' product pictures, the pack opening's effects
-- (Config/PackFx), the portals' swirl and glow and the town's beam textures (Config/Town) and every weapon's portrait
-- (Config/WeaponLooks: the weapon chip, the Armory, the Forge), the register drawer's notes and coins
-- (Config/RegisterStation); and the sounds the shop plays first (TownPreload.sounds). Pure (callers pass the configs
-- in), Lune-tested.
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
	registerStation: any,
	register: any,
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
	for _, id in c.registerStation.MONEY_IMAGES do
		add(id)
	end
	return list
end

-- The sounds the shop plays first, each once (owner 2026-11-16: "make sure loading screen load necessary items"):
-- every level-up set's sound, sting and layers (the Power-up fanfare's rise plays before its badge), the register's
-- scan beep and its sale sounds
function TownPreload.sounds(c: Configs): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: any)
		if typeof(id) == "string" and string.sub(id, 1, #PREFIX) == PREFIX and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	for _, set in c.levelUpFx.SOUNDS.sets do
		add(set.sound.id)
		add(set.sting.id)
		for _, layer in set.layers or {} do
			add(layer.id)
		end
	end
	add(c.register.SCAN_SOUND_ID)
	for _, sound in c.register.SALE_SOUNDS do
		add(sound.id)
	end
	return list
end

return TownPreload
