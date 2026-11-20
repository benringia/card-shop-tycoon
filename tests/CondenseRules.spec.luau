--!strict
local CondenseRules = require("../src/shared/Util/CondenseRules")
local config = require("../src/shared/Config/Beasts")
local grading = require("../src/shared/Config/Grading")
local expect = require("./lib/expect")

local function counts(normal: number, foil: number)
	return { normal = normal, foil = foil }
end

local function total(takes: { any }): number
	local sum = 0
	for _, take in takes do
		sum += take.count
	end
	return sum
end

local BEAST_STAR0 = { beast = true, foil = false, grade = "S", stars = 0 } -- next star costs 4
local BEAST_STAR1 = { beast = true, foil = false, grade = "S", stars = 1 } -- next star costs 8

return {
	["goldSealAllowed: any step except a Legendary's A to S"] = function()
		expect.equal(CondenseRules.goldSealAllowed("Legendary", "S"), false, "the chase stays paid")
		expect.equal(CondenseRules.goldSealAllowed("Legendary", "A"), true, "B to A is fine")
		expect.equal(CondenseRules.goldSealAllowed("Epic", "S"), true, "other rarities to S")
	end,

	["shards: not used when duplicates are enough"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(4, 0) }, BEAST_STAR0, 10)
		assert(takes, `expected a plan, got {reason}`)
		expect.equal(used, 0, "no shards")
		expect.equal(total(takes), 4, "four duplicates")
	end,

	["shards: cover the shortfall after duplicates"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(5, 0) }, BEAST_STAR1, 3)
		assert(takes, `expected a plan, got {reason}`)
		expect.equal(used, 3, "three shards")
		expect.equal(total(takes), 5, "all five duplicates")
	end,

	["shards: at most half the cost"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(3, 0) }, BEAST_STAR1, 10)
		expect.isNil(takes, "refused")
		expect.equal(reason, "short:3:8", "reason")
		expect.equal(used, 0, "nothing used")
		local ok, _, half = CondenseRules.plan(config, { C = counts(4, 0) }, BEAST_STAR1, 4)
		assert(ok, "4 duplicates + 4 shards is enough")
		expect.equal(half, 4, "half the cost in shards")
	end,

	["shards: nil means no shards"] = function()
		local takes, reason, used = CondenseRules.plan(config, { C = counts(5, 0) }, BEAST_STAR1)
		expect.isNil(takes, "short without shards")
		expect.equal(reason, "short:5:8", "reason")
		expect.equal(used, 0, "zero")
	end,

	["uses normals weakest grade first, then foils"] = function()
		local stacks = { C = counts(2, 1), B = counts(1, 0), S = counts(3, 2) }
		local takes = CondenseRules.plan(config, stacks, { beast = true, foil = false, grade = "S", stars = 1 }) -- needs 8
		assert(takes, "expected a plan")
		expect.equal(total(takes), 8, "total")
		expect.equal(takes[1].grade, "C", "first C")
		expect.equal(takes[1].foil, false, "first normal")
		expect.equal(takes[2].grade, "B", "then B")
		expect.equal(takes[3].grade, "S", "then S normal")
		expect.equal(takes[3].count, 3, "all S normals")
		expect.equal(takes[4].foil, true, "then foils")
		expect.equal(takes[4].grade, "C", "C foil first")
	end,

	["plain main is not a duplicate"] = function()
		local stacks = { C = counts(4, 0) }
		local takes, reason = CondenseRules.plan(config, stacks, { beast = false, foil = false, grade = "C", stars = 0 })
		expect.isNil(takes, "refused")
		expect.equal(reason, "short:3:4", "reason")
		expect.equal(CondenseRules.countDuplicates(stacks, { beast = false, foil = false, grade = "C", stars = 0 }), 3, "count")
		stacks.C.normal = 5
		local ok = CondenseRules.plan(config, stacks, { beast = false, foil = false, grade = "C", stars = 0 })
		assert(ok, "5 copies: main + 4")
		expect.equal(total(ok), 4, "uses 4")
	end,

	["levelled main counts every plain copy"] = function()
		local takes = CondenseRules.plan(config, { A = counts(4, 0) }, { beast = true, foil = false, grade = "A", stars = 0 })
		assert(takes, "expected a plan")
		expect.equal(total(takes), 4, "uses all 4")
	end,

	["max stars refused"] = function()
		local takes, reason = CondenseRules.plan(config, { C = counts(99, 0) }, { beast = true, foil = false, grade = "C", stars = 5 })
		expect.isNil(takes, "refused")
		expect.equal(reason, "max", "reason")
	end,

	["default main: levelled first, then plain foil, then plain normal"] = function()
		local copies = {
			{ key = "plainSfoil", beast = false, foil = true, power = 300 },
			{ key = "plainC", beast = false, foil = false, power = 200 },
			{ key = "lv1", beast = true, foil = false, power = 230 },
			{ key = "lv8", beast = true, foil = false, power = 400 },
			{ key = "plainBfoil", beast = false, foil = true, power = 250 },
		}
		CondenseRules.sortMainChoices(copies)
		local order = {}
		for _, copy in copies do
			table.insert(order, copy.key)
		end
		expect.equal(table.concat(order, ","), "lv8,lv1,plainSfoil,plainBfoil,plainC", "order")
	end,

	["finds the card a plain main became"] = function()
		local before = { old = true }
		local beasts = {
			old = { cardId = "FS30", foil = false, grade = "C" },
			other = { cardId = "FS01", foil = false, grade = "C" },
			wrongGrade = { cardId = "FS30", foil = false, grade = "S" },
			fresh = { cardId = "FS30", foil = false, grade = "C" },
		}
		before.other = true
		before.wrongGrade = true
		expect.equal(CondenseRules.findNewCard(before, beasts, "FS30", false, "C"), "fresh", "new one")
		before.fresh = true
		expect.isNil(CondenseRules.findNewCard(before, beasts, "FS30", false, "C"), "none new")
	end,

	["junk counts are ignored"] = function()
		local stacks: any = { C = { normal = -3, foil = 0 / 0 }, B = "junk", Z = counts(50, 0) }
		local takes, reason = CondenseRules.plan(config, stacks, { beast = true, foil = false, grade = "C", stars = 0 })
		expect.isNil(takes, "unknown grade Z and bad counts don't count")
		expect.equal(reason, "short:0:4", "reason")
	end,
	["grading: the next grade, and none past S"] = function()
		expect.equal(CondenseRules.nextGrade(config.GRADES, "C"), "B", "C")
		expect.equal(CondenseRules.nextGrade(config.GRADES, "A"), "S", "A")
		expect.isNil(CondenseRules.nextGrade(config.GRADES, "S"), "S is the top")
		expect.isNil(CondenseRules.nextGrade(config.GRADES, "Z"), "unknown")
	end,

	["grading: a step costs that rarity's duplicates and cash, taking the weakest copies first"] = function()
		local plainMain = { beast = false, foil = false, grade = "C", stars = 0 }
		-- 3 plain C copies: one is the main, two are duplicates; a Legendary C -> B needs 1
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(3, 0), S = counts(1, 0) }, plainMain)
		assert(plan, `expected a plan, got {reason}`)
		expect.equal(plan.grade, "B", "goes up to B")
		expect.equal(plan.copies, grading.COSTS.Legendary.B.copies, "copies")
		expect.equal(plan.cash, grading.COSTS.Legendary.B.cash, "cash")
		expect.equal(#plan.takes, 1, "one stack")
		expect.equal(plan.takes[1].grade, "C", "a C copy goes before the S")
		expect.equal(total(plan.takes), plan.copies, "takes the copies it costs")
	end,

	["grading: the plain main itself is never a duplicate"] = function()
		local plainMain = { beast = false, foil = false, grade = "C", stars = 0 }
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(1, 0) }, plainMain)
		expect.isNil(plan, "only the main")
		expect.equal(reason, "short:0:1", "reason")
	end,

	["grading: short of duplicates, already S, or an unknown rarity"] = function()
		local beastA = { beast = true, foil = false, grade = "A", stars = 2 }
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(2, 0) }, beastA)
		expect.isNil(plan, "A -> S needs 3")
		expect.equal(reason, "short:2:3", "short")
		local _, maxed = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(9, 0) }, { beast = true, foil = false, grade = "S", stars = 0 })
		expect.equal(maxed, "max", "S can't go higher")
		local _, unknown = CondenseRules.gradePlan(grading, config, "Mythic", { C = counts(9, 0) }, beastA)
		expect.equal(unknown, "unknown", "no costs for that rarity")
	end,

	["grading: costs rise with each step, Legendary C to S 6 copies and $15,500"] = function()
		for rarity, steps in grading.COSTS do
			assert(steps.B.cash < steps.A.cash and steps.A.cash < steps.S.cash, `{rarity} cash doesn't rise`)
			assert(steps.B.copies <= steps.A.copies and steps.A.copies <= steps.S.copies, `{rarity} copies don't rise`)
		end
		assert(grading.COSTS.Legendary.S.cash >= 12500, "Legendary A -> S costs at least $12,500")
		local top = CondenseRules.gradeCostToTop(grading, config.GRADES, "Legendary", "C")
		expect.equal(top.copies, 6, "copies C to S")
		expect.equal(top.cash, 15500, "cash C to S")
		local fromS = CondenseRules.gradeCostToTop(grading, config.GRADES, "Legendary", "S")
		expect.equal(fromS.copies, 0, "nothing past S")
	end,
	["grading seals cover missing duplicates, at most half a step"] = function()
		local beastA = { beast = true, foil = false, grade = "A", stars = 0 }
		-- Legendary A -> S needs 3 duplicates; half of 3, rounded down, is 1
		local plan, reason = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(2, 0) }, beastA, 5)
		assert(plan, `expected a plan, got {reason}`)
		expect.equal(plan.seals, 1, "one seal fills the gap")
		expect.equal(total(plan.takes), 2, "the two real duplicates go first")
		local none, short = CondenseRules.gradePlan(grading, config, "Legendary", {}, beastA, 5)
		expect.isNil(none, "seals can't cover more than half a step")
		expect.equal(short, "short:0:3", "reason")
		local enough = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(3, 0) }, beastA, 5)
		assert(enough, "a plan")
		expect.equal(enough.seals, 0, "no seals when the duplicates are enough")
		local without = CondenseRules.gradePlan(grading, config, "Legendary", { C = counts(3, 0) }, beastA)
		assert(without, "a plan")
		expect.equal(without.seals, 0, "no seals given")
	end,

	-- Owner 2026-11-20: "the card condenser is currently very confusing. make it better/easily understandable": the row
	-- says what you have and what a star uses in plain words ("x21 · 4 copies for the next star" before)
	["row line when ready"] = function()
		local text, share = CondenseRules.rowLine(21, 4, 4, true)
		expect.equal(text, "You have 21 copies · a star uses 4", "text")
		expect.equal(share, 1, "bar full")
	end,

	["row line while raising"] = function()
		local text, share = CondenseRules.rowLine(3, 3, 4, false)
		expect.equal(text, "3 of 4 copies for the next star", "text")
		expect.equal(share, 0.75, "bar")
	end,

	["the big button says what it does and how long it takes, or what's missing"] = function()
		expect.equal(CondenseRules.buttonWords(true, nil, "2:00", false), "Add a star · takes 2:00")
		expect.equal(CondenseRules.buttonWords(true, nil, "2:00", true), "Putting it in...", "waiting for the server")
		expect.equal(CondenseRules.buttonWords(false, "max", "2:00", false), "Max stars reached")
		expect.equal(CondenseRules.buttonWords(false, "short:2:4", "2:00", false), "Need 4 extra copies (you have 2)")
		expect.equal(CondenseRules.buttonWords(false, "working", "2:00", false), "This copy can't go in now")
		expect.equal(CondenseRules.buttonWords(false, nil, "2:00", false), "This copy can't go in now")
	end,

	-- Owner 2026-11-20: "after the timer than condenser just do nothing. I just got a toast notification. I need a
	-- better notification inside the condenser after the timer is done, that is waiting for me to reopen the
	-- condenser": the finished card's new star waits (a player attribute) until they open the Condenser and take it out
	["a finished star waits to be shown: its card round trips, junk is nothing"] = function()
		local value = CondenseRules.encodeDone({ cardId = "FS27", foil = true, grade = "S", level = 30, stars = 3 })
		local done = CondenseRules.decodeDone(value)
		assert(done, "read back")
		expect.equal(done.cardId, "FS27")
		expect.equal(done.foil, true)
		expect.equal(done.grade, "S")
		expect.equal(done.level, 30)
		expect.equal(done.stars, 3)
		local plain = CondenseRules.decodeDone(CondenseRules.encodeDone({ cardId = "FS1", foil = false, grade = "C", level = 1, stars = 1 }))
		expect.equal((plain :: any).foil, false)
		expect.isNil(CondenseRules.decodeDone(nil))
		expect.isNil(CondenseRules.decodeDone(""))
		expect.isNil(CondenseRules.decodeDone("FS27|1|S|x|3"))
		expect.isNil(CondenseRules.decodeDone("FS27|1|Z|30|3"), "a grade that isn't one")
		expect.isNil(CondenseRules.decodeDone("FS27|1|S|30|0"), "no star to show")
		expect.isNil(CondenseRules.decodeDone(12))
	end,

	-- Owner 2026-11-20 (the same day, on the first rewrite): "this part needs to be better/easily understandable with
	-- no '->'": the chosen card's side says things in whole words and shows Now beside After
	["the reveal's words: how many stars it has now, never an arrow"] = function()
		expect.equal(CondenseRules.doneLine(3), "Now 3 stars!")
		expect.equal(CondenseRules.doneLine(1), "Now 1 star!")
		expect.equal(CondenseRules.doneLine(5), "Now 5 stars: the most!")
	end,

	["under the stars: which star this adds"] = function()
		expect.equal(CondenseRules.starWords(0, 5), "Adds star 1 of 5")
		expect.equal(CondenseRules.starWords(3, 5), "Adds star 4 of 5")
		expect.equal(CondenseRules.starWords(5, 5), "Has all 5 stars")
		expect.equal(CondenseRules.starWords(7, 5), "Has all 5 stars")
	end,

	["the box under the card: which copy gets the star, and which are used up"] = function()
		local stays, used = CondenseRules.keepWords("Grade S", 1, "3 Grade C + 1 Grade B")
		expect.equal(stays, "Gets the star: your Grade S · Lv 1 copy")
		expect.equal(used, "Used up: 3 Grade C + 1 Grade B")
		local only, none = CondenseRules.keepWords("Grade C", 12, nil)
		expect.equal(only, "Gets the star: your Grade C · Lv 12 copy")
		expect.isNil(none, "nothing to use yet: one line")
	end,

	["how much a number grows, for the After column"] = function()
		expect.equal(CondenseRules.gain(320, 371), "+51")
		expect.equal(CondenseRules.gain(1474, 1645), "+171")
		expect.equal(CondenseRules.gain(100, 100), "")
		expect.equal(CondenseRules.gain(100, 90), "", "never a loss shown")
	end,

	-- Owner 2026-11-20: "also check the other machines(forge,grading maching) for pain points/ confusing elements":
	-- the Grading Station said "Owned 7 · C -> B: 3 + $5" and "Grade C -> B / Power 320 -> 371" in one block of text,
	-- and its timer ended in a toast like the Condenser's
	["the Grading Station's row: what you have and what the next grade uses"] = function()
		expect.equal(CondenseRules.gradeRowLine(7, "B", 3, "$5.00"), "You have 7 copies · Grade B uses 3 + $5.00")
		expect.equal(CondenseRules.gradeRowLine(1, "A", 1, "$40.00"), "You have 1 copy · Grade A uses 1 + $40.00")
		expect.equal(CondenseRules.gradeRowLine(4, nil, 0, ""), "You have 4 copies · Grade S: the best")
	end,

	["the Grading Station's button: what it makes, its price and its wait, or what's missing"] = function()
		local base = { inFlight = false, grade = "B", cash = "$5.00", have = "$2.00", affordable = true, gold = false, clock = "1:00", reason = nil }
		local function with(changes: { [string]: any }): any
			local copy = table.clone(base)
			for key, value in changes do
				(copy :: any)[key] = value
			end
			return copy
		end
		expect.equal(CondenseRules.gradeButtonWords(base), "Make it Grade B · $5.00 · takes 1:00")
		expect.equal(CondenseRules.gradeButtonWords(with({ gold = true })), "Make it Grade B · Gold Seal pays · takes 1:00")
		expect.equal(CondenseRules.gradeButtonWords(with({ affordable = false })), "Need $5.00 (you have $2.00)")
		expect.equal(CondenseRules.gradeButtonWords(with({ inFlight = true })), "Putting it in...")
		expect.equal(CondenseRules.gradeButtonWords(with({ grade = false, reason = "max" })), "Already Grade S")
		expect.equal(CondenseRules.gradeButtonWords(with({ grade = false, reason = "short:1:3" })), "Need 3 extra copies (you have 1)")
		expect.equal(CondenseRules.gradeButtonWords(with({ grade = false, reason = "working" })), "This copy can't go in now")
	end,

	["a finished grade waits like a finished star: plain copies have no stars, and the reveal says the grade"] = function()
		local value = CondenseRules.encodeDone({ cardId = "FS35", foil = false, grade = "B", level = 1, stars = 0 })
		expect.isNil(CondenseRules.decodeDone(value), "the Condenser's needs a star")
		local done = CondenseRules.decodeDone(value, 0)
		assert(done, "the Grading Station's doesn't")
		expect.equal(done.grade, "B")
		expect.equal(done.stars, 0)
		expect.equal(CondenseRules.gradeDoneLine("B"), "Now Grade B!")
		expect.equal(CondenseRules.gradeDoneLine("S"), "Now Grade S: the best!")
		expect.equal(CondenseRules.gradeBefore("B"), "C")
		expect.equal(CondenseRules.gradeBefore("A"), "B")
		expect.equal(CondenseRules.gradeBefore("S"), "A")
		expect.isNil(CondenseRules.gradeBefore("C"), "nothing under C")
		expect.equal(CondenseRules.gradeWords("C", "B"), "Makes it Grade B")
		expect.equal(CondenseRules.gradeWords("S", nil), "Grade S: the best it can be")
		local stays, used = CondenseRules.keepWords("Grade C", 1, "3 Grade C + $5.00", "grade")
		expect.equal(stays, "Gets the grade: your Grade C · Lv 1 copy")
		expect.equal(used, "Used up: 3 Grade C + $5.00")
	end,

	["none of the Condenser's words use an arrow"] = function()
		local lines = {
			CondenseRules.doneLine(1),
			CondenseRules.doneLine(5),
			CondenseRules.starWords(0, 5),
			CondenseRules.starWords(5, 5),
			CondenseRules.buttonWords(true, nil, "0:30", false),
			CondenseRules.buttonWords(false, "short:2:4", "0:30", false),
			(CondenseRules.rowLine(7, 4, 4, true)),
			(CondenseRules.rowLine(3, 3, 4, false)),
			(CondenseRules.keepWords("Grade S", 1, "3 Grade C")),
			CondenseRules.gradeRowLine(7, "B", 3, "$5.00"),
			CondenseRules.gradeRowLine(7, nil, 0, ""),
			CondenseRules.gradeDoneLine("B"),
			CondenseRules.gradeWords("C", "B"),
			CondenseRules.gradeButtonWords({ inFlight = false, grade = "B", cash = "$5.00", have = "$2.00", affordable = true, gold = false, clock = "1:00" }),
		}
		for _, text in lines do
			assert(not string.find(text, "->", 1, true) and not string.find(text, ">", 1, true), `no arrow in "{text}"`)
		end
	end,

	["row line at max stars"] = function()
		local text, share = CondenseRules.rowLine(5, 0, 0, false)
		expect.equal(text, "Max stars", "text")
		expect.equal(share, 1, "bar full")
	end,
}
