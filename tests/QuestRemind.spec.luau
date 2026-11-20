--!strict
-- Owner 2026-11-21, with the quests moved into the Phone: "add something that always reminds players to check quests
-- specially when they are doing nothing. but not to the point that it is annoying." A small bubble by the Phone's tile
-- when the player has stood idle a while: what's waiting, or the quest nearest done. Never while they're busy, never
-- back to back, never when there's nothing left to do.
local QuestRemind = require("../src/shared/Util/QuestRemind")
local Quests = require("../src/shared/Config/Quests")
local expect = require("./lib/expect")

local R = Quests.REMIND

local function quest(text: string, progress: number, goal: number, claimed: boolean?): any
	return { id = text, kind = "shop", text = text, icon = "Pack", goal = goal, progress = progress, done = progress >= goal, claimed = claimed == true, cash = 75, xp = 75 }
end

local function view(quests: { any }, week: any?): any
	local claimable = 0
	for _, entry in quests do
		if entry.done and not entry.claimed then
			claimable += 1
		end
	end
	return { quests = quests, bonusReady = false, bonusClaimed = false, claimable = claimable, week = week }
end

return {
	["only after standing idle a while, and never back to back"] = function()
		local joined = 0
		local now = 1000
		expect.equal(QuestRemind.due(now, joined, now - R.idle, nil, R), true, "idle long enough, none yet")
		expect.equal(QuestRemind.due(now, joined, now - R.idle + 1, nil, R), false, "only just stopped")
		expect.equal(QuestRemind.due(now, joined, nil, nil, R), false, "busy or moving: never")
		expect.equal(QuestRemind.due(now, joined, now - 500, now - R.every + 1, R), false, "one came a moment ago")
		expect.equal(QuestRemind.due(now, joined, now - 500, now - R.every, R), true, "a long breather later")
		expect.equal(QuestRemind.due(R.first - 1, joined, 0, nil, R), false, "never in the first moments after joining")
		assert(R.idle >= 30, "a real pause, not a breath")
		assert(R.every >= 180, "minutes apart: not annoying")
		assert(R.show >= 4 and R.show <= 10, "up long enough to read, gone soon")
	end,

	["it says what waits first, then the quest nearest done"] = function()
		local claim = QuestRemind.words(view({ quest("Rip 8 packs", 8, 8), quest("Serve 6 customers", 1, 6) }), nil)
		assert(claim, "something to say")
		expect.equal(claim.text, "A quest is done! Claim it.")
		expect.equal(claim.strong, true, "something to take: the stronger nudge")
		local two = QuestRemind.words(view({ quest("Rip 8 packs", 8, 8), quest("Serve 6 customers", 6, 6) }), nil)
		expect.equal((two :: any).text, "2 quests are done! Claim them.")
		local build = QuestRemind.words(view({ quest("Rip 8 packs", 1, 8) }), "Forge")
		expect.equal((build :: any).text, "You can build the Forge!")
		expect.equal((build :: any).strong, true)
		local near = QuestRemind.words(view({ quest("Rip 8 packs", 2, 8), quest("Serve 6 customers", 5, 6), quest("Win 4 wild fights", 0, 4) }), nil)
		expect.equal((near :: any).text, "Quest: Serve 6 customers · 5 / 6", "the one nearest done")
		expect.equal((near :: any).icon, "Pack")
		expect.equal((near :: any).strong, false)
	end,

	["the week's quests when today's are finished, and nothing when all is done"] = function()
		local week = view({ quest("Rip 21 packs", 20, 21), quest("Win 14 wild fights", 3, 14) })
		local done = view({ quest("Rip 8 packs", 8, 8, true) }, week)
		expect.equal((QuestRemind.words(done, nil) :: any).text, "Weekly: Rip 21 packs · 20 / 21")
		local allDone = view({ quest("Rip 8 packs", 8, 8, true) }, view({ quest("Rip 21 packs", 21, 21) }))
		expect.isNil(QuestRemind.words(allDone, nil), "nothing left: no reminder")
		expect.isNil(QuestRemind.words(nil, nil), "no quests yet")
	end,

	["every line is short enough for its bubble"] = function()
		local long = QuestRemind.words(view({ quest("Level up creatures 3 times", 2, 3) }), nil)
		assert(#(long :: any).text <= R.maxLength, "fits")
		local build = QuestRemind.words(view({ quest("Rip 8 packs", 1, 8) }), "Collector Case")
		assert(#(build :: any).text <= R.maxLength)
	end,
}
