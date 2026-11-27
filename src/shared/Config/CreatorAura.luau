--!strict
-- The Creator aura (owner 2026-11-27: "Dev exclusive title and aura", pick C "orbiting cards"; spec
-- docs/superpowers/specs/2026-11-27-live-admin-creator-design.md): while the game's owner wears the Creator title
-- (TitleService sets the player's CreatorAura attribute) every client draws three card backs (Config/CardDesign
-- BACK.IMAGE) circling that character, each over a gold glow (Config/AttackFx TEXTURES.glow). Client
-- CreatorAuraController; the orbit in Shared/Util/CreatorAuraRules (Lune-tested). Plain data. Studs and seconds.
return {
	COUNT = 3, -- cards
	RADIUS = 3, -- from the HumanoidRootPart's centre
	HEIGHT = 0.4, -- above the HumanoidRootPart's centre: chest height
	LAP = 9, -- seconds a card takes to go round
	BOB = 0.15, -- up and down, three times a lap
	CARD = { w = 1.1, h = 1.6 }, -- a card's size
	CORNER = 0.08, -- its rounded corners, of its width
	GLOW = {
		color = { 255, 207, 74 }, -- the game's gold
		size = 1.7, -- of the card's size
		transparency = 0.35,
	},
	MAX_DISTANCE = 140, -- drawn this close (studs from the camera)
}
