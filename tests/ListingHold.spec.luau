--!strict
-- Owner 2026-11-17: "when you list a card on glass cases. it automatically list at 100% market. which sometimes would
-- instantly be bought by a customer before you can set a higher price". A new listing waits for its price: nobody can
-- buy it until the owner presses Done, closes the case's window, or the hold runs out.
local ListingHold = require("../src/server/Util/ListingHold")
local expect = require("./lib/expect")

local SECONDS = 120

local function sorted(list: { number }): string
	table.sort(list)
	return table.concat(list, ",")
end

return {
	["a new listing waits; the other slots don't"] = function()
		local holds = {}
		ListingHold.hold(holds, "caseA", 2, 10, SECONDS)
		expect.equal(ListingHold.isHeld(holds, "caseA", 2, 11), true, "the new card")
		expect.equal(ListingHold.isHeld(holds, "caseA", 1, 11), false, "a card already out")
		expect.equal(ListingHold.isHeld(holds, "caseB", 2, 11), false, "the same slot in another case")
	end,

	["the hold runs out on its own"] = function()
		local holds = {}
		ListingHold.hold(holds, "caseA", 1, 10, SECONDS)
		expect.equal(ListingHold.isHeld(holds, "caseA", 1, 10 + SECONDS - 0.1), true, "just before")
		expect.equal(ListingHold.isHeld(holds, "caseA", 1, 10 + SECONDS), false, "on time")
		expect.equal(next(holds), nil, "a run-out hold is forgotten")
	end,

	["Done lets one card go; closing the window lets the case go"] = function()
		local holds = {}
		ListingHold.hold(holds, "caseA", 1, 0, SECONDS)
		ListingHold.hold(holds, "caseA", 3, 0, SECONDS)
		ListingHold.hold(holds, "caseB", 1, 0, SECONDS)
		expect.equal(sorted(ListingHold.release(holds, "caseA", 3)), "3", "Done on slot 3")
		expect.equal(ListingHold.isHeld(holds, "caseA", 3, 1), false, "slot 3 on sale")
		expect.equal(ListingHold.isHeld(holds, "caseA", 1, 1), true, "slot 1 still waits")
		expect.equal(sorted(ListingHold.release(holds, "caseA", nil)), "1", "the window closed")
		expect.equal(ListingHold.isHeld(holds, "caseB", 1, 1), true, "another case keeps its hold")
		expect.equal(sorted(ListingHold.release(holds, "caseA", nil)), "", "nothing left to let go")
	end,

	["a price tap keeps a waiting card waiting, never holds one on sale"] = function()
		local holds = {}
		ListingHold.hold(holds, "caseA", 1, 0, SECONDS)
		expect.equal(ListingHold.refresh(holds, "caseA", 1, 100, SECONDS), true, "still pricing")
		expect.equal(ListingHold.isHeld(holds, "caseA", 1, 100 + SECONDS - 1), true, "the time starts again")
		expect.equal(ListingHold.refresh(holds, "caseA", 2, 100, SECONDS), false, "a card on sale stays on sale")
		expect.equal(ListingHold.isHeld(holds, "caseA", 2, 101), false, "slot 2")
	end,

	-- owner 2026-11-20: "glasscases: some players just add cards and doesnt press done. it should be considered done
	-- when the player walks away even if they did not press DONE"
	["walking away from the case is Done"] = function()
		local Showcase = { WALK_AWAY = 16 }
		expect.equal(ListingHold.away(4, Showcase.WALK_AWAY), false, "at the case")
		expect.equal(ListingHold.away(Showcase.WALK_AWAY, Showcase.WALK_AWAY), false, "still in reach")
		expect.equal(ListingHold.away(Showcase.WALK_AWAY + 0.1, Showcase.WALK_AWAY), true, "walked off")
		expect.equal(ListingHold.away(nil, Showcase.WALK_AWAY), true, "no character, or the case is gone")
	end,

	["the walk-away distance is past the case's prompt and the server's reach"] = function()
		-- Config/Showcase needs Roblox to load: its numbers are read from its text
		local source = require("@lune/fs").readFile("src/shared/Config/Showcase.luau")
		local Showcase = {
			WALK_AWAY = tonumber(string.match(source, "WALK_AWAY = ([%d%.]+)")) :: number,
			WALK_CHECK = tonumber(string.match(source, "WALK_CHECK = ([%d%.]+)")) :: number,
		}
		assert(Showcase.WALK_AWAY >= 14, "not while still pressing its buttons (Stock.INTERACT_DISTANCE 14)")
		assert(Showcase.WALK_AWAY <= 24, "a few steps, not across the shop")
		assert(Showcase.WALK_CHECK <= 1, "noticed within a second")
	end,
}
