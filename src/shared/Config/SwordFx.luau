--!strict
-- How the player's fight looks and feels (spec 2026-11-02-you-in-the-fight-design): the closing-ring warning (look B),
-- hit feel (sparks, a flash on what you hit, hit-stop, shake), the slash trail, the boss's wind-up glow and the loss
-- countdown. Ring textures: tools/textures/make_ring_textures.py, uploaded. Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	-- The sword-moves round's effect textures (tools/textures/make_sword_fx.py, assets/ui/fx-sword), white, tinted in
	-- game: the swing arc's body (upright: a Beam runs a texture's height along its length), the hit's star burst (a
	-- 4 x 4 flipbook), the dash slash's cut lines (upright) and the stars the arc sheds
	TEXTURES = {
		crescent = "rbxassetid://103655929836006",
		burst = "rbxassetid://114900780647359",
		line = "rbxassetid://111098556704939",
		star = "rbxassetid://117269166059195",
	},

	-- Closing rings: a thin outline of the area and a glowing ring closing onto it (RingRules.closingScale)
	RING_OUTLINE = "rbxassetid://127119552313668",
	RING_GLOW = "rbxassetid://78616850376916",
	CONE_OUTLINE = "rbxassetid://113532760508849",
	CONE_GLOW = "rbxassetid://124524147480952",
	RING_FIT = { outline = 1.024, glow = 1.09 }, -- the textures' margins: a texture this many times the area fits it
	RING_COLOR = rgb(255, 122, 26), -- orange (owner's pick from the mockup): stands out on every arena floor
	RING_OUTLINE_TRANSPARENCY = 0.25,
	RING_LIFT = 0.15, -- studs above the ground (no z-fighting)
	RING_FLASH_SECONDS = 0.3, -- the white flash as it lands, fading out
	RING_GROUND_RAY = 30, -- studs down from the ring's height to find the ground

	-- Hits
	-- Your swing freezes this long on a hit (hit-stop; sword-moves round): a cut, and the finisher or the dash slash
	HIT_STOP = { cut = 0.08, big = 0.12 },
	FADE = { strike = 0.04 }, -- seconds a cut or the skill blends in (Util/SwordAnims): snappy, no mushy start
	FLASH_SECONDS = 0.12, -- what you hit flashes white this long
	SPARKS = 14, -- sparks per sword hit
	SPARK_COLOR = rgb(255, 236, 170),
	SHAKE = { cut = { seconds = 0.08, studs = 0.12 }, skill = { seconds = 0.18, studs = 0.3 }, hurt = { seconds = 0.15, studs = 0.25 } },

	-- A sword hit's slash arc (Util/HitFx.cut; its colour and size are the sword's, Config/Swords slash): `size` studs,
	-- this far in front of you (`ahead`), the combo's last cut and the skill bigger; the skill adds a ring at your feet
	SLASH = { size = 4.2, ahead = 4, up = 1.2, finisher = 1.25, skill = 1.7, skillRing = 11, flash = 1.6 },

	-- The slash trail on your blade while a cut or the skill swings
	TRAIL_SECONDS = 0.35,
	TRAIL_LIFETIME = 0.16,
	TRAIL_COLOR = rgb(210, 235, 255),
	TRAIL_BLADE = { base = 0.8, tip = 4.3 }, -- studs up the blade from the grip
	-- Drawing your sword: a flash of light and a glint at the blade's tip
	GLEAM = { seconds = 0.3, brightness = 4, range = 8, size = 2.2, color = rgb(255, 250, 225) },

	-- The boss winding up: a quick hit flashes it red; a big attack rears it back (its roar pose) with an orange glow
	WINDUP_QUICK_COLOR = rgb(255, 70, 70),
	WINDUP_BIG_COLOR = rgb(255, 160, 60),
	WINDUP_FILL = 0.55, -- the glow's strongest (Highlight fill transparency)
}
