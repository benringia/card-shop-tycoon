--!strict
-- Luck bought with Robux (owner 2026-11-14: "LUCK BOOSTER for ROBUX"; products 2x Luck 15 / 30 min and 3x Super Luck
-- 30 min made on Creator Hub): each purchase adds time to its strength, the strongest runs first and only it runs
-- down (while you play), Pish's Luck adds on top; the rarity guide shows the last card's odds with each.
local BoughtLuck = require("../src/shared/Util/BoughtLuck")
local LuckRules = require("../src/shared/Util/LuckRules")
local Luck = require("../src/shared/Config/Luck")
local Packs = require("../src/shared/Config/PackOdds")
local Monetization = require("../src/shared/Config/Monetization")
local expect = require("./lib/expect")

return {
	["every luck product is on Creator Hub and adds its strength's time"] = function()
		for key, product in Luck.PRODUCTS do
			assert(typeof(Monetization.PRODUCTS[key]) == "number" and Monetization.PRODUCTS[key] > 0, `{key} has its product id`)
			assert(Luck.STRENGTHS[product.strength], `{key}'s strength exists`)
		end
		expect.equal(Luck.PRODUCTS.Luck15.seconds, 15 * 60)
		expect.equal(Luck.PRODUCTS.Luck30.seconds, 30 * 60)
		expect.equal(Luck.PRODUCTS.SuperLuck30.strength, "x3")
		expect.equal(Luck.STRENGTHS.x2.boost, 1, "2x: the good rarities' weights doubled")
		expect.equal(Luck.STRENGTHS.x3.boost, 2, "3x: tripled")
	end,

	["buying adds time; the strongest runs first and only it runs down"] = function()
		local state = BoughtLuck.clean(nil, Luck)
		expect.isNil(BoughtLuck.active(state, Luck), "none at first")
		state = BoughtLuck.add(state, "x2", 900, Luck)
		state = BoughtLuck.add(state, "x2", 1800, Luck)
		expect.equal(state.x2, 2700, "a second buy adds on")
		expect.equal(BoughtLuck.active(state, Luck), "x2")
		state = BoughtLuck.add(state, "x3", 1800, Luck)
		expect.equal(BoughtLuck.active(state, Luck), "x3", "Super Luck goes first")
		state = BoughtLuck.tick(state, 600, Luck)
		expect.equal(state.x3, 1200)
		expect.equal(state.x2, 2700, "the 2x waits its turn")
		state = BoughtLuck.tick(state, 1500, Luck)
		expect.equal(state.x3, 0, "never below zero")
		expect.equal(BoughtLuck.active(state, Luck), "x2", "then the 2x runs")
		expect.equal(BoughtLuck.add(state, "x2", 999999, Luck).x2, Luck.MAX_SECONDS, "capped")
		expect.equal(BoughtLuck.add(state, "nope", 60, Luck).x2, state.x2, "an unknown strength changes nothing")
	end,

	["a saved luck is cleaned on load"] = function()
		local state = BoughtLuck.clean({ x2 = 61.7, x3 = -5, junk = 9 }, Luck)
		expect.equal(state.x2, 61)
		expect.equal(state.x3, 0)
		expect.isNil((state :: any).junk)
		expect.equal(BoughtLuck.clean("x", Luck).x2, 0)
		expect.equal(BoughtLuck.clean({ x3 = 1e9 }, Luck).x3, Luck.MAX_SECONDS)
	end,

	-- The premium Store (owner 2026-11-14 "make it feel like a WIN", option A): each boost's tile says its win in a chip,
	-- and a purchase plays a win card with its own title and line
	["the Store's odds chip says the Legendary chance before and after, in plain text"] = function()
		expect.equal(BoughtLuck.oddsText(0.01, 0.02), "Legendary 1% to 2%")
		expect.equal(BoughtLuck.oddsText(0.01, 0.03), "Legendary 1% to 3%")
		expect.equal(BoughtLuck.oddsText(0.005, 0.0125), "Legendary 0.5% to 1.3%", "small chances keep a decimal")
		assert(not string.find(BoughtLuck.oddsText(0.01, 0.02), "[^%w%s%%%.]"), "plain text the fonts draw (no arrow)")
	end,

	["every purchase has a win card: a big title and a line"] = function()
		for _, kind in { "x2", "x3", "jobslot" } do
			local win = Luck.WIN[kind]
			assert(win and win.title ~= "" and win.text ~= "", `{kind} has a win card`)
			assert(#win.title <= 14, `{kind}'s title is short and big`)
		end
		expect.equal(BoughtLuck.winText(Luck.WIN.x2.text, 1800), "30 minutes of luckier packs!")
		expect.equal(BoughtLuck.winText(Luck.WIN.jobslot.text, 0), Luck.WIN.jobslot.text, "no time in it")
		expect.equal(BoughtLuck.winText(Luck.WIN.x2.text, 60), "1 minute of luckier packs!", "one minute, not one minutes")
	end,

	["its boost adds to Pish's"] = function()
		expect.equal(BoughtLuck.boost(nil, Luck), 0)
		expect.equal(BoughtLuck.boost("x2", Luck), 1)
		expect.equal(BoughtLuck.boost("x3", Luck), 2)
	end,

	["the guide's numbers: the last card's chances with 2x and 3x luck"] = function()
		local slots = Packs.SLOTS.FirstSparkPack
		local hit = slots[#slots]
		local plain = LuckRules.chances(hit)
		expect.near(plain.Legendary, 0.01, 1e-9)
		local two = LuckRules.chances(LuckRules.boost(hit, Packs.RANK, Luck.FROM_RARITY, Luck.STRENGTHS.x2.boost))
		expect.near(two.Legendary, 0.02, 1e-9, "2x: Legendary 2%")
		expect.near(two.Epic, 0.28, 1e-9, "Epic 28%")
		local three = LuckRules.chances(LuckRules.boost(hit, Packs.RANK, Luck.FROM_RARITY, Luck.STRENGTHS.x3.boost))
		expect.near(three.Legendary, 0.03, 1e-9, "3x: Legendary 3%")
		local total = 0
		for _, chance in three do
			total += chance
		end
		expect.near(total, 1, 1e-9, "the chances add up to 1")
	end,
}
