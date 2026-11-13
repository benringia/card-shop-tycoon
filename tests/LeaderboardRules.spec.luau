--!strict
-- The plaza leaderboard (owner 2026-11-13: "Remove roblox leaderboards on load, we will be adding a leaderboard in game
-- at the plaza for most cards opened"; "names of all time players across all servers and names of the players within
-- their server"): who's on each list, in what order, and when a player's total goes to the shared store
local LeaderboardRules = require("../src/shared/Util/LeaderboardRules")
local Leaderboard = require("../src/shared/Config/Leaderboard")
local Data = require("../src/shared/Config/Data")
local expect = require("./lib/expect")

local function names(list: { LeaderboardRules.Entry }): string
	local out = {}
	for _, entry in list do
		table.insert(out, entry.name)
	end
	return table.concat(out, ",")
end

return {
	["this server: everyone here, most packs first, a new player with none still listed"] = function()
		local list = LeaderboardRules.rank({
			{ userId = 1, name = "Ana", count = 5 },
			{ userId = 2, name = "Ben", count = 0 },
			{ userId = 3, name = "Cy", count = 40 },
		}, 10, true)
		expect.equal(names(list), "Cy,Ana,Ben")
	end,

	["ties go by name, then the list stops at its size"] = function()
		local list = LeaderboardRules.rank({
			{ userId = 1, name = "Zed", count = 7 },
			{ userId = 2, name = "Amy", count = 7 },
			{ userId = 3, name = "Max", count = 9 },
		}, 2, true)
		expect.equal(names(list), "Max,Amy")
		expect.equal(#LeaderboardRules.rank({}, 10, true), 0, "an empty server")
	end,

	["all time: the stored top, with players here now counted live, each once, nobody at zero"] = function()
		local stored = {
			{ userId = 1, name = "Ana", count = 100 },
			{ userId = 2, name = "Ben", count = 60 },
			{ userId = 3, name = "Cy", count = 50 },
		}
		local live = {
			{ userId = 2, name = "Ben", count = 120 }, -- opened more since the store was read
			{ userId = 4, name = "Dee", count = 55 },
			{ userId = 5, name = "Eve", count = 0 },
		}
		local list = LeaderboardRules.merge(stored, live, 3)
		expect.equal(names(list), "Ben,Ana,Dee", "Ben's live total, Dee climbs on, Cy drops off")
		expect.equal(list[1].count, 120)
		local stale = LeaderboardRules.merge({ { userId = 9, name = "Old", count = 30 } }, { { userId = 9, name = "New", count = 10 } }, 3)
		expect.equal(stale[1].count, 30, "the higher total wins")
		expect.equal(stale[1].name, "New", "the live name (a renamed player)")
	end,

	["a total goes to the store when it's above zero and changed"] = function()
		expect.equal(LeaderboardRules.shouldWrite(12, nil), true, "first time: existing totals reach the board")
		expect.equal(LeaderboardRules.shouldWrite(12, 12), false, "unchanged")
		expect.equal(LeaderboardRules.shouldWrite(13, 12), true)
		expect.equal(LeaderboardRules.shouldWrite(0, nil), false, "not loaded yet, or nothing opened")
	end,

	["counts read with thousands separators"] = function()
		expect.equal(LeaderboardRules.countText(7), "7")
		expect.equal(LeaderboardRules.countText(1234), "1,234")
		expect.equal(LeaderboardRules.countText(1234567), "1,234,567")
	end,

	["the store resets with the save data, and the board keeps within Roblox's limits"] = function()
		expect.equal(Leaderboard.storeName(Data.STORE_NAME), `{Data.STORE_NAME}_PacksOpened`)
		assert(Leaderboard.TOP >= 5 and Leaderboard.TOP <= 10, "a readable list")
		assert(Leaderboard.READ_EVERY >= 60, "GetSortedAsync is limited per minute")
		assert(Leaderboard.WRITE_EVERY >= 30, "a write per player at most every half minute")
	end,

	-- Owner 2026-11-13, pick A: each list a giant card, the top three on a podium in its art window, the rest in its
	-- text box
	["a list card holds the whole top: three on the podium, the rest as rows that fit its text box"] = function()
		local face = Leaderboard.FACE
		expect.equal(face.podium, 3)
		local panel = face.height * face.inset[2]
		local box = panel * (1 - face.art) - face.boxPad * 2
		assert((Leaderboard.TOP - face.podium) * face.rowHeight <= box, "the rows overflow the text box")
		for _, list in { "allTime", "server" } do
			assert(face.lists[list] and face.lists[list].title ~= "", `{list} has a title`)
		end
	end,
}
