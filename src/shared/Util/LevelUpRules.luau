--!strict
-- Level-up rewards and effect bookkeeping (spec 2026-11-04-round4-design section 8, Config/Levels): cash every level,
-- a gift every GIFT_EVERY levels (owner 2026-11-16), nothing past MAX_LEVEL; level-ups held during a fight merge into
-- one effect.
-- Pure (no requires, no Roblox APIs): callers pass Config/Levels in, so tests/ can run it in Lune.
local LevelUpRules = {}

type Gift = { item: string, count: number }
type Config = {
	REWARD_CASH_PER_LEVEL: number,
	MILESTONE_EVERY: number,
	GIFT_EVERY: number,
	GIFTS: { [number]: { Gift } },
	EXTRA_EVERY: number,
	EXTRA: Gift,
	MAX_LEVEL: number,
}
-- `items`: Config/Items id -> how many
export type Rewards = { cash: number, items: { [string]: number } }
export type Pending = { from: number, to: number }

-- Every 10th level: the rainbow pillar
-- The shop's next unlock under its level bar (owner 2026-11-17, the first 15 minutes: always a next goal): the lowest
-- level above `level` in `unlocks`, the first one listed there, "+N" for the others at it; nil when nothing's left
function LevelUpRules.nextUnlockText(level: number, unlocks: { { level: number, name: string } }): string?
	local best: { level: number, name: string }? = nil
	local more = 0
	for _, unlock in unlocks do
		if unlock.level > level then
			if not best or unlock.level < best.level then
				best, more = unlock, 0
			elseif unlock.level == best.level then
				more += 1
			end
		end
	end
	if not best then
		return nil
	end
	return if more > 0 then `Lv {best.level}: {best.name} +{more}` else `Lv {best.level}: {best.name}`
end

function LevelUpRules.isMilestone(cfg: Config, level: number): boolean
	return level > 0 and level % cfg.MILESTONE_EVERY == 0
end

-- The titles (Config/Titles: ORDER, ById with a "level" check) a level-up from `from` to `to` earns, in their order
function LevelUpRules.titlesReached(titles: any, from: number, to: number): { string }
	local names: { string } = {}
	for _, id in titles.ORDER do
		local title = titles.ById[id]
		local check = if title then title.check else nil
		if check and check.kind == "level" and check.min > from and check.min <= to then
			table.insert(names, title.name)
		end
	end
	return names
end

-- Everything levels from + 1 to `to` pay (each level its own), capped at MAX_LEVEL
function LevelUpRules.rewards(cfg: Config, from: number, to: number): Rewards
	local total: Rewards = { cash = 0, items = {} }
	local function give(gift: Gift)
		total.items[gift.item] = (total.items[gift.item] or 0) + gift.count
	end
	for level = math.max(from, 1) + 1, math.min(to, cfg.MAX_LEVEL) do
		total.cash += cfg.REWARD_CASH_PER_LEVEL * level
		if level % cfg.GIFT_EVERY == 0 then
			for _, gift in cfg.GIFTS[level % 10] or {} do
				give(gift)
			end
		end
		if level % cfg.EXTRA_EVERY == 0 then
			give(cfg.EXTRA)
		end
	end
	return total
end

-- One effect for level-ups that waited: from the level before the first, to the latest
function LevelUpRules.merge(pending: Pending?, from: number, to: number): Pending
	if not pending then
		return { from = from, to = to }
	end
	return { from = math.min(pending.from, from), to = math.max(pending.to, to) }
end

-- When a shop level-up held during a fight may play (os.clock): a boss fight's end screen first (the victory screen, or
-- the defeat countdown and the trip home; Config/LevelUpFx AFTER_BOSS), anything else at once
function LevelUpRules.freeAt(cfg: { AFTER_BOSS: { win: number, lose: number } }, now: number, boss: boolean, result: string): number
	if not boss then
		return now
	end
	if result == "win" then
		return now + cfg.AFTER_BOSS.win
	elseif result == "run" then
		return now -- ran away: no end screen
	end
	return now + cfg.AFTER_BOSS.lose -- lost or timed out: the defeat screen
end

-- Which level-up sound set plays (round 5, spec section 7): the picked one when it's a set's number, else the default
function LevelUpRules.soundSet(sounds: { sets: { any }, default: number }, pick: any): number
	if typeof(pick) == "number" and pick == math.floor(pick) and pick >= 1 and pick <= #sounds.sets then
		return pick
	end
	return sounds.default
end

-- Why a Bag pack can't be opened now (the pack opening takes over the camera): in a fight, or in PvP; nil when free
function LevelUpRules.openBlocked(fighting: boolean, inArena: boolean): string?
	if fighting or inArena then
		return "Open it after the fight."
	end
	return nil
end

return LevelUpRules
