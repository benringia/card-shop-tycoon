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
}
