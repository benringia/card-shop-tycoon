--!strict
-- The character window's element wheel (owner 2026-11-12, pick A: "simple graphs instead of a bunch of texts"): one
-- arrow per "beats" from Config/Combat, its ends clear of the icons, a both-ways pair drawn side by side
local ElementWheel = require("../src/shared/Util/ElementWheel")
local Combat = require("../src/shared/Config/Combat")
local Look = require("../src/shared/Config/CharacterWindow")
local ElementNames = require("../src/shared/Config/ElementNames")
local expect = require("./lib/expect")

local WHEEL = Look.WHEEL

local function arrows(): { ElementWheel.Arrow }
	return ElementWheel.arrows(Combat.BEATS, WHEEL.nodes, WHEEL.icon / 2 + WHEEL.gap, WHEEL.pairOffset)
end

local function distance(x1: number, y1: number, x2: number, y2: number): number
	return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

return {
	["one arrow for every beats, from the winner to the beaten"] = function()
		local list = arrows()
		local relations = 0
		for from, beaten in Combat.BEATS do
			for _, to in beaten do
				relations += 1
				local found = 0
				for _, arrow in list do
					if arrow.from == from and arrow.to == to then
						found += 1
					end
				end
				expect.equal(found, 1, `{from} -> {to}`)
			end
		end
		expect.equal(#list, relations, "no extra arrows")
	end,

	["every element has a spot inside the wheel, its icon and name too"] = function()
		for _, key in ElementNames.ORDER do
			local node = WHEEL.nodes[key]
			assert(node, `{key} has a spot`)
			local half = WHEEL.icon / 2
			expect.equal(node.x - half >= 0 and node.x + half <= WHEEL.size.x, true, `{key} fits across`)
			local top = node.y - half - (if node.nameAbove then WHEEL.nameHeight else 0)
			local bottom = node.y + half + (if node.nameAbove then 0 else WHEEL.nameHeight)
			expect.equal(top >= 0 and bottom <= WHEEL.size.y, true, `{key} and its name fit down`)
		end
	end,

	-- owner's Studio look 2026-11-12: the names under Fire and Electric sat across the arrows leaving them
	["no arrow crosses a name: an icon with arrows leaving downward has its name above"] = function()
		for _, arrow in arrows() do
			for _, key in { arrow.from, arrow.to } do
				local node = WHEEL.nodes[key]
				local other = WHEEL.nodes[if key == arrow.from then arrow.to else arrow.from]
				if other.y > node.y + 1 then
					expect.equal(node.nameAbove, true, `{key}'s name sits above (an arrow goes down from it)`)
				elseif other.y < node.y - 1 then
					expect.equal(node.nameAbove ~= true, true, `{key}'s name sits below (an arrow comes from above)`)
				end
			end
		end
	end,

	["an arrow starts and stops clear of the icons"] = function()
		local clear = WHEEL.icon / 2 + WHEEL.gap
		for _, arrow in arrows() do
			local a, b = WHEEL.nodes[arrow.from], WHEEL.nodes[arrow.to]
			-- a pair's arrows are pushed sideways, so measure along the line between the two centres
			local length = distance(a.x, a.y, b.x, b.y)
			local ux, uy = (b.x - a.x) / length, (b.y - a.y) / length
			local startAlong = (arrow.x1 - a.x) * ux + (arrow.y1 - a.y) * uy
			local endAlong = (arrow.x2 - a.x) * ux + (arrow.y2 - a.y) * uy
			expect.near(startAlong, clear, 1e-6, `{arrow.from} -> {arrow.to} starts outside its icon`)
			expect.near(endAlong, length - clear, 1e-6, `{arrow.from} -> {arrow.to} stops at the other icon`)
		end
	end,

	["a both-ways pair (Electric and Dark) is two arrows side by side, not on top of each other"] = function()
		local there, back
		for _, arrow in arrows() do
			if arrow.from == "Volt" and arrow.to == "Shade" then
				there = arrow
			elseif arrow.from == "Shade" and arrow.to == "Volt" then
				back = arrow
			end
		end
		assert(there and back, "both arrows")
		local gap = distance((there.x1 + there.x2) / 2, (there.y1 + there.y2) / 2, (back.x1 + back.x2) / 2, (back.y1 + back.y2) / 2)
		expect.near(gap, WHEEL.pairOffset * 2, 1e-6, "pushed apart by the offset each way")
		for _, arrow in arrows() do
			if arrow.from == "Ember" and arrow.to == "Bloom" then
				local a, b = WHEEL.nodes.Ember, WHEEL.nodes.Bloom
				local length = distance(a.x, a.y, b.x, b.y)
				local side = ((arrow.x1 - a.x) * (b.y - a.y) - (arrow.y1 - a.y) * (b.x - a.x)) / length
				expect.near(side, 0, 1e-6, "a one-way arrow stays on the line")
			end
		end
	end,
}
