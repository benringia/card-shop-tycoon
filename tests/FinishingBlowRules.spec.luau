--!strict
-- The finishing blow (spec 2026-11-25-finishing-blow-design; owner: A "but no KO popout", then felt a test: "strong
-- feels good, freeze the creature too"): whose last hit gets the moment, the knockout's beat, launch and kick with it,
-- and the knockout still over before the server lets the monster go
local Rules = require("../src/shared/Util/FinishingBlowRules")
local Config = require("../src/shared/Config/FinishingBlow")
local MonsterKO = require("../src/shared/Config/MonsterKO")
local expect = require("./lib/expect")

local function near(a: number, b: number, message: string?)
	assert(math.abs(a - b) < 1e-6, `{message or "value"}: expected {b}, got {a}`)
end

local WILD, BOSS = Config.WILD, Config.BOSS

return {
	["the felt numbers"] = function()
		near(WILD.hold, 0.16, "wild hold")
		near(WILD.power, 1.25, "wild launch")
		near(WILD.shake, 0.6, "wild kick")
		near(WILD.zoom, 8, "wild zoom")
		near(WILD.zoomIn, 0.05, "wild zoom in")
		near(WILD.back, 0.35, "wild zoom back")
		expect.equal(WILD.sound, "rbxassetid://9117330384", "wild thud: Pick Impacts 1")
		near(WILD.volume, 0.7, "wild volume")
		near(WILD.flash, 0, "no screen flash on a wild win")
		near(BOSS.hold, 0.4, "boss hold")
		near(BOSS.shake, 1.2, "boss kick")
		near(BOSS.zoom, 11, "boss zoom")
		near(BOSS.zoomIn, 0.05, "boss zoom in")
		near(BOSS.back, 0.35, "boss zoom back")
		expect.equal(BOSS.sound, "rbxassetid://9125484367", "boss boom: Deep Hits Big Reverberant Booms 2")
		near(BOSS.volume, 0.7, "boss volume")
		near(BOSS.flash, 0.3, "boss screen flash")
		near(Config.FLASH_TAIL, 0.2, "screen flash tail")
		near(Config.BODY_FLASH.fill, 0.7, "boss body flash fill")
		near(Config.BODY_FLASH.tail, 0.25, "boss body flash tail")
		near(Config.MARGIN, 0.1, "latency margin")
		near(MonsterKO.SERVER_SECONDS, 2.7, "the server keeps a beaten monster")
	end,

	["holds are beats, not stalls"] = function()
		assert(WILD.hold > MonsterKO.hitStop, "longer than a plain knockout's beat")
		assert(WILD.hold <= 0.2, `wild hold {WILD.hold} <= 0.2`)
		assert(BOSS.hold > WILD.hold, "a boss holds longer")
		assert(BOSS.hold <= 0.5, `boss hold {BOSS.hold} <= 0.5`)
	end,

	["only your running fight's monster"] = function()
		assert(Rules.mine(true, true), "your fight's monster, fight running: yours")
		assert(not Rules.mine(false, true), "you ran or lost, then someone else beat it: not yours")
		assert(not Rules.mine(true, false), "another monster beaten near your fight: not yours")
		assert(not Rules.mine(false, false), "nothing to do with you")
	end,

	["no moment: a plain knockout's beat, launch and kick"] = function()
		local hitStop, power, shake = Rules.knockout(MonsterKO, false, nil)
		near(hitStop, MonsterKO.hitStop, "beat")
		near(power, 1, "launch")
		near(shake, MonsterKO.shake, "kick")
		local eliteStop, elitePower, eliteShake = Rules.knockout(MonsterKO, true, nil)
		near(eliteStop, MonsterKO.hitStop, "elite beat")
		near(elitePower, MonsterKO.elite.power, "elite launch")
		near(eliteShake, MonsterKO.shake * MonsterKO.elite.shake, "elite kick")
	end,

	["a moment: its hold, a harder launch and kick"] = function()
		local hitStop, power, shake = Rules.knockout(MonsterKO, false, WILD)
		near(hitStop, 0.16, "beat")
		near(power, 1.25, "launch")
		near(shake, 0.6, "kick")
	end,

	["an elite keeps its extra on top"] = function()
		local hitStop, power, shake = Rules.knockout(MonsterKO, true, WILD)
		near(hitStop, 0.16, "beat")
		near(power, 1.25 * MonsterKO.elite.power, "launch")
		near(shake, 0.6 * MonsterKO.elite.shake, "kick")
	end,

	["the knockout's length"] = function()
		local plain = Rules.knockoutSeconds(MonsterKO, MonsterKO.hitStop)
		near(plain, MonsterKO.hitStop + MonsterKO.maxFlight + MonsterKO.settleSeconds + MonsterKO.holdSeconds + MonsterKO.poofSeconds, "sum")
		near(Rules.knockoutSeconds(MonsterKO, WILD.hold) - plain, WILD.hold - MonsterKO.hitStop, "only the beat grows")
	end,

	["the knockout still ends the margin before the server lets go"] = function()
		local longest = Rules.knockoutSeconds(MonsterKO, WILD.hold)
		assert(longest <= MonsterKO.SERVER_SECONDS - Config.MARGIN, `{longest} s <= {MonsterKO.SERVER_SECONDS} - {Config.MARGIN} s`)
	end,
}
