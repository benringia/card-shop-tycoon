--!strict
-- Owner 2026-11-13: "when a player donates then clicks OK or even when clicking/pressing something in general, the
-- cinematic stops, make the cinematic start only after the player screen is clear. same with other cinematics."
-- (Util/ScreenClearRules: whether a cinematic may start now)
local ScreenClearRules = require("../src/shared/Util/ScreenClearRules")
local expect = require("./lib/expect")

local MAX = 120

return {
	["a cinematic waits while a purchase dialog or the Roblox menu is open"] = function()
		expect.equal(ScreenClearRules.clear({ promptSince = nil, menuOpen = false, now = 50 }, MAX), true, "nothing open")
		expect.equal(ScreenClearRules.clear({ promptSince = 40, menuOpen = false, now = 50 }, MAX), false, "the purchase dialog (its OK not pressed yet)")
		expect.equal(ScreenClearRules.clear({ promptSince = nil, menuOpen = true, now = 50 }, MAX), false, "the Roblox menu")
	end,

	["a purchase dialog that never reports closing stops holding cinematics after a while"] = function()
		expect.equal(ScreenClearRules.clear({ promptSince = 0, menuOpen = false, now = MAX - 1 }, MAX), false)
		expect.equal(ScreenClearRules.clear({ promptSince = 0, menuOpen = false, now = MAX + 1 }, MAX), true, "never stuck for good")
	end,
}
