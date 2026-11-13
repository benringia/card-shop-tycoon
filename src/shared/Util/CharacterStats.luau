--!strict
-- The character window's three numbers (owner 2026-11-12; spec 2026-11-12-wild-danger-character-window-design): Power
-- (the strongest party card's: what a boss's recommended Power is checked against), Attack (the equipped weapon's
-- Power) and Defense (the party's Power added up: Util/DefenseRules, written out here since pure modules don't require
-- siblings). Pure, Lune-tested.
local CharacterStats = {}

export type Stats = { power: number, attack: number, defense: number }

function CharacterStats.compute(partyPowers: { number }, weaponPower: number): Stats
	local strongest, total = 0, 0
	for _, power in partyPowers do
		strongest = math.max(strongest, power)
		total += power
	end
	return { power = strongest, attack = weaponPower, defense = total }
end

export type Progress = {
	level: number,
	into: number,
	span: number,
	cards: number,
	cardsTotal: number,
	bosses: number,
	bossesTotal: number,
	titles: number,
	titlesTotal: number,
}
export type Tile = { name: string, value: string, share: number }

local function share(have: number, total: number): number
	return if total > 0 then math.clamp(have / total, 0, 1) else 0
end

-- The window's four progress tiles over the stats (owner 2026-11-13, pick A: goals at a glance): your level with the XP
-- into it (full at the last level), the cards you've collected, the bosses beaten and the titles earned, each with how
-- far along it is (0-1)
function CharacterStats.progress(p: Progress): { Tile }
	return {
		{ name = "Level", value = tostring(p.level), share = if p.span > 0 then share(p.into, p.span) else 1 },
		{ name = "Cards", value = `{p.cards}/{p.cardsTotal}`, share = share(p.cards, p.cardsTotal) },
		{ name = "Bosses", value = `{p.bosses}/{p.bossesTotal}`, share = share(p.bosses, p.bossesTotal) },
		{ name = "Titles", value = `{p.titles}/{p.titlesTotal}`, share = share(p.titles, p.titlesTotal) },
	}
end

return CharacterStats
