--!strict
-- Element callouts (owner 2026-11-25: picked "A", a chip in your creature's status row; spec
-- 2026-11-25-element-callouts-design): the chip a matchup shows in a fight. Your creature's element against the
-- monster's, the way your hits land (CombatMath's wheel: Config/Combat BEATS, STRONG, WEAK); an even fight shows none.
-- Pure, no requires (Lune-tested: tests/MatchupRules); `names` is Config/ElementNames.
local MatchupRules = {}

export type Chip = {
	good: boolean, -- strong (green) or weak (red)
	words: string, -- "Weak vs Fire"
	tag: string, -- "0.75x"
	element: string, -- the foe's element key, for its icon
}

-- A multiplier in plain numbers: 1.5 -> "1.5x", 0.75 -> "0.75x", 2 -> "2x"
function MatchupRules.tag(multiplier: number): string
	local text = string.format("%.2f", multiplier)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text .. "x"
end

local function beats(combat: any, a: string, b: string): boolean
	local list = combat.BEATS[a]
	return list ~= nil and table.find(list, b) ~= nil
end

local function known(combat: any, element: string): boolean
	if combat.BEATS[element] then
		return true
	end
	for _, beaten in combat.BEATS do
		if table.find(beaten, element) then
			return true
		end
	end
	return false
end

-- The chip for your creature's element `mine` against the foe's `foe`; nil when even, when either is missing or unknown
-- (no monster foe: the arena). Electric and Dark beat each other, so both ways are strong (the chip says how you hit)
function MatchupRules.chip(combat: any, mine: string?, foe: string?, names: { [string]: any }): Chip?
	if not mine or not foe or mine == "" or foe == "" or not known(combat, mine) or not known(combat, foe) then
		return nil
	end
	local name = names[foe]
	local plain = if typeof(name) == "string" then name else foe
	if beats(combat, mine, foe) then
		return { good = true, words = `Strong vs {plain}`, tag = MatchupRules.tag(combat.STRONG), element = foe }
	elseif beats(combat, foe, mine) then
		return { good = false, words = `Weak vs {plain}`, tag = MatchupRules.tag(combat.WEAK), element = foe }
	end
	return nil
end

return MatchupRules
