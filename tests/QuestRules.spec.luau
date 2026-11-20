--!strict
-- Daily quests (owner 2026-11-17: "yes do the three now"): three a day (one shop, one cards, one adventure; easier at a
-- low shop level), each paying cash and shop XP, and a bonus chest once all three are claimed. They reset each UTC day,
-- like the daily gift (GiftRules.dayOf).
local QuestRules = require("../src/shared/Util/QuestRules")
local Quests = require("../src/shared/Config/Quests")
local GiftRules = require("../src/shared/Util/GiftRules")
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

	-- Weekly quests (owner 2026-11-17: "what players do after daily quests?", look A): one of each kind every Monday to
	-- Monday UTC week (the gifts' weeks), each goal a week of the day's, the Weekly Chest once all three are done
	["a week's quests: one of each kind, each goal a week of the day's at the shop's level"] = function()
		for _, level in { 1, 4, 20, 60 } do
			local list = QuestRules.rollWeek(Quests, level, { 0.5, 0.5, 0.5 })
			expect.equal(#list, #Quests.KINDS, `{#Quests.KINDS} weekly quests at level {level}`)
			for index, quest in list do
				local info = entry(quest.id)
				expect.equal(info.kind, Quests.KINDS[index], `weekly quest {index} is a {Quests.KINDS[index]} quest`)
				assert((info.minLevel or 1) <= level, `{quest.id} is unlocked at level {level}`)
				expect.equal(quest.goal, QuestRules.goalFor(info, level) * Quests.WEEKLY.TIMES, `{quest.id}'s weekly goal at level {level}`)
				expect.equal(quest.progress, 0, "nothing done yet")
			end
		end
		assert(Quests.WEEKLY.TIMES >= 5, "a week's goal is several days of play")
		assert(#Quests.WEEKLY.CHEST > 0, "the chest holds something")
	end,

	["the same week keeps its quests; a new week rolls new ones and shuts the chest"] = function()
		local week = QuestRules.refreshWeek(QuestRules.freshWeek(), 2915, Quests, 5, { 0, 0, 0 })
		expect.equal(week.week, 2915)
		expect.equal(#week.list, #Quests.KINDS)
		expect.equal(week.chest, false)
		week.list[1].progress = 4
		local same = QuestRules.refreshWeek(week, 2915, Quests, 40, { 0.9, 0.9, 0.9 })
		expect.equal(same, week, "the same week: unchanged, even at a new level")
		local opened = table.clone(week)
		opened.chest = true
		local nextWeek = QuestRules.refreshWeek(opened, 2916, Quests, 5, { 0, 0, 0 })
		expect.equal(nextWeek.week, 2916)
		expect.equal(nextWeek.chest, false, "a new week's chest is shut")
		expect.equal(nextWeek.list[1].progress, 0, "new quests start at nothing")
	end,

	["the week counts the same play; its chest opens once all three are done, once"] = function()
		-- level 1, rolls 0: the first quest of each kind (serve, rip, wild)
		local week = QuestRules.refreshWeek(QuestRules.freshWeek(), 1, Quests, 1, { 0, 0, 0 })
		local events = { "serve", "rip", "winWild" }
		for index, quest in week.list do
			local after, done = QuestRules.addWeek(week, Quests, events[index], quest.goal - 1)
			assert(after ~= week, "progress moved")
			expect.equal(#done, 0, "not done yet")
			week = after
			expect.equal(QuestRules.chestReady(week), false, "not all done")
		end
		local refused, why = QuestRules.claimChest(week)
		expect.equal(refused, nil, "the chest waits")
		expect.equal(why, "notDone")
		for index in week.list do
			local after, done = QuestRules.addWeek(week, Quests, events[index], 5)
			expect.equal(done[1], index, `weekly quest {index} just finished`)
			expect.equal(after.list[index].progress, after.list[index].goal, "never past the goal")
			week = after
		end
		local unmoved = QuestRules.addWeek(week, Quests, "serve", 3)
		expect.equal(unmoved, week, "a done quest counts no more")
		local ignored = QuestRules.addWeek(week, Quests, "rip", -2)
		expect.equal(ignored, week, "nothing for a bad amount")
		expect.equal(QuestRules.chestReady(week), true, "all three done: the chest, no claims needed")
		local opened = QuestRules.claimChest(week)
		assert(opened, "it opens")
		expect.equal(opened.chest, true)
		expect.equal(QuestRules.chestReady(opened), false, "once")
		local again, whyAgain = QuestRules.claimChest(opened)
		expect.equal(again, nil)
		expect.equal(whyAgain, "claimed")
	end,

	["a saved week made safe"] = function()
		local clean = QuestRules.cleanWeek({
			week = 12.7,
			chest = true,
			list = {
				{ id = "rip", goal = 21, progress = 99, claimed = true },
				{ id = "gone", goal = 5, progress = 1 },
				"junk",
				{ id = "serve", goal = -3, progress = -1 },
			},
		}, Quests)
		expect.equal(clean.week, 12)
		expect.equal(clean.chest, true)
		expect.equal(#clean.list, 2, "unknown quests dropped")
		expect.equal(clean.list[1].progress, 21, "progress never past the goal")
		expect.equal(clean.list[2].goal, 1, "a goal at least 1")
		expect.equal(clean.list[2].progress, 0)
		local fresh = QuestRules.cleanWeek(nil, Quests)
		expect.equal(fresh.week, -1)
		expect.equal(#fresh.list, 0)
		expect.equal(fresh.chest, false)
	end,

	["the week's view: rows like the day's, the chest as its bonus, no pay per quest"] = function()
		local week = QuestRules.refreshWeek(QuestRules.freshWeek(), 1, Quests, 1, { 0, 0, 0 })
		local view = QuestRules.weekView(week, Quests)
		expect.equal(#view.quests, 3)
		expect.equal(view.quests[1].text, `Serve {week.list[1].goal} customers`, "its goal in the words")
		expect.equal(view.quests[1].kind, "shop")
		expect.equal(view.quests[1].cash, 0, "the chest is the prize")
		expect.equal(view.bonusReady, false)
		expect.equal(view.claimable, 0)
		for index in week.list do
			week.list[index].progress = week.list[index].goal
		end
		local ready = QuestRules.weekView(week, Quests)
		expect.equal(ready.bonusReady, true, "all done: the chest to open")
		expect.equal(ready.claimable, 1)
		expect.equal(ready.quests[2].done, true)
		local opened = QuestRules.claimChest(week)
		assert(opened, "it opens")
		local after = QuestRules.weekView(opened, Quests)
		expect.equal(after.bonusClaimed, true)
		expect.equal(after.claimable, 0)
	end,

	["weeks end on Monday at 00:00 UTC, where the gifts' weeks end; words for what's left"] = function()
		local monday = 4 * 86400 -- 1970-01-05, a Monday (day 0 was a Thursday)
		expect.equal(QuestRules.weekLeft(monday), 7 * 86400, "a whole week on Monday morning")
		expect.equal(QuestRules.weekLeft(monday - 1), 1, "a second left on Sunday night")
		for _, now in { 1795000000, 1795350000, 1795420800, 1795420799 } do
			local left = QuestRules.weekLeft(now)
			local week = GiftRules.weekOf(GiftRules.dayOf(now))
			expect.equal(GiftRules.weekOf(GiftRules.dayOf(now + left)), week + 1, "it ends where the gifts' week ends")
			expect.equal(GiftRules.weekOf(GiftRules.dayOf(now + left - 1)), week, "not a second early")
		end
		expect.equal(QuestRules.weekLeftText(monday), "7 days left")
		expect.equal(QuestRules.weekLeftText(monday - 2 * 86400 - 5), "2 days left")
		expect.equal(QuestRules.weekLeftText(monday - 86400 - 5), "1 day left")
		expect.equal(QuestRules.weekLeftText(monday - 5 * 3600 - 120), "5h left")
		expect.equal(QuestRules.weekLeftText(monday - 59), "1m left")
	end,

	["the strip: today's quests, then the week's once today's chest is opened, then all done"] = function()
		local week = QuestRules.weekView(QuestRules.refreshWeek(QuestRules.freshWeek(), 1, Quests, 1, { 0, 0, 0 }), Quests)
		local day = QuestRules.view(QuestRules.refresh(QuestRules.fresh(), 1, Quests, 1, { 0, 0, 0 }), Quests, 1)
		day.week = week
		expect.equal(QuestRules.stripMode(day), "daily", "today's quests first")
		day.bonusClaimed = true
		expect.equal(QuestRules.stripMode(day), "weekly", "today's chest opened: the week's quests")
		week.bonusClaimed = true
		expect.equal(QuestRules.stripMode(day), "done", "the week's chest opened too: all done")
		day.week = nil
		expect.equal(QuestRules.stripMode(day), "done", "no week rolled: done")
	end,

	-- owner 2026-11-17 ("mobile version screen now too crowded", "go A" of artifact GtT4bM87otu1aayFVANr7z): a phone
	-- shows the quests as a chip by the cash, its scroll and one chip (the count, Claim! or the hours left), no title, no
	-- arrow (its arrow only ever hid the title: "clicking on the quest arrow in mobile doesnt do anything")
	["the band's pieces: the title, the count or Claim!, the arrow; a phone's chip only the scroll and one chip"] = function()
		local function parts(compact: boolean, claimable: boolean, weekly: boolean): string
			local shown = QuestRules.bandParts(compact, claimable, weekly)
			return `{if shown.title then "title" else "-"} {if shown.claim then "claim" else "-"} {if shown.count then "count" else "-"} {if shown.fold then "fold" else "-"}`
		end
		expect.equal(parts(false, false, false), "title - count fold", "a computer: the title, the count and the arrow")
		expect.equal(parts(false, true, false), "title claim count fold", "Claim! beside the count")
		expect.equal(parts(false, true, true), "title claim - fold", "the week's Claim! alone")
		expect.equal(parts(true, false, false), "- - count -", "a phone: the scroll and the count")
		expect.equal(parts(true, true, false), "- claim - -", "a phone: the scroll and Claim!")
		expect.equal(parts(true, true, true), "- claim - -", "the week's Claim! the same")
	end,
	-- Owner 2026-11-21, with a picture of the Quests window: "improve quest window UI. easily understandable/immersive".
	-- Each section gets a heading that says how it's going, each quest its count beside its name and its pay as chips
	-- with pictures (no "250/250 · +$75 · +75 shop XP" line), and a goal of one reads like a sentence
	["a goal of one reads naturally (never 'Beat a boss 1 times')"] = function()
		for _, pooled in Quests.POOL do
			assert(typeof(pooled.one) == "string" and #pooled.one > 0, `{pooled.id} has words for a goal of one`)
			assert(not string.find(pooled.one, "{n}", 1, true), `{pooled.id}: no number to fill`)
			assert(not string.find(pooled.one, " 1 times", 1, true), pooled.id)
		end
		local one = QuestRules.view({ day = 1, list = { { id = "boss", goal = 1, progress = 0, claimed = false } }, bonus = false }, Quests, 4)
		expect.equal(one.quests[1].text, "Beat a boss")
		local two = QuestRules.view({ day = 1, list = { { id = "boss", goal = 2, progress = 0, claimed = false } }, bonus = false }, Quests, 26)
		expect.equal(two.quests[1].text, "Beat a boss 2 times")
	end,

	["the window: what a quest's row offers, what it pays, how the day is going"] = function()
		local going = { id = "rip", kind = "cards", text = "Rip 8 packs", icon = "Pack", goal = 8, progress = 3, done = false, claimed = false, cash = 75, xp = 75 }
		local done = table.clone(going)
		done.progress, done.done = 8, true
		local claimed = table.clone(done)
		claimed.claimed = true
		expect.equal(QuestRules.rowState(going, false), "going")
		expect.equal(QuestRules.rowState(done, false), "claim", "finished: its pay waits")
		expect.equal(QuestRules.rowState(claimed, false), "claimed")
		expect.equal(QuestRules.rowState(done, true), "done", "a weekly quest pays through its chest")
		expect.equal(QuestRules.rowState(going, true), "going")
		expect.equal(QuestRules.countText(going), "3 / 8")
		local pay = QuestRules.pay(going, false)
		expect.equal(#pay, 2)
		expect.equal(pay[1].icon, "Coin")
		expect.equal(pay[1].text, "$75")
		expect.equal(pay[2].text, "75 XP")
		local weekly = QuestRules.pay(going, true)
		expect.equal(#weekly, 1)
		expect.equal(weekly[1].text, "Weekly Chest")
		local view: any = { quests = { going, done, claimed }, bonusReady = false, bonusClaimed = false, claimable = 1 }
		expect.equal(QuestRules.sectionLine(view), "2 of 3 done")
		expect.equal(QuestRules.sectionLine({ quests = { done, claimed }, bonusReady = false, bonusClaimed = false, claimable = 1 } :: any), "All done!")
		expect.equal(QuestRules.chestLeft(view, false), 2, "the day's chest: every quest claimed first")
		expect.equal(QuestRules.chestLeft(view, true), 1, "the week's: every quest done")
		expect.equal(QuestRules.chestWaiting(2), "2 more to go")
		expect.equal(QuestRules.chestWaiting(1), "1 more to go")
		expect.equal(QuestRules.chestWaiting(0), "Ready!")
	end,
}
