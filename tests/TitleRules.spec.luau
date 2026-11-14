--!strict
-- The owner 2026-11-12: "add TITLES tab on the character menu, I'm planning to add titles system"
local TitleRules = require("../src/shared/Util/TitleRules")
local Titles = require("../src/shared/Config/Titles")
local expect = require("./lib/expect")

local NONE = { cleared = {}, secret = false }
local BOTH = { cleared = { prismHydra = true }, secret = true }

-- A player well into the game (owner 2026-11-13: "add more titles that is obtainable in game")
local BUSY = {
	cleared = { meadowWarden = true, caveBroodQueen = true, emberColossus = true, frostTyrant = true },
	secret = false,
	supporter = 0,
	level = 31,
	stats = { packsOpened = 120, customersServed = 400, totalEarned = 52000 },
	cards = 22,
	sets = { FS = { have = 30, total = 35 } },
	rarities = { Legendary = 1 },
	pvpWins = 3,
}

return {
	["more titles to earn: shop levels, sales, packs, collection, bosses and duels"] = function()
		expect.equal(#Titles.ORDER >= 15, true, "plenty to chase")
		local got = TitleRules.earned(Titles, BUSY)
		for _, id in { "shopkeeper", "tycoon", "packRipper", "luckyStar", "collector", "wildHunter" } do
			expect.equal(table.find(got, id) ~= nil, true, `{id} earned`)
		end
		for _, id in { "cardMogul", "millionaire", "shopStar", "setMaster", "trailblazer", "duelist", "champion", "dungeonConqueror" } do
			expect.equal(table.find(got, id) == nil, true, `{id} not yet`)
		end
	end,

	["how far a locked title is: its count and goal"] = function()
		local have, need = TitleRules.progress(Titles, BUSY, "cardMogul")
		expect.equal(have == 31 and need == 50, true, "shop level")
		have, need = TitleRules.progress(Titles, BUSY, "setMaster")
		expect.equal(have == 30 and need == 35, true, "First Spark cards")
		have, need = TitleRules.progress(Titles, BUSY, "trailblazer")
		expect.equal(have == 1 and need == 3, true, "Frontier bosses beaten")
		have, need = TitleRules.progress(Titles, BUSY, "millionaire")
		expect.equal(have == 52000 and need == 1000000, true, "money from sales")
		have, need = TitleRules.progress(Titles, NONE, "packRipper")
		expect.equal(have == 0 and need == 100, true, "an old progress with no counts: zero")
	end,

	["new titles: earned now but never told, in order; once earned a title stays earned"] = function()
		expect.equal(table.concat(TitleRules.newly({ "tycoon", "collector", "shopkeeper" }, { "shopkeeper" }), ","), "tycoon,collector")
		expect.equal(#TitleRules.newly({ "tycoon" }, { "tycoon" }), 0, "told already")
		expect.equal(table.concat(TitleRules.merge(Titles, { "collector" }, { "dungeonConqueror" }), ","), "dungeonConqueror,collector", "kept from another place, in the list's order")
	end,

	-- owner 2026-11-12, after looking at other games: "lets do gradient, and shorter" (pick B: small gradient text)
	["titles are short and drawn in a two-colour gradient; supporter titles shimmer"] = function()
		for _, id in Titles.ORDER do
			local title = Titles.ById[id]
			expect.equal(#title.name <= 12, true, `{id}: "{title.name}" is short`)
			expect.equal(#title.gradient == 2 and #title.gradient[1] == 3 and #title.gradient[2] == 3, true, `{id}: its gradient`)
			expect.equal((title.shimmer == true) == (title.check.kind == "supporter"), true, `{id}: shimmers only if a supporter title`)
		end
		expect.equal(Titles.ById.dungeonConqueror.name, "Hydra Slayer")
		expect.equal(Titles.ById.legendarySupporter.name, "Legend")
	end,

	-- "Support the dev" (owner 2026-11-12): a gift earns its tier's title and every one below it
	["supporter titles: earned by the best gift, its tier and the ones below"] = function()
		local function earnedAt(best: number): { string }
			return TitleRules.earned(Titles, { cleared = {}, secret = false, supporter = best })
		end
		expect.equal(#earnedAt(0), 0, "no gift: none")
		expect.equal(table.concat(earnedAt(1), ","), "supporter")
		expect.equal(table.find(earnedAt(3), "legendarySupporter") ~= nil and table.find(earnedAt(3), "supporter") ~= nil, true, "the top tier has all three")
		expect.equal(TitleRules.shown(Titles, "", earnedAt(3)), "legendarySupporter", "automatic: the best one first")
		expect.equal(#TitleRules.earned(Titles, NONE), 0, "an old progress with no supporter field: none")
	end,

	["every title has a name, a colour, how to earn it and a check"] = function()
		for _, id in Titles.ORDER do
			local title = Titles.ById[id]
			assert(title, `{id} is listed`)
			expect.equal(#title.name > 0 and #title.how > 0 and #title.color == 3, true, `{id}'s words`)
			local kinds = { bossClear = true, secret = true, supporter = true, level = true, stat = true, bosses = true, cards = true, set = true, rarity = true, pvp = true }
			expect.equal(kinds[title.check.kind] == true, true, `{id}'s check`)
			expect.equal(typeof(title.icon) == "string" and #title.icon > 0, true, `{id}: an icon before it`)
			expect.equal(string.find(title.name .. title.how, "[\128-\255]") == nil, true, `{id}: plain ASCII`)
		end
	end,

	["earned: from boss clears and the secret, in the list's order"] = function()
		expect.equal(#TitleRules.earned(Titles, NONE), 0, "none yet")
		local both = TitleRules.earned(Titles, BOTH)
		expect.equal(table.concat(both, ","), "dungeonConqueror,crystalSeeker")
		expect.equal(table.concat(TitleRules.earned(Titles, { cleared = {}, secret = true }), ","), "crystalSeeker")
	end,

	["shown: the equipped one if earned; automatic: the first earned (Dungeon Conqueror before Crystal Seeker)"] = function()
		local both = TitleRules.earned(Titles, BOTH)
		expect.equal(TitleRules.shown(Titles, "", both), "dungeonConqueror", "automatic: today's pick")
		expect.equal(TitleRules.shown(Titles, "crystalSeeker", both), "crystalSeeker", "chosen")
		expect.equal(TitleRules.shown(Titles, "crystalSeeker", { "dungeonConqueror" }), "dungeonConqueror", "chosen but not earned: automatic")
		expect.equal(TitleRules.shown(Titles, "removedTitle", both), "dungeonConqueror", "a title that no longer exists: automatic")
		expect.equal(TitleRules.shown(Titles, "", {}), nil, "none earned: no title")
	end,

	["canEquip: only an earned title, or automatic"] = function()
		expect.equal(TitleRules.canEquip("", {}), true, "automatic always")
		expect.equal(TitleRules.canEquip("crystalSeeker", { "crystalSeeker" }), true)
		expect.equal(TitleRules.canEquip("dungeonConqueror", { "crystalSeeker" }), false, "not earned: refused")
		expect.equal(TitleRules.canEquip("madeUp", { "crystalSeeker" }), false)
	end,

	-- achievement decor (spec 2026-11-14-shop-windows-design): one check met or not, the titles' own measure
	["one achievement check, met or not"] = function()
		local progress = { cleared = { frostTyrant = true }, secret = false, stats = { packsOpened = 499 } }
		expect.equal(TitleRules.meets({ kind = "bossClear", boss = "frostTyrant" }, progress), true)
		expect.equal(TitleRules.meets({ kind = "bossClear", boss = "prismHydra" }, progress), false)
		expect.equal(TitleRules.meets({ kind = "stat", stat = "packsOpened", min = 500 }, progress), false)
		progress.stats = { packsOpened = 500 }
		expect.equal(TitleRules.meets({ kind = "stat", stat = "packsOpened", min = 500 }, progress), true)
	end,
}

