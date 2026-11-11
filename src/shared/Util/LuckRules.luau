--!strict
-- Pish's Luck and his gift's floor (spec 2026-11-09-tutorial-pish-design 5, 7), on a pack's hit slot (its list of
-- { rarity, weight }; `rank` is Config/PackOdds RANK). Pure; the slot passed in is never changed.
export type Weighted = { rarity: string, weight: number }

local LuckRules = {}

local function copy(slot: { Weighted }): { Weighted }
	local out = {}
	for _, option in slot do
		table.insert(out, { rarity = option.rarity, weight = option.weight })
	end
	return out
end

-- Luck: `fromRarity` and better raised by `amount` (0.25: +25%); the lowest rarity below them gives up the weight
-- they gained (never below 0). A slot with nothing below `fromRarity` stays as it was.
function LuckRules.boost(slot: { Weighted }, rank: { [string]: number }, fromRarity: string, amount: number): { Weighted }
	local out = copy(slot)
	local threshold = rank[fromRarity] or math.huge
	local lowest: Weighted? = nil
	for _, option in out do
		local r = rank[option.rarity] or 0
		if r < threshold and (not lowest or r < (rank[lowest.rarity] or 0)) then
			lowest = option
		end
	end
	if not lowest then
		return out
	end
	local gained = 0
	for _, option in out do
		if (rank[option.rarity] or 0) >= threshold then
			gained += option.weight * amount
			option.weight *= 1 + amount
		end
	end
	lowest.weight = math.max(0, lowest.weight - gained)
	return out
end

-- The gift: only `minRarity` and better (their own weights); none left: `minRarity` for sure
function LuckRules.atLeast(slot: { Weighted }, rank: { [string]: number }, minRarity: string): { Weighted }
	local floor = rank[minRarity] or 0
	local out = {}
	for _, option in slot do
		if (rank[option.rarity] or 0) >= floor then
			table.insert(out, { rarity = option.rarity, weight = option.weight })
		end
	end
	if #out == 0 then
		return { { rarity = minRarity, weight = 1 } }
	end
	return out
end

-- Whether petting gives luck now: never had it (0), or the last was `cooldown` seconds ago or more; nil (not loaded) never
function LuckRules.canGrant(lastAt: number?, now: number, cooldown: number): boolean
	if lastAt == nil then
		return false -- not loaded yet (or gone): the saved time could still say no
	end
	return lastAt <= 0 or now - lastAt >= cooldown
end

-- Seconds of luck left (0 when none)
function LuckRules.left(untilTime: number?, now: number): number
	if not untilTime then
		return 0
	end
	return math.max(0, untilTime - now)
end

-- The luck badge's text: a clover (or `icon`: Chikin's Courage's) and the time left as m:ss (part of a second shows as
-- a whole one), nil once over
function LuckRules.badgeText(untilTime: number?, now: number, icon: string?): string?
	local seconds = math.ceil(LuckRules.left(untilTime, now))
	if seconds <= 0 then
		return nil
	end
	return string.format("%s %d:%02d", icon or "🍀", seconds // 60, seconds % 60)
end

return LuckRules
