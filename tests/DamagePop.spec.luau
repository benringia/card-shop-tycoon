--!strict
local DamagePop = require("../src/shared/Util/DamagePop")
local cfg = require("../src/shared/Config/AttackFx").NUMBERS
local expect = require("./lib/expect")

return {
	["a number bursts in big, then settles"] = function()
		local start = DamagePop.at(0, "normal", cfg)
		expect.equal(start.scale < 1, true, "starts small")
		local peak = DamagePop.at(cfg.normal.pop, "normal", cfg)
		expect.near(peak.scale, cfg.normal.peak, 1e-9, "the peak at the end of the pop")
		local settled = DamagePop.at(cfg.normal.pop + cfg.settle, "normal", cfg)
		expect.near(settled.scale, 1, 1e-9, "then back to its size")
	end,

	["it rises and fades out at the end"] = function()
		local life = DamagePop.life("normal", cfg)
		expect.equal(DamagePop.at(0, "normal", cfg).rise, 0)
		expect.equal(DamagePop.at(life * 0.5, "normal", cfg).rise > 0, true)
		expect.near(DamagePop.at(life, "normal", cfg).rise, cfg.normal.rise, 1e-9, "full rise at the end")
		expect.equal(DamagePop.at(life * 0.3, "normal", cfg).alpha, 1, "solid early on")
		expect.near(DamagePop.at(life, "normal", cfg).alpha, 0, 1e-9, "gone at the end")
	end,

	["criticals are bigger, last longer and wiggle"] = function()
		expect.equal(cfg.crit.peak > cfg.normal.peak, true)
		expect.equal(DamagePop.life("crit", cfg) > DamagePop.life("normal", cfg), true)
		local wiggle = DamagePop.at(cfg.crit.pop + cfg.settle * 0.5, "crit", cfg).rotation
		expect.equal(math.abs(wiggle) > 0, true, "a crit tilts while it settles")
		expect.equal(DamagePop.at(cfg.normal.pop + cfg.settle * 0.5, "normal", cfg).rotation, 0, "a normal one doesn't")
	end,

	["every style has its numbers, unknown ones play as normal"] = function()
		for _, style in { "normal", "crit", "strong", "weak", "heal", "tick" } do
			expect.equal(cfg[style] ~= nil, true, style)
			expect.equal(DamagePop.life(style, cfg) > 0, true, style)
		end
		expect.equal(DamagePop.life("nope", cfg), DamagePop.life("normal", cfg))
	end,
}
