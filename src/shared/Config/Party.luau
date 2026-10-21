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
	-- Cards that reuse another card's model (tinted to their element): { [cardName] = modelName }
	MODEL_FOR_CARD = {},

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
}
