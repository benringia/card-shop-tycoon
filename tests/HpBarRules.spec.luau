--!strict
local HpBarRules = require("../src/shared/Util/HpBarRules")
local CombatHud = require("../src/shared/Config/CombatHud")
local expect = require("./lib/expect")

local cfg = CombatHud

return {
	["a hit drops the fill at once while the red ghost holds, then drains"] = function()
		expect.equal(cfg.HP_BAR.GHOST_HOLD, 0.35)
		expect.equal(cfg.HP_BAR.GHOST_DRAIN, 0.45)
		local bar = HpBarRules.new(1)
		HpBarRules.set(bar, 0.6, 10, cfg)
		local fill, ghost = HpBarRules.sample(bar, 10, cfg)
		expect.equal(fill, 0.6)
		expect.equal(ghost, 1)
		fill, ghost = HpBarRules.sample(bar, 10.3, cfg)
		expect.equal(ghost, 1, "still holding")
		_, ghost = HpBarRules.sample(bar, 10.575, cfg)
		expect.near(ghost, 0.9, 1e-9, "eases in: a quarter of the way at half time")
		_, ghost = HpBarRules.sample(bar, 10.8, cfg)
		expect.near(ghost, 0.6, 1e-9)
		_, ghost = HpBarRules.sample(bar, 20, cfg)
		expect.equal(ghost, 0.6)
	end,

	["a second hit while the ghost drains keeps it where it is and holds again"] = function()
		local bar = HpBarRules.new(1)
		HpBarRules.set(bar, 0.6, 10, cfg)
		HpBarRules.set(bar, 0.4, 10.575, cfg)
		local fill, ghost = HpBarRules.sample(bar, 10.6, cfg)
		expect.equal(fill, 0.4)
		expect.near(ghost, 0.9, 1e-9)
		_, ghost = HpBarRules.sample(bar, 10.575 + 0.8, cfg)
		expect.near(ghost, 0.4, 1e-9)
	end,

	["a heal moves the pale lead ahead at once and the fill rises to it"] = function()
		expect.equal(cfg.HP_BAR.HEAL_RISE, 0.5)
		local bar = HpBarRules.new(0.4)
		HpBarRules.set(bar, 0.7, 5, cfg)
		local fill, ghost, flash, healing = HpBarRules.sample(bar, 5, cfg)
		expect.equal(ghost, 0.7)
		expect.equal(fill, 0.4)
		expect.equal(flash, 0, "heals don't flash")
		expect.equal(healing, true)
		fill = HpBarRules.sample(bar, 5.25, cfg)
		expect.near(fill, 0.625, 1e-9, "eases out: three quarters of the way at half time")
		fill = HpBarRules.sample(bar, 5.5, cfg)
		expect.near(fill, 0.7, 1e-9)
	end,

	["a hit flashes the bar white for a moment"] = function()
		local bar = HpBarRules.new(1)
		HpBarRules.set(bar, 0.9, 3, cfg)
		local _, _, flash, healing = HpBarRules.sample(bar, 3, cfg)
		expect.equal(flash, 1)
		expect.equal(healing, false)
		_, _, flash = HpBarRules.sample(bar, 3 + cfg.HP_BAR.FLASH, cfg)
		expect.equal(flash, 0)
	end,

	["the same share again changes nothing"] = function()
		local bar = HpBarRules.new(0.5)
		HpBarRules.set(bar, 0.5, 1, cfg)
		local _, _, flash = HpBarRules.sample(bar, 1, cfg)
		expect.equal(flash, 0)
		expect.equal(HpBarRules.settled(bar, 1, cfg), true)
	end,

	["settled once the ghost and the fill stop moving"] = function()
		local bar = HpBarRules.new(1)
		expect.equal(HpBarRules.settled(bar, 0, cfg), true)
		HpBarRules.set(bar, 0.5, 2, cfg)
		expect.equal(HpBarRules.settled(bar, 2.5, cfg), false)
		expect.equal(HpBarRules.settled(bar, 2.81, cfg), true)
	end,

	["shares are kept between 0 and 1"] = function()
		local bar = HpBarRules.new(1.5)
		local fill = HpBarRules.sample(bar, 0, cfg)
		expect.equal(fill, 1)
		HpBarRules.set(bar, -0.2, 1, cfg)
		fill = HpBarRules.sample(bar, 1, cfg)
		expect.equal(fill, 0)
	end,

	["a bigger hit flashes the screen's edges harder"] = function()
		expect.near(HpBarRules.flashPeak(12, 100, cfg), 0.59, 1e-9)
		expect.near(HpBarRules.flashPeak(1, 100, cfg), 0.37, 1e-9)
		expect.equal(HpBarRules.flashPeak(40, 100, cfg), 1)
		expect.equal(HpBarRules.flashPeak(5, 0, cfg), cfg.HIT_FLASH.MIN)
	end,

	["the edge flash fades out over its seconds"] = function()
		expect.equal(cfg.HIT_FLASH.SECONDS, 0.55)
		expect.near(HpBarRules.edgeAlpha(4, 4, 0.8, 1, false, cfg), 0.8, 1e-9)
		expect.near(HpBarRules.edgeAlpha(4 + 0.275, 4, 0.8, 1, false, cfg), 0.2, 1e-9, "eases out")
		expect.near(HpBarRules.edgeAlpha(4 + 0.55, 4, 0.8, 1, false, cfg), 0, 1e-9)
		expect.equal(HpBarRules.edgeAlpha(0, -math.huge, 0, 1, false, cfg), 0, "never hit")
	end,

	-- owner 2026-11-12: "an indication that I or my pet are low on health. like a heartbeat sound and more agressive red
	-- flashes": the edges beat like a heart (two thumps a beat), harder than the old soft pulse
	["below 30% HP the edges beat like a heart, never while down"] = function()
		local flash = cfg.HIT_FLASH
		expect.equal(flash.LOW_SHARE, 0.3)
		expect.equal(flash.PULSE_MAX >= 0.7, true, "an aggressive red, not the old soft 0.45")
		local period = HpBarRules.beatSeconds(0.2, cfg)
		local function at(t: number): number
			return HpBarRules.edgeAlpha(t * period, -math.huge, 0, 0.2, false, cfg)
		end
		expect.near(at(0), flash.PULSE_MIN, 1e-9, "a beat starts from the rest")
		expect.near(at(flash.THUMP / 2), flash.PULSE_MAX, 1e-9, "the first thump's peak")
		expect.near(at(flash.SECOND_AT + flash.THUMP / 2), flash.PULSE_MIN + (flash.PULSE_MAX - flash.PULSE_MIN) * flash.SECOND_SHARE, 1e-9, "the second, softer")
		expect.near(at(0.75), flash.PULSE_MIN, 1e-9, "a rest till the next beat")
		expect.equal(HpBarRules.edgeAlpha(period / 2, -math.huge, 0, 0.3, false, cfg), 0, "at 30% exactly")
		expect.equal(HpBarRules.edgeAlpha(period / 2, -math.huge, 0, 0.2, true, cfg), 0, "down")
	end,

	["critical (below 15%) beats faster"] = function()
		local flash = cfg.HIT_FLASH
		expect.equal(HpBarRules.beatSeconds(0.25, cfg), flash.PULSE_SECONDS)
		expect.equal(HpBarRules.beatSeconds(0.1, cfg), flash.CRITICAL_SECONDS)
		expect.equal(flash.CRITICAL_SECONDS < flash.PULSE_SECONDS, true)
	end,

	["each beat counts once for its sound, none above 30% or while down"] = function()
		local period = HpBarRules.beatSeconds(0.2, cfg)
		expect.equal(HpBarRules.beatIndex(10, 0.5, false, cfg), nil, "healthy: no heartbeat")
		expect.equal(HpBarRules.beatIndex(10, 0.2, true, cfg), nil, "down: no heartbeat")
		local first = HpBarRules.beatIndex(period * 3.1, 0.2, false, cfg)
		expect.equal(HpBarRules.beatIndex(period * 3.9, 0.2, false, cfg), first, "one beat")
		expect.equal(HpBarRules.beatIndex(period * 4.05, 0.2, false, cfg), (first :: number) + 1, "the next")
	end,

	["the warning follows the lowest of you and your standing creatures"] = function()
		expect.equal(HpBarRules.lowestShare(0.8, { 0.2, 0.9 }), 0.2, "your creature is low")
		expect.equal(HpBarRules.lowestShare(0.1, { 0.9 }), 0.1, "you are low")
		expect.equal(HpBarRules.lowestShare(0.8, { 0 }), 0.8, "a fainted creature doesn't count")
		expect.equal(HpBarRules.lowestShare(nil, { 0.5 }), 0.5, "no sword: only creatures")
		expect.equal(HpBarRules.lowestShare(nil, {}), 1, "nothing to watch")
	end,

	["a hit over the pulse shows whichever is stronger"] = function()
		expect.near(HpBarRules.edgeAlpha(0, 0, 0.9, 0.2, false, cfg), 0.9, 1e-9)
		local late = cfg.HIT_FLASH.SECONDS * 0.9
		expect.near(HpBarRules.edgeAlpha(late, 0, 0.9, 0.2, false, cfg), HpBarRules.edgeAlpha(late, -math.huge, 0, 0.2, false, cfg), 1e-9)
	end,

	["the portrait shakes for a quarter second, then rests"] = function()
		local shake = cfg.PORTRAIT.SHAKE
		expect.equal(shake.seconds, 0.25)
		local x, y = HpBarRules.shake(1, 1, cfg)
		expect.equal(x, 0)
		expect.equal(y, 0)
		x, y = HpBarRules.shake(1 + 0.25 * 0.2, 1, cfg)
		expect.near(x, shake.offsets[1][1], 1e-9)
		expect.near(y, shake.offsets[1][2], 1e-9)
		x = HpBarRules.shake(1 + 0.25 * 0.3, 1, cfg)
		expect.near(x, (shake.offsets[1][1] + shake.offsets[2][1]) / 2, 1e-9, "between two keys")
		x, y = HpBarRules.shake(1.3, 1, cfg)
		expect.equal(x, 0)
		expect.equal(y, 0)
	end,
}
