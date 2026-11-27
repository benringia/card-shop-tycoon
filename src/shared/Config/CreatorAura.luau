--!strict
-- The Creator aura (owner 2026-11-27: "Dev exclusive title and aura", pick C "orbiting cards"; spec
-- docs/superpowers/specs/2026-11-27-live-admin-creator-design.md): while the game's owner wears the Creator title
-- (TitleService sets the player's CreatorAura attribute) every client draws three card backs (Config/CardDesign
-- BACK.IMAGE) circling that character, each glowing gold (GLOW below), with a light and a sparkle trail. Client
-- CreatorAuraController; the orbit in Shared/Util/CreatorAuraRules (Lune-tested). Plain data. Studs and seconds.
return {
	COUNT = 3, -- cards
	RADIUS = 3, -- from the HumanoidRootPart's centre
	HEIGHT = 0.4, -- above the HumanoidRootPart's centre: chest height
	LAP = 9, -- seconds a card takes to go round
	BOB = 0.15, -- up and down, three times a lap
	CARD = { w = 1.1, h = 1.6 }, -- a card's size
	CORNER = 0.08, -- its rounded corners, of its width
	-- Owner 2026-11-27 on seeing it: "make the cards around me glow" (was a faint 1.7x halo at 0.35)
	-- The halo: the cards' own card-shaped glow picture (Config/GradeLook IMAGES.glow, a Grade S card's gold), on its own
	-- BillboardGui behind the card. The particles' soft glow (Config/AttackFx) was nearly see-through in an ImageLabel.
	GLOW = {
		color = { 255, 186, 40 }, -- a Grade S card's gold (Config/GradeLook GLOW.S)
		reach = 0.45, -- card widths round the card on every side (a Grade S card's picture reaches 0.25)
		brightness = 2.5, -- the halo's layer is lit past white, so it glows in daylight too
		transparency = 0.05, -- at its brightest
		breathe = { low = 0.05, high = 0.4, seconds = 1.2 }, -- then swinging between these, in and out
	},
	RIM = { color = { 255, 230, 140 }, thickness = 3 }, -- a gold edge round each card (pixels)
	LIGHT = { color = { 255, 205, 100 }, brightness = 1.5, range = 8 }, -- each card lights what's near it
	-- a trail of glowing sparkles behind each card (Roblox's own sparkle: it reads in daylight, Config/Support SPARKLE)
	SPARKLES = {
		texture = "rbxasset://textures/particles/sparkles_main.dds",
		color = { 255, 220, 120 },
		rate = 10, -- a second, per card
		lifetime = 0.8,
		size = 0.35,
		speed = 0.3,
		lightEmission = 1,
	},
	MAX_DISTANCE = 140, -- drawn this close (studs from the camera)
}
