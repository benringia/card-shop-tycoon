--!strict
-- Party and summoning: 3 party cards, one summoned creature that walks with you and gives its element's perk.
-- See DESIGN.md 5.8 and the party & summoning spec. Plain data only so Lune tests can load this file.
return {
	PARTY_SIZE = 3,
	-- Perk per element: its kind and the value for a Common at 0 stars
	PERKS = {
		Ember = { kind = "Hype", base = 0.05, icon = "🔥" }, -- customers arrive more often
		Tide = { kind = "Calm", base = 0.10, icon = "💧" }, -- customers wait longer in the queue
		Bloom = { kind = "Express", base = 0.10, icon = "🌿" }, -- deliveries arrive faster
		Volt = { kind = "Hustle", base = 0.05, icon = "⚡" }, -- you walk faster
		Shade = { kind = "Haggle", base = 0.05, icon = "🌙" }, -- customers more willing to buy at your price
	},
	RARITY_MULTIPLIER = { Common = 1, Rare = 1.5, ["Very Rare"] = 2, Epic = 2.5, Legendary = 3 },
	STAR_BONUS = 0.10, -- each star adds this share of the perk

	-- Creature size, as a multiple of CREATURE_HEIGHT
	SIZE_BY_RARITY = { Common = 0.7, Rare = 0.85, ["Very Rare"] = 1, Epic = 1.2, Legendary = 1.4 },
	CREATURE_HEIGHT = 3, -- studs, for size 1
	FOLLOW_OFFSET = { side = 3, back = 3.5 }, -- studs from the owner, on the ground
	TELEPORT_DISTANCE = 40, -- further than this and the creature jumps next to its owner
	MARKER_RATE = 20, -- server marker updates per second
	MAX_MODEL_PARTS = 200, -- bigger models fall back to the placeholder

	-- Motion kit for static models (Util/CreatureMotion)
	MOTION = {
		BREATH_SECONDS = 3,
		BREATH_AMOUNT = 0.03, -- 3% squash-and-stretch when idle
		HOP_HEIGHT = 0.6,
		STEP_LENGTH = 2.5, -- studs per hop
		WADDLE_DEGREES = 8,
		LEAN_DEGREES = 10,
		LEAN_FULL_SPEED = 12, -- full lean at this speed (studs/s)
		LAND_SQUASH = 0.08,
		WALK_SPEED_MIN = 0.5, -- below this the creature counts as standing
		HOVER_HEIGHT = 2.5,
		HOVER_BOB = 0.4,
	},
	FLYING = { "Solarion", "Voidmaw", "Nightowl", "Emberwing", "Hushmoth", "Fizzlebug" },
	-- Bone animation for rigged pack models (Util/PetRig, Util/PetAnimator), drawn on each client. Angles in
	-- degrees unless named _RAD; seconds. Walks trot (diagonal legs together) or step (two legs); the spine
	-- breathes, tails wag in a wave, ears flop; standing, a random fidget plays every FIDGET_GAP seconds.
	PET_ANIM = {
		STRIDE = 1.6, -- studs per full leg cycle at size 1 (scaled with the creature)
		LEG_SWING = 28, -- upper leg, forward and back
		KNEE_LIFT = 32, -- lower leg bends as it swings forward
		BREATH = math.rad(2.5), -- spine pitch, radians
		BREATH_SECONDS = 2.6,
		WALK_BOB = 4, -- spine and head nod per step
		TAIL_WAG = 14, -- base of the tail, standing; each segment further adds TAIL_GROW
		TAIL_GROW = 0.45,
		TAIL_SECONDS = 1.1,
		TAIL_WALK = 0.8, -- wag speed while walking (slower: the tail sways behind)
		TAIL_WALK_AMOUNT = 0.55, -- and smaller
		TAIL_LAG = 0.7, -- radians of phase per segment (the wave)
		EAR_FLOP = 12,
		LOOK = 38, -- look around: head and neck turn
		TILT = 18, -- head tilt
		SNIFF = 24, -- head and neck down
		STRETCH = 26, -- front legs reach forward, spine dips
		HAPPY_WAG = 2.4, -- tail wag multiplier
		HIP_SWAY = 9, -- pets without tail bones (Kitsune): the hips sway so the tails swish, the spine turns back
		SIT = 22, -- sit: hips down, hind legs fold
		SCRATCH = 50, -- a hind leg up to scratch
		SHAKE = 16, -- shake like a wet dog: spine and head roll, fast
		YAWN = 26, -- head up
		HOP_HEIGHT = 0.9, -- whole-body hop (studs at size 1), twice
		BOUNCE = 0.35, -- creatures without bones: a few quick bounces
		SHAKE_BODY = 10, -- the whole body rolls during a shake
		-- Fidgets for rigged pets (bones), and for creatures without bones (whole-body only)
		FIDGETS = { "look", "tilt", "sniff", "stretch", "wag", "hop", "spin", "shake", "sit", "scratch", "yawn" },
		BODY_FIDGETS = { "hop", "spin", "shake", "look", "bounce" },
		FIDGET_GAP = { 2.5, 6 },
		FIDGET_SECONDS = {
			look = 2.4, tilt = 1.6, sniff = 1.8, stretch = 2, wag = 1.6,
			hop = 1.1, spin = 1.2, shake = 1.2, sit = 3, scratch = 1.8, yawn = 2, bounce = 1,
		},
		BLEND_SECONDS = 0.25, -- standing <-> walking
		DISTANCE = 70, -- only animated this close to the camera
		-- The rigged pack's whole-body motion is gentler: the legs do the walking
		HOP_SCALE = 0.35,
		WADDLE_SCALE = 0.4,
	},
	-- Bones whose names don't follow the pack's pattern, by model: { [boneName] = role name }
	PET_BONE_ALIASES = {
		Puppy = {
			bone_24 = "1_Right_Limb_0", bone_25 = "1_Right_Limb_1", bone_26 = "1_Right_Limb_2",
			["1_Right_Limb_0"] = "Stub", -- a stray bone at the hip
			Head_2 = "Ear_Left_0", Head_3 = "Ear_Left_1", Head_4 = "Ear_Left_2",
			bone_12 = "Ear_Right_0", bone_13 = "Ear_Right_1", bone_14 = "Ear_Right_2",
		},
	} :: { [string]: { [string]: string } },

	-- Each card's creature model: a model in a pack file (assets/creatures/<pack>.rbxm -> CreatureModels.<pack>),
	-- optionally in one of its colour variants (a SurfaceAppearance in the model's Variants folder). Cards not
	-- listed use a model named after the card, else the placeholder. Cute Pets: bought pack (BabBabyTV).
	CREATURE_MODELS = {
		Cindercub = { pack = "CutePets", model = "RedPanda" },
		Puffpuddle = { pack = "CutePets", model = "Axolotl" },
		Sprouthop = { pack = "CutePets", model = "Bunny" },
		Zappit = { pack = "CutePets", model = "Hamster" },
		Gloomlet = { pack = "CutePets", model = "Cat" },
		Ashbeak = { pack = "CutePets", model = "Chick" },
		Shellshy = { pack = "CutePets", model = "Penguin" },
		Mossmole = { pack = "CutePets", model = "Capybara" },
		Wispurr = { pack = "CutePets", model = "CrystalCat" },
		Coalbit = { pack = "CutePets", model = "Raccoon" },
		Petalpaw = { pack = "CutePets", model = "Fawn" },
		Hushmoth = { pack = "CutePets", model = "Owl", variant = "Shadow" },
		Sparkrat = { pack = "CutePets", model = "Hamster", variant = "Golden" },
		Driplet = { pack = "CutePets", model = "Penguin", variant = "Rainbow" },
		Blazehound = { pack = "CutePets", model = "Puppy" },
		Boltlynx = { pack = "CutePets", model = "Cat", variant = "Golden" },
		Nightowl = { pack = "CutePets", model = "Owl" },
		Vinewyrm = { pack = "CutePets", model = "BabyDragon" },
		Emberwing = { pack = "CutePets", model = "Phoenix" },
		Voltkit = { pack = "CutePets", model = "Fox", variant = "Golden" },
		Briarhorn = { pack = "CutePets", model = "Unicorn" },
		Duskstalker = { pack = "CutePets", model = "ShadowDragon" },
		["Eclipse Fox"] = { pack = "CutePets", model = "Kitsune" },
	} :: { [string]: { pack: string, model: string, variant: string? } },

	-- Glow by rarity: point light brightness and range, sparkles per second, outline, pulsing aura
	GLOW = {
		Common = { light = 0, lightRange = 0, sparkles = 0, outline = false, pulse = false },
		Rare = { light = 0.4, lightRange = 5, sparkles = 0, outline = false, pulse = false },
		["Very Rare"] = { light = 0.6, lightRange = 6, sparkles = 2, outline = false, pulse = false },
		Epic = { light = 0.8, lightRange = 7, sparkles = 3, outline = true, pulse = false },
		Legendary = { light = 1.2, lightRange = 9, sparkles = 5, outline = true, pulse = true },
	},
	SPARKLES_PER_STAR = 1,
	GRADE_S_SPARKLES = 2,
	MAX_OUTLINES = 31, -- Roblox draws at most 31 Highlights on a screen
	ACTION_COOLDOWN = 0.5,

	-- The quick party bar in the bottom-right corner (PartyBarController). Pixels; colours as { r, g, b }.
	BAR = {
		AVATAR = 54,
		SLOT = { 48, 66 }, -- a party card, width and height
		GAP = 8,
		RIM = 2.5,
		LIFT = 1.12, -- the summoned card grows this much
		TRAY = { 22, 26, 38 },
		TRAY_TRANSPARENCY = 0.1,
		EMPTY = { 36, 42, 58 },
		EMPTY_EDGE = { 70, 78, 100 },
	},
}
