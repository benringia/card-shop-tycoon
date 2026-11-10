--!strict
-- The owner 2026-11-10: "add random animations to the boss instead of just standing still and attacking. maybe add like
-- he's walking around while waiting for his next attack or roaring. something intimidating but not limiting its attack
-- speed": between moves a boss walks to a new spot near its own, roars or stomps (client-side; its attacks keep the
-- server's clock and it attacks from wherever it stands)
local BossIdleRules = require("../src/shared/Util/BossIdleRules")
local Bosses = require("../src/shared/Config/Bosses")
local expect = require("./lib/expect")

local CFG = Bosses.IDLE

return {
	["a new spot stays near its own, never in among the fighters in front"] = function()
		local wander = CFG.wander
		for _, rolls in { { 0, 0 }, { 1, 1 }, { 0.5, 0.5 }, { 0, 1 }, { 1, 0 }, { 0.2, 0.9 } } do
			local x, z = BossIdleRules.spot(rolls[1], rolls[2], 1, CFG)
			assert(math.abs(x) <= wander.radius + 1e-9, `x {x}`)
			assert(z >= -wander.front - 1e-9 and z <= wander.radius * wander.back + 1e-9, `z {z}`)
		end
		local big = BossIdleRules.spot(1, 0.5, 1.5, CFG)
		expect.near(big, wander.radius * 1.5, 1e-9, "a bigger boss walks further")
	end,

	["a walk goes to its spot at its pace, facing the way it goes, then faces the fight"] = function()
		local speed = 6
		local x0, z0, _, done0 = BossIdleRules.walk(0, 0, 0, 6, 0, speed)
		expect.near(x0, 0, 1e-9)
		expect.near(z0, 0, 1e-9)
		expect.equal(done0, false)
		local seconds = BossIdleRules.walkSeconds(0, 0, 6, 0, speed)
		expect.near(seconds, 1, 1e-9, "6 studs at 6 a second")
		local xm, _, yawMid = BossIdleRules.walk(seconds / 2, 0, 0, 6, 0, speed)
		expect.near(xm, 3, 0.01, "half way")
		expect.near(yawMid, math.atan2(-1, 0), 1e-9, "facing right as it walks right")
		local xe, ze, yawEnd, doneEnd = BossIdleRules.walk(seconds + 0.01, 0, 0, 6, 0, speed)
		expect.near(xe, 6, 1e-9)
		expect.near(ze, 0, 1e-9)
		expect.equal(doneEnd, true)
		expect.equal(yawEnd, 0, "facing the fight once there")
	end,

	["it picks a walk, a roar or a stomp by the config's weights"] = function()
		local counts = {}
		for step = 0, 99 do
			local action = BossIdleRules.pick((step + 0.5) / 100, CFG.weights)
			counts[action] = (counts[action] or 0) + 1
		end
		local total = 0
		for _, w in CFG.weights do
			total += w
		end
		for action, weight in CFG.weights do
			expect.near((counts[action] or 0) / 100, weight / total, 0.02, action)
		end
	end,

	["it idles only after the intro, between moves, standing"] = function()
		expect.equal(BossIdleRules.free(10, 0, 12, false), false, "the intro")
		expect.equal(BossIdleRules.free(13, 14, 12, false), false, "a move playing")
		expect.equal(BossIdleRules.free(15, 14, 12, false), true)
		expect.equal(BossIdleRules.free(15, 14, 12, true), false, "fainted")
	end,

	["the idle numbers keep it lively but never in the way"] = function()
		assert(CFG.gap[1] >= 0.5 and CFG.gap[2] <= 4, "something every few seconds")
		assert(CFG.wander.radius <= 12, "it stays near its spot")
		assert(CFG.wander.speed >= 4, "a walk fits between its attacks")
		assert(CFG.after >= 0.2, "a breath after each move first")
		assert(CFG.roarVolume < Bosses.ROAR_VOLUME, "its idle roar quieter than its intro roar")
		expect.near(BossIdleRules.gap(0, CFG.gap), CFG.gap[1], 1e-9)
		expect.near(BossIdleRules.gap(1, CFG.gap), CFG.gap[2], 1e-9)
	end,
}
