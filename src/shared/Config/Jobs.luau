--!strict
-- Shop jobs: cards working in your shop. See DESIGN.md 5.8 and the shop jobs spec.
-- Plain numbers only so Lune unit tests can load this file.
return {
	JOBS = { "Restocker", "Cashier" },
	-- What each job does and its icon (Config/UIIcons), for the Jobs panel
	JOB_INFO = {
		Restocker = { icon = "Shelves", text = "Carries boxes from the delivery pad to empty shelves" },
		Cashier = { icon = "Register", text = "Scans customers' cards at the register" },
	},
	-- shop level for the first job slot (owner 2026-11-17: "unlock the cashier earlier": was 20, the manual register
	-- grew into a chore before then; level 8 is about half an hour into a first session)
	UNLOCK_LEVEL = 8,
	FREE_SLOTS = 1,
	PASS_SLOTS = 1, -- extra slots from the Extra Job Slot game pass
	-- The Extra Job Slot on offer in the Shop Jobs window (owner 2026-11-15: "slot 2 should already say Unlock and make
	-- the window more enticing to buy"; JobsController): a golden row (`top` to `bottom`, `edge` outline and glow) with a
	-- light sweeping across it every `shineEvery` s, `stars` twinkling round the worker, its title and line
	OFFER = {
		height = 104,
		top = { 255, 249, 222 },
		bottom = { 255, 226, 140 },
		edge = { 255, 196, 60 },
		shineEvery = 3,
		stars = 2,
		title = "Unlock a 2nd worker!",
		line = "Two cards work in your shop at once: one can restock while the other runs the register.",
	},
	XP_PER_MINUTE = 2, -- per working card, while the owner is online
	-- Work speed = (SPD / REFERENCE_SPD) ^ SPEED_EXPONENT, clamped. The exponent widens the gap between
	-- rarities: a fresh Grade C Common (SPD 10) works at ~0.6x, a fresh Legendary (SPD 20) at ~1.7x.
	-- Levelling raises SPD, so a raised Common catches up.
	REFERENCE_SPD = 14, -- this SPD (a fresh Very Rare) works at base speed
	SPEED_EXPONENT = 1.5,
	SPEED_MIN = 0.4,
	SPEED_MAX = 2.5,
	WALK_SPEED = 12, -- studs per second at base speed
	STOCK_SECONDS = 2, -- stocking one box at base speed
	SCAN_SECONDS = 1.2, -- one counter item at base speed
	MISTAKE_MAX = 0.20, -- at Power <= MISTAKE_POWER_LOW
	MISTAKE_MIN = 0.03, -- at Power >= MISTAKE_POWER_HIGH
	MISTAKE_POWER_LOW = 170,
	MISTAKE_POWER_HIGH = 485,
	-- Tired spells (Util/TiredRules, owner 2026-11-06): after `every` seconds of work (random in the range) a worker is
	-- tired for `seconds`: it works and walks at `speed` and its mistake chance is x`mistakes` (at most mistakeCap);
	-- then it's rested. It never stops; the owner gets a toast and can step in at the register meanwhile. The server
	-- steps each worker's clock every `tick` seconds
	TIRED = { every = { 600, 900 }, seconds = 300, speed = 0.6, mistakes = 1.5, mistakeCap = 0.3, tick = 1 },
	IDLE_RECHECK_SECONDS = 2,
	STUCK_GRACE_SECONDS = 1, -- extra time per path step before a worker counts as stuck and re-paths
	ACTION_COOLDOWN = 0.5, -- seconds between assign/unassign requests (server)
	STATUS_SEND_SECONDS = 1, -- status updates to the owner are batched to at most one per this
	RARITY_SCALE = { Common = 0.8, Rare = 0.9, ["Very Rare"] = 1, Epic = 1.15, Legendary = 1.3 },
	-- Workers drawn with a creature model (WorkerVisualController) are at least this tall, so a cashier shows
	-- over the counter (2.5 tall) even as a small Common
	CREATURE_MIN_HEIGHT = 3.4,
	-- A worker's name tag (name, grade and level, job): pixels, studs over a rig's head or over the drawn creature's
	-- top (its hover included, Util/CreatureFlight), a solid text outline (0) so it reads against light walls
	TAG = { width = 190, height = 66, overHead = 2.6, overCreature = 1.4, stroke = 0, maxDistance = 70 },
	-- The words the Jobs panel shows for a worker's speed and mistakes (the first entry that matches, from the top),
	-- with a tone for their colour
	SPEED_WORDS = {
		{ min = 1.5, word = "Very fast", tone = "good" },
		{ min = 1.15, word = "Fast", tone = "good" },
		{ min = 0.85, word = "Normal speed", tone = "ok" },
		{ min = 0.6, word = "Slow", tone = "bad" },
		{ min = 0, word = "Very slow", tone = "bad" },
	},
	MISTAKE_WORDS = {
		{ max = 0.05, word = "Almost no mistakes", tone = "good" },
		{ max = 0.09, word = "Few mistakes", tone = "good" },
		{ max = 0.14, word = "Some mistakes", tone = "ok" },
		{ max = 1, word = "Lots of mistakes", tone = "bad" },
	},
}
