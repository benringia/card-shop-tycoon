--!strict
-- The prologue's rules (spec 2026-11-14-prologue-hydra-design; Config/Prologue): the real boss fight's Hydra HP is held
-- between two curves, never faster than reaching END_SHARE at FIGHT.min and never slower than reaching it at FIGHT.max,
-- so the fight lasts 35-60 s whatever you do (BattleService); each player's lair has its own spot in the sky; the cards
-- lent for it are the best there are (PrologueService); act 3's knock-back, crawl and the cards it takes, and your eyes
-- opening in town (PrologueController). Pure; tested in tests/PrologueRules.
local PrologueRules = {}

export type LentBeast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- Degrees in each joint's own frame: shoulders raised out to the side + (lying face down: 180 reaches ahead along the
-- floor, 90 out sideways), hips forward +, elbows and knees bent +, the neck tipping the head back (up, while you lie
-- face down) +; `advance`: studs crawled so far
export type CrawlPose = {
	rightShoulder: number,
	leftShoulder: number,
	rightElbow: number,
	leftElbow: number,
	neck: number,
	rightHip: number,
	leftHip: number,
	rightKnee: number,
	leftKnee: number,
	advance: number,
}

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

-- 0 -> 1 with a soft start and end
local function ease(share: number): number
	return (1 - math.cos(math.pi * clamp01(share))) / 2
end

-- The Hydra's HP share `elapsed` seconds into the fight after `dealt` (the share of its HP the fight has taken)
function PrologueRules.hpShare(elapsed: number, dealt: number, cfg: any): number
	local drop = 1 - cfg.END_SHARE
	local ceiling = 1 - drop * clamp01(elapsed / cfg.FIGHT.min) -- the lowest it may be by now
	local floor = 1 - drop * clamp01(elapsed / cfg.FIGHT.max) -- the highest it may still be
	return math.clamp(1 - dealt, ceiling, floor)
end

-- Whether the fight is over (act 3 begins)
function PrologueRules.done(share: number, cfg: any): boolean
	return share <= cfg.END_SHARE + 1e-9
end

-- The middle of lair `slot`'s floor (on its top), as plain numbers
function PrologueRules.arenaCentre(slot: number, cfg: any): { x: number, y: number, z: number }
	return { x = slot * cfg.ARENA.spacing, y = cfg.ARENA.height, z = 0 }
end

-- The lowest lair nobody is using
function PrologueRules.freeSlot(taken: { [number]: any }): number
	local slot = 0
	while taken[slot] ~= nil do
		slot += 1
	end
	return slot
end

-- The cards lent for the fight, in LOADOUT order (the first is summoned): each at `best`, foil, with an id no saved
-- card can have; a name `cardIds` doesn't know is left out
function PrologueRules.lentBeasts(cfg: any, cardIds: { [string]: string }, best: { level: number, stars: number, grade: string }): { LentBeast }
	local beasts: { LentBeast } = {}
	for _, name in cfg.LOADOUT.creatures do
		local cardId = cardIds[name]
		if cardId then
			table.insert(beasts, { id = `prologue_{#beasts + 1}`, cardId = cardId, foil = true, level = best.level, xp = 0, stars = best.stars, grade = best.grade })
		end
	end
	return beasts
end

-- The Hydra's blow `t` seconds after it lands (Config/Prologue KNOCK): how far back (studs, away from it) and up you are
-- and how far you've tumbled (degrees, backwards is -), landing face down with your head toward it
function PrologueRules.knock(t: number, cfg: any): { back: number, up: number, flip: number }
	local k = cfg.KNOCK
	local s = clamp01(t / k.seconds)
	return { back = k.back * (1 - (1 - s) ^ 2), up = 4 * k.height * s * (1 - s), flip = -k.flip * (1 - (1 - s) ^ 3) }
end

-- How far back the blow can throw you from (x, z) (studs from the lair's middle) along (dx, dz) (a flat unit
-- direction) without leaving its floor: KNOCK.back, or less to stay KNOCK.margin inside the edge; 0 if already past
function PrologueRules.knockRoom(x: number, z: number, dx: number, dz: number, cfg: any): number
	local reach = cfg.ARENA.radius + cfg.ARENA.rim - cfg.KNOCK.margin
	local c = x * x + z * z - reach * reach
	if c >= 0 then
		return 0
	end
	-- the far root of (x + dx b)^2 + (z + dz b)^2 = reach^2 (|d| = 1)
	local half = x * dx + z * dz
	local exit = -half + math.sqrt(half * half - c)
	return math.clamp(exit, 0, cfg.KNOCK.back)
end

-- How far one arm reaches (1: stretched out ahead, 0: pulled in) at `strokes` strokes into the crawl: it pulls during
-- its stroke and reaches out again during the other arm's
local function reachShare(strokes: number): number
	local cycle = strokes % 2
	return if cycle < 1 then 1 - ease(cycle) else ease(cycle - 1)
end

-- Your crawl toward the Hydra `t` seconds in (Config/Prologue CRAWL): the arms take turns pulling you forward a step
-- each, head up; after the last stroke your head sinks to the floor, one arm still reaching
function PrologueRules.crawl(t: number, cfg: any): CrawlPose
	local c = cfg.CRAWL
	local finish = c.stroke * c.strokes
	local at = math.min(t, finish)
	local strokes = at / c.stroke
	local within = strokes % 1
	local right, left = reachShare(strokes), reachShare(strokes + 1)
	local swing = math.sin(math.pi * strokes)
	local head = c.head * (0.8 + 0.2 * math.sin(math.pi * within))
	local sink = if t > finish then 1 - ease((t - finish) / c.collapse) else 1
	local done = math.floor(strokes)
	return {
		rightShoulder = c.pull + (c.reach - c.pull) * right,
		leftShoulder = c.pull + (c.reach - c.pull) * left,
		rightElbow = c.elbowPull + (c.elbowReach - c.elbowPull) * right,
		leftElbow = c.elbowPull + (c.elbowReach - c.elbowPull) * left,
		neck = head * sink,
		rightHip = c.hip * swing,
		leftHip = -c.hip * swing,
		rightKnee = c.knee * (0.5 + 0.5 * swing),
		leftKnee = c.knee * (0.5 - 0.5 * swing),
		advance = if t >= finish then c.step * c.strokes else c.step * (done + ease(within)),
	}
end

-- How open your eyes are (0 shut, 1 open) `t` seconds into waking up (Config/Prologue WAKE.lids: { seconds, open })
function PrologueRules.lids(t: number, cfg: any): number
	local keys = cfg.WAKE.lids
	if t <= keys[1][1] then
		return clamp01(keys[1][2])
	end
	for index = 2, #keys do
		local a, b = keys[index - 1], keys[index]
		if t <= b[1] then
			local share = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 1
			return clamp01(a[2] + (b[2] - a[2]) * share)
		end
	end
	return clamp01(keys[#keys][2])
end

-- The cards the Hydra takes, in the order they fly: your three Legendaries, then `names` (the others in the game, any
-- order) without those again, `count` in all at most
function PrologueRules.stolenCards(cfg: any, names: { string }, count: number): { string }
	local taken: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, name in cfg.LOADOUT.creatures do
		if #taken < count then
			table.insert(taken, name)
		end
		seen[name] = true
	end
	for _, name in names do
		if #taken >= count then
			break
		end
		if not seen[name] then
			seen[name] = true
			table.insert(taken, name)
		end
	end
	return taken
end

return PrologueRules
