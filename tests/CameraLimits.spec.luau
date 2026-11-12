--!strict
-- How far the camera zooms out (owner 2026-11-12: "should we restrict zooming out too much on camera?"; Roblox's
-- default is 128 studs): a closer cap everywhere, more room in boss fights (big bosses)
local CameraLimits = require("../src/shared/Config/CameraLimits")
local expect = require("./lib/expect")

return {
	["the camera zooms out less than Roblox's 128 studs, a boss fight a little further"] = function()
		expect.equal(CameraLimits.MAX_ZOOM >= 30 and CameraLimits.MAX_ZOOM < 128, true, "a closer cap")
		expect.equal(CameraLimits.BOSS_MAX_ZOOM > CameraLimits.MAX_ZOOM and CameraLimits.BOSS_MAX_ZOOM <= 100, true, "room for a big boss")
	end,
}
