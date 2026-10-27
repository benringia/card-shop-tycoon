--!strict
-- Economy simulator: how long players take to reach pull goals, using the game's real numbers (pack odds and pity,
-- grade chances, grading costs, card list, product prices, customer timing). Monte Carlo over many players.
-- Usage: lune run tools/economy/sim [players]
--
-- The player modelled (an early-game shop, DESIGN.md 7.5): stocks only First Spark packs at market price, so customers
-- buy them; the shop earns while the player opens packs with the profit, one every OPEN_SECONDS. No monsters, no card
-- sales, no other products. Change the assumptions below to model other stages.
local fs = require("@lune/fs")
local process = require("@lune/process")

local PackOdds = require("../../src/shared/Config/PackOdds")
local Grading = require("../../src/shared/Config/Grading")
local Beasts = require("../../src/shared/Config/Beasts")
local CardList = require("../../src/shared/Config/CardList")
local Products = require("../../src/shared/Config/Products")
local Pricing = require("../../src/shared/Config/Pricing")
local BeastMath = require("../../src/shared/Util/BeastMath")
local PityRules = require("../../src/shared/Util/PityRules")
local CondenseRules = require("../../src/shared/Util/CondenseRules")

-- Assumptions ---------------------------------------------------------------------------------------------------
local PACK_ID = "FirstSparkPack"
local OPEN_SECONDS = 6 -- carrying, tearing and the reveal, per pack
local STAR_DUPLICATES = Beasts.STAR_COSTS[1] -- the first star
local MAX_HOURS = 400 -- a player who hasn't reached a goal by then counts as this
local PLAYERS = tonumber((process.args[1])) or 2000

-- Customer timing from Config/Customers (it holds Color3 values, so Lune reads the numbers from its text)
local customersSource = fs.readFile("src/shared/Config/Customers.luau")
local function readNumber(name: string): number
	local value = string.match(customersSource, name .. " = ([%d%.]+)")
	assert(value, `Config/Customers has no {name}`)
	return tonumber(value) :: number
end
local customersPerMinute = 60 / ((readNumber("SPAWN_INTERVAL_MIN") + readNumber("SPAWN_INTERVAL_MAX")) / 2)
local itemsPerCustomer = (readNumber("ITEMS_MIN") + readNumber("ITEMS_MAX")) / 2

local product = nil
for _, entry in Products.List or Products do
	if typeof(entry) == "table" and entry.id == PACK_ID then
		product = entry
	end
end
assert(product, `no product {PACK_ID}`)
local packCost = product.boxCost / product.unitsPerBox
local buyChance = Pricing.BUY_BANDS[1].chance -- at market price
local profitPerMinute = customersPerMinute * itemsPerCustomer * buyChance * (product.marketPrice - packCost)

-- The cards in packs, by rarity
local byRarity: { [string]: { string } } = {}
for _, row in CardList.SET1 do
	local name, rarity = row[1], row[3]
	byRarity[rarity] = byRarity[rarity] or {}
	table.insert(byRarity[rarity], name)
end

-- Lune has no Random class: math.random, seeded so runs repeat
math.randomseed(1)
local rng = {
	NextNumber = function(_self): number
		return math.random()
	end,
	NextInteger = function(_self, low: number, high: number): number
		return math.random(low, high)
	end,
}

