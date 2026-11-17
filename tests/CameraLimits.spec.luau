--!strict
-- How far the camera zooms out (owner 2026-11-12: "should we restrict zooming out too much on camera?"; Roblox's
-- default is 128 studs): a closer cap everywhere, more room in boss fights (big bosses)
local CameraLimits = require("../src/shared/Config/CameraLimits")
local expect = require("./lib/expect")

return {
	-- owner 2026-11-17: "When battle starts, zoom out to the max (we set this earlier around 40 something)"
	["a phone's fight pulls the camera out within each fight's cap: the max in a wild fight, 40-odd for a boss"] = function()
		local zoom = CameraLimits.FIGHT_ZOOM
		expect.equal(zoom.wild, CameraLimits.MAX_ZOOM, "a wild fight: out to the cap")
		assert(zoom.boss >= 40 and zoom.boss < 50, "a boss fight: the 40-odd studs the owner remembers")
		assert(zoom.boss <= CameraLimits.BOSS_MAX_ZOOM, "within the boss cap (the player can still zoom to it)")
		assert(zoom.holdSeconds > 0 and zoom.holdSeconds < 1, "the zoom's floor is only held a moment")
		-- a boss's intro takes the camera a moment after the fight starts (BattleController waits up to 2 s for the boss to
		-- arrive): the zoom waits for it to take the camera and give it back, or the hand-back undoes it
		assert(zoom.introTakes > 2 and zoom.introTakes < zoom.waitSeconds, "time for the intro to take the camera")
	end,

	["a phone's wild fight looks down over you (your pet and the monster in view); never past a wall behind you"] = function()
		local zoom = CameraLimits.FIGHT_ZOOM
		assert(zoom.wildPitch >= 30 and zoom.wildPitch <= 45, "an action game's angle, not straight down")
		-- a boss arena starts you with your back to its fence and the boss 30 studs ahead: looking down pushes the boss off
		-- the top of a phone's screen, so a boss fight keeps the angle its intro hands back (FightTouchController)
		-- the trees and the exit portal past an arena's fence hide the fight: it stops short of a wall
		assert(zoom.wallMargin > 0 and zoom.wallMargin < 5, "a little room kept in front of a wall")
		-- a camera already past the fence (zoomed out by an earlier fight) comes in to it, but never nearer than `nearest`:
		-- the Meadow Warden's arena starts you 16 studs in front of its exit portal, so it must sit in front of it
		assert(zoom.nearest >= 10 and zoom.nearest < 16, "in front of the portal, not on your head")
	end,

	["the camera zooms out less than Roblox's 128 studs, a boss fight a little further"] = function()
		-- owner 2026-11-15: about 25 studs ("make zoomout limited to about this size"), still far enough to see round you
		expect.equal(CameraLimits.MAX_ZOOM >= 20 and CameraLimits.MAX_ZOOM <= 30, true, "a close cap")
		expect.equal(CameraLimits.BOSS_MAX_ZOOM > CameraLimits.MAX_ZOOM and CameraLimits.BOSS_MAX_ZOOM <= 100, true, "room for a big boss")
	end,
}
