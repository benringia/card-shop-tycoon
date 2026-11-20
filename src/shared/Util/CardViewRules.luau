--!strict
-- What the binder's card view shows (Config/CardView): a few things first, the rest behind "More about this card".
-- Pure, Lune-tested (tests/CardViewRules).
local CardViewRules = {}

export type Chip = { words: string, good: boolean, element: string }

-- The view's parts in order. `more`: the details are open. `entries`: how many different copies the list would show.
function CardViewRules.sections(more: boolean, entries: number): { string }
	local list = { "copy", "matchups", "toggle" }
	if more then
		table.insert(list, "skills")
		table.insert(list, "buffs")
		table.insert(list, "elements")
	end
	-- one copy: the list would only repeat "This copy"
	if more or entries > 1 then
		table.insert(list, "copies")
	end
	return list
end

-- This copy's stat tiles: one big Power first, the others with the details
function CardViewRules.stats(more: boolean): { string }
	return if more then { "Power", "Hp", "Atk", "Spd" } else { "Power" }
end

-- The "To sell..." line shows with the details only
function CardViewRules.sellHint(more: boolean): boolean
	return more
end

function CardViewRules.toggleWords(more: boolean, cfg: { TOGGLE: { more: string, less: string } }): string
	return if more then cfg.TOGGLE.less else cfg.TOGGLE.more
end

-- The XP bar's words (`toNext` 0: max level)
function CardViewRules.xpWords(level: number, xp: number, toNext: number): string
	if toNext <= 0 then
		return "Max level"
	end
	return `Level {level + 1}: {xp}/{toNext} XP`
end

-- The next star's words (`cost` nil: max stars)
function CardViewRules.starWords(have: number, cost: number?): string
	if not cost then
		return "Max stars"
	end
	return `Next star: {have}/{cost} copies`
end

-- Chips for the elements it hits hard and the ones that hit it hard, named as players read them (`names`:
-- Config/ElementNames)
function CardViewRules.matchups(wheel: { strong: { string }, weak: { string } }, names: { [string]: any }): { Chip }
	local chips: { Chip } = {}
	local function plain(key: string): string
		local name = names[key]
		return if typeof(name) == "string" then name else key
	end
	for _, element in wheel.strong do
		table.insert(chips, { words = `Strong vs {plain(element)}`, good = true, element = element })
	end
	for _, element in wheel.weak do
		table.insert(chips, { words = `Weak vs {plain(element)}`, good = false, element = element })
	end
	return chips
end

-- The panel's height and top (owner 2026-11-20: "theres a huge space here on this window fix it"): `content` px of
-- body plus `chrome` px (header, gaps, the buttons) as tall as that, at least `least`, never past the room (`room`:
-- its top and bottom on screen; then the body scrolls), centred in the room. `full`: a chooser is open (party, job),
-- which takes the whole room
function CardViewRules.fitPanel(content: number, chrome: number, room: { top: number, bottom: number }, least: number, full: boolean?): { height: number, top: number }
	local space = room.bottom - room.top
	local height = if full then space else math.clamp(content + chrome, math.min(least, space), space)
	return { height = height, top = room.top + (space - height) / 2 }
end

return CardViewRules
