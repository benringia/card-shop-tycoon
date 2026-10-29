--!strict
-- The glass cases' upright, spinning cards (UI project 3 spec section 3)
local CaseLayout = require("../src/shared/Config/CaseLayout")
local ShowcaseLayout = require("../src/shared/Util/ShowcaseLayout")
local expect = require("./lib/expect")

local equal = expect.equal
local CASE = { x = 6, y = 4, z = 2 } -- Config/Shelves size of both cases

return {
	["six upright cards fit the 6 x 4 x 2 case without touching while they spin"] = function()
		local look = CaseLayout.UPRIGHT
		local slots = ShowcaseLayout.uprightSlots(6, CASE, look)
		equal(#slots, 6, "six")
		local half = look.cardSize.x / 2
		for i, a in slots do
			equal(math.abs(a.x) + half <= CASE.x / 2 and math.abs(a.z) + half <= CASE.z / 2, true, `slot {i} inside the footprint`)
			equal(a.y - look.cardSize.y / 2 >= -CASE.y / 2 and a.y + look.cardSize.y / 2 <= CASE.y / 2, true, `slot {i} inside the height`)
			for j = i + 1, #slots do
				local b = slots[j]
				local apart = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2) >= 2 * half
				local stacked = math.abs(a.y - b.y) >= look.cardSize.y
				equal(apart or stacked, true, `slots {i} and {j} clear`)
			end
		end
		equal(slots[4].y > slots[1].y, true, "back row raised")
		equal(slots[4].z > slots[1].z, true, "back row behind the front one")
	end,

	["fewer slots fill the front row first, left to right"] = function()
		local slots = ShowcaseLayout.uprightSlots(2, CASE, CaseLayout.UPRIGHT)
		equal(#slots, 2, "two")
		equal(slots[1].z, slots[2].z, "same row")
		equal(slots[1].x < slots[2].x, true, "left to right")
	end,
}
