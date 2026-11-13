--!strict
-- The "Empty" badges over your shelves (owner 2026-11-14: a shop full of empty shelves buried the screen in badges):
-- only the nearest few show, never two overlapping on screen, none off screen
local BadgeRules = require("../src/shared/Util/BadgeRules")
local expect = require("./lib/expect")

local SIZE = { w = 84, h = 30 }

local function badge(id: string, distance: number, x: number, y: number, onScreen: boolean?): BadgeRules.Candidate
	return { id = id, distance = distance, x = x, y = y, onScreen = onScreen ~= false }
end

local function shown(picked: { [string]: boolean }): string
	local ids = {}
	for id in picked do
		table.insert(ids, id)
	end
	table.sort(ids)
	return table.concat(ids, ",")
end

return {
	["the nearest few empty shelves show, the rest wait"] = function()
		local picked = BadgeRules.pick({
			badge("far", 30, 100, 100),
			badge("near", 5, 300, 100),
			badge("mid", 12, 500, 100),
			badge("next", 20, 700, 100),
		}, 3, SIZE)
		expect.equal(shown(picked), "mid,near,next")
	end,

	["two badges that would overlap on screen: only the nearer one shows"] = function()
		local picked = BadgeRules.pick({
			badge("front", 6, 400, 200),
			badge("behind", 9, 430, 210), -- 30 px across, 10 down: on top of the front one
			badge("apart", 15, 400, 260), -- 60 px down: clear of it
		}, 3, SIZE)
		expect.equal(shown(picked), "apart,front")
	end,

	["a badge off screen never takes a place"] = function()
		local picked = BadgeRules.pick({
			badge("behindYou", 2, 0, 0, false),
			badge("ahead", 8, 400, 200),
		}, 1, SIZE)
		expect.equal(shown(picked), "ahead")
	end,

	["no empty shelves, no badges"] = function()
		expect.equal(shown(BadgeRules.pick({}, 3, SIZE)), "")
	end,
}
