--!strict
local BeastMath = require("../src/shared/Util/BeastMath")
local config = require("../src/shared/Config/Beasts")
local expect = require("./lib/expect")

local function isKnown(cardId: string): boolean
	return cardId == "FS01"
end

return {
	["stats: plain common ember"] = function()
		local stats = BeastMath.getStats(config, "Common", "Ember", false, 1, 0, "C")
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 14, "atk") -- 12 * 1.2 = 14.4
		expect.equal(stats.spd, 10, "spd")
	end,

	["stats: max foil legendary shade"] = function()
		-- growth = 2.74 (Lv 30) * 1.75 (5 stars) * 1.05 (foil) = 5.03475
		local stats = BeastMath.getStats(config, "Legendary", "Shade", true, 30, 5, "C")
		expect.equal(stats.hp, 906, "hp")
		expect.equal(stats.atk, 199, "atk")
		expect.equal(stats.spd, 111, "spd")
	end,

	["stats: unknown rarity and element fall back"] = function()
		local stats = BeastMath.getStats(config, "Mythic", "Plasma", false, 1, 0, "C")
		expect.equal(stats.hp, 60, "hp")
		expect.equal(stats.atk, 12, "atk")
	end,

	["stats: very rare base"] = function()
		local stats = BeastMath.getStats(config, "Very Rare", "Tide", false, 1, 0, "C")
		expect.equal(stats.hp, 120, "hp") -- 100 * 1.2
		expect.equal(stats.atk, 21, "atk")
		expect.equal(stats.spd, 14, "spd")
	end,

	["value: Cindercub Lv 15 3 stars"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, false, 15, 3, "C"), 0.20 * (1 + config.LEVEL_VALUE_GROWTH * 14) * config.STAR_VALUE[4], 0.006) -- to the cent
	end,

	["value: plain foil"] = function()
		expect.near(BeastMath.getValue(config, 0.20, 3, true, 1, 0, "C"), 0.60, 0.001)
	end,

	["value: star table 0 to 5"] = function()
		expect.equal(#config.STAR_VALUE, config.MAX_STARS + 1)
		expect.equal(config.STAR_VALUE[1], 1, "no stars: the card's own value")
		for stars = 0, 5 do
			expect.near(BeastMath.getValue(config, 1, 3, false, 1, stars, "C"), config.STAR_VALUE[stars + 1], 0.001, `{stars} stars`)
		end
	end,

	-- owner 2026-11-20, from a tester: "you can easily earn money fast by upgrading stars of the cards then selling it.
	-- make sure this doesnt get abused". A star was worth more than the copies that made it (1 star: 6x for 5 cards,
	-- or for 3 cards and 2 Star Shards), and one sale to one customer carried all of it. A starred card is now worth
	-- less than the cards that went into it, even with Star Shards standing in for half of them: stars are for power
	-- ...and levels (free XP from fights and tonics) multiplied that again: a Lv 30 card sold for 3.9x. A maxed card,
	-- 5 stars and Lv 30, is still worth less than the 65 cards inside it; a level adds a little
	["levels add a little value, never a way to print money"] = function()
		local top = 1 + config.LEVEL_VALUE_GROWTH * (config.MAX_LEVEL - 1)
		assert(top > 1 and top <= 2, `a Lv {config.MAX_LEVEL} card is worth {top}x`)
		local cards = 1
		for _, cost in config.STAR_COSTS do
			cards += cost
		end
		assert(config.STAR_VALUE[config.MAX_STARS + 1] * top < cards, "maxed: under the cards that went into it")
	end,

	["a starred card is never worth more than the cards that went into it"] = function()
		local cards, fewest = 1, 1 -- the copies inside it, and the fewest with Star Shards filling their share
		for stars = 1, config.MAX_STARS do
			local cost = config.STAR_COSTS[stars]
			cards += cost
			fewest += cost - math.floor(cost * config.MAX_SHARD_SHARE)
			local worth = config.STAR_VALUE[stars + 1]
			assert(worth <= fewest * 0.9, `{stars} stars: worth {worth} cards, made of {fewest} at the least`)
			assert(worth <= cards * 0.5, `{stars} stars: worth {worth} cards, made of {cards} without shards`)
			assert(worth > config.STAR_VALUE[stars], `{stars} stars is still worth more than {stars - 1}`)
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
	["grade: S boosts stats by 10%"] = function()
		local c = BeastMath.getStats(config, "Legendary", "Volt", false, 1, 0, "C")
		local s = BeastMath.getStats(config, "Legendary", "Volt", false, 1, 0, "S")
		expect.equal(c.hp, 180, "C hp")
		expect.equal(s.hp, 198, "S hp")
	end,

	-- owner 2026-11-21: "change the pricing of cards. Legendary Grade S should be really expensive. Legendary Grade A
	-- should be expensive and so on. grades should affect cards price" (a grade added 3 / 6 / 10% before)
	["a card's grade is a big part of its price, the more the rarer the card"] = function()
		local function worth(rarity: string, grade: string, base: number?, foil: boolean?, stars: number?): number
			return BeastMath.getValue(config, base or 100, 3, foil == true, 1, stars or 0, grade, rarity)
		end
		-- a $100 card of each rarity at each grade
		expect.equal(worth("Legendary", "C"), 100)
		expect.equal(worth("Legendary", "B"), 150)
		expect.equal(worth("Legendary", "A"), 400, "expensive")
		expect.equal(worth("Legendary", "S"), 2000, "really expensive")
		expect.equal(worth("Epic", "S"), 1200)
		expect.equal(worth("Epic", "A"), 300)
		expect.equal(worth("Very Rare", "S"), 800)
		expect.equal(worth("Rare", "S"), 500)
		expect.equal(worth("Common", "S"), 500)
		expect.equal(worth("Common", "B"), 125)
		-- every grade is worth more than the one under it, and a rarer card's grade more than a commoner one's
		local order = { "Common", "Rare", "Very Rare", "Epic", "Legendary" }
		for index, rarity in order do
			for g = 2, #config.GRADES do
				assert(worth(rarity, config.GRADES[g]) > worth(rarity, config.GRADES[g - 1]), `{rarity} {config.GRADES[g]}`)
				if index > 1 then
					assert(worth(rarity, config.GRADES[g]) >= worth(order[index - 1], config.GRADES[g]), `{rarity} {config.GRADES[g]} against {order[index - 1]}`)
				end
			end
		end
		-- the real cards: the dearest Legendary ($150) at Grade S, and its foil
		expect.equal(worth("Legendary", "S", 150), 3000)
		expect.equal(worth("Legendary", "S", 150, true), 9000)
		-- an unknown rarity or grade: no premium
		expect.equal(BeastMath.getValue(config, 100, 3, false, 1, 0, "S", nil), 500, "no rarity: the plainest table")
		expect.equal(BeastMath.getValue(config, 100, 3, false, 1, 0, "Z", "Legendary"), 100)
	end,

	-- the grade's part is added once, never multiplied by the stars or the levels: squishing plain copies into a Grade S
	-- card can't multiply what they're worth (the star rule above keeps holding at every grade)
	["a grade's worth is added on top: stars and levels never multiply it"] = function()
		for _, rarity in { "Common", "Epic", "Legendary" } do
			local premium = BeastMath.getValue(config, 100, 3, false, 1, 0, "S", rarity) - BeastMath.getValue(config, 100, 3, false, 1, 0, "C", rarity)
			for stars = 0, config.MAX_STARS do
				for _, level in { 1, 15, config.MAX_LEVEL } do
					local s = BeastMath.getValue(config, 100, 3, false, level, stars, "S", rarity)
					local c = BeastMath.getValue(config, 100, 3, false, level, stars, "C", rarity)
					expect.near(s - c, premium, 0.011, `{rarity} {stars} stars Lv {level}`)
				end
			end
		end
	end,

	-- grading a card up to sell it never pays: every step's cash (Config/Grading) is more than the step adds to the
	-- dearest card of its rarity, even a foil
	["grading up never pays for itself in the card's price"] = function()
		local Grading = require("../src/shared/Config/Grading")
		-- each rarity's dearest card (Config/Rarities maxValue; that file needs Roblox) and the foil's x3
		local TOP = { Common = 0.5, Rare = 3, ["Very Rare"] = 6, Epic = 20, Legendary = 150 }
		local FOIL = 3
		for rarity, steps in Grading.COSTS do
			local top = TOP[rarity]
			for g = 2, #config.GRADES do
				local grade, under = config.GRADES[g], config.GRADES[g - 1]
				local gain = BeastMath.getValue(config, top, FOIL, true, 1, 0, grade, rarity)
					- BeastMath.getValue(config, top, FOIL, true, 1, 0, under, rarity)
				assert(gain < steps[grade].cash, `{rarity} to {grade}: adds ${gain}, costs ${steps[grade].cash}`)
			end
		end
	end,

	["grade: unknown grade counts as C"] = function()
		local c = BeastMath.getStats(config, "Rare", "Tide", false, 1, 0, "C")
		local x = BeastMath.getStats(config, "Rare", "Tide", false, 1, 0, "Z")
		expect.equal(x.hp, c.hp, "hp")
	end,

	["grade: roll boundaries"] = function()
		-- C 55% / B 30% / A 13% / S 2%
		local cases = { { 0, "C" }, { 0.549, "C" }, { 0.55, "B" }, { 0.849, "B" }, { 0.85, "A" }, { 0.979, "A" }, { 0.98, "S" }, { 0.9999, "S" } }
		for _, case in cases do
			expect.equal(BeastMath.rollGrade(config, case[1]), case[2], `roll {case[1]}`)
		end
	end,

	["grade: rarer cards are less often Grade S, the rest going to C"] = function()
		for _, rarity in { "Common", "Rare", "Very Rare" } do
			expect.equal(BeastMath.gradeChances(config, rarity), config.GRADE_CHANCES, `{rarity} uses the default`)
		end
		local epic, legendary = BeastMath.gradeChances(config, "Epic"), BeastMath.gradeChances(config, "Legendary")
		assert(legendary.S < epic.S and epic.S < config.GRADE_CHANCES.S, "Grade S isn't rarer on rarer cards")
		for _, chances in { epic, legendary } do
			local total = 0
			for _, grade in config.GRADES do
				total += chances[grade] or 0
			end
			expect.near(total, 1, 1e-9, "the chances add up to 1")
			expect.equal(chances.B, config.GRADE_CHANCES.B, "B unchanged")
			expect.equal(chances.A, config.GRADE_CHANCES.A, "A unchanged")
		end
		-- Legendary: C 56% / B 30% / A 13% / S 1%
		expect.equal(BeastMath.rollGrade(config, 0.985, "Legendary"), "A", "a roll that's S on a Common is A on a Legendary")
		expect.equal(BeastMath.rollGrade(config, 0.985), "S", "no rarity: the default chances")
		expect.equal(BeastMath.rollGrade(config, 0.991, "Legendary"), "S", "the top 1%")
		expect.equal(BeastMath.rollGrade(config, 0.559, "Legendary"), "C", "C reaches 56%")
	end,

	["grade: rolled from any chance table, like the pity Legendary's"] = function()
		local stingy = { C = 0.8, B = 0.18, A = 0.018, S = 0.002 }
		expect.equal(BeastMath.rollGradeFrom(config, 0.79, stingy), "C", "C up to 80%")
		expect.equal(BeastMath.rollGradeFrom(config, 0.97, stingy), "B", "B to 98%")
		expect.equal(BeastMath.rollGradeFrom(config, 0.9985, stingy), "S", "only the top 0.2% is S")
	end,

	["grade: helpers"] = function()
		expect.equal(BeastMath.isGrade(config, "S"), true, "S")
		expect.equal(BeastMath.isGrade(config, "Z"), false, "Z")
		expect.equal(BeastMath.isGrade(config, 5), false, "number")
		expect.equal(BeastMath.getGradeRank(config, "C"), 1, "C rank")
		expect.equal(BeastMath.getGradeRank(config, "S"), 4, "S rank")
		expect.equal(BeastMath.getGradeRank(config, "Z"), 0, "unknown rank")
	end,

	["power: weighted sum"] = function()
		expect.equal(BeastMath.getPower(config, { hp = 60, atk = 12, spd = 10 }), 170, "common base")
	end,

	["power: rarity beats grade at every level and star"] = function()
		local rarities = { "Common", "Rare", "Very Rare", "Epic", "Legendary" }
		local elements = {}
		for name in config.ELEMENT_MULTIPLIERS do
			table.insert(elements, name)
		end
		for i = 1, #rarities - 1 do
			for _, level in { 1, 15, 30 } do
				for stars = 0, 5 do
					local best, worst = -math.huge, math.huge
					for _, element in elements do
						best = math.max(best, BeastMath.getPower(config, BeastMath.getStats(config, rarities[i], element, true, level, stars, "S")))
						worst = math.min(worst, BeastMath.getPower(config, BeastMath.getStats(config, rarities[i + 1], element, false, level, stars, "C")))
					end
					assert(best < worst, `{rarities[i]} {best} >= {rarities[i + 1]} {worst} at Lv {level}, {stars} stars`)
				end
			end
		end
	end,

	["sanitize: grade kept or defaulted"] = function()
		local s = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0, stars = 0, grade = "S" }, isKnown)
		assert(s, "expected a card")
		expect.equal(s.grade, "S", "kept")
		local bad = BeastMath.sanitize(config, { cardId = "FS01", level = 1, xp = 0, stars = 0, grade = "ZZ" }, isKnown)
		assert(bad, "expected a card")
		expect.equal(bad.grade, "C", "defaulted")
	end,
	["level progress: the share of the way to the next level, full at max"] = function()
		expect.equal(BeastMath.levelProgress(config, 1, 0), 0)
		expect.near(BeastMath.levelProgress(config, 1, 25), 0.5, 1e-9, "25 of 50")
		expect.equal(BeastMath.levelProgress(config, config.MAX_LEVEL, 0), 1, "max level: full")
		expect.equal(BeastMath.levelProgress(config, 1, 999), 1, "never past full")
	end,
}
