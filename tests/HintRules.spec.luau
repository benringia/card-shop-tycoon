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

	["every word is plain text and short"] = function()
		local all = {}
		strings(Hints.WORDS, all)
		assert(#all >= 12, "every tip's words")
		for _, text in all do
			local plain = string.gsub(text, "·", "")
			assert(string.match(plain, "^[%w%s%p]*$"), `plain ASCII: {text}`)
			local filled = string.gsub(string.gsub(text, "%%d", "12"), "%%s", "Meadow Warden")
			assert(#filled <= 46, `fits the bubble: {filled}`)
		end
		-- the Wild's real bosses, the only ones a tip names
		local Bosses = require("../src/shared/Config/Bosses")
		for _, boss in Bosses.BOSSES do
			if boss.place == "Wild" then
				for _, line in { Hints.WORDS.boss.ready, Hints.WORDS.boss.loot } do
					local said = string.format(line, boss.name)
					assert(#said <= 46, `fits the bubble: {said}`)
				end
			end
		end
	end,
}
