--!strict
local BinderGesture = require("../src/shared/Util/BinderGesture")
local expect = require("./lib/expect")
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local equal = expect.equal
local TAP = 10

return {
	["a second finger during a press is refused, and the first finger's lift still ends it"] = function()
		local gesture = BinderGesture.new()
		local accepted = BinderGesture.press(gesture, "finger1", 100, 100, 0)
		equal(accepted, true, "first finger takes the gesture")
		equal(BinderGesture.press(gesture, "finger2", 300, 100, 0.2), false, "second finger refused")
		expect.isNil(BinderGesture.release(gesture, "finger2"), "second finger's lift ends nothing")
		local ended = BinderGesture.release(gesture, "finger1")
		equal(ended ~= nil and ended.id, "finger1", "first finger's lift ends its press")
		equal(BinderGesture.active(gesture), false, "free again")
	end,
	["moves from other pointers don't move the gesture"] = function()
		local gesture = BinderGesture.new()
		BinderGesture.press(gesture, "finger1", 100, 100, 0)
		equal(BinderGesture.move(gesture, "finger2", 400, 100), false, "not the owner")
		equal(BinderGesture.move(gesture, "finger1", 104, 100), true, "the owner")
		local ended = BinderGesture.release(gesture, "finger1")
		equal(ended and ended.x, 104, "last position kept")
	end,
	["a lost release: the same pointer pressing again ends the stale press first"] = function()
		local gesture = BinderGesture.new()
		BinderGesture.press(gesture, "mouse", 100, 100, 0)
		-- the mouse was let go outside the window: no release came
		local accepted, stale = BinderGesture.press(gesture, "mouse", 200, 200, 3)
		equal(accepted, true, "the new press is taken")
		equal(stale ~= nil and stale.startX, 100, "the stale press comes back to be ended")
		local ended = BinderGesture.release(gesture, "mouse")
		equal(ended and ended.startX, 200, "the new press is the live one")
	end,
	["a hold only shows while the finger hasn't moved (a slow swipe is a swipe)"] = function()
		local gesture = BinderGesture.new()
		BinderGesture.press(gesture, "finger1", 100, 100, 0)
		equal(BinderGesture.canHold(gesture, "finger1", TAP), true, "still: a hold")
		BinderGesture.move(gesture, "finger1", 106, 102)
		equal(BinderGesture.canHold(gesture, "finger1", TAP), true, "a little wobble is still a hold")
		BinderGesture.move(gesture, "finger1", 140, 100)
		equal(BinderGesture.canHold(gesture, "finger1", TAP), false, "moved: no hold")
		BinderGesture.move(gesture, "finger1", 100, 100)
		equal(BinderGesture.canHold(gesture, "finger1", TAP), false, "coming back doesn't make it a hold again")
		equal(BinderGesture.canHold(gesture, "finger2", TAP), false, "another finger can't hold it")
	end,
	["cancel frees the gesture (window focus lost, binder closed)"] = function()
		local gesture = BinderGesture.new()
		BinderGesture.press(gesture, "finger1", 100, 100, 0)
		local cancelled = BinderGesture.cancel(gesture)
		equal(cancelled ~= nil and cancelled.id, "finger1", "the cancelled press comes back")
		equal(BinderGesture.active(gesture), false, "free")
		expect.isNil(BinderGesture.release(gesture, "finger1"), "its late lift ends nothing")
		equal(BinderGesture.press(gesture, "finger2", 50, 50, 1), true, "a new press is taken")
		expect.isNil(BinderGesture.cancel(BinderGesture.new()), "nothing to cancel")
	end,
	["every rule exists as soon as the module loads (none nested inside another)"] = function()
		local fresh = luau.load(luau.compile(fs.readFile("src/shared/Util/BinderGesture.luau")), { debugName = "BinderGesture" })()
		for _, name in { "new", "press", "move", "release", "canHold", "cancel", "active" } do
			equal(typeof(fresh[name]), "function", name)
		end
	end,
}
