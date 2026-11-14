--!strict
-- Every loading screen is the binder (owner 2026-11-13, spec docs/superpowers/specs/2026-11-13-loading-screen-binder-
-- design.md): a binder open over the world's own painting, a card of Pish, Chikin or Turts sliding into a pocket for
-- each bit loaded (9 pockets: in), the count, the step and a tip, under a pink "ONE MORE PACK" ribbon. On join and
-- teleports (ReplicatedFirst/LoadingScreen shows it, Controllers/LoadingController drives it) and on the Wild portal
-- (Controllers/WildLoadingController, its steps in Config/WildLoading); Util/LoadingRules decides. Each place's look
-- (LOOKS, by Workspace PlaceKind, and "Wild" for the portal) is laid over the main one. Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	TITLE = "ONE MORE PACK", -- the ribbon: the game's name everywhere
	PLACE = "", -- the place's name above the count (none in town)
	ACCENT = rgb(255, 210, 60), -- the count, the stitching, "Ready!", the slow-save note
	ACCENT_DROP = rgb(107, 61, 0), -- the count's darker drop
	BACKGROUND = { top = rgb(42, 47, 69), bottom = rgb(18, 19, 28) }, -- under the painting until it's in
	-- The world's painting behind the binder: town, Pish and Chikin's shop at night (Config/PackOpening BACKDROP.IMAGE;
	-- the two peek out from the corners). BACKDROP_RECT: x, y, width, height in the picture; width 0: the whole picture
	BACKDROP = "rbxassetid://89947475330742",
	BACKDROP_RECT = { 0, 0, 0, 0 },
	DIM_TRANSPARENCY = 0.45, -- the dark layer over the painting, so the binder reads
	POCKETS = 9,
	-- The binder's cards: the dogs painted in the card art's style (owner 2026-11-14: art, not their models), each in
	-- an element's scene, their names on a plate (docs/card-art.md "The loading screen's dog cards",
	-- tools/ui-art/make_dog_cards.py; assets/ui/loading/dog_cards/cards). In this order, each with its rarity rim (RIMS)
	DOG_CARDS = {
		{ dog = "Pish", image = "rbxassetid://132626957541066", rarity = "Legendary" }, -- pointing, moonlit garden
		{ dog = "Chikin", image = "rbxassetid://74101055717473", rarity = "Epic" }, -- pointing, by the fire
		{ dog = "Turts", image = "rbxassetid://98367774695397", rarity = "Very Rare" }, -- sitting, stormy peak
		{ dog = "Chikin", image = "rbxassetid://127074815682951", rarity = "Rare" }, -- sitting, lagoon
		{ dog = "Turts", image = "rbxassetid://114836884250612", rarity = "Epic" }, -- a head tilt, by the fire
		{ dog = "Pish", image = "rbxassetid://124790936790346", rarity = "Legendary" }, -- a head tilt, forest
		{ dog = "Turts", image = "rbxassetid://94613521922105", rarity = "Legendary" }, -- leaping for joy, forest
		{ dog = "Pish", image = "rbxassetid://89084052661370", rarity = "Very Rare" }, -- a play bow, lagoon
		{ dog = "Chikin", image = "rbxassetid://119200752178063", rarity = "Epic" }, -- a hop, stormy peak
	},
	RIMS = {
		Legendary = rgb(255, 200, 40),
		Epic = rgb(170, 80, 255),
		["Very Rare"] = rgb(40, 210, 200),
		Rare = rgb(70, 140, 255),
	},
	RIBBON = { top = rgb(255, 92, 138), bottom = rgb(214, 42, 100), drop = rgb(122, 15, 51) },
	-- The binder (Config/Collection BOOK's leather): its case, pages, pockets, rings, the count's "/ 9"
	BOOK = {
		case = rgb(32, 34, 46),
		page = rgb(38, 42, 55),
		pocket = rgb(52, 56, 73),
		pocketEdge = rgb(88, 94, 116),
		ring = rgb(245, 247, 252),
		muted = rgb(205, 210, 230),
	},
	TIP_COLORS = { back = rgb(255, 248, 230), text = rgb(59, 42, 82) },
	-- Something moving from the first frame, before any card flies in (owner 2026-11-14: "at first glance look static.
	-- add some elements that indicates it is loading", option B of three): Pish trots on the spot under the step over a
	-- road running back under him. His trot sheet (assets/ui/loading/pish_walk.png, tools/blender/build_pish_walk_sheet.py:
	-- FRAMES frames of FRAME_SIZE pixels, COLUMNS across, trotting left to right; FEET: where his feet land, down a frame)
	-- at FPS frames a second; the road's DASHES dashes run back ROAD_SPEED dash-lengths a second. Never progress: the
	-- pockets alone say how far it is.
	TROT = {
		IMAGE = "rbxassetid://123917292492684",
		FRAMES = 12,
		COLUMNS = 4,
		FRAME_SIZE = 256,
		FPS = 14,
		FEET = 0.8,
		DASHES = 9,
		ROAD_SPEED = 1.6,
	},
	DOTS_SECONDS = 0.35, -- the step's dots count up one at a time this often ("Stocking the shelves...")
	FLY_SECONDS = 0.45, -- a card sliding into its pocket
	FLY_STAGGER = 0.12, -- seconds between cards when several pockets fill at once
	READY_HOLD = 0.4, -- "Ready!" shows this long before the screen fades
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
	-- The Dungeon's cavern (its own loading step): DungeonBuilder's world folder, and ground found under you within
	-- GROUND_DEPTH studs
	CAVERN = { FOLDER = "Dungeon", GROUND_DEPTH = 60 },
	FADE_SECONDS = 0.6,
	-- Each place's own look laid over the above (Util/LoadingRules.look): its painting, colour, name, steps and tips
	LOOKS = {
		-- The Wild portal (Controllers/WildLoadingController; its steps and timings in Config/WildLoading): the First
		-- Spark cover's flowery valley, as the Wild's screen had
		Wild = {
			PLACE = "THE WILD",
			ACCENT = rgb(74, 222, 128),
			ACCENT_DROP = rgb(13, 74, 36),
			BACKGROUND = { top = rgb(28, 61, 40), bottom = rgb(8, 19, 12) },
			BACKDROP = "rbxassetid://95161168581849", -- Config/BinderCovers First Spark
			BACKDROP_RECT = { 0, 500, 680, 380 }, -- its hills and flowers (of the 680 x 1014 painting)
			TIPS = {
				"Tip: monsters get stronger the further you go.",
				"Tip: swap to a creature whose element beats the boss's.",
				"Tip: the healing spring wakes resting cards 3x faster.",
				"Tip: an elite monster drops better loot.",
			},
		},
		-- The Frontier (spec 2026-11-10-frontier-valley-design), also on the Wild portal inside the Frontier: Frostwood
		Frontier = {
			PLACE = "THE FRONTIER",
			ACCENT = rgb(150, 215, 255),
			ACCENT_DROP = rgb(23, 58, 99),
			BACKGROUND = { top = rgb(31, 45, 88), bottom = rgb(10, 12, 28) },
			BACKDROP = "rbxassetid://109335537720736", -- Frostwood (assets/ui/loading/frontier_frostwood.jpg)
			BACKDROP_RECT = { 0, 0, 0, 0 },
			STEPS = { "Getting everything ready...", "Loading your cards...", "Raising the Frontier...", "Waking up your creature...", "Getting the fight gear ready..." },
			TIPS = {
				"Tip: everything in the Rift chases you. Stay together!",
				"Tip: red eyes in the fog? Something is watching you...",
				"Tip: each boss waits behind its portal by the trail.",
				"Tip: the Dungeon's crystal arch is at the far end of the Rift.",
			},
		},
		-- The Dungeon: the Crystal Abyss (assets/ui/loading/dungeon_abyss.jpg, Figma-generated), and its cavern step
		Dungeon = {
			PLACE = "THE DUNGEON",
			ACCENT = rgb(201, 162, 255),
			ACCENT_DROP = rgb(61, 26, 110),
			BACKGROUND = { top = rgb(46, 29, 82), bottom = rgb(13, 8, 24) },
			BACKDROP = "rbxassetid://123239577474460",
			BACKDROP_RECT = { 0, 0, 0, 0 },
			STEPS = { "Getting everything ready...", "Loading your cards...", "Lighting the crystal cave...", "Waking up your creature...", "Getting the fight gear ready..." },
			TIPS = {
				"Tip: solve each room's puzzle to open the next gate.",
				"Tip: stay together, the Hydra hits hard!",
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
