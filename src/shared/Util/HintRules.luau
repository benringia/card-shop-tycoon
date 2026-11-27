--!strict
-- What now? hints (spec 2026-11-27-what-now-hints-design): which tip a player gets once they've done nothing for a
-- while, its words, when one may show and where its bubble sits by the arrow (client HintController). Pure: callers
-- pass the facts and Config/Hints, so tests/ run it in Lune.
local HintRules = {}

export type Facts = {
	registerWaiting: boolean, -- a customer waits at the register, nobody there (RegisterService's RegisterWaiting)
	questsDone: number, -- daily and weekly quests done, not claimed
	boxWaiting: boolean, -- a delivered box on the pad or in your hands
	boxesComing: number, -- ordered boxes on the way
	shelvesStocked: boolean, -- some shelf has stock
	cash: number,
	cheapestBox: number?, -- the least a box to order costs at the shop's level (LessonRules.cheapestBox)
	stationReady: string?, -- a station's finished job waiting to be taken out: its Config/Shelves id
	buildName: string?, -- the next main quest build the cash covers
	packs: number, -- packs and deck boxes in the Bag
	boss: { name: string, cleared: boolean }?, -- a Wild boss to go for now (BossBoardController.Suggested)
	questText: string?, -- the quest nearest done, in words (QuestRemind.words)
	inTown: boolean,
}

local HOLDS: { [string]: (Facts) -> boolean } = {
	register = function(f: Facts): boolean
		return f.registerWaiting
	end,
	claim = function(f: Facts): boolean
		return f.questsDone > 0
	end,
	stock = function(f: Facts): boolean
		return f.boxWaiting
	end,
	-- never what they can't pay for (owner 2026-11-18), nor while boxes are on the way or waiting
	order = function(f: Facts): boolean
		local cheapest = f.cheapestBox
		return not f.shelvesStocked and not f.boxWaiting and f.boxesComing == 0 and cheapest ~= nil and f.cash >= cheapest
	end,
	station = function(f: Facts): boolean
		return f.stationReady ~= nil
	end,
	build = function(f: Facts): boolean
		return f.buildName ~= nil
	end,
	packs = function(f: Facts): boolean
		return f.packs > 0
	end,
	boss = function(f: Facts): boolean
		return f.boss ~= nil
	end,
	quest = function(f: Facts): boolean
		return f.questText ~= nil
	end,
	hunt = function(f: Facts): boolean
		return f.inTown
	end,
}

-- Whether tip `kind` is still something to do (an unknown kind never is)
function HintRules.holds(kind: string, facts: Facts): boolean
	local check = HOLDS[kind]
	return check ~= nil and check(facts)
end

-- The first tip of `order` that holds and isn't in `skip`; nil: nothing to suggest
function HintRules.pick(facts: Facts, skip: { [string]: boolean }, order: { string }): string?
	for _, kind in order do
		if not skip[kind] and HintRules.holds(kind, facts) then
			return kind
		end
	end
	return nil
end

local function counted(words: { one: string, many: string }, n: number): string
	return if n == 1 then words.one else string.format(words.many, n)
end

-- What Pish says for tip `kind` (`words`: Config/Hints WORDS)
function HintRules.words(kind: string, facts: Facts, words: any): string
	if kind == "claim" then
		return counted(words.claim, facts.questsDone)
	elseif kind == "packs" then
		return counted(words.packs, facts.packs)
	elseif kind == "station" then
		return words.station[facts.stationReady or ""] or ""
	elseif kind == "build" then
		return string.format(words.build, facts.buildName or "")
	elseif kind == "boss" then
		local boss = facts.boss
		return if boss then string.format(if boss.cleared then words.boss.loot else words.boss.ready, boss.name) else ""
	elseif kind == "quest" then
		return facts.questText or ""
	end
	local plain = words[kind]
	return if typeof(plain) == "string" then plain else ""
end

-- `idleSince`: standing still and free since (nil: moving or busy); `quietSince`: since the cash or XP last changed
export type Timing = { joinedAt: number, idleSince: number?, quietSince: number, lastShownAt: number? }

-- Whether a tip may show at `now`: `FIRST` seconds past joining, the player idle `IDLE` seconds or with nothing earned
-- for `LOST`, and `GAP` seconds after the last tip
function HintRules.due(now: number, t: Timing, cfg: { FIRST: number, IDLE: number, LOST: number, GAP: number }): boolean
	if now - t.joinedAt < cfg.FIRST then
		return false
	end
	local idleSince = t.idleSince
	local idle = idleSince ~= nil and now - idleSince >= cfg.IDLE
	if not idle and now - t.quietSince < cfg.LOST then
		return false
	end
	local last = t.lastShownAt
	return last == nil or now - last >= cfg.GAP
end

-- The tips not to give now: muted ones (their x) and ones shown less than `repeatSeconds` ago
function HintRules.skip(now: number, shownAt: { [string]: number }, muted: { [string]: boolean }, repeatSeconds: number): { [string]: boolean }
	local skip: { [string]: boolean } = {}
	for kind, on in muted do
		if on then
			skip[kind] = true
		end
	end
	for kind, at in shownAt do
		if now - at < repeatSeconds then
			skip[kind] = true
		end
	end
	return skip
end

export type Box = { x: number, y: number, w: number, h: number }

-- Where the bubble sits (its top-left, px) by the arrow drawn at `arrow` turned `rotation` degrees (its picture points
-- down at 0 and turns clockwise: 90 points left, -90 right, 180 up): on the side it points away from, `gap` px off it,
-- in whole px, kept `margin` px inside the view
function HintRules.bubbleAt(arrow: Box, rotation: number, bubble: { w: number, h: number }, view: { w: number, h: number }, cfg: { gap: number, margin: number }): { x: number, y: number }
	local turn = math.rad(rotation)
	local ux, uy = -math.sin(turn), math.cos(turn)
	local function reach(w: number, h: number): number
		return math.abs(ux) * w / 2 + math.abs(uy) * h / 2
	end
	local away = reach(arrow.w, arrow.h) + cfg.gap + reach(bubble.w, bubble.h)
	local x = math.floor(arrow.x + arrow.w / 2 - ux * away - bubble.w / 2 + 0.5)
	local y = math.floor(arrow.y + arrow.h / 2 - uy * away - bubble.h / 2 + 0.5)
	return {
		x = math.clamp(x, cfg.margin, math.max(cfg.margin, view.w - cfg.margin - bubble.w)),
		y = math.clamp(y, cfg.margin, math.max(cfg.margin, view.h - cfg.margin - bubble.h)),
	}
end

local OUTCOMES = { shown = true, done = true, closed = true }

-- A client's "a tip was shown, followed or closed" (Remotes.HintSeen, HintService): the kind when it's one of `order`
-- and the outcome when it's one that's logged; nils for anything else
function HintRules.readSeen(kind: unknown, outcome: unknown, order: { string }): (string?, string?)
	if typeof(kind) ~= "string" or typeof(outcome) ~= "string" or not OUTCOMES[outcome] or not table.find(order, kind) then
		return nil, nil
	end
	return kind, outcome
end

return HintRules
