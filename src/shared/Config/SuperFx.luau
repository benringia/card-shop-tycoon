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

-- pose: the creature's own signature pose it strikes as the move lands (Util/PetRig, Party.SIGNATURE), else "cast";
-- dash: it charges through its target and back as it lands
local function look(tier: string, card: string, element: string, color: { number }, own: { [string]: { any } }, pose: string?, dash: boolean?): any
	local fields: { [string]: { any } } = { scale = SCALE, particles = PARTICLES, shake = SHAKE, extra = EXTRA }
	for field, values in own do
		fields[field] = values
	end
	return { tier = tier, card = card, element = element, color = color, grades = grades(fields), pose = pose, dash = dash }
end

-- A look's wind-up pose instead of the plain charge crouch (owner 2026-11-05: Inferno and Magma Slam "jump high up")
local function withWindup(made: any, pose: string): any
	made.windupPose = pose
	return made
end

-- A look that winds up longer than its tier (owner 2026-11-05: Supernova "really quick ... dont rush the animations"):
-- `seconds` (Config/Combat SIGNATURES windup matches) and the share of them each part of its charge takes
local function withTiming(made: any, seconds: number, timing: { [string]: number }): any
	made.windup = seconds
	made.timing = timing
	return made
end

-- A Legendary look's sky on the caster's screen during its cinematic (Util/SuperCinematic): a colour grade over the
-- world (tint, brightness, saturation, contrast), eased in with the call and back with the camera
local function withSky(made: any, tint: { number }, brightness: number, saturation: number, contrast: number): any
	made.sky = { tint = tint, brightness = brightness, saturation = saturation, contrast = contrast }
	return made
end

