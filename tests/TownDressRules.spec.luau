--!strict
-- The town's dressing (owner 2026-11-19: "do town beauties"): leaves falling from the plaza's trees, a shooting star
-- now and then at night, and on a weekly event's day (Boss Rush, Lucky Sunday) a small banner on every street light.
-- All client side and cheap: a few parts and particles, no lights, no GUIs. Config/TownDress, Util/TownDressRules.
-- The first build strung lights from lamp to lamp with pennants between them; the owner the same day: "remove/replace
-- string lights. it's too much. its also covering the shops entrances". So nothing hangs across a shop front any
-- more: the banners sit on the lamp posts, which stand in the gaps between the shops.
local TownDress = require("../src/shared/Config/TownDress")
local TownDressRules = require("../src/shared/Util/TownDressRules")
local Events = require("../src/shared/Config/Events")
local expect = require("./lib/expect")

return {
	["no string lights: nothing in the dressing hangs between the lamps"] = function()
		local cfg: any, rules: any = TownDress, TownDressRules
		expect.isNil(cfg.LIGHTS, "no strings, bulbs or pennants")
		expect.isNil(rules.spans, "no spans between lamps")
		expect.isNil(rules.bulbs)
	end,

	["a plain day has no banners; an event's day has its own on the lamp posts"] = function()
		expect.isNil(TownDressRules.look(TownDress, nil), "a plain day")
		expect.isNil(TownDressRules.look(TownDress, "nope"), "an event without dressing")
		for _, event in Events.DAYS do
			local look = TownDressRules.look(TownDress, event.id)
			assert(look, `{event.id}: its banner`)
			assert(#look.color == 3 and #look.tint == 3, `{event.id}: its colours`)
			assert(string.find(look.image, "rbxassetid://", 1, true), `{event.id}: its picture`)
		end
	end,

	["a banner hangs on its lamp post, off the ground, facing the street"] = function()
		local banners = TownDress.BANNERS
		-- a north-row lamp (the street is toward +z from it)
		local x, y, z, faceZ = TownDressRules.banner({ x = -32, z = -44.9 }, banners)
		expect.near(math.abs(x - -32), banners.out, 1e-6, "beside its pole")
		expect.near(z, -44.9, 1e-6, "in line with the lamps, never out over a shop front")
		expect.equal(y, banners.height)
		expect.equal(faceZ, 1, "toward the street")
		local _, _, _, south = TownDressRules.banner({ x = 88, z = 44.9 }, banners)
		expect.equal(south, -1, "the south row faces north")
		assert(banners.height - banners.size.y / 2 >= 5.5, "over a player's head")
		assert(banners.size.x <= 2 and banners.size.y <= 3, "small: one per lamp, eight in the town")
	end,

	["leaves fall slowly and a shooting star is rare"] = function()
		local leaves = TownDress.LEAVES
		assert(leaves.rate > 0 and leaves.rate * leaves.life[2] <= 12, "at most a dozen leaves a tree in the air")
		assert(string.find(leaves.texture, "rbxassetid://", 1, true), "its uploaded picture")
		local star = TownDress.STAR
		assert(star.every[1] >= 30, "never a meteor shower")
		expect.equal(TownDressRules.starShows(0.2, star), false, "not by day or at dusk")
		expect.equal(TownDressRules.starShows(star.night, star), true, "deep in the night")
	end,
}
