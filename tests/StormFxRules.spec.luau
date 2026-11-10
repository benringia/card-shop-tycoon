--!strict
-- The Storm Sovereign's thunderclap effects' numbers (the owner 2026-11-11; Util/StormFx draws them)
local StormFxRules = require("../src/shared/Util/StormFxRules")
local AttackFx = require("../src/shared/Config/AttackFx")
local expect = require("./lib/expect")

return {
	["the clap's lightning lands all over its storm circle, inside it"] = function()
		local radius = 28
		local points = StormFxRules.strikePoints(9, radius)
		expect.equal(#points, 9)
		local quarters = {}
		for _, point in points do
			local reach = math.sqrt(point.x * point.x + point.z * point.z)
			assert(reach <= radius * 0.95 + 1e-6, `inside the circle ({reach})`)
			assert(reach >= radius * 0.2 - 1e-6, `clear of the boss ({reach})`)
			assert(point.delay >= 0 and point.delay <= AttackFx.STORM.clap.stagger + 1e-9, "within the stagger")
			quarters[(if point.x >= 0 then 1 else 0) + (if point.z >= 0 then 2 else 0)] = true
		end
		for quarter = 0, 3 do
			assert(quarters[quarter], `a strike in every quarter ({quarter})`)
		end
		expect.equal(#StormFxRules.strikePoints(0, radius), 0, "none asked: none")
	end,

	["the storm circle spreads from the boss to its edge over the warning"] = function()
		expect.near(StormFxRules.fillShare(0, 2), AttackFx.STORM.circle.startFill, 1e-9, "starts small round the boss")
		expect.near(StormFxRules.fillShare(2, 2), 1, 1e-9, "full at the clap")
		expect.near(StormFxRules.fillShare(5, 2), 1, 1e-9, "never past its edge")
		assert(StormFxRules.fillShare(1, 2) > StormFxRules.fillShare(0.5, 2), "grows")
		expect.near(StormFxRules.fillShare(1, 0), 1, 1e-9, "no warning: full at once")
	end,

	["crackles run round the circle's edge, each a short arc between two points on it"] = function()
		local a, b = StormFxRules.edgeArc(0, 20, 30)
		expect.near(math.sqrt(a.x * a.x + a.z * a.z), 20, 1e-6, "on the edge")
		expect.near(math.sqrt(b.x * b.x + b.z * b.z), 20, 1e-6, "on the edge")
		local chord = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
		expect.near(chord, 2 * 20 * math.sin(math.rad(15)), 1e-6, "30 degrees apart")
	end,
}
