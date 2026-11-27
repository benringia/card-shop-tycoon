--!strict
-- What now? tips (spec 2026-11-27-what-now-hints-design): which tip, its words, when one may show, where its bubble sits
local HintRules = require("../src/shared/Util/HintRules")
local Hints = require("../src/shared/Config/Hints")
local expect = require("./lib/expect")

local function facts(over: { [string]: any }): HintRules.Facts
	local made: { [string]: any } = {
		registerWaiting = false,
		questsDone = 0,
		boxWaiting = false,
		boxesComing = 0,
		shelvesStocked = false,
		cash = 0,
		cheapestBox = nil,
		stationReady = nil,
		buildName = nil,
		packs = 0,
		boss = nil,
		questText = nil,
		inTown = false,
	}
	for key, value in over do
		made[key] = value
	end
	return made :: any
end

-- Every string inside a table, nested
local function strings(value: any, into: { string })
	if typeof(value) == "string" then
		table.insert(into, value)
	elseif typeof(value) == "table" then
		for _, inner in value do
			strings(inner, into)
		end
	end
end

return {
	["nothing to do in the Wild: no tip"] = function()
		expect.equal(HintRules.pick(facts({}), {}, Hints.ORDER), nil)
	end,

	["nothing to do in town: hunt"] = function()
		expect.equal(HintRules.pick(facts({ inTown = true }), {}, Hints.ORDER), "hunt")
	end,

	["the first that's true wins"] = function()
		local busy = facts({ registerWaiting = true, questsDone = 2, packs = 3, inTown = true })
		expect.equal(HintRules.pick(busy, {}, Hints.ORDER), "register")
		expect.equal(HintRules.pick(facts({ questsDone = 2, packs = 3, inTown = true }), {}, Hints.ORDER), "claim")
		expect.equal(HintRules.pick(facts({ packs = 3, inTown = true }), {}, Hints.ORDER), "packs")
		expect.equal(Hints.ORDER[1], "register")
		expect.equal(Hints.ORDER[#Hints.ORDER], "hunt", "hunting is what's left")
	end,

	["skipped kinds are passed over"] = function()
		local two = facts({ registerWaiting = true, packs = 1 })
		expect.equal(HintRules.pick(two, { register = true }, Hints.ORDER), "packs")
		expect.equal(HintRules.pick(two, { register = true, packs = true }, Hints.ORDER), nil)
	end,

	["order needs empty shelves, the cash and nothing on the way"] = function()
		expect.equal(HintRules.pick(facts({ cheapestBox = 40, cash = 40 }), {}, Hints.ORDER), "order")
		expect.equal(HintRules.pick(facts({ cheapestBox = 40, cash = 39 }), {}, Hints.ORDER), nil, "never what they can't pay for")
		expect.equal(HintRules.pick(facts({ cheapestBox = 40, cash = 90, boxesComing = 2 }), {}, Hints.ORDER), nil, "boxes on the way")
		expect.equal(HintRules.pick(facts({ cheapestBox = 40, cash = 90, boxWaiting = true }), {}, Hints.ORDER), "stock")
		expect.equal(HintRules.pick(facts({ cheapestBox = 40, cash = 90, shelvesStocked = true }), {}, Hints.ORDER), nil)
		expect.equal(HintRules.pick(facts({ cash = 90 }), {}, Hints.ORDER), nil, "nothing to order at this level")
	end,

	["each tip holds while its thing is true"] = function()
		expect.equal(HintRules.holds("station", facts({ stationReady = "Condenser" })), true)
		expect.equal(HintRules.holds("station", facts({})), false)
		expect.equal(HintRules.holds("build", facts({ buildName = "Bulk Bin" })), true)
		expect.equal(HintRules.holds("boss", facts({ boss = { name = "Meadow Warden", cleared = false } })), true)
		expect.equal(HintRules.holds("quest", facts({ questText = "Quest: Open 3 packs · 1/3" })), true)
		expect.equal(HintRules.holds("hunt", facts({ inTown = true })), true)
		expect.equal(HintRules.holds("hunt", facts({})), false, "already in the Wild")
	end,

	["an unknown kind never holds"] = function()
		expect.equal(HintRules.holds("nope", facts({ inTown = true, packs = 3 })), false)
	end,

	["words fill in counts and names"] = function()
		local words = Hints.WORDS
		expect.equal(HintRules.words("claim", facts({ questsDone = 1 }), words), "A quest is done! Claim it.")
		expect.equal(HintRules.words("claim", facts({ questsDone = 3 }), words), "3 quests are done! Claim them.")
		expect.equal(HintRules.words("packs", facts({ packs = 1 }), words), "Open your pack!")
		expect.equal(HintRules.words("packs", facts({ packs = 4 }), words), "Open your 4 packs!")
		expect.equal(HintRules.words("build", facts({ buildName = "Bulk Bin" }), words), "You can build the Bulk Bin!")
		expect.equal(HintRules.words("station", facts({ stationReady = "GradingStation" }), words), "Your graded card is ready! Take it out.")
		expect.equal(HintRules.words("station", facts({ stationReady = "Condenser" }), words), "Your new star is ready! Take it out.")
		local warden = { name = "Meadow Warden", cleared = false }
		expect.equal(HintRules.words("boss", facts({ boss = warden }), words), "You're strong enough for the Meadow Warden!")
		expect.equal(HintRules.words("boss", facts({ boss = { name = "Meadow Warden", cleared = true } }), words), "The Meadow Warden's loot is ready!")
		expect.equal(HintRules.words("quest", facts({ questText = "Quest: Open 3 packs · 1/3" }), words), "Quest: Open 3 packs · 1/3")
		expect.equal(HintRules.words("register", facts({}), words), "Customers are waiting! Ring them up.")
		expect.equal(HintRules.words("hunt", facts({}), words), "Hunt monsters in the Wild!")
	end,

	["a tip waits past the first minute"] = function()
		expect.equal(HintRules.due(59, { joinedAt = 0, idleSince = 0, quietSince = 0 }, Hints), false)
		expect.equal(HintRules.due(60, { joinedAt = 0, idleSince = 30, quietSince = 60 }, Hints), true)
	end,

	["standing idle 30 s or 2 minutes with nothing earned"] = function()
		expect.equal(HintRules.due(200, { joinedAt = 0, idleSince = 171, quietSince = 199 }, Hints), false)
		expect.equal(HintRules.due(200, { joinedAt = 0, idleSince = 170, quietSince = 199 }, Hints), true)
		expect.equal(HintRules.due(200, { joinedAt = 0, idleSince = nil, quietSince = 81 }, Hints), false, "moving, earning")
		expect.equal(HintRules.due(200, { joinedAt = 0, idleSince = nil, quietSince = 80 }, Hints), true, "walking around, nothing earned")
	end,

	["two minutes between tips"] = function()
		local timing = { joinedAt = 0, idleSince = 0, quietSince = 0, lastShownAt = 100 }
		expect.equal(HintRules.due(219, timing, Hints), false)
		expect.equal(HintRules.due(220, timing, Hints), true)
	end,

	["a muted tip or one shown in the last 5 minutes is skipped"] = function()
		local skip = HintRules.skip(400, { packs = 101, claim = 99 }, { hunt = true }, 300)
		expect.equal(skip.packs, true)
		expect.equal(skip.hunt, true)
		expect.equal(skip.claim, nil)
	end,

	["over an arrow pointing down the bubble sits above it"] = function()
		local at = HintRules.bubbleAt({ x = 480, y = 300, w = 78, h = 78 }, 0, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 })
		expect.equal(at.x, 399)
		expect.equal(at.y, 248)
	end,

	["beside an arrow at the left edge it sits to its right"] = function()
		local at = HintRules.bubbleAt({ x = 17, y = 261, w = 78, h = 78 }, 90, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 })
		expect.equal(at.x, 101)
		expect.equal(at.y, 277)
		local right = HintRules.bubbleAt({ x = 905, y = 261, w = 78, h = 78 }, -90, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 })
		expect.equal(right.x, 659, "at the right edge: to its left")
	end,

	["an arrow pointing up puts it underneath"] = function()
		local at = HintRules.bubbleAt({ x = 480, y = 20, w = 78, h = 78 }, 180, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 })
		expect.equal(at.x, 399)
		expect.equal(at.y, 104)
	end,

	["never off the screen, never on the arrow"] = function()
		local corner = HintRules.bubbleAt({ x = 2, y = 2, w = 78, h = 78 }, 0, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 })
		expect.equal(corner.x, 86, "no room over it in the corner: beside it")
		expect.equal(corner.y, 18)
		local edge = HintRules.bubbleAt({ x = 950, y = 300, w = 78, h = 78 }, 0, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 })
		expect.equal(edge.x, 1000 - 8 - 240)
	end,

	-- owner 2026-11-28 "make sure no overlapping elements": on a phone the claim tip's arrow points down at the quest
	-- strip from the top bar, no room over it, and the bubble fell on the strip and the cash
	["the bubble never lands on what the arrow points at: by the phone's quest strip it sits beside it"] = function()
		local view, bubble, cfg = { w = 750, h = 323 }, { w = 289, h = 46 }, { gap = 6, margin = 8 }
		local strip = { x = 557, y = -5, w = 105, h = 46 } -- the strip's ring
		local arrow = { x = 591, y = -63, w = 36, h = 46 } -- its whole bounce, in the top bar
		local at = HintRules.bubbleAt(arrow, 0, bubble, view, cfg, strip)
		local function covers(box: { x: number, y: number, w: number, h: number }): boolean
			return at.x < box.x + box.w and box.x < at.x + bubble.w and at.y < box.y + box.h and box.y < at.y + bubble.h
		end
		expect.equal(covers(strip), false, "off the strip")
		expect.equal(covers(arrow), false, "off the arrow")
		expect.equal(at.x + bubble.w <= strip.x, true, "on the roomier side: left of it")
		expect.equal(at.x >= 8 and at.y >= 8 and at.y + bubble.h <= view.h - 8, true, "on the screen")
	end,

	["no room beside it either: past what it points at"] = function()
		local view, bubble, cfg = { w = 300, h = 600 }, { w = 240, h = 46 }, { gap = 6, margin = 8 }
		local target = { x = 110, y = 8, w = 80, h = 40 }
		local at = HintRules.bubbleAt({ x = 130, y = -50, w = 40, h = 54 }, 0, bubble, view, cfg, target)
		expect.equal(at.x, 30)
		expect.equal(at.y, 54, "under it, the gap off its bottom")
	end,

	-- seen 2026-11-28 on a phone: "Put your box on a shelf!" over a thing near the top edge, no room over the arrow; the
	-- bubble went right onto the quest strip and the cash
	["the bubble keeps clear of the HUD: off the cash column, on the free side"] = function()
		local view, bubble, cfg = { w = 750, h = 323 }, { w = 289, h = 46 }, { gap = 6, margin = 8 }
		local arrow = { x = 345, y = -28, w = 40, h = 58 } -- its whole bounce, down to the top of a thing near the top edge
		local hud = { { x = 565, y = 3, w = 89, h = 30 }, { x = 692, y = 5, w = 36, h = 26 }, { x = 12, y = 79, w = 50, h = 129 } }
		local at = HintRules.bubbleAt(arrow, 0, bubble, view, cfg, nil, hud)
		for i, box in hud do
			local covers = at.x < box.x + box.w and box.x < at.x + bubble.w and at.y < box.y + box.h and box.y < at.y + bubble.h
			expect.equal(covers, false, `off the HUD's piece {i}`)
		end
		expect.equal(at.x + bubble.w <= arrow.x, true, "left of the arrow: the free side")
	end,

	["nowhere clear of the HUD: the spot covering the least, still off the arrow"] = function()
		local view, bubble, cfg = { w = 750, h = 323 }, { w = 289, h = 46 }, { gap = 6, margin = 8 }
		local arrow = { x = 345, y = -28, w = 40, h = 58 }
		local hud = { { x = 0, y = 0, w = 300, h = 60 }, { x = 420, y = 0, w = 330, h = 20 } }
		local at = HintRules.bubbleAt(arrow, 0, bubble, view, cfg, nil, hud)
		expect.equal(at.x >= arrow.x + arrow.w, true, "right: it covers less there")
	end,

	["with room over the arrow a target changes nothing"] = function()
		local at = HintRules.bubbleAt({ x = 480, y = 300, w = 78, h = 78 }, 0, { w = 240, h = 46 }, { w = 1000, h = 600 }, { gap = 6, margin = 8 }, { x = 470, y = 380, w = 98, h = 50 })
		expect.equal(at.x, 399)
		expect.equal(at.y, 248)
	end,

	["the server takes only real tips and outcomes"] = function()
		local kind, outcome = HintRules.readSeen("packs", "shown", Hints.ORDER)
		expect.equal(kind, "packs")
		expect.equal(outcome, "shown")
		for _, bad in { { "packs", "eaten" }, { "nope", "done" }, { 5, "done" }, { "packs", nil } } do
			local k, o = HintRules.readSeen(bad[1], bad[2], Hints.ORDER)
			expect.equal(k, nil)
			expect.equal(o, nil)
		end
	end,

	["every word is plain text and short"] = function()
		local all = {}
		strings(Hints.WORDS, all)
		assert(#all >= 12, "every tip's words")
		for _, text in all do
			local plain = string.gsub(text, "·", "")
			assert(string.match(plain, "^[%w%s%p]*$"), `plain ASCII: {text}`)
			local filled = string.gsub(string.gsub(text, "%%d", "12"), "%%s", "Meadow Warden")
			assert(#filled <= Hints.MAX_WORDS, `fits the bubble: {filled}`)
		end
		-- the Wild's real bosses, the only ones a tip names
		local Bosses = require("../src/shared/Config/Bosses")
		for _, boss in Bosses.BOSSES do
			if boss.place == "Wild" then
				for _, line in { Hints.WORDS.boss.ready, Hints.WORDS.boss.loot } do
					local said = string.format(line, boss.name)
					assert(#said <= Hints.MAX_WORDS, `fits the bubble: {said}`)
				end
			end
		end
	end,
}
