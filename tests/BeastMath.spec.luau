--!strict
local BeastMath = require("../src/shared/Util/BeastMath")
local config = require("../src/shared/Config/Beasts")
local expect = require("./lib/expect")

local function isKnown(cardId: string): boolean
	return cardId == "FS01"
end

return {
	["stats: fresh common ember"] = function()
		local stats = BeastMath.getStats(config, "Common", "Ember", false, 1, 1)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 14, "atk") -- 12 * 1.2 = 14.4
		expect.equal(stats.spd, 10, "spd")
	end,

	["stats: max foil legendary shade"] = function()
		-- growth = 2.74 (Lv 30) * 1.6 (5 stars) * 1.05 (foil) = 4.6032
		local stats = BeastMath.getStats(config, "Legendary", "Shade", true, 30, 5)
		expect.equal(stats.hp, 690, "hp")
		expect.equal(stats.atk, 152, "atk")
		expect.equal(stats.spd, 81, "spd")
	end,

	["stats: unknown rarity and element fall back"] = function()
		local stats = BeastMath.getStats(config, "Mythic", "Plasma", false, 1, 1)
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 12, "atk")
	end,

	["value: spec example Cindercub Lv 15 3-star"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, false, 15, 3), 1.08, 0.001)
	end,

	["value: fresh foil"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, true, 1, 1), 0.60, 0.001)
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

	["sanitize: xp above the level cap is trimmed"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 2, xp = 999, stars = 1 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.xp, 140, "xp") -- xpToNext(2) - 1
		expect.equal(beast.foil, false, "missing foil -> false")
	end,

	["sanitize: NaN level falls back to 1"] = function()
		local beast = BeastMath.sanitize(config, { cardId = "FS01", level = 0 / 0, xp = 0, stars = 1 }, isKnown)
		assert(beast, "expected a beast")
		expect.equal(beast.level, 1, "level")
	end,

	["sanitize: rejects unknown cards and non-tables"] = function()
		expect.isNil(BeastMath.sanitize(config, { cardId = "NOPE", level = 1, xp = 0, stars = 1 }, isKnown), "unknown")
		expect.isNil(BeastMath.sanitize(config, "junk", isKnown), "string")
		expect.isNil(BeastMath.sanitize(config, nil, isKnown), "nil")
	end,
}
