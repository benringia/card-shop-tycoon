--!strict
-- Level-up rewards and effect bookkeeping (spec 2026-11-04-round4-design section 8, Config/Levels): cash every level,
-- a pack every PACK_EVERY levels, nothing past MAX_LEVEL; level-ups held during a fight merge into one effect.
-- Pure (no requires, no Roblox APIs): callers pass Config/Levels in, so tests/ can run it in Lune.
local LevelUpRules = {}

type Config = { REWARD_CASH_PER_LEVEL: number, PACK_EVERY: number, MAX_LEVEL: number }
export type Rewards = { cash: number, packs: number }
export type Pending = { from: number, to: number }

function LevelUpRules.isMilestone(cfg: Config, level: number): boolean
	return level > 0 and level % cfg.PACK_EVERY == 0
end

-- Everything levels from + 1 to `to` pay (each level its own), capped at MAX_LEVEL
function LevelUpRules.rewards(cfg: Config, from: number, to: number): Rewards
	local total: Rewards = { cash = 0, packs = 0 }
	for level = math.max(from, 1) + 1, math.min(to, cfg.MAX_LEVEL) do
		total.cash += cfg.REWARD_CASH_PER_LEVEL * level
		if LevelUpRules.isMilestone(cfg, level) then
			total.packs += 1
		end
	end
	return total
end

-- The toast's reward for reaching this level: "+$70", "+$100 · +1 pack"
function LevelUpRules.rewardText(cfg: Config, level: number): string
	local reward = LevelUpRules.rewards(cfg, level - 1, level)
	local text = `+${reward.cash}`
	if reward.packs > 0 then
		text ..= ` · +{reward.packs} pack{if reward.packs == 1 then "" else "s"}`
	end
	return text
end

-- One effect for level-ups that waited: from the level before the first, to the latest
function LevelUpRules.merge(pending: Pending?, from: number, to: number): Pending
	if not pending then
		return { from = from, to = to }
	end
	return { from = math.min(pending.from, from), to = math.max(pending.to, to) }
end

return LevelUpRules
