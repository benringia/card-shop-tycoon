--!strict
-- Shop variety (spec 2026-11-24-shop-variety-design): "Found it all!" (a plain customer who finds every product on a
-- list of two or more pays 10% more), its toast, and the word a customer uses for the product they missed
local VarietyRules = require("../src/shared/Util/VarietyRules")
local Customers = require("../src/shared/Config/Customers")
local Offline = require("../src/shared/Config/Offline")
local expect = require("./lib/expect")

return {
	["found it all: a plain customer with every product bought"] = function()
		local cfg = Customers
		expect.equal(cfg.FOUND_ALL.share, 0.10)
		expect.equal(cfg.FOUND_ALL.minProducts, 2)
		local list = { "FirstSparkPack", "CardSleeves" }
		local both = { FirstSparkPack = true, CardSleeves = true }
		expect.equal(VarietyRules.foundAll(cfg, "plain", list, both), true)
		expect.equal(VarietyRules.foundAll(cfg, "plain", list, { FirstSparkPack = true }), false, "sleeves missed")
		expect.equal(VarietyRules.foundAll(cfg, "plain", { "FirstSparkPack" }, { FirstSparkPack = true }), false, "one product: no variety to find")
		expect.equal(VarietyRules.foundAll(cfg, "plain", { "FirstSparkPack", "FirstSparkPack" }, { FirstSparkPack = true }), false, "the same product twice is one product")
		expect.equal(VarietyRules.foundAll(cfg, "plain", { "FirstSparkPack", "CardSleeves", "FirstSparkPack" }, both), true, "a product listed twice counts once")
		for _, kind in { "kid", "bargain", "bigSpender", "collector" } do
			expect.equal(VarietyRules.foundAll(cfg, kind, list, both), false, `{kind}: never`)
		end
		expect.equal(VarietyRules.foundAll(cfg, "plain", {}, {}), false, "an empty list")
	end,

	["found it all bonus is 10% to the cent"] = function()
		expect.equal(VarietyRules.bonus(Customers, 42), 4.2)
		expect.equal(VarietyRules.bonus(Customers, 3.33), 0.33)
		expect.equal(VarietyRules.bonus(Customers, 0), 0)
		expect.equal(VarietyRules.bonus(Customers, -5), 0, "never negative")
		expect.equal(VarietyRules.toast(Customers, 4.2), "Found it all! +$4.20")
	end,

	["the missing product's word"] = function()
		expect.equal(VarietyRules.word(Offline.PLURALS, "CardSleeves"), "sleeves")
		expect.equal(VarietyRules.word(Offline.PLURALS, "DeckBox"), "deck boxes")
		expect.equal(VarietyRules.word(Offline.PLURALS, "Unknown"), "things")
	end,
}
