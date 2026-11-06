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

-- How much of a Verdant look's vines to draw (final review 2026-11-07: phones): all of them, in full, for your own; on
-- low graphics (or a struggling frame rate) or for another player's cast, rows `spacing` times as far apart, `share` of
-- the trap ring's and roots' vines, and stems only (`details` off: no thorns, leaf or bud)
function SwordSkillFxRules.vineBudget(lowGraphics: boolean, others: boolean): { spacing: number, share: number, details: boolean }
	if lowGraphics or others then
		return { spacing = 2, share = 0.5, details = false }
	end
	return { spacing = 1, share = 1, details = true }
end

return SwordSkillFxRules
