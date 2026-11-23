--!strict
-- Petting Pish or Chikin (owner 2026-11-23: "when players pet pish and chikin they should get a noticeable popup that
-- they got a notification", mockup A): the dog hands you its painted card (the loading screen's dog cards), which pops
-- up in the middle of the screen with a glow and rays, says what you got, then shrinks and flies into your buffs. Petting
-- again too soon gives nothing, so the dog's speech bubble says when it can again. Read by client Util/PetReward and
-- Util/PetRewardRules (the words, from Config/Pish LUCK and Config/Chikin COURAGE). Plain data: colours { r, g, b },
-- seconds, pixels (at a 1080-pixel-tall screen; scaled to the screen).
return {
	DOGS = {
		Pish = {
			card = "rbxassetid://124790936790346", -- his head-tilt card in the forest (Config/LoadingScreen DOG_CARDS)
			title = "Pish's Luck!",
			line = "Better pulls for %s", -- the time it lasts
			chip = "%s and up: +%d%% chance", -- the rarity it starts at, the boost
			again = "Lucky again in %s!", -- his bubble when petted too soon
			glow = { 255, 226, 140 },
			edge = { 220, 203, 255 },
			chipColor = { 63, 214, 160 },
			chipText = { 16, 57, 43 },
			icon = "🍀",
			tilt = -4,
		},
		Chikin = {
			card = "rbxassetid://119200752178063", -- his hop card on the stormy peak
			title = "Chikin's Courage!",
			line = "Your creatures hit harder for %s",
			chip = "+%d%% damage in every fight",
			again = "Brave again in %s!",
			glow = { 255, 170, 140 },
			edge = { 255, 194, 173 },
			chipColor = { 255, 159, 128 },
			chipText = { 61, 22, 11 },
			icon = "💪",
			tilt = 4,
		},
	},
	-- the card's width, height; text big enough to read on a phone's short screen once scaled (MIN_SCALE)
	SIZES = { card = { 172, 256 }, glow = 440, title = 48, line = 28, chip = 24 },
	MIN_SCALE = 0.6, -- the stage never smaller than this on a short screen
	TIMES = { popIn = 0.4, hold = 2.2, fly = 0.55 },
	DIM = 0.35, -- the screen behind, darkened this much
	SOUND = { id = "rbxassetid://9126073318", volume = 0.3 }, -- PSE "Synth Sparkle Tone ... Bell Tone Ding 1"
}
