--!strict
-- The Recycler (owner 2026-11-21: "we also neeed a way to get rid of thousands of other copies of other rarities. we
-- already have commons", then "can we have add a recycler. that can make extra cards turn into upgrade materials. make
-- sure the costs are fair", layout A of artifact UjbnCvUyswFQ7d1vQSrW7R): a shop machine that turns the binder's extra
-- Rares, Very Rares, Epics and Legendaries into upgrade materials. Its recipes, which copies are extras, and its
-- window's words (Config/Recycler, Util/RecycleRules)
local RecycleRules = require("../src/shared/Util/RecycleRules")
local Recycler = require("../src/shared/Config/Recycler")
local Beasts = require("../src/shared/Config/Beasts")
local Grading = require("../src/shared/Config/Grading")
local Items = require("../src/shared/Config/Items")
local Turts = require("../src/shared/Config/Turts")
local CardList = require("../src/shared/Config/CardList")
local PackOdds = require("../src/shared/Config/PackOdds")
local Products = require("../src/shared/Config/Products")
local expect = require("./lib/expect")

local function counts(normal: number, foil: number)
	return { normal = normal, foil = foil }
end

local RARITY = { R1 = "Rare", R2 = "Rare", V1 = "Very Rare", E1 = "Epic", L1 = "Legendary", C1 = "Common" }
local function rarityOf(cardId: string): string?
	return RARITY[cardId]
end

local function piles(stacks: any, beasts: any)
	return RecycleRules.piles(Recycler, Beasts, Grading, stacks, beasts or {}, rarityOf)
end

-- a set 1 rarity's average market value
local function worth(rarity: string): number
	local sum, n = 0, 0
	for _, row in CardList.SET1 do
		if row[3] == rarity then
			sum += row[4]
			n += 1
		end
	end
	assert(n > 0, `{rarity} cards were read`)
	return sum / n
end

return {
	["each rarity always makes the same material"] = function()
		expect.equal(table.concat(Recycler.ORDER, ","), "Rare,Very Rare,Epic,Legendary")
		expect.equal(Recycler.RECIPES.Rare.per, 80)
		expect.equal(Recycler.RECIPES.Rare.item, "wildOre")
		expect.equal(Recycler.RECIPES["Very Rare"].per, 60)
		expect.equal(Recycler.RECIPES["Very Rare"].item, "xpTonic")
		expect.equal(Recycler.RECIPES.Epic.per, 60)
		expect.equal(Recycler.RECIPES.Epic.item, "starShard")
		expect.equal(Recycler.RECIPES.Legendary.per, 1)
		expect.equal(Recycler.RECIPES.Legendary.item, "starShard")
		expect.isNil(Recycler.RECIPES.Common, "Commons stay with the Bulk Bin")
		for rarity, recipe in Recycler.RECIPES do
			assert(Items.ITEMS[recipe.item], `{rarity}: {recipe.item} is a Bag item`)
			assert(Recycler.ITEM_WORDS[recipe.item], `{recipe.item} has its words`)
			assert(Recycler.PLURALS[rarity], `{rarity} has its plural`)
			-- the grade chase keeps its price: seals come from bosses and gifts only
			assert(recipe.item ~= "gradingSeal" and recipe.item ~= "goldSeal", `{rarity}: never a seal`)
		end
	end,

	-- "make sure the costs are fair": a pile gives back about a tenth of what its cards are worth, counted at Turts'
	-- own value for the material (what it costs in farming time), so the machine clears clutter and never beats
	-- playing. A Legendary gives most of its worth: a spare one only exists once that card has every star and Grade S
	["the costs are fair: about a tenth of the cards' worth back, a Legendary most of it"] = function()
		for _, rarity in { "Rare", "Very Rare", "Epic" } do
			local recipe = Recycler.RECIPES[rarity]
			local back = Turts.OFFERS[recipe.item].value / (recipe.per * worth(rarity))
			assert(back >= 0.08 and back <= 0.2, `{rarity}: {math.floor(back * 100)}% back`)
		end
		local legendary = Turts.OFFERS.starShard.value / worth("Legendary")
		assert(legendary >= 0.5 and legendary <= 1, `Legendary: {math.floor(legendary * 100)}% back`)
	end,

	["a card keeps what it still needs: its missing stars and grades, and 2 spare"] = function()
		-- nothing done yet: 64 copies for five stars, 14 for Grade S, 2 spare
		expect.equal(RecycleRules.reserve(Recycler, Beasts, Grading, "Rare", 0, "C"), 64 + 14 + 2)
		-- every star and Grade S: only the spare ones
		expect.equal(RecycleRules.reserve(Recycler, Beasts, Grading, "Rare", 5, "S"), 2)
		-- an Epic with 3 stars at Grade A: 16 + 24 for the stars, 4 for Grade S
		expect.equal(RecycleRules.reserve(Recycler, Beasts, Grading, "Epic", 3, "A"), 40 + 4 + 2)
		expect.equal(RecycleRules.reserve(Recycler, Beasts, Grading, "Legendary", 0, "C"), 64 + 6 + 2)
	end,

	["the extras: plain Grade C and B copies past what the card keeps, never foils, never Grade A or S"] = function()
		local stacks = {
			R1 = { C = counts(300, 9), B = counts(50, 0), A = counts(3, 0) }, -- best grade A: keeps 64 + 8 + 2 = 74
			R2 = { C = counts(10, 0) }, -- keeps 80: nothing extra
			E1 = { C = counts(10, 2), S = counts(4, 0) },
			C1 = { C = counts(999, 0) },
			Z9 = { C = counts(500, 0) }, -- not a card
			L1 = { C = "junk", B = { normal = -4, foil = 0 / 0 } },
		}
		local beasts = { one = { cardId = "E1", stars = 5, grade = "S" } }
		local got = piles(stacks, beasts)
		-- R1 keeps its 3 A, its 50 B and 21 of its C: 279 Grade C go
		expect.equal(got.Rare.count, 279)
		expect.equal(#got.Rare.takes, 1)
		expect.equal(got.Rare.takes[1].cardId, "R1")
		expect.equal(got.Rare.takes[1].grade, "C")
		-- E1 is maxed (its best card has 5 stars and Grade S): it keeps 2, the Grade S copies first, so all 10 C go
		expect.equal(got.Epic.count, 10)
		expect.equal(got["Very Rare"].count, 0)
		expect.equal(got.Legendary.count, 0)
		expect.isNil(got.Common, "no pile for Commons")
		-- plainest first, then by card: Grade C before Grade B
		local mixed = piles({ R1 = { C = counts(100, 0), B = counts(100, 0) }, R2 = { C = counts(90, 0) } }, {})
		-- R1's best grade is B: it keeps 64 + 12 + 2 = 78, all of them Grade B; R2 keeps 80
		expect.equal(mixed.Rare.count, 100 + 22 + 10)
		expect.equal(mixed.Rare.takes[1].cardId, "R1")
		expect.equal(mixed.Rare.takes[1].grade, "C")
		expect.equal(mixed.Rare.takes[2].cardId, "R2")
		expect.equal(mixed.Rare.takes[3].grade, "B")
		expect.equal(mixed.Rare.takes[3].count, 22, "R1 keeps its 78 best: 78 Grade B")
	end,

	-- Owner 2026-11-21: "make sure players cant accidentally recycle their most powerful creatures. or the creatures
	-- they've been using". A creature (a levelled card) is never a plain copy, so it never goes; and the copies it
	-- still needs stay, counted from the ones it can use: since the same day the Condenser never squishes a copy better
	-- than the card that gets the star, so a Grade C creature's stars need Grade C copies
	["a creature keeps the copies it can use: its own grade and under first, then the ones a grade-up opens"] = function()
		local stacks = { R1 = { A = counts(2, 0), B = counts(30, 0), C = counts(100, 0) } }
		local got = piles(stacks, { { cardId = "R1", stars = 0, grade = "C" } })
		-- it keeps its 2 best (the Grade A copies) and the 78 its stars and grades need, all of them Grade C: kept
		-- best-first instead, 54 Grade C would go and its stars could never be finished
		expect.equal(got.Rare.count, 22 + 30)
		expect.equal(got.Rare.takes[1].grade, "C")
		expect.equal(got.Rare.takes[1].count, 22)
		expect.equal(got.Rare.takes[2].grade, "B")
		expect.equal(got.Rare.takes[2].count, 30)
		local leftC = 100 - got.Rare.takes[1].count
		assert(leftC >= 64 + 14, `its stars and grades still have their Grade C copies ({leftC})`)
		-- short of its own grade: the grades a grade-up opens fill in, lowest first
		local short = piles({ R1 = { B = counts(200, 0), C = counts(10, 0) } }, { { cardId = "R1", stars = 0, grade = "C" } })
		-- spare: 2 B; its need 78: 10 C, then 68 B
		expect.equal(short.Rare.count, 200 - 2 - 68)
		for _, take in short.Rare.takes do
			expect.equal(take.grade, "B", "every Grade C copy stays")
		end
		-- two creatures of one card: each keeps what it needs (the most either needs of each grade)
		local both = piles({ R1 = { B = counts(100, 0), C = counts(100, 0) } }, { { cardId = "R1", stars = 0, grade = "C" }, { cardId = "R1", stars = 0, grade = "B" } })
		-- spare 2 B; the Grade C one keeps 78 C; the Grade B one (64 + 12 for A and S) 76 B first: keeps 2 + 76 B, 78 C
		expect.equal(both.Rare.count, (100 - 78) + (100 - 78))
		-- a creature anywhere counts: in a station or on display, the server lists it too (RecyclerService)
		local maxed = piles({ R1 = { C = counts(100, 0) } }, { { cardId = "R1", stars = 5, grade = "S" } })
		expect.equal(maxed.Rare.count, 98, "a creature with every star and Grade S needs none: only the 2 spare stay")
		-- what goes is only ever plain copies: never more than the stacks hold, never a foil
		local foils = piles({ R1 = { C = counts(0, 500) } }, {})
		expect.equal(foils.Rare.count, 0)
	end,

	-- "accidentally": the window shows the cards that will go before anything goes, and the server takes no copy that
	-- wasn't in that list (a creature it knows of in a station or a case keeps even more)
	["never more than you saw: the list you confirmed caps every card and grade"] = function()
		local takes = { { cardId = "R1", grade = "C", count = 22 }, { cardId = "R1", grade = "B", count = 30 }, { cardId = "E1", grade = "C", count = 10 } }
		local shown = RecycleRules.shownMap(takes)
		expect.equal(shown["R1:C"], 22)
		expect.equal(shown["R1:B"], 30)
		expect.equal(shown["E1:C"], 10)
		-- the server's own list (a pack opened since: more Grade C) is cut back to what was shown
		local server = { Rare = { rarity = "Rare", count = 82, takes = { { cardId = "R1", grade = "C", count = 40 }, { cardId = "R2", grade = "C", count = 12 }, { cardId = "R1", grade = "B", count = 30 } } } }
		local trimmed = RecycleRules.trimToShown(server, shown)
		expect.equal(trimmed.Rare.count, 52)
		expect.equal(#trimmed.Rare.takes, 2, "a card that wasn't shown never goes")
		expect.equal(trimmed.Rare.takes[1].count, 22)
		expect.equal(trimmed.Rare.takes[2].count, 30)
		expect.equal(server.Rare.count, 82, "the server's own list is left as it was")
		-- what a client sends is checked: card and grade keys, whole counts, a sane size; anything else, no list at all
		local read = RecycleRules.readShown({ ["R1:C"] = 22, ["E1:B"] = 3 })
		assert(read and read["R1:C"] == 22 and read["E1:B"] == 3, "a good list")
		expect.isNil(RecycleRules.readShown(nil))
		expect.isNil(RecycleRules.readShown("R1:C"))
		expect.isNil(RecycleRules.readShown({ ["R1:A"] = 2 }), "Grade A never goes")
		expect.isNil(RecycleRules.readShown({ ["R1:C"] = 2.5 }))
		expect.isNil(RecycleRules.readShown({ ["R1:C"] = -1 }))
		expect.isNil(RecycleRules.readShown({ ["R1:C"] = 0 / 0 }))
		expect.isNil(RecycleRules.readShown({ [1] = 5 }))
		local huge = {}
		for index = 1, 301 do
			huge[`C{index}:C`] = 1
		end
		expect.isNil(RecycleRules.readShown(huge), "too many lines")
		-- the review's list: one line a card (its grades added up), the most first
		local byCard = RecycleRules.byCard(takes)
		expect.equal(#byCard, 2)
		expect.equal(byCard[1].cardId, "R1")
		expect.equal(byCard[1].count, 52)
		expect.equal(byCard[2].count, 10)
		-- its words
		expect.equal(RecycleRules.reviewSay(52), "Recycle these 52 cards?")
		expect.equal(RecycleRules.reviewSay(1), "Recycle this card?")
		expect.equal(RecycleRules.reviewSay(3214), "Recycle these 3,214 cards?")
	end,

	["a pile makes whole materials; the rest stays"] = function()
		local made, used, more = RecycleRules.make(279, 80)
		expect.equal(made, 3)
		expect.equal(used, 240)
		expect.equal(more, 41, "41 more for a fourth")
		made, used, more = RecycleRules.make(41, 60)
		expect.equal(made, 0)
		expect.equal(used, 0)
		expect.equal(more, 19)
		made, used, more = RecycleRules.make(3, 1)
		expect.equal(made, 3)
		expect.equal(used, 3)
		made = RecycleRules.make(0 / 0, 60)
		expect.equal(made, 0, "junk makes nothing")
		-- exactly the cards used leave the binder, plainest first
		local trimmed = RecycleRules.trim({ { cardId = "R1", grade = "C", count = 100 }, { cardId = "R2", grade = "C", count = 90 }, { cardId = "R1", grade = "B", count = 20 } }, 160)
		expect.equal(#trimmed, 2)
		expect.equal(trimmed[2].count, 60)
	end,

	["a plan: one pile or every pile, the same material added up"] = function()
		local got = piles({ R1 = { C = counts(400, 0) }, E1 = { C = counts(200, 0) }, L1 = { C = counts(75, 0) } }, {})
		-- R1 keeps 80: 320 extra = 4 Wild Ore; E1 keeps 64 + 7 + 2 = 73: 127 extra = 2 Star Shards; L1 keeps 72: 3 extra
		local takes, gains = RecycleRules.plan(Recycler, got, "Rare")
		expect.equal(#gains, 1)
		expect.equal(gains[1].item, "wildOre")
		expect.equal(gains[1].count, 4)
		expect.equal(takes[1].count, 320)
		takes, gains = RecycleRules.plan(Recycler, got, nil)
		expect.equal(#gains, 2, "Wild Ore, then the Epics' and the Legendaries' Star Shards as one")
		expect.equal(gains[2].item, "starShard")
		expect.equal(gains[2].count, 2 + 3)
		local cards = 0
		for _, take in takes do
			cards += take.count
		end
		expect.equal(cards, 320 + 120 + 3)
		-- nothing to make: no takes, no gains
		takes, gains = RecycleRules.plan(Recycler, piles({ R1 = { C = counts(100, 0) } }, {}), nil)
		expect.equal(#takes, 0)
		expect.equal(#gains, 0)
		-- a rarity with no recipe
		takes, gains = RecycleRules.plan(Recycler, got, "Common")
		expect.equal(#gains, 0)
	end,

	["the window's words"] = function()
		expect.equal(RecycleRules.count(3214), "3,214")
		expect.equal(RecycleRules.count(41), "41")
		expect.equal(RecycleRules.count(1234567), "1,234,567")
		expect.equal(RecycleRules.rowTitle(Recycler, "Rare", 3214), "3,214 extra Rares")
		expect.equal(RecycleRules.rowTitle(Recycler, "Epic", 1), "1 extra Epic")
		expect.equal(RecycleRules.rowTitle(Recycler, "Legendary", 0), "No extra Legendaries")
		expect.equal(RecycleRules.rowSub(Recycler, "Rare"), "80 make 1 Wild Ore")
		expect.equal(RecycleRules.rowSub(Recycler, "Legendary"), "1 makes 1 Star Shard")
		expect.equal(RecycleRules.outWords(Recycler, "wildOre", 40), "40 Wild Ore")
		expect.equal(RecycleRules.outWords(Recycler, "xpTonic", 1), "1 XP Tonic")
		expect.equal(RecycleRules.outWords(Recycler, "starShard", 9), "9 Star Shards")
		-- a row's button: Recycle, how many more it needs, or None
		local text, on = RecycleRules.rowButton(279, 80)
		expect.equal(text, "Recycle")
		expect.equal(on, true)
		text, on = RecycleRules.rowButton(41, 60)
		expect.equal(text, "19 more")
		expect.equal(on, false)
		text, on = RecycleRules.rowButton(0, 60)
		expect.equal(text, "None")
		expect.equal(on, false)
		-- the big button
		local title, sub = RecycleRules.allWords(Recycler, { { item = "wildOre", count = 40 }, { item = "xpTonic", count = 1 } })
		expect.equal(title, "Recycle everything")
		expect.equal(sub, "40 Wild Ore · 1 XP Tonic")
		title, sub = RecycleRules.allWords(Recycler, {}, 0)
		expect.equal(title, "Nothing to recycle yet")
		expect.isNil(sub)
		title, sub = RecycleRules.allWords(Recycler, {}, 123.4)
		expect.equal(title, "Recycle everything")
		expect.equal(sub, "$123.40")
		-- what you got
		expect.equal(RecycleRules.doneWords(Recycler, { { item = "wildOre", count = 40 } }), "You got 40 Wild Ore!")
		expect.equal(RecycleRules.doneWords(Recycler, { { item = "wildOre", count = 40 }, { item = "starShard", count = 2 } }), "You got 40 Wild Ore and 2 Star Shards!")
		expect.equal(RecycleRules.doneWords(Recycler, { { item = "wildOre", count = 4 }, { item = "xpTonic", count = 1 }, { item = "starShard", count = 2 } }), "You got 4 Wild Ore, 1 XP Tonic and 2 Star Shards!")
	end,

	-- Owner 2026-11-21: "on recycler add. convert to coins. for players who just need coins": the same extras for cash,
	-- every extra card (no leftovers), each rarity a fixed price. About an eighth of a card's worth, like the materials;
	-- and since this pay has no pace of its own, a pack's extras never pay back half the pack
	["coins: every extra card for cash, about an eighth of its worth, never half a pack back"] = function()
		expect.equal(Recycler.COINS.Rare, 0.2)
		expect.equal(Recycler.COINS["Very Rare"], 0.5)
		expect.equal(Recycler.COINS.Epic, 1.5)
		expect.equal(Recycler.COINS.Legendary, 15)
		for _, rarity in Recycler.ORDER do
			local back = Recycler.COINS[rarity] / worth(rarity)
			assert(back >= 0.08 and back <= 0.2, `{rarity}: {math.floor(back * 100)}% back`)
		end
		-- what a pack's cards pay at the most (every one of them an extra): under half its price
		for _, id in { "FirstSparkPack", "DeckBox" } do
			local pays = 0
			for _, slot in PackOdds.SLOTS[id] do
				local total = 0
				for _, entry in slot do
					total += entry.weight
				end
				for _, entry in slot do
					pays += entry.weight / total * (Recycler.COINS[entry.rarity] or 0)
				end
			end
			local product = Products.ById[id]
			local price = product.boxCost / product.unitsPerBox
			assert(pays < price * 0.5, `{id}: its cards recycle for ${string.format("%.2f", pays)} of ${price}`)
		end
		-- a plan: every extra goes, the cash to the cent
		local got = piles({ R1 = { C = counts(518, 0) }, E1 = { C = counts(80, 0) } }, {})
		-- R1 keeps 80: 438 extra at $0.20; E1 keeps 73: 7 extra at $1.50
		local takes, cash = RecycleRules.coinPlan(Recycler, got, "Rare")
		expect.equal(cash, 87.6)
		expect.equal(takes[1].count, 438)
		takes, cash = RecycleRules.coinPlan(Recycler, got, nil)
		expect.equal(cash, 87.6 + 10.5)
		expect.equal(#takes, 2)
		takes, cash = RecycleRules.coinPlan(Recycler, piles({ R1 = { C = counts(10, 0) } }, {}), nil)
		expect.equal(cash, 0)
		expect.equal(#takes, 0)
		-- its words
		expect.equal(RecycleRules.money(87.6), "$87.60")
		expect.equal(RecycleRules.money(3175), "$3,175.00")
		expect.equal(RecycleRules.coinSub(Recycler, "Rare"), "$0.20 each")
		expect.equal(RecycleRules.coinSub(Recycler, "Legendary"), "$15.00 each")
		expect.equal(RecycleRules.doneWords(Recycler, {}, 87.6), "You got $87.60!")
		expect.equal(RecycleRules.doneWords(Recycler, { { item = "wildOre", count = 5 } }, 0), "You got 5 Wild Ore!")
		expect.equal(RecycleRules.modeOk("coins"), true)
		expect.equal(RecycleRules.modeOk("materials"), true)
		expect.equal(RecycleRules.modeOk("gold"), false)
		expect.equal(RecycleRules.modeOk(nil), false)
	end,

	-- "then add timers for every conversion": the machine works on what went in (the stations' timed jobs, with their
	-- Finish now), longer the more it makes, between 10 seconds and an hour
	["every conversion takes time: longer the more it makes, never under 10 seconds nor over an hour"] = function()
		expect.equal(RecycleRules.seconds(Recycler, { { item = "wildOre", count = 5 } }, 0), 100)
		expect.equal(RecycleRules.seconds(Recycler, { { item = "xpTonic", count = 1 } }, 0), 40)
		expect.equal(RecycleRules.seconds(Recycler, { { item = "starShard", count = 2 } }, 0), 120)
		expect.equal(RecycleRules.seconds(Recycler, { { item = "wildOre", count = 5 }, { item = "starShard", count = 1 } }, 0), 160)
		expect.equal(RecycleRules.seconds(Recycler, {}, 87.6), 88, "a second a dollar")
		expect.equal(RecycleRules.seconds(Recycler, {}, 2), 10, "never under 10 seconds")
		expect.equal(RecycleRules.seconds(Recycler, { { item = "wildOre", count = 500 } }, 0), 3600, "never over an hour")
		expect.equal(RecycleRules.seconds(Recycler, {}, 99999), 3600)
		for _, recipe in Recycler.RECIPES do
			assert(Recycler.SECONDS[recipe.item], `{recipe.item} has its time`)
		end
		-- what goes in the station (saved with the save): plain data
		local job = RecycleRules.job({ { item = "wildOre", count = 5 } }, 0, 1000, 100)
		expect.equal(job.kind, "recycle")
		expect.equal(job.startedAt, 1000)
		expect.equal(job.finishAt, 1100)
		expect.equal(job.gains[1].item, "wildOre")
		expect.equal(job.cash, 0)
	end,

	-- a machine in the Build menu from shop Lv 12 for $800 (between the Bulk Bin and the Grading Station)
	["the Recycler is a Fixture from shop level 12 for $800"] = function()
		local fs = require("@lune/fs")
		local source = fs.readFile("src/shared/Config/Shelves.luau")
		local body = string.match(source, '\n\t{\n[^{}]-id = "Recycler"(.-)\n\t},')
		assert(body, "a Recycler entry")
		assert(string.find(body, 'kind = "Recycler"', 1, true), "kind Recycler")
		assert(string.find(body, 'category = "Fixtures"', 1, true), "a Fixture")
		assert(string.find(body, "cost = 800", 1, true), "$800")
		assert(string.find(body, "unlockLevel = 12", 1, true), "level 12")
		expect.equal(Recycler.SHELF, "Recycler")
	end,
}
