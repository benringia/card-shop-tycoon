--!strict
-- Owner 2026-11-21 (launch day): the quest strip "increase font size. its small on the laptops" and the party dock
-- "also make this bigger on desktop". The HUD's scale only ever shrank (1 at 560 px tall and up), so on a laptop or a
-- monitor it stayed phone-sized. These pieces now grow with the screen on a mouse-and-keyboard screen.
local HudGrow = require("../src/shared/Util/HudGrow")
local Config = require("../src/shared/Config/HudGrow")
local expect = require("./lib/expect")

return {
	["a desktop's HUD pieces grow with the screen's height, up to a cap"] = function()
		expect.equal(HudGrow.scale(Config.REFERENCE, false, Config), 1, "at the reference height: as before")
		assert(HudGrow.scale(620, false, Config) > 1.05, "a small laptop window: a little bigger")
		assert(HudGrow.scale(720, false, Config) > 1.2, "a laptop: clearly bigger")
		expect.equal(HudGrow.scale(1080, false, Config), Config.MAX, "a monitor: the cap")
		expect.equal(HudGrow.scale(4000, false, Config), Config.MAX)
		assert(HudGrow.scale(700, false, Config) > HudGrow.scale(650, false, Config), "taller: bigger")
	end,

	["never smaller than before, and a touch screen keeps its own sizes"] = function()
		expect.equal(HudGrow.scale(400, false, Config), 1, "a short window: no growth (the HUD's own shrink handles it)")
		expect.equal(HudGrow.scale(0, false, Config), 1)
		for _, height in { 320, 560, 720, 1080 } do
			expect.equal(HudGrow.scale(height, true, Config), 1, `touch at {height}: the phone's layout`)
		end
	end,

	["the cap keeps the dock and the strip from crowding the screen"] = function()
		assert(Config.MAX > 1.2 and Config.MAX <= 1.4, "bigger, never huge")
		assert(Config.REFERENCE >= 500 and Config.REFERENCE <= 600)
	end,
	-- Owner 2026-11-21, a little later: "increase overall font sizes for desktop. fontsizes are too small for laptops":
	-- every window (UIKit.panel) grows by the same share, but never past what fits the screen
	["a window grows like the HUD, as far as it fits the screen"] = function()
		local screen = { w = 1366, h = 710 }
		local small = HudGrow.window(1.35, { w = 460, h = 520 }, screen, Config)
		assert(small > 1.2 and small <= 1.35, "a small window grows")
		assert(520 * small <= screen.h * Config.WINDOW_FIT + 0.01, "and still fits the screen's height")
		local wide = HudGrow.window(1.35, { w = 1250, h = 400 }, screen, Config)
		assert(wide < 1.1 and 1250 * wide <= screen.w * Config.WINDOW_FIT + 0.01, "a wide one grows only as far as it fits")
		expect.equal(HudGrow.window(1.35, { w = 1300, h = 690 }, screen, Config), 1, "one that fills the screen stays as it is")
		expect.equal(HudGrow.window(1.35, { w = 2000, h = 900 }, screen, Config), 1, "never smaller than before")
		expect.equal(HudGrow.window(1, { w = 460, h = 520 }, screen, Config), 1, "no growth (a phone): as before")
		expect.equal(HudGrow.window(1.35, { w = 0, h = 0 }, screen, Config), 1, "a window with no size yet")
		expect.equal(HudGrow.window(1.35, { w = 460, h = 300 }, { w = 3840, h = 2000 }, Config), 1.35, "plenty of room: the full share")
		assert(Config.WINDOW_FIT > 0.85 and Config.WINDOW_FIT <= 0.98, "a margin round a grown window")
		expect.equal(Config.WINDOWS, true, "on (the switch to turn window growth off)")
	end,
	-- Owner 2026-11-21: "this window is going back to its small size when I hide then show it": folding the quest
	-- strip plays a small bump on it, which took the strip's one UIScale (the HUD's own, holding the desktop growth),
	-- set it to 1 and left it there. A piece's scale at rest is now written on it (Hud.scaleWith) and a bump starts
	-- and ends there.
	["a bump on a grown piece starts and ends at its grown size"] = function()
		expect.equal(HudGrow.rest(1.24), 1.24, "the size the HUD gave it")
		expect.equal(HudGrow.rest(nil), 1, "a piece the HUD doesn't scale")
		expect.equal(HudGrow.rest("big"), 1, "not a number")
		expect.equal(HudGrow.rest(0), 1, "never nothing")
		expect.equal(HudGrow.rest(-2), 1)
		local from, peak, back = HudGrow.bump(1.24, 1.04)
		expect.equal(from, 1.24)
		expect.equal(back, 1.24, "back where it was, not 1")
		assert(math.abs(peak - 1.24 * 1.04) < 1e-9, "a little bigger than its own size")
		assert(typeof(Config.ATTRIBUTE) == "string" and #Config.ATTRIBUTE > 0, "the attribute's name")
	end,
}
