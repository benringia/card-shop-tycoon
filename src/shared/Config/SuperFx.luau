--!strict
-- The super moves' looks (spec 2026-11-05-super-moves-design; the owner: "since this is epic and legendary skills I
-- want them to be way epic/cooler looking than the ones we already did"). Ten looks (Config/Combat SIGNATURES `look`),
-- each a step up from grade C to S ("the higher the creature grade the better the skill must look and feel"), S with
-- an extra the others don't have. Rarity sets the cinematic's size (TIERS): Epic a quick swoop, Legendary the full
-- show (bars, a sky change, a black-and-white impact frame). Drawn by Util/SuperFx (everyone) and Util/SuperCinematic
-- (the caster's screen); the pure choices in Util/SuperFxRules. Plain data (Lune-tested).
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

-- A grade table from four values per field: { field = { C, B, A, S } } -> { C = {...}, B = {...}, ... }
local function grades(fields: { [string]: { any } }): { [string]: { [string]: any } }
	local out: { [string]: { [string]: any } } = {}
	for index, grade in { "C", "B", "A", "S" } do
		local look: { [string]: any } = {}
		for field, values in fields do
			look[field] = values[index]
		end
		out[grade] = look
	end
	return out
end

-- Every look's shared fields: how big it is, how many particles, how hard the impact shakes, the S extra
local SCALE = { 1, 1.2, 1.45, 1.8 }
local PARTICLES = { 24, 36, 52, 72 }
local SHAKE = { 0.6, 0.8, 1.05, 1.4 }
local EXTRA = { false, false, false, true }

-- pose: the creature's own signature pose it strikes as the move lands (Util/PetRig, Party.SIGNATURE), else "cast"
local function look(tier: string, card: string, element: string, color: { number }, own: { [string]: { any } }, pose: string?): any
	local fields: { [string]: { any } } = { scale = SCALE, particles = PARTICLES, shake = SHAKE, extra = EXTRA }
	for field, values in own do
		fields[field] = values
	end
	return { tier = tier, card = card, element = element, color = color, grades = grades(fields), pose = pose }
end

return {
	-- The cinematic by rarity: wind-up seconds (the sim's, Config/Combat SIGNATURES), the call beat's seconds, and what
	-- only Legendary gets; swoop: studs the camera travels in its swoop to the creature
	TIERS = {
		Epic = { windup = 1.5, call = 0.3, bars = false, impactFrame = false, sky = false, swoop = 10 },
		Legendary = { windup = 2, call = 0.3, bars = true, impactFrame = true, sky = true, swoop = 14 },
	},
	LOW_GRAPHICS_GRADE = "B", -- extras off: a look plays no richer than its B grade (and no black-and-white frame)
	-- The caster's camera, in multiples of the creature's height: the call's low close shot in front of it and to one
	-- side (the charge drifts closer), then the impact's wide shot from behind it framing it and its target; fov in degrees, ease in
	-- seconds (the swoop in and the ease back)
	CAMERA = {
		callDistance = 1.6,
		callHeight = 0.35,
		callAngle = 40, -- degrees round from straight in front, so its target never stands in the shot
		chargeDistance = 1.3,
		focusHeight = 0.3,
		impactDistance = 3.2,
		impactHeight = 1.1,
		impactSide = 0.8,
		impactReach = 0.55, -- the impact shot backs off at least this share of the creature-target distance
		fov = 62,
		ease = 0.35,
	},
	LOOKS = {
		-- A fire tornado leaps onto the boss and leaves a ring of fire (S: the ground cracks into lava)
		Inferno = look("Epic", "Infernox", "Ember", rgb(255, 106, 26), {
			tornadoHeight = { 14, 18, 23, 30 },
			embers = { 20, 30, 44, 64 },
			fireRing = { 1.5, 1.7, 1.95, 2.3 }, -- the ring of fire's radius, in the target's size (its width, 3-12 studs)
		}, "firebreath"),
		-- A wave crashes over your side and sets into a water dome with spirit koi (S: a rainbow sheen, a second ring)
		TidalShield = look("Epic", "Abyssal Koi", "Tide", rgb(79, 183, 255), {
			koi = { 2, 3, 4, 6 },
			dome = { 12, 13, 14.5, 16 },
			waveHeight = { 10, 12, 15, 19 },
		}, "abysschomp"),
		-- Clouds part, a giant water lotus closes into a dome of light (S: a halo over the Kirin, golden rain)
		TidalBlessing = look("Legendary", "Tideborne Kirin", "Tide", rgb(191, 230, 255), {
			petals = { 8, 10, 12, 16 },
			lotus = { 10, 12, 15, 19 },
			rays = { 3, 4, 6, 8 },
		}, "blessing"),
		-- A lightning dash through the boss with afterimages, electric rings for the stun (S: a bolt from the sky)
		Stampede = look("Epic", "Thunderhorn", "Volt", rgb(255, 216, 74), {
			afterimages = { 2, 3, 4, 6 },
			trailWidth = { 2, 2.5, 3.2, 4 },
		}),
		-- The titan leaps and crashes down, lava cracks race to the boss, geysers (S: a ring of lava round the landing)
		MagmaSlam = look("Epic", "Cinder Titan", "Ember", rgb(255, 122, 42), {
			cracks = { 4, 5, 7, 9 },
			crackLength = { 14, 18, 23, 30 },
			geysers = { 2, 3, 4, 6 },
			rocks = { 6, 9, 13, 18 },
		}, "lavaslam"),
		-- A black moon covers the sun and the fox turns to shadow (S: two shadow clones)
		Eclipse = look("Epic", "Eclipse Fox", "Shade", rgb(167, 139, 250), {
			corona = { 10, 12, 15, 19 },
			afterimages = { 2, 3, 4, 6 },
		}),
		-- Space cracks like glass and it blinks between rifts (S: the arena's edge cracks for a moment)
		RiftStep = look("Epic", "Riftwalker", "Shade", rgb(192, 107, 255), {
			rifts = { 3, 4, 5, 7 },
			shards = { 8, 12, 16, 24 },
		}),
		-- The sky turns to space and Solarion hurls a small sun down (S: two impact frames, pillars of light)
		Supernova = look("Legendary", "Solarion", "Ember", rgb(255, 209, 102), {
			sun = { 4, 5, 6.5, 8.5 },
			rings = { 2, 2, 3, 4 },
			rays = { 4, 6, 8, 12 },
		}),
		-- Storm clouds gather and a colossal bolt strikes (S: three bolts and a chain of lightning round the arena)
		Thunderstorm = look("Legendary", "Stormking", "Volt", rgb(159, 214, 255), {
			forks = { 3, 4, 6, 8 },
			storm = { 24, 30, 38, 48 },
			bolts = { 1, 1, 1, 3 },
		}),
		-- A black hole opens and spectral jaws clamp the boss, life flows back (S: the jaws bite twice)
		Devour = look("Legendary", "Voidmaw", "Shade", rgb(139, 92, 246), {
			hole = { 8, 10, 13, 17 },
			streams = { 4, 6, 8, 12 },
			bites = { 1, 1, 1, 2 },
		}),
	},
	-- White textures with the shape in the alpha (tools/textures/make_super_fx.py, uploaded), filled look by look
	TEXTURES = {
		firestrip = "rbxassetid://98322968420111", -- flame tongues for beams (the tornadoes, the torrent)
		crack = "rbxassetid://118892821263938", -- glowing cracks spreading out (Inferno's S lava)
		waterstrip = "rbxassetid://135040662984540", -- rippling water bands for beams (Tidal Shield's swirl)
	},
	-- Licensed sounds per look (Pro Sound Effects / APM): call, charge, impact, layer, linger; filled look by look
	SOUNDS = {
		Inferno = {
			call = "rbxassetid://9113985717", -- Creature Roar Mix Of Animals Gate Creaks 1
			charge = "rbxassetid://9114446277", -- Fire Whoosh 6
			impact = "rbxassetid://9114554567", -- Gas Fire Explosion 3
			layer = "rbxassetid://9114446802", -- Fire Whoosh 13 (A and S)
			linger = "rbxassetid://9112780193", -- Fireplace Constant Burning Flame 1 (the 6 s burn)
		},
		TidalShield = {
			call = "rbxassetid://9120585252", -- Water Splash Big Water Splash Dive In 1 (the koi leaps)
			charge = "rbxassetid://9116317695", -- Liquid Shake 1 (the swirl, the wave rising)
			impact = "rbxassetid://9120611318", -- Wave Crashes Single Large Impacts 4
			layer = "rbxassetid://9125409816", -- Bubbles Small Underwater Above Water Quality (A and S)
			hit = "rbxassetid://9112872239", -- Small Bubbles Water Surface Float Up Pop 5 (a hit soaked)
			burst = "rbxassetid://9120585252", -- the splash as the dome bursts
		},
		TidalBlessing = {
			call = "rbxassetid://9125602386", -- Heavenly Harmonic Presence Glowing Crystal (the clouds part)
			charge = "rbxassetid://9125635430", -- Magical Exit Sparkling Pass Bys Clinking Chimes (the lotus opens)
			impact = "rbxassetid://9116394876", -- Magic Glows Soft Clusters Of Chiming Hits 2
			layer = "rbxassetid://9120611318", -- Wave Crashes Single Large Impacts 4 (A and S)
			linger = "rbxassetid://9114791989", -- Heavenly Presence Thick Melodic Choir Pad 1 (while the dome forms)
			hit = "rbxassetid://9112872239", -- Small Bubbles Water Surface Float Up Pop 5
			burst = "rbxassetid://9120585252", -- Water Splash Big Water Splash Dive In 1
		},
		Stampede = {},
		MagmaSlam = {
			call = "rbxassetid://9125484367", -- Deep Hits Big Reverberant Booms Rumbling Tail 2
			charge = "rbxassetid://9118617342", -- Rock Impact Large Hit Scrape 1
			impact = "rbxassetid://9114554531", -- Gas Fire Explosion 1
			layer = "rbxassetid://9118587494", -- Rock Drop On Concrete Drops Breaks 2 (A and S)
			linger = "rbxassetid://9125883906", -- Rocks Tumble Falling Down Cliff Grit Scatter
		},
		Eclipse = {},
		RiftStep = {},
		Supernova = {},
		Thunderstorm = {},
		Devour = {},
	},
} :: any
