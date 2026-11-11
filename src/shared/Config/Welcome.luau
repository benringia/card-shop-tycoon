--!strict
-- The first-visit welcome cinematic (Portal Worlds spec): a flight past Forest Falls, Frostpeak, over the plaza and past
-- Ember Canyon, ending in front of the player's own shop; the time of day runs as a time-lapse from morning to
-- sunset, holding sunset for the last SUNSET_SHARE. Plain data, read by Lune tests (Util/WelcomePath).
-- KEYS: t (0..1 of the flight), the camera's position and where it looks; the shop's key is added at t = 1.
-- Livelier since the owner 2026-11-11 ("a bit plain. can you make it more epic/jolly/welcoming, like a whoosh sound on
-- the camera and stuff like that"): its own music (Config/Music WELCOME), a card for each place as the camera passes it
-- (CARDS: seconds into the flight, popping in with a chime), whooshes on the fast stretches (CUES), a camera that widens
-- as it speeds up and banks into turns (LENS, Util/WelcomePath.lens) and confetti at your shop (CONFETTI).
return {
	SECONDS = 12,
	SUNSET_SHARE = 0.5,
	KEYS = {
		{ t = 0, pos = { x = 218, y = 40, z = -82 }, look = { x = 185, y = 16, z = -150 } }, -- Forest Falls
		{ t = 0.22, pos = { x = 158, y = 46, z = 72 }, look = { x = 205, y = 36, z = 185 } }, -- Frostpeak and the aurora
		{ t = 0.45, pos = { x = 62, y = 44, z = -22 }, look = { x = 0, y = 5, z = 0 } }, -- over the plaza
		{ t = 0.68, pos = { x = -118, y = 40, z = -22 }, look = { x = -215, y = 10, z = 0 } }, -- Ember Canyon
	},
	SHOP_VIEW = { back = 32, up = 11, lookUp = 8 }, -- studs out from the shop's door, above the ground; looking at the sign
	SKIP_SIZE = { 140, 56 }, -- pixels
	STREAM_TIMEOUT = 3, -- seconds at most to wait for the scenery along the flight to stream in (all keys at once)
	BAR_SHARE = 0.09, -- the black cinema bars, share of the screen's height each
	TITLE = "Welcome to Cardshop Simulator!",
	TITLE_SECONDS = { 0.6, 3.6 }, -- when the title shows
	-- A card at the bottom as the camera passes each place (seconds into the flight; the camera reaches Frostpeak at
	-- about 3.7 s, the plaza 5.6, Ember Canyon 7.4, your shop at the end): its icon, name and what you do there
	CARDS = {
		{ from = 0.5, to = 2.8, icon = "🌲", title = "Forest Falls", sub = "Battle wild creatures", color = { 120, 200, 96 } },
		{ from = 3.2, to = 5.0, icon = "❄️", title = "Frostpeak", sub = "The Frontier: tougher monsters", color = { 150, 210, 255 } },
		{ from = 5.2, to = 6.9, icon = "⛲", title = "The Plaza", sub = "Meet other shop owners", color = { 255, 200, 90 } },
		{ from = 7.1, to = 9.1, icon = "🔥", title = "Ember Canyon", sub = "Battle other players", color = { 255, 120, 60 } },
		{ from = 10.6, to = 12, icon = "🏪", title = "Your shop!", sub = "Open packs, sell cards, get rich", color = { 255, 150, 210 }, finale = true },
	},
	CARD_POP = 0.45, -- seconds a card bounces in over (Util/WelcomePath.cardAt)
	-- Sounds at moments of the flight (seconds; each card also chimes as it pops): whooshes as the camera swoops
	-- between places, a sparkle with the title, the finale at your shop. Pro Sound Effects.
	CUES = {
		{ at = 0.6, sound = "sparkle", volume = 0.6 },
		{ at = 2.5, sound = "whoosh1", volume = 0.7 },
		{ at = 4.5, sound = "whoosh2", volume = 0.7 },
		{ at = 6.4, sound = "whoosh3", volume = 0.7 },
		{ at = 8.9, sound = "whoosh4", volume = 0.75 },
		{ at = 10.6, sound = "finale", volume = 0.8 },
		{ at = 10.7, sound = "pop", volume = 0.6 },
	},
	SOUNDS = {
		whoosh1 = "rbxassetid://9116410164", -- Magic Swoosh Fast Zooming Pass Bys 2
		whoosh2 = "rbxassetid://9116416708", -- Magic Swoosh Fast Zooming Pass Bys Airy 16
		whoosh3 = "rbxassetid://9116412767", -- Magic Swoosh Fast Zooming Pass Bys 4
		whoosh4 = "rbxassetid://9116417467", -- Magic Swoosh Fast Zooming Pass Bys Airy 23
		chime = "rbxassetid://9125644310", -- Magic Twirling Small High Pitch Spinning Chime (each card)
		sparkle = "rbxassetid://9116394876", -- Magic Glows Soft Clusters Of Chiming Hits 2 (the title)
		finale = "rbxassetid://9125635430", -- Magical Exit Sparkling Pass Bys Clinking Chimes (your shop)
		pop = "rbxassetid://9117841338", -- Pop Airy 1 (the confetti)
	},
	CHIME_VOLUME = 0.45,
	-- The camera: its field of view widens with its speed (studs a second) up to `maxExtra` degrees, and it banks into
	-- turns (its look's turn in degrees a second) up to `maxRoll`, both eased by `smoothing` a second
	LENS = { fov = 70, maxExtra = 12, fovPerSpeed = 0.15, maxRoll = 8, rollPerTurn = 0.12, smoothing = 3 },
	-- Your shop's finale as the flight arrives (Util/WelcomeFx; the owner 2026-11-11: "dont add drawn confetti. search for
	-- a free/safe particle/VFX on creator store"): confetti shooting up from two cannons either side of the door
	-- (Onogork's Confetti Particle Emitter, 8250441745: its size and colour flickering as each piece spins; `count` per
	-- colour per cannon; `side` studs from the door, tilted `tilt` degrees inward), and over the sign the Euphoric
	-- Games VFX Pack's star burst, gold stars twinkling and a soft glow (`up` studs over the door). Emitters as
	-- Util/PackEmitter reads them (`colorKeys`: a flickering colour).
	FINALE = {
		seconds = 4, -- the pieces are cleared after this
		confetti = {
			count = 12,
			side = 11,
			up = 1,
			tilt = 22,
			palette = {
				{ { 255, 140, 180 }, { 230, 60, 120 } },
				{ { 255, 220, 110 }, { 230, 160, 30 } },
				{ { 130, 205, 255 }, { 40, 110, 230 } },
				{ { 160, 235, 150 }, { 60, 170, 80 } },
				{ { 210, 170, 255 }, { 140, 80, 220 } },
			},
			emitter = {
				texture = "confettiSquare",
				lifetime = { 2.2, 3 },
				speed = { 38, 52 },
				spread = { 22, 22 },
				accel = { 0, -30, 0 },
				drag = 0.7,
				rotation = { 0, 356 },
				rotSpeed = { -100, 100 },
				-- Onogork's: the size (and colour) flick between a face and an edge, so each piece seems to tumble
				-- (bigger than his 0.2: the camera watches from 32 studs out)
				size = { { 0, 0.9 }, { 0.1, 0.05 }, { 0.2, 0.9 }, { 0.3, 0.05 }, { 0.4, 0.9 }, { 0.5, 0.05 }, { 0.6, 0.9 }, { 0.7, 0.05 }, { 0.8, 0.9 }, { 0.9, 0.05 }, { 1, 0.9 } },
				transparency = { { 0, 0 }, { 0.85, 0 }, { 1, 1 } },
				emission = 0,
				brightness = 1,
			},
			circle = "confettiCircle", -- every other colour round pieces
		},
		burst = {
			count = 30,
			up = 9,
			emitter = {
				texture = "starStreak",
				lifetime = { 0.45, 0.7 },
				speed = { 110, 190 },
				spread = { 360, 360 },
				accel = { 0, -10, 0 },
				drag = 12,
				size = { { 0, 1 }, { 0.54, 2.7 }, { 0.69, 2.4 }, { 0.75, 1.15 }, { 0.84, 2.6 }, { 0.9, 1 }, { 1, 0 } },
				transparency = { { 0, 0.25 }, { 1, 0 } },
				color = { 255, 214, 110 },
				emission = 1,
				brightness = 4,
				facing = "parallel",
				zOffset = 2,
			},
		},
		stars = {
			count = 14,
			up = 9,
			box = { 16, 8, 2 },
			emitter = {
				texture = "goldStars",
				lifetime = { 0.9, 1.4 },
				rotation = { -360, 360 },
				size = { { 0, 2 }, { 1, 2 } },
				transparency = { { 0, 1 }, { 0.5, 0 }, { 1, 1 } },
				color = { 255, 212, 57 },
				emission = 2,
				brightness = 4,
				zOffset = 1,
			},
		},
		glow = {
			count = 2,
			up = 9,
			emitter = {
				texture = "auraLight",
				lifetime = { 1, 1.2 },
				rotation = { -360, 360 },
				size = { { 0, 10 }, { 1, 10 } },
				transparency = { { 0, 1 }, { 0.4, 0.75 }, { 1, 1 } },
				color = { 255, 220, 140 },
				emission = 1,
				brightness = 1.5,
			},
		},
	},
}
