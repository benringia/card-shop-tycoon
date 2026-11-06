--!strict
-- The round 1 swords' own effects (sword skills round, spec 2026-11-06-sword-skills-design 2 and 4), drawn by the
-- client's Util/SwordSkillFx: each sword's slash (on cuts 1-3), finisher (cut 3's slam) and skill, named by its
-- Config/Swords moveset's `fx`. Textures are keys of AttackFx, MoveFx, SuperFx or SwordFx TEXTURES (reused where they
-- fit, spec 4). Placeholder numbers until each sword's round tunes its looks (Tasks 5-8): `seconds` the effect lasts,
-- `size` studs across at full scale, `count` particles; a skill's `form`: around you, ahead of you toward your aim, or
-- on the aimed foe. Plain data so Lune tests read it.
export type Kind = "slash" | "finisher" | "skill"
export type Form = "around" | "ahead" | "on"
export type Look = { kind: Kind, textures: { string }, seconds: number, size: number, count: number, form: Form? }

local LOOKS: { [string]: Look } = {
	-- Forge Sword: its element's trail, a burst of its element, the Elemental Spin's ring wave
	elementTrail = { kind = "slash", textures = { "spark", "glow" }, seconds = 0.5, size = 4, count = 8 },
	elementBurst = { kind = "finisher", textures = { "impact", "spark" }, seconds = 0.8, size = 6, count = 14 },
	elementalSpin = { kind = "skill", textures = { "ring", "spark" }, seconds = 1, size = 18, count = 24, form = "around" },
	-- Verdant Blade: leaves off each swing, roots and thorns under the foe, Thornline's vines
	leafShed = { kind = "slash", textures = { "shard", "glow" }, seconds = 0.7, size = 4, count = 8 },
	rootBurst = { kind = "finisher", textures = { "vine", "bark" }, seconds = 1, size = 6, count = 12 },
	thornline = { kind = "skill", textures = { "vine", "bark" }, seconds = 1.2, size = 18, count = 24, form = "ahead" },
	-- Sunforged Blade: a fire trail, the lava crack, Sunfall Cleave's crescent wave
	fireTrail = { kind = "slash", textures = { "flame", "spark" }, seconds = 0.5, size = 4, count = 10 },
	lavaCrack = { kind = "finisher", textures = { "crack", "flame", "smoke" }, seconds = 1.2, size = 8, count = 16 },
	sunfallCleave = { kind = "skill", textures = { "crescent", "flame" }, seconds = 1, size = 24, count = 28, form = "ahead" },
	-- Prism Blade: rainbow arcs, prism shards, Prism Judgment's ghost blades and pillar
	rainbowArc = { kind = "slash", textures = { "star", "glow" }, seconds = 0.5, size = 4, count = 8 },
	prismShatter = { kind = "finisher", textures = { "shard", "star" }, seconds = 0.9, size = 7, count = 16 },
	prismJudgment = { kind = "skill", textures = { "star", "glow" }, seconds = 1.6, size = 10, count = 30, form = "on" },
}

return {
	LOOKS = LOOKS,
	-- Other players' effects (spec 4 "Everyone sees them"): drawn within `range` studs of your camera, at most `full`
	-- at once in full; past that only their light version (Util/SwordSkillFxRules.drawsOthers)
	OTHERS = { range = 90, full = 3 },
	-- `/skillfx <sword> [cut1|cut2|cut3|skill] [level]` (DevService, the admin panel's "Sword skills"): the weapon each
	-- name previews, an element name for that element's Forge Sword
	PREVIEW = {
		sunforged = "sunforgedBlade",
		verdant = "verdantBlade",
		prism = "prismBlade",
		forge = "forgeSword_Ember",
		ember = "forgeSword_Ember",
		tide = "forgeSword_Tide",
		bloom = "forgeSword_Bloom",
		volt = "forgeSword_Volt",
		shade = "forgeSword_Shade",
	} :: { [string]: string },
}
