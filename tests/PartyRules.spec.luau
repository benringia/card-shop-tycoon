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
	["fight perk: the element's kind with its fight value, rarity and stars as in the shop"] = function()
		expect.equal(config.FIGHT_PERKS.Hype, 0.06)
		expect.equal(config.FIGHT_PERKS.Calm, 0.05)
		expect.equal(config.FIGHT_PERKS.Express, 0.08)
		expect.equal(config.FIGHT_PERKS.Hustle, 0.05)
		expect.equal(config.FIGHT_PERKS.Haggle, 0.06)
		local hype = PartyRules.getFightPerk(config, "Ember", "Common", 0) :: any
		expect.equal(hype.kind, "Hype")
		expect.near(hype.value, 0.06, 1e-9)
		local haggle = PartyRules.getFightPerk(config, "Shade", "Legendary", 5) :: any
		expect.equal(haggle.kind, "Haggle")
		expect.near(haggle.value, 0.27, 1e-9, "0.06 x 3 x 1.5")
		local calm = PartyRules.getFightPerk(config, "Tide", "Legendary", 5) :: any
		expect.near(calm.value, 0.225, 1e-9)
		expect.isNil(PartyRules.getFightPerk(config, "Plasma", "Common", 0), "no element, no perk")
	end,

	["describe a fight perk"] = function()
		local function text(element: string): string
			return PartyRules.describeFight(PartyRules.getFightPerk(config, element, "Common", 0) :: any)
		end
		expect.equal(text("Ember"), "hits 6% harder")
		expect.equal(text("Tide"), "takes 5% less damage")
		expect.equal(text("Bloom"), "skills recharge 8% faster")
		expect.equal(text("Volt"), "creature attacks 5% faster")
		expect.equal(text("Shade"), "6% chance to crit")
	end,

	["describe"] = function()
		local bloom = PartyRules.getPerk(config, "Bloom", "Rare", 0)
		assert(bloom, "expected a perk")
		expect.equal(PartyRules.describe(bloom), "Express: deliveries 15% faster", "bloom")
		local ember = PartyRules.getPerk(config, "Ember", "Common", 0)
		assert(ember, "expected a perk")
		expect.equal(PartyRules.describe(ember), "Hype: customers 5% more often", "ember")
	end,
	["changes: who joined, swapped in or left, by slot"] = function()
		local list = PartyRules.changes({ [1] = "a", [3] = "c" }, { [1] = "b", [2] = "n" }, 3)
		expect.equal(#list, 3, "three slots changed")
		expect.equal(list[1].slot, 1, "slot order")
		expect.equal(list[1].kind, "swapped", "a out, b in")
		expect.equal(list[1].before, "a", "who left")
		expect.equal(list[1].after, "b", "who came")
		expect.equal(list[2].kind, "joined", "an empty slot filled")
		expect.equal(list[2].after, "n", "the newcomer")
		expect.isNil(list[2].before, "nobody left")
		expect.equal(list[3].kind, "left", "a slot emptied")
		expect.equal(list[3].before, "c", "who left")
	end,
	["changes: nothing when the same cards stay"] = function()
		expect.equal(#PartyRules.changes({ [2] = "x" }, { [2] = "x" }, 3), 0, "unchanged")
		expect.equal(#PartyRules.changes({}, {}, 3), 0, "empty party")
	end,
	["changeText: the toast for each change"] = function()
		expect.equal(PartyRules.changeText("joined", "Cindercub", nil), "Cindercub joined your party!", "joined")
		expect.equal(PartyRules.changeText("swapped", "Cindercub", "Ashbeak"), "Cindercub swapped in for Ashbeak!", "swapped")
		expect.equal(PartyRules.changeText("left", nil, "Ashbeak"), "Ashbeak left your party", "left")
	end,
}
