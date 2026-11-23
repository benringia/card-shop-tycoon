--!strict
-- The Edit bar (owner 2026-11-23, mockup C "Action bar": the shop's Edit window's plain list replaced by the object
-- lit up and its own candy tiles at the bottom centre; "change RECYCLE to USE"): what each placed thing offers
local EditBarRules = require("../src/shared/Util/EditBarRules")
local expect = require("./lib/expect")

local function ids(bar: EditBarRules.Bar): string
	local list = {}
	for _, tile in bar.tiles do
		table.insert(list, tile.id)
	end
	return table.concat(list, ",")
end

local function tile(bar: EditBarRules.Bar, id: string): EditBarRules.Tile
	for _, each in bar.tiles do
		if each.id == id then
			return each
		end
	end
	error(`no {id} tile in {ids(bar)}`)
end

local rack: EditBarRules.Thing = { kind = "Products", name = "Small Pack Rack", capacity = 24, units = 0, refund = 50 }
local EVERY: { EditBarRules.Thing } = {
	rack,
	{ kind = "Products", name = "Small Pack Rack", capacity = 24, units = 18, product = "First Spark Pack", refund = 50 },
	{ kind = "Bin", name = "Bulk Bin", capacity = 100, units = 12, refund = 150 },
	{ kind = "CustomerCards", name = "Glass Showcase", capacity = 6, cards = 0, refund = 125 },
	{ kind = "PlayerCards", name = "Collector Case", capacity = 6, cards = 2, refund = 150 },
	{ kind = "Condenser", name = "Card Condenser", refund = 250 },
	{ kind = "Grading", name = "Grading Station", refund = 2500, machine = { working = 28 } },
	{ kind = "Forge", name = "Forge", refund = 750, machine = { done = true } },
	{ kind = "Recycler", name = "Recycler", refund = 400 },
	{ kind = "Trophy", name = "Meadow Warden Trophy" },
	{ kind = "Decor", name = "Potted Plant", decor = 2, refund = 30 },
	{ kind = "Window", name = "Arched Window", refund = 120 },
	{ kind = "Poster", name = "Beware of Dog" },
}

