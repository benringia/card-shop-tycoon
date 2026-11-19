--!strict
local CardReveal = require("../src/shared/Config/CardReveal")
local RevealRules = require("../src/shared/Util/RevealRules")
local expect = require("./lib/expect")

return {
	-- Owner 2026-11-17 ("do all": the creature comes alive; Pokemon TCG Pocket's immersive cards): an Epic, a Legendary,
	-- a Frontier card or a card you never had bursts out of its card on the stage
	["the creature comes alive for big and new cards"] = function()
		expect.equal(RevealRules.comesAlive("Epic", false, false), true)
		expect.equal(RevealRules.comesAlive("Legendary", false, false), true)
		expect.equal(RevealRules.comesAlive("Common", false, true), true, "a Frontier card")
		expect.equal(RevealRules.comesAlive("Common", true, false), true, "a card you never had")
		expect.equal(RevealRules.comesAlive("Very Rare", false, false), false, "a Very Rare you have")
		expect.equal(RevealRules.comesAlive("Common", false, false), false, "a Common you have")
		-- Owner 2026-11-19 ("on early game, the creature models shown when opening a pack is rough and not loaded
		-- fully"): a creature whose model isn't downloaded yet stays in its card (the card still reveals)
		expect.equal(RevealRules.comesAlive("Legendary", true, false, false), false, "its model isn't in yet")
		expect.equal(RevealRules.comesAlive("Common", true, false, false), false, "a new card, model not in yet")
		expect.equal(RevealRules.comesAlive("Epic", false, false, true), true, "its model is in")
		local alive = CardReveal.CREATURE
		assert(alive.holdSeconds >= 1 and alive.holdSeconds <= 3, "a moment, not a wait")
		assert(alive.height > 0 and alive.popSeconds > 0 and alive.backSeconds > 0, "its size and timings")
	end,

	-- Owner 2026-11-17 ("do all": the pack trembles): a pack holding an Epic or better shivers and glows before it's torn;
	-- sometimes one with a Very Rare does too (a fake-out keeps it a guess); nothing less ever does
	["a heavy pack: Epic or better inside, sometimes a Very Rare as a fake-out"] = function()
		local tell = CardReveal.PACK_TELL
		expect.equal(RevealRules.packTell(tell, { "Common", "Rare", "Epic" }, 0.99), true, "an Epic")
		expect.equal(RevealRules.packTell(tell, { "Legendary" }, 0.99), true, "a Legendary")
		expect.equal(RevealRules.packTell(tell, { "Common", "Very Rare" }, tell.fakeOut - 0.01), true, "a fake-out")
		expect.equal(RevealRules.packTell(tell, { "Common", "Very Rare" }, tell.fakeOut + 0.01), false, "most Very Rares don't")
		expect.equal(RevealRules.packTell(tell, { "Common", "Rare", "Rare" }, 0), false, "never for less")
		expect.equal(RevealRules.packTell(tell, {}, 0), false, "an empty pack")
		assert(tell.fakeOut > 0 and tell.fakeOut < 0.5, "a fake-out now and then")
	end,

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

	-- Owner 2026-11-17 ("highlight any veryrare and above cards on the after opening 10cards")
	["Open 10's best pulls: Very Rare and up stand out"] = function()
		expect.equal(RevealRules.standsOut("Very Rare", "Very Rare"), true, "a Very Rare")
		expect.equal(RevealRules.standsOut("Epic", "Very Rare"), true, "an Epic")
		expect.equal(RevealRules.standsOut("Legendary", "Very Rare"), true, "a Legendary")
		expect.equal(RevealRules.standsOut("Rare", "Very Rare"), false, "not a Rare")
		expect.equal(RevealRules.standsOut("Common", "Very Rare"), false, "not a Common")
		expect.equal(RevealRules.standsOut("Unknown", "Very Rare"), false, "nothing unknown")
		local best = CardReveal.BEST
		expect.equal(best.from, "Very Rare", "the owner's line: Very Rare and up")
		assert(best.dim > 0.3 and best.dim < 0.8, "the rest dims, still readable")
		assert(best.halo > 1 and best.spinSeconds > 0 and best.shineEvery > 1, "a halo bigger than the card, a turning rim, a shine now and then")
	end,

	-- Owner 2026-11-18, pick C: "Pulling a Legendary should play an epic legendary cinematic" (Open 1 and Open 10)
	["only a Legendary tears the sky, foil or not, wherever it's revealed"] = function()
		local sky = CardReveal.SKY_TEAR
		expect.equal(RevealRules.tearsSky("Legendary", sky), true)
		for _, rarity in { "Common", "Rare", "Very Rare", "Epic" } do
			expect.equal(RevealRules.tearsSky(rarity, sky), false, rarity)
		end
	end,

	["the sky tear's beats: the card lands before its creature dives back in; Open 10's is about 3 s"] = function()
		local sky, alive = CardReveal.SKY_TEAR, CardReveal.CREATURE
		assert(CardReveal.BY_RARITY.Legendary.tease >= 1.5, "a tease long enough for the sky to crack open")
		assert(sky.cardDelay + sky.cardSeconds < sky.creatureSeconds + alive.holdSeconds, "the card in place while its creature is still out")
		assert(sky.spins >= 2, "the card spins down, not just falls")
		local bulk = sky.bulk
		local total = bulk.open + bulk.burst + bulk.hold + bulk.card + bulk.fade
		assert(total >= 2.5 and total <= 3.5, `Open 10's sky tear is about 3 s (was {total})`)
		assert(sky.rumble[2] > sky.rumble[1], "the rumble grows as the sky cracks")
	end,
}
