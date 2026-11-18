--!strict
-- A card a monster drops (owner 2026-11-18: "If a monster drops a new card. make it more noticeable"; pick C "loot
-- beam" of three storyboards, artifact GrridUmWCzFRDtdLja2edS): it lands glowing on the ground where the monster
-- poofed, floating and turning slowly under a tall beam in its rarity colour you can see from far away, with rising
-- sparkles, a glow on the ground and a chime. Walk within `pickupRange` (or wait `autoSeconds`: it comes to you) and it
-- pops up showing its face, then flies into your Cards button, which bounces with a +1 (client Util/CardLoot,
-- Shared/Util/CardLootRules, BattleController). Only the winner sees it: the card is already in their binder, this is
-- the moment. Studs and seconds. Plain data (Lune-tested: tests/CardLootRules).
return {
	cardHeight = 3, -- the card's size (its width height / 1.4), outlined in its rarity colour
	hover = 2.2, -- its middle this far over the ground
	land = { from = 3, seconds = 0.5 }, -- it drops this far onto its spot, dipping a little past it (CardLootRules.landing)
	spin = 55, -- degrees a second it turns
	bob = { studs = 0.18, speed = 2.4 }, -- its gentle float
	-- the light column and its bright middle, clear round the card (checked in Studio: running across it, the beam washed
	-- the card's face out) and brightest just above it
	beam = { height = 34, width = 2.4, core = 0.9 },
	glow = { radius = 2.4, pulse = 0.18, speed = 3 }, -- the disc on the ground
	light = { brightness = 2.2, range = 16 },
	motes = { rate = 14, speed = { 3, 6 }, lifetime = { 1.1, 1.8 }, size = 0.35 },
	pickupRange = 6, -- studs from you: it's picked up...
	showFor = 1.1, -- ...once it has shown this long (a monster beaten right beside you still shows its card first)
	autoSeconds = 4, -- left alone this long it comes to you
	farRange = 90, -- further than this when it would come (you went away): it just fades, it's yours already
	come = { seconds = 0.45 }, -- flying to you
	pickup = { rise = 1.4, grow = 1.35, seconds = 0.35, hold = 0.45, fly = 0.5 }, -- pops up showing its face, then into Cards
	fade = 0.35,
	-- Licensed Pro Sound Effects in use elsewhere
	sounds = {
		land = { id = "rbxassetid://9126073960", volume = 0.45 }, -- Synth Sparkle Tone Ding
		pickup = { id = "rbxassetid://9117841338", volume = 0.45 }, -- Pop Airy 1
	},
	-- The land chime louder for rarer cards
	landVolume = { Common = 0.7, Rare = 0.85, ["Very Rare"] = 1, Epic = 1.15, Legendary = 1.3 } :: { [string]: number },
}
