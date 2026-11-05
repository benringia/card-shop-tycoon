--!strict
-- Collectors (spec 2026-11-06-customers-design): each wants one card, half the time one you own, and pays up to a
-- premium over what it's worth
local CollectorRules = require("../src/shared/Util/CollectorRules")
local Customers = require("../src/shared/Config/Customers")
local expect = require("./lib/expect")

local ALL = {
	{ id = "c1", rarity = "Common" },
	{ id = "c2", rarity = "Common" },
	{ id = "r1", rarity = "Rare" },
	{ id = "v1", rarity = "Very Rare" },
	{ id = "e1", rarity = "Epic" },
	{ id = "l1", rarity = "Legendary" },
}

local function isIn(id: string, list: { string }): boolean
	return table.find(list, id) ~= nil
end

return {
	["a collector wants a card you own half the time"] = function()
		local owned = { "e1", "l1" }
		assert(isIn(CollectorRules.wanted(Customers, owned, ALL, 0.2, 0.3), owned), "rollShare 0.2: an owned card")
		assert(isIn(CollectorRules.wanted(Customers, owned, ALL, 0.2, 0.9), owned), "any pick roll stays in owned")
		local fromAll = CollectorRules.wanted(Customers, owned, ALL, 0.8, 0.0)
		expect.equal(fromAll, "c1", "rollShare 0.8: from every card (pick 0: the first)")
		expect.equal(CollectorRules.wanted(Customers, {}, ALL, 0.2, 0.0), "c1", "nothing owned: from every card")
	end,

	["rarer cards are wanted less often"] = function()
		local counts: { [string]: number } = {}
		local rarityOf: { [string]: string } = {}
		for _, card in ALL do
			rarityOf[card.id] = card.rarity
		end
		for step = 0, 999 do
			local id = CollectorRules.wanted(Customers, {}, ALL, 0.9, step / 1000)
			local rarity = rarityOf[id]
			counts[rarity] = (counts[rarity] or 0) + 1
		end
		assert((counts.Legendary or 0) < (counts.Common or 0), "Legendary less often than Common")
		assert((counts.Legendary or 0) > 0, "Legendary still wanted sometimes")
		-- per card: two Commons share the Common weight, so compare one Common card against the one Legendary
		assert((counts.Legendary or 0) < (counts.Common or 0) / 2, "one Legendary card less than one Common card")
	end,

	-- Between finding the card and reaching the showcase the owner may move it, swap it or reprice it
	["collector rechecks"] = function()
		expect.equal(CollectorRules.stillThere({ cardId = "e1", price = 120 }, "e1", 100, Customers), true)
		expect.equal(CollectorRules.stillThere(nil, "e1", 100, Customers), false, "the slot emptied")
		expect.equal(CollectorRules.stillThere({ cardId = "c1", price = 1 }, "e1", 100, Customers), false, "another card")
		expect.equal(CollectorRules.stillThere({ cardId = "e1", price = 140 }, "e1", 100, Customers), false, "now over the premium")
	end,

	["pays up to 1.3x what it's worth"] = function()
		expect.equal(Customers.COLLECTOR.premium, 1.3)
		expect.equal(CollectorRules.buys(Customers, 129, 100), true)
		expect.equal(CollectorRules.buys(Customers, 130, 100), true, "exactly the premium")
		expect.equal(CollectorRules.buys(Customers, 131, 100), false)
		expect.equal(CollectorRules.buys(Customers, 1, 0), false, "a worthless card: no sale")
	end,
}
