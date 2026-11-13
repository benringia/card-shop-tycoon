--!strict
-- Which of your empty shelves show their floating "Empty" badge (ShelfInfoController; owner 2026-11-14: a shop full
-- of empty shelves buried the screen in badges): the nearest ones first, at most `max`, skipping any off screen or
-- whose badge would overlap one already shown. Pure (Lune-tested).
local BadgeRules = {}

-- One empty shelf: how far it is, and where its badge would sit on screen (pixels)
export type Candidate = { id: any, distance: number, x: number, y: number, onScreen: boolean }

function BadgeRules.pick(candidates: { Candidate }, max: number, size: { w: number, h: number }): { [any]: boolean }
	local sorted = table.clone(candidates)
	table.sort(sorted, function(a, b)
		return a.distance < b.distance
	end)
	local picked: { [any]: boolean } = {}
	local placed: { Candidate } = {}
	for _, candidate in sorted do
		if #placed >= max then
			break
		end
		if not candidate.onScreen then
			continue
		end
		local clear = true
		for _, other in placed do
			if math.abs(candidate.x - other.x) < size.w and math.abs(candidate.y - other.y) < size.h then
				clear = false
				break
			end
		end
		if clear then
			picked[candidate.id] = true
			table.insert(placed, candidate)
		end
	end
	return picked
end

return BadgeRules
