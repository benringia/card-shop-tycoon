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

return SwordSkillFxRules