return {
	-- The cinematic by rarity: wind-up seconds (the sim's, Config/Combat SIGNATURES), the call beat's seconds, and what
	-- only Legendary gets; swoop: studs the camera travels in its swoop to the creature
	TIERS = {
		Epic = { windup = 1.5, call = 0.3, bars = false, impactFrame = false, sky = false, swoop = 10 },
		Legendary = { windup = 2, call = 0.3, bars = true, impactFrame = true, sky = true, swoop = 14 },
	},
	LOW_GRAPHICS_GRADE = "B", -- extras off: a look plays no richer than its B grade (and no black-and-white frame)
	-- Another player's super plays no richer than this (owner 2026-11-13, "Light touch" for others' effects in boss
	-- fights: B is about half an S look's particles); the caster's own screen keeps its grade
	OTHERS_GRADE = "B",
	-- The caster's camera, in multiples of the creature's height: the call's low close shot in front of it and to one
	-- side (the charge drifts closer), then the impact's wide shot from behind it framing it and its target; fov in degrees, ease in
	-- seconds (the swoop in and the ease back)
	-- Distances and heights in the creature's heights; minReach / minHeight: studs the close shots never come nearer
	-- than or sink below (owner 2026-11-06: "sometimes camera is too low or too close that animations are hard to
	-- see": the charge backs off from the call so a wind-up or leap fits, small creatures get the floors)
	CAMERA = {
		callDistance = 2.2,
		callHeight = 0.6,
		callAngle = 40, -- degrees round from straight in front, so its target never stands in the shot
		chargeDistance = 2.7,
		chargeHeight = 0.8,
		minReach = 10,
		minHeight = 4,
		focusHeight = 0.45,
		impactDistance = 3.4,
		impactHeight = 1.3,
		impactSide = 0.8,
		impactReach = 0.55, -- the impact shot backs off at least this share of the creature-target distance
		fov = 62,
		ease = 0.35,
		-- A player, creature or boss between the camera and the caster fades this much, on the caster's screen only
		-- (owner 2026-11-05: the creature was sometimes covered); the shots also stand off to the side with fewer
		fade = 0.8,
	},
	LOOKS = {
		-- A fire tornado leaps onto the boss and leaves a ring of fire (S: the ground cracks into lava)
		Inferno = withWindup(look("Epic", "Infernox", "Ember", rgb(255, 106, 26), {
			tornadoHeight = { 14, 18, 23, 30 },
			-- owner 2026-11-06 "make it more visible": its flame beams' width (studs) and how long it stands
			tornadoWidth = { 3.2, 3.8, 4.5, 5.4 },
			tornadoSeconds = { 2.8, 3, 3.3, 3.8 },
			embers = { 20, 30, 44, 64 },
			fireRing = { 1.5, 1.7, 1.95, 2.3 }, -- the ring of fire's radius, in the target's size (its width, 3-12 studs)
		}, "firebreath"), "leap"),
		-- A wave crashes over your side and sets into a water dome with spirit koi (S: a rainbow sheen, a second ring)
		TidalShield = look("Epic", "Abyssal Koi", "Tide", rgb(79, 183, 255), {
			koi = { 2, 3, 4, 6 },
			dome = { 12, 13, 14.5, 16 },
			waveHeight = { 10, 12, 15, 19 },
		}, "abysschomp"),
		-- Clouds part, a giant water lotus closes into a dome of light (S: a halo over the Kirin, golden rain)
		TidalBlessing = withSky(look("Legendary", "Tideborne Kirin", "Tide", rgb(191, 230, 255), {
			petals = { 8, 10, 12, 16 },
			lotus = { 10, 12, 15, 19 },
			rays = { 3, 4, 6, 8 },
		}, "blessing"), rgb(255, 246, 222), 0.06, 0.05, 0.08), -- the clouds part: warm, bright
		-- A lightning dash through the boss with afterimages, electric rings for the stun (S: a bolt from the sky)
		Stampede = look("Epic", "Thunderhorn", "Volt", rgb(255, 216, 74), {
			afterimages = { 2, 3, 4, 6 },
			trailWidth = { 2, 2.5, 3.2, 4 },
		}, "thundercall", true),
		-- The titan leaps and crashes down, lava cracks race to the boss, geysers (S: a ring of lava round the landing)
		MagmaSlam = withWindup(look("Epic", "Cinder Titan", "Ember", rgb(255, 122, 42), {
			cracks = { 4, 5, 7, 9 },
			crackLength = { 14, 18, 23, 30 },
			geysers = { 2, 3, 4, 6 },
			rocks = { 6, 9, 13, 18 },
		}, "lavaslam"), "leap"),
		-- It holds still as a star sigil draws itself under it and a black moon covers the sun, then it glows dark purple
		-- and a mirror image copies its every move while it evades everything (owner 2026-11-05; S: two mirror images)
		Eclipse = withWindup(look("Epic", "Eclipse Fox", "Shade", rgb(167, 139, 250), {
			corona = { 10, 12, 15, 19 },
			afterimages = { 2, 3, 4, 6 },
			sigil = { 1.1, 1.25, 1.4, 1.6 }, -- the star sigil's radius, in the creature's height
			mirrors = { 1, 1, 1, 2 },
		}, "eclipse"), "still"),
		-- Space cracks like glass and it blinks between rifts (S: the arena's edge cracks for a moment)
		RiftStep = look("Epic", "Riftwalker", "Shade", rgb(192, 107, 255), {
			rifts = { 3, 4, 5, 7 },
			shards = { 8, 12, 16, 24 },
		}, "riftroar"),
		-- The sky turns to space; Solarion's sun grows over its hands, rises slowly over the boss, swells and bursts (S:
		-- two impact frames, pillars of light). Its own pace: grow, rise, then what's left hangs and swells.
		Supernova = withTiming(withSky(look("Legendary", "Solarion", "Ember", rgb(255, 209, 102), {
			sun = { 4, 5, 6.5, 8.5 },
			burst = { 17, 18, 20, 22 }, -- studs over the target the risen sun bursts (the cinematic frames it too)
			rings = { 2, 2, 3, 4 },
			rays = { 4, 6, 8, 12 },
			impactFrames = { 1, 1, 1, 2 },
		}, "sunburst"), rgb(96, 80, 170), -0.38, -0.25, 0.2), 3.5, { grow = 0.4, rise = 0.45 }), -- deep space
		-- Storm clouds gather and a colossal bolt strikes (S: three bolts and a chain of lightning round the arena)
		Thunderstorm = withSky(look("Legendary", "Stormking", "Volt", rgb(159, 214, 255), {
			forks = { 3, 4, 6, 8 },
			storm = { 24, 30, 38, 48 },
			bolts = { 1, 1, 1, 3 },
		}, "hornstorm"), rgb(140, 160, 200), -0.28, -0.35, 0.18), -- a storm sky
		-- A black hole opens and spectral jaws clamp the boss, life flows back (S: the jaws bite twice)
		Devour = withSky(look("Legendary", "Voidmaw", "Shade", rgb(139, 92, 246), {
			hole = { 8, 10, 13, 17 },
			streams = { 4, 6, 8, 12 },
			bites = { 1, 1, 1, 2 },
		}, "voidroar"), rgb(150, 110, 210), -0.32, -0.45, 0.22), -- the world dims
	},
	-- White textures with the shape in the alpha (tools/textures/make_super_fx.py, uploaded), filled look by look
	TEXTURES = {
		firestrip = "rbxassetid://98322968420111", -- flame tongues for beams (the tornadoes, the torrent)
		crack = "rbxassetid://118892821263938", -- glowing cracks spreading out (Inferno's S lava)
		waterstrip = "rbxassetid://135040662984540", -- rippling water bands for beams (Tidal Shield's swirl)
		swirl = "rbxassetid://82162011115712", -- five spiral arms (Config/WildLoading's): Devour's black hole
	},
	-- Licensed sounds per look (Pro Sound Effects / APM): call, charge, impact, layer, linger; filled look by look
	SOUNDS = {
		Inferno = {
			call = "rbxassetid://9113985717", -- Creature Roar Mix Of Animals Gate Creaks 1
			charge = "rbxassetid://9114446277", -- Fire Whoosh 6
			impact = "rbxassetid://9114554567", -- Gas Fire Explosion 3
			layer = "rbxassetid://9114446802", -- Fire Whoosh 13 (A and S)
			linger = "rbxassetid://9112780193", -- Fireplace Constant Burning Flame 1 (the 6 s burn)
			tornado = "rbxassetid://9114438917", -- Fire Sheet 3 (the tornado roars up)
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
			linger = "rbxassetid://9114791989", -- Heavenly Presence Thick Melodic Choir Pad 1 (the light rain)
			revive = "rbxassetid://9125602386", -- Heavenly Harmonic Presence Glowing Crystal (a pillar stands one up)
			heal = "rbxassetid://9114369623", -- Fairy Dust 1 (the others' sparkle)
		},
		Stampede = {
			call = "rbxassetid://9126100408", -- Thunder With Lion Roar Growl Low Rumble Roar (its bellow)
			charge = "rbxassetid://9125980435", -- Spaceship Pre Blast Electric Charge Up Buzzy
			impact = "rbxassetid://9126082854", -- Synth Thunder Cracks Individual Explosion (owner: "thunder on impact")
			thunder = "rbxassetid://9120016256", -- Thunder Cracks Big Rumbling Blasts Booming 3 (the roll under it, every grade)
			layer = "rbxassetid://9116276946", -- Lightning Flashes Quick Electrical Bursts 21 (A and S)
			linger = "rbxassetid://9114245570", -- Electric Hum 7 (the stun)
		},
		MagmaSlam = {
			call = "rbxassetid://9125484367", -- Deep Hits Big Reverberant Booms Rumbling Tail 2
			charge = "rbxassetid://9118617342", -- Rock Impact Large Hit Scrape 1
			impact = "rbxassetid://9114554531", -- Gas Fire Explosion 1
			layer = "rbxassetid://9118587494", -- Rock Drop On Concrete Drops Breaks 2 (A and S)
			linger = "rbxassetid://9125883906", -- Rocks Tumble Falling Down Cliff Grit Scatter
		},
		Eclipse = {
			call = "rbxassetid://9120790529", -- Wolf Howl Two Versions 1
			charge = "rbxassetid://9120697982", -- Whoosh By Howling Wind Light Rumbling 5
			impact = "rbxassetid://9113551598", -- Boom Pass By Low End Multiple Variations 2
			layer = "rbxassetid://9125637449", -- Magic Growl Eerie Tonal Swells (A and S)
			linger = "rbxassetid://9114353377", -- Evil Drone Deep Unsettling Rumbly Keening 1 (the 5 s)
		},
		RiftStep = {
			call = "rbxassetid://9114590297", -- Glass Break 1 (space cracks)
			charge = "rbxassetid://9125981170", -- Spaceship Pre Blast Electric Charge Up Glass
			impact = "rbxassetid://9116422213", -- Magic Transformation 17 (it blinks out)
			layer = "rbxassetid://9114591515", -- Glass Breaks 2 (A and S)
			blink = "rbxassetid://9120749129", -- Wind Burst Alien Vortex Blasts 1 (it bursts out of a rift)
			slash = "rbxassetid://9120717850", -- Whoosh Fast Swish By 4 (each strike)
		},
		Supernova = {
			call = "rbxassetid://9114055189", -- Descending Synth Burst Tonal Light Phasing 2 (it rises)
			charge = "rbxassetid://9116420139", -- Magic Tones Harmonic Tonal Swells Atonal 2 (the sun grows)
			impact = "rbxassetid://9113216700", -- Avalanche Crashing 3
			layer = "rbxassetid://9114554531", -- Gas Fire Explosion 1 (A and S)
			linger = "rbxassetid://9113224030", -- Avalanche Rumbling 2 (the crater)
		},
		Thunderstorm = {
			call = "rbxassetid://9120742493", -- Whoosh Sweeteners Tearing Atmosphere 1 (the clouds swirl in)
			charge = "rbxassetid://9126069838", -- Synth Lightning Crack Sharp Some Rolling Tail
			impact = "rbxassetid://9120016037", -- Thunder Cracks Big Rumbling Blasts Booming 1
			layer = "rbxassetid://9126082854", -- Synth Thunder Cracks Individual Explosion (A and S)
			linger = "rbxassetid://9112852465", -- Rain Continuous Drizzle 1
		},
		Devour = {
			call = "rbxassetid://9125603019", -- Heavenly Presence Eerie Choral Tones Dark (the world dims)
			charge = "rbxassetid://9120749463", -- Wind Burst Alien Vortex Blasts 11 (the black hole pulls)
			impact = "rbxassetid://9118617328", -- Rock Impact Large Hit Scrape 3 (the jaws clamp)
			layer = "rbxassetid://9126100173", -- Thunder With Lion Roar Growl Low Rumble Roar (A and S)
			linger = "rbxassetid://9114353377", -- Evil Drone Deep Unsettling Rumbly Keening 1 (life flowing back)
		},
	},
} :: any
