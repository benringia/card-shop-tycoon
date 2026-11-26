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

	-- owner 2026-11-26: "Bulkbin: Currently with one click all your commons are gone. make the player use it display a
	-- window. so that they will know what they putting on it", pick B: the window lists the extras and a tap keeps a
	-- card out
	["extras: a card kept out gives nothing"] = function()
		local stacks = {
			c1 = { C = { normal = 10, foil = 0 } },
			c2 = { C = { normal = 6, foil = 0 } },
		}
		local takes, total = BulkRules.extras(stacks, rarityOf, Bulk, { c1 = true })
		expect.equal(count(takes, "c1", "C"), 0, "c1 is kept out")
		expect.equal(count(takes, "c2", "C"), 4, "c2's extras still go")
		expect.equal(total, 4)
		local _, all = BulkRules.extras(stacks, rarityOf, Bulk)
		expect.equal(all, 12, "nothing kept out: both cards' extras")
	end,

	["the window's tiles: each card's extras added up, the most first"] = function()
		local takes = {
			{ cardId = "c2", grade = "C", count = 3 },
			{ cardId = "c1", grade = "C", count = 2 },
			{ cardId = "c3", grade = "C", count = 3 },
			{ cardId = "c1", grade = "B", count = 2 },
		}
		local tiles = BulkRules.byCard(takes)
		expect.equal(#tiles, 3)
		expect.equal(tiles[1].cardId, "c1", "c1's 2 C and 2 B: 4, the most")
		expect.equal(tiles[1].count, 4)
		expect.equal(tiles[2].cardId, "c2", "a tie goes by card id")
		expect.equal(tiles[3].cardId, "c3")
		expect.equal(#BulkRules.byCard({}), 0)
	end,

	-- what the client sends: the card ids it keeps out. Anything else is refused, never trusted
	["the cards kept out, read from the client"] = function()
		local function isCard(id: string): boolean
			return RARITY[id] ~= nil
		end
		local set = BulkRules.readKeepOut({ "c1", "c2" }, isCard, 10)
		assert(set, "a list of card ids")
		expect.equal(set.c1, true)
		expect.equal(set.c2, true)
		expect.isNil(set.r9)
		local empty = BulkRules.readKeepOut(nil, isCard, 10)
		assert(empty and next(empty) == nil, "none kept out")
		local unknown = BulkRules.readKeepOut({ "nope" }, isCard, 10)
		assert(unknown and next(unknown) == nil, "an unknown id keeps nothing out")
		expect.isNil(BulkRules.readKeepOut("c1", isCard, 10), "not a list")
		expect.isNil(BulkRules.readKeepOut({ "c1", 5 }, isCard, 10), "a number in it")
		expect.isNil(BulkRules.readKeepOut({ c1 = true }, isCard, 10), "not a list: named keys")
		expect.isNil(BulkRules.readKeepOut({ "c1", "c1", "c1" }, isCard, 2), "too long")
	end,

	["the window's words: what goes in, what stays, and the button"] = function()
		local function words(extras: number, kept: number, room: number): BulkRules.Words
			return BulkRules.words({ extras = extras, kept = kept, room = room, per = Bulk.PER, keep = Bulk.KEEP })
		end
		local view = words(25, 2, 100)
		expect.equal(view.title, "25 cards = 5 handfuls")
		expect.equal(view.line, "2 kept out · customers buy them 5 at a time")
		expect.equal(view.button, "Put 25 in")
		expect.equal(view.ready, true)
		expect.equal(view.cards, 25)
		expect.equal(view.handfuls, 5)
		view = words(27, 0, 100)
		expect.equal(view.title, "25 cards = 5 handfuls", "whole handfuls only")
		expect.equal(view.line, "2 stay in your binder · customers buy them 5 at a time")
		view = words(5, 1, 100)
		expect.equal(view.title, "5 cards = 1 handful")
		view = words(30, 0, 2)
		expect.equal(view.title, "10 cards = 2 handfuls", "the bin's room caps it")
		expect.equal(view.line, "20 stay in your binder · customers buy them 5 at a time")
		view = words(3, 0, 100)
		expect.equal(view.title, "Not enough for a handful yet")
		expect.equal(view.ready, false)
		expect.equal(view.button, "Nothing to put in")
		view = words(0, 0, 100)
		expect.equal(view.title, "No extra Commons yet")
		expect.equal(view.ready, false)
		view = words(0, 3, 100)
		expect.equal(view.title, "Every card is kept out")
		expect.equal(view.ready, false)
		view = words(25, 0, 0)
		expect.equal(view.title, "This bin is full")
		expect.equal(view.button, "Bin full")
		expect.equal(view.ready, false)
		for _, case in { words(25, 2, 100), words(27, 0, 100), words(3, 0, 100), words(0, 0, 100), words(0, 3, 100), words(25, 0, 0) } do
			for _, text in { case.title, case.line, case.button } do
				assert(#text <= 80 and not string.find(text, "[^\32-\126\194\183]"), `short and plain: {text}`)
			end
		end
	end,
}
