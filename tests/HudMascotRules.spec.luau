--!strict
local HudMascotRules = require("../src/shared/Util/HudMascotRules")
local HudMascot = require("../src/shared/Config/HudMascot")
local expect = require("./lib/expect")

local CFG: any = {
	blink = { every = { 3, 7 }, seconds = 0.12 },
	duck = { down = 0.15, hold = 0.35, up = 0.3 },
	tap = { seconds = 0.35, scale = 0.12 },
	headroom = 40,
	images = { peek = "rbxassetid://1", tail = "" },
}

return {
	-- owner 2026-11-12: "move pish's icon to the right side of the party UI ... make the bubble come out of him"
	["on a PC he sits on the party bar's right end; on a phone its left end (the level pill sits over the right)"] = function()
		expect.equal(HudMascotRules.side(HudMascot, false), "right")
		expect.equal(HudMascotRules.side(HudMascot, true), "left")
		local width = HudMascot.size.peek[1]
		local right = HudMascotRules.layout(HudMascot, "right")
		expect.equal(right.fromRight, true, "measured from the bar's right edge")
		expect.near(right.sticker, -(HudMascot.offset.right + width), 1e-9, "his left edge, right offset plus his width in")
		expect.near(right.tail, right.sticker + HudMascot.tail.at[1], 1e-9, "the tail by his side, as on the left")
		expect.near(right.tap + HudMascot.tapArea.w / 2, right.sticker + width / 2, 1e-9, "the tap area centred on him")
		local left = HudMascotRules.layout(HudMascot, "left")
		expect.equal(left.fromRight, false)
		expect.near(left.sticker, HudMascot.offset.left, 1e-9)
		expect.equal(HudMascot.seat >= width - 16, true, "the bar keeps a seat for him on the right, clear of the third card")
	end,
	["blinks come 3-7 s apart"] = function()
		expect.equal(HudMascotRules.nextBlink(0, CFG), 3)
		expect.equal(HudMascotRules.nextBlink(1, CFG), 7)
		expect.equal(HudMascotRules.nextBlink(9, CFG), 7, "a roll out of range is clamped")
	end,

	["a duck goes down, holds, comes back up"] = function()
		expect.equal(HudMascotRules.duckShare(0, CFG), 0)
		expect.near(HudMascotRules.duckShare(0.15, CFG), 1, 1e-9)
		expect.equal(HudMascotRules.duckShare(0.3, CFG), 1, "holding")
		expect.near(HudMascotRules.duckShare(0.8, CFG), 0, 1e-9, "back up")
		expect.equal(HudMascotRules.duckShare(5, CFG), 0)
		local mid = HudMascotRules.duckShare(0.65, CFG)
		expect.equal(mid > 0 and mid < 1, true, "on its way up")
	end,

	["a duck restarted mid-way continues from where it is and ends fully up"] = function()
		local t = HudMascotRules.restartAt(0.5, CFG)
		expect.near(HudMascotRules.duckShare(t, CFG), 0.5, 1e-6)
		expect.near(HudMascotRules.duckShare(t + 10, CFG), 0, 1e-9)
		expect.equal(HudMascotRules.restartAt(0, CFG), 0)
	end,

	["a tap bounce swells and settles"] = function()
		expect.equal(HudMascotRules.bounce(0, CFG), 1)
		expect.near(HudMascotRules.bounce(0.175, CFG), 1.12, 1e-9)
		expect.equal(HudMascotRules.bounce(1, CFG), 1)
	end,

	["a duck goes far enough that a breathing, bouncing sticker still hides"] = function()
		local cfg = { breath = { scale = 0.03 }, tap = { scale = 0.12 } }
		expect.near(HudMascotRules.duckTravel(100, cfg :: any), 115, 1e-9)
	end,

	["no picture means no headroom"] = function()
		expect.equal(HudMascotRules.headroom(CFG), 40)
		expect.equal(HudMascotRules.headroom({ headroom = 40, images = { peek = "", tail = "" } } :: any), 0)
	end,

	["the game's mascot config is sane"] = function()
		local m = HudMascot
		for _, id in { m.images.peek, m.images.tail, m.voice.id } do
			expect.equal(id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil, true, id)
		end
		for _, eye in m.eyes do
			expect.equal(eye.x >= 0 and eye.y >= 0 and eye.x + eye.w <= 1 and eye.y + eye.h <= 1, true, "eyes inside the picture")
		end
		expect.equal(m.blink.every[1] > 0 and m.blink.every[2] >= m.blink.every[1], true)
		expect.equal(m.voice.volume > 0 and m.voice.volume <= 0.5, true, "quiet")
		-- Everything about this creature is config, so another one needs no code (spec goal, docs/hud-mascot.md)
		expect.equal(m.tapArea.w >= 48 / 0.7 and m.tapArea.h >= 48 / 0.7, true, "a finger-sized tap area at the smallest HUD scale (0.7)")
		expect.equal(typeof(m.tail.angle) == "number" and typeof(m.tail.at[1]) == "number" and typeof(m.tail.at[2]) == "number", true, "the tail's angle and spot")
		expect.equal(#m.crease == 3, true, "the closed eye's line colour")
		expect.equal(m.tilt.period > 0 and m.tilt.degrees > 0 and m.clipPad >= 0, true, "the breathing tilt and room round the sticker")
	end,
}
