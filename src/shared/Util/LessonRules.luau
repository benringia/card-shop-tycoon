--!strict
-- Pish's lesson visits and the stuck helper (spec 2026-11-09-tutorial-pish-design 8, 16). Pure: `lessons` is
-- Config/Pish LESSONS, `cfg` its STUCK.
export type Lesson = { id: string, level: number?, icon: string, shelf: string?, product: string?, trigger: string? }
export type Facts = {
	played: number, -- seconds of play so far
	quiet: number, -- seconds since the last order, restock, sale or pack
	sinceNudge: number, -- seconds since Pish last came to point
	boxWaiting: boolean, -- a delivered box is waiting to go on a shelf
	shelvesStocked: boolean, -- some shelf has stock on it
}

local LessonRules = {}

-- Level order; one level's lessons (and the event lessons, after every level) in the order the config lists them
local function inLevelOrder(lessons: { Lesson }, keep: (Lesson) -> boolean): { string }
	local picked = {}
	for index, lesson in lessons do
		if keep(lesson) then
			table.insert(picked, { lesson = lesson, index = index })
		end
	end
	table.sort(picked, function(a, b)
		local levelA, levelB = a.lesson.level or math.huge, b.lesson.level or math.huge
		if levelA ~= levelB then
			return levelA < levelB
		end
		return a.index < b.index
	end)
	local ids = {}
	for _, entry in picked do
		table.insert(ids, entry.lesson.id)
	end
	return ids
end

-- The lessons a level-up from `fromLevel` to `toLevel` brings, in level order, leaving out ones seen (true) or already
-- waiting (false). Loading a save (from = to) brings none, so players never get lessons for what they unlocked before.
-- Event lessons (no level) never come this way.
function LessonRules.due(lessons: { Lesson }, fromLevel: number, toLevel: number, seen: { [string]: boolean }): { string }
	return inLevelOrder(lessons, function(lesson)
		local level = lesson.level
		return level ~= nil and level > fromLevel and level <= toLevel and seen[lesson.id] == nil
	end)
end

-- The lessons an event brings (`trigger`, e.g. "trophy": the first trophy item), not seen or waiting yet
function LessonRules.byEvent(lessons: { Lesson }, trigger: string, seen: { [string]: boolean }): { string }
	return inLevelOrder(lessons, function(lesson)
		return lesson.trigger == trigger and seen[lesson.id] == nil
	end)
end

-- The lessons due but not shown yet (saved false: gained during a fight, an opening or in another place), in level
-- order; unknown ids are left out
function LessonRules.pending(lessons: { Lesson }, seen: { [string]: boolean }): { string }
	return inLevelOrder(lessons, function(lesson)
		return seen[lesson.id] == false
	end)
end

-- A lesson's thing was placed or ordered: it's seen (true), also when it isn't waiting yet, so a case bought at
-- level 1 is never taught at level 2 (final review I3). Returns a copy
function LessonRules.used(seen: { [string]: boolean }, lessonId: string): { [string]: boolean }
	local after = table.clone(seen)
	after[lessonId] = true
	return after
end

-- The lesson that placing this shelf completes (`kind` its Config/Shelves kind: any trophy completes the trophy one)
function LessonRules.forShelf(lessons: { Lesson }, shelfId: string, kind: string?): string?
	for _, lesson in lessons do
		if lesson.shelf == shelfId or (kind == "Trophy" and lesson.trigger == "trophy") then
			return lesson.id
		end
	end
	return nil
end

-- The lesson that ordering this product completes
function LessonRules.forProduct(lessons: { Lesson }, productId: string): string?
	for _, lesson in lessons do
		if lesson.product == productId then
			return lesson.id
		end
	end
	return nil
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
