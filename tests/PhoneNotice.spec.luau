--!strict
-- Owner 2026-11-21: "can we just put the quests inside phone and just add a noticeable notification on the phone
-- everytime there's some changes to the quest or anything that is inside the phone." On a computer the quests are a
-- Phone app; the Phone's tile wears a red count of what waits inside (a quest to claim, a chest, a build you can
-- afford, an unread review) and moves when something in it changes: a ping when the count rises, a nudge for progress.
local PhoneNotice = require("../src/shared/Util/PhoneNotice")
local expect = require("./lib/expect")

local function quest(id: string, progress: number, goal: number, claimed: boolean?): any
	return { id = id, kind = "sell", text = id, icon = "Coin", goal = goal, progress = progress, done = progress >= goal, claimed = claimed == true, cash = 1, xp = 1 }
end

local function view(quests: { any }, bonusReady: boolean?, week: any?): any
	local claimable = 0
	for _, entry in quests do
		if entry.done and not entry.claimed then
			claimable += 1
		end
	end
	if bonusReady then
		claimable += 1
	end
	return { quests = quests, bonusReady = bonusReady == true, bonusClaimed = false, claimable = claimable, week = week }
end

return {
	["the Quests app counts what waits to be taken"] = function()
		expect.equal(PhoneNotice.quests(nil, false), 0, "no quests yet")
		expect.equal(PhoneNotice.quests(view({ quest("a", 1, 5), quest("b", 2, 5) }), false), 0, "nothing finished")
		expect.equal(PhoneNotice.quests(view({ quest("a", 5, 5), quest("b", 2, 5) }), false), 1, "one quest to claim")
		expect.equal(PhoneNotice.quests(view({ quest("a", 5, 5, true), quest("b", 5, 5, true) }, true), false), 1, "the day's chest")
		local week = view({ quest("w", 9, 9) }, true)
		expect.equal(PhoneNotice.quests(view({ quest("a", 5, 5) }, false, week), false), 2, "a quest and the Weekly Chest")
		expect.equal(PhoneNotice.quests(view({ quest("a", 1, 5) }), true), 1, "the main quest's build you can pay for")
	end,

	["the Phone's tile shows everything that waits inside it"] = function()
		expect.equal(PhoneNotice.total({ Quests = 2, Reviews = 3 }), 5)
		expect.equal(PhoneNotice.total({ Quests = 0, Reviews = 0 }), 0)
		expect.equal(PhoneNotice.total({}), 0)
		expect.equal(PhoneNotice.text(0), "", "nothing: no badge")
		expect.equal(PhoneNotice.text(3), "3")
		expect.equal(PhoneNotice.text(12), "9+", "never a number too wide for the badge")
	end,

	["something to take: a ping; progress only: a nudge; nothing new: nothing"] = function()
		expect.equal(PhoneNotice.kind(0, 1, true), "ping", "a quest just finished")
		expect.equal(PhoneNotice.kind(2, 3, false), "ping", "one more waits")
		expect.equal(PhoneNotice.kind(1, 1, true), "nudge", "a quest moved on")
		expect.isNil(PhoneNotice.kind(1, 1, false), "nothing changed")
		expect.isNil(PhoneNotice.kind(2, 1, false), "you took one: no fuss")
		expect.equal(PhoneNotice.kind(2, 1, true), "nudge", "took one while another moved on")
	end,

	["what counts as a change to the quests"] = function()
		local before = view({ quest("a", 1, 5), quest("b", 2, 5) })
		expect.equal(PhoneNotice.questsChanged(before, view({ quest("a", 2, 5), quest("b", 2, 5) })), true, "progress")
		expect.equal(PhoneNotice.questsChanged(before, view({ quest("a", 1, 5), quest("b", 2, 5) })), false, "the same again")
		expect.equal(PhoneNotice.questsChanged(before, view({ quest("c", 0, 5), quest("d", 0, 5) })), true, "a new day's quests")
		expect.equal(PhoneNotice.questsChanged(nil, before), false, "the first state after joining: no fuss")
		expect.equal(PhoneNotice.questsChanged(before, nil), false)
		local weekBefore = view({ quest("a", 1, 5) }, false, view({ quest("w", 1, 9) }))
		local weekAfter = view({ quest("a", 1, 5) }, false, view({ quest("w", 2, 9) }))
		expect.equal(PhoneNotice.questsChanged(weekBefore, weekAfter), true, "a weekly quest moved on")
	end,
	-- Found checking Pish's first visit after the quests moved into the Phone: the Phone's tile wore a count and pinged
	-- through a tour that hides the quests (the calm HUD). While a guide hides them the Quests app reports nothing
	["quiet while a guide hides the quests"] = function()
		local waiting = view({ quest("a", 5, 5), quest("b", 5, 5) })
		expect.equal(PhoneNotice.quests(waiting, true, true), 0, "hidden by a tour: no count")
		expect.equal(PhoneNotice.quests(waiting, true, false), 3, "the tour over: what waits")
		expect.equal(PhoneNotice.quests(waiting, true), 3, "not told: as before")
	end,
}
