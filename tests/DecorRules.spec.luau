--!strict
-- Shop decor (spec 2026-11-14-shop-decor-design): the six shop looks bought and switched, a save cleaned on load, and
-- the decor part of the shop rating (a bought look plus a few placed pieces fill it)
local DecorRules = require("../src/shared/Util/DecorRules")
local Decor = require("../src/shared/Config/Decor")
local expect = require("./lib/expect")

local MATERIALS = { WoodPlanks = true, Wood = true, SmoothPlastic = true, Slate = true, Grass = true, Marble = true }

local function near(actual: number, expected: number, label: string?)
	assert(math.abs(actual - expected) < 1e-6, `{label or ""}: expected {expected}, got {actual}`)
end

local function isColor(value: any): boolean
	if typeof(value) ~= "table" or #value ~= 3 then
		return false
	end
	for _, channel in value do
		if typeof(channel) ~= "number" or channel < 0 or channel > 255 then
			return false
		end
	end
	return true
end

return {
	["a bought look plus four or five pieces fills the decor part"] = function()
		near(DecorRules.score(Decor, "CandyPastel", { 1, 1, 2 }), 0.75, "a look and three pieces")
		near(DecorRules.score(Decor, "CandyPastel", { 1, 1, 2, 2 }), 1, "a look and four pieces")
		near(DecorRules.score(Decor, "CandyPastel", { 1, 1, 1, 1, 1, 1 }), 1, "a look and six plain pieces")
		near(DecorRules.score(Decor, "CozyWood", table.create(20, 3)), 1, "never above 1")
		near(DecorRules.score(Decor, "CozyWood", {}), 0, "the default look alone gives nothing")
		near(DecorRules.score(Decor, "Disco", { 2 }), 0.25, "an unknown look gives nothing")
	end,

	["buying a look: unknown, owned, locked, short, fine"] = function()
		local state = { look = "CozyWood", owned = { "CandyPastel" } }
		expect.equal(select(2, DecorRules.canBuy(Decor, state, "Disco", 50, 1e6)), "That look doesn't exist.")
		expect.equal(select(2, DecorRules.canBuy(Decor, state, "CandyPastel", 50, 1e6)), "You already own Candy Pastel.")
		expect.equal(select(2, DecorRules.canBuy(Decor, state, "CozyWood", 50, 1e6)), "You already own Cozy Wood.")
		expect.equal(select(2, DecorRules.canBuy(Decor, state, "StarryNight", 15, 1e6)), "Starry Night unlocks at shop level 16.")
		expect.equal(select(2, DecorRules.canBuy(Decor, state, "NeonArcade", 8, 1999)), "You need $2000 for Neon Arcade.")
		expect.equal(DecorRules.canBuy(Decor, state, "NeonArcade", 8, 2000), true)
	end,

	["using a look: any owned one, whatever the level"] = function()
		local state = { look = "CozyWood", owned = { "StarryNight" } }
		expect.equal(DecorRules.canUse(Decor, state, "StarryNight"), true, "owned at level 16 earlier, still usable")
		expect.equal(DecorRules.canUse(Decor, state, "CozyWood"), true)
		expect.equal(select(2, DecorRules.canUse(Decor, state, "CandyPastel")), "Buy Candy Pastel first.")
		expect.equal(select(2, DecorRules.canUse(Decor, state, "Disco")), "That look doesn't exist.")
		expect.equal(DecorRules.owns(Decor, state, "CozyWood"), true, "the default is always owned")
		expect.equal(DecorRules.owns(Decor, state, "NeonArcade"), false)
	end,

	["a save is cleaned: unknown ids dropped, the look in use must be owned, the default never stored"] = function()
		local state = DecorRules.clean(Decor, { look = "StarryNight", owned = { "CandyPastel", "Disco", 7, "CozyWood", "CandyPastel" } })
		expect.equal(state.look, "CozyWood", "Starry Night isn't owned")
		expect.equal(table.concat(state.owned, ","), "CandyPastel")
		expect.equal(DecorRules.clean(Decor, "junk").look, "CozyWood")
		expect.equal(#DecorRules.clean(Decor, nil).owned, 0)
		expect.equal(DecorRules.clean(Decor, { look = "CandyPastel", owned = { "CandyPastel" } }).look, "CandyPastel")
	end,

	["looks: the default free at level 1, then dearer and later, colours and materials Roblox knows"] = function()
		local first = Decor.LOOKS[1]
		expect.equal(first.id, Decor.DEFAULT_LOOK)
		expect.equal(first.price, 0)
		expect.equal(first.level, 1)
		expect.equal(#Decor.LOOKS, 6)
		local seen: { [string]: boolean } = {}
		for index, look in Decor.LOOKS do
			assert(not seen[look.id], `{look.id} twice`)
			seen[look.id] = true
			assert(DecorRules.look(Decor, look.id) == look, `{look.id} found by id`)
			assert(typeof(look.name) == "string" and #look.name > 0, `{look.id} has a name`)
			if index > 1 then
				local before = Decor.LOOKS[index - 1]
				assert(look.price > before.price, `{look.id} dearer than {before.id}`)
				assert(look.level > before.level, `{look.id} later than {before.id}`)
				expect.equal(DecorRules.lookPoints(Decor, look.id), Decor.LOOK_POINTS)
			end
			for _, key in { "floor", "wall", "band", "trim" } do
				assert(isColor((look :: any)[key]), `{look.id}.{key} is a colour`)
			end
			assert(MATERIALS[look.floorMaterial], `{look.id} floor material {look.floorMaterial}`)
			assert(MATERIALS[look.bandMaterial], `{look.id} band material {look.bandMaterial}`)
			assert(look.tile > 0, `{look.id} wallpaper tile size`)
			if look.extra then
				assert(look.extra == "topStrip" or look.extra == "crystals", `{look.id} extra {look.extra}`)
				assert(isColor(look.extraColor), `{look.id} extra colour`)
			end
		end
		expect.equal(DecorRules.lookPoints(Decor, Decor.DEFAULT_LOOK), 0)
		expect.equal(Decor.LOOK_POINTS, 2)
		expect.equal(Decor.FULL, 8)
	end,

	["every look has its uploaded wallpaper"] = function()
		for _, look in Decor.LOOKS do
			assert(string.match(look.wallpaper, "^rbxassetid://%d+$"), `{look.id} wallpaper {look.wallpaper}`)
		end
	end,

	["the piece cap"] = function()
		expect.equal(DecorRules.fitsCap(19, 20), true)
		expect.equal(DecorRules.fitsCap(20, 20), false)
	end,
}