return {
	["an empty rack: Remove rests, Move, and Sell held down for its refund"] = function()
		local bar = EditBarRules.bar(rack)
		expect.equal(bar.name, "Small Pack Rack")
		expect.equal(ids(bar), "unstock,move,sell", "its own use first, Move, then Sell")
		expect.equal(bar.chip.text, "Empty · 0 / 24")
		expect.equal(bar.chip.tone, "empty")
		expect.equal(tile(bar, "unstock").state, "off", "nothing to box up")
		assert(tile(bar, "unstock").why ~= nil, "a tap on a resting tile still says why")
		local sell = tile(bar, "sell")
		expect.equal(sell.state, "ready")
		expect.equal(sell.hold, true, "selling is held down")
		expect.equal(sell.sub, "+$50")
	end,

	["a stocked rack: Sell locked until the stock comes off, and says how"] = function()
		local bar = EditBarRules.bar({ kind = "Products", name = "Small Pack Rack", capacity = 24, units = 18, product = "First Spark Pack", refund = 50 })
		expect.equal(bar.chip.text, "18 / 24")
		expect.equal(bar.chip.tone, "full")
		expect.equal(tile(bar, "unstock").state, "ready")
		local sell = tile(bar, "sell")
		expect.equal(sell.state, "locked")
		assert(sell.why and string.find(sell.why, "stock", 1, true), "the lock names the stock")
		assert(string.find(bar.hint, "First Spark Pack", 1, true), "the hint names what's on it")
	end,

	["a case with cards: Cards first, Sell locked until the cards come out"] = function()
		local bar = EditBarRules.bar({ kind = "PlayerCards", name = "Collector Case", capacity = 6, cards = 2, refund = 150 })
		expect.equal(ids(bar), "cards,move,sell")
		expect.equal(bar.chip.text, "2 / 6 cards")
		expect.equal(tile(bar, "cards").state, "ready")
		local sell = tile(bar, "sell")
		expect.equal(sell.state, "locked")
		assert(sell.why and string.find(sell.why, "cards", 1, true), "the lock names the cards")
		expect.equal(EditBarRules.bar({ kind = "CustomerCards", name = "Glass Showcase", capacity = 6, cards = 0, refund = 125 }).chip.text, "Empty · 0 / 6")
	end,

	["a machine's own button says Use, the Recycler's too (owner: change RECYCLE to USE)"] = function()
		for _, kind in { "Condenser", "Grading", "Forge", "Recycler" } do
			local bar = EditBarRules.bar({ kind = kind :: any, name = kind, refund = 100 })
			expect.equal(ids(bar), "use,move,sell", kind)
			expect.equal(tile(bar, "use").label, "Use", kind)
			expect.equal(tile(bar, "sell").state, "ready", kind)
		end
	end,

	["a machine's chip: ready, working with its clock, or done and waiting"] = function()
		expect.equal(EditBarRules.bar({ kind = "Recycler", name = "Recycler", refund = 400 }).chip.tone, "good")
		local working = EditBarRules.bar({ kind = "Grading", name = "Grading Station", refund = 2500, machine = { working = 88 } })
		expect.equal(working.chip.text, "Working · 1:28")
		expect.equal(working.chip.tone, "busy")
		local done = EditBarRules.bar({ kind = "Forge", name = "Forge", refund = 750, machine = { done = true } })
		expect.equal(done.chip.tone, "ready")
		assert(string.find(done.chip.text, "Done", 1, true), "done and waiting")
	end,

	["a trophy goes back to the Bag and a poster comes down: free, so no hold"] = function()
		local trophy = EditBarRules.bar({ kind = "Trophy", name = "Meadow Warden Trophy" })
		expect.equal(ids(trophy), "move,bag")
		expect.equal(tile(trophy, "bag").hold, false)
		assert(string.find(trophy.hint, "Meadow Warden", 1, true), "the boss it came from")
		local poster = EditBarRules.bar({ kind = "Poster", name = "Beware of Dog" })
		expect.equal(ids(poster), "move,takeDown")
		expect.equal(tile(poster, "takeDown").hold, false)
	end,

	["every Sell for money is held down, and nothing else is"] = function()
		for _, thing in EVERY do
			for _, each in EditBarRules.bar(thing).tiles do
				expect.equal(each.hold, each.id == "sell", `{thing.name} {each.id}`)
			end
		end
	end,

	["every tile and chip in short, plain words: labels fit the tile, no arrows or odd symbols"] = function()
		for _, thing in EVERY do
			local bar = EditBarRules.bar(thing)
			for _, text in { bar.name, bar.chip.text, bar.hint } do
				assert(not string.find(text, "->", 1, true), `no arrows: {text}`)
			end
			for _, each in bar.tiles do
				assert(#each.label <= 9, `{thing.name}: "{each.label}" fits the tile`)
				assert(#each.sub > 0 and #each.sub <= 16, `{thing.name} {each.id}: "{each.sub}" is a short line`)
				if each.state ~= "ready" then
					assert(each.why and #each.why > 0, `{thing.name} {each.id}: a tap says why`)
				end
				for _, text in { each.label, each.sub, each.why or "" } do
					for _, code in utf8.codes(text) do
						assert(code < 128 or code == 0xB7, `{thing.name} {each.id}: plain text only in "{text}"`)
					end
				end
			end
		end
	end,

	["money reads like money: whole dollars short, thousands with a comma, cents kept"] = function()
		expect.equal(EditBarRules.money(50), "$50")
		expect.equal(EditBarRules.money(2500), "$2,500")
		expect.equal(EditBarRules.money(12.5), "$12.50")
		expect.equal(EditBarRules.money(1234567), "$1,234,567")
	end,

	["missing numbers count as nothing (a thing still loading)"] = function()
		local bar = EditBarRules.bar({ kind = "Products", name = "Wall Shelf" })
		expect.equal(bar.chip.text, "Empty · 0 / 0")
		expect.equal(tile(bar, "sell").sub, "+$0")
		expect.equal(tile(bar, "sell").state, "ready")
	end,
}
