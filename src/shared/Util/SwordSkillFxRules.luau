--!strict
-- Rules for the round 1 swords' effects (sword skills round, spec 2026-11-06-sword-skills-design 4), pure so Lune tests
-- them: how big an effect draws, and whether another player's is drawn
local SwordSkillFxRules = {}

-- An effect's scale from the weapon's trail scale (WeaponLookRules.layers): its size until +7, then it grows with the
-- trail (1.2 / 1.35 / 1.5)
function SwordSkillFxRules.scale(trailScale: number): number
	return math.max(1, trailScale)
end

-- Another player's effect `distance` studs from your camera, with `fullDrawn` of theirs already drawing in full: full
-- within range while fewer than `others.full` are, then light (the slash only), none out of range
function SwordSkillFxRules.drawsOthers(distance: number, fullDrawn: number, others: { range: number, full: number }): "full" | "light" | "none"
	if distance > others.range then
		return "none"
	end
	return if fullDrawn < others.full then "full" else "light"
end

-- Your skill's camera moment at `t` seconds into the skill (Config/SwordSkillFx CINEMATIC): "rise" to the low angle,
-- "charge" held there until the cleave at `release`, "chase" after the crescent for its `travel` seconds, "impact" held
-- on the burst, "back" to your view, then "done"; and how far through that beat it is (0-1)
function SwordSkillFxRules.cinematicBeat(t: number, release: number, travel: number, cfg: { rise: number, hold: number, back: number }): (string, number)
	local landed = release + travel
	local beats = {
		{ name = "rise", from = 0, to = cfg.rise },
		{ name = "charge", from = cfg.rise, to = release },
		{ name = "chase", from = release, to = landed },
		{ name = "impact", from = landed, to = landed + cfg.hold },
		{ name = "back", from = landed + cfg.hold, to = landed + cfg.hold + cfg.back },
	}
	for _, beat in beats do
		if t < beat.to then
			return beat.name, if beat.to > beat.from then math.clamp((t - beat.from) / (beat.to - beat.from), 0, 1) else 1
		end
	end
	return "done", 1
end

-- How far out to the side the skill cinematic's wide shot stands so a flight `length` studs long, plus `margin` studs
-- either side, fits across a camera `fov` degrees tall on a screen `aspect` wide to tall; never nearer than `least`
function SwordSkillFxRules.wideDistance(length: number, margin: number, fov: number, aspect: number, least: number): number
	local across = 2 * math.atan(math.tan(math.rad(fov) / 2) * aspect)
	return math.max(least, (length / 2 + margin) / math.tan(across / 2))
end

-- The wide shot's distance `out` zoomed out past the body the skill lands on: `reach` studs from its middle to its
-- side (0: nothing there) plus `clearance`, so the camera never stands inside a big boss
function SwordSkillFxRules.wideClear(out: number, reach: number, clearance: number): number
	if reach <= 0 then
		return out
	end
	return math.max(out, reach + clearance)
end

-- How much of a Verdant look's vines to draw (final review 2026-11-07: phones): all of them, in full, for your own; on
-- low graphics (or a struggling frame rate) or for another player's cast, rows `spacing` times as far apart, `share` of
-- the trap ring's and roots' vines, and stems only (`details` off: no thorns, leaf or bud)
function SwordSkillFxRules.vineBudget(lowGraphics: boolean, others: boolean): { spacing: number, share: number, details: boolean }
	if lowGraphics or others then
		return { spacing = 2, share = 0.5, details = false }
	end
	return { spacing = 1, share = 1, details = true }
end

-- Where Torrent Strike's big columns burst (Config/SwordSkillFx torrentStrike beats): under every foe of `targets`
-- (SwordRules targets: id, x, z, radius) whose edge is within `radius` of (px, pz), as the server's spin counts it, at
-- its near edge (`foeEdge` of its radius in from its centre, toward you), one size larger per `foeSizeStuds` of its
-- radius up to `foeSizeMax`
function SwordSkillFxRules.torrentFoes(beats: { [string]: number }, px: number, pz: number, targets: { { id: string, x: number, z: number, radius: number } }): { { id: string, x: number, z: number, size: number } }
	local foes = {}
	for _, target in targets do
		local dx, dz = target.x - px, target.z - pz
		local distance = math.sqrt(dx * dx + dz * dz)
		if distance - target.radius < beats.radius then
			local inward = if distance > 1e-6 then math.min(target.radius * beats.foeEdge, distance) / distance else 0
			table.insert(foes, {
				id = target.id,
				x = target.x - dx * inward,
				z = target.z - dz * inward,
				size = math.clamp(target.radius / beats.foeSizeStuds, 1, beats.foeSizeMax),
			})
		end
	end
	return foes
end

