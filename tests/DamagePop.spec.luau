--!strict
local DamagePop = require("../src/shared/Util/DamagePop")
local cfg = require("../src/shared/Config/AttackFx").NUMBERS
local expect = require("./lib/expect")

return {
	-- owner 2026-11-26 (pick B, "make the thorns subtle"): a Thorns reflect pops a normal-sized green number tagged
	-- THORNS over the foe, and fewer, smaller thorns than a Bloom attack's landing come out of the ground under it
	["a Thorns reflect: a green number tagged THORNS, subtle thorns under the foe"] = function()
		local AttackFx = require("../src/shared/Config/AttackFx")
		local thorns = AttackFx.THORNS
		expect.equal(thorns.tag, "THORNS")
		expect.equal(thorns.number, "normal", "never a crit-sized pop")
		expect.equal(#thorns.color, 3)
		expect.equal(thorns.spikes < AttackFx.THROW.ELEMENT.Bloom.count, true, "fewer thorns than a Bloom hit's")
		expect.equal(thorns.scale < 1, true, "and smaller")
		expect.equal(thorns.minScale <= thorns.maxScale, true)
	end,

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

	-- A boss's normal hit on your creature (owner 2026-11-18, pick C "hits you feel"): big, in the boss's colour
	["a boss's hit on your creature pops bigger than a strong hit and stays as long as a normal one"] = function()
		local boss = cfg.bossHit
		expect.equal(boss ~= nil, true, "the bossHit style exists")
		expect.equal(boss.peak > cfg.strong.peak, true, "bigger than a strong hit's")
		expect.equal(DamagePop.life("bossHit", cfg) >= DamagePop.life("normal", cfg), true, "stays as long")
		expect.near(DamagePop.at(boss.pop, "bossHit", cfg).scale, boss.peak, 1e-6, "it bursts to its peak")
	end,

	-- Element callouts (spec 2026-11-25-element-callouts-design; owner: "bigger"): a strong hit pops like a crit over a
	-- gold burst
	["a strong hit pops to a crit's peak, still under a boss's hit"] = function()
		expect.near(cfg.strong.peak, 2.1, 1e-9, "the felt size")
		expect.near(cfg.strong.peak, cfg.crit.peak, 1e-9, "a crit's")
		expect.equal(cfg.bossHit.peak > cfg.strong.peak, true, "a boss's hit stays the biggest")
	end,

	["the plain strong pop (a pylon's hit, a strong hit on your side) keeps the old size"] = function()
		local plain = cfg.strongPlain
		expect.equal(plain ~= nil, true, "the strongPlain style exists")
		expect.near(plain.peak, 1.75, 1e-9, "the strong peak before element callouts")
		expect.near(DamagePop.life("strongPlain", cfg), DamagePop.life("strong", cfg), 1e-9, "as long as a strong hit")
	end,

	-- The gold burst celebrates your strong hits; one on your own side is bad news, not a party
	["only a strong hit on your foes gets the big pop and burst"] = function()
		expect.equal(DamagePop.strongStyle("b:m", "a"), "strong", "your creature on the monster")
		expect.equal(DamagePop.strongStyle("b:add1", "a"), "strong", "on a boss's add")
		expect.equal(DamagePop.strongStyle("a:@123", "a"), "strongPlain", "the monster on you")
		expect.equal(DamagePop.strongStyle("a:beast", "a"), "strongPlain", "the monster on your creature")
		expect.equal(DamagePop.strongStyle("a:beast", "b"), "strong", "the arena: you on side b hit side a")
		expect.equal(DamagePop.strongStyle("b:beast", "b"), "strongPlain", "the arena: hit on your side b")
	end,

	["the strong burst's numbers"] = function()
		local burst = cfg.STRONG_BURST
		expect.equal(burst.rays, 12)
		expect.equal(burst.long.length, 64)
		expect.equal(burst.long.width, 11)
		expect.equal(burst.short.length, 44)
		expect.equal(burst.short.width, 7)
		expect.equal(burst.inner, 18)
		expect.equal(burst.disc, 70)
		expect.near(burst.discTransparency, 0.45, 1e-9)
		expect.equal(burst.color[1] == 255 and burst.color[2] == 196 and burst.color[3] == 64, true, "gold")
		expect.equal(#burst.fade, 3, "tip, middle, root")
	end,

	-- A GUI turns about its own middle: a ray anchored at the centre and turned bunched up on one side (the mockup's
	-- first try), so each ray's middle sits out along its angle
	["the burst's rays fan all the way round, long and short in turn"] = function()
		local burst = cfg.STRONG_BURST
		local rays = DamagePop.burstRays(burst)
		expect.equal(#rays, burst.rays)
		for index, ray in rays do
			local long = index % 2 == 1
			local spec = if long then burst.long else burst.short
			expect.equal(ray.length, spec.length, `ray {index} length`)
			expect.equal(ray.width, spec.width, `ray {index} width`)
			expect.near(ray.rotation, (index - 1) * 360 / burst.rays, 1e-9, `ray {index} turned`)
			local reach = burst.inner + spec.length / 2
			local angle = math.rad(ray.rotation)
			expect.near(ray.x, math.sin(angle) * reach, 1e-9, `ray {index} x`)
			expect.near(ray.y, -math.cos(angle) * reach, 1e-9, `ray {index} y (up is negative)`)
		end
		-- the first points straight up, the seventh straight down: round the whole centre
		expect.near(rays[1].x, 0, 1e-9)
		expect.equal(rays[1].y < 0, true, "up")
		expect.equal(rays[7].y > 0, true, "down")
	end,
}
