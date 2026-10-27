--!strict
local PityRules = require("../src/shared/Util/PityRules")
local PackOdds = require("../src/shared/Config/PackOdds")
local expect = require("./lib/expect")

local PITY, RANK = PackOdds.PITY, PackOdds.RANK

-- Opens `count` packs with nothing better than `best`; returns the rarities pity raised them to and the final state
local function openMany(state: PityRules.State, count: number, best: string): ({ string }, PityRules.State)
	local forced: { string } = {}
	for _ = 1, count do
		local raised
		raised, state = PityRules.open(PITY, RANK, state, best)
		if raised then
			table.insert(forced, raised)
		end
	end
	return forced, state
end

return {
	["the first Legendary is guaranteed on the 130th pack, and never before"] = function()
		local forced, state = openMany({ legendary = 0, epic = 0, firstDone = false }, PITY.FIRST_LEGENDARY_PACKS - 1, "Very Rare")
		local legendaries = 0
		for _, rarity in forced do
			if rarity == "Legendary" then
				legendaries += 1
			end
		end
		expect.equal(legendaries, 0, "no Legendary before the 130th pack")
		expect.equal(state.legendary, PITY.FIRST_LEGENDARY_PACKS - 1, "counted")
		local raised, after = PityRules.open(PITY, RANK, state, "Common")
		expect.equal(raised, "Legendary", "the 130th pack")
		expect.equal(after.legendary, 0, "reset")
		expect.equal(after.epic, 0, "a Legendary counts as Epic or better")
		expect.equal(after.firstDone, true, "the first Legendary is done")
	end,

	["after the first, a Legendary is guaranteed every 210 packs"] = function()
		assert(PITY.LEGENDARY_PACKS > PITY.FIRST_LEGENDARY_PACKS, "the first guarantee is the shorter one")
		local _, state = openMany({ legendary = 0, epic = 0, firstDone = true }, PITY.FIRST_LEGENDARY_PACKS, "Very Rare")
		expect.equal(state.legendary, PITY.FIRST_LEGENDARY_PACKS, "no pity at 130 once the first is done")
		local forced = openMany({ legendary = 0, epic = 0, firstDone = true }, PITY.LEGENDARY_PACKS, "Very Rare")
		local legendaries = 0
		for _, rarity in forced do
			if rarity == "Legendary" then
				legendaries += 1
			end
		end
		expect.equal(legendaries, 1, "one on the 210th pack")
		local natural = select(2, PityRules.open(PITY, RANK, { legendary = 5, epic = 0, firstDone = false }, "Legendary"))
		expect.equal(natural.firstDone, true, "a lucky first Legendary counts too")
	end,

	["an Epic or better is guaranteed every 40 packs"] = function()
		local forced = openMany({ legendary = 0, epic = 0, firstDone = false }, 120, "Rare")
		expect.equal(#forced, 3, "packs 40, 80 and 120")
		for _, rarity in forced do
			expect.equal(rarity, "Epic", "raised to Epic")
		end
		local _, state = openMany({ legendary = 0, epic = 0, firstDone = false }, PITY.EPIC_PACKS, "Rare")
		expect.equal(state.epic, 0, "the Epic pity resets the Epic count")
		expect.equal(state.legendary, PITY.EPIC_PACKS, "but not the Legendary one")
	end,

	["a lucky pull resets its own count and pity leaves it alone"] = function()
		local raised, state = PityRules.open(PITY, RANK, { legendary = 129, epic = 39, firstDone = false }, "Legendary")
		expect.isNil(raised, "a natural Legendary isn't raised")
		expect.equal(state.legendary, 0, "Legendary reset")
		expect.equal(state.epic, 0, "Epic reset")
		local raisedEpic, afterEpic = PityRules.open(PITY, RANK, { legendary = 10, epic = 39, firstDone = false }, "Epic")
		expect.isNil(raisedEpic, "a natural Epic isn't raised")
		expect.equal(afterEpic.epic, 0, "Epic reset")
		expect.equal(afterEpic.legendary, 11, "the Legendary count keeps going")
	end,

	["when both are due, the Legendary wins"] = function()
		local raised, state = PityRules.open(PITY, RANK, { legendary = 129, epic = 39, firstDone = false }, "Common")
		expect.equal(raised, "Legendary", "Legendary first")
		expect.equal(state.epic, 0, "and it counts for the Epic too")
	end,

	["remaining counts down to the next guarantee, and bad saves start from zero"] = function()
		local legendary, epic = PityRules.remaining(PITY, { legendary = 0, epic = 0, firstDone = false })
		expect.equal(legendary, PITY.FIRST_LEGENDARY_PACKS, "130 to go for the first")
		expect.equal((PityRules.remaining(PITY, { legendary = 0, epic = 0, firstDone = true })), PITY.LEGENDARY_PACKS, "210 after")
		expect.equal(epic, PITY.EPIC_PACKS, "40 to go")
		local nextLegendary = PityRules.remaining(PITY, { legendary = 129, epic = 0, firstDone = false })
		expect.equal(nextLegendary, 1, "the very next pack")
		local state = PityRules.read({ legendary = -3, epic = 0 / 0 })
		expect.equal(state.legendary, 0, "negative")
		expect.equal(state.epic, 0, "NaN")
		expect.equal(PityRules.read(nil).legendary, 0, "missing")
		expect.equal(PityRules.read(nil).firstDone, false, "missing: the first Legendary still to come")
		expect.equal(PityRules.read({ firstDone = true }).firstDone, true, "kept")
	end,

	["the pity Legendary's grade is stingy, and the odds add up"] = function()
		local total = 0
		for _, chance in PITY.LEGENDARY_GRADES do
			total += chance
		end
		expect.near(total, 1, 1e-9, "grade chances add up to 1")
		assert(PITY.LEGENDARY_GRADES.S <= 0.002, "a pity Legendary is almost never Grade S")
		for _, slots in PackOdds.SLOTS do
			for _, slot in slots do
				local sum = 0
				for _, option in slot do
					sum += option.weight
				end
				expect.near(sum, 1, 1e-9, "each slot's weights add up to 1")
			end
		end
		local hit = PackOdds.SLOTS.FirstSparkPack[#PackOdds.SLOTS.FirstSparkPack]
		for _, option in hit do
			if option.rarity == "Legendary" then
				expect.equal(option.weight, 0.01, "First Spark Legendary is 1%")
			end
		end
	end,
}
