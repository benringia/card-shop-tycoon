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

	-- owner 2026-11-21: "sort by grade" (a foil Grade C stood before a plain Grade A)
	["default copy: levelled cards first, then plain ones; in each the best grade first, a foil before a plain of its grade"] = function()
		local copies = {
			{ key = "foilC", beast = false, foil = true, grade = "C", power = 311 },
			{ key = "plainA", beast = false, foil = false, grade = "A", power = 312 },
			{ key = "plainB", beast = false, foil = false, grade = "B", power = 304 },
			{ key = "plainC", beast = false, foil = false, grade = "C", power = 295 },
			{ key = "foilA", beast = false, foil = true, grade = "A", power = 330 },
			{ key = "lvB", beast = true, foil = false, grade = "B", power = 900 },
			{ key = "lvS", beast = true, foil = false, grade = "S", power = 400 },
			{ key = "lvSweak", beast = true, foil = false, grade = "S", power = 380 },
		}
		CondenseRules.sortMainChoices(copies)
		local order = {}
		for _, copy in copies do
			table.insert(order, copy.key)
		end
		expect.equal(table.concat(order, ","), "lvS,lvSweak,lvB,foilA,plainA,plainB,foilC,plainC", "order")
	end,

	-- owner 2026-11-21: "condenser never uses better copies"
	["a star never uses up a copy better than the card that gets it"] = function()
		local pal = { beast = true, foil = false, grade = "B", stars = 0 } -- needs 4
		local takes = CondenseRules.plan(config, { C = counts(2, 1), B = counts(1, 0), A = counts(3, 0), S = counts(5, 5) }, pal)
		assert(takes, "C, C, B and the foil C")
		expect.equal(total(takes), 4)
		for _, take in takes do
			assert(take.grade == "C" or take.grade == "B", `never a Grade {take.grade}`)
		end
		-- not enough without the better ones: short, however many of those there are
		local none, reason = CondenseRules.plan(config, { C = counts(2, 0), B = counts(1, 0), S = counts(9, 0) }, pal)
		expect.isNil(none)
		expect.equal(reason, "short:3:4")
		expect.equal(CondenseRules.countDuplicates({ C = counts(2, 0), B = counts(1, 0), S = counts(9, 0) }, pal, config), 3)
		-- Star Shards fill only what the usable copies leave
		local withShards, _, used = CondenseRules.plan(config, { C = counts(2, 0), B = counts(1, 0), S = counts(9, 0) }, pal, 10)
		assert(withShards, "3 copies and a shard")
		expect.equal(used, 1)
		expect.equal(total(withShards), 3)
		-- a plain Grade A kept: its own grade's other copies and the ones under it
		local plain = { beast = false, foil = false, grade = "A", stars = 0 }
		expect.equal(CondenseRules.countDuplicates({ C = counts(1, 0), A = counts(3, 0), S = counts(2, 0) }, plain, config), 3)
		-- the better copies left alone, to say so
		expect.equal(CondenseRules.betterCopies({ C = counts(2, 0), B = counts(1, 0), A = counts(1, 1), S = counts(9, 0) }, pal, config), 11)
		expect.equal(CondenseRules.betterCopies({ C = counts(2, 0) }, pal, config), 0)
		expect.equal(CondenseRules.betterCopies({ S = counts(3, 0) }, { beast = false, foil = false, grade = "S", stars = 0 }, config), 0)
	end,

	-- owner 2026-11-21: "Keep a different card is so confusing. can we change wording or anything to make it more
	-- understandable. also the next window make it more understandable": a chip that says what it does, and the copies
	-- as pictures with plain words
	["the copy picker in plain words"] = function()
		local say, small = CondenseRules.pickSay("Tidecaller", "star")
		expect.equal(say, "Which Tidecaller gets the star?")
		expect.equal(small, "Tap the one you want. Better ones are never used up.")
		say = CondenseRules.pickSay("Tidecaller", "grade")
		expect.equal(say, "Which Tidecaller gets the grade?")
		-- under a copy's picture: what it is in a few words (a foil wears its own tag on the picture)
		expect.equal(CondenseRules.copyLabel({ beast = false, level = 1, count = 2 }), "You have 2")
		expect.equal(CondenseRules.copyLabel({ beast = false, level = 1, count = 1 }), "You have 1")
		expect.equal(CondenseRules.copyLabel({ beast = true, level = 12, count = 1 }), "Lv 12")
		-- the line about better copies left out, only when there are some
		expect.isNil(CondenseRules.safeWords(0))
		-- (owner 2026-11-26: "change "Squish" to "Combine"": no squishing in the words)
		expect.equal(CondenseRules.safeWords(1), "Your 1 better copy stays safe: it is never used up.")
		expect.equal(CondenseRules.safeWords(3), "Your 3 better copies stay safe: they are never used up.")
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

	["how much a number grows, for the After column"] = function()
		expect.equal(CondenseRules.gain(320, 371), "+51")
		expect.equal(CondenseRules.gain(1474, 1645), "+171")
		expect.equal(CondenseRules.gain(100, 100), "")
		expect.equal(CondenseRules.gain(100, 90), "", "never a loss shown")
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
	end,

	["none of the Condenser's words use an arrow"] = function()
		local lines = {
			CondenseRules.doneLine(1),
			CondenseRules.doneLine(5),
			(CondenseRules.buttonWords({ ready = true, inFlight = false, max = false, missing = 0, seconds = 30 })),
			(CondenseRules.buttonWords({ ready = false, inFlight = false, max = false, missing = 2, seconds = 30 })),
			(CondenseRules.rowTag(4, 4, true)),
			(CondenseRules.rowTag(3, 4, false)),
			CondenseRules.say({ name = "Reefray", copies = 4, shards = 0, missing = 0, max = false, maxStars = 5 }),
			CondenseRules.say({ name = "Reefray", copies = 2, shards = 0, missing = 2, max = false, maxStars = 5 }),
			CondenseRules.gradeSay({ name = "Voidmaw", grade = "A", copies = 2, seals = 0, missing = 0 }),
			CondenseRules.gradeSay({ name = "Voidmaw", grade = nil, copies = 0, seals = 0, missing = 0 }),
			(CondenseRules.gradeRowTag(1, 3, "B", false, true)),
			CondenseRules.gradeDoneLine("B"),
			(CondenseRules.gradeButton({ inFlight = false, grade = "B", cash = "$5", have = "$2", affordable = true, missing = 0, seconds = 60, gold = false })),
			CondenseRules.fillChip(4) :: string,
		}
		for _, text in lines do
			assert(not string.find(text, "->", 1, true) and not string.find(text, ">", 1, true), `no arrow in "{text}"`)
		end
	end,

	-- owner 2026-11-26: "the first tab is now "Condense" or something where the players put the card they want to
	-- condense. the condenser then autofills the extra cards(weakest)": a chip over the recipe says so
	["the Condenser says it filled in your weakest extras for you"] = function()
		expect.equal(CondenseRules.fillChip(4), "Filled in for you: your 4 weakest extras")
		expect.equal(CondenseRules.fillChip(1), "Filled in for you: your weakest extra")
		expect.isNil(CondenseRules.fillChip(0), "nothing filled in: no chip")
	end,

	-- owner 2026-11-20, of the Condenser's window: "make this window easier to understand and more immersive. a kid
	-- wouldnt understand this" (pick A, the recipe: the copies used, an arrow, the card with its new star; one plain
	-- sentence; no Value, no grade talk; Star Shards tapped into empty spots)
	["one plain sentence says what will happen"] = function()
		local function say(copies: number, shards: number, missing: number, max: boolean?): string
			return CondenseRules.say({ name = "Reefray", copies = copies, shards = shards, missing = missing, max = max == true, maxStars = 5 })
		end
		-- owner 2026-11-26: "change "Squish" to "Combine""
		expect.equal(say(4, 0, 0), "Combine 4 extra Reefray into this one. It gets a star!")
		expect.equal(say(1, 0, 0), "Combine 1 extra Reefray into this one. It gets a star!")
		expect.equal(say(2, 2, 0), "Combine 2 extra Reefray and 2 Star Shards into this one. It gets a star!")
		expect.equal(say(3, 1, 0), "Combine 3 extra Reefray and 1 Star Shard into this one. It gets a star!")
		expect.equal(say(2, 0, 2), "Find 2 more Reefray to add a star.")
		expect.equal(say(3, 0, 1), "Find 1 more Reefray to add a star.")
		expect.equal(say(0, 0, 0, true), "Reefray has all 5 stars!")
		for _, text in { say(4, 0, 0), say(12, 12, 0), say(2, 0, 22), say(0, 0, 0, true) } do
			assert(not string.find(text, "Value", 1, true) and not string.find(text, "Grade", 1, true), `no value or grade talk: {text}`)
			assert(not string.find(text, "[^\32-\126]"), `plain ASCII: {text}`)
			assert(#text <= 90, `short: {text}`)
		end
	end,

	["a row's tag: Ready!, how many more, or all stars"] = function()
		expect.equal(select(1, CondenseRules.rowTag(4, 4, true)), "Ready!")
		expect.equal(select(2, CondenseRules.rowTag(4, 4, true)), "ready")
		expect.equal(select(1, CondenseRules.rowTag(1, 4, false)), "3 more")
		expect.equal(select(2, CondenseRules.rowTag(1, 4, false)), "wait")
		expect.equal(select(3, CondenseRules.rowTag(1, 4, false)), 0.25, "its bar")
		expect.equal(select(1, CondenseRules.rowTag(0, 0, false)), "All stars")
		expect.equal(select(2, CondenseRules.rowTag(0, 0, false)), "max")
		expect.equal(select(1, CondenseRules.rowTag(2, 4, true)), "Ready!", "ready with Star Shards filling in")
	end,

	["how long it takes, in words"] = function()
		expect.equal(CondenseRules.waitWords(23), "23 seconds")
		expect.equal(CondenseRules.waitWords(1), "1 second")
		expect.equal(CondenseRules.waitWords(60), "1 minute")
		expect.equal(CondenseRules.waitWords(90), "2 minutes", "part minutes round up")
		expect.equal(CondenseRules.waitWords(1800), "30 minutes")
		expect.equal(CondenseRules.waitWords(3600), "1 hour")
		expect.equal(CondenseRules.waitWords(5400), "1 hour 30 minutes")
		expect.equal(CondenseRules.waitWords(7200), "2 hours")
		expect.equal(CondenseRules.waitWords(0), "1 second")
	end,

	["the big button: what it does and how long it takes, or what is missing"] = function()
		local function words(view: any): (string, string?)
			return CondenseRules.buttonWords(view)
		end
		local text, sub = words({ ready = true, inFlight = false, max = false, missing = 0, seconds = 23 })
		expect.equal(text, "Add a star!")
		expect.equal(sub, "takes 23 seconds")
		expect.equal((words({ ready = true, inFlight = true, max = false, missing = 0, seconds = 23 })), "Putting it in...")
		expect.equal((words({ ready = false, inFlight = false, max = true, missing = 0, seconds = 0 })), "All stars!")
		expect.equal((words({ ready = false, inFlight = false, max = false, missing = 2, seconds = 0 })), "2 more copies needed")
		expect.equal((words({ ready = false, inFlight = false, max = false, missing = 1, seconds = 0 })), "1 more copy needed")
		expect.equal((words({ ready = false, inFlight = false, max = false, missing = 0, seconds = 0 })), "This copy can't go in now")
		expect.isNil(select(2, words({ ready = false, inFlight = false, max = false, missing = 2, seconds = 0 })), "no time under a button that does nothing")
	end,

	["the recipe's spots: copies first, then Star Shards, then spots a shard could fill, then empty ones"] = function()
		local function kinds(need: number, copies: number, shards: number, offers: number): string
			return table.concat(CondenseRules.slots(need, copies, shards, offers), " ")
		end
		expect.equal(kinds(4, 4, 0, 0), "copy copy copy copy")
		expect.equal(kinds(4, 2, 2, 0), "copy copy shard shard")
		expect.equal(kinds(4, 2, 0, 2), "copy copy offer offer")
		expect.equal(kinds(4, 1, 0, 2), "copy offer offer empty")
		expect.equal(kinds(4, 0, 0, 0), "empty empty empty empty")
		expect.equal(#CondenseRules.slots(24, 30, 9, 9), 24, "never more spots than the star needs")
		expect.equal(kinds(4, 9, 0, 0), "copy copy copy copy")
	end,

	["how many empty spots offer a Star Shard: only with the shards off, never more than half a star"] = function()
		expect.equal(CondenseRules.shardOffers(4, 2, 12, 0.5, false), 2)
		expect.equal(CondenseRules.shardOffers(4, 1, 12, 0.5, false), 2, "half of the star at most")
		expect.equal(CondenseRules.shardOffers(4, 3, 12, 0.5, false), 1, "only what's missing")
		expect.equal(CondenseRules.shardOffers(4, 2, 1, 0.5, false), 1, "only the shards you have")
		expect.equal(CondenseRules.shardOffers(4, 4, 12, 0.5, false), 0, "nothing missing")
		expect.equal(CondenseRules.shardOffers(4, 2, 12, 0.5, true), 0, "already on: they show as shards")
		expect.equal(CondenseRules.shardOffers(4, 2, 0, 0.5, false), 0)
	end,

	-- the wider recipe of the put-a-card-in windows (owner 2026-11-26): a few copies stand in one row, like the mockup
	["the spots sit in a neat grid whatever the star or the grade costs"] = function()
		local Beasts = require("../src/shared/Config/Beasts")
		local Grading = require("../src/shared/Config/Grading")
		local needs: { number } = table.clone(Beasts.STAR_COSTS)
		for _, steps in Grading.COSTS do
			for _, step in steps do
				table.insert(needs, step.copies)
			end
		end
		for _, need in needs do
			local columns = CondenseRules.slotColumns(need)
			expect.equal(need % columns, 0, `{need} spots fill their rows`)
			assert(need / columns <= 3, `{need} spots: no more than 3 rows`)
			assert(columns <= 8, `{need} spots: no more than 8 across`)
		end
		expect.equal(CondenseRules.slotColumns(4), 4, "a first star's 4 copies in one row")
		expect.equal(CondenseRules.slotColumns(2), 2)
		expect.equal(CondenseRules.slotColumns(8), 4)
		expect.equal(CondenseRules.slotColumns(24), 8)
	end,

	["under the spots: what a tap does with Star Shards"] = function()
		local function words(view: any): string?
			return CondenseRules.shardWords(view)
		end
		expect.isNil(words({ have = 0, on = false, used = 0, offers = 0, could = false, missing = 2, max = false }), "no shards: nothing to say")
		expect.isNil(words({ have = 5, on = false, used = 0, offers = 0, could = false, missing = 0, max = false }), "nothing missing")
		expect.isNil(words({ have = 5, on = true, used = 0, offers = 0, could = false, missing = 0, max = true }), "max stars")
		expect.equal(words({ have = 5, on = false, used = 0, offers = 2, could = true, missing = 2, max = false }), "Tap an empty spot: Star Shards finish this star! (5 left)")
		expect.equal(words({ have = 5, on = false, used = 0, offers = 2, could = false, missing = 3, max = false }), "Tap an empty spot to use a Star Shard (5 left)")
		expect.equal(words({ have = 5, on = true, used = 2, offers = 0, could = false, missing = 0, max = false }), "Using 2 Star Shards. Tap one to take them out.")
		expect.equal(words({ have = 5, on = true, used = 1, offers = 0, could = false, missing = 0, max = false }), "Using 1 Star Shard. Tap it to take it out.")
		expect.equal(words({ have = 5, on = true, used = 2, offers = 0, could = false, missing = 1, max = false }), "Star Shards are in, but you still need 1 more copy.")
		expect.isNil(words({ have = 5, on = true, used = 0, offers = 0, could = false, missing = 0, max = false }), "on, and none needed")
	end,

	-- owner 2026-11-26: the grade swap and "Keep a different copy" left the Grading Station with its redesign ("drop
	-- both"): nothing in the rules offers a swap any more
	["the grade swap is gone"] = function()
		expect.isNil((CondenseRules :: any).swapPlan)
		expect.isNil((CondenseRules :: any).swapWords)
		expect.isNil((CondenseRules :: any).swapLine)
		expect.isNil((require("../src/shared/Config/Grading") :: any).SWAP)
	end,

	-- owner 2026-11-20: "yes skip better copies": a grade-up listed the player's Grade S spare among the copies it
	-- would use up ("Used up: 1 Grade B + 1 Grade S") for a step to Grade B. A copy better than the card being graded
	-- is never a duplicate (it is worth swapping in, or keeping)
	["grading never uses up a copy better than the card being graded"] = function()
		local main = { beast = true, foil = false, grade = "C", stars = 1 }
		-- a Very Rare C to B needs 2 copies: one B and one S spare are both better than the card
		local none, why = CondenseRules.gradePlan(grading, config, "Very Rare", { B = counts(1, 0), S = counts(1, 0) }, main)
		expect.isNil(none, "no plan from better copies")
		expect.equal(why, "short:0:2")
		-- with two C copies there too, those go in and the better ones stay
		local plan = CondenseRules.gradePlan(grading, config, "Very Rare", { C = counts(2, 0), B = counts(1, 0), S = counts(1, 0) }, main)
		assert(plan, "two Grade C copies are enough")
		expect.equal(total(plan.takes), 2)
		for _, take in plan.takes do
			expect.equal(take.grade, "C", "only copies no better than the card")
		end
		-- a Grade B card may use C and B copies, never A or S
		local better = { beast = true, foil = false, grade = "B", stars = 0 }
		local toA = CondenseRules.gradePlan(grading, config, "Very Rare", { C = counts(1, 0), B = counts(2, 0), A = counts(5, 0), S = counts(5, 0) }, better)
		assert(toA, "C and B copies cover a Very Rare's 3")
		for _, take in toA.takes do
			assert(take.grade == "C" or take.grade == "B", `a Grade {take.grade} copy used up`)
		end
		-- seals fill in for the copies that are missing, as before
		local sealed = CondenseRules.gradePlan(grading, config, "Very Rare", { C = counts(1, 0), S = counts(3, 0) }, main, 5)
		assert(sealed, "one copy and one seal")
		expect.equal(sealed.seals, 1)
		expect.equal(total(sealed.takes), 1)
	end,

	["the Condenser leaves better copies alone too (since 2026-11-21)"] = function()
		local main = { beast = true, foil = false, grade = "C", stars = 0 }
		expect.equal(CondenseRules.countDuplicates({ C = counts(1, 0), S = counts(3, 0) }, main, config), 1)
		expect.equal(CondenseRules.countDuplicates({ C = counts(1, 0), S = counts(3, 0) }, main), 1, "the card view's count, with no config")
	end,

	-- owner 2026-11-20: "in grading station window. redesign it like the condenser to be easily understood. it's
	-- currently so confusing": the same picture recipe (the copies and the cash that go in, an arrow, the card with its
	-- new grade), one sentence, one button
	-- owner 2026-11-26: "change "Make it Grade A" to "Upgrade" then the cost. remove the cost anywhere else": the
	-- sentence says what goes in, never the cash
	["grading: one plain sentence says what will happen"] = function()
		local function say(grade: string?, copies: number, seals: number, missing: number): string
			return CondenseRules.gradeSay({ name = "Voidmaw", grade = grade, copies = copies, seals = seals, missing = missing })
		end
		expect.equal(say("A", 2, 0, 0), "Use 2 extra Voidmaw to make it Grade A!")
		expect.equal(say("A", 1, 1, 0), "Use 1 extra Voidmaw and 1 Grading Seal to make it Grade A!")
		expect.equal(say("B", 0, 2, 0), "Use 2 Grading Seals to make it Grade B!")
		expect.equal(say("A", 1, 0, 1), "Find 1 more Voidmaw to make it Grade A.")
		expect.equal(say(nil, 0, 0, 0), "Voidmaw is Grade S: the best!")
		for _, text in { say("A", 8, 4, 0), say("S", 1, 0, 7), say(nil, 0, 0, 0), say("A", 2, 0, 0), say("B", 0, 2, 0) } do
			assert(#text <= 90 and not string.find(text, "[^\32-\126]"), text)
			assert(not string.find(text, "$", 1, true) and not string.find(text, "cash", 1, true), `no cost in the sentence: {text}`)
		end
	end,

	["grading: a row's tag"] = function()
		local function tag(have: number, need: number, grade: string?, ready: boolean, cashOk: boolean): (string, string, number)
			return CondenseRules.gradeRowTag(have, need, grade, ready, cashOk)
		end
		expect.equal(select(1, tag(2, 2, "A", true, true)), "Ready!")
		expect.equal(select(2, tag(2, 2, "A", true, true)), "ready")
		expect.equal(select(1, tag(1, 3, "B", false, true)), "2 more")
		expect.equal(select(2, tag(1, 3, "B", false, true)), "wait")
		expect.near(select(3, tag(1, 3, "B", false, true)), 1 / 3, 1e-9)
		expect.equal(select(1, tag(2, 2, "A", false, false)), "Need cash", "the copies are there, the cash isn't")
		expect.equal(select(2, tag(2, 2, "A", false, false)), "cash")
		expect.equal(select(1, tag(0, 0, nil, false, true)), "Top grade")
		expect.equal(select(2, tag(0, 0, nil, false, true)), "max")
	end,

	-- the button is "Upgrade" then the cost, the only place the cost shows; its small line says how long, or what's
	-- missing
	["grading: the big button and the small line under it"] = function()
		local function words(view: any): (string, string?)
			return CondenseRules.gradeButton(view)
		end
		local base = { inFlight = false, grade = "A", cash = "$2,500", have = "$9,000", affordable = true, missing = 0, seconds = 3600, gold = false }
		local function with(changes: any): any
			local view = table.clone(base)
			for key, value in changes do
				view[key] = value
			end
			return view
		end
		local text, sub = words(base)
		expect.equal(text, "Upgrade $2,500")
		expect.equal(sub, "takes 1 hour")
		expect.equal((words(with({ inFlight = true }))), "Putting it in...")
		expect.equal((words(with({ grade = false }))), "Top grade!")
		text, sub = words(with({ missing = 2 }))
		expect.equal(text, "Upgrade $2,500", "the cost stays on the button")
		expect.equal(sub, "2 more copies needed")
		expect.equal(select(2, words(with({ missing = 1 }))), "1 more copy needed")
		text, sub = words(with({ affordable = false, have = "$900" }))
		expect.equal(text, "Upgrade $2,500")
		expect.equal(sub, "you have $900")
		text, sub = words(with({ gold = true }))
		expect.equal(text, "Upgrade with a Gold Seal", "a Gold Seal pays instead of the cash")
		expect.equal(sub, "takes 1 hour")
	end,

	-- the USE row's first tile: the copies that go in, picked for you
	["grading: the copies tile"] = function()
		local title, sub = CondenseRules.copiesTile(2)
		expect.equal(title, "2 extra copies")
		expect.equal(sub, "Your weakest, picked for you")
		expect.equal((CondenseRules.copiesTile(1)), "1 extra copy")
		title, sub = CondenseRules.copiesTile(0)
		expect.equal(title, "No extra copies")
		expect.equal(sub, "Find more of this card")
	end,

	["the Condenser's line for Star Shards: a tap on an empty spot uses them"] = function()
		expect.equal(CondenseRules.shardWords({ have = 5, on = false, used = 0, offers = 2, could = true, missing = 2, max = false }), "Tap an empty spot: Star Shards finish this star! (5 left)")
		expect.isNil(CondenseRules.shardWords({ have = 0, on = false, used = 0, offers = 0, could = false, missing = 2, max = false }))
	end,

	-- owner 2026-11-26: the Condenser's tabs "Condense" and Ready, the Grading Station's "Upgrade" and Ready ("Ready is
	-- fine"); every line short and plain
	["the put-a-card-in windows' words"] = function()
		local Grading = require("../src/shared/Config/Grading")
		local Condenser = require("../src/shared/Config/Condenser")
		expect.equal(table.concat(Condenser.WINDOW.TABS, ","), "Condense,Ready")
		expect.equal(table.concat(Grading.WINDOW.TABS, ","), "Upgrade,Ready")
		expect.equal(Grading.WINDOW.EMPTY_BUTTON, "Upgrade", "the button says Upgrade, its cost once a card is in")
		expect.equal(Condenser.WINDOW.OTHER, "Pick other copies")
		for _, window in { Condenser.WINDOW, Grading.WINDOW } do
			for key, text in window do
				if typeof(text) == "string" then
					assert(#text <= 90 and not string.find(text, "[^\32-\126]"), `{key}: {text}`)
					assert(not string.find(text, "$", 1, true), `{key}: no cost in the window's words`)
				end
			end
		end
	end,

	["grading: the copies it can use are the ones no better than the card"] = function()
		local main = { beast = true, foil = false, grade = "B", stars = 0 }
		expect.equal(CondenseRules.gradeHave(config, { C = counts(2, 1), B = counts(1, 0), A = counts(4, 0), S = counts(2, 0) }, main), 4)
		expect.equal(CondenseRules.gradeHave(config, {}, main), 0)
		-- a plain main is set aside, as everywhere
		expect.equal(CondenseRules.gradeHave(config, { C = counts(3, 0) }, { beast = false, foil = false, grade = "C", stars = 0 }), 2)
	end,
	-- owner 2026-11-20: "whats the use of grading seals? I cant see it inside the grading station", then "also the
	-- golden seall or something"; since 2026-11-26 (the redesign) they are the USE row's second and third tiles, there
	-- even with none, so a player learns they exist, and the Gold Seal's never names the cash it pays
	["the Grading Station's USE tiles say what Grading Seals and Gold Seals do"] = function()
		local function seal(view): (string, string)
			return CondenseRules.sealTile(view)
		end
		local title, sub = seal({ have = 15, on = false, used = 0, offers = 1, could = false, missing = 3, max = false })
		expect.equal(title, "Grading Seals x15")
		expect.equal(sub, "Tap: fills a missing copy")
		title, sub = seal({ have = 15, on = true, used = 1, offers = 0, could = false, missing = 2, max = false })
		expect.equal(sub, "1 in. Tap to take out")
		title, sub = seal({ have = 15, on = true, used = 2, offers = 0, could = false, missing = 0, max = false })
		expect.equal(sub, "2 in. Tap to take out")
		-- the copies are all there (or the step takes one copy): it only says what they are
		title, sub = seal({ have = 15, on = false, used = 0, offers = 0, could = false, missing = 0, max = false })
		expect.equal(sub, "Fill in for missing copies")
		title, sub = seal({ have = 1, on = false, used = 0, offers = 0, could = false, missing = 0, max = false })
		expect.equal(title, "Grading Seal x1")
		title, sub = seal({ have = 0, on = false, used = 0, offers = 0, could = false, missing = 2, max = false })
		expect.equal(title, "Grading Seals x0", "none: the tile still shows")
		expect.equal(sub, "You have none yet")

		title, sub = CondenseRules.goldTile(11, false, true)
		expect.equal(title, "Gold Seals x11")
		expect.equal(sub, "Tap: pays the cash")
		title, sub = CondenseRules.goldTile(11, true, true)
		expect.equal(sub, "Pays the cash! Tap to undo")
		title, sub = CondenseRules.goldTile(1, false, false)
		expect.equal(title, "Gold Seal x1")
		expect.equal(sub, "Not for a Legendary's Grade S")
		title, sub = CondenseRules.goldTile(0, false, true)
		expect.equal(title, "Gold Seals x0")
		expect.equal(sub, "You have none yet")
		for _, have in { 0, 1, 11 } do
			for _, on in { false, true } do
				local _, line = CondenseRules.goldTile(have, on, true)
				assert(not string.find(line, "$", 1, true), `no cost on the Gold Seal tile: {line}`)
			end
		end

		local Items = require("../src/shared/Config/Items")
		expect.equal(Items.ITEMS.gradingSeal.use, "At the Grading Station, tap Grading Seals (or an empty spot) to put them in. They can fill up to half the copies a grade needs.")
		expect.equal(Items.ITEMS.goldSeal.use, "At the Grading Station, tap Gold Seals: one pays the cash for that grade.")
	end,
}
