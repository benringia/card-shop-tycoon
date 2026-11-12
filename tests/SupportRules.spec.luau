--!strict
-- "Support the dev" (owner 2026-11-12: "a 'Support the dev' somewhere where the supporter will receive a supporters
-- aura and title"; picks: Pish asks, golden sparkles, the town dogs thank you; three amounts): the saved gifts, the
-- best tier, which product is which tier and when Pish asks (Util/SupportRules, Config/Support)
local SupportRules = require("../src/shared/Util/SupportRules")
local Support = require("../src/shared/Config/Support")
local Monetization = require("../src/shared/Config/Monetization")
local Titles = require("../src/shared/Config/Titles")
local expect = require("./lib/expect")

local function asking(over: any): any
	local base = { asked = false, best = 0, touring = false, ready = true }
	for key, value in over do
		base[key] = value
	end
	return base
end

return {
	["three tiers, each a product with an id, a title and a growing aura"] = function()
		expect.equal(#Support.TIERS, 3)
		for index, tier in Support.TIERS do
			expect.equal(typeof(Monetization.PRODUCTS[tier.product]) == "number" and Monetization.PRODUCTS[tier.product] > 0, true, `{tier.name}: a product id`)
			expect.equal(SupportRules.tierOf(Support, tier.product), index)
			expect.equal(#tier.name > 0 and #tier.perk > 0 and #tier.icon > 0, true, `{tier.name}: its words`)
			local aura = Support.AURA[index]
			assert(aura, `{tier.name}: an aura`)
			if index > 1 then
				expect.equal(aura.rate > Support.AURA[index - 1].rate, true, `{tier.name}: more sparkles than the tier below`)
			end
		end
		expect.equal(SupportRules.tierOf(Support, "SkipS"), nil, "not a support product")
		for _, tier in Support.TIERS do
			expect.equal(Titles.ById[tier.title].name, tier.name, `{tier.name}: the gift is called what its title says`)
		end
	end,

	["a gift counts and keeps the best tier (a smaller gift later never lowers it)"] = function()
		local state = SupportRules.read(nil)
		expect.equal(state.gifts == 0 and state.best == 0, true, "nobody yet")
		state = SupportRules.give(state, 2, 3)
		expect.equal(state.gifts == 1 and state.best == 2, true)
		state = SupportRules.give(state, 1, 3)
		expect.equal(state.gifts == 2 and state.best == 2, true, "a smaller gift keeps Super Supporter")
		state = SupportRules.give(state, 9, 3)
		expect.equal(state.best, 3, "never past the top tier")
	end,

	["a saved record read back: junk becomes nothing, numbers kept in range"] = function()
		local kept = SupportRules.read({ gifts = 4, best = 2 }, 3)
		expect.equal(kept.gifts == 4 and kept.best == 2, true)
		local junk = SupportRules.read({ gifts = "x", best = 7 }, 3)
		expect.equal(junk.gifts == 0 and junk.best == 3, true, "a best past the top: the top")
		local negative = SupportRules.read({ gifts = -2, best = -1 }, 3)
		expect.equal(negative.gifts == 0 and negative.best == 0, true)
	end,

	-- owner 2026-11-12: "when a player donates, play a cinematic that both dogs running towards the player, then saying
	-- something like 'thank you, for your support, this is for you' and then a glow slowly coming out the players body"
	["the thank-you: dogs run in, talk, then the glow; the aura appears as the glow ends"] = function()
		local c = Support.CINEMATIC
		expect.equal(c.at.talkPish < c.at.talkChikin and c.at.talkChikin < c.at.glow and c.at.glow < c.at.leave and c.at.leave < c.at.done, true, "in order")
		expect.equal(math.abs(c.at.glow + c.glow.seconds - c.reveal) < 0.01, true, "the server's aura lands as the glow finishes")
		expect.equal(c.run.stop < c.run.from and c.run.minRun <= c.run.from, true)
		expect.equal(#string.format(c.lines.pish, "AVeryLongName20Chars") <= 52 and #c.lines.chikin <= 30, true, "short lines")
	end,

	["the dogs only come when nothing else holds the screen; otherwise just the glow"] = function()
		expect.equal(SupportRules.thanksMode({ fighting = false, touring = false, busy = false }), "full")
		expect.equal(SupportRules.thanksMode({ fighting = true, touring = false, busy = false }), "glow", "mid-fight")
		expect.equal(SupportRules.thanksMode({ fighting = false, touring = true, busy = false }), "glow", "a tour leads")
		expect.equal(SupportRules.thanksMode({ fighting = false, touring = false, busy = true }), "glow", "another cinematic or screen")
	end,

	["Pish asks once a session, never a supporter, never during a tour or before the first visit is done"] = function()
		expect.equal(SupportRules.nudge(asking({})), true, "a good moment: he asks")
		expect.equal(SupportRules.nudge(asking({ asked = true })), false, "once a session")
		expect.equal(SupportRules.nudge(asking({ best = 1 })), false, "they already gave")
		expect.equal(SupportRules.nudge(asking({ touring = true })), false, "not over a tour")
		expect.equal(SupportRules.nudge(asking({ ready = false })), false, "not before Pish's first visit is done")
		expect.equal(#Support.NUDGE.text <= 60, true, "a short bubble")
	end,
}
