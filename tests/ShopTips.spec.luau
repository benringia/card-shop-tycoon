--!strict
-- Owner 2026-11-17: "add tooltips to the items in shop to explain what Items they hold and what they do": every tile in
-- the Shop window says what it holds and what it does, in words a child understands
local ShopTips = require("../src/shared/Util/ShopTips")
local Offline = require("../src/shared/Config/Offline")
local expect = require("./lib/expect")

local STOCK = { "packs", "sleeves", "deck boxes", "booster boxes" }

local function shortAndPlain(lines: { string }, label: string)
	expect.equal(#lines, 2, `{label}: what it holds, what it does`)
	for _, line in lines do
		assert(#line > 0 and #line <= 90, `{label}: "{line}" is short`)
		assert(not string.find(line, "[{}]"), `{label}: no unfilled blank in "{line}"`)
	end
end

return {
	["a stock shelf: how many, of which stock, and that customers buy from it"] = function()
		local any = ShopTips.lines({ kind = "Products", capacity = 24 }, STOCK)
		expect.equal(any[1], "Holds 24 of your stock: packs, sleeves, deck boxes or booster boxes.", "any stock")
		assert(string.find(any[2], "Customers", 1, true), "who buys")
		local hook = ShopTips.lines({ kind = "Products", capacity = 20, accepts = { "sleeves", "deck boxes" } }, STOCK)
		expect.equal(hook[1], "Holds 20 of your stock: sleeves or deck boxes.", "only what it takes")
		shortAndPlain(any, "rack")
		shortAndPlain(hook, "hook")
	end,

	["the Bulk Bin: handfuls of extra Commons, filled from the binder"] = function()
		local bin = ShopTips.lines({ kind = "Products", capacity = 100, bulk = true }, STOCK)
		assert(string.find(bin[1], "100 handfuls of 5 extra Commons", 1, true), bin[1])
		assert(string.find(bin[2], "Add extras", 1, true), "how to fill it")
		shortAndPlain(bin, "bin")
	end,

	["every kind of shop item has words: cases, machines, decor, trophies"] = function()
		for _, kind in { "CustomerCards", "PlayerCards", "Condenser", "Grading", "Forge", "Decor", "Trophy" } do
			shortAndPlain(ShopTips.lines({ kind = kind, capacity = 6, decor = 2 }, STOCK), kind)
		end
		assert(string.find(ShopTips.lines({ kind = "Decor", capacity = 0, decor = 3 }, STOCK)[1], "+3", 1, true), "decor points")
		assert(string.find(ShopTips.lines({ kind = "PlayerCards", capacity = 6 }, STOCK)[2], "players", 1, true), "other players buy")
	end,

	["shop looks and windows too"] = function()
		shortAndPlain(ShopTips.look(), "look")
		local window = ShopTips.window(2)
		shortAndPlain(window, "window")
		assert(string.find(window[2], "+2", 1, true), "its decor points")
	end,

	["the stock words are the welcome-back card's (one word per product)"] = function()
		for _, id in { "FirstSparkPack", "CardSleeves", "DeckBox", "FirstSparkBox" } do
			assert(Offline.PLURALS[id], `{id} has its word`)
		end
	end,
}
