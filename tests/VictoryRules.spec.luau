--!strict
local VictoryRules = require("../src/shared/Util/VictoryRules")
local Items = require("../src/shared/Config/Items")
local Victory = require("../src/shared/Config/Victory")
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
		-- The owner 2026-11-19: no "too fast" rule, no daily limit, so no note says a win was smaller
		expect.equal(#VictoryRules.notes({ flagged = true, reduced = true }), 0, "no smaller-loot notes")
		-- A win before the loot timer ends pays a quarter of the cash (BossRules.pay): it says so, with when it's full again
		local small = VictoryRules.notes({ fullPay = false, payShare = 0.25, lootIn = 200 })
		expect.equal(#small, 1)
		expect.equal(small[1], "Loot timer running: 25% cash. Full loot and cash in 3:20")
		local full = VictoryRules.notes({ fullPay = true, lootIn = 420 })
		expect.equal(full[1], "Full loot and cash again in 7:00")
	end,
	-- Boss Rush (Config/Events): a loot win during it says why the wait is shorter; a win between loot doesn't
	["a loot win during an event says what the event did"] = function()
		local rush = VictoryRules.notes({ fullPay = true, lootIn = 210, event = "Boss Rush: loot twice as fast today" })
		expect.equal(#rush, 2)
		expect.equal(rush[1], "Full loot and cash again in 3:30")
		expect.equal(rush[2], "Boss Rush: loot twice as fast today")
		expect.equal(#VictoryRules.notes({ fullPay = false, payShare = 0.25, lootIn = 100, event = "x" }), 1, "no loot, no event note")
		expect.equal(#VictoryRules.notes({ fullPay = true, lootIn = 420, event = 5 }), 1, "junk ignored")
	end,
	["the subtitle names the foe and the time"] = function()
		expect.equal(VictoryRules.subtitle("Meadow Warden", 84), "Meadow Warden defeated · 1:24")
		expect.equal(VictoryRules.subtitle(nil, nil), "Fight won")
	end,
	-- Teams (spec 2026-11-15-teams-design): teammates near you add their bonus to your own win, shown as a third pill
	["a win with teammates near shows the team bonus"] = function()
		local toast = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 16.12, xpEach = 49, team = 0.3 }, {})
		expect.equal(#toast.pills, 3)
		expect.equal(toast.pills[3].icon, "Party")
		expect.equal(toast.pills[3].text, "+30% team")
		local alone = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 12.4, xpEach = 38 }, {})
		expect.equal(#alone.pills, 2, "no team, no pill")
	end,
	-- Owner 2026-11-17: a small shop XP from killing monsters; the toast says how much (after the creatures' XP)
	["a win's shop XP shows on the toast and the boss screen"] = function()
		local toast = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 4, xpEach = 38, shopXp = 2 }, {})
		expect.equal(#toast.pills, 3)
		expect.equal(toast.pills[3].icon, "Level")
		expect.equal(toast.pills[3].text, "+2 shop XP")
		local team = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 4, xpEach = 38, shopXp = 2, team = 0.15 }, {})
		expect.equal(team.pills[4].icon, "Party", "the team bonus stays last")
		local tiles = VictoryRules.tiles({ cash = 36, xpEach = 40, shopXp = 18 }, Items, {})
		expect.equal(#tiles, 3)
		expect.equal(tiles[3].icon, "Level")
		expect.equal(tiles[3].amount, "+18")
		expect.equal(tiles[3].label, "shop XP")
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

	["Wild Ore joins the line but isn't a gold one by itself (it's common)"] = function()
		local plain = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 1, xpEach = 1, ore = 1 }, {})
		expect.equal(plain.kind, "win")
		expect.equal(plain.line, "+1 Wild Ore")
		local rare = VictoryRules.toast({ result = "win", foe = "Mossling", cash = 1, xpEach = 1, shards = 1, ore = 1 }, {})
		expect.equal(rare.kind, "rare")
		expect.equal(rare.line, "+1 Star Shard · +1 Wild Ore")
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

	-- The owner 2026-11-10: "after defeating a boss change the victory sound effects to something rewarding/satisfying":
	-- three licensed stings to pick from by ear (Studio: /victorysound <1-3>), the first the default
	["a boss win plays a rewarding sting, one of three to pick from"] = function()
		local options = Victory.WIN_OPTIONS
		expect.equal(#options, 3)
		for index, option in options do
			assert(string.match(option.id, "^rbxassetid://%d+$"), `option {index}'s id`)
			assert(#option.name > 0, `option {index}'s name`)
			assert(option.startAt >= 0 and option.startAt < 2, `option {index}'s start`)
		end
		expect.equal(Victory.SOUNDS.win, options[1].id, "the first is the default")
		expect.equal(Victory.START_AT.win, options[1].startAt)
		assert(Victory.SOUNDS.win ~= "rbxassetid://1844539433", "not the old orchestral hits")
	end,
	-- Seen 2026-11-27: the win toast lay on Chikin's "Monsters give your shop a little XP too." at the top. It slides in
	-- under the talk card (and Skip hanging off it) when they'd meet, else where it always slides in
	["a monster win's toast slides in under the tutorial's card, never on it"] = function()
		local gap = Victory.TOAST.belowTalk
		assert(typeof(gap) == "number" and gap >= 6 and gap <= 24, "a small gap under the card")
		local toast = { x = 300, y = 64, w = 400, h = 60 }
		expect.equal(VictoryRules.toastTop(toast, {}, gap), 64, "no tutorial: where it always slides in")
		local card = { x = 230, y = 8, w = 540, h = 100 }
		expect.equal(VictoryRules.toastTop(toast, { card }, gap), 108 + gap, "under the card")
		local skip = { x = 640, y = 102, w = 68, h = 24 }
		expect.equal(VictoryRules.toastTop(toast, { card, skip }, gap), 126 + gap, "under Skip hanging off it too")
		expect.equal(VictoryRules.toastTop(toast, { skip, card }, gap), 126 + gap, "whatever order they come in")
		local low = { x = 230, y = 500, w = 540, h = 100 }
		expect.equal(VictoryRules.toastTop(toast, { low }, gap), 64, "a card down above the HUD leaves the top alone")
		local aside = { x = 20, y = 8, w = 200, h = 100 }
		expect.equal(VictoryRules.toastTop(toast, { aside }, gap), 64, "beside it: no move")
		local touching = { x = 230, y = 8, w = 540, h = 56 }
		expect.equal(VictoryRules.toastTop(toast, { touching }, gap), 64, "a card ending where it starts: no move")
		local unmeasured = { x = 500, y = 64, w = 0, h = 0 }
		expect.equal(VictoryRules.toastTop(unmeasured, { card }, gap), 108 + gap, "not laid out yet (0 x 0): still clear")
	end,
	-- Owner 2026-11-21 (launch day), on a monster win's banner: "make this bigger and make it last longer"
	["a monster win's banner is big and stays long enough to read"] = function()
		local Victory = require("../src/shared/Config/Victory")
		local toast = Victory.TOAST
		assert(toast.seconds >= 4 and toast.seconds <= 6, "long enough to read three pills, gone before the next fight ends")
		assert(toast.scale >= 1.25 and toast.scale <= 1.6, "bigger on a desktop")
		assert(toast.touchScale >= 1 and toast.touchScale < toast.scale, "a phone's a little bigger too, within its width")
	end,
}
