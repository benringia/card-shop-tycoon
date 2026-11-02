--!strict
-- How the player's fight looks and feels (spec 2026-11-02-you-in-the-fight-design): the closing-ring warning (look B),
-- hit feel (sparks, a flash on what you hit, hit-stop, shake), the slash trail, the boss's wind-up glow and the loss
-- countdown. Ring textures: tools/textures/make_ring_textures.py, uploaded. Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	-- Closing rings: a thin outline of the area and a glowing ring closing onto it (RingRules.closingScale)
	RING_OUTLINE = "rbxassetid://127119552313668",
	RING_GLOW = "rbxassetid://78616850376916",
	CONE_OUTLINE = "rbxassetid://113532760508849",
	CONE_GLOW = "rbxassetid://124524147480952",
	RING_FIT = { outline = 1.024, glow = 1.09 }, -- the textures' margins: a texture this many times the area fits it
	RING_COLOR = rgb(255, 255, 255),
	RING_OUTLINE_TRANSPARENCY = 0.25,
	RING_LIFT = 0.15, -- studs above the ground (no z-fighting)
	RING_FLASH_SECONDS = 0.3, -- the white flash as it lands, fading out
	RING_GROUND_RAY = 30, -- studs down from the ring's height to find the ground

	-- Hits
	HIT_STOP_SECONDS = 0.06, -- your sword's animation freezes this long on a hit
	FLASH_SECONDS = 0.12, -- what you hit flashes white this long
	SPARKS = 14, -- sparks per sword hit
	SPARK_COLOR = rgb(255, 236, 170),
	SHAKE = { cut = { seconds = 0.08, studs = 0.12 }, skill = { seconds = 0.18, studs = 0.3 }, hurt = { seconds = 0.15, studs = 0.25 } },

	-- The slash trail on your blade while a cut or the skill swings
	TRAIL_SECONDS = 0.35,
	TRAIL_LIFETIME = 0.16,
	TRAIL_COLOR = rgb(210, 235, 255),
	TRAIL_BLADE = { base = 0.8, tip = 4.3 }, -- studs up the blade from the grip

	-- The boss winding up: a quick hit flashes it red; a big attack rears it back (its roar pose) with an orange glow
	WINDUP_QUICK_COLOR = rgb(255, 70, 70),
	WINDUP_BIG_COLOR = rgb(255, 160, 60),
	WINDUP_FILL = 0.55, -- the glow's strongest (Highlight fill transparency)
}
