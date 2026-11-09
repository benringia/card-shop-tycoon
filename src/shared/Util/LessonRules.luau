--!strict
-- Pish's lesson visits and the stuck helper (spec 2026-11-09-tutorial-pish-design 8). Pure: `lessons` is Config/Pish
-- LESSONS, `cfg` its STUCK.
export type Lesson = { id: string, level: number, icon: string }
export type Facts = {
	played: number, -- seconds of play so far
	quiet: number, -- seconds since the last order, restock, sale or pack
	sinceNudge: number, -- seconds since Pish last came to point
	boxWaiting: boolean, -- a delivered box is waiting to go on a shelf
	shelvesStocked: boolean, -- some shelf has stock on it
}

local LessonRules = {}

-- The lessons a level-up from `fromLevel` to `toLevel` brings, in level order, leaving out ones seen. Loading a save
-- (from = to) brings none, so players never get lessons for what they unlocked before.
function LessonRules.due(lessons: { Lesson }, fromLevel: number, toLevel: number, seen: { [string]: boolean }): { string }
	local picked = {}
	for _, lesson in lessons do
		if lesson.level > fromLevel and lesson.level <= toLevel and not seen[lesson.id] then
			table.insert(picked, lesson)
		end
	end
	table.sort(picked, function(a, b)
		return a.level < b.level
	end)
	local ids = {}
	for _, lesson in picked do
		table.insert(ids, lesson.id)
	end
	return ids
end

-- What Pish comes to point at for a stuck new player: "stock" (a box waiting for a shelf), "order" (empty shelves), or
-- nil (not stuck, too soon since the last nudge, or past their first hour)
function LessonRules.nudge(cfg: { firstSeconds: number, quiet: number, gap: number }, facts: Facts): ("order" | "stock")?
	if facts.played > cfg.firstSeconds or facts.quiet < cfg.quiet or facts.sinceNudge < cfg.gap then
		return nil
	end
	if facts.boxWaiting then
		return "stock"
	end
	if not facts.shelvesStocked then
		return "order"
	end
	return nil
end

return LessonRules
