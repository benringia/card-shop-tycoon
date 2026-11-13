--!strict
-- Shop decor (spec docs/superpowers/specs/2026-11-14-shop-decor-design.md, DESIGN "Shop decor"): the six shop looks
-- sold in the Shop menu's Decor tab (Util/DecorRules, DecorService, PlotService.SetLook) and the decor part of the
-- shop rating. The placeable pieces are Config/Shelves entries of kind "Decor". Plain data (colours { r, g, b },
-- materials by Enum.Material name), read by Lune tests.
return {
	DEFAULT_LOOK = "CozyWood", -- every shop's inside until another look is in use; always owned, never stored
	LOOK_POINTS = 2, -- decor points a look other than the default gives
	FULL = 8, -- decor points that fill the rating's decor part
	SPIN_SECONDS = 6, -- one turn of the Card Pedestal's floating card (DecorSpinController)
	-- The Floor Lamp's light on its Bulb (Util/DecorLooks.finish): small and shadowless, cheap on phones
	LAMP_LIGHT = { range = 10, brightness = 0.8, color = { 255, 220, 150 } },
	-- A piece's parts the game finishes by name (Util/DecorLooks.finish; the Blender pack and the stand-ins name them
	-- alike): Glow and Bulb glow in the piece's colour, Picture wears a picture
	GLOW_COLORS = {
		FloorLamp = { 255, 225, 160 },
		BoosterTower = { 255, 215, 90 },
		CardPedestal = { 190, 150, 255 },
	},
	-- the standee's Pish and Chikin hugging a pack (the card back's art, CardDesign BACK.IMAGE; the Support card's
	-- picture fails as a 3D texture), the pack statue's front (the First Spark phoenix, Config/Packs), the card frame's
	-- painting (Cindercub's card art, Config/CardArt FULL)
	PICTURES = {
		DogStandee = "rbxassetid://90882539153680",
		CardFrame = "rbxassetid://85793984557948",
		PackStatue = "rbxassetid://81309929146607",
	},

	-- A look dresses the inside only: the floor; a liner just inside each side wall and the back wall (FeatureWall)
	-- with a tiling wallpaper (`tile` studs a repeat; Figma-generated, made seamless by tools/textures/make_seamless.py,
	-- uploaded); a panel band along the bottom of the three walls and a glowing
	-- trim on top of it. `extra`: "topStrip" (a second glowing strip near the ceiling) or "crystals" (glowing crystal
	-- clusters along the wall bottoms), in `extraColor`. In price order: the Decor tab lists them this way.
	LOOKS = {
		{
			id = "CozyWood",
			name = "Cozy Wood",
			price = 0,
			level = 1,
			floor = { 196, 150, 104 },
			floorMaterial = "WoodPlanks",
			wall = { 246, 232, 210 },
			wallpaper = "rbxassetid://140274546163841", -- assets/ui/decor-wallpapers/CozyWood.png
			tile = 16,
			band = { 150, 100, 64 },
			bandMaterial = "WoodPlanks",
			trim = { 255, 214, 150 },
		},
		{
			id = "CandyPastel",
			name = "Candy Pastel",
			price = 500,
			level = 3,
			floor = { 255, 196, 222 },
			floorMaterial = "SmoothPlastic",
			wall = { 196, 240, 226 },
			wallpaper = "rbxassetid://107942581359523", -- assets/ui/decor-wallpapers/CandyPastel.png
			tile = 16,
			band = { 255, 255, 255 },
			bandMaterial = "SmoothPlastic",
			trim = { 255, 120, 180 },
		},
		{
			id = "EnchantedForest",
			name = "Enchanted Forest",
			price = 1000,
			level = 5,
			floor = { 110, 160, 82 },
			floorMaterial = "Grass",
			wall = { 196, 224, 170 },
			wallpaper = "rbxassetid://80265812410572", -- assets/ui/decor-wallpapers/EnchantedForest.png
			tile = 16,
			band = { 120, 84, 52 },
			bandMaterial = "Wood",
			trim = { 255, 236, 140 },
		},
		{
			id = "NeonArcade",
			name = "Neon Arcade",
			price = 2000,
			level = 8,
			floor = { 34, 30, 58 },
			floorMaterial = "SmoothPlastic",
			wall = { 52, 34, 96 },
			wallpaper = "rbxassetid://92983687469967", -- assets/ui/decor-wallpapers/NeonArcade.png
			tile = 16,
			band = { 24, 22, 40 },
			bandMaterial = "SmoothPlastic",
			trim = { 60, 240, 255 },
			extra = "topStrip",
			extraColor = { 255, 70, 200 },
		},
		{
			id = "CrystalCave",
			name = "Crystal Cave",
			price = 3500,
			level = 12,
			floor = { 70, 76, 120 },
			floorMaterial = "Slate",
			wall = { 96, 84, 160 },
			wallpaper = "rbxassetid://100802963912352", -- assets/ui/decor-wallpapers/CrystalCave.png
			tile = 16,
			band = { 60, 52, 110 },
			bandMaterial = "Slate",
			trim = { 190, 140, 255 },
			extra = "crystals",
			extraColor = { 200, 150, 255 },
		},
		{
			id = "StarryNight",
			name = "Starry Night",
			price = 5000,
			level = 16,
			floor = { 28, 34, 72 },
			floorMaterial = "Marble",
			wall = { 24, 30, 70 },
			wallpaper = "rbxassetid://94967248578003", -- assets/ui/decor-wallpapers/StarryNight.png
			tile = 16,
			band = { 18, 22, 52 },
			bandMaterial = "SmoothPlastic",
			trim = { 255, 220, 120 },
		},
	},

	-- The look's parts inside the shop (PlotService.SetLook). Studs above the floor's top.
	SHELL = {
		HEIGHT = 17, -- the liners' height (the walls are 18; the ceiling sits on top)
		BAND = 3.4, -- the panel band along the wall bottoms
		TRIM = 0.3, -- the glowing trim on top of the band
		TOP_STRIP = 15.5, -- the "topStrip" extra's height
		CRYSTALS = 16, -- the "crystals" extra's clusters
	},
}
