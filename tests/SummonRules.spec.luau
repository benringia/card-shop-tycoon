--!strict
-- The Rift Devourer's summons (the owner 2026-11-11: "will show up to a random corner of an arena and runs to the
-- summoned pet"): where each comes out, how fast it runs, where it stops to bite (Util/SummonRules; BattleService
-- moves them, Util/RiftFx draws the rifts)
local SummonRules = require("../src/shared/Util/SummonRules")
local Bosses = require("../src/shared/Config/Bosses")
local BossRules = require("../src/shared/Util/BossRules")
local expect = require("./lib/expect")

local function length(x: number, z: number): number
	return math.sqrt(x * x + z * z)
end

return {
	["the four corners sit inside the fence, round the arena's centre, clear of the boss"] = function()
		local rift = Bosses.BOSSES.riftDevourer
		local radius = BossRules.arenaRadius(rift, Bosses)
		local seen = {}
		for index = 1, 4 do
			local corner = SummonRules.corner(index, radius, Bosses.BOSS_SPOT, Bosses.SUMMON.cornerShare)
			-- the boss's own space: it faces the gate (-Z), the arena's centre BOSS_SPOT in front of it
			local fromCentre = length(corner.x, corner.z + Bosses.BOSS_SPOT)
			assert(fromCentre <= radius - 6, `corner {index} inside the fence ({fromCentre} of {radius})`)
			assert(length(corner.x, corner.z) >= rift.ringRadius + 6, `corner {index} past the pets' ring`)
			seen[(if corner.x > 0 then 1 else 0) + (if corner.z > -Bosses.BOSS_SPOT then 2 else 0)] = true
		end
		for quarter = 0, 3 do
			assert(seen[quarter], `one corner in each quarter ({quarter})`)
		end
	end,

	["a wave's summons come out at different corners, picked at random"] = function()
		local picks = SummonRules.pickCorners(2, { 0.1, 0.9 })
		expect.equal(#picks, 2)
		assert(picks[1] ~= picks[2], "two different corners")
		local starts = {}
		for _, roll in { 0, 0.3, 0.6, 0.99 } do
			starts[SummonRules.pickCorners(1, { roll })[1]] = true
		end
		for index = 1, 4 do
			assert(starts[index], `corner {index} can come up`)
		end
		local four = SummonRules.pickCorners(4, { 0.5, 0.5, 0.5, 0.5 })
		local distinct = {}
		for _, index in four do
			distinct[index] = true
		end
		local n = 0
		for _ in distinct do
			n += 1
		end
		expect.equal(n, 4, "four summons, four corners")
		expect.equal(#SummonRules.pickCorners(6, {}), 6, "more than four share corners")
	end,

	["a summon runs fast enough to reach its pet as it arrives"] = function()
		expect.near(SummonRules.runSpeed(42, 2.8, 6, 30), 15, 1e-9, "42 studs in 2.8 s")
		expect.equal(SummonRules.runSpeed(200, 2.8, 6, 30), 30, "never faster than the cap")
		expect.equal(SummonRules.runSpeed(1, 2.8, 6, 30), 6, "never slower than a walk")
		expect.equal(SummonRules.runSpeed(10, 0, 6, 30), 30, "no time: as fast as it goes")
	end,

	-- It climbs out of its rift: from under the ground and small, up and full size as its emerge time ends
	["it rises out of its rift, growing, and is all out when its emerge time is up"] = function()
		local sink0, scale0 = SummonRules.emerge(0, 1.2)
		expect.near(sink0, 1, 1e-9, "starts under the ground")
		assert(scale0 > 0.2 and scale0 < 0.7, `starts small ({scale0})`)
		local lastSink, lastScale = sink0, scale0
		for step = 1, 12 do
			local sink, scale = SummonRules.emerge(step * 0.1, 1.2)
			assert(sink <= lastSink + 1e-9 and scale >= lastScale - 1e-9, "only ever rises and grows")
			lastSink, lastScale = sink, scale
		end
		local sinkEnd, scaleEnd = SummonRules.emerge(1.2, 1.2)
		expect.near(sinkEnd, 0, 1e-9, "all out")
		expect.near(scaleEnd, 1, 1e-9, "full size")
		local sinkNone, scaleNone = SummonRules.emerge(0, 0)
		expect.equal(sinkNone, 0, "no emerge time: out at once")
		expect.equal(scaleNone, 1)
	end,

	["it stops a bite's reach short of its pet, on its own side"] = function()
		local spot = SummonRules.meleeSpot({ x = 0, z = 0 }, { x = 30, z = 40 }, 5)
		expect.near(spot.x, 3, 1e-9)
		expect.near(spot.z, 4, 1e-9)
		local same = SummonRules.meleeSpot({ x = 2, z = 2 }, { x = 2, z = 2 }, 5)
		expect.near(length(same.x - 2, same.z - 2), 5, 1e-9, "on top of it: still a reach away")
	end,
}
