--!strict
local BeastMath = require("../src/shared/Util/BeastMath")
local config = require("../src/shared/Config/Beasts")
local expect = require("./lib/expect")

local function isKnown(cardId: string): boolean
	return cardId == "FS01"
end

return {
	["stats: plain common ember"] = function()
		local stats = BeastMath.getStats(config, "Common", "Ember", false, 1, 0)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 14, "atk") -- 12 * 1.2 = 14.4
		expect.equal(stats.spd, 10, "spd")
	end,

	["stats: max foil legendary shade"] = function()
		-- growth = 2.74 (Lv 30) * 1.75 (5 stars) * 1.05 (foil) = 5.03475
		local stats = BeastMath.getStats(config, "Legendary", "Shade", true, 30, 5)
		expect.equal(stats.hp, 755, "hp")
		expect.equal(stats.atk, 166, "atk")
		expect.equal(stats.spd, 89, "spd")
	end,

	["stats: unknown rarity and element fall back"] = function()
		local stats = BeastMath.getStats(config, "Mythic", "Plasma", false, 1, 0)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 12, "atk")
	end,

	["stats: very rare base"] = function()
		local stats = BeastMath.getStats(config, "Very Rare", "Tide", false, 1, 0)
		expect.equal(stats.hp, 114, "hp") -- 95 * 1.2
		expect.equal(stats.atk, 19, "atk")
		expect.equal(stats.spd, 13, "spd")
	end,

	["value: Cindercub Lv 15 3 stars"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, false, 15, 3), 14.40, 0.001) -- 0.20 * 2.4 * 30
	end,

	["value: plain foil"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, true, 1, 0), 0.60, 0.001)
	end,

	["value: star table 0 to 5"] = function()
		local expected = { 1, 6, 15, 30, 50, 80 }
		for stars = 0, 5 do
			expect.near(BeastMath.getValue(config, 1, 3, false, 1, stars), expected[stars + 1], 0.001, `{stars} stars`)
		end
	end,

	["condense cost per star, 64 total"] = function()
		local total = 0
		for stars, cost in { [0] = 4, [1] = 8, [2] = 12, [3] = 16, [4] = 24 } do
			expect.equal(BeastMath.getCondenseCost(config, stars), cost, `{stars} stars`)
			total += cost
		end
		expect.equal(total, 64, "total")
		expect.isNil(BeastMath.getCondenseCost(config, 5), "max stars")
		expect.isNil(BeastMath.getCondenseCost(config, -1), "negative")
	end,

	["xp curve"] = function()
		expect.equal(BeastMath.getXpToNext(config, 1), 50, "Lv1")
		expect.equal(BeastMath.getXpToNext(config, 2), 141, "Lv2")
		expect.equal(BeastMath.getXpToNext(config, 29), 7808, "Lv29")
		expect.equal(BeastMath.getXpToNext(config, 30), 0, "max")
	end,

	["applyXp: several level-ups carry the remainder"] = function()
		local level, xp = BeastMath.applyXp(config, 1, 0, 500) -- 50 + 141 + 260 = 451
		expect.equal(level, 4, "level")
		expect.equal(xp, 49, "xp")
	end,

	["applyXp: stops at max level with 0 xp"] = function()
		local level, xp = BeastMath.applyXp(config, 29, 7800, 100)
		expect.equal(level, 30, "level")
		expect.equal(xp, 0, "xp")
		local level2, xp2 = BeastMath.applyXp(config, 30, 0, 1000)
		expect.equal(level2, 30, "level at cap")
		expect.equal(xp2, 0, "xp at cap")
	end,

	["applyXp: ignores zero, negative and NaN amounts"] = function()
		local nan = 0 / 0
		for _, amount in { 0, -10, nan } do
			local level, xp = BeastMath.applyXp(config, 3, 20, amount)
			expect.equal(level, 3, "level")
			expect.equal(xp, 20, "xp")
		end
	end,

	["sanitize: clamps out-of-range values"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", foil = true, level = 99, xp = -5, stars = 9 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.level, 30, "level")
		expect.equal(beast.stars, 5, "stars")
		expect.equal(beast.xp, 0, "xp")
		expect.equal(beast.foil, true, "foil")
	end,

	["sanitize: stars default and floor are 0"] = function()
		local nan = 0 / 0
		for _, raw in { -3, nan, "two" } do
			local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0, stars = raw }, isKnown)
			assert(beast, "expected a beast")
			expect.equal(beast.stars, 0, `stars {tostring(raw)}`)
		end
		local missing = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0 }, isKnown)
		assert(missing, "expected a beast")
		expect.equal(missing.stars, 0, "missing stars")
	end,

	["sanitize: xp above the level cap is trimmed"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 2, xp = 999, stars = 0 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.xp, 140, "xp") -- xpToNext(2) - 1
		expect.equal(beast.foil, false, "missing foil -> false")
	end,

	["sanitize: NaN level falls back to 1"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 0 / 0, xp = 0, stars = 0 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.level, 1, "level")
	end,

	["sanitize: rejects unknown cards and non-tables"] = function()
		expect.isNil(BeastMath.sanitize(config, { cardId = "NOPE", level = 1, xp = 0, stars = 0 }, isKnown), "unknown")
		expect.isNil(BeastMath.sanitize(config, "junk", isKnown), "string")
		expect.isNil(BeastMath.sanitize(config, nil, isKnown), "nil")
	end,
}
