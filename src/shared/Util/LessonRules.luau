--!strict
-- Pish's lesson visits and the stuck helper (spec 2026-11-09-tutorial-pish-design 8, 16). Pure: `lessons` is
-- Config/Pish LESSONS, `cfg` its STUCK.
export type Lesson = { id: string, level: number?, icon: string, shelf: string?, product: string?, trigger: string?, on: string?, rush: boolean?, late: boolean? }
export type Facts = {
	played: number, -- seconds of play so far
	quiet: number, -- seconds since the last order, restock, sale or pack
	sinceNudge: number, -- seconds since Pish last came to point
	boxWaiting: boolean, -- a delivered box is waiting to go on a shelf
	shelvesStocked: boolean, -- some shelf has stock on it
	canOrder: boolean, -- the player's cash covers the cheapest box of packs
	muted: boolean, -- the player told him "Got it" on a nudge: no more this session
}
-- What the player is doing right now (owner 2026-11-18: "do not popup when the player is currently doing something.
-- like manning the cashier"), read on the client by Util/PlayerBusy
export type Busy = {
	fight: boolean, -- a fight on
	show: boolean, -- a pack opening, a weapon reveal or a cinematic
	popup: boolean, -- a level-up card, a gift, a locked card, a purchase dialog or the Roblox menu
	register: boolean, -- manning the register, or its checkout up
	carrying: boolean, -- boxes in hand
	building: boolean, -- placing a shelf, a window or a piece of decor
	window: boolean, -- a window, the phone or the binder open
}
-- Config/Pish PACE
export type Pace = { free: number, gap: number, wait: number }

local BUSY_ORDER = { "fight", "show", "popup", "register", "carrying", "building", "window" }

local LessonRules = {}

-- The first thing keeping the player busy, biggest first; nil: free. `allowed`: what the visit on now uses itself (a
-- lesson's windows and placing), which doesn't count
function LessonRules.busyWith(busy: Busy, allowed: { [string]: boolean }?): string?
	for _, reason in BUSY_ORDER do
		if (busy :: any)[reason] == true and not (allowed and allowed[reason]) then
			return reason
		end
	end
	return nil
end

-- Whether a visit (a lesson or a nudge) may start now: the player free since `freeSince` for `pace.free` seconds, and
-- `pace.gap` seconds past the end of his last visit (`lastEnded`, nil: none yet), so he never comes back to back.
-- `rush`: a lesson that comes the moment its thing unlocks (jobs) skips the breather, never the free moment
function LessonRules.mayStart(now: number, freeSince: number?, lastEnded: number?, pace: Pace, rush: boolean?): boolean
	if freeSince == nil or now - freeSince < pace.free then
		return false
	end
	return rush == true or lastEnded == nil or now - lastEnded >= pace.gap
end

-- How long a pointing lesson waits for the tap: longer when it has an introduction to give once its window is open
function LessonRules.pointSeconds(hasIntro: boolean, cfg: { LESSON_SECONDS: number, INTRO_SECONDS: number }): number
	return if hasIntro then cfg.INTRO_SECONDS else cfg.LESSON_SECONDS
end

-- Whether a lesson comes the moment its thing unlocks (Config/Pish LESSONS `rush`: jobs)
function LessonRules.rushes(lessons: { Lesson }, lessonId: string): boolean
	for _, lesson in lessons do
		if lesson.id == lessonId then
			return lesson.rush == true
		end
	end
	return false
end

-- The waiting lessons with the rushing ones first in line, the rest in their order
function LessonRules.rushFirst(queue: { string }, lessons: { Lesson }): { string }
	local first, rest = {}, {}
	for _, id in queue do
		table.insert(if LessonRules.rushes(lessons, id) then first else rest, id)
	end
	return table.move(rest, 1, #rest, #first + 1, first)
end

-- A visit under way while the player is busy since `busySince` (nil: they aren't): "on" carries on, "pause" steps back
-- (his card and paw hidden, his time stopped), "leave" past `pace.wait` (he goes; the lesson waits for a better moment)
function LessonRules.whileBusy(now: number, busySince: number?, pace: Pace): "on" | "pause" | "leave"
	if busySince == nil then
		return "on"
	end
	return if now - busySince >= pace.wait then "leave" else "pause"
end

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
-- Event lessons (no level) never come this way, nor first-use ones (`on`: they wait for their thing to be placed).
function LessonRules.due(lessons: { Lesson }, fromLevel: number, toLevel: number, seen: { [string]: boolean }): { string }
	return inLevelOrder(lessons, function(lesson)
		local level = lesson.level
		return lesson.on == nil and level ~= nil and level > fromLevel and level <= toLevel and seen[lesson.id] == nil
	end)
end

-- The lessons of things added after launch (`late`: the Recycler) that a save at shop `level` is already past and
-- never heard of (owner 2026-11-21: "pish will introduce it to old players"): they wait to be shown from its next
-- join, like a level-up's. Not seen (true) nor waiting (false) ones; other lessons never come for old unlocks.
function LessonRules.late(lessons: { Lesson }, level: number, seen: { [string]: boolean }): { string }
	return inLevelOrder(lessons, function(lesson)
		return lesson.late == true and lesson.level ~= nil and lesson.level <= level and seen[lesson.id] == nil
	end)
end

-- The first-use lesson a shelf just placed brings (`on = "placed"`: a machine or a card case, explained beside it):
-- nil when it has none, or it was explained (true) or is waiting already (false)
function LessonRules.onPlaced(lessons: { Lesson }, shelfId: string, _kind: string?, seen: { [string]: boolean }): string?
	for _, lesson in lessons do
		if lesson.on == "placed" and lesson.shelf == shelfId and seen[lesson.id] == nil then
			return lesson.id
		end
	end
	return nil
end

-- Whether a lesson has the player buy its thing (so it waits until they can pay: firstReady): one that walks them
-- to a shelf or a product, not one that explains a thing already placed
function LessonRules.buys(lesson: Lesson): boolean
	return lesson.on == nil and (lesson.shelf ~= nil or lesson.product ~= nil)
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

-- The first waiting lesson to show now (owner 2026-11-16: the glass case lesson only once you can pay for it): one
-- that has you buy something (`cost` of it: a shelf's price, a product's box) waits, keeping its place, until `cash`
-- covers it; one that buys nothing never waits. nil: none ready
function LessonRules.firstReady(queue: { string }, lessons: { Lesson }, cash: number, cost: (Lesson) -> number): string?
	for _, id in queue do
		for _, lesson in lessons do
			if lesson.id == id then
				if cash >= cost(lesson) then
					return id
				end
				break
			end
		end
	end
	return nil
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

-- The least a box to order costs at shop level `level` (the Bulk Bin's free handfuls are never ordered), nil when
-- nothing is: whether "Let's order packs!" is something the player can do
function LessonRules.cheapestBox(products: { { boxCost: number, unlockLevel: number, bulk: boolean? } }, level: number): number?
	local cheapest: number? = nil
	for _, product in products do
		if not product.bulk and product.boxCost > 0 and product.unlockLevel <= level then
			cheapest = math.min(cheapest or math.huge, product.boxCost)
		end
	end
	return cheapest
end

-- What Pish comes to point at for a stuck new player: "stock" (a box waiting for a shelf), "order" (empty shelves, and
-- the cash for a box: owner 2026-11-18, "Pish is forcing players to buy items that the player cant afford yet"), or nil
-- (not stuck, too soon since the last nudge, past their first hour, or told "Got it")
function LessonRules.nudge(cfg: { firstSeconds: number, quiet: number, gap: number }, facts: Facts): ("order" | "stock")?
	if facts.muted or facts.played > cfg.firstSeconds or facts.quiet < cfg.quiet or facts.sinceNudge < cfg.gap then
		return nil
	end
	if facts.boxWaiting then
		return "stock"
	end
	if not facts.shelvesStocked and facts.canOrder then
		return "order"
	end
	return nil
end

return LessonRules
