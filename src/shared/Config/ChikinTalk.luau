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
				binderOpen = "Tap your strongest card!",
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
			now = { default = "Walk up to a monster to fight it!" },
		},
		firstWin = {
			intro = { "You won! Your creature got XP.", "Win more fights to level it up!", "Come back at shop level 4. Bye!" },
			now = {},
		},
		sword = {
			intro = { "Woof! You got a sword!", "Now you fight too. Let's try it!" },
			now = {},
		},
		wild2 = {
			intro = {},
			now = { default = "Follow my paws to the Wild!" },
		},
		fight2 = {
			intro = {},
			now = { default = "Walk up to a monster to fight it!" },
		},
		boss = {
			intro = { "Great fighting!", "The Meadow Warden lives through that portal.", "Beat it for a trophy! Bye!" },
			now = {},
		},
	} :: { [string]: { intro: { string }, now: { [string]: string } } },
	-- His first fight lost (in place of firstWin's intro)
	LOST = { "Oh no! Your creature got tired.", "Rest it, or bring another card.", "Come back at shop level 4. Bye!" },
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
	} :: { [string]: string },
	NEXT = "Next",
	BYE = "Bye!",
}
