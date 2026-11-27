--!strict
-- Owner 2026-11-21: "On tutorials: make the highlight more noticeable, also make it fit the shape of what it is
-- highlighting. also make the pawprint more noticeable." The gold ring (and the spotlight's hole) take the corner of
-- the thing they're on: a round button gets a round ring, a pill a pill, a tile its own rounding; a second ring pings
-- outward; the paws are bigger with a dark backing so they show on light floors and walls.
local CueShape = require("../src/shared/Util/CueShape")
local Cues = require("../src/shared/Config/Cues")
local UIIcons = require("../src/shared/Config/UIIcons")
local expect = require("./lib/expect")

return {
	-- Owner 2026-11-27 ("Maybe just use arrows instead of paws. to be simple", picks B and 1; spec
	-- 2026-11-27-tutorial-arrows-design): the chunky gold arrow and the ground chevron, made by
	-- tools/ui-icons/make_cue_arrows.py
	["the arrows' pictures are uploaded"] = function()
		for _, name in { "ArrowCue", "Chevron" } do
			local id = (UIIcons :: any)[name]
			assert(typeof(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, `{name} is uploaded`)
		end
	end,

	["the ring takes the shape of what it's on"] = function()
		local pad = 5 -- how far off the ring stands (CueShape.pad: the thing's outline plus RING.gap)
		expect.equal(CueShape.radius({ w = 52, h = 52 }, { scale = 0.5, offset = 0 }, pad, Cues.RING.fallback), 26 + pad, "a round button: a round ring")
		expect.equal(CueShape.radius({ w = 200, h = 48 }, { scale = 0.5, offset = 0 }, pad, Cues.RING.fallback), 24 + pad, "a pill: a pill")
		expect.equal(CueShape.radius({ w = 72, h = 72 }, { scale = 0, offset = 22 }, pad, Cues.RING.fallback), 22 + pad, "a tile: its own rounding")
		expect.equal(CueShape.radius({ w = 40, h = 30 }, { scale = 0, offset = 99 }, pad, Cues.RING.fallback), 15 + pad, "never rounder than the thing itself")
		expect.equal(CueShape.radius({ w = 120, h = 60 }, nil, pad, Cues.RING.fallback), Cues.RING.fallback, "no rounding found: the old corner")
		expect.equal(CueShape.radius({ w = 120, h = 60 }, { scale = 0, offset = 0 }, pad, Cues.RING.fallback), pad, "a square thing: a nearly square ring")
		expect.equal(CueShape.radius({ w = 0, h = 0 }, { scale = 0.5, offset = 0 }, pad, Cues.RING.fallback), pad, "nothing there yet")
	end,

	["which piece of a button holds its shape: its own corner, else a face that fills it"] = function()
		local target = { w = 72, h = 72 }
		expect.equal(CueShape.fills({ w = 72, h = 72 }, target), true, "its face")
		expect.equal(CueShape.fills({ w = 66, h = 64 }, target), true, "a face a little inside it")
		expect.equal(CueShape.fills({ w = 22, h = 22 }, target), false, "a key cap in its corner")
		expect.equal(CueShape.fills({ w = 130, h = 130 }, target), false, "a glow far bigger than it")
		expect.equal(CueShape.fills({ w = 72, h = 18 }, target), false, "its label")
	end,

	["a second ring pings outward and fades, again and again"] = function()
		local ping = Cues.PING
		local grow0, fade0 = CueShape.ping(0, ping)
		expect.equal(grow0, 0)
		assert(fade0 < 0.3, "starts clear to see")
		local growEnd, fadeEnd = CueShape.ping(ping.period * 0.999, ping)
		assert(growEnd > ping.grow * 0.95 and fadeEnd > 0.95, "ends wide and gone")
		local growMid = CueShape.ping(ping.period * 0.5, ping)
		assert(growMid > 0 and growMid < ping.grow, "growing in between")
		expect.equal(CueShape.ping(ping.period * 2, ping), 0, "and starts over")
	end,

	["more noticeable than before"] = function()
		assert(Cues.RING.thickness > 4, "a thicker ring (4 px before)")
		assert(Cues.PAW.size > 64 and Cues.PAW.min > 40, "a bigger bouncing paw (64 / 40 before)")
		assert(Cues.PRINT.px > 46 and Cues.PRINT.min > 16, "bigger paw prints (46 / 16 before)")
		assert(Cues.PRINT.dim < 0.55, "paw prints never as faint as before (0.55)")
		assert(Cues.PAW.back > 1 and Cues.PAW.back <= 1.4, "a dark backing a little bigger than the paw")
		assert(Cues.PAW.min >= 44, "still clear on a small button")
	end,
	-- Found 2026-11-21 with the Phone under the gift's tile: the paw over the Phone sat on the gift. A tile in the left
	-- side column gets its paw on its right, pointing left
	["a tile in the left column is pointed at from its right side"] = function()
		expect.equal(CueShape.pawSide({ x = 8, w = 96 }, 1891, Cues.PAW.sideShare), "right", "the Phone's tile at the left edge")
		expect.equal(CueShape.pawSide({ x = 843, w = 96 }, 1891, Cues.PAW.sideShare), "above", "a tile at the bottom centre")
		expect.equal(CueShape.pawSide({ x = 600, w = 680 }, 1891, Cues.PAW.sideShare), "above", "a window's button")
		expect.equal(CueShape.pawSide({ x = 8, w = 96 }, 0, Cues.PAW.sideShare), "above", "no screen size yet")
		assert(Cues.PAW.sideShare > 0.05 and Cues.PAW.sideShare < 0.2, "only what hugs the left edge")
	end,
	-- owner 2026-11-20 (the Phone's tile on a computer, where the HUD is drawn bigger): "the highight border doesnt fit
	-- the tile. check it and make sure every highlighted elements fit the highlight border". A corner given in px is
	-- drawn times the thing's scale, and the ring sits just outside the thing's own outline
	["the ring fits a scaled thing: its corner grows with the scale, and it hugs the thing's own outline"] = function()
		local pad = 4
		expect.near(CueShape.radius({ w = 98.6, h = 98.6 }, { scale = 0, offset = 22 }, pad, Cues.RING.fallback, 1.37), 22 * 1.37 + pad, 1e-6, "a tile drawn 1.37 times bigger: its corner is too")
		expect.equal(CueShape.radius({ w = 72, h = 72 }, { scale = 0, offset = 22 }, pad, Cues.RING.fallback, 1), 22 + pad, "not scaled: as before")
		expect.equal(CueShape.radius({ w = 52, h = 52 }, { scale = 0.5, offset = 0 }, pad, Cues.RING.fallback, 1.37), 26 + pad, "a round thing stays round: its corner is a share of its drawn size")
		expect.near(CueShape.pad(3, 1.37, Cues.RING), 3 * 1.37 + Cues.RING.gap, 1e-6, "just outside its white outline, drawn bigger too")
		expect.equal(CueShape.pad(nil, 1, Cues.RING), Cues.RING.gap, "no outline: right on its edge")
		assert(Cues.RING.gap >= 1 and Cues.RING.gap <= 4, "hugging: no band of background between the thing and its ring")
	end,
}
