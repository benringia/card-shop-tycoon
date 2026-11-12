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

return CharacterStats
