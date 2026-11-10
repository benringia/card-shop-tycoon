--!strict
-- The loading screen on join and during teleports ("card fan", option C): three cards fanning out over a slim gold bar
-- and the step it's on, until the character, the save, the summoned creature and the fight gear are ready; since
-- 2026-11-05 in the Wild screen's feel (owner's option B, "the card fan in the swirl": the fan in front of a turning
-- swirl over the First Spark cover's sky)
-- (ReplicatedFirst/LoadingScreen shows it, Controllers/LoadingController drives it, Util/LoadingRules decides).
-- Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	TITLE = "Cardshop Simulator",
	FAN_CARDS = { "Infernox", "Solarion", "Abyssal Koi" }, -- card paintings (Config/CardArt SMALL), left to right
	FAN_DEGREES = 24, -- how far the side cards swing out
	FAN_SECONDS = 1.6, -- one swing out (then back)
	BACKGROUND = { top = rgb(27, 42, 74), bottom = rgb(13, 20, 36) },
	CARD_EDGE = rgb(255, 210, 122),
	-- Behind the fan: the First Spark cover's sky (its golden star and the five element orbs), dimmed, and the Wild
	-- screen's spiral twice, gold in front and pink behind, turning against each other
	BACKDROP = "rbxassetid://95161168581849", -- Config/BinderCovers First Spark
	BACKDROP_RECT = { 0, 0, 680, 560 }, -- x, y, width, height of the 680 x 1014 painting
	BACKDROP_TRANSPARENCY = 0.55,
	SWIRL = "rbxassetid://82162011115712", -- Config/WildLoading SWIRL (tools/textures/make_portal_swirl.py)
	SWIRL_COLORS = { rgb(255, 210, 122), rgb(255, 159, 207) }, -- in front, behind
	SWIRL_SIZE = 0.5, -- of the screen's height (the copy behind is 1.35x and fainter)
	SWIRL_SECONDS = { 7, 11 }, -- one turn: in front, behind (the other way)
	BAR_COLOR = rgb(255, 210, 122),
	NOTE_COLOR = rgb(255, 210, 122),
	-- Steps in order: the character, the save, the shop's pictures (product models, icons, covers), the summoned
	-- creature, the fight gear (art, sounds, moves)
	FIRST_STEP = { Main = "Opening your shop...", Frontier = "Opening the Frontier...", Dungeon = "Opening the Dungeon..." },
	STEPS = { "Getting everything ready...", "Loading your cards...", "Stocking the shelves...", "Waking up your creature...", "Getting the fight gear ready..." },
	READY = "Ready!",
	SLOW_SECONDS = 6, -- the save still loading after this: say why
	SLOW_NOTE = "Your save is still closing on another server, almost there!",
	MAX_SECONDS = 30, -- fades anyway after this, so nobody is stuck
	-- The town round you, with the shop's pictures (owner 2026-11-09: "in town. some models still load some time after
	-- the loading screen": a mesh is only fetched once it's drawn up close, so scenery popped in as you walked): the area
	-- round your character streamed in (at most STREAM_TIMEOUT seconds), then these Workspace folders' meshes and
	-- textures fetched; anything streaming in later is fetched as it arrives (LoadingController)
	TOWN_FOLDERS = { "TownDecor", "Town", "Scenery", "Plots" },
	STREAM_TIMEOUT = 8,
	FADE_SECONDS = 0.6,
	-- Each place's own look laid over the above (Util/LoadingRules.look, by Workspace PlaceKind): the Frontier's (spec
	-- 2026-11-10-frontier-valley-design: "the Wild portal's swirl in icy blue and violet, with the area's picture"),
	-- also carried by the main game's teleport there (LoadingRules.teleportLook)
	LOOKS = {
		Frontier = {
			TITLE = "The Frontier",
			BACKGROUND = { top = rgb(24, 32, 62), bottom = rgb(12, 10, 28) },
			BACKDROP = "rbxassetid://109335537720736", -- Frostwood (assets/ui/loading/frontier_frostwood.jpg, the area concept)
			BACKDROP_RECT = { 0, 0, 1376, 768 },
			BACKDROP_TRANSPARENCY = 0.45,
			SWIRL_COLORS = { rgb(150, 215, 255), rgb(170, 90, 255) }, -- icy blue in front, violet behind
			CARD_EDGE = rgb(150, 215, 255),
			BAR_COLOR = rgb(150, 215, 255),
			NOTE_COLOR = rgb(150, 215, 255),
			STEPS = { "Getting everything ready...", "Loading your cards...", "Raising the Frontier...", "Waking up your creature...", "Getting the fight gear ready..." },
			TIPS = {
				"Tip: everything in the Rift chases you. Stay together!",
				"Tip: red eyes in the fog? Something is watching you...",
				"Tip: each boss waits behind its portal by the trail.",
				"Tip: the Dungeon's crystal arch is at the far end of the Rift.",
			},
		},
	},
	TIP_SECONDS = 4, -- each tip shows this long
	TIPS = {
		"Tip: dodge when the ground glows!",
		"Tip: higher stars make your creature's perk stronger.",
		"Tip: swap creatures to change your fight perk.",
		"Tip: grade S cards are worth the most.",
	},
}
