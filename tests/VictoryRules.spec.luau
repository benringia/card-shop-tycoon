--!strict
local VictoryRules = require("../src/shared/Util/VictoryRules")
local Items = require("../src/shared/Config/Items")
local expect = require("./lib/expect")

local function find(tiles: { VictoryRules.Tile }, label: string): VictoryRules.Tile?
	for _, tile in tiles do
		if tile.label == label then
			return tile
		end
	end
	return nil
end

return {
	["a win shows cash and XP first"] = function()
		local tiles = VictoryRules.tiles({ cash = 12.5, xpEach = 40 }, Items, {})
		expect.equal(#tiles, 2)
		expect.equal(tiles[1].icon, "Cash")
		expect.equal(tiles[1].amount, "$12.50")
		expect.equal(tiles[2].icon, "Xp")
		expect.equal(tiles[2].amount, "+40")
		expect.equal(tiles[2].label, "XP each")
	end,

	["shards, a dropped card and boss items each get a tile"] = function()
		local summary = {
			cash = 100,
			xpEach = 10,
			shards = 2,
			card = { cardId = "c1", grade = "A" },
			boss = { firstClear = true, chest = { { item = "goldSeal", count = 1 } }, items = { { item = "starShard", count = 3 } }, bonus = true },
		}
		local tiles = VictoryRules.tiles(summary, Items, { c1 = { name = "Ashbeak", set = "Base" } })
		local shard = find(tiles, "Star Shards")
		assert(shard, "shards")
		expect.equal(shard.amount, "x2")
		local card = find(tiles, "Ashbeak")
		assert(card, "the card")
		expect.equal(card.rare, true, "a new card glows")
		expect.equal(card.amount, "Grade A")
		local seal = find(tiles, Items.ITEMS.goldSeal.name)
		assert(seal, "the chest's item")
		expect.equal(seal.rare, true, "a first-clear chest item glows")
		local loot = find(tiles, Items.ITEMS.starShard.name)
		assert(loot, "the ground loot")
		expect.equal(loot.amount, "x3")
		expect.equal(loot.rare, false)
		assert(find(tiles, "Daily bonus"), "the daily bonus")
	end,

	["unknown items and cards are left out, never a broken tile"] = function()
		local tiles = VictoryRules.tiles({ cash = 1, xpEach = 1, card = { cardId = "nope" }, boss = { items = { { item = "nope", count = 1 } } } }, Items, {})
		expect.equal(#tiles, 2)
	end,

	["boss notes say where the loot is and why it's smaller"] = function()
		local notes = VictoryRules.notes({ items = { { item = "starShard", count = 1 } }, carried = true, lootIn = 90 })
		expect.equal(#notes, 3)
		expect.equal(string.find(notes[1], "ground", 1, true) ~= nil, true)
		expect.equal(#VictoryRules.notes(nil), 0)
		expect.equal(#VictoryRules.notes({ flagged = true, reduced = true }), 1, "flagged wins over reduced")
	end,
	["the subtitle names the foe and the time"] = function()
		expect.equal(VictoryRules.subtitle("Meadow Warden", 84), "Meadow Warden defeated · 1:24")
		expect.equal(VictoryRules.subtitle(nil, nil), "Fight won")
	end,
	["a normal monster's win is a toast: who fell, cash and XP"] = function()
		local toast = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 12.4, xpEach = 38 }, {})
		expect.equal(toast.kind, "win")
		expect.equal(toast.title, "Mossling defeated")
		expect.equal(#toast.pills, 2)
		expect.equal(toast.pills[1].icon, "Cash")
		expect.equal(toast.pills[1].text, "+$12.40")
		expect.equal(toast.pills[2].icon, "Xp")
		expect.equal(toast.pills[2].text, "+38 XP")
		expect.equal(toast.line, nil)
	end,

	["a card drop or shards add a gold line"] = function()
		local toast = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 1, xpEach = 1, card = { cardId = "c1", grade = "B" }, shards = 1 }, { c1 = { name = "Petalpaw" } })
		expect.equal(toast.kind, "rare")
		expect.equal(toast.line, "New card! Petalpaw · Grade B · +1 Star Shard")
	end,

	["losing or running away are toasts too"] = function()
		local lose = VictoryRules.toast({ result = "lose" }, {}, "resting 5:00")
		expect.equal(lose.kind, "lose")
		expect.equal(lose.title, "Your party fainted")
		expect.equal(lose.line, "resting 5:00")
		local run = VictoryRules.toast({ result = "run" }, {})
		expect.equal(run.kind, "run")
		expect.equal(run.title, "Got away safely")
	end,
}
