--!strict
-- What Chikin says (spec 2026-11-10-chikin-combat-tutorial-design): each step's intro lines (one at a time, with Next)
-- and the line for what to do now, by situation (Util/TalkRules.show, as Config/PishTalk). Short lines, big text, no
-- symbols the fonts can't draw (tests/ChikinRules).
return {
	NAME = "Chikin",
	STEPS = {
		hello = {
			intro = { "Woof! I'm Chikin, Pish's buddy!", "Your cards are creatures.", "Let's train one to fight!" },
			now = {},
		},
		party = {
			intro = {},
			now = {
				default = "Tap Cards.",
				binderOpen = "Tap a card you like!",
				cardOpen = "Tap Add to party!",
				closeWindow = "Tap the X to close this window.",
			},
		},
		summon = {
			intro = {},
			now = {
				default = "Tap it on your party bar to call it out!",
				closeWindow = "Tap the X to close this window.",
			},
		},
		wild = {
			intro = { "Now let's find a monster!" },
			now = { default = "Follow my paws to the Wild!" },
		},
		fight = {
			intro = {},
			now = { default = "Walk up to a monster and tap Fight!" },
		},
		firstWin = {
			-- he hands over the first sword here (owner 2026-11-16: "chikin should give the player a sword before leaving
			-- the player on wild"): it appears on your back with its popup (SwordGiven, WeaponService)
			intro = { "You won! Your creature got XP.", "Here's a sword! Now you can fight too.", "Let's try it on another monster!" },
			now = {},
		},
		swordWin = {
			-- owner 2026-11-18: monsters give the shop a little XP now (Config/Levels FIGHT_XP_PER_CASH): stay and hunt to
			-- shop level 4, or go sell in town, faster; the last line's paw is on the town button (Config/Chikin TOWN_LINE)
			intro = {
				"Great fighting!",
				"Monsters give your shop a little XP too.",
				"Stay and hunt here to reach shop level 4...",
				"...or tap here to sell in your shop: much faster!",
			},
			now = {},
		},
		sword = {
			intro = { "Woof! Shop level 4!", "A boss is waiting for you!" },
			now = {},
		},
		wild2 = {
			intro = {},
			now = { default = "Follow my paws to the Wild!" },
		},
		fight2 = {
			intro = {},
			now = { default = "Find another monster and tap Fight!" },
		},
		boss = {
			intro = { "The Meadow Warden lives through that portal.", "Beat it for a trophy! Bye!" },
			now = {},
		},
	} :: { [string]: { intro: { string }, now: { [string]: string } } },
	-- The last line of his goodbye after the sword fight for a player already at shop level 4 (the boss visit comes
	-- straight on)
	SWORD_NOW = "You're shop level 4 already! Let's find a boss!",
	-- A sword fight lost or run from: the step stays, he cheers them on to try again
	RETRY = "Oops! Rest up, then try another one!",
	-- His first fight lost (in place of firstWin's intro)
	LOST = { "Oh no! Your creature got tired.", "Here's a sword! Now you can fight too.", "Rest up, then try another monster!" },
	-- In a fight: what to try, one tip at a time (ChikinController), the paw on the button
	FIGHT = {
		creature = "Your creature fights by itself!",
		pet = "Tap Pet when it's ready: a big move!",
		petKey = "Press R when Pet is ready: a big move!",
		attack = "Tap Attack to swing your sword!",
		attackClick = "Click to swing your sword!",
		dodge = "Tap Dodge when a hit is coming!",
		dodgeKey = "Press Shift to dodge a hit!",
		skill = "Tap Skill for your sword's big move!",
		skillKey = "Press E for your sword's big move!",
	} :: { [string]: string },
	-- The Skip button and his tour card (Util/TutorialCues), as Pish's
	LABELS = {
		tour = "Chikin's Training · %d of %d",
		tourGift = "Finish it to fight like a pro!",
		replay = "Chikin's fight lesson",
		petMe = "pet me for courage!", -- under Town Chikin's tag when you can pet him (TownChikinController)
		arrivalName = "Chikin!", -- his name card as he pops out of the stars (Util/DogMagic.banner)
		arrivalRole = "Your battle coach",
	} :: { [string]: string },
	-- Town Chikin's hello to a player who comes near (%s: their name; Util/GreetRules, TownChikinController)
	GREETS = {
		"Woof! Hi, %s!",
		"Hey %s! Ready to battle?",
		"%s! Good to see you!",
		"Arf! Hi %s! Train with me?",
	},
	-- ... and to a supporter ("Support the dev", owner 2026-11-12: the town dogs thank you)
	THANKS = {
		"Thanks for the help, %s! 💛",
		"%s! You're the best! 💛",
		"Woof! Thank you, %s! 💛",
	},
	NEXT = "Next",
	BYE = "Bye!",
	GO = "Let's go!", -- a hello's last button
	GOT_IT = "Got it!", -- sends him off (Config/Chikin GOT_IT_STEPS)
}
