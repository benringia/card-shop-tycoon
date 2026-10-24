--!strict
local CardReveal = require("../src/shared/Config/CardReveal")
local RevealRules = require("../src/shared/Util/RevealRules")
local expect = require("./lib/expect")

return {
	["a plain common flips at once with no show"] = function()
		local plan = RevealRules.plan(CardReveal, "Common", false, false)
		expect.equal(plan.tease, 0, "tease")
		expect.equal(plan.burst, 0, "burst")
		expect.equal(plan.banner, nil, "banner")
		expect.equal(plan.spotlight, false, "spotlight")
	end,

	["a legendary gets the full show"] = function()
		local plan = RevealRules.plan(CardReveal, "Legendary", false, false)
		expect.equal(plan.tease, 2, "tease")
		expect.equal(plan.rays, true, "rays")
		expect.equal(plan.flash, true, "flash")
		expect.equal(plan.spotlight, true, "spotlight")
		expect.equal(plan.banner, "LEGENDARY!", "banner")
	end,

	["foil adds sparks, a minimum tease and the FOIL prefix"] = function()
		local plain = RevealRules.plan(CardReveal, "Rare", false, false)
		local foil = RevealRules.plan(CardReveal, "Rare", true, false)
		expect.equal(foil.burst, plain.burst + CardReveal.FOIL.EXTRA_BURST, "burst")
		expect.equal(foil.tease, CardReveal.FOIL.MIN_TEASE, "tease raised to the foil minimum")
		expect.equal(foil.banner, "FOIL RARE!", "banner")
	end,

	["a foil common still gets a banner"] = function()
		local plan = RevealRules.plan(CardReveal, "Common", true, false)
		expect.equal(plan.banner, "FOIL!", "banner")
		expect.equal(plan.tease, CardReveal.FOIL.MIN_TEASE, "tease")
	end,

	["frontier cards use the frontier show"] = function()
		local plan = RevealRules.plan(CardReveal, "Rare", false, true)
		expect.equal(plan.banner, "FRONTIER!", "banner")
		expect.equal(plan.spotlight, true, "spotlight")
	end,

	["an unknown rarity falls back to common"] = function()
		local plan = RevealRules.plan(CardReveal, "Mythic", false, false)
		expect.equal(plan.tease, 0, "tease")
		expect.equal(plan.banner, nil, "banner")
	end,

	["the plan is a copy, so changing it leaves the config alone"] = function()
		local plan = RevealRules.plan(CardReveal, "Epic", false, false)
		plan.burst = 999
		expect.equal(CardReveal.BY_RARITY.Epic.burst, 24, "config untouched")
	end,
}
