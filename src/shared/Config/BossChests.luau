--!strict
-- The boss chests (spec docs/superpowers/specs/2026-11-11-boss-chests-design.md): after a full-loot win of a boss with a
-- weapon, three chests on the reveal stage; the player picks one. The weapon if it dropped (same odds and pity as
-- before), otherwise its material (MATERIAL weights, averaging the old roll's 1.2: 80% x 1-2). Plain data (Lune reads it).
return {
	COUNT = 3,
	PICK_SECONDS = 20, -- then the server opens one itself
	GRACE_SECONDS = 2, -- on top of PICK_SECONDS, for the network
	MATERIAL = {
		{ count = 1, weight = 0.85 },
		{ count = 2, weight = 0.10 },
		{ count = 3, weight = 0.05 },
	},
	OPEN_GAP = 0.4, -- seconds between the other chests opening after yours
	SKIP_AFTER = 1.5, -- a miss closes on a tap after this
	CLOSE_AFTER = 5, -- or by itself after this
	REVEAL_AFTER = 3.2, -- a weapon's chest opens (its tension, burst and the others: BEATS), then (server) its drop cinematic
	-- The look (BossChestController, Util/ChestModel), on the pack opening's stage (Util/OpeningStage): the chests sit
	-- across the view at these screen fractions (y: their bottoms), `width` of the view wide each but never taller than
	-- `height` of it (a wide window), and never under `minPixels` wide on a phone; their cards rise above them, at most
	-- `cardHeight` of the view tall
	LOOK = {
		xs = { 0.22, 0.5, 0.78 },
		y = 0.8,
		width = 0.2,
		height = 0.3,
		minPixels = 130,
		cardHeight = 0.34,
		wobble = { angle = 5, speed = 2.4 }, -- degrees, radians a second (each chest a step behind the last)
		lift = 0.18, -- the picked chest rises this share of its width
		lidOpen = 110, -- degrees
		openSeconds = 0.35,
		colors = {
			wood = { 176, 108, 58 },
			woodDark = { 120, 70, 36 },
			trim = { 246, 196, 82 },
			glow = { 255, 220, 120 }, -- a material's light (a weapon's: its rarity colour)
		},
	},
	-- The opening's beats (the owner 2026-11-11: "more immersive"; Util/ChestMotion): the chests drop in one after another
	-- (studs, seconds; a small shake on each landing), rattle now and then while waiting (their lid cracks `crack`
	-- degrees), hop and glow under the pointer, and the picked one shakes harder and harder (degrees) while the camera
	-- pushes in, then bursts: flash, shake, gold shards (coins), rays, the reward rising out spinning; the others pop
	-- open after; a tap sends yours off to the top right.
	BEATS = {
		drop = { stagger = 0.22, seconds = 0.4, height = 3, shake = 0.05 },
		rattle = { every = { 2, 4.5 }, seconds = 0.4, crack = 16, hop = 0.08 },
		hover = { hop = 0.12, glow = 0.3 },
		tension = { seconds = 1.2, shakeFrom = 3, shakeTo = 14, speed = 34, push = 1.3, pushSeconds = 0.5, leak = 0.5 },
		burst = { flash = 0.55, shake = 0.08, shards = 24, size = 3, rise = 0.55, spin = 200, othersAfter = 0.8 },
		collect = { seconds = 0.5 },
	},
	-- Config/PackOpening sound names (rattle: the creak sped up)
	SOUNDS = {
		pick = "flip",
		creak = "chestCreak",
		thud = "chestThud",
		rattle = "chestCreak",
		tension = "tease",
		weapon = "hitEpic",
		material = "hitRare",
		coins = "chestCoins",
		empty = "chestPoof",
		collect = "shimmer",
	},
	RATTLE_SPEED = 1.8,
	-- A reduced win's empty chest (ChestRules.reason): its card's words and glyph
	EMPTY = {
		glyph = "💨",
		strong = { line = "Too strong here!", under = "Harder bosses fill chests" },
		tired = { line = "Empty for today", under = "Full chests again tomorrow" },
	},
	-- The chest model (Util/ChestModel): ReplicatedStorage.PackModels[MODEL] with its Body and Lid (tools/blender/
	-- build_chest.py), else a stand-in built from parts
	MODEL = "Chest",
}
