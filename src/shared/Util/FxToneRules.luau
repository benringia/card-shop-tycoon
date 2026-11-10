--!strict
-- Effects toned to the scene's brightness (the owner 2026-11-10: "the particles are too bright on a white map like
-- this"; Config/FxTone, applied by Util/FxTone): how bright the scene is from the ground's and fog's colours, and what
-- that does to an effect: less additive light and brightness, a glowing white core fading, lights dimming. Pure,
-- Lune-tested. Colours are { r, g, b } 0-255.
local FxToneRules = {}

local function luminance(rgb: { number }): number
	return (0.2126 * rgb[1] + 0.7152 * rgb[2] + 0.0722 * rgb[3]) / 255
end

-- How bright the scene is, 0 (as made) to 1 (fully toned), from the ground under you and the fog
function FxToneRules.level(ground: { number }, fog: { number }, cfg: any): number
	local scene = luminance(ground) * cfg.ground + luminance(fog) * cfg.fog
	return math.clamp((scene - cfg.from) / (cfg.to - cfg.from), 0, 1)
end

export type Base = { lightEmission: number, brightness: number, color: { number } }
export type Toned = { lightEmission: number, brightness: number, fade: number }

-- An effect at `level`: its additive light and brightness lowered; `fade` (0-1): how far a glowing white core goes
-- toward clear (0 for anything coloured, or soft and not glowing: smoke, mist)
function FxToneRules.tone(base: Base, level: number, cfg: any): Toned
	local white = base.color[1] >= cfg.white and base.color[2] >= cfg.white and base.color[3] >= cfg.white
	local core = white and base.lightEmission >= cfg.coreLight
	return {
		lightEmission = base.lightEmission * (1 - cfg.emission * level),
		brightness = base.brightness * (1 - cfg.brightness * level),
		fade = if core then cfg.whiteFade * level else 0,
	}
end

-- A transparency value faded `fade` of the way to clear (its opacity times 1 - fade)
function FxToneRules.fadeValue(transparency: number, fade: number): number
	return 1 - (1 - transparency) * (1 - fade)
end

-- An effect light's brightness at `level`
function FxToneRules.lightBrightness(brightness: number, level: number, cfg: any): number
	return brightness * (1 - cfg.light * level)
end

return FxToneRules
