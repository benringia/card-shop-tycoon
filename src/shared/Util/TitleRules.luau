--!strict
-- Which titles a player has earned, how far they are from the rest, which one shows over their name and whether they may
-- pick one (Config/Titles; TitleService, the character window's Titles tab). Pure, Lune-tested.
local TitleRules = {}

-- What earns titles (TitleService gathers it): boss clears and the Dungeon's secret (BossService), the best "Support
-- the dev" gift, the shop level, lifetime counters (packs opened, customers served, money from sales), different cards
-- owned, each set's cards owned of its total, cards owned by rarity, duels won. Missing counts are 0.
export type Progress = {
	cleared: { [string]: boolean },
	secret: boolean,
	supporter: number?,
	level: number?,
	stats: { [string]: number }?,
	cards: number?,
	sets: { [string]: { have: number, total: number } }?,
	rarities: { [string]: number }?,
	pvpWins: number?,
}

-- How far `progress` is toward a title's check: what they have and what it needs
local function measure(check: any, progress: Progress): (number, number)
	local kind = check.kind
	if kind == "bossClear" then
		return if progress.cleared[check.boss] then 1 else 0, 1
	elseif kind == "secret" then
		return if progress.secret then 1 else 0, 1
	elseif kind == "supporter" then
		return progress.supporter or 0, check.tier
	elseif kind == "level" then
		return progress.level or 0, check.min
	elseif kind == "stat" then
		local stats = progress.stats
		return if stats then stats[check.stat] or 0 else 0, check.min
	elseif kind == "bosses" then
		local beaten = 0
		for _, boss in check.bosses do
			if progress.cleared[boss] then
				beaten += 1
			end
		end
		return beaten, #check.bosses
	elseif kind == "cards" then
		return progress.cards or 0, check.min
	elseif kind == "set" then
		local set = if progress.sets then progress.sets[check.set] else nil
		return if set then set.have else 0, if set and set.total > 0 then set.total else check.count
	elseif kind == "rarity" then
		local rarities = progress.rarities
		return if rarities then rarities[check.rarity] or 0 else 0, check.min
	elseif kind == "pvp" then
		return progress.pvpWins or 0, check.min
	end
	return 0, 1
end

-- The ids earned now, in the list's order
function TitleRules.earned(cfg: any, progress: Progress): { string }
	local list = {}
	for _, id in cfg.ORDER do
		local have, need = measure(cfg.ById[id].check, progress)
		if need > 0 and have >= need then
			table.insert(list, id)
		end
	end
	return list
end

-- How far a title is: what they have and what it needs (the Titles tab's bar on a locked title)
function TitleRules.progress(cfg: any, progress: Progress, id: string): (number, number)
	local title = cfg.ById[id]
	if not title then
		return 0, 1
	end
	return measure(title.check, progress)
end

-- The titles earned now that they were never told about, in the order given
function TitleRules.newly(earnedNow: { string }, known: { string }): { string }
	local list = {}
	for _, id in earnedNow do
		if not table.find(known, id) then
			table.insert(list, id)
		end
	end
	return list
end

-- Every title in either list (earned here now, or earned before: a title stays earned), in the list's order
function TitleRules.merge(cfg: any, a: { string }, b: { string }): { string }
	local list = {}
	for _, id in cfg.ORDER do
		if table.find(a, id) or table.find(b, id) then
			table.insert(list, id)
		end
	end
	return list
end

-- The title shown: the equipped one if it's earned, else (automatic, or one no longer earned or listed) the first earned
function TitleRules.shown(cfg: any, equipped: string, earned: { string }): string?
	if equipped ~= "" and cfg.ById[equipped] and table.find(earned, equipped) then
		return equipped
	end
	return earned[1]
end

-- Whether a player may pick `id` ("" = automatic, always)
function TitleRules.canEquip(id: string, earned: { string }): boolean
	return id == "" or table.find(earned, id) ~= nil
end

return TitleRules
