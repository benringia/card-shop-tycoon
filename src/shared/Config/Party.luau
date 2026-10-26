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
	SIZE_BY_RARITY = { Common = 0.7, Rare = 0.85, ["Very Rare"] = 1, Epic = 1.5, Legendary = 1.4 },
	CREATURE_HEIGHT = 3, -- studs, for size 1
	FOLLOW_OFFSET = { side = 3, back = 3.5 }, -- studs from the owner, on the ground (times a model entry's size)
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
	-- Cards that fly when drawn with their own model or the placeholder
	FLYING = { "Solarion", "Voidmaw", "Nightowl", "Emberwing", "Hushmoth", "Fizzlebug" },
	-- Packs whose models fly (wings with bones of their own). Cute Pets walks: its wings can't flap.
	FLYING_PACKS = {} :: { string },
	-- Pack models that fly, by the first bone of each left wing (the right one is the same name with .R for .L;
	-- the bones after it on the same side flap too, trailing it). Found by hand: the Ultra pack names them
	-- Root.L.009 and the like.
	WINGS = {
		DarkBat = { "Root.L.009" },
		FairyMoth = { "Root.L.004", "Root.L.009" },
		Venowasp = { "Root.L.009" },
		NeonSwallow = { "Root.L.009" },
		StoneBird = { "Root.L.009" },
		HeronDemon = { "Root.L" },
	} :: { [string]: { string } },
	-- Arms held some other way than hanging at the sides (degrees): hang = off straight down, forward = reach
	-- forward from there, bend = elbows, swing = walking swing (else PET_ANIM.ARM_SWING). Flametor holds its short
	-- arms up in front like a T-rex, and so does Infernox; Sprouthop swings its arms wide.
	ARM_POSE = {
		Flametor = { hang = 50, forward = 55, bend = 60 },
		Infernox = { hang = 8, forward = 60, bend = 70, swing = 8 }, -- nearly straight down first, so the forward swing brings them in front
		Thornback = { hang = 8, forward = 65, bend = 90, swing = 6 }, -- scythes folded up in front, praying
		Duskstalker = { hang = 14, forward = 10, bend = 30, swing = 38 }, -- fists ready, a fighter's swagger
		Voltkit = { hang = 12, forward = 5, bend = 20, swing = 34 }, -- a hero's stride
		Sprouthop = { hang = 12, forward = 0, bend = 14, swing = 32 },
		Cindercub = { hang = 0, forward = 0, bend = 0, swing = 14 }, -- paws rest on its tummy, so only a little swing
		Zappit = { hang = 0, forward = 0, bend = 10, swing = 18 }, -- arms hang at its sides
		Mossmole = { hang = 0, forward = 0, bend = 0, swing = 4 }, -- hugging its moss garden
		Petalpaw = { hang = 0, forward = 0, bend = 15, swing = 24 },
		Ashbeak = { hang = 0, forward = 0, bend = 0, swing = 10 }, -- folded wings, fluttering a little
		Fizzlebug = { hang = 0, forward = 0, bend = 15, swing = 12 },
		Wispurr = { hang = 0, forward = 0, bend = 0, swing = 12 }, -- paws held up in front
	} :: { [string]: { hang: number, forward: number, bend: number, swing: number? } },
	-- Signature idles: a model's own fidget, played instead of an ordinary one this often (Util/PetRig poses it,
	-- Util/SignatureFx draws its effect): Sprouthop holds up a hand for a butterfly, Voidmaw's heads roar one after
	-- another, Boltlynx roars with lightning crackling off its ear and tail bolts, Stormjack's heads roar with lightning leaping
	-- between their mouths, Infernox breathes fire, Puffpuddle cracks a shell on its chest, Cindercub hiccups little puffs of fire, Zappit zap-hops with lightning off its bolts, Mossmole puffs glowing spores from its mushroom garden, Petalpaw twirls in a swirl of petals, Gloomlet loops the loop in shadow smoke, Ashbeak flaps up a puff of embers, Shellshy peeks out of its shell in a stream of bubbles, Fizzlebug buzzes up and zaps the ground, Wispurr floats up and fades like a ghost, Emberwing swoops trailing fire, Tidecaller rears up and splashes a ring of water, Briarhorn charges in a burst of thorns, Abyssal Koi lunges and snaps its fangs in a dark surge, Blazehound sneezes a puff of fire,
	-- Thornback does kung fu, Eclipse Fox summons an eclipse, Duskstalker backflips, Solarion's heads roar fire,
	-- Voltkit charges lightning between its fists
	SIGNATURE = {
		Sprouthop = { fidget = "butterfly", chance = 0.35 },
		Cindercub = { fidget = "hiccup", chance = 0.35 },
		Zappit = { fidget = "zaphop", chance = 0.35 },
		Mossmole = { fidget = "sporepuff", chance = 0.35 },
		Petalpaw = { fidget = "petaltwirl", chance = 0.35 },
		Gloomlet = { fidget = "shadowloop", chance = 0.35 },
		Ashbeak = { fidget = "emberflap", chance = 0.35 },
		Shellshy = { fidget = "shypeek", chance = 0.35 },
		Fizzlebug = { fidget = "buzzzap", chance = 0.35 },
		Wispurr = { fidget = "ghostfloat", chance = 0.35 },
		Emberwing = { fidget = "flameswoop", chance = 0.35 },
		Tidecaller = { fidget = "tidecall", chance = 0.35 },
		Briarhorn = { fidget = "thorncharge", chance = 0.35 },
		AbyssalKoi = { fidget = "abysschomp", chance = 0.35 },
		Voidmaw = { fidget = "voidroar", chance = 0.35 },
		Boltlynx = { fidget = "thunderroar", chance = 0.35 },
		Stormjack = { fidget = "stormroar", chance = 0.35 },
		Infernox = { fidget = "firebreath", chance = 0.35 },
		Puffpuddle = { fidget = "shellcrack", chance = 0.35 },
		Blazehound = { fidget = "sneeze", chance = 0.35 },
		Thornback = { fidget = "kungfu", chance = 0.35 },
		EclipseFox = { fidget = "eclipse", chance = 0.35 },
		Duskstalker = { fidget = "backflip", chance = 0.35 },
		Solarion = { fidget = "solarroar", chance = 0.35 },
		Voltkit = { fidget = "voltcharge", chance = 0.35 },
	} :: { [string]: { fidget: string, chance: number } },
	-- How a model carries itself, so each moves like the creature it is (else the defaults): its own idle fidgets
	-- (else PET_ANIM.FIDGETS), its tail's swish speed and size (times PET_ANIM's), and how much it bounces walking
	-- (times PET_ANIM.HOP_SCALE). Big beasts swish slowly, don't hop or spin, and walk heavily; Infernox stomps.
	CREATURE_STYLE = {
		Boltlynx = { fidgets = { "look", "tilt", "sniff", "stretch", "sit", "scratch", "yawn", "shake", "wag" }, tailSpeed = 0.45, tailAmount = 0.9, bounce = 0.5 },
		Voidmaw = { fidgets = { "look", "sniff", "yawn", "shake", "tilt", "stretch" }, tailSpeed = 0.35, tailAmount = 0.7, bounce = 0.25 },
		Stormjack = { fidgets = { "look", "tilt", "sniff", "yawn", "shake", "hop", "wag", "sit", "stretch" }, tailSpeed = 0.8 },
		Infernox = { fidgets = { "look", "tilt", "sniff", "yawn", "shake", "stomp", "stretch" }, tailSpeed = 0.35, tailAmount = 1, bounce = 0.6 },
		Sprouthop = { fidgets = { "look", "tilt", "sniff", "stretch", "hop", "spin", "shake", "yawn" } },
		Cindercub = { fidgets = { "look", "tilt", "sniff", "stretch", "hop", "spin", "shake", "yawn", "wag" }, tailSpeed = 1.2, bounce = 1.2 },
		Zappit = { fidgets = { "look", "tilt", "sniff", "hop", "hop", "spin", "shake", "wag" }, tailSpeed = 1.4, bounce = 1.8 }, -- a bunny: hops about
		Mossmole = { fidgets = { "look", "tilt", "sniff", "yawn", "shake", "hop" }, bounce = 0.8 }, -- a gentle waddler
		Petalpaw = { fidgets = { "look", "tilt", "sniff", "hop", "shake", "wag", "stretch" }, tailSpeed = 0.7, tailAmount = 1.2, bounce = 1.2 }, -- a big slow tail sway
		Gloomlet = { fidgets = { "look", "tilt", "spin", "shake" } }, -- a flyer
		Ashbeak = { fidgets = { "look", "tilt", "sniff", "hop", "shake", "wag" }, tailSpeed = 1.3, bounce = 1.3 }, -- a bobbing chick
		Shellshy = { fidgets = { "look", "tilt", "sniff", "yawn", "shake" }, tailSpeed = 0.6, tailAmount = 0.6, bounce = 0.3 }, -- a slow plodder
		Fizzlebug = { fidgets = { "look", "tilt", "spin", "shake" } }, -- a flyer
		Wispurr = { fidgets = { "look", "tilt", "sniff", "stretch", "yawn", "shake", "wag" }, tailSpeed = 0.7, bounce = 0.9 }, -- a lazy cat
		Emberwing = { fidgets = { "look", "tilt", "spin", "shake" }, tailSpeed = 0.6 }, -- a flyer
		Tidecaller = { fidgets = { "look", "tilt", "sniff", "stretch", "yawn", "shake" }, tailSpeed = 0.45, tailAmount = 1.1, bounce = 0.4 }, -- a proud sea dragon
		Briarhorn = { fidgets = { "look", "sniff", "shake", "stomp", "yawn" }, tailSpeed = 0.5, tailAmount = 0.9, bounce = 0.35 }, -- a heavy bull
		AbyssalKoi = { fidgets = { "look", "tilt", "shake" }, tailSpeed = 0.5 }, -- a lurking swimmer
		Puffpuddle = { fidgets = { "look", "tilt", "sniff", "groom", "roll", "yawn", "wag", "shake", "groom" }, tailSpeed = 0.6 }, -- a sea otter
		Blazehound = { tailSpeed = 1.2 }, -- an excited little dog: every dog fidget, a quick wag
		Thornback = { fidgets = { "look", "tilt", "sniff", "stretch", "shake", "yawn" }, tailSpeed = 0.4, tailAmount = 0.4, bounce = 0.5 },
		EclipseFox = { fidgets = { "look", "tilt", "sniff", "stretch", "sit", "scratch", "yawn", "shake" }, tailSpeed = 0.5, tailAmount = 1.1, bounce = 0.7 },
		Duskstalker = { fidgets = { "look", "tilt", "stretch", "hop", "shake", "yawn", "spin" }, tailSpeed = 0.7 },
		Solarion = { fidgets = { "look", "sniff", "yawn", "shake", "stomp", "stretch", "stomp" }, tailSpeed = 0.35, tailAmount = 0.7, bounce = 0.25 },
		Voltkit = { fidgets = { "look", "tilt", "sniff", "stretch", "hop", "shake", "wag", "yawn" }, tailSpeed = 0.8, tailAmount = 1.1 },
	} :: { [string]: { fidgets: { string }?, tailSpeed: number?, tailAmount: number?, bounce: number? } },
	-- Wingbeat speed for big winged models (times PET_ANIM.FLAP_SECONDS' pace; under 1 is slower)
	WING_SPEED = {
		HeronDemon = 0.55,
		NeonSwallow = 0.55,
		Fizzlebug = 0.9, -- a bee's buzz, kept calm (faster shook the whole body)
	} :: { [string]: number },
	-- Pack models whose body waves side to side instead of walking: "swim" floats and swims (fish), "slither"
	-- stays on the ground and waves mostly while moving (snakes)
	UNDULATE = {
		IceShark = "swim",
		AbyssalKoi = "swim",
		Merilux = "swim",
		GiantSnake = "slither",
	} :: { [string]: string },
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
		-- Many tails (Tails_<tail>_<bone>, a kitsune): each on its own beat, fanned, rising and falling a little
		TAILS_SPREAD = 1.9, -- radians of wag between one tail and the next
		TAILS_AMOUNT = 0.7, -- of a single tail's swish
		TAILS_RISE = 6, -- degrees each tail lifts and drops
		-- Capes (Cape_<bone>): billowing back when running, fluttering standing
		CAPE_BILLOW = 45,
		CAPE_FLUTTER = 6,
		CAPE_SECONDS = 1.6,
		LOOK = 38, -- look around: head and neck turn
		TILT = 18, -- head tilt
		SNIFF = 24, -- head and neck down
		STRETCH = 26, -- front legs reach forward, spine dips
		HAPPY_WAG = 2.4, -- tail wag multiplier
		HIP_SWAY = 9, -- pets without tail bones (Kitsune): the hips sway so the tails swish, the spine turns back
		IDLE_SWAY = 2.5, -- two-legged rigs without a tail: weight shifting slowly from foot to foot instead
		IDLE_SWAY_SECONDS = 4.2,
		HIP_TWIST = 9, -- walking on two legs: the hips turn with the forward leg...
		HIP_ROLL = 4, -- ...and dip over the standing one
		SHOULDER_COUNTER = 0.75, -- the chest turns back against the hips (more than cancelling them)
		SIT = 22, -- sit: hips down, hind legs fold
		SCRATCH = 50, -- a hind leg up to scratch
		SHAKE = 16, -- shake like a wet dog: spine and head roll, fast
		YAWN = 26, -- head up
		-- Many-headed rigs (Hydra_<head>_<bone>, Jaw_<head>): each neck sways and nods on its own beat
		HYDRA_SWAY = 14,
		HYDRA_NOD = 7,
		HYDRA_SECONDS = 3.4,
		HYDRA_SPREAD = 2.4, -- radians of beat between one head and the next (out of step, never in a row)
		HYDRA_LAG = 0.6, -- radians of beat per bone up the neck
		JAW_SNAP = 24, -- degrees a jaw snaps open now and then
		JAW_SNAP_SECONDS = 2.2,
		JAW_YAWN = 42,
		HOP_HEIGHT = 0.9, -- whole-body hop (studs at size 1), twice
		BOUNCE = 0.35, -- creatures without bones: a few quick bounces
		SHAKE_BODY = 10, -- the whole body rolls during a shake
		-- Fidgets for rigged pets (bones), and for creatures without bones (whole-body only)
		FIDGETS = { "look", "tilt", "sniff", "stretch", "wag", "hop", "spin", "shake", "sit", "scratch", "yawn" },
		BODY_FIDGETS = { "hop", "spin", "shake", "look", "bounce" },
		-- Saved-animation beasts (Crystal Titans): a roar (rear back, lunge, shockwave ring and sparks in the element
		-- colour), a stomp (rise and slam, dust ring) or a look round, between their own idle animation
		TITAN_FIDGETS = { "roar", "stomp", "look", "roar" },
		ROAR_PITCH = 18,
		ROAR_LIFT = 0.25,
		ROAR_BURST = 0.4, -- of the way through: the lunge and shockwave
		-- Signature idles (Party.SIGNATURE, effects in Util/SignatureFx)
		ROAR_NECK = 30, -- a roaring head rears back and lunges this far
		ROAR_RIPPLE = 0.05, -- of the fidget between one hydra head's roar and the next
		BUTTERFLY_CUE = 0.15, -- of the way through: the butterfly appears on the raised hand
		BUTTERFLY_ARM = 65, -- the right arm comes up this far
		BUTTERFLY_LOOK = 20, -- the head looks up...
		BUTTERFLY_FOLLOW = 30, -- ...and turns to follow it round
		KUNGFU_CHOP = 60, -- each arm swings up and chops this far
		VOLT_FISTS = 60, -- Voltkit's volt charge brings both fists up this far
		ECLIPSE_LOOK = 40, -- Eclipse Fox looks up at its eclipse this far
		BACKFLIP_HEIGHT = 1.4, -- studs at size 1
		SIT_UP = 45, -- a four-legged creature sitting right up on its hind legs (a sea otter grooming) pitches up this far
		GROOM_PAW = 55, -- a sea otter sitting up lifts its front paws this far, to its face or to hold a shell...
		SHELL_TAP = 20, -- ...and taps the shell by dropping them this far
		STOMP_HEIGHT = 0.5,
		-- Flying pets (owls, phoenixes, dragons: the pack's wings have no bones of their own, so the whole body beats):
		-- legs tucked, the body rising and dipping with each flap, the spine pulsing, the head steadying
		FLAP_SECONDS = 0.34, -- one wingbeat hovering
		FLAP_FAST = 1.35, -- this much quicker flying along
		FLAP_LIFT = 0.22, -- studs at size 1
		FLAP_PITCH = 7, -- spine, each beat
		WING_FLAP = 35, -- degrees up and down from rest, each wing bone (Party.WINGS)
		WING_LAG = 0.5, -- radians the next wing bone trails its parent
		-- Rigs named by Util/RigGuess: arms lowered from a T-pose swing against the legs; IK feet lift as they step;
		-- fish swim and snakes slither with a wave down the body (Party.UNDULATE)
		ARM_SWING = 24,
		ARM_BEND = 14, -- elbows, when hanging
		ARM_HANG = 15, -- degrees from straight down a lowered arm ends
		FOOT_LIFT = 0.28, -- studs at size 1
		SWIM_SECONDS = 1.4,
		SWIM_FAST = 1.6,
		SWIM_BEND = 14, -- degrees, scaled up towards the tail
		SWIM_LAG = 0.8, -- radians of phase per bone along the body
		SLITHER_STILL = 0.25, -- how much a snake waves standing still
		LEG_TUCK = 38,
		KNEE_TUCK = 30,
		FLY_FIDGETS = { "look", "tilt", "spin", "wag" },
		FIDGET_GAP = { 2.5, 6 },
		FIDGET_SECONDS = {
			look = 2.4, tilt = 1.6, sniff = 1.8, stretch = 2, wag = 1.6,
			hop = 1.1, spin = 1.2, shake = 1.2, sit = 3, scratch = 1.8, yawn = 2, bounce = 1, roar = 2.2, stomp = 1,
			butterfly = 4.5, voidroar = 3, thunderroar = 2.6, stormroar = 3, firebreath = 3.2, sneeze = 1.6, kungfu = 2.6,
			groom = 3, shellcrack = 3, roll = 1.4, eclipse = 4, backflip = 1.3, solarroar = 3.2, voltcharge = 3,
			hiccup = 2.4, zaphop = 1.6, sporepuff = 2.4, petaltwirl = 1.6, shadowloop = 1.6, emberflap = 1.8, shypeek = 2.8, buzzzap = 2, ghostfloat = 3, flameswoop = 2.2, tidecall = 2.4, thorncharge = 2.2, abysschomp = 2,
		},
		-- Abyssal Koi's abyss chomp: how far it draws back and lunges forward (studs at size 1)
		CHOMP_DRAW = 0.4,
		CHOMP_LUNGE = 1.6,
		-- Briarhorn's thorn charge: how far its head goes down (degrees) and how far it lunges forward (studs at size 1)
		CHARGE_LOWER = 14,
		CHARGE_LUNGE = 1.2,
		-- Tidecaller's tide call: how far it rears up (degrees) and lifts (studs at size 1) before stamping down
		TIDE_REAR = 28,
		TIDE_LIFT = 0.3,
		-- Emberwing's flame swoop: how high it climbs (studs at size 1) and how steeply it dives (degrees)
		SWOOP_HEIGHT = 1.2,
		SWOOP_DIVE = 35,
		-- Wispurr's ghost float: how high it drifts (studs at size 1) and sways (degrees), and how see-through it goes
		GHOST_RISE = 1,
		GHOST_SWAY = 8,
		GHOST_FADE = 0.55,
		-- Fizzlebug's buzz zap: how far it zigzags (degrees) and how high it rises (studs at size 1)
		BUZZ_ZIGZAG = 30,
		BUZZ_RISE = 0.8,
		-- Shellshy's shy peek: how low it sinks into its shell (studs at size 1) and how far its head tucks (degrees)
		SHY_DUCK = 0.15,
		SHY_HEAD = 30,
		-- Ashbeak's ember flap: how high it hops (studs at size 1) and how far its folded wings beat out (degrees)
		FLAP_HOP = 0.5,
		EMBER_FLAP = 55,
		-- Gloomlet's shadow loop: how high it rises over the top of the loop (studs at size 1)
		LOOP_HEIGHT = 1.2,
		-- Petalpaw's petal twirl: how high it lifts mid-spin (studs at size 1)
		TWIRL_LIFT = 0.2,
		-- Mossmole's spore puff: how far it rises onto its toes (studs at size 1) and leans back (degrees)
		SPORE_LIFT = 0.25,
		SPORE_LEAN = 8,
		-- Zappit's zap hop: how high it springs and how low it crouches first (studs at size 1)
		ZAPHOP_HEIGHT = 1.4,
		ZAPHOP_CROUCH = 0.15,
		-- Cindercub's hiccups: when each one comes (fractions of the fidget), how sharp, the hop (studs at size 1),
		-- the body's tip back and the head's jolt back (degrees)
		HICCUP_BEATS = { 0.2, 0.5, 0.8 },
		HICCUP_WIDTH = 0.07,
		HICCUP_HOP = 0.25,
		HICCUP_PITCH = 6,
		HICCUP_HEAD = 22,
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
		-- Ultra Detailed pack (bought): rigged without animations, so Util/RigGuess finds the legs, tail and head
		-- and the code walk drives them; rigs without legs hop. Tints colour the models to their element.
		Cindercub = { pack = "Originals", model = "Cindercub", size = 1.6 }, -- original, tools/blender/rig_cindercub.py (Meshy-generated fire bear cub)
		Ashbeak = { pack = "Originals", model = "Ashbeak", size = 1.4 }, -- original, tools/blender/rig_ashbeak.py (Meshy-generated ember chick)
		Coalbit = { pack = "UltraPets", model = "Salamander", tint = { 130, 110, 110 } },
		Blazehound = { pack = "Originals", model = "Blazehound" }, -- original, tools/blender/build_blazehound.py
		Magmaw = { pack = "UltraPets", model = "Salamander", hue = 0.04 },
		Infernox = { pack = "Originals", model = "Infernox", size = 1.3 }, -- original, tools/blender/build_infernox.py
		Emberwing = { pack = "Originals", model = "Emberwing", size = 1.2, flies = true }, -- original, tools/blender/rig_emberwing.py (Meshy-generated fire swallow)
		Puffpuddle = { pack = "Originals", model = "Puffpuddle" }, -- original, tools/blender/build_puffpuddle.py
		Shellshy = { pack = "Originals", model = "Shellshy", size = 1.4 }, -- original, tools/blender/rig_shellshy.py (Meshy-generated baby sea turtle)
		Driplet = { pack = "UltraPets", model = "FrostDove" },
		Reefray = { pack = "UltraPets", model = "MetalCrab" },
		Mistfin = { pack = "UltraPets", model = "IceShark", size = 1.3 },
		["Abyssal Koi"] = { pack = "Originals", model = "AbyssalKoi", size = 1.6 }, -- original, tools/blender/rig_abyssalkoi.py (Meshy-generated abyss koi)
		Tidecaller = { pack = "Originals", model = "Tidecaller", size = 1.6 }, -- original, tools/blender/rig_tidecaller.py (Meshy-generated sea dragon)
		Sprouthop = { pack = "Originals", model = "Sprouthop", size = 2.2 }, -- original, tools/blender/build_sprouthop.py
		Mossmole = { pack = "Originals", model = "Mossmole", size = 1.5 }, -- original, tools/blender/rig_mossmole.py (Meshy-generated forest mole)
		Petalpaw = { pack = "Originals", model = "Petalpaw", size = 1.5 }, -- original, tools/blender/rig_petalpaw.py (Meshy-generated flower squirrel)
		Thornback = { pack = "Originals", model = "Thornback", size = 1.3 }, -- original, tools/blender/build_thornback.py
		Vinewyrm = { pack = "UltraPets", model = "GiantSnake" },
		Briarhorn = { pack = "Originals", model = "Briarhorn", size = 1.7 }, -- original, tools/blender/rig_briarhorn.py (Meshy-generated forest bull)
		Zappit = { pack = "Originals", model = "Zappit", size = 1.5 }, -- original, tools/blender/rig_zappit.py (Meshy-generated electric bunny)
		Fizzlebug = { pack = "Originals", model = "Fizzlebug", size = 1.6, flies = true }, -- original, tools/blender/rig_fizzlebug.py (Meshy-generated electric bee)
		Sparkrat = { pack = "UltraPets", model = "LightingMouse" },
		Boltlynx = { pack = "Originals", model = "Boltlynx", size = 1.7 }, -- original, tools/blender/rig_boltlynx.py (Meshy-generated lynx)
		Stormjack = { pack = "Originals", model = "Stormjack", size = 1.8 }, -- original, tools/blender/build_stormjack.py
		Thunderhorn = { pack = "UltraPets", model = "Lumistag", tint = { 255, 235, 150 }, size = 1.3 },
		Voltkit = { pack = "Originals", model = "Voltkit", size = 1.4 }, -- original, tools/blender/build_voltkit.py
		Gloomlet = { pack = "Originals", model = "Gloomlet", size = 1.4, flies = true }, -- original, tools/blender/rig_gloomlet.py (Meshy-generated shadow bat)
		Wispurr = { pack = "Originals", model = "Wispurr", size = 1.4 }, -- original, tools/blender/rig_wispurr.py (Meshy-generated ghost kitten)
		Hushmoth = { pack = "UltraPets", model = "FairyMoth", size = 1.3 },
		Nightowl = { pack = "UltraPets", model = "HeronDemon" },
		["Eclipse Fox"] = { pack = "Originals", model = "EclipseFox", size = 1.2 }, -- original, tools/blender/build_eclipsefox.py
		Duskstalker = { pack = "Originals", model = "Duskstalker", size = 1.4 }, -- original, tools/blender/build_duskstalker.py
		-- Legendaries: Crystal Titans (bought Accretion "Stud Pet Pack 03"), with their own Idle/Walk/Run animations
		Solarion = { pack = "Originals", model = "Solarion", size = 3 }, -- original, tools/blender/build_solarion.py
		Voidmaw = { pack = "Originals", model = "Voidmaw", size = 3 }, -- original, tools/blender/build_voidmaw.py
		-- Frontier set
		Frostfang = { pack = "UltraPets", model = "PurpleFox", tint = { 170, 220, 255 } },
		["Gale Sprite"] = { pack = "UltraPets", model = "NeonSwallow" },
		Riftwalker = { pack = "UltraPets", model = "VoidDragon" },
		["Cinder Titan"] = { pack = "UltraPets", model = "GorillaVulcano" },
		["Aurora Drake"] = { pack = "CrystalTitans", model = "RainbowHydra", size = 2.2 },
		Stormking = { pack = "CrystalTitans", model = "SapphireCrab", size = 2.2 },
	} :: { [string]: { pack: string, model: string, variant: string?, tint: { number }?, hue: number?, size: number?, flies: boolean? } },
	-- Saved-animation models (Util/KeyframePlayer): idle below WALK_FROM, run blending in from RUN_FROM to RUN_FULL
	-- (studs a second at size 1, so following a player at 16 studs a second runs); the walk plays at normal speed
	-- at WALK_SPEED, the run at RUN_SPEED. AMPLIFY exaggerates each animation's turns (the pack's own walk only bends
	-- the legs 11 degrees, too little to see on a big spiky beast).
	KEYFRAME_ANIM = {
		WALK_FROM = 0.5, RUN_FROM = 4, RUN_FULL = 6.5, WALK_SPEED = 3, RUN_SPEED = 6.5, BLEND_SECONDS = 0.25,
		AMPLIFY = { 1, 2, 1.6 }, -- idle, walk, run
	},

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
