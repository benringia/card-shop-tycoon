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
local expect = require("./lib/expect")

-- Config/Packs needs `script` (Roblox only): two packs in its shape stand in
local PACKS = { ById = { basic = { art = "rbxassetid://111" }, plain = {} } }

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

	["only image ids, each once"] = function()
		local seen = {}
		for _, id in TownPreload.images(CONFIGS) do
			expect.equal(string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
			expect.equal(seen[id], nil, `{id} twice`)
			seen[id] = true
		end
	end,
}
