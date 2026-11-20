--!strict
-- What the Phone's tile tells you about the things inside it (owner 2026-11-21: "put the quests inside phone and just
-- add a noticeable notification on the phone everytime there's some changes to the quest or anything that is inside
-- the phone"): the red count of what waits (client Util/Hud.setBadge), and whether the tile moves when something in
-- it changes (Hud.notice). Pure, Lune-tested (tests/PhoneNotice).
local PhoneNotice = {}

type Quest = { id: string, progress: number, done: boolean, claimed: boolean }
type View = { quests: { Quest }, bonusReady: boolean, bonusClaimed: boolean, claimable: number, week: View? }

-- What waits in the Quests app: quests to claim and the day's chest (the view's `claimable`), the Weekly Chest, and the
-- main quest's build once the cash covers it (`mainReady`); nothing while a guide's tour hides the quests (`hidden`: the
-- calm HUD)
function PhoneNotice.quests(view: View?, mainReady: boolean, hidden: boolean?): number
	if hidden then
		return 0
	end
	local count = if mainReady then 1 else 0
	if not view then
		return count
	end
	count += view.claimable
	local week = view.week
	if week and week.bonusReady and not week.bonusClaimed then
		count += 1
	end
	return count
end

-- Everything waiting in the Phone: each app's count added up (the Phone tile's badge)
function PhoneNotice.total(counts: { [string]: number }): number
	local total = 0
	for _, count in counts do
		total += math.max(0, count)
	end
	return total
end

-- A badge's words: nothing at 0, "9+" past 9
function PhoneNotice.text(count: number): string
	if count <= 0 then
		return ""
	end
	return if count > 9 then "9+" else tostring(count)
end

-- What the Phone's tile does when an app's count goes from `before` to `after`: "ping" when more waits than before,
-- "nudge" when only something inside moved on (`changed`: a quest's progress), nothing otherwise (taking one is no news)
function PhoneNotice.kind(before: number, after: number, changed: boolean): string?
	if after > before then
		return "ping"
	end
	return if changed then "nudge" else nil
end

local function moved(before: View, after: View): boolean
	if #before.quests ~= #after.quests then
		return true
	end
	for index, quest in after.quests do
		local old = before.quests[index]
		if old.id ~= quest.id or quest.progress > old.progress or (quest.done and not old.done) then
			return true -- new quests (another day's), progress, or one just finished
		end
	end
	return false
end

-- Whether the quests changed in a way worth telling: progress, a quest finished, or new quests; the daily ones or the
-- week's. Never the first state after joining
function PhoneNotice.questsChanged(before: View?, after: View?): boolean
	if not before or not after then
		return false
	end
	if moved(before, after) then
		return true
	end
	local weekBefore, weekAfter = before.week, after.week
	return weekBefore ~= nil and weekAfter ~= nil and moved(weekBefore, weekAfter)
end

return PhoneNotice