-- Torrent Strike's torrents (Config/SwordSkillFx torrentStrike beats; owner 2026-11-09: "make the torrents appear at a
-- random at a time.by one or by two torrents"): `torrents` of them in bursts of one or two (two with `pairShare`), the
-- first burst at `hit`, the rest spread evenly to `hit + spread` with a little jitter; each at a random spot `nearest`-
-- `radius` studs from you (x to your right, z ahead), `apart` studs from every other, kept `lane` studs off your
-- left-right line (the side camera looks in along it), `columnHeight`-`outerHeight` tall. `rand()` returns 0-1. A
-- torrent with no room left after a few tries is dropped.
local SPOT_TRIES = 40
local JITTER = 0.2 -- a burst moves up to this share of the gap between bursts, so they stay in order
function SwordSkillFxRules.torrentBursts(beats: { [string]: number }, rand: () -> number): { { at: number, x: number, z: number, height: number } }
	local sizes: { number } = {}
	local left = beats.torrents
	while left > 0 do
		local size = if left >= 2 and rand() < beats.pairShare then 2 else 1
		table.insert(sizes, size)
		left -= size
	end
	local step = if #sizes > 1 then beats.spread / (#sizes - 1) else 0
	local near2, far2 = beats.nearest * beats.nearest, beats.radius * beats.radius
	local bursts = {}
	for index, size in sizes do
		local at = beats.hit + step * (index - 1)
		if index > 1 and index < #sizes then
			at += (rand() * 2 - 1) * JITTER * step
		end
		for _ = 1, size do
			for _ = 1, SPOT_TRIES do
				local distance = math.sqrt(near2 + rand() * (far2 - near2)) -- even over the area
				local angle = rand() * 2 * math.pi
				local x, z = math.sin(angle) * distance, math.cos(angle) * distance
				local clear = math.abs(z) >= beats.lane
				for _, other in bursts do
					if clear and (other.x - x) ^ 2 + (other.z - z) ^ 2 < beats.apart * beats.apart then
						clear = false
					end
				end
				if clear then
					local height = beats.columnHeight + rand() * (beats.outerHeight - beats.columnHeight)
					table.insert(bursts, { at = at, x = x, z = z, height = height })
					break
				end
			end
		end
	end
	return bursts
end

-- Whether a skill look's camera moment frames you where you stand (a look drawn round you, Torrent Strike) rather than
-- where its effect lands ahead
function SwordSkillFxRules.framesOnCaster(look: { form: string? }): boolean
	return look.form == "around"
end

-- An arc of `seconds` from angle `from` to `to`, due to start `startIn` seconds from now: when to start it, from where
-- and over how long. One already due (a cut's slash is called at the sword's arc start, SwordFx.ARCS, after the
-- scythe's Whirlwind turns have begun) starts now from where the swing is, so it still ends on time; nothing is drawn
-- twice.
function SwordSkillFxRules.arcCatchUp(startIn: number, seconds: number, from: number, to: number): (number, number, number)
	if startIn >= 0 or seconds <= 0 then
		return math.max(0, startIn), from, seconds
	end
	local gone = math.min(-startIn, seconds)
	return 0, from + (to - from) * gone / seconds, seconds - gone
end

-- How many pieces a scythe crescent over `angle` radians is laid in: `perHalfTurn` for every half turn, half that for
-- another player's (or on low graphics), never under three
function SwordSkillFxRules.scythePieces(angle: number, lite: boolean, perHalfTurn: number): number
	local per = if lite then perHalfTurn / 2 else perHalfTurn
	return math.max(3, math.round(math.abs(angle) / math.pi * per))
end

-- Whether a skill's camera moment still watches for a cancel (a dodge or a switch ends it) `t` seconds in: until its
-- effect leaves (`release`), or until the skill's hit (`hit`) when that comes later (Thousand Cuts' moment starts at
-- 0.75 s, its hit at 1.8 s; final review 2026-11-09: a dodge in between left the camera on the wide shot)
function SwordSkillFxRules.cinematicWatches(t: number, release: number, hit: number?): boolean
	return t < math.max(release, hit or 0)
end

-- How far ahead of you cut 3's finisher draws: where you stand for a look drawn round you (the scythe's Whirlwind), at
-- the end of the cut's line (`lineLength`: the spear's plunge), else nil (just ahead: a sword's slam, SwordSkillFx)
function SwordSkillFxRules.finisherAhead(look: { form: string? }, lineLength: number?): number?
	if look.form == "around" then
		return 0
	end
	return lineLength
end

-- Which side a skill's camera moment stands off to (1 right, -1 left; the owner 2026-11-11: "the camera just zooms in
-- with the boss blocking"): the one with fewer bodies between it and you or the skill's effect; on a tie, the one walls
-- and hills block least (each side's clear share, 0-1)
function SwordSkillFxRules.cinematicSide(rightBodies: number, leftBodies: number, rightClear: number, leftClear: number): number
	if leftBodies ~= rightBodies then
		return if leftBodies < rightBodies then -1 else 1
	end
	return if leftClear > rightClear then -1 else 1
end

return SwordSkillFxRules
