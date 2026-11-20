--!strict
-- The Deck Box is worth its price (owner 2026-11-20: "whats the point of deck box? its just an expensive version of
-- the booster pack? if not fix it"): it costs three packs, so opening one must beat opening three packs where it
-- counts. Every Deck Box has a Very Rare or better, and its chance of an Epic and of a Legendary is at least three
-- packs' chance; three packs still give three times the cards (Commons for the Condenser).
local PackOdds = require("../src/shared/Config/PackOdds")
local Products = require("../src/shared/Config/Products")
local Items = require("../src/shared/Config/Items")
local expect = require("./lib/expect")

local RANK = PackOdds.RANK

local function hit(id: string): { PackOdds.Weighted }
	local slots = PackOdds.SLOTS[id]
	return slots[#slots]
end

-- The chance a slot rolls `rarity` or better
local function atLeast(slot: { PackOdds.Weighted }, rarity: string): number
	local total, good = 0, 0
	for _, entry in slot do
		total += entry.weight
		if RANK[entry.rarity] >= RANK[rarity] then
			good += entry.weight
		end
	end
	return good / total
end

local function unitCost(id: string): number
	local product = Products.ById[id]
	return product.boxCost / product.unitsPerBox
end

return {
	["a Deck Box costs as much as three packs, to stock and to buy"] = function()
		expect.equal(unitCost("DeckBox") / unitCost("FirstSparkPack"), 3)
		expect.equal(Products.ById.DeckBox.marketPrice / Products.ById.FirstSparkPack.marketPrice, 3)
	end,

	["every Deck Box has a Very Rare or better"] = function()
		expect.equal(atLeast(hit("DeckBox"), "Very Rare"), 1)
		assert(atLeast(hit("FirstSparkPack"), "Very Rare") < 0.5, "a pack's hit is mostly a Rare")
	end,

	["opening one beats opening three packs for an Epic and for a Legendary"] = function()
		local packs = unitCost("DeckBox") / unitCost("FirstSparkPack")
		for _, rarity in { "Epic", "Legendary" } do
			local threePacks = 1 - (1 - atLeast(hit("FirstSparkPack"), rarity)) ^ packs
			local deck = atLeast(hit("DeckBox"), rarity)
			assert(deck >= threePacks, `{rarity}: {deck} against three packs' {threePacks}`)
			assert(deck <= threePacks * 1.25, `{rarity}: not a way round the packs' odds ({deck} against {threePacks})`)
		end
	end,

	["its slots add up, five cards, two of them Rare or better"] = function()
		local slots = PackOdds.SLOTS.DeckBox
		expect.equal(#slots, 5)
		local sure = 0
		for _, slot in slots do
			local total = 0
			for _, entry in slot do
				total += entry.weight
			end
			assert(math.abs(total - 1) < 1e-9, "weights add up to 1")
			if atLeast(slot, "Rare") == 1 then
				sure += 1
			end
		end
		expect.equal(sure, 2)
	end,

	["its Bag item says what it is for"] = function()
		local words = Items.ITEMS.deckBox.description
		assert(string.find(words, "Very Rare or better", 1, true), words)
		assert(#words <= 90, "short")
	end,
}
