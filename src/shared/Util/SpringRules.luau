--!strict
-- What the healing spring says when you ask it (owner 2026-11-20: "make the healing spring interactable ... 'bring
-- your injured pet here to get healed' fix the wordings"; Config/Combat SPRING_ASK, server BattleService): what it's
-- for, or who is hurt and how long their rest takes beside it. Pure, Lune-tested.
local SpringRules = {}

-- `seconds` of rest left, as it passes beside the spring (`speed` times faster), in round words: "30 seconds" (up to
-- the next 5), "2 minutes" (up to the next whole one)
function SpringRules.timeWords(seconds: number, speed: number): string
	local here = math.max(1, seconds / speed)
	if here <= 55 then
		return `{math.ceil(here / 5) * 5} seconds`
	end
	local minutes = math.ceil(here / 60)
	return if minutes == 1 then "1 minute" else `{minutes} minutes`
end

-- The card's words: `names` of your hurt (resting) creatures, `seconds` the longest rest among them still has
function SpringRules.words(names: { string }, seconds: number?, speed: number, ask: any): string
	local template = if #names == 0 or not seconds then ask.idle elseif #names == 1 then ask.one else ask.many
	local values = {
		speed = tostring(speed),
		name = names[1] or "",
		count = tostring(#names),
		time = if seconds then SpringRules.timeWords(seconds, speed) else "",
	}
	return (string.gsub(template, "{(%w+)}", values))
end

return SpringRules
