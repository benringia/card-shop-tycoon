--!strict
-- Tips shown the first few times (owner 2026-11-17: "make sure players know you can put packs in the bag"; Config/Tips):
-- how many times each tip has shown, saved as tips = { [id] = count }. A tip shows until it has shown `shows` times, and
-- never again once the player has done what it teaches. Pure, Lune-tested (tests/TipRules); TipService saves the map.
local TipRules = {}

export type Tips = { [string]: number }

TipRules.MAX_COUNT = 99 -- a count is never kept higher (no tip shows this often)

-- A saved map made safe: names to whole numbers 0..MAX_COUNT; anything else dropped
function TipRules.clean(raw: unknown): Tips
	local tips: Tips = {}
	if typeof(raw) ~= "table" then
		return tips
	end
	for id, count in raw :: { [unknown]: unknown } do
		if typeof(id) == "string" and typeof(count) == "number" and count == count and count >= 0 then
			tips[id] = math.min(math.floor(count), TipRules.MAX_COUNT)
		end
	end
	return tips
end

-- Whether the tip shows now, counted if so: true its first `shows` times
function TipRules.next(tips: Tips, id: string, shows: number): (Tips, boolean)
	local count = tips[id] or 0
	if count >= shows then
		return tips, false
	end
	local updated = table.clone(tips)
	updated[id] = count + 1
	return updated, true
end

-- The player did what the tip teaches: it never shows again
function TipRules.done(tips: Tips, id: string, shows: number): Tips
	local updated = table.clone(tips)
	updated[id] = math.max(updated[id] or 0, shows)
	return updated
end

return TipRules
