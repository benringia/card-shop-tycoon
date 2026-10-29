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

	["plans: Legendary is cinematic with gold shards and alive; Common is plain and quick"] = function()
		local legend = RevealRules.plan(CardReveal, "Legendary", false, false)
		expect.equal(legend.cinematic and legend.goldShards and legend.alive, true, "legendary")
		expect.equal(legend.shards > 0 and legend.glintRate > 0 and legend.moteRate > 0 and legend.tilt > 0, true, "legendary amounts")
		local common = RevealRules.plan(CardReveal, "Common", false, false)
		expect.equal(common.tease == 0 and not common.alive and not common.cinematic and common.shards == 0, true, "common")
		expect.equal(RevealRules.plan(CardReveal, "Epic", false, false).cinematic, true, "epic cinematic")
		expect.equal(RevealRules.plan(CardReveal, "Very Rare", false, false).cinematic, false, "very rare not")
		expect.equal(RevealRules.plan(CardReveal, "Rare", false, false).alive, true, "rare alive")
		expect.equal(RevealRules.plan(CardReveal, "Common", true, false).holo, true, "foil is holo")
		expect.equal(RevealRules.plan(CardReveal, "Common", false, false).holo, false, "plain is not")
		local frontier = RevealRules.plan(CardReveal, "Common", false, true)
		expect.equal(frontier.cinematic and frontier.alive and frontier.goldShards, true, "frontier")
	end,

	["scaleCount: low graphics keep a quarter, high and Automatic keep all"] = function()
		expect.equal(RevealRules.scaleCount(40, 1), 10, "level 1")
		expect.equal(RevealRules.scaleCount(40, 7), 40, "level 7")
		expect.equal(RevealRules.scaleCount(40, 0), 40, "Automatic")
		expect.equal(RevealRules.scaleCount(3, 1), 1, "never below one when there was some")
		expect.equal(RevealRules.scaleCount(0, 1), 0, "none stays none")
	end,

	["the plan is a copy, so changing it leaves the config alone"] = function()
		local plan = RevealRules.plan(CardReveal, "Epic", false, false)
		plan.burst = 999
		expect.equal(CardReveal.BY_RARITY.Epic.burst, 24, "config untouched")
	end,
}
