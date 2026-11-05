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
	-- Owner 2026-11-05: "Thunderhorn is walking sideways". Circling its spot it kept facing the foe, so it strafed; it
	-- faces the way it goes (forward is -z, as a marker's look), and turns back to the foe to charge
	["circling, it faces the way it goes"] = function()
		for seed = 1, 4 do
			for step = 1, 40 do
				local t = step * 0.37
				local yaw = FightMotion.heading(seed, t, cfg)
				local x0, z0 = FightMotion.offset(seed, t - 0.01, cfg)
				local x1, z1 = FightMotion.offset(seed, t + 0.01, cfg)
				local dx, dz = x1 - x0, z1 - z0
				local length = math.sqrt(dx * dx + dz * dz)
				-- CFrame.Angles(0, yaw, 0) turns forward (0, 0, -1) to (-sin yaw, 0, -cos yaw)
				expect.near(-math.sin(yaw), dx / length, 1e-3, `seed {seed} t {t}: x`)
				expect.near(-math.cos(yaw), dz / length, 1e-3, `seed {seed} t {t}: z`)
			end
		end
	end,

	["turning takes the short way round and eases in"] = function()
		local from, to = math.rad(170), math.rad(-170)
		local turned = FightMotion.turn(from, to, 1 / 60, 8)
		expect.equal(turned > from, true, "past 180, not back through 0")
		expect.near(FightMotion.turn(0.5, 0.5, 1 / 60, 8), 0.5, 1e-9, "already there")
		local near = FightMotion.turn(0, 1, 10, 8)
		expect.near(near, 1, 1e-3, "a long frame gets all the way")
		local step = FightMotion.turn(0, 1, 1 / 60, 8)
		expect.equal(step > 0 and step < 0.3, true, "one frame only part of the way")
	end,
}
