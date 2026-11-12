--!strict
-- The Dungeon's objective line (spec 2026-11-12-dungeon-atmosphere: plain text at the top right): the run's stage as
-- one short line from Config/Dungeon OBJECTIVES, and its progress ("2 / 3") when there is one. Pure (no requires).
local ObjectiveRules = {}

export type Line = { text: string, progress: string? }

-- `stage`: a DungeonRun stage or "pylons" (room 3 while one stands); an unknown one reads as a fight room's
function ObjectiveRules.line(stage: string, done: number?, total: number?, texts: { [string]: string }): Line
	local text = texts[stage] or texts.room or ""
	local progress = if done and total and total > 0 then `{done} / {total}` else nil
	return { text = text, progress = progress }
end

-- The small label over the line: a puzzle room's own name, "OBJECTIVE" elsewhere
function ObjectiveRules.label(stage: string, labels: { [string]: string }): string
	return labels[stage] or "OBJECTIVE"
end

-- The stage's clue after `seconds` on it: the first at once, the next every `every` seconds, the last one stays.
-- Nil for a stage without clues.
function ObjectiveRules.hint(stage: string, seconds: number, hints: { [string]: { string } }, every: number): string?
	local list = hints[stage]
	if not list or #list == 0 then
		return nil
	end
	local index = math.clamp(math.floor(math.max(0, seconds) / every) + 1, 1, #list)
	return list[index]
end

return ObjectiveRules
