--!strict
-- Footsteps (the owner 2026-11-11: "lets just add a footsteps sound effect on whatever the character is stepping on";
-- Util/FootstepRules, FootstepController): a step every STRIDE studs a walking character covers on the ground, the
-- sound of the floor's surface (MATERIALS by Enum.Material name, else DEFAULT; none in the air or water), a different
-- one of the surface's sounds each step at a random pitch in PITCH. Your own at full volume, other players' within RANGE
-- studs (the nearest MAX_OTHERS) at OTHERS of it. Roblox's own running loop is muted under them. Plain data.
-- Pro Sound Effects has no plain human footsteps in Roblox's licensed library, so these are its nearest surface hits:
-- dirt thuds, a foliage rustle, loose sand, snow crunches, muted wood thuds, and a foot stomp (several in one clip:
-- `region` plays only its first `region` seconds).
return {
	STRIDE = 5.5, -- studs a step (16 studs a second: about 3 steps a second)
	MIN_SPEED = 3, -- studs a second: slower is shuffling, no steps
	PITCH = { 0.9, 1.12 },
	OTHERS = 0.6,
	RANGE = 45,
	MAX_OTHERS = 6,
	ROLL_OFF = 40, -- studs: other players' steps fade out by here
	-- volumes half of the first try's (the owner 2026-11-11: "lower the volume of the footsteps")
	SURFACES = {
		grass = {
			ids = {
				"rbxassetid://9118685591", -- Rocks Dirt Impacts In Ground 12 (muted thud)
				"rbxassetid://9118686853", -- Rocks Dirt Impacts In Ground 30
				"rbxassetid://9114517148", -- Foliage Drop 5 (light rustle)
			},
			volume = 0.175,
		},
		dirt = {
			ids = {
				"rbxassetid://9118685591", -- Rocks Dirt Impacts In Ground 12
				"rbxassetid://9118686853", -- Rocks Dirt Impacts In Ground 30
				"rbxassetid://9118688024", -- Rocks Dirt Impacts In Ground 45
				"rbxassetid://9118687440", -- Rocks Dirt Impacts In Ground 40
			},
			volume = 0.2,
		},
		sand = {
			ids = {
				"rbxassetid://9118768256", -- Sand Impacts 4 (loose, sharp)
				"rbxassetid://9118768193", -- Sand Impacts 5
			},
			volume = 0.175,
		},
		snow = {
			ids = {
				"rbxassetid://9119310905", -- Snowball Hits Lands Semi-Deep Snow 8 (crunch)
				"rbxassetid://9119310903", -- Snowball Hits Lands Semi-Deep Snow 9
				"rbxassetid://9119316983", -- Snow Scrape Multiple Short Slides Crispy 2
			},
			volume = 0.175,
		},
		wood = {
			ids = {
				"rbxassetid://9120880067", -- Wood Grab Muted Thuds 15
				"rbxassetid://9120880314", -- Wood Grab Muted Thuds 17
			},
			volume = 0.225,
		},
		stone = {
			ids = {
				"rbxassetid://9114523161", -- Foot Stomp 1 (hard floor)
				"rbxassetid://9114523351", -- Foot Stomp 2
				"rbxassetid://9114523345", -- Foot Stomp 3
				"rbxassetid://9114523358", -- Foot Stomp 4
			},
			volume = 0.15,
			region = 0.28,
		},
	},
	DEFAULT = "stone", -- plastic, metal, glass and the rest: a hard floor
	MATERIALS = {
		Grass = "grass",
		LeafyGrass = "grass",
		Ground = "dirt",
		Mud = "dirt",
		Pebble = "dirt",
		Sand = "sand",
		Snow = "snow",
		Glacier = "snow",
		Ice = "snow",
		Wood = "wood",
		WoodPlanks = "wood",
		Concrete = "stone",
		Cobblestone = "stone",
		Brick = "stone",
		Pavement = "stone",
		Asphalt = "stone",
		Slate = "stone",
		Rock = "stone",
		Basalt = "stone",
		Granite = "stone",
		Marble = "stone",
		Limestone = "stone",
		Sandstone = "stone",
		CrackedLava = "stone",
		Salt = "stone",
	} :: { [string]: string },
	NONE = { Air = true, Water = true } :: { [string]: boolean }, -- no floor to step on
}
