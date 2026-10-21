--!strict
local PartyRules = require("../src/shared/Util/PartyRules")
local config = require("../src/shared/Config/Party")
local expect = require("./lib/expect")

return {
	["perk by element and rarity"] = function()
		local hype = PartyRules.getPerk(config, "Ember", "Common", 0)
		assert(hype, "expected a perk")
		expect.equal(hype.kind, "Hype", "kind")
		expect.near(hype.value, 0.05, 1e-9, "common")
		local legendary = PartyRules.getPerk(config, "Ember", "Legendary", 0)
		assert(legendary, "expected a perk")
		expect.near(legendary.value, 0.15, 1e-9, "legendary")
		local tide = PartyRules.getPerk(config, "Tide", "Epic", 0)
		assert(tide, "expected a perk")
		expect.near(tide.value, 0.25, 1e-9, "tide epic")
	end,
	["stars add 10% each"] = function()
		local volt = PartyRules.getPerk(config, "Volt", "Common", 5)
		assert(volt, "expected a perk")
		expect.near(volt.value, 0.05 * 1.5, 1e-9, "5 stars")
	end,
	["unknown element or rarity"] = function()
		expect.isNil(PartyRules.getPerk(config, "Plasma", "Common", 0), "no perk")
		local shade = PartyRules.getPerk(config, "Shade", "Mythic", 0)
		assert(shade, "expected a perk")
		expect.near(shade.value, 0.05, 1e-9, "rarity x1")
	end,
	["describe"] = function()
		local bloom = PartyRules.getPerk(config, "Bloom", "Rare", 0)
		assert(bloom, "expected a perk")
		expect.equal(PartyRules.describe(bloom), "Express: deliveries 15% faster", "bloom")
		local ember = PartyRules.getPerk(config, "Ember", "Common", 0)
		assert(ember, "expected a perk")
		expect.equal(PartyRules.describe(ember), "Hype: customers 5% more often", "ember")
	end,
}
