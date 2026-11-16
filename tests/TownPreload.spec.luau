--!strict
-- The town's pictures the loading screen keeps drawn before you walk in (Util/TownPreload; owner 2026-11-09: "same with
-- in town. make sure models and weapon effects are ready"): the shop's first pictures as before, plus the pack opening's
-- effects, the portals' swirl and every weapon's portrait (a Studio check found these unfetched when the screen closed)
local TownPreload = require("../src/shared/Util/TownPreload")
local UIIcons = require("../src/shared/Config/UIIcons")
local HudMascot = require("../src/shared/Config/HudMascot")
local BinderCovers = require("../src/shared/Config/BinderCovers")
local LevelUpFx = require("../src/shared/Config/LevelUpFx")
local ProductPictures = require("../src/shared/Config/ProductPictures")
local PackFx = require("../src/shared/Config/PackFx")
local Town = require("../src/shared/Config/Town")
local WeaponLooks = require("../src/shared/Config/WeaponLooks")
local RegisterStation = require("../src/shared/Config/RegisterStation")
local expect = require("./lib/expect")

-- Config/Packs needs `script` (Roblox only): two packs in its shape stand in
local PACKS = { ById = { basic = { art = "rbxassetid://111" }, plain = {} } }
-- Config/Register holds a Vector3 (Roblox only): its sounds in its shape stand in
local Register = { SCAN_SOUND_ID = "rbxassetid://201", SALE_SOUNDS = { { id = "rbxassetid://202", volume = 0.5 }, { id = "rbxassetid://203", volume = 0.3 } } }

local CONFIGS = {
	uiIcons = UIIcons,
	packs = PACKS,
	hudMascot = HudMascot,
	binderCovers = BinderCovers,
	levelUpFx = LevelUpFx,
	productPictures = ProductPictures,
	packFx = PackFx,
	town = Town,
	weaponLooks = WeaponLooks,
	registerStation = RegisterStation,
	register = Register,
}

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

return {
	["the shop's first pictures, as before"] = function()
		local ids = TownPreload.images(CONFIGS)
		for name, id in UIIcons do
			if typeof(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://" then
				expect.equal(has(ids, id), true, `icon {name}`)
			end
		end
		expect.equal(has(ids, "rbxassetid://111"), true, "a pack's front")
		for _, id in LevelUpFx.IMAGES do
			expect.equal(has(ids, id), true, "a level-up texture")
		end
		for _, cover in BinderCovers.SETS do
			expect.equal(has(ids, cover.art), true, "a binder cover")
		end
	end,

	["the pack opening's effects, the portals' swirl and every weapon's portrait"] = function()
		local ids = TownPreload.images(CONFIGS)
		for name, id in PackFx.IMAGES do
			expect.equal(has(ids, id), true, `pack effect {name}`)
		end
		for name, sheet in PackFx.SHEETS do
			expect.equal(has(ids, sheet.image), true, `pack effect sheet {name}`)
		end
		expect.equal(has(ids, Town.PORTAL_FX.VORTEX_TEXTURE), true, "the portals' swirl")
		expect.equal(has(ids, Town.PORTAL_FX.GLOW_TEXTURE), true, "the portals' glow")
		for weaponId, look in WeaponLooks.WEAPONS do
			if look.portrait ~= "" then
				expect.equal(has(ids, look.portrait), true, `{weaponId}'s portrait`)
			end
		end
	end,

	-- Owner 2026-11-09: "in town. some models still load some time after the loading screen": a mesh is only fetched
	-- once it's drawn up close, so the scenery popped in as you walked; the loading screen streams in the area round you
	-- and fetches every town folder's meshes and textures first
	["the loading screen fetches the town's scenery, shops and plots"] = function()
		local LoadingScreen = require("../src/shared/Config/LoadingScreen")
		for _, name in { "TownDecor", "Town", "Scenery", "Plots" } do
			expect.equal(table.find(LoadingScreen.TOWN_FOLDERS, name) ~= nil, true, name)
		end
		expect.equal(LoadingScreen.STREAM_TIMEOUT > 0 and LoadingScreen.STREAM_TIMEOUT < LoadingScreen.MAX_SECONDS, true, "streaming in never holds it past its cap")
	end,

	-- Owner 2026-11-16: "make sure loading screen load necessary items before letting players play": the register's
	-- notes and coins (its drawer opens on your first cash sale)
	["the register's money pictures"] = function()
		local ids = TownPreload.images(CONFIGS)
		for cents, id in RegisterStation.MONEY_IMAGES do
			expect.equal(has(ids, id), true, `money {cents}`)
		end
	end,

	["the sounds the shop plays first: every level-up set's sound, sting and layers, the register's beep and sale"] = function()
		local ids = TownPreload.sounds(CONFIGS)
		for index, set in LevelUpFx.SOUNDS.sets do
			expect.equal(has(ids, set.sound.id), true, `set {index} sound`)
			expect.equal(has(ids, set.sting.id), true, `set {index} sting`)
			for layerIndex, layer in set.layers or {} do
				expect.equal(has(ids, layer.id), true, `set {index} layer {layerIndex}`)
			end
		end
		expect.equal(has(ids, Register.SCAN_SOUND_ID), true, "the scan beep")
		for _, sound in Register.SALE_SOUNDS do
			expect.equal(has(ids, sound.id), true, "a sale sound")
		end
		local seen = {}
		for _, id in ids do
			expect.equal(seen[id], nil, `{id} twice`)
			seen[id] = true
		end
	end,

	["only image ids, each once"] = function()
		local seen = {}
		for _, id in TownPreload.images(CONFIGS) do
			expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
			expect.equal(seen[id], nil, `{id} twice`)
			seen[id] = true
		end
	end,
}
