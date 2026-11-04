--!strict
-- The defeat screen (owner 2026-11-04, design A "Defeated card"; Util/DefeatScreen, Util/DefeatRules): the world goes
-- grey with a red edge and a quiet piano sting plays; "DEFEATED" drops in, then a card with the fight's numbers (your
-- sword, each creature, the boss's HP left, rings dodged), a tip, and a countdown ring to town (Combat.LOSS_COUNTDOWN;
-- it can't be skipped). Plain data (Lune-tested).
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	-- APM "Moonlight Tides (sting)" (Roblox-licensed): a pensive piano phrase, 4 s, kept quiet (owner 2026-11-04: subtle)
	MUSIC = "rbxassetid://9045742074",
	MUSIC_VOLUME = 0.22,
	MUSIC_FADE = 0.8, -- seconds it fades out when the screen closes
	-- The world behind it (a ColorCorrectionEffect): saturation, brightness and tint, faded in over `fade` seconds
	GREY = { saturation = -0.85, brightness = -0.08, tint = rgb(255, 214, 214), fade = 0.5 },
	EDGE_COLOR = rgb(140, 0, 0), -- the vignette (Config/CombatHud HIT_FLASH image)
	EDGE_STRENGTH = 0.55,
	TITLE_COLOR = rgb(255, 74, 74),
	CARD_EDGE = rgb(255, 90, 90),
	TIP_COLOR = rgb(255, 217, 160),
	MAX_CREATURES = 3, -- creature rows on the card (the biggest hitters)
	-- One shown at random under the card: the boss's own, else general ones. Plain ASCII (fonts).
	TIPS = {
		general = {
			"Shift dashes through attacks, and you can't be hit while dashing",
			"A creature whose element beats the boss hits it 50% harder",
			"Swap in a rested creature with 1-3 before yours faints",
		},
		meadowWarden = {
			"Step out of the root ring before it closes, or dash through it",
			"Tangled slows you: dash out of the next ring instead of walking",
		},
		caveBroodQueen = {
			"Her web is a cone from her: step to the side, or dash through it",
			"Some webs come huge: watch the warning's size before you step",
			"Poison stops when it runs out, so keep swinging",
		},
		emberColossus = {
			"The meteor lands where its ring closes: dash out before it hits",
			"Burning ticks for 3 seconds: dodge the next slam to stop it coming back",
		},
		frostTyrant = {
			"Chilled slows you and your dodge: get out of rings early",
			"An Ember creature melts through the Frost Tyrant's ice",
		},
		stormSovereign = {
			"Shocked stops your sword and dodge for a moment: don't stand in its rings",
			"Bring a Shade creature: it hits Volt bosses harder",
		},
		riftDevourer = {
			"Weak makes your sword hit softer: dodge its swipes to keep full power",
			"Its swipe is a cone: move to the side, not straight back",
		},
		prismHydra = {
			"Each head has its element: swap to the creature that beats the one glowing",
			"Watch for two rings at once later in the fight",
		},
	},
}
