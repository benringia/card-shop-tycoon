--!strict
-- The quest reminder (owner 2026-11-21: "add something that always reminds players to check quests specially when
-- they are doing nothing. but not to the point that it is annoying"): when it may show and what it says. On a
-- computer the quests live in the Phone, so a player standing idle gets a small bubble by the Phone's tile (client
-- QuestController). Numbers: Config/Quests REMIND. Pure, Lune-tested (tests/QuestRemind).
local QuestRemind = {}

type Quest = { text: string, icon: string, goal: number, progress: number, done: boolean, claimed: boolean }
type View = { quests: { Quest }, claimable: number, week: View? }
export type Words = { text: string, icon: string, strong: boolean }
type Config = { first: number, idle: number, every: number }

-- Whether a reminder may show at `now`: not in the first moments after joining (`joinedAt`), the player idle and free
-- since `idleSince` (nil: busy or moving) for `cfg.idle` seconds, and `cfg.every` seconds past the last one (`lastAt`)
function QuestRemind.due(now: number, joinedAt: number, idleSince: number?, lastAt: number?, cfg: Config): boolean
	if now - joinedAt < cfg.first or idleSince == nil or now - idleSince < cfg.idle then
		return false
	end
	return lastAt == nil or now - lastAt >= cfg.every
end

-- The quest nearest done among those still going; nil when none is
local function nearest(quests: { Quest }): Quest?
	local best: Quest? = nil
	local bestShare = -1
	for _, quest in quests do
		if not quest.done then
			local share = quest.progress / math.max(1, quest.goal)
			if share > bestShare then
				best, bestShare = quest, share
			end
		end
	end
	return best
end

-- What the reminder says, the most useful thing first: quests done and waiting to be claimed, a main quest build the
-- cash covers (`buildName`), the daily quest nearest done, then the week's; nil with nothing left to do (no reminder).
-- `strong`: something waits to be taken (the Phone's tile pings rather than nudges)
function QuestRemind.words(view: View?, buildName: string?): Words?
	if not view then
		return nil
	end
	if view.claimable > 0 then
		local text = if view.claimable == 1 then "A quest is done! Claim it." else `{view.claimable} quests are done! Claim them.`
		return { text = text, icon = "Gift", strong = true }
	end
	if buildName then
		return { text = `You can build the {buildName}!`, icon = "Level", strong = true }
	end
	local today = nearest(view.quests)
	if today then
		return { text = `Quest: {today.text} · {today.progress} / {today.goal}`, icon = today.icon, strong = false }
	end
	local week = view.week
	local weekly = if week then nearest(week.quests) else nil
	if weekly then
		return { text = `Weekly: {weekly.text} · {weekly.progress} / {weekly.goal}`, icon = weekly.icon, strong = false }
	end
	return nil
end

return QuestRemind
