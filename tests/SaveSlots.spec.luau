--!strict
-- The owner's test save (owner 2026-11-16: "is there anyway I can experience what new player experience without
-- wiping?"; their second account couldn't pass Roblox's age check): only the game's owner can switch to a separate,
-- fresh save and back; "reset" starts another fresh one; nobody else ever has a choice
local SaveSlots = require("../src/server/Util/SaveSlots")
local expect = require("./lib/expect")

return {
	["the real save keeps its key; a test save has its own per run"] = function()
		expect.equal(SaveSlots.key("Player_", 42, SaveSlots.clean(nil)), "Player_42")
		expect.equal(SaveSlots.key("Player_", 42, { test = true, run = 1 }), "Player_42_test1")
		expect.equal(SaveSlots.key("Player_", 42, { test = true, run = 3 }), "Player_42_test3")
		expect.equal(SaveSlots.key("Player_", 42, { test = false, run = 3 }), "Player_42", "back on the real save")
	end,

	-- 2026-11-16: Studio's checks were landing on the owner's live playthrough save; Studio's test save is its own
	["Studio's test save is its own, never the live test save; the real save is the real save"] = function()
		expect.equal(SaveSlots.key("Player_", 42, { test = true, run = 3 }, true), "Player_42_studio")
		expect.equal(SaveSlots.key("Player_", 42, { test = true, run = 3 }, false), "Player_42_test3")
		expect.equal(SaveSlots.key("Player_", 42, { test = false, run = 3 }, true), "Player_42", "main in Studio: the real save")
	end,

	-- 2026-11-25: a new player's first minutes played again and again (Pish's first steps): Studio's switch loads a
	-- brand-new save kept in memory and never written (ProfileStore's Mock); never outside Studio
	["Studio's fresh switch: a brand-new unsaved save, in Studio only"] = function()
		expect.equal(SaveSlots.fresh(true, true), true)
		expect.equal(SaveSlots.fresh(false, true), false, "never in the live game")
		expect.equal(SaveSlots.fresh(true, false), false)
		expect.equal(SaveSlots.fresh(true, nil), false)
	end,

	["a stored choice is checked"] = function()
		local none = SaveSlots.clean(nil)
		expect.equal(none.test, false)
		expect.equal(none.run, 1)
		local junk = SaveSlots.clean({ test = "yes", run = -4 })
		expect.equal(junk.test, false)
		expect.equal(junk.run, 1)
		local kept = SaveSlots.clean({ test = true, run = 5.7 })
		expect.equal(kept.test, true)
		expect.equal(kept.run, 5)
	end,

	["test, main and reset"] = function()
		local state = SaveSlots.clean(nil)
		local after, ok = SaveSlots.apply(state, "test")
		expect.equal(ok, true)
		expect.equal(after.test, true)
		expect.equal(after.run, 1)
		after = SaveSlots.apply(after, "main")
		expect.equal(after.test, false)
		after = SaveSlots.apply(after, "reset")
		expect.equal(after.test, true, "reset goes to a fresh test save")
		expect.equal(after.run, 2)
		local _, unknown = SaveSlots.apply(after, "wipe")
		expect.equal(unknown, false)
	end,

	["only the game's owner gets a choice"] = function()
		expect.equal(SaveSlots.isOwner(42, 42, "User"), true)
		expect.equal(SaveSlots.isOwner(7, 42, "User"), false)
		expect.equal(SaveSlots.isOwner(42, 42, "Group"), false, "a group's id is not a player")
		expect.equal(SaveSlots.isOwner(42, 0, "User"), false, "an unpublished place has no owner")
	end,
}
