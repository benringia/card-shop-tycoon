--!strict
-- The Bulk Bin (owner 2026-11-17: "a really active player ... end up like 1000 common cards. we need a way to get rid
-- those right?", then "lets do C"): your extra Commons go in a bin, 5 to a handful, and customers buy the handfuls
local BulkRules = require("../src/shared/Util/BulkRules")
local Bulk = require("../src/shared/Config/Bulk")
local expect = require("./lib/expect")

local RARITY = { c1 = "Common", c2 = "Common", r1 = "Rare" }
local function rarityOf(id: string): string?
	return RARITY[id]
end

local function count(takes: { BulkRules.Take }, cardId: string, grade: string): number
	local total = 0
	for _, take in takes do
		if take.cardId == cardId and take.grade == grade then
			total += take.count
		end
	end
	return total
end

return {
	["extras: Commons past the 2 best you keep, never foils, never A or S"] = function()
		local stacks = {
			c1 = { S = { normal = 1, foil = 0 }, B = { normal = 3, foil = 1 }, C = { normal = 10, foil = 2 } },
			c2 = { A = { normal = 2, foil = 0 }, C = { normal = 1, foil = 0 } },
			r1 = { C = { normal = 30, foil = 0 } },
		}
		local takes, total = BulkRules.extras(stacks, rarityOf, Bulk)
		-- c1: keeps its S and one B; 2 B and 10 C go. c2: keeps both A; its 1 C goes. Rares stay.
		expect.equal(count(takes, "c1", "B"), 2, "c1's spare Bs")
		expect.equal(count(takes, "c1", "C"), 10, "c1's Cs")
		expect.equal(count(takes, "c2", "C"), 1, "c2's C (its two As are the kept ones)")
		expect.equal(count(takes, "c1", "S"), 0, "never an S")
		expect.equal(count(takes, "r1", "C"), 0, "not a Rare")
		expect.equal(total, 13, "13 extras")
		for _, take in takes do
			assert(take.count > 0, "no empty takes")
		end
	end,

	["extras: nothing to give with a few copies, or an empty binder"] = function()
		local _, total = BulkRules.extras({ c1 = { C = { normal = 2, foil = 5 } } }, rarityOf, Bulk)
		expect.equal(total, 0, "2 copies are the 2 you keep; foils never go")
		local _, none = BulkRules.extras({}, rarityOf, Bulk)
		expect.equal(none, 0, "an empty binder")
	end,

	["fill: whole handfuls that fit the bin's room"] = function()
		local handfuls, cards = BulkRules.fill(13, 100, 5)
		expect.equal(handfuls, 2, "13 extras make 2 handfuls")
		expect.equal(cards, 10, "10 cards go in, 3 stay")
		handfuls, cards = BulkRules.fill(1000, 40, 5)
		expect.equal(handfuls, 40, "the bin's room caps it")
		expect.equal(cards, 200, "200 cards")
		handfuls = BulkRules.fill(4, 100, 5)
		expect.equal(handfuls, 0, "less than a handful")
	end,

	["trim: exactly the cards going in, the plainest first"] = function()
		-- as extras gives them: the plainest grade first
		local takes = {
			{ cardId = "c1", grade = "C", count = 6 },
			{ cardId = "c2", grade = "C", count = 3 },
			{ cardId = "c1", grade = "B", count = 4 },
		}
		local chosen = BulkRules.trim(takes, 10)
		local sum = 0
		for _, take in chosen do
			sum += take.count
		end
		expect.equal(sum, 10, "10 cards")
		expect.equal(count(chosen, "c1", "C") + count(chosen, "c2", "C"), 9, "every C before a B")
		expect.equal(count(chosen, "c1", "B"), 1, "one B to make 10")
	end,

	["customers ask for a handful only while a bin has some"] = function()
		expect.equal(BulkRules.wants("kid", true, 0.1, Bulk.CHANCE), true, "a kid, a bin with stock")
		expect.equal(BulkRules.wants("kid", false, 0.0, Bulk.CHANCE), false, "no stocked bin: never")
		expect.equal(BulkRules.wants("collector", true, 0.0, Bulk.CHANCE), false, "collectors want single cards")
		expect.equal(BulkRules.wants("kid", true, 0.99, Bulk.CHANCE), false, "not every kid")
		expect.equal(Bulk.PER, 5, "5 to a handful, as the mockup's sign")
	end,
}
