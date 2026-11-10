--!strict
-- The town's day cycle (Portal Worlds spec): morning (the longest stretch), afternoon, sunset, a short night, dawn, the
-- same for everyone in town in a server. Each phase keeps its own sky, haze, bloom and colours, then blends into the
-- next over its last BLEND_SECONDS; the sun creeps from the phase's clockTime to its clockEnd the whole time. Outside
-- TOWN_REGION (the Wild, the Arena stands, the boss arenas) the FIXED phase's look shows, so fights never happen at
-- night. Util/DayCycle does the maths; DayCycleController applies it on each client. Plain data, read by Lune tests.
-- Colours are { r, g, b }; atmosphere is { density, offset, haze, glare, color, decay }; bloom { intensity, size,
-- threshold }; sunRays { intensity, spread }.

local MORNING = {
	clockTime = 7.3,
	brightness = 2.2,
	exposure = 0,
	ambient = { 105, 110, 130 },
	outdoorAmbient = { 135, 140, 165 },
	atmosphere = { density = 0.33, offset = 0.12, haze = 1.8, glare = 0.5, color = { 255, 228, 200 }, decay = { 170, 195, 235 } },
	bloom = { intensity = 0.4, size = 30, threshold = 1.6 },
	saturation = 0.18,
	contrast = 0.05,
	tint = { 255, 246, 236 },
	sunRays = { intensity = 0.07, spread = 0.6 },
}

-- Today's look before the cycle (was Town.LIGHTING): the Wild and the Arena keep it
local AFTERNOON = {
	clockTime = 15.5,
	brightness = 1.6,
	exposure = -0.25,
	ambient = { 110, 102, 96 },
	outdoorAmbient = { 120, 112, 105 },
	atmosphere = { density = 0.25, offset = 0.1, haze = 1.2, glare = 0.2, color = { 225, 215, 200 }, decay = { 140, 160, 190 } },
	bloom = { intensity = 0.25, size = 24, threshold = 2 },
	saturation = 0.12,
	contrast = 0,
	tint = { 255, 255, 255 },
	sunRays = { intensity = 0, spread = 0 },
}

local SUNSET = {
	clockTime = 17.6,
	brightness = 2.6,
	exposure = 0.1,
	ambient = { 125, 95, 100 },
	outdoorAmbient = { 155, 115, 115 },
	atmosphere = { density = 0.3, offset = 0.15, haze = 1.5, glare = 1.2, color = { 255, 175, 125 }, decay = { 140, 100, 160 } },
	bloom = { intensity = 0.5, size = 32, threshold = 1.4 },
	saturation = 0.22,
	contrast = 0.08,
	tint = { 255, 230, 212 },
	sunRays = { intensity = 0.12, spread = 0.7 },
}

-- ambient lights the shops' insides (and shade); outdoorAmbient the open air. Night keeps the air dark and blue but the
-- shops warm and readable
local NIGHT = {
	clockTime = 21.5,
	brightness = 0.6,
	exposure = 0,
	ambient = { 130, 118, 120 },
	outdoorAmbient = { 60, 70, 110 },
	atmosphere = { density = 0.35, offset = 0.1, haze = 1, glare = 0, color = { 90, 110, 170 }, decay = { 40, 50, 90 } },
	bloom = { intensity = 0.6, size = 30, threshold = 1.2 },
	saturation = 0.1,
	contrast = 0.1,
	tint = { 215, 225, 255 },
	sunRays = { intensity = 0, spread = 0 },
}

local DAWN = {
	clockTime = 5.6,
	brightness = 1.2,
	exposure = 0,
	ambient = { 110, 105, 130 },
	outdoorAmbient = { 130, 120, 150 },
	atmosphere = { density = 0.36, offset = 0.12, haze = 2, glare = 0.4, color = { 255, 200, 190 }, decay = { 150, 150, 200 } },
	bloom = { intensity = 0.45, size = 30, threshold = 1.5 },
	saturation = 0.15,
	contrast = 0.04,
	tint = { 255, 235, 235 },
	sunRays = { intensity = 0.06, spread = 0.6 },
}

