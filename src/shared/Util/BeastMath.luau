--!strict
-- Pure Glimmerbeast maths: stats, value, the XP curve, and validation of saved beasts.
-- No Roblox APIs and no requires, so it runs in Studio and in Lune tests (tests/).
-- Callers pass the config (Config/Beasts.luau) in; BeastRules does that for game code.
export type Stats = { hp: number, atk: number, spd: number }
export type BeastData = { cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
export type BeastConfig = {
	MAX_LEVEL: number,
	START_STARS: number,
	MAX_STARS: number,
	BASE_STATS: { [string]: Stats },
	ELEMENT_MULTIPLIERS: { [string]: Stats },
	LEVEL_STAT_GROWTH: number,
	STAR_STAT_GROWTH: number,
	FOIL_STAT_MULTIPLIER: number,
	LEVEL_VALUE_GROWTH: number,
	STAR_VALUE: { number },
	STAR_COSTS: { number },
	XP_BASE: number,
	XP_EXPONENT: number,
	GRADES: { string },
	GRADE_CHANCES: { [string]: number },
	GRADE_CHANCES_BY_RARITY: { [string]: { [string]: number } }?,
	GRADE_BONUS: { [string]: number },
	DEFAULT_GRADE: string,
	POWER_ATK_WEIGHT: number,
	POWER_SPD_WEIGHT: number,
}

local NO_ELEMENT: Stats = { hp = 1, atk = 1, spd = 1 }

local BeastMath = {}

local function isFiniteNumber(value: unknown): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function clampInteger(value: unknown, min: number, max: number, default: number): number
	if not isFiniteNumber(value) then
		return default
	end
	return math.clamp(math.floor(value :: number), min, max)
end

local function getGradeMultiplier(config: BeastConfig, grade: string): number
	return 1 + (config.GRADE_BONUS[grade] or 0)
end

function BeastMath.isGrade(config: BeastConfig, grade: unknown): boolean
	return typeof(grade) == "string" and config.GRADE_BONUS[grade] ~= nil
end

function BeastMath.getGradeRank(config: BeastConfig, grade: string): number
	return table.find(config.GRADES, grade) or 0
end

-- roll is a uniform random number in [0, 1); the caller supplies it so this stays pure
-- The grade chances for a card of this rarity (GRADE_CHANCES unless the rarity has its own)
function BeastMath.gradeChances(config: BeastConfig, rarity: string?): { [string]: number }
	local byRarity = config.GRADE_CHANCES_BY_RARITY
	return if rarity and byRarity and byRarity[rarity] then byRarity[rarity] else config.GRADE_CHANCES
end

function BeastMath.rollGrade(config: BeastConfig, roll: number, rarity: string?): string
	local chances = BeastMath.gradeChances(config, rarity)
	local total = 0
	for _, grade in config.GRADES do
		total += chances[grade] or 0
		-- The epsilon keeps float sums like 0.5 + 0.3 + 0.15 = 0.95000000000000001 on the right boundary
		if roll < total - 1e-9 then
			return grade
		end
	end
	return config.GRADES[#config.GRADES]
end

function BeastMath.getPower(config: BeastConfig, stats: Stats): number
	return stats.hp + stats.atk * config.POWER_ATK_WEIGHT + stats.spd * config.POWER_SPD_WEIGHT
end

function BeastMath.getStats(
	config: BeastConfig,
	rarity: string,
	element: string,
	foil: boolean,
	level: number,
	stars: number,
	grade: string
): Stats
	local base = config.BASE_STATS[rarity] or config.BASE_STATS.Common
	local elementBias = config.ELEMENT_MULTIPLIERS[element] or NO_ELEMENT
	local growth = (1 + config.LEVEL_STAT_GROWTH * (level - 1))
		* (1 + config.STAR_STAT_GROWTH * stars)
		* (if foil then config.FOIL_STAT_MULTIPLIER else 1)
		* getGradeMultiplier(config, grade)
	return {
		hp = math.round(base.hp * elementBias.hp * growth),
		atk = math.round(base.atk * elementBias.atk * growth),
		spd = math.round(base.spd * elementBias.spd * growth),
	}
end

function BeastMath.getValue(
	config: BeastConfig,
	baseValue: number,
	foilMultiplier: number,
	foil: boolean,
	level: number,
	stars: number,
	grade: string
): number
	local value = baseValue
		* (if foil then foilMultiplier else 1)
		* (1 + config.LEVEL_VALUE_GROWTH * (level - 1))
		* (config.STAR_VALUE[stars + 1] or 1)
		* getGradeMultiplier(config, grade)
	return math.round(value * 100) / 100
end

function BeastMath.getXpToNext(config: BeastConfig, level: number): number
	if level >= config.MAX_LEVEL then
		return 0
	end
	return math.round(config.XP_BASE * level ^ config.XP_EXPONENT)
end

-- Duplicates needed for the next star, or nil if there is no next star
function BeastMath.getCondenseCost(config: BeastConfig, stars: number): number?
	if stars < 0 or stars >= config.MAX_STARS then
		return nil
	end
	return config.STAR_COSTS[math.floor(stars) + 1]
end

-- Applies every level-up the XP covers; leftover XP carries over. XP stops at max level.
function BeastMath.applyXp(config: BeastConfig, level: number, xp: number, amount: number): (number, number)
	if not isFiniteNumber(amount) or amount <= 0 then
		return level, xp
	end
	local total = xp + math.floor(amount)
	while level < config.MAX_LEVEL do
		local needed = BeastMath.getXpToNext(config, level)
		if total < needed then
			break
		end
		total -= needed
		level += 1
	end
	if level >= config.MAX_LEVEL then
		total = 0
	end
	return level, total
end

-- Turns untrusted saved data into a valid beast, or nil if it can't be one
function BeastMath.sanitize(config: BeastConfig, raw: unknown, isKnownCard: (string) -> boolean): BeastData?
	if typeof(raw) ~= "table" then
		return nil
	end
	local entry = raw :: { [string]: unknown }
	local cardId = entry.cardId
	if typeof(cardId) ~= "string" or not isKnownCard(cardId) then
		return nil
	end
	local level = clampInteger(entry.level, 1, config.MAX_LEVEL, 1)
	local stars = clampInteger(entry.stars, 0, config.MAX_STARS, config.START_STARS)
	local xpCap = math.max(0, BeastMath.getXpToNext(config, level) - 1)
	return {
		cardId = cardId,
		foil = entry.foil == true,
		level = level,
		xp = clampInteger(entry.xp, 0, xpCap, 0),
		stars = stars,
		grade = if BeastMath.isGrade(config, entry.grade) then entry.grade :: string else config.DEFAULT_GRADE,
	}
end

return BeastMath
