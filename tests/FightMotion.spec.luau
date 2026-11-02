--!strict
local FightMotion = require("../src/shared/Util/FightMotion")
local AttackFx = require("../src/shared/Config/AttackFx")
local expect = require("./lib/expect")

local cfg = AttackFx.ORBIT

return {
	["a creature stays within its orbit and darts"] = function()
		for seed = 1, 5 do
			for step = 0, 200 do
				local x, z = FightMotion.offset(seed, step * 0.05, cfg)
				expect.equal(math.sqrt(x * x + z * z) <= cfg.radius + cfg.dart + 1e-9, true, `seed {seed} t {step * 0.05}`)
			end
		end
	end,

	["the same seed and time give the same place; seeds differ"] = function()
		local x1, z1 = FightMotion.offset(3, 2.5, cfg)
		local x2, z2 = FightMotion.offset(3, 2.5, cfg)
		expect.equal(x1, x2)
		expect.equal(z1, z2)
		local x3, z3 = FightMotion.offset(4, 2.5, cfg)
		expect.equal(x1 ~= x3 or z1 ~= z3, true)
	end,

	["it keeps moving"] = function()
		local x1, z1 = FightMotion.offset(1, 1, cfg)
		local x2, z2 = FightMotion.offset(1, 1.5, cfg)
		expect.equal(math.abs(x1 - x2) + math.abs(z1 - z2) > 0.1, true)
	end,

	["charging stops the motion clock, so the creature holds still"] = function()
		local clock = FightMotion.newClock()
		FightMotion.advance(clock, 10, false)
		local before = FightMotion.advance(clock, 11, false)
		local held1 = FightMotion.advance(clock, 11.2, true)
		local held2 = FightMotion.advance(clock, 11.5, true)
		expect.equal(held1, before)
		expect.equal(held2, before)
		local after = FightMotion.advance(clock, 12, false)
		expect.near(after, before + 0.5, 1e-9, "it carries on from where it stopped")
	end,
}
