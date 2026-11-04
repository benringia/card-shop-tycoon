--!strict
-- The Pet button moves' looks, sounds and motion by the creature's grade (spec 2026-11-05-pet-moves-design; the owner:
-- "the higher the creature grade the better the skill must look and feel"). Healing Rain (Tide), Vine Snare (Bloom),
-- Overcharge (Volt) and Curse (Shade); Fireball keeps its own look in Util/ElementFx. Drawn by Util/MoveFx from the
-- sim's events (Util/FightFx); the grade picked by Util/MoveFxRules. Sizes in studs, colours RGB. Plain data
-- (Lune-tested: every grade a step up from the one below).
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	-- How far the creature moves in its wind-up and cast pose (Util/PetRig amount), and the wind-up's glow and ring
	POSE_AMOUNT = { C = 1, B = 1.2, A = 1.45, S = 1.8 },
	WINDUP = {
		C = { glow = 1.5, ring = 0.8 },
		B = { glow = 1.7, ring = 0.95 },
		A = { glow = 2, ring = 1.1 },
		S = { glow = 2.4, ring = 1.35 },
	},
	-- The pose each move is cast with (Party.PET_ANIM poses every creature has)
	POSES = { Rain = "cast", Snare = "stomp", Overcharge = "zaphop", Curse = "cast" },
	-- With the low-graphics switch off a move plays no richer than this grade
	LOW_GRAPHICS_GRADE = "B",
	-- Seconds before orbs nobody spent fade on their own (the sim normally says)
	ORB_TIMEOUT = 8,

	-- Healing Rain: a cloud over each creature it heals, rain on it, a glow, a rising "+N" each tick
	RAIN = {
		C = { cloud = 4, drops = 20, drop = 0.12, glow = 0.6, tick = 1, ripple = false, motes = false, rings = false, rainbow = false,
			cloudColor = rgb(125, 138, 156), tickColor = rgb(134, 239, 172) },
		B = { cloud = 5, drops = 40, drop = 0.15, glow = 0.9, tick = 1.1, ripple = true, motes = false, rings = false, rainbow = false,
			cloudColor = rgb(165, 180, 200), tickColor = rgb(74, 222, 128) },
		A = { cloud = 6.5, drops = 70, drop = 0.18, glow = 1.3, tick = 1.25, ripple = true, motes = true, rings = false, rainbow = false,
			cloudColor = rgb(219, 231, 245), tickColor = rgb(74, 222, 128) },
		S = { cloud = 8, drops = 110, drop = 0.22, glow = 1.8, tick = 1.45, ripple = true, motes = true, rings = true, rainbow = true,
			cloudColor = rgb(240, 249, 255), tickColor = rgb(253, 224, 71) },
	},

	-- Vine Snare: vines or roots burst up round the target, wrap it, hold, wither. `reach`: share of its height they climb
	VINES = {
		C = { count = 2, thickness = 0.3, reach = 0.45, turns = 1, leaves = 0, thorns = 0, blossoms = 0, dirt = false, crack = false,
			pollen = false, color = rgb(74, 222, 128) },
		B = { count = 3, thickness = 0.45, reach = 0.7, turns = 1.4, leaves = 4, thorns = 0, blossoms = 0, dirt = false, crack = false,
			pollen = false, color = rgb(34, 197, 94) },
		A = { count = 4, thickness = 0.65, reach = 0.9, turns = 1.8, leaves = 5, thorns = 8, blossoms = 0, dirt = true, crack = false,
			pollen = false, color = rgb(77, 124, 47) },
		S = { count = 5, thickness = 0.9, reach = 1, turns = 2.2, leaves = 6, thorns = 10, blossoms = 5, dirt = true, crack = true,
			pollen = true, color = rgb(91, 140, 53) },
	},

	-- Overcharge: three orbs circling the creature (one per fast attack, Combat ABILITIES Volt), each spent with a hit.
	-- `radius` times the creature's height; `spin` turns a second
	ORBS = {
		C = { size = 0.5, spin = 0.5, radius = 0.55, glow = 0.3, light = 0.6, arcs = false, bolt = false, flash = false, ring = false,
			color = rgb(254, 240, 138), core = rgb(255, 255, 230) },
		B = { size = 0.7, spin = 0.7, radius = 0.6, glow = 0.5, light = 1, arcs = false, bolt = false, flash = false, ring = false,
			color = rgb(250, 204, 21), core = rgb(255, 250, 210) },
		A = { size = 0.9, spin = 0.95, radius = 0.65, glow = 0.8, light = 1.5, arcs = true, bolt = true, flash = false, ring = false,
			color = rgb(245, 158, 11), core = rgb(255, 247, 200) },
		S = { size = 1.2, spin = 1.25, radius = 0.72, glow = 1.2, light = 2.2, arcs = true, bolt = true, flash = true, ring = true,
			color = rgb(59, 130, 246), core = rgb(224, 242, 254) },
	},

	-- Curse: a rune circle under the caster, then a sigil, aura and smoke on the target. `circle` and `sigil` in studs,
	-- `darken` how far the target is darkened, `smoke` puffs a second
	CURSE = {
		C = { circle = 4, rings = 1, spin = 0.15, sigil = 2.2, aura = 0.35, smoke = 0, darken = 0.15, hex = false, chains = false,
			flames = false, color = rgb(124, 92, 214) },
		B = { circle = 5, rings = 1, spin = 0.2, sigil = 2.8, aura = 0.5, smoke = 0, darken = 0.25, hex = true, chains = false,
			flames = false, color = rgb(167, 139, 250) },
		A = { circle = 6.5, rings = 2, spin = 0.25, sigil = 3.6, aura = 0.7, smoke = 10, darken = 0.4, hex = true, chains = true,
			flames = false, color = rgb(196, 181, 253) },
		S = { circle = 8.5, rings = 3, spin = 0.3, sigil = 4.6, aura = 0.9, smoke = 20, darken = 0.55, hex = true, chains = true,
			flames = true, color = rgb(233, 213, 255) },
	},

	-- Textures (tools/textures/make_move_fx.py, uploaded; white with alpha, tinted in game) and Roblox-licensed sounds
	-- (Pro Sound Effects / APM), filled move by move
	TEXTURES = {
		raindrop = "rbxassetid://83707706646646", -- Healing Rain's drops
		vine = "rbxassetid://108129567302096", -- Vine Snare's leafy vines (C, B)
		bark = "rbxassetid://111998421915115", -- its thorny roots (A, S)
		rune = "rbxassetid://119290018382435", -- Curse's rune circle (a seven-point star in rings)
		sigil = "rbxassetid://104673189717381", -- Curse's mark over the foe (an eye in a broken ring, dripping)
	},
	SOUNDS = {
		Rain = {
			cast = "rbxassetid://9114369623", -- Fairy Dust 1
			loop = "rbxassetid://9112852465", -- Rain Continuous Drizzle 1
			layer = "rbxassetid://9112793880", -- Heavy Rain 1 (A and S)
			tick = "rbxassetid://9125644310", -- Magic Twirling Small High Pitch Spinning Chime
		},
		Snare = {
			burst = "rbxassetid://9118675035", -- Rocks Dirt Debris Pouring Bursts 1
			wrap = "rbxassetid://9114519078", -- Foliage Rustle 1
			creak = "rbxassetid://9125405388", -- Bow Stretches Wood Creaking Ripping Tearing
			layer = "rbxassetid://9126239755", -- Wood Crack Thick Splintering Bursts Creaking (A and S)
		},
		Overcharge = {
			cast = "rbxassetid://9116272073", -- Lightning Flashes Quick Electrical Bursts 1
			hum = "rbxassetid://9114245570", -- Electric Hum 7 (while orbs remain)
			zap = "rbxassetid://9116276946", -- Lightning Flashes Quick Electrical Bursts 21 (an orb spent)
			thunder = "rbxassetid://9126082854", -- Synth Thunder Cracks Individual Explosion (S)
		},
		Curse = {
			swell = "rbxassetid://9125637449", -- Magic Growl Eerie Tonal Swells (the circle opens)
			hex = "rbxassetid://9120113588", -- Tonal Impact 2 (the curse lands)
			drone = "rbxassetid://9114353377", -- Evil Drone Deep Unsetting Rumbly Keening 1 (while cursed)
			layer = "rbxassetid://9113802079", -- Choral Drone Short Eerie Tones Hollow 1 (A and S)
		},
	},
}
