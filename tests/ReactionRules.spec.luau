--!strict
-- Reactions (spec 2026-11-06-customers-design): customers stop at your best cards on display and pet your creature
local ReactionRules = require("../src/shared/Util/ReactionRules")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local LEGENDARY = { rarity = "Legendary", foil = false }
local EPIC = { rarity = "Epic", foil = false }

return {
	["epic, legendary or foil cards draw a whoa"] = function()
		expect.equal(ReactionRules.drawsAWhoa(EPIC), true)
		expect.equal(ReactionRules.drawsAWhoa(LEGENDARY), true)
		expect.equal(ReactionRules.drawsAWhoa({ rarity = "Common", foil = true }), true, "any foil")
		expect.equal(ReactionRules.drawsAWhoa({ rarity = "Very Rare", foil = false }), false)
		expect.equal(ReactionRules.drawsAWhoa({ rarity = "Rare", foil = false }), false)
	end,

	["a legendary draws a small crowd"] = function()
		expect.equal(ReactionRules.room(Customers, 0, EPIC), true)
		expect.equal(ReactionRules.room(Customers, 1, EPIC), false, "one watcher at a time")
		expect.equal(ReactionRules.room(Customers, 2, LEGENDARY), true)
		expect.equal(ReactionRules.room(Customers, 3, LEGENDARY), false, "up to 3")
	end,

	["near your creature, some stop to pet it"] = function()
		expect.equal(ReactionRules.pets(Customers, 5, 0.2), true)
		expect.equal(ReactionRules.pets(Customers, 5, 0.5), false, "35% of them")
		expect.equal(ReactionRules.pets(Customers, 9, 0.0), false, "too far")
	end,
}
