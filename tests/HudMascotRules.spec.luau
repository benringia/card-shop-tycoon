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
	end,
}
