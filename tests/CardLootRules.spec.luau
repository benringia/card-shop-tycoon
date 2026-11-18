--!strict
-- A monster's dropped card on the ground (owner 2026-11-18, pick C "loot beam"; Config/CardLoot): when it's picked up,
-- comes to you or just fades, and its landing
local CardLootRules = require("../src/shared/Util/CardLootRules")
local CardLoot = require("../src/shared/Config/CardLoot")
local expect = require("./lib/expect")

return {
	["walking near picks it up, once it has been seen a moment"] = function()
		expect.equal(CardLootRules.next(0.1, CardLoot.pickupRange - 0.5, CardLoot), "wait", "right beside it as it lands: it shows first")
		expect.equal(CardLootRules.next(CardLoot.showFor, CardLoot.pickupRange - 0.5, CardLoot), "pickup", "then it's picked up")
		expect.equal(CardLootRules.next(3, CardLoot.pickupRange, CardLoot), "pickup", "at the edge")
		expect.equal(CardLootRules.next(1, CardLoot.pickupRange + 5, CardLoot), "wait", "not yet: it waits")
		assert(CardLoot.showFor >= CardLoot.land.seconds and CardLoot.showFor < CardLoot.autoSeconds, "it lands and is seen first")
	end,

	["left alone it comes to you, unless you went far away (then it just fades: it's yours already)"] = function()
		expect.equal(CardLootRules.next(CardLoot.autoSeconds, 30, CardLoot), "come", "a while: it comes")
		expect.equal(CardLootRules.next(CardLoot.autoSeconds, CardLoot.farRange + 1, CardLoot), "fade", "you left")
		expect.equal(CardLootRules.next(0.5, nil, CardLoot), "fade", "no character (respawning, travelling)")
	end,

	["it lands on its spot with a little bounce, never in the ground"] = function()
		local land = CardLoot.land
		expect.near(CardLootRules.landing(0, CardLoot), CardLoot.hover + land.from, 1e-9, "starts above its spot")
		expect.near(CardLootRules.landing(land.seconds, CardLoot), CardLoot.hover, 1e-9, "ends on its spot")
		expect.near(CardLootRules.landing(land.seconds + 3, CardLoot), CardLoot.hover, 1e-9, "stays")
		local lowest = math.huge
		for step = 0, 100 do
			lowest = math.min(lowest, CardLootRules.landing(land.seconds * step / 100, CardLoot))
		end
		assert(lowest < CardLoot.hover, "it dips below its spot a little (the bounce)")
		assert(lowest > CardLoot.cardHeight / 2, "but never into the ground")
	end,

	["the beam towers over the card; it waits a few seconds before it comes"] = function()
		assert(CardLoot.beam.height > CardLoot.hover * 8, "seen from far away")
		assert(CardLoot.autoSeconds >= 2 and CardLoot.autoSeconds <= 8, "time to walk over first")
		assert(CardLoot.farRange > CardLoot.pickupRange * 5, "it comes from across a clearing")
	end,
}
