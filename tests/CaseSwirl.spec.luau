--!strict
-- The glass cases' spiral lights (owner 2026-11-14, concept B "museum vitrine": "make it look exactly like that. with
-- the glows and everything"): a light circles each card's beam as it climbs from the pad to the top, then starts again
local CaseSwirl = require("../src/shared/Util/CaseSwirl")
local expect = require("./lib/expect")

local CFG = { seconds = 2.5, turns = 1.5, radius = 0.5, bottom = 0.1, top = 2.4 }

return {
	["it climbs from the pad to the top once a lap, always the same distance from the beam"] = function()
		local start = CaseSwirl.point(0, 0, CFG)
		expect.near(start.y, CFG.bottom, 1e-6, "starts at the pad")
		local late = CaseSwirl.point(CFG.seconds * 0.999, 0, CFG)
		expect.equal(late.y > CFG.top - 0.01, true, "near the top at the lap's end")
		local last = -math.huge
		for step = 0, 99 do
			local here = CaseSwirl.point(CFG.seconds * step / 100, 0, CFG)
			expect.near(math.sqrt(here.x ^ 2 + here.z ^ 2), CFG.radius, 1e-6, `step {step}: on its circle`)
			expect.equal(here.y > last, true, `step {step}: always climbing within a lap`)
			last = here.y
		end
	end,

	["each lap counts up, so the trail can be cleared when it jumps back down"] = function()
		expect.equal(CaseSwirl.point(0.1, 0, CFG).lap, 0)
		expect.equal(CaseSwirl.point(CFG.seconds + 0.1, 0, CFG).lap, 1)
		expect.equal(CaseSwirl.point(CFG.seconds * 2 + 0.1, 0, CFG).lap, 2)
	end,

	["it turns `turns` times a lap, and a phase puts neighbouring cards out of step"] = function()
		local a = CaseSwirl.point(0, 0, CFG)
		local b = CaseSwirl.point(CFG.seconds / CFG.turns * 0.999999, 0, CFG)
		expect.near(a.x, b.x, 1e-3, "one turn later: the same side of the beam")
		local shifted = CaseSwirl.point(0, 0.5, CFG)
		expect.near(shifted.y, CFG.bottom + (CFG.top - CFG.bottom) * 0.5, 1e-6, "half a lap ahead")
	end,
}
