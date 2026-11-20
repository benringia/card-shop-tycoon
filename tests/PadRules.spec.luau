--!strict
-- The delivery pad's stacks (owner 2026-11-20: "when there is alot of boxes piled up, and the players just want to take
-- the one on top. it's dificult. make it better"): one stack a product, only a stack's top box can be picked up
local PadRules = require("../src/shared/Util/PadRules")
local expect = require("./lib/expect")

local COLUMNS, HIGH = 4, 3

local function at(places: { PadRules.Place }, index: number): string
	return `{places[index].column}:{places[index].level}`
end

return {
	["each product has its own stack, in the order the products first came"] = function()
		local places = PadRules.arrange({ "Pack", "Sleeves", "Pack", "Deck", "Sleeves", "Pack" }, COLUMNS, HIGH)
		expect.equal(at(places, 1), "1:0", "the first pack starts stack 1")
		expect.equal(at(places, 2), "2:0", "sleeves start stack 2")
		expect.equal(at(places, 3), "1:1", "the second pack goes on the first")
		expect.equal(at(places, 4), "3:0")
		expect.equal(at(places, 5), "2:1")
		expect.equal(at(places, 6), "1:2")
	end,

	["a full stack's product starts another on the next empty spot"] = function()
		local places = PadRules.arrange({ "Pack", "Pack", "Pack", "Pack", "Deck", "Pack" }, COLUMNS, HIGH)
		expect.equal(at(places, 3), "1:2", "three high")
		expect.equal(at(places, 4), "2:0", "the fourth starts a second stack")
		expect.equal(at(places, 5), "3:0", "the deck boxes get the next spot")
		expect.equal(at(places, 6), "2:1", "more packs go on the second stack")
	end,

	["a full pad (12 boxes) still gives every box its own place, none higher than the limit"] = function()
		local products = {}
		for index = 1, 12 do
			products[index] = if index % 3 == 0 then "Deck" elseif index % 2 == 0 then "Sleeves" else "Pack"
		end
		local places = PadRules.arrange(products, COLUMNS, HIGH)
		local seen = {}
		for index, place in places do
			assert(place.column >= 1 and place.column <= COLUMNS, "on the pad")
			assert(place.level >= 0 and place.level < HIGH, `box {index} no higher than {HIGH}`)
			local key = at(places, index)
			assert(not seen[key], `two boxes at {key}`)
			seen[key] = true
		end
	end,

	["past the limit boxes still land somewhere: on the lowest stack"] = function()
		local products = table.create(14, "Pack")
		local places = PadRules.arrange(products, COLUMNS, HIGH)
		expect.equal(#places, 14)
		expect.equal(places[13].level, HIGH, "one over, never lost")
		assert(places[13].column ~= places[14].column, "spread out")
	end,

	["only the top box of each stack can be picked up"] = function()
		local products = { "Pack", "Sleeves", "Pack", "Deck", "Sleeves", "Pack" }
		local places = PadRules.arrange(products, COLUMNS, HIGH)
		local tops = PadRules.tops(places)
		expect.equal(tops[6], true, "the top pack")
		expect.equal(tops[5], true, "the top sleeves")
		expect.equal(tops[4], true, "the only deck box")
		expect.isNil(tops[1], "a pack under two others")
		expect.isNil(tops[3])
		expect.isNil(tops[2])
		local count = 0
		for _ in tops do
			count += 1
		end
		expect.equal(count, 3, "one prompt a stack")
		expect.equal(next(PadRules.tops({})), nil, "an empty pad")
		-- taking the top one leaves the one under it on top
		local after = PadRules.arrange({ "Pack", "Sleeves", "Pack", "Deck", "Sleeves" }, COLUMNS, HIGH)
		expect.equal(PadRules.tops(after)[3], true)
	end,

	["the prompt says what the stack holds and how many wait"] = function()
		expect.equal(PadRules.label("Card Sleeves", 1), "Card Sleeves")
		expect.equal(PadRules.label("Card Sleeves", 3), "Card Sleeves · 3 boxes")
		expect.equal(PadRules.label("Card Sleeves", 0), "Card Sleeves")
	end,
}
