--!strict
-- Daily quests (owner 2026-11-17: "yes do the three now"): three a day (one shop, one cards, one adventure; easier at a
-- low shop level), each paying cash and shop XP, and a bonus chest once all three are claimed. They reset each UTC day,
-- like the daily gift (GiftRules.dayOf).
local QuestRules = require("../src/shared/Util/QuestRules")
local Quests = require("../src/shared/Config/Quests")
local expect = require("./lib/expect")

local function entry(id: string): any
	for _, quest in Quests.POOL do
		if quest.id == id then
			return quest
		end
	end
	error(`no quest {id}`)
end

-- a day's three quests at `level`, rolled with the same numbers every time
local function rolled(level: number, rolls: { number }?): { QuestRules.Quest }
	return QuestRules.roll(Quests, level, rolls or { 0, 0, 0 })
end

return {
	["a day's quests: one of each kind, each unlocked at the shop's level, its goal from the level"] = function()
		for _, level in { 1, 3, 8, 20, 60 } do
			for _, roll in { 0, 0.5, 0.999 } do
				local list = rolled(level, { roll, roll, roll })
				expect.equal(#list, #Quests.KINDS, `{#Quests.KINDS} quests at level {level}`)
				for index, quest in list do
					local info = entry(quest.id)
					expect.equal(info.kind, Quests.KINDS[index], `quest {index} is a {Quests.KINDS[index]} quest`)
					assert((info.minLevel or 1) <= level, `{quest.id} is unlocked at level {level}`)
					assert(not info.maxLevel or level <= info.maxLevel, `{quest.id} isn't past its last level`)
					expect.equal(quest.goal, QuestRules.goalFor(info, level), `{quest.id}'s goal at level {level}`)
					expect.equal(quest.progress, 0, "nothing done yet")
					expect.equal(quest.claimed, false, "not claimed")
				end
			end
		end
		local again = rolled(8, { 0.3, 0.6, 0.9 })
		local same = rolled(8, { 0.3, 0.6, 0.9 })
		for index in again do
			expect.equal(again[index].id, same[index].id, "the same numbers roll the same quests")
		end
	end,

	["goals grow with the shop level"] = function()
		local serve = entry("serve")
		assert(QuestRules.goalFor(serve, 40) > QuestRules.goalFor(serve, 1), "a big shop serves more")
		local boss = entry("boss")
		for _, quest in rolled(1, { 0.99, 0.99, 0.99 }) do
			assert(quest.id ~= boss.id, "no boss quest before the bosses open")
		end
	end,

	["the same day keeps its quests; a new day rolls new ones and a fresh bonus"] = function()
		local state = QuestRules.refresh(QuestRules.fresh(), 100, Quests, 5, { 0, 0, 0 })
		expect.equal(state.day, 100)
		expect.equal(#state.list, #Quests.KINDS)
		state.list[1].progress = state.list[1].goal
		state.list[1].claimed = true
		state.bonus = true
		local later = QuestRules.refresh(state, 100, Quests, 9, { 0.9, 0.9, 0.9 })
		expect.equal(later.list[1].claimed, true, "today's progress kept")
		expect.equal(later.bonus, true, "today's bonus kept")
		local tomorrow = QuestRules.refresh(state, 101, Quests, 9, { 0, 0, 0 })
		expect.equal(tomorrow.day, 101)
		expect.equal(tomorrow.bonus, false, "a new bonus")
		for _, quest in tomorrow.list do
			expect.equal(quest.claimed, false, "new quests")
			expect.equal(quest.progress, 0, "from zero")
		end
	end,

	["playing counts toward the matching quests, up to their goal; it says which just got done"] = function()
		local state = QuestRules.fresh()
		state.day = 1
		state.list = {
			{ id = "serve", goal = 3, progress = 0, claimed = false },
			{ id = "rip", goal = 2, progress = 1, claimed = false },
			{ id = "wild", goal = 2, progress = 0, claimed = false },
		}
		local after, done = QuestRules.add(state, Quests, entry("rip").event, 5)
		expect.equal(after.list[2].progress, 2, "capped at the goal")
		expect.equal(#done, 1, "one finished")
		expect.equal(done[1], 2, "the rip quest")
		expect.equal(after.list[1].progress, 0, "other quests untouched")
		local again, none = QuestRules.add(after, Quests, entry("rip").event, 1)
		expect.equal(#none, 0, "a done quest doesn't finish twice")
		expect.equal(again.list[2].progress, 2)
		local unchanged, nothing = QuestRules.add(after, Quests, "nope", 1)
		expect.equal(#nothing, 0, "an unknown event counts for nothing")
		expect.equal(unchanged == after, true, "nothing moved: the same state (the server sends nothing)")
		local _, zero = QuestRules.add(after, Quests, entry("serve").event, -2)
		expect.equal(#zero, 0, "no negative progress")
	end,

	["a quest is claimed once it's done, once; the bonus once all three are claimed"] = function()
		local state = QuestRules.fresh()
		state.day = 1
		state.list = {
			{ id = "serve", goal = 3, progress = 3, claimed = false },
			{ id = "rip", goal = 2, progress = 1, claimed = false },
			{ id = "wild", goal = 2, progress = 2, claimed = false },
		}
		local _, why = QuestRules.claim(state, 2)
		expect.equal(why, "notDone", "not done yet")
		local claimed = QuestRules.claim(state, 1) :: QuestRules.State
		expect.equal(claimed.list[1].claimed, true)
		expect.equal(state.list[1].claimed, false, "the input is untouched")
		local _, twice = QuestRules.claim(claimed, 1)
		expect.equal(twice, "claimed", "only once")
		local _, bad = QuestRules.claim(claimed, 9)
		expect.equal(bad, "unknown", "no such quest")
		expect.equal(QuestRules.bonusReady(claimed), false, "the bonus waits for all three")
		local all = QuestRules.claim(claimed, 3) :: QuestRules.State
		all.list[2].progress = 2
		all = QuestRules.claim(all, 2) :: QuestRules.State
		expect.equal(QuestRules.bonusReady(all), true, "all three claimed")
		local opened = QuestRules.claimBonus(all) :: QuestRules.State
		expect.equal(opened.bonus, true)
		local _, again = QuestRules.claimBonus(opened)
		expect.equal(again, "claimed", "the bonus only once a day")
	end,

	["each quest pays cash and shop XP that grow with the shop level"] = function()
		local low, high = QuestRules.reward(Quests, 1), QuestRules.reward(Quests, 30)
		assert(low.cash > 0 and low.xp > 0, "something at level 1")
		assert(high.cash > low.cash and high.xp > low.xp, "more for a bigger shop")
		expect.equal(high.cash, Quests.REWARD.cash + Quests.REWARD.cashPerLevel * 30)
	end,

	["a saved state is cleaned: junk starts fresh, unknown quests dropped, numbers made sane"] = function()
		local fresh = QuestRules.clean("junk", Quests)
		expect.equal(fresh.day, -1)
		expect.equal(#fresh.list, 0)
		local cleaned = QuestRules.clean({ day = 12.7, bonus = "yes", list = {
			{ id = "serve", goal = 3, progress = 9, claimed = false },
			{ id = "nope", goal = 3, progress = 0, claimed = false },
			{ id = "rip", goal = -4, progress = -1, claimed = 1 },
		} }, Quests)
		expect.equal(cleaned.day, 12)
		expect.equal(cleaned.bonus, false, "not a boolean: false")
		expect.equal(#cleaned.list, 2, "the unknown quest dropped")
		expect.equal(cleaned.list[1].progress, 3, "progress capped at the goal")
		expect.equal(cleaned.list[2].goal, 1, "a goal is at least 1")
		expect.equal(cleaned.list[2].progress, 0, "no negative progress")
		expect.equal(cleaned.list[2].claimed, false, "not a boolean: false")
	end,

	["what the client shows: each quest's words with its goal, progress, reward; the bonus"] = function()
		local state = QuestRules.fresh()
		state.day = 1
		state.list = {
			{ id = "serve", goal = 3, progress = 3, claimed = false },
			{ id = "rip", goal = 2, progress = 1, claimed = false },
			{ id = "wild", goal = 2, progress = 0, claimed = false },
		}
		local view = QuestRules.view(state, Quests, 10)
		expect.equal(#view.quests, 3)
		expect.equal(view.quests[1].text, "Serve 3 customers")
		expect.equal(view.quests[1].done, true)
		expect.equal(view.quests[2].done, false)
		expect.equal(view.quests[1].cash, QuestRules.reward(Quests, 10).cash)
		expect.equal(view.bonusReady, false)
		expect.equal(view.claimable, 1, "one to claim (the tile's count)")
		expect.equal(view.quests[2].kind, "cards", "its kind (the strip's bubble colour)")
	end,

	["the quest pool's words are short and plain, every kind has a quest from level 1, every event is known"] = function()
		for _, kind in Quests.KINDS do
			local any = false
			for _, quest in Quests.POOL do
				if quest.kind == kind and (quest.minLevel or 1) <= 1 then
					any = true
				end
			end
			assert(any, `a {kind} quest at level 1`)
		end
		for _, quest in Quests.POOL do
			assert(table.find(Quests.KINDS, quest.kind), `{quest.id}'s kind`)
			assert(table.find(Quests.EVENTS, quest.event), `{quest.id}'s event {quest.event}`)
			local text = string.gsub(quest.text, "{n}", "999")
			assert(#text <= 32 and not string.find(text, "[^\32-\126]"), `{quest.id}'s words are short and plain: {text}`)
			assert(#quest.goals >= 1 and quest.goals[1].level <= (quest.minLevel or 1), `{quest.id} has a goal from its first level`)
			local UIIcons = require("../src/shared/Config/UIIcons")
			assert(UIIcons[quest.icon], `{quest.id}'s icon {quest.icon} is a picture`)
		end
	end,

	-- Owner 2026-11-17 ("add design/immersive animations on the quest strip"): the strip animates what changed since the
	-- last state: a quest moving on (+1), one finishing (its check stamps in), the done count, Claim appearing, all done
	["what the strip animates between two states"] = function()
		local function view(progress: { number }, claimed: { boolean }, bonusClaimed: boolean): any
			local quests = {}
			local claimable = 0
			for index, value in progress do
				local done = value >= 3
				if done and not claimed[index] then
					claimable += 1
				end
				table.insert(quests, { id = `q{index}`, goal = 3, progress = value, done = done, claimed = claimed[index] == true })
			end
			return { quests = quests, bonusReady = false, bonusClaimed = bonusClaimed, claimable = claimable }
		end
		local before = view({ 3, 1, 0 }, {}, false)
		local after = view({ 3, 3, 1 }, {}, false)
		local changes = QuestRules.stripChanges(before, after)
		expect.equal(#changes.progressed, 2, "two quests moved on")
		expect.equal(changes.progressed[1], 2, "the second")
		expect.equal(changes.progressed[2], 3, "and the third")
		expect.equal(#changes.finished, 1, "one finished")
		expect.equal(changes.finished[1], 2, "the second")
		expect.equal(changes.doneChanged, true, "the done count went 1 -> 2")
		expect.equal(changes.claimAppeared, false, "Claim was already there (the first quest)")
		local quiet = QuestRules.stripChanges(view({ 1, 0, 0 }, {}, false), view({ 3, 0, 0 }, {}, false))
		expect.equal(quiet.claimAppeared, true, "the first claimable quest brings Claim in")
		local claimedOne = QuestRules.stripChanges(view({ 3, 0, 0 }, {}, false), view({ 3, 0, 0 }, { true }, false))
		expect.equal(#claimedOne.progressed + #claimedOne.finished, 0, "a claim moves no bar")
		local all = QuestRules.stripChanges(view({ 3, 3, 3 }, { true, true, true }, false), view({ 3, 3, 3 }, { true, true, true }, true))
		expect.equal(all.allDone, true, "the chest opened: all done")
		local fresh = QuestRules.stripChanges(nil, after)
		expect.equal(#fresh.progressed + #fresh.finished, 0, "nothing to animate on the first state")
		local newDay = view({ 0, 0, 0 }, {}, false)
		newDay.quests[1].id = "other"
		expect.equal(#QuestRules.stripChanges(after, newDay).progressed, 0, "a new day's quests aren't progress")
	end,
}
