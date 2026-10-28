--!strict
-- Which summoned creatures a client draws (CreatureController): your own always, then the nearest others within the
-- draw distance, up to a cap, so a full server doesn't animate every pet on a phone. A drawn creature stays until it
-- is past the (longer) hide distance, so one standing at the edge doesn't flicker in and out.
local CreatureCull = {}

export type Entry = { key: string, distance: number, own: boolean, drawn: boolean }
export type Rules = { drawDistance: number, hideDistance: number, maxDrawn: number }

function CreatureCull.pick(entries: { Entry }, rules: Rules): { [string]: boolean }
	local candidates: { Entry } = {}
	for _, entry in entries do
		local reach = if entry.drawn then rules.hideDistance else rules.drawDistance
		if entry.own or entry.distance <= reach then
			table.insert(candidates, entry)
		end
	end
	table.sort(candidates, function(a, b)
		if a.own ~= b.own then
			return a.own
		end
		return a.distance < b.distance
	end)
	local drawn: { [string]: boolean } = {}
	for index, entry in candidates do
		if index > rules.maxDrawn and not entry.own then
			break
		end
		drawn[entry.key] = true
	end
	return drawn
end

return CreatureCull