local function rollRarity(slot: { PackOdds.Weighted }): string
	local total = 0
	for _, option in slot do
		total += option.weight
	end
	local roll = rng:NextNumber() * total
	for _, option in slot do
		roll -= option.weight
		if roll <= 0 then
			return option.rarity
		end
	end
	return slot[#slot].rarity
end

type Pull = { card: string, rarity: string, grade: string }

-- One pack, with the player's pity applied like PackService does
local function openPack(state: PityRules.State): ({ Pull }, PityRules.State)
	local pulls: { Pull } = {}
	local best, bestRank = "Common", 0
	for _, slot in PackOdds.SLOTS[PACK_ID] do
		local rarity = rollRarity(slot)
		local pool = byRarity[rarity]
		table.insert(pulls, { card = pool[rng:NextInteger(1, #pool)], rarity = rarity, grade = BeastMath.rollGrade(Beasts, rng:NextNumber(), rarity) })
		local rank = PackOdds.RANK[rarity] or 0
		if rank > bestRank then
			best, bestRank = rarity, rank
		end
	end
	local forced, after = PityRules.open(PackOdds.PITY, PackOdds.RANK, state, best)
	if forced then
		local pool = byRarity[forced]
		local grade = if forced == "Legendary"
			then BeastMath.rollGradeFrom(Beasts, rng:NextNumber(), PackOdds.PITY.LEGENDARY_GRADES)
			else BeastMath.rollGrade(Beasts, rng:NextNumber(), forced)
		pulls[#pulls] = { card = pool[rng:NextInteger(1, #pool)], rarity = forced, grade = grade }
	end
	return pulls, after
end

type Result = { firstEpic: number, firstLegendary: number, luckyS: number, goal: number, goalByGrading: boolean, packs: number }

-- Hours for one player to reach each goal. The goal is a Grade S Legendary with 1 star: by luck (pull an S, then
-- STAR_DUPLICATES more copies of it) or by grading (enough copies of one Legendary to grade it to S and star it, then
-- the grading cash, saved from the shop's profit after the packs stop)
local function simulatePlayer(): Result
	local state: PityRules.State = { legendary = 0, epic = 0, firstDone = false }
	local packsPerHour = math.min(3600 / OPEN_SECONDS, profitPerMinute * 60 / packCost) -- time or cash, whichever runs out first
	local hoursPerPack = 1 / packsPerHour
	local copies: { [string]: { [string]: number } } = {} -- legendary name -> grade -> count
	local result: Result = { firstEpic = MAX_HOURS, firstLegendary = MAX_HOURS, luckyS = MAX_HOURS, goal = MAX_HOURS, goalByGrading = false, packs = 0 }
	local luckyCard: string? = nil
	local done = false -- the goal's time is settled
	local packs = 0
	while packs * hoursPerPack < MAX_HOURS do
		packs += 1
		local now = packs * hoursPerPack
		local pulls
		pulls, state = openPack(state)
		for _, pull in pulls do
			if (pull.rarity == "Epic" or pull.rarity == "Legendary") and result.firstEpic == MAX_HOURS then
				result.firstEpic = now
			end
			if pull.rarity == "Legendary" then
				if result.firstLegendary == MAX_HOURS then
					result.firstLegendary = now
				end
				local owned = copies[pull.card] or {}
				copies[pull.card] = owned
				owned[pull.grade] = (owned[pull.grade] or 0) + 1
				if pull.grade == "S" and not luckyCard then
					luckyCard = pull.card
					result.luckyS = now
				end
			end
		end
		if not done then
			-- Luck: the S copy plus enough duplicates of it for the star
			if luckyCard then
				local total = 0
				for _, count in copies[luckyCard] do
					total += count
				end
				if total >= 1 + STAR_DUPLICATES and now < result.goal then
					result.goal, result.goalByGrading, result.packs = now, false, packs
				end
			end
			-- Grading: the best copy graded up to S, plus the star; the grading cash saved after the packs stop
			for _, owned in copies do
				local total, bestRank, bestGrade = 0, 0, "C"
				for grade, count in owned do
					total += count
					local rank = table.find(Beasts.GRADES, grade) or 0
					if count > 0 and rank > bestRank then
						bestRank, bestGrade = rank, grade
					end
				end
				local toTop = CondenseRules.gradeCostToTop(Grading, Beasts.GRADES, "Legendary", bestGrade)
				if total >= 1 + toTop.copies + STAR_DUPLICATES then
					local finish = now + toTop.cash / (profitPerMinute * 60)
					if finish < result.goal then
						result.goal, result.goalByGrading, result.packs = finish, true, packs
					end
				end
			end
			done = result.goal <= now
		end
		-- Keep opening until the lucky S shows up too, so its time isn't cut short by the goal
		if done and luckyCard then
			return result
		end
	end
	if result.packs == 0 then
		result.packs = packs
	end
	return result
end

local function percentile(values: { number }, p: number): number
	table.sort(values)
	return values[math.max(1, math.ceil(#values * p))]
end

local function hours(value: number): string
	if value >= MAX_HOURS then
		return `>{MAX_HOURS} h`
	end
	return if value < 1 then string.format("%d min", math.floor(value * 60 + 0.5)) else string.format("%.1f h", value)
end

local firstEpic, firstLegendary, luckyS, goal, packsOpened = {}, {}, {}, {}, {}
local byGrading = 0
for _ = 1, PLAYERS do
	local result = simulatePlayer()
	table.insert(firstEpic, result.firstEpic)
	table.insert(firstLegendary, result.firstLegendary)
	table.insert(luckyS, result.luckyS)
	table.insert(goal, result.goal)
	table.insert(packsOpened, result.packs)
	if result.goalByGrading then
		byGrading += 1
	end
end

print(`Economy simulator: {PLAYERS} players, {PACK_ID} only, opening one every {OPEN_SECONDS}s`)
print(string.format("Shop profit: %.1f customers/min x %.1f items x %.0f%% buy x $%.2f = $%.0f an hour", customersPerMinute, itemsPerCustomer, buyChance * 100, product.marketPrice - packCost, profitPerMinute * 60))
print(string.format("Packs opened: %.0f an hour (cash-limited at $%.2f each)", math.min(3600 / OPEN_SECONDS, profitPerMinute * 60 / packCost), packCost))
print("")
print(string.format("%-40s %10s %10s %10s", "Goal", "median", "90% by", "99% by"))
local function row(label: string, values: { number })
	print(string.format("%-40s %10s %10s %10s", label, hours(percentile(values, 0.5)), hours(percentile(values, 0.9)), hours(percentile(values, 0.99))))
end
row("First Epic or better", firstEpic)
row("First Legendary", firstLegendary)
row("A Grade S Legendary pulled (luck only)", luckyS)
row("Grade S Legendary with 1 star", goal)
print(string.format("  reached by grading: %d%% of players; packs opened (median): %d", math.floor(byGrading / PLAYERS * 100 + 0.5), percentile(packsOpened, 0.5)))
