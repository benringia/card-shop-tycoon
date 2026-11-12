--!strict
-- Timed station upgrades (owner 2026-11-12; Config/Upgrades, spec 2026-11-12-timed-upgrades-revive-design): how long an
-- upgrade waits, which "Finish now" tier its time left is in, the clock it shows and the saved jobs read back on load.
-- Pure, Lune-tested.
local UpgradeRules = {}

-- A job held in a station: the item (a levelled card, a plain copy, or a weapon's id with its grade and level to be)
-- and its times (os.time)
export type Job = {
	kind: string,
	startedAt: number,
	finishAt: number,
	beast: { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }?,
	plain: { cardId: string, foil: boolean, grade: string }?,
	weaponId: string?,
	grade: string?,
	level: number?,
}

local KINDS = { star = "card", grade = "card", level = "weapon", reforge = "weapon", craft = "weapon" }
local GRADES = { C = true, B = true, A = true, S = true }
local MAX_SPAN = 3600 * 2 -- seconds: a saved job longer than this is junk

-- Seconds an upgrade waits: star / level by the target stars or level (1-based), grade by the target grade
function UpgradeRules.seconds(cfg: any, kind: string, step: (number | string)?): number
	local waits = cfg.WAITS[kind]
	if typeof(waits) == "number" then
		return waits
	elseif typeof(waits) == "table" and step ~= nil then
		local value = waits[step]
		if typeof(value) == "number" then
			return value
		end
		-- past the table's end: its last (longest) wait
		if typeof(step) == "number" and #waits > 0 then
			return waits[math.clamp(step, 1, #waits)]
		end
	end
	return cfg.WAITS.craft
end

-- The "Finish now" tier for this much time left
function UpgradeRules.tier(cfg: any, left: number): string
	for _, tier in cfg.TIERS do
		if left <= tier.upTo then
			return tier.name
		end
	end
	return cfg.TIERS[#cfg.TIERS].name
end

-- "0:45", "12:30", "1:00:00"
function UpgradeRules.clock(seconds: number): string
	local total = math.max(0, math.ceil(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- The requirement card's line when a station already has a job
function UpgradeRules.busyText(stationName: string, left: number): string
	return `The {stationName} is busy ({UpgradeRules.clock(left)} left)`
end

-- The smallest skip token owned that covers `tier` (the tier itself or a bigger one), or nil
function UpgradeRules.tokenFor(tokens: { [string]: number }, tier: string, cfg: any): string?
	local reached = false
	for _, entry in cfg.TIERS do
		reached = reached or entry.name == tier
		if reached and (tokens[entry.name] or 0) > 0 then
			return entry.name
		end
	end
	return nil
end

-- Whether a job's time is up (also counts the time the player was away)
function UpgradeRules.due(job: Job, now: number): boolean
	return now >= job.finishAt
end

local function isCard(cards: any, cardId: any): boolean
	return typeof(cardId) == "string" and cards.ById[cardId] ~= nil
end

-- A saved job read back, or nil when it can't be (the caller gives its item back)
function UpgradeRules.readJob(raw: any, cards: any, weapons: any): Job?
	if typeof(raw) ~= "table" or typeof(raw.kind) ~= "string" or not KINDS[raw.kind] then
		return nil
	end
	local startedAt, finishAt = raw.startedAt, raw.finishAt
	if typeof(startedAt) ~= "number" or typeof(finishAt) ~= "number" then
		return nil
	end
	local span = finishAt - startedAt
	if span <= 0 or span > MAX_SPAN then
		return nil
	end
	local job: Job = { kind = raw.kind, startedAt = startedAt, finishAt = finishAt }
	local items = 0
	local beast = raw.beast
	if beast ~= nil then
		if typeof(beast) ~= "table" or typeof(beast.id) ~= "string" or not isCard(cards, beast.cardId) or typeof(beast.foil) ~= "boolean"
			or typeof(beast.level) ~= "number" or typeof(beast.xp) ~= "number" or typeof(beast.stars) ~= "number" or not GRADES[beast.grade] then
			return nil
		end
		job.beast = { id = beast.id, cardId = beast.cardId, foil = beast.foil, level = beast.level, xp = beast.xp, stars = beast.stars, grade = beast.grade }
		items += 1
	end
	local plain = raw.plain
	if plain ~= nil then
		if typeof(plain) ~= "table" or not isCard(cards, plain.cardId) or typeof(plain.foil) ~= "boolean" or not GRADES[plain.grade] then
			return nil
		end
		job.plain = { cardId = plain.cardId, foil = plain.foil, grade = plain.grade }
		items += 1
	end
	if raw.weaponId ~= nil then
		local weapon = if typeof(raw.weaponId) == "string" then weapons.ById[raw.weaponId] else nil
		if not weapon or not GRADES[raw.grade] then
			return nil
		end
		job.weaponId, job.grade = raw.weaponId, raw.grade
		if raw.level ~= nil then
			if typeof(raw.level) ~= "number" or raw.level < 0 or raw.level > weapons.MAX_LEVEL then
				return nil
			end
			job.level = math.floor(raw.level)
		end
		items += 1
	end
	-- exactly one item, of the kind's sort
	if items ~= 1 or (KINDS[job.kind] == "card") ~= (job.weaponId == nil) then
		return nil
	end
	return job
end

return UpgradeRules