return {
	-- seconds: how long the phase lasts; clockEnd: where the sun has crept to when the phase starts blending onward
	PHASES = {
		{ name = "morning", seconds = 420, look = MORNING, clockEnd = 15.2 },
		{ name = "afternoon", seconds = 300, look = AFTERNOON, clockEnd = 17.3 },
		{ name = "sunset", seconds = 240, look = SUNSET, clockEnd = 18.2 },
		{ name = "night", seconds = 120, look = NIGHT, clockEnd = 2.5 },
		{ name = "dawn", seconds = 90, look = DAWN, clockEnd = 7 },
	},
	BLEND_SECONDS = 40,
	FIXED = "afternoon",
	TOWN_REGION = { HALF_X = 320, HALF_Z = 300 }, -- studs round the plaza: the town and its three portal areas
	UPDATE_HZ = 10, -- each client updates the lighting this often
	SPECULAR = 0.35, -- how much walls and floors reflect the sky (Roblox default 1 makes bright patches)
	-- The Wild valley's areas with a look of their own (by zone, Config/WildValley BIOMES; spec
	-- 2026-11-04-valley-scenery-design): blended in over AREA_BLEND seconds while you're in one (DayCycle.areaMix), out
	-- again as you leave; the other areas keep the fixed afternoon look
	AREA_BLEND = 2,
	-- Studs a second past which the player jumped rather than walked (DayCycle.jumped: a teleport, a respawn); the
	-- area looks then snap instead of blending, so nobody arrives under the wrong sky
	AREA_SNAP_SPEED = 150,
	AREA_LOOKS = {
		[2] = { -- the Caves: darker and bluer (owner 2026-11-04: "darker"), so the glowing mushrooms stand out by day
			clockTime = 14.5,
			brightness = 1.0,
			exposure = -0.3,
			ambient = { 75, 88, 112 },
			outdoorAmbient = { 85, 98, 125 },
			atmosphere = { density = 0.6, offset = 0.05, haze = 2.4, glare = 0, color = { 120, 145, 180 }, decay = { 60, 72, 105 } }, -- round 2: fog hides where the area ends
			bloom = { intensity = 0.45, size = 28, threshold = 1.3 },
			saturation = 0.15,
			contrast = 0.1,
			tint = { 225, 235, 250 },
			sunRays = { intensity = 0, spread = 0 },
		},
		[3] = { -- Ember Ridge: a smoky orange sky (round 2, the owner's pick "burnt hills to the volcano"), from the Ember
			-- Colossus' arena look
			clockTime = 16.4,
			brightness = 2.2,
			exposure = 0.15,
			ambient = { 150, 105, 90 },
			outdoorAmbient = { 180, 125, 105 },
			atmosphere = { density = 0.42, offset = 0.1, haze = 2.3, glare = 0.6, color = { 255, 140, 90 }, decay = { 115, 72, 70 } },
			bloom = { intensity = 0.55, size = 30, threshold = 1.4 },
			saturation = 0.2,
			contrast = 0.12,
			tint = { 255, 215, 190 },
			sunRays = { intensity = 0.08, spread = 0.5 },
		},
	},
	-- The Frontier valley (spec 2026-11-10-frontier-valley-design: darker and more dangerous than the Wild): no day cycle.
	-- FIXED in the camp and on the passes; each area's look blends in while you're in it (AREA_BLEND, as the Wild's), each
	-- boss arena's while you're in one of its copies (Config/FrontierValley)
	FRONTIER = {
		FIXED = { -- a cold grey dusk
			clockTime = 17.2,
			brightness = 1.2,
			exposure = -0.2,
			ambient = { 95, 100, 115 },
			outdoorAmbient = { 105, 110, 128 },
			atmosphere = { density = 0.5, offset = 0.1, haze = 2.2, glare = 0.1, color = { 170, 178, 195 }, decay = { 95, 100, 120 } },
			bloom = { intensity = 0.35, size = 24, threshold = 1.6 },
			saturation = -0.05,
			contrast = 0.1,
			tint = { 225, 232, 245 },
			sunRays = { intensity = 0.05, spread = 0.4 },
		},
		AREA_LOOKS = {
			{ -- Frostwood: a grey snowy dusk, thick fog for the red eyes
				clockTime = 16.8,
				brightness = 1.1,
				exposure = -0.25,
				ambient = { 100, 108, 125 },
				outdoorAmbient = { 112, 120, 140 },
				atmosphere = { density = 0.62, offset = 0.15, haze = 2.6, glare = 0, color = { 185, 195, 212 }, decay = { 110, 118, 140 } },
				bloom = { intensity = 0.3, size = 24, threshold = 1.7 },
				saturation = -0.1,
				contrast = 0.08,
				tint = { 225, 235, 250 },
				sunRays = { intensity = 0, spread = 0 },
			},
			{ -- Stormpeak: under a thunderstorm, grey and cold (the lightning flashes it brighter; brightened 2026-11-10 in
				-- Studio: at dusk it was too dark to fight in)
				clockTime = 16,
				brightness = 1.5,
				exposure = 0,
				ambient = { 105, 110, 132 },
				outdoorAmbient = { 120, 126, 148 },
				atmosphere = { density = 0.5, offset = 0.05, haze = 2.3, glare = 0, color = { 120, 126, 148 }, decay = { 70, 74, 92 } },
				bloom = { intensity = 0.4, size = 26, threshold = 1.5 },
				saturation = -0.15,
				contrast = 0.15,
				tint = { 205, 215, 235 },
				sunRays = { intensity = 0, spread = 0 },
			},
			{ -- the Rift: violet and dim, its cracks and crystals glowing (brightened 2026-11-10 in Studio: too dark to see the
				-- ground)
				clockTime = 17.3,
				brightness = 1.4,
				exposure = 0.05,
				ambient = { 120, 90, 150 },
				outdoorAmbient = { 135, 100, 170 },
				atmosphere = { density = 0.42, offset = 0, haze = 2.1, glare = 0.2, color = { 130, 90, 175 }, decay = { 70, 45, 100 } },
				bloom = { intensity = 0.55, size = 30, threshold = 1.3 },
				saturation = 0.1,
				contrast = 0.15,
				tint = { 225, 205, 255 },
				sunRays = { intensity = 0, spread = 0 },
			},
		},
		ARENA_LOOKS = {
			{ -- the Frost Tyrant's frozen hall: cold blue light, snow in the air
				clockTime = 16.5,
				brightness = 1.3,
				exposure = -0.15,
				ambient = { 110, 125, 150 },
				outdoorAmbient = { 120, 135, 165 },
				atmosphere = { density = 0.55, offset = 0.1, haze = 2.4, glare = 0.1, color = { 190, 210, 235 }, decay = { 120, 140, 175 } },
				bloom = { intensity = 0.4, size = 26, threshold = 1.5 },
				saturation = -0.05,
				contrast = 0.1,
				tint = { 215, 232, 255 },
				sunRays = { intensity = 0.05, spread = 0.4 },
			},
			{ -- the Storm Sovereign's summit: under the storm's eye
				clockTime = 16.4,
				brightness = 1.4,
				exposure = -0.05,
				ambient = { 100, 106, 130 },
				outdoorAmbient = { 112, 120, 145 },
				atmosphere = { density = 0.5, offset = 0.05, haze = 2.3, glare = 0.2, color = { 100, 110, 140 }, decay = { 55, 60, 85 } },
				bloom = { intensity = 0.5, size = 28, threshold = 1.4 },
				saturation = -0.1,
				contrast = 0.18,
				tint = { 210, 220, 245 },
				sunRays = { intensity = 0, spread = 0 },
			},
			{ -- the Rift Devourer's island: the void all round
				clockTime = 17.6,
				brightness = 1.3,
				exposure = 0,
				ambient = { 115, 85, 150 },
				outdoorAmbient = { 128, 92, 165 },
				atmosphere = { density = 0.55, offset = 0, haze = 2.2, glare = 0.3, color = { 95, 55, 140 }, decay = { 40, 20, 65 } },
				bloom = { intensity = 0.6, size = 30, threshold = 1.2 },
				saturation = 0.15,
				contrast = 0.18,
				tint = { 225, 200, 255 },
				sunRays = { intensity = 0, spread = 0 },
			},
		},
	},
	-- The Wild bosses' arenas (by zone; spec 2026-11-01-wild-bosses-arenas-design), each its painting's look while you're
	-- in one of its copies (Util/WildValley.arenaZoneAt), never night; the haze hides what lies past its walls
	ARENA_LOOKS = {
		{ -- the Warden's grove: a sunny afternoon, warm light through the trees
			clockTime = 14.5,
			brightness = 1.8,
			exposure = -0.15,
			ambient = { 110, 108, 92 },
			outdoorAmbient = { 125, 122, 100 },
			atmosphere = { density = 0.38, offset = 0.15, haze = 1.6, glare = 0.4, color = { 215, 225, 195 }, decay = { 150, 175, 140 } },
			bloom = { intensity = 0.35, size = 26, threshold = 1.8 },
			saturation = 0.18,
			contrast = 0.03,
			tint = { 255, 250, 235 },
			sunRays = { intensity = 0.15, spread = 0.6 },
		},
		{ -- the Broodmother's hollow: dim and cold under its rock roof
			clockTime = 15.5,
			brightness = 0.6,
			exposure = -0.5,
			ambient = { 55, 50, 75 },
			outdoorAmbient = { 60, 55, 85 },
			atmosphere = { density = 0.5, offset = 0, haze = 2.2, glare = 0, color = { 70, 60, 100 }, decay = { 40, 35, 70 } },
			bloom = { intensity = 0.4, size = 28, threshold = 1.5 },
			saturation = 0.05,
			contrast = 0.1,
			tint = { 205, 200, 255 },
			sunRays = { intensity = 0, spread = 0 },
		},
		{ -- the Behemoth's lava field: a red-orange haze, ash in the air (brightened: the user found it too dark)
			clockTime = 16.4,
			brightness = 2.2,
			exposure = 0.15,
			ambient = { 150, 105, 90 },
			outdoorAmbient = { 180, 125, 105 },
			atmosphere = { density = 0.42, offset = 0.1, haze = 2.3, glare = 0.6, color = { 255, 140, 90 }, decay = { 115, 72, 70 } },
			bloom = { intensity = 0.55, size = 30, threshold = 1.4 },
			saturation = 0.2,
			contrast = 0.12,
			tint = { 255, 215, 190 },
			sunRays = { intensity = 0.08, spread = 0.5 },
		},
	},
}
