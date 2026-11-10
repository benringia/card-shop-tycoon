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
	-- The same perk in monster and boss fights (not PvP), from the creature fighting for you: its value for a Common
	-- at 0 stars, grown by RARITY_MULTIPLIER and STAR_BONUS as above (Util/PartyRules.getFightPerk, BattleSim)
	FIGHT_PERKS = {
		Hype = 0.06, -- your sword and your creature hit harder
		Calm = 0.05, -- you and your creature take less damage
		Express = 0.08, -- the sword skill, element ability and signature recharge faster
		Hustle = 0.05, -- your creature attacks faster
		Haggle = 0.06, -- chance for a critical hit (double damage) from your sword and your creature
	},

	-- Creature size, as a multiple of CREATURE_HEIGHT
	SIZE_BY_RARITY = { Common = 0.7, Rare = 0.85, ["Very Rare"] = 1, Epic = 1.5, Legendary = 1.4 },
	CREATURE_HEIGHT = 3, -- studs, for size 1
	FOLLOW_OFFSET = { side = 3, back = 3.5 }, -- studs from the owner, on the ground (times a model entry's size)
	TELEPORT_DISTANCE = 40, -- further than this and the creature jumps next to its owner
	MARKER_RATE = 20, -- server marker updates per second
	MAX_MODEL_PARTS = 200, -- bigger models fall back to the placeholder
	PRELOAD_PARTY_WAIT = 3, -- seconds the background model download waits at start for the player's own cards to go first
	PRELOAD_BATCH = 6, -- models per background download call
	MONSTER_PRELOAD_WAIT = 5, -- seconds after start before this place's boss and monster models download (MonsterController)

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
	FLYING = { "Nightowl", "Emberwing", "Hushmoth", "Fizzlebug" },
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
	-- forward from there, bend = elbows, swing = walking swing (else PET_ANIM.ARM_SWING), idle = how far they bob
	-- standing (none if left out). Flametor holds its short
	-- arms up in front like a T-rex (Infernox's are modelled that way); Sprouthop swings its arms wide.
	ARM_POSE = {
		Flametor = { hang = 50, forward = 55, bend = 60 },
		Infernox = { hang = 0, forward = 0, bend = 10, swing = 8 }, -- small arms already held in front, as modelled
		Sprouthop = { hang = 12, forward = 0, bend = 14, swing = 32 },
		Cindercub = { hang = 0, forward = 0, bend = 0, swing = 14 }, -- paws rest on its tummy, so only a little swing
		Coalbit = { hang = 0, forward = 0, bend = 0, swing = 10 }, -- paws resting on its belly
		Driplet = { hang = 0, forward = 0, bend = 0, swing = 10 }, -- folded wings, fluttering a little
		Mistfin = { hang = 0, forward = 0, bend = 0, swing = 12 }, -- flippers hanging at its sides
		Puffpuddle = { hang = 0, forward = 0, bend = 0, swing = 6 }, -- paws resting on its belly (moulded to it: lifted far they tear)
		Sparkrat = { hang = 50, forward = 0, bend = 20, swing = 30, idle = 18 }, -- stubby arms held out happily (lower and they sink into its round belly), bobbing as it stands
		Zappit = { hang = 0, forward = 0, bend = 10, swing = 18 }, -- arms hang at its sides
		Mossmole = { hang = 0, forward = 0, bend = 0, swing = 4 }, -- hugging its moss garden
		Petalpaw = { hang = 0, forward = 0, bend = 15, swing = 24 },
		CinderTitan = { hang = 6, forward = 8, bend = 20, swing = 30 }, -- heavy knuckle-dragging swing
		Solarion = { hang = 0, forward = 0, bend = 8, swing = 22 }, -- a god's measured stride, arms at its sides as modelled
		Ashbeak = { hang = 0, forward = 0, bend = 0, swing = 10 }, -- folded wings, fluttering a little
		Fizzlebug = { hang = 0, forward = 0, bend = 15, swing = 12 },
		Wispurr = { hang = 0, forward = 0, bend = 0, swing = 12 }, -- paws held up in front
	} :: { [string]: { hang: number, forward: number, bend: number, swing: number?, idle: number? } },
	-- Signature idles: a model's own fidget, played instead of an ordinary one this often (Util/PetRig poses it,
	-- Util/SignatureFx draws its effect): Sprouthop holds up a hand for a butterfly, Voidmaw roars a black hole open in
	-- front of its maw, Boltlynx roars with lightning crackling off its ear and tail bolts, Stormjack the storm ram charges horn first as
	-- lightning rains round it, Infernox breathes fire, Puffpuddle cracks a shell on its chest, Cindercub hiccups little puffs of fire, Zappit zap-hops with lightning off its bolts, Mossmole puffs glowing spores from its mushroom garden, Petalpaw twirls in a swirl of petals, Gloomlet loops the loop in shadow smoke, Ashbeak flaps up a puff of embers, Shellshy peeks out of its shell in a stream of bubbles, Fizzlebug buzzes up and zaps the ground, Wispurr floats up and fades like a ghost, Emberwing swoops trailing fire, Tidecaller rears up and splashes a ring of water, Briarhorn charges in a burst of thorns, Abyssal Koi lunges and snaps its fangs in a dark surge, Thunderhorn rears and calls lightning down onto its antlers, Riftwalker roars a void rift open behind it, Cinder Titan pounds its chest and slams the ground in a ring of fire, Tideborne Kirin rears and calls a spiral of water and golden light, Stormking charges horn-first as lightning rains round it, Reefray barrel-rolls and sends out a glowing tide ring, Nightowl swivels its head right round and hoots as a crescent moon rises, Coalbit hunkers down as its embers flare and glow, Sparkrat shivers with static and zaps lightning from its tail to its ears, Driplet shakes itself dry in a ring of splashing drops, Hushmoth twirls in the air shedding glowing pastel dust, Magmaw breathes a gout of fire, Mistfin hops and lands in a rolling wave of glowing mist, Vinewyrm rears up as flowers and leaves burst round it, Frostfang pounces and ice crystals burst up where it lands, Gale Sprite dives in a spinning gust and lightning flashes off its wings, Blazehound sneezes a puff of fire,
	-- Thornback charges in a burst of thorns, Eclipse Fox summons an eclipse, Duskstalker backflips, Solarion raises a sun over its head that bursts into rays and a ring of fire,
	-- Voltkit curls its tail up over its back and lightning strikes down from its orb
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
		Thunderhorn = { fidget = "thundercall", chance = 0.35 },
		Riftwalker = { fidget = "riftroar", chance = 0.35 },
		CinderTitan = { fidget = "lavaslam", chance = 0.35 },
		Kirin = { fidget = "blessing", chance = 0.35 },
		Stormking = { fidget = "hornstorm", chance = 0.35 },
		Reefray = { fidget = "mantaroll", chance = 0.35 },
		Coalbit = { fidget = "emberglow", chance = 0.35 },
		Sparkrat = { fidget = "staticshock", chance = 0.35 },
		Magmaw = { fidget = "firebreath", chance = 0.35 },
		Mistfin = { fidget = "mistwave", chance = 0.35 },
		Vinewyrm = { fidget = "vinebloom", chance = 0.35 },
		Frostfang = { fidget = "frostpounce", chance = 0.35 },
		GaleSprite = { fidget = "galedive", chance = 0.35 },
		Driplet = { fidget = "watershake", chance = 0.35 },
		Hushmoth = { fidget = "mothdust", chance = 0.35 },
		Nightowl = { fidget = "owlturn", chance = 0.35 },
		Voidmaw = { fidget = "voidroar", chance = 0.35 },
		prismHydra = { fidget = "roar", chance = 0.3 }, -- the final boss (its model is saved under its boss id)
		-- Wild monsters (keyed by species; Util/MonsterLooks): the wolf roars (the plain wildroar), the golem stomps
		["Ash Wolf"] = { fidget = "wildroar", chance = 0.3 },
		["Magma Golem"] = { fidget = "stomp", chance = 0.3 },
		-- The Wild bosses (keyed by boss id, spec 2026-11-01-wild-bosses-arenas-design): only the Warden has a random
		-- one; the Brood Queen's flare and the Colossus's vents come from the fight (Config/Bosses moments)
		meadowWarden = { fidget = "rootslam", chance = 0.3 },
		Boltlynx = { fidget = "thunderroar", chance = 0.35 },
		Stormjack = { fidget = "hornstorm", chance = 0.35 },
		Infernox = { fidget = "firebreath", chance = 0.35 },
		Puffpuddle = { fidget = "shellcrack", chance = 0.35 },
		Blazehound = { fidget = "sneeze", chance = 0.35 },
		Thornback = { fidget = "thorncharge", chance = 0.35 },
		EclipseFox = { fidget = "eclipse", chance = 0.35 },
		Duskstalker = { fidget = "backflip", chance = 0.35 },
		Solarion = { fidget = "sunburst", chance = 0.35 },
		Voltkit = { fidget = "tailstrike", chance = 0.35 },
	} :: { [string]: { fidget: string, chance: number } },
	-- How a model carries itself, so each moves like the creature it is (else the defaults): its own idle fidgets
	-- (else PET_ANIM.FIDGETS), its tail's swish speed and size (times PET_ANIM's), and how much it bounces walking
	-- (times PET_ANIM.HOP_SCALE), and its wingbeat's size (wingAmount, times WING_FLAP). Big beasts swish slowly, don't hop or spin, and walk heavily; Infernox stomps.
	-- A heavy gait: stride (times PET_ANIM.STRIDE: longer, slower steps), legSwing (times LEG_SWING) and sway (times
	-- the two-legged hip roll; above 1 it also sinks onto a bent standing knee, PET_ANIM.HEAVY_KNEE). gait "gallop":
	-- PET_ANIM.GALLOP. jaw: the share of a full gape its Jaw_0 opens (mouths modelled shut and cut open by
	-- rig_kit.mouth_cut crease if they gape wide; 1 when nil).
	CREATURE_STYLE = {
		Boltlynx = { fidgets = { "look", "tilt", "sniff", "stretch", "sit", "scratch", "yawn", "shake", "wag" }, tailSpeed = 0.45, tailAmount = 0.9, bounce = 0.5 },
		-- Pish, the tutorial's guide puppy (spec 2026-11-09-tutorial-pish-design): a small dog's quick wag and bouncy trot;
		-- his big idles are keyed clips (assets/monster-animations/Pish), so only small fidgets here
		-- a small dog's walk (owner 2026-11-10: "shaking so fast"): longer strides, about 1.8 leg cycles a second
		-- strolling and 3.2 trotting (tests/PishWalk), a soft bob
		Pish = { fidgets = { "look", "tilt", "sniff" }, tailSpeed = 0.9, tailAmount = 1, bounce = 0.35, stride = 1.8 },
		Voidmaw = { fidgets = { "look", "sniff", "yawn", "shake", "tilt", "stretch", "stomp" }, tailSpeed = 0.35, tailAmount = 0.7, bounce = 0.4, stride = 1.2 }, -- a huge prowling dragon
		prismHydra = { fidgets = { "look", "shake", "stomp" }, tailSpeed = 0.3, tailAmount = 0.5, bounce = 0.2, stride = 0.9 }, -- the final boss: heavy, slow
		-- Wild monsters (keyed by species, spec 2026-11-01-wild-monster-models-design)
		Mossling = { fidgets = { "look", "sniff", "shake", "yawn" }, tailSpeed = 0.5, tailAmount = 0.5, bounce = 0.3, stride = 1.1 }, -- a heavy, slow plod
		["Puddle Crab"] = { fidgets = { "look", "shake" }, bounce = 0.2 }, -- six legs walking in tripods
		["Cave Bat"] = { fidgets = { "look", "tilt", "spin" } }, -- flies, wings beating
		["Spark Beetle"] = { fidgets = { "look", "shake" }, bounce = 0.2 }, -- six legs, two tripods
		["Magma Golem"] = { fidgets = { "look", "shake", "stomp" }, bounce = 0.15, stride = 1.3, legSwing = 0.6, sway = 1.4 }, -- lumbers on two legs
		["Ash Wolf"] = { fidgets = { "look", "sniff", "stretch", "shake", "yawn" }, tailSpeed = 0.5, tailAmount = 0.8, bounce = 0.4 }, -- a fast prowl
		-- The Wild bosses (keyed by boss id, spec 2026-11-01-wild-bosses-arenas-design)
		meadowWarden = { fidgets = { "look", "shake", "stomp" }, bounce = 0.15, stride = 1.4, legSwing = 0.6, sway = 1.6 }, -- two heavy legs, long arms dragging
		caveBroodQueen = { fidgets = { "look", "tilt", "shake" }, bounce = 0.1 }, -- eight legs in a wave
		emberColossus = { fidgets = { "look", "sniff", "shake", "stomp" }, bounce = 0.2, stride = 1.3, legSwing = 0.6 }, -- a heavy four-legged plod on stubby legs (its rig holds clean up to this swing)
		Stormjack = { fidgets = { "look", "sniff", "shake", "stomp", "hop", "wag" }, tailSpeed = 1.2, tailAmount = 0.7, bounce = 0.8 }, -- a stocky ram, stubby tail flicking
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
		Briarhorn = { fidgets = { "look", "sniff", "shake", "stomp", "yawn" }, tailSpeed = 0.5, tailAmount = 0.9, bounce = 0.6, stride = 1.25, legSwing = 0.75, sway = 1.8 }, -- a heavy bison on short legs: shorter swings so it plods instead of crouching
		AbyssalKoi = { fidgets = { "look", "tilt", "shake" }, tailSpeed = 0.5 }, -- a lurking swimmer
		Thunderhorn = { fidgets = { "look", "sniff", "shake", "stomp", "tilt" }, tailSpeed = 0.6, tailAmount = 0.6, bounce = 0.5, stride = 1.9, gait = "gallop", jaw = 0.4 }, -- a proud stag on long legs, galloping (long strides)
		Riftwalker = { fidgets = { "look", "sniff", "shake", "stomp", "yawn" }, tailSpeed = 0.4, tailAmount = 0.8, bounce = 0.3 }, -- a prowling dragon
		CinderTitan = { fidgets = { "look", "sniff", "shake", "stomp", "yawn", "stretch" }, bounce = 0.9, stride = 1.35, legSwing = 0.75, sway = 2.6 }, -- a heavy brute: long slow lumbering steps, rolling from foot to foot
		Kirin = { fidgets = { "look", "tilt", "sniff", "shake", "stretch" }, tailSpeed = 0.5, tailAmount = 1.1, bounce = 0.6, stride = 1.2 }, -- a graceful, unhurried divine beast
		Stormking = { fidgets = { "look", "sniff", "shake", "stomp" }, tailSpeed = 0.4, tailAmount = 0.7, bounce = 0.3, stride = 1.3, jaw = 0.45 }, -- a colossal armoured plodder
		Nightowl = { fidgets = { "look", "tilt", "tilt", "shake" }, tailSpeed = 0.6 }, -- a watchful owl, head tilting
		Hushmoth = { fidgets = { "look", "tilt", "spin", "shake" } }, -- a fluttering flyer
		GaleSprite = { fidgets = { "look", "tilt", "spin", "shake" }, tailSpeed = 0.9 }, -- a darting flyer
		Frostfang = { fidgets = { "look", "tilt", "sniff", "stretch", "shake", "wag", "yawn" }, tailSpeed = 0.8, tailAmount = 1.1, bounce = 0.9 }, -- a light-footed fox
		Vinewyrm = { fidgets = { "look", "tilt", "sniff", "shake" }, tailSpeed = 0.6 }, -- a slithering serpent
		Mistfin = { fidgets = { "look", "tilt", "sniff", "yawn", "shake", "wag" }, tailSpeed = 0.7, tailAmount = 1.2, bounce = 1 }, -- a proud waddling seal, its tail fin swishing
		Magmaw = { fidgets = { "look", "sniff", "yawn", "shake", "stomp" }, tailSpeed = 0.6, tailAmount = 1.1, bounce = 0.5 }, -- a heavy crawling salamander, its long tail swaying
		Driplet = { fidgets = { "look", "tilt", "sniff", "hop", "shake", "wag" }, tailSpeed = 1.1, bounce = 1.2 }, -- a bobbing little dove
		Sparkrat = { fidgets = { "look", "tilt", "sniff", "hop", "hop", "spin", "shake", "wag" }, tailSpeed = 1.3, bounce = 1.4 }, -- a zippy little mouse
		Coalbit = { fidgets = { "look", "tilt", "sniff", "yawn", "shake", "wag", "hop" }, tailSpeed = 1.1, bounce = 1.2 }, -- a bouncy little cub waddling upright, its tail swishing
		Reefray = { fidgets = { "look", "tilt", "shake" }, tailSpeed = 0.5, tailAmount = 0.5, wingAmount = 0.3 }, -- a gliding manta: shallow beats of its broad wings (full ones folded it up on end), its long tail trailing
		Puffpuddle = { fidgets = { "look", "tilt", "sniff", "yawn", "wag", "shake", "hop" }, tailSpeed = 0.6, bounce = 1.1 }, -- an upright sea otter (rolling over would cartwheel it)
		Blazehound = { tailSpeed = 1.2 }, -- an excited little dog: every dog fidget, a quick wag
		Thornback = { fidgets = { "look", "sniff", "sniff", "shake", "stomp", "yawn" }, tailSpeed = 1.1, tailAmount = 0.7, bounce = 0.7 }, -- a snuffling boar, its curly tail flicking
		EclipseFox = { fidgets = { "look", "tilt", "sniff", "stretch", "sit", "scratch", "yawn", "shake" }, tailSpeed = 0.5, tailAmount = 1.1, bounce = 0.7, jaw = 0.6 },
		Duskstalker = { fidgets = { "look", "tilt", "sniff", "stretch", "shake", "yawn" }, tailSpeed = 0.7, tailAmount = 0.9, stride = 1.1 }, -- a prowling wolf
		Solarion = { fidgets = { "look", "stomp", "stretch", "shake", "look" }, bounce = 0.5, stride = 1.25, legSwing = 0.7, sway = 1.6 }, -- a fire god: slow, heavy, majestic steps
		Voltkit = { fidgets = { "look", "tilt", "sniff", "stretch", "shake", "yawn" }, tailSpeed = 0.6, tailAmount = 0.8, bounce = 0.7, stride = 0.9 }, -- an armoured pangolin waddle
	} :: { [string]: { fidgets: { string }?, tailSpeed: number?, tailAmount: number?, wingAmount: number?, bounce: number?, stride: number?, legSwing: number?, sway: number?, gait: string?, jaw: number? } },
	-- Wingbeat speed for big winged models (times PET_ANIM.FLAP_SECONDS' pace; under 1 is slower)
	WING_SPEED = {
		HeronDemon = 0.55,
		NeonSwallow = 0.55,
		Fizzlebug = 0.9, -- a bee's buzz, kept calm (faster shook the whole body)
		GaleSprite = 0.8, -- a swift's quick wingbeat
		Hushmoth = 0.7, -- a moth's soft flutter
		Reefray = 0.45, -- a manta's slow, deep wingbeat
	} :: { [string]: number },
	-- Pack models whose body waves side to side instead of walking: "swim" floats and swims (fish), "slither"
	-- stays on the ground and waves mostly while moving (snakes)
	UNDULATE = {
		IceShark = "swim",
		AbyssalKoi = "swim",
		Merilux = "swim",
		GiantSnake = "slither",
		Vinewyrm = "slither",
	} :: { [string]: string },
	-- Bone animation for rigged pack models (Util/PetRig, Util/PetAnimator), drawn on each client. Angles in
	-- degrees unless named _RAD; seconds. Walks trot (diagonal legs together) or step (two legs); the spine
	-- breathes, tails wag in a wave, ears flop; standing, a random fidget plays every FIDGET_GAP seconds.
	PET_ANIM = {
		STRIDE = 1.6, -- studs per full leg cycle at size 1 (scaled with the creature)
		-- A gallop (CREATURE_STYLE gait "gallop"; owner 2026-11-05: Thunderhorn "make it like its running"): each right
		-- leg `lead` of a stride behind its left, LEG_SWING and KNEE_LIFT times `swing` and `knee`, the spine rocking
		-- `rock` degrees each way, the head kept `steady` (a share of the rock undone), the body bounding `lift` studs
		GALLOP = { lead = 0.08, swing = 1.5, knee = 1.4, rock = 6, steady = 0.6, lift = 0.35 },
		LEG_SWING = 28, -- upper leg, forward and back
		KNEE_LIFT = 32, -- lower leg bends as it swings forward
		BREATH = math.rad(2.5), -- spine pitch, radians
		BREATH_SECONDS = 2.6,
		ARM_IDLE_SECONDS = 1.6, -- one bob of the arms standing (ARM_POSE idle)
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
		HEAVY_KNEE = 14, -- degrees a heavy gait (CREATURE_STYLE sway) bends the standing knee
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
		-- Voltkit's tail strike: how far each tail bone turns up (degrees, from the base): its tail runs back and down,
		-- so the base lifts it high over the tall armoured back and the next bones ease the tip back over it
		STRIKE_CURL = { 125, -15, -15, 0 },
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
		WING_REST = 3, -- degrees folded wings shift with each breath on the ground
		WING_SPREAD = 40, -- degrees folded wings spread for a roar
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
			charge = 0.6, strike = 0.5, combo = 0.6, cast = 0.6, leap = 1.5,
			look = 2.4, tilt = 1.6, sniff = 1.8, stretch = 2, wag = 1.6,
			hop = 1.1, spin = 1.2, shake = 1.2, sit = 3, scratch = 1.8, yawn = 2, bounce = 1, roar = 2.2, stomp = 1, rootslam = 1.6,
			butterfly = 4.5, voidroar = 3, thunderroar = 2.6, stormroar = 3, firebreath = 3.2, sneeze = 1.6, kungfu = 2.6,
			groom = 3, shellcrack = 3, roll = 1.4, eclipse = 4, backflip = 1.3, sunburst = 3.2, tailstrike = 2.6,
			hiccup = 2.4, zaphop = 1.6, sporepuff = 2.4, petaltwirl = 1.6, shadowloop = 1.6, emberflap = 1.8, shypeek = 2.8, buzzzap = 2, ghostfloat = 3, flameswoop = 2.2, tidecall = 2.4, thorncharge = 2.2, abysschomp = 2, thundercall = 2.4, riftroar = 3, lavaslam = 3, blessing = 3.2, hornstorm = 2.4, mantaroll = 2.2, owlturn = 2.6, emberglow = 2.6, staticshock = 2.2, watershake = 2, mothdust = 2.6, mistwave = 2.2, vinebloom = 2.6, frostpounce = 2.2, galedive = 2,
		},
		-- Nightowl's owl turn: how far its head swivels round (degrees, neck and head together) and nods with the hoot
		OWL_TURN = 120,
		HOOT_NOD = 16,
		-- Gale Sprite's gale dive: how high it climbs (studs at size 1) and how steeply it dives (degrees)
		GALE_CLIMB = 0.7,
		GALE_DIVE = 30,
		-- Frostfang's frost pounce: how low it crouches, how high and far it leaps (studs at size 1), how far it tips (degrees)
		POUNCE_CROUCH = 0.15,
		POUNCE_HEIGHT = 0.5,
		POUNCE_LEAP = 0.9,
		POUNCE_TIP = 12,
		-- Vinewyrm's vine bloom: how high it rears (studs at size 1), leans back and sways (degrees)
		BLOOM_RISE = 0.3,
		BLOOM_LEAN = 10,
		BLOOM_SWAY = 8,
		-- Mistfin's mist wave: how low it crouches and how high it hops (studs at size 1), and how far it leans back (degrees)
		MIST_CROUCH = 0.12,
		MIST_HOP = 0.45,
		MIST_LEAN = 8,
		-- Hushmoth's moth dust: how high it drifts up (studs at size 1) and sways (degrees) as it twirls
		DUST_RISE = 0.6,
		DUST_SWAY = 8,
		-- Driplet's water shake: how hard it shakes side to side (degrees) and how high it fluffs up first (studs at size 1)
		WATER_SHAKE = 9,
		WATER_FLUFF = 0.15,
		-- Sparkrat's static shock: how much it shivers as static builds (degrees) and how high it hops as it discharges (studs at size 1)
		STATIC_SHIVER = 4,
		STATIC_HOP = 0.4,
		STATIC_ARMS = 45, -- and how far its arms fling up (degrees)
		-- Coalbit's ember glow: how low it hunkers (studs at size 1) and how much it shivers (degrees) as its embers flare
		EMBER_CROUCH = 0.12,
		EMBER_SHIVER = 3,
		-- Reefray's manta roll: how high it rises (studs at size 1) for its barrel roll
		MANTA_RISE = 0.8,
		-- Cinder Titan's lava slam: how far the arms pound the chest and go up for the slam (degrees), and the rise
		-- (studs at size 1)
		SLAM_POUND = 45,
		SLAM_RAISE = 66,
		SLAM_LIFT = 0.25,
		-- Solarion's sunburst: how far both arms swing up overhead (degrees) and how far it rises (studs at size 1)
		SUN_RAISE = 160,
		SUN_LIFT = 0.15,
		-- Tideborne Kirin's celestial blessing: how far it rears (degrees) and lifts (studs at size 1) before the light rises
		BLESSING_REAR = 30,
		BLESSING_LIFT = 0.4,
		-- Thunderhorn's thunder call: how far it rears (degrees) and lifts (studs at size 1) before the strike
		THUNDER_REAR = 32,
		THUNDER_LIFT = 0.35,
		-- Abyssal Koi's abyss chomp: how far it draws back and lunges forward (studs at size 1)
		-- Fight attack poses (FightFx): charge crouches and draws back (held), strike lunges, combo lunges three times,
		-- cast rears up then throws (studs at size 1, degrees)
		CHARGE_CROUCH = 0.25,
		CHARGE_DRAW = 0.35,
		STRIKE_LUNGE = 1.4,
		COMBO_LUNGE = 0.9,
		CAST_PITCH = 18,
		CAST_LUNGE = 0.6,
		-- ...and the limbs with them (degrees; owner 2026-11-05: the Eclipse Fox "doesnt have a basic attack animation"):
		-- the charge lowers the head and raises the tail, a strike bites, a combo swipes a front paw (or arm) each third,
		-- left, right, left, and a cast rears the head back, then thrusts it forward
		ATTACK_COIL = 14,
		ATTACK_TAIL = 16,
		ATTACK_BITE = 22,
		ATTACK_DIP = 18,
		ATTACK_PAW = 55,
		ATTACK_ARM = 60,
		CAST_REAR = 22,
		CAST_THRUST = 16,
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
		LEAP_HEIGHT = 3.2, -- a super's wind-up leap (Inferno, Magma Slam): studs at size 1, risen by LEAP_RISE of it,
		LEAP_RISE = 0.35, -- dropping back down over the last LEAP_FALL (it lands as the move hits)
		LEAP_FALL = 0.2,
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
		Coalbit = { pack = "Originals", model = "Coalbit", size = 1.4 }, -- original, tools/blender/rig_coalbit.py (Meshy-generated baby coal salamander, upright)
		Blazehound = { pack = "Originals", model = "Blazehound", size = 1.3 }, -- original, tools/blender/rig_blazehound.py (Meshy-generated flame dachshund; was the voxel build_blazehound.py)
		Magmaw = { pack = "Originals", model = "Magmaw", size = 1.3 }, -- original, tools/blender/rig_magmaw.py (Meshy-generated lava salamander)
		Infernox = { pack = "Originals", model = "Infernox", size = 1.8 }, -- original, tools/blender/rig_infernox.py (Meshy-generated fire T-rex; was the voxel build_infernox.py)
		Emberwing = { pack = "Originals", model = "Emberwing", size = 1.2, flies = true }, -- original, tools/blender/rig_emberwing.py (Meshy-generated fire swallow)
		Puffpuddle = { pack = "Originals", model = "Puffpuddle", size = 1.4 }, -- original, tools/blender/rig_puffpuddle.py (Meshy-generated upright sea otter; was the voxel build_puffpuddle.py)
		Shellshy = { pack = "Originals", model = "Shellshy", size = 1.4 }, -- original, tools/blender/rig_shellshy.py (Meshy-generated baby sea turtle)
		Driplet = { pack = "Originals", model = "Driplet", size = 1.6 }, -- original, tools/blender/rig_driplet.py (Meshy-generated water dove, head drop added by hand)
		Reefray = { pack = "Originals", model = "Reefray", size = 0.6, flies = true }, -- original, tools/blender/rig_reefray.py (Meshy-generated coral manta; flat, so a small size: models scale by height)
		Mistfin = { pack = "Originals", model = "Mistfin", size = 1.4 }, -- original, tools/blender/rig_mistfin.py (Meshy-generated mist seal pup, glowing marks painted by hand)
		["Abyssal Koi"] = { pack = "Originals", model = "AbyssalKoi", size = 1.6 }, -- original, tools/blender/rig_abyssalkoi.py (Meshy-generated ice shark, crystals added by hand)
		Tidecaller = { pack = "Originals", model = "Tidecaller", size = 1.6 }, -- original, tools/blender/rig_tidecaller.py (Meshy-generated sea dragon)
		Sprouthop = { pack = "Originals", model = "Sprouthop", size = 1.5 }, -- original, tools/blender/rig_sprouthop.py (Meshy-generated tree sprite; was the voxel build_sprouthop.py)
		Mossmole = { pack = "Originals", model = "Mossmole", size = 1.5 }, -- original, tools/blender/rig_mossmole.py (Meshy-generated forest mole)
		Petalpaw = { pack = "Originals", model = "Petalpaw", size = 1.5 }, -- original, tools/blender/rig_petalpaw.py (Meshy-generated flower squirrel)
		Thornback = { pack = "Originals", model = "Thornback", size = 1.4 }, -- original, tools/blender/rig_thornback.py (Meshy-generated thorn boar; was the voxel mantis build_thornback.py)
		Vinewyrm = { pack = "Originals", model = "Vinewyrm", size = 1.7 }, -- original, tools/blender/rig_vinewyrm.py (Meshy-generated vine serpent)
		Briarhorn = { pack = "Originals", model = "Briarhorn", size = 1.7 }, -- original, tools/blender/rig_briarhorn.py (Meshy-generated forest bison)
		Zappit = { pack = "Originals", model = "Zappit", size = 1.5 }, -- original, tools/blender/rig_zappit.py (Meshy-generated electric bunny)
		Fizzlebug = { pack = "Originals", model = "Fizzlebug", size = 1.6, flies = true }, -- original, tools/blender/rig_fizzlebug.py (Meshy-generated electric bee)
		Sparkrat = { pack = "Originals", model = "Sparkrat", size = 1.4 }, -- original, tools/blender/rig_sparkrat.py (Meshy-generated electric mouse, bolt tail added by hand)
		Boltlynx = { pack = "Originals", model = "Boltlynx", size = 1.7 }, -- original, tools/blender/rig_boltlynx.py (Meshy-generated lynx)
		Stormjack = { pack = "Originals", model = "Stormjack", size = 1.7 }, -- original, tools/blender/rig_stormjack.py (Meshy-generated storm ram, bolts added by hand; was the voxel build_stormjack.py)
		Thunderhorn = { pack = "Originals", model = "Thunderhorn", size = 1.8 }, -- original, tools/blender/rig_thunderhorn.py (Meshy-generated thunder stag; slim, so a size up)
		Voltkit = { pack = "Originals", model = "Voltkit", size = 1.5 }, -- original, tools/blender/rig_voltkit.py (Meshy-generated storm pangolin; was the voxel build_voltkit.py fox hero)
		Gloomlet = { pack = "Originals", model = "Gloomlet", size = 1.4, flies = true }, -- original, tools/blender/rig_gloomlet.py (Meshy-generated shadow bat)
		Wispurr = { pack = "Originals", model = "Wispurr", size = 1.4 }, -- original, tools/blender/rig_wispurr.py (Meshy-generated ghost kitten)
		Hushmoth = { pack = "Originals", model = "Hushmoth", size = 1.4, flies = true }, -- original, tools/blender/rig_hushmoth.py (Meshy-generated fluffy moth)
		Nightowl = { pack = "Originals", model = "Nightowl", size = 1.4, flies = true }, -- original, tools/blender/rig_nightowl.py (Meshy-generated shadow owl)
		["Eclipse Fox"] = { pack = "Originals", model = "EclipseFox", size = 1.8 }, -- original, tools/blender/rig_eclipsefox.py (Meshy-generated shadow kitsune; was the voxel build_eclipsefox.py)
		Duskstalker = { pack = "Originals", model = "Duskstalker", size = 1.5 }, -- original, tools/blender/rig_duskstalker.py (Meshy-generated shadow wolf; was the voxel build_duskstalker.py monkey king)
		-- Legendaries: Crystal Titans (bought Accretion "Stud Pet Pack 03"), with their own Idle/Walk/Run animations
		Solarion = { pack = "Originals", model = "Solarion", size = 3 }, -- original, tools/blender/rig_solarion.py (Meshy-generated sun fire god; was the voxel build_solarion.py)
		Voidmaw = { pack = "Originals", model = "Voidmaw", size = 2.6 }, -- original, tools/blender/rig_voidmaw.py (Meshy-generated cosmic void dragon; was the voxel build_voidmaw.py hydra)
		-- Frontier set
		Frostfang = { pack = "Originals", model = "Frostfang", size = 2 }, -- original, tools/blender/rig_frostfang.py (Meshy-generated ice fox)
		["Gale Sprite"] = { pack = "Originals", model = "GaleSprite", size = 1.9, flies = true }, -- original, tools/blender/rig_galesprite.py (Meshy-generated storm swift)
		Riftwalker = { pack = "Originals", model = "Riftwalker", size = 1.5 }, -- original, tools/blender/rig_riftwalker.py (Meshy-generated void dragon)
		["Cinder Titan"] = { pack = "Originals", model = "CinderTitan", size = 2 }, -- original, tools/blender/rig_cindertitan.py (Meshy-generated volcano gorilla)
		["Tideborne Kirin"] = { pack = "Originals", model = "Kirin", size = 2.5 }, -- original, tools/blender/rig_kirin.py (Meshy-generated celestial sea kirin; was Aurora Drake)
		Stormking = { pack = "Originals", model = "Stormking", size = 2.4 }, -- original, tools/blender/rig_stormking.py (Meshy-generated storm titan beetle)
	} :: { [string]: { pack: string, model: string, variant: string?, tint: { number }?, hue: number?, size: number?, flies: boolean? } },
	-- Saved-animation models (Util/KeyframePlayer): idle below WALK_FROM, run blending in from RUN_FROM to RUN_FULL
	-- (studs a second at size 1, so following a player at 16 studs a second runs); the walk plays at normal speed
	-- at WALK_SPEED, the run at RUN_SPEED. AMPLIFY exaggerates each animation's turns (the pack's own walk only bends
	-- the legs 11 degrees, too little to see on a big spiky beast).
	KEYFRAME_ANIM = {
		WALK_FROM = 0.5, RUN_FROM = 4, RUN_FULL = 6.5, WALK_SPEED = 3, RUN_SPEED = 6.5, BLEND_SECONDS = 0.25,
		AMPLIFY = { 1, 2, 1.6 }, -- idle, walk, run
		ONE_SHOT_BLEND = 0.15, -- seconds a one-shot attack clip blends in and out (Util/ClipPlayer)
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
	-- A creature appearing, leaving and fainting (owner 2026-11-04; Util/SummonFx, Util/SummonMotion): a summon pops in
	-- out of a ring and pillar of light over `pop` seconds when it was stamped (SummonedAt) at most `window` seconds ago;
	-- an unsummon shrinks it away and a light flies back into its owner over `unsummon` seconds (the server waits that
	-- long before removing it); a faint flashes, tips it over in `tip` seconds, spins dizzy stars for `stars` seconds,
	-- then it fades in a puff over `fade` seconds (and comes back when the fight is over)
	SUMMON_FX = { window = 1.5, pop = 0.4, pillar = 9, unsummon = 0.45, tip = 0.3, stars = 1.3, fade = 0.4 },
	-- Their sounds (owner 2026-11-04; Pro Sound Effects, Roblox-licensed), played where the creature is, at a steady pitch:
	-- one soft bell ding as it pops up (the owner found the first chime cluster loud and busy: "subtle, premium"), a
	-- quiet airy whoosh as it flies back into you. Volume is the Sound's own; range in studs.
	SUMMON_SOUNDS = {
		summon = { id = "rbxassetid://9116395089", volume = 0.1, pitch = 1 }, -- "Quiet twinkle cluster" (owner's pick 2026-11-04): PSE "Magic Glows Soft Clusters Of Chiming Hits 4"
		unsummon = { id = "rbxassetid://9117962385", volume = 0.1, pitch = 1 }, -- "Soft magic fade" (owner's pick 2026-11-04): PSE "Pulsing Tone Smooth Mid Range Synth Tone 3"
		range = 60,
		-- Sounds for the owner to choose from (2026-11-03): in Studio "/summonsound <n> [volume]" and
		-- "/unsummonsound <n> [volume]" (or the admin panel) play option n and use it for your summons until "<cmd> 0"
		options = {
			summon = {
				{ name = "Soft bell ding", id = "rbxassetid://9126073001", volume = 0.16, pitch = 0.82 }, -- PSE "Synth Sparkle Tone High Pitch Bell Tone Ding 4"
				{ name = "Long bell ring", id = "rbxassetid://9126073318", volume = 0.14, pitch = 0.9 }, -- PSE "... Bell Tone Ding 1"
				{ name = "Echo sparkle ping", id = "rbxassetid://9126076030", volume = 0.14, pitch = 0.85 }, -- PSE "Synth Sparkle Tone High Pitch Tone Burst Ping 4"
				{ name = "Airy magic swell", id = "rbxassetid://9117964708", volume = 0.12, pitch = 1 }, -- PSE "Pulsing Tone Smooth Mid Range Synth Tone 10"
				{ name = "Quiet twinkle cluster (now)", id = "rbxassetid://9116395089", volume = 0.1, pitch = 1 }, -- PSE "Magic Glows Soft Clusters Of Chiming Hits 4"
			},
			unsummon = {
				{ name = "Airy whoosh", id = "rbxassetid://9116400132", volume = 0.18, pitch = 1 }, -- PSE "Magic Movement Airy Whips Swooshes 24"
				{ name = "Short soft whoosh", id = "rbxassetid://9116401003", volume = 0.18, pitch = 1 }, -- PSE "... Swooshes 37"
				{ name = "Quick swish", id = "rbxassetid://9116401192", volume = 0.18, pitch = 1 }, -- PSE "... Swooshes 38"
				{ name = "Shimmer pass", id = "rbxassetid://9125646918", volume = 0.14, pitch = 1 }, -- PSE "Magic Whooshes Pass Bys Metallic Shimmering 7"
				{ name = "Soft magic fade (now)", id = "rbxassetid://9117962385", volume = 0.1, pitch = 1 }, -- PSE "Pulsing Tone Smooth Mid Range Synth Tone 3"
			},
		},
	},
	-- Your summoned creature's voice (Util/PetVoice, owner 2026-11-04 "an occasional chirp"): small creatures chirp,
	-- Epics and Legendaries huff; pitched lower the bigger they are; only you hear your own, nearby. It says hello
	-- `hello` seconds after popping up.
	VOICE = {
		small = { "rbxassetid://9117237144", "rbxassetid://9117010372" }, -- PSE "Parakeet Chirps 8", "Mouse Vocal 3"
		big = { "rbxassetid://9113989919" }, -- PSE "Creature Vocal Spider Hiss Exhale 1", pitched down: a big beast's huff
		bigRarities = { Epic = true, Legendary = true },
		every = { 18, 40 }, -- seconds between chirps
		-- Sound volumes (owner 2026-11-06: the screech on summon too loud, Epics and Legendaries most): small chirps, then
		-- the big rarities' huff, a pitched-down hiss that carries much more
		volume = 0.22,
		bigVolume = 0.1,
		range = 45, -- studs it carries (RollOffMaxDistance)
		pitch = { min = 0.55, max = 1.3, vary = 0.08, power = 0.45 },
		bounce = 0.08,
		bounceSeconds = 0.3,
		hello = 0.5,
	},
	-- Your summoned creature while you stand at the healing spring (Util/HealFx, owner 2026-11-04): a "+ Healing" pill over
	-- its name, green plus signs float up off it, sparkles rise, a green light breathes on it, a ring ripples at its feet.
	-- Seconds, studs; colour { r, g, b }.
	HEAL_FX = {
		color = { 90, 235, 120 },
		plusEvery = 0.22,
		plusLife = 1.2,
		plusSize = 64, -- pixels, give or take a quarter
		plusRise = 2.6,
		sparkleRate = 10,
		light = 2.5, -- PointLight brightness at the top of a breath
		pulse = 1.4, -- seconds per breath
		ringEvery = 1.6,
	},
	-- Each client draws your own creatures plus the nearest others (Util/CreatureCull), so a full server stays light
	CULL = { drawDistance = 140, hideDistance = 170, maxDrawn = 30 }, -- studs from the camera; creatures
	CULL_INTERVAL = 0.5, -- seconds between checks
	ACTION_COOLDOWN = 0.5,

	-- The quick party bar in the bottom-right corner (PartyBarController). Pixels; colours as { r, g, b }.
	-- The creature pals look (spec 2026-11-03-hud-creature-pals-design): a cream cushion with round portraits in white
	-- rings, the summoned one bigger with an orange ring; the mascot peeks over its top (Config/HudMascot)
	BAR = {
		PORTRAIT = 48, -- a party portrait's size
		PORTRAIT_OUT = 56, -- the summoned one
		HIT = 70, -- a portrait's (and the Party pill's) tap area: 48 px even at the smallest HUD scale (0.7)
		-- The portrait's 3D rim (owner 2026-11-03, avatar pick b; spec 2026-11-03-cotton-candy-ui-design): a rim in the
		-- creature's element colour (Config/BabyColors ELEMENTS) RIM px wide, its deep shade showing RIM_BASE px under it,
		-- a thin white ring (INNER_RING px) round the picture, a dark fade over the picture's top SINK share (sunk in), a
		-- shine across the top (a share of the portrait wide and tall, from TOP down, see-through). The summoned one also
		-- sits RIM_BASE px higher.
		RIM = 5,
		RIM_BASE = 4,
		INNER_RING = 2,
		SINK = { depth = 0.45, transparency = 0.55 },
		SHINE = { width = 0.62, height = 0.24, top = -0.02, transparency = 0.68 },
		POP = 1.35, -- a card joining the party pops up this much, then settles
		POP_SECONDS = 0.5,
		NAME_WAIT = 2, -- seconds the "joined your party" toast waits for a new card's name to arrive with the binder
		CUSHION = { top = { 255, 246, 234 }, bottom = { 246, 223, 196 }, base = { 233, 201, 162 } },
		OUTLINE = 4, -- the cushion's white outline
		EMPTY = { 238, 220, 196 }, -- an empty slot's fill
		EMPTY_EDGE = { 214, 188, 156 }, -- its faint ring
		TEXT = { 107, 74, 42 }, -- brown words on cream (levels, Party, the "+")
		OUT = { 255, 138, 58 }, -- the summoned portrait's ring, glow and tag
		PARTY_PILL = { 52, 28 }, -- the "Party" pill, drawn inside its HIT-sized tap area
		PILL_HOVER = { scale = 1.05, lift = 3, seconds = 0.3 }, -- a small hop under a mouse, like the HUD tiles
		-- The XP sparks after a monster win (spec 2026-11-03-windows-round3-design, Util/SparkPath): min to max sparks per
		-- portrait (more for more XP), each `seconds` on a curve bowed `lift` px up, `stagger` s apart, `size` px, lilac;
		-- then "+N XP" pops over the portrait (`popText` px), rising `popRise` px over `popSeconds`
		SPARKS = {
			min = 3,
			max = 6,
			seconds = 0.9,
			stagger = 0.07,
			lift = 140,
			size = 22,
			color = { 180, 139, 255 },
			popText = 16,
			popRise = 26,
			popSeconds = 1.2,
			levelRoll = 0.4, -- seconds the level chip counts up from the old level once the sparks land
		},
	},
}
