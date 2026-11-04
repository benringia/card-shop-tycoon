--!strict
-- Shop levels 1-100 (spec 2026-11-04-round4-design section 8): every unlock moved to the new level whose XP is
-- nearest the XP it needed before the new curve, so the game's pace stays the same. Config/Shelves holds Color3
-- values, so its unlock levels are read from its text (like tests/ShelvesConfig.spec).
local fs = require("@lune/fs")
local LevelMath = require("../src/shared/Util/LevelMath")
local Levels = require("../src/shared/Config/Levels")
local Products = require("../src/shared/Config/Products")
local Jobs = require("../src/shared/Config/Jobs")
local Swords = require("../src/shared/Config/Swords")
local Bosses = require("../src/shared/Config/Bosses")
local Pvp = require("../src/shared/Config/Pvp")
local expect = require("./lib/expect")

-- The XP each unlock needed before the new curve (old levels 2-10 and the bosses' 12, 15, 18, 22)
local OLD_PRODUCTS = { CardSleeves = 150, DeckBox = 2500, FirstSparkBox = 9000 }
local OLD_SHELVES = { WallShelf = 500, Condenser = 1200, AccessoryHook = 2500, BigDisplayRack = 5000, GradingStation = 15000 }
local OLD_JOBS, OLD_SWORD = 36000, 500
local OLD_BOSSES = { 500, 2500, 15000, 65670, 129044, 225429, 436223 }

local function nearest(xp: number): number
	local best, bestGap = 1, math.huge
	for level = 1, Levels.MAX_LEVEL do
		local gap = math.abs(LevelMath.getRequiredXp(Levels, level) - xp)
		if gap < bestGap then
			best, bestGap = level, gap
		end
	end
	return best
end

local function shelfUnlock(id: string): number?
	local source = fs.readFile("src/shared/Config/Shelves.luau")
	local start = string.find(source, `id = "{id}"`, 1, true)
	assert(start, `no shelf {id}`)
	return tonumber(string.match(source, "unlockLevel = (%d+)", start))
end

return {
	["every unlock sits at the level nearest its XP today"] = function()
		for id, old in OLD_PRODUCTS do
			expect.equal(Products.ById[id].unlockLevel, nearest(old), `product {id}`)
		end
		for id, old in OLD_SHELVES do
			expect.equal(shelfUnlock(id), nearest(old), `shelf {id}`)
		end
		expect.equal(Jobs.UNLOCK_LEVEL, nearest(OLD_JOBS), "shop jobs")
		expect.equal(Swords.UNLOCK_SHOP_LEVEL, nearest(OLD_SWORD), "starter sword")
		for index, bossId in Bosses.LADDER do
			expect.equal(Bosses.BOSSES[bossId].shopLevel, nearest(OLD_BOSSES[index]), `boss {index} {bossId}`)
		end
	end,

	["the new levels are the spec's table"] = function()
		expect.equal(Products.ById.CardSleeves.unlockLevel, 3, "Card Sleeves")
		expect.equal(Jobs.UNLOCK_LEVEL, 20, "shop jobs")
		local want = { 4, 7, 14, 26, 34, 43, 57 }
		for index, bossId in Bosses.LADDER do
			expect.equal(Bosses.BOSSES[bossId].shopLevel, want[index], `boss {index}`)
		end
	end,

	["PvP bet cap halves"] = function()
		expect.equal(Pvp.CAP_PER_LEVEL, 25, "CAP_PER_LEVEL")
	end,
}
