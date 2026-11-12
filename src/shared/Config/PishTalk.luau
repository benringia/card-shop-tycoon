--!strict
-- What Pish says (spec 2026-11-09-tutorial-pish-design 14, the owner's script): for each first-visit step a few intro
-- lines (Next moves on), then the line for what to do now, by situation (TutorialController finds the situation and
-- points the paw at its thing); a talk with only intro lines ends on its last Next (the goodbye). One line per lesson
-- visit and per nudge. "{game}" is Config/Game.NAME. Plain ASCII, the middle dot and emoji only, at most 60
-- characters (tests/TalkRules). Plain data.
export type StepTalk = { intro: { string }, now: { [string]: string } }

return {
	STEPS = {
		giftPack = {
			intro = { "Hi! I'm Pish!", "Welcome to {game}!", "This is your very own card shop!" },
			now = {
				default = "I brought you a present. Open your Bag!",
				bagOpen = "Tap my present!",
				picked = "Now tap Open!",
			},
		},
		buildRack = {
			intro = {},
			now = {
				default = "Shops need shelves! Tap Manage.",
				trayOpen = "Tap Shop.",
				shopOpen = "Pick the Small Pack Rack.",
				placing = "Put it on the floor and tap to place!",
			},
		},
		orderStock = {
			intro = { "Empty shelves don't sell. Let's order packs!" },
			now = {
				default = "Walk to the computer.",
				orderOpen = "Pick First Spark packs, then Order!",
			},
		},
		stockRack = {
			intro = {},
			now = {
				default = "Your box is here! Pick it up.",
				carrying = "Now put the packs on your rack!",
			},
		},
		customer = {
			intro = {},
			now = { default = "Look, a customer! Let them shop." },
		},
		ringUp = {
			intro = {},
			now = {
				default = "They're at the counter! Stand behind it.",
				charge = "Tap Charge to sell!",
			},
		},
		gift = {
			intro = { "You made your first sale! Here's my gift: a special pack!" },
			now = {
				default = "Open it in your Bag!",
				bagOpen = "Tap my gift!",
				picked = "Now tap Open!",
			},
		},
		bye = {
			intro = { "You're a real shop owner now!", "My buddy Chikin will teach you to fight!", "Need me later? Tap me on your party bar. Bye!" },
			now = {},
		},
	} :: { [string]: StepTalk },

	-- A lesson visit's line (Config/Pish LESSONS ids)
	-- Each lesson visit's first line (what's new and why); a shelf or stock lesson then teaches it with TEACH
	LESSONS = {
		showcase = "Sell your spare cards in a Glass Showcase!",
		sleeves = "New at the computer: Card Sleeves!",
		collectorCase = "Sell cards to other players in a Collector Case!",
		sword = "You got a sword! Try it in the Wild!",
		wallShelf = "Wall Shelves are here! More room for stock.",
		condenser = "The Card Condenser is here! It powers up cards.",
		forge = "The Forge is here! Make and upgrade weapons.",
		expand = "Deck Boxes are here! Customers love them.",
		accessoryHook = "Accessory Hooks are here! For sleeves and decks.",
		bigRack = "The Big Display Rack is here! Lots of stock.",
		boosterBox = "Booster Boxes are in! They sell for a lot.",
		grading = "The Grading Station is here! Grade your cards.",
		jobs = "Your cards can work now! Tap Jobs.",
		trophy = "You won a trophy! Show it off in your shop.",
		titles = "You earned a title! Tap your face to equip it.",
	} :: { [string]: string },

	-- Once it's placed or ordered, Pish runs to it and says what it's for, one line at a time with Next (the last one
	-- "Bye!"; owner 2026-11-10: "make him explain what this for and stuff like that")
	AFTER = {
		showcase = {
			"Customers buy single cards from this case!",
			"Walk up, press Edit, then Cards to add some.",
			"Price near a card's value and it sells fast!",
		},
		collectorCase = {
			"This case is for other players, not customers.",
			"Press Edit, then Cards, to put your best ones in.",
			"Players who visit your shop can buy them!",
		},
		wallShelf = {
			"It holds packs, just like your rack.",
			"Carry a box to it to stock it!",
		},
		accessoryHook = {
			"It holds Card Sleeves and Deck Boxes.",
			"Carry their boxes to it to stock it!",
		},
		bigRack = {
			"It holds lots of stock at once.",
			"Fill it up and customers buy more!",
		},
		condenser = {
			"Put spare copies of a card in here.",
			"They give that card more stars and Power!",
		},
		forge = {
			"Make weapons here with Wild Ore and cash.",
			"Upgrade them to hit harder in fights!",
		},
		grading = {
			"Grade your cards up here.",
			"A better grade makes a card worth more!",
		},
		trophy = {
			"Everyone who visits your shop sees it!",
			"Beat more bosses for more trophies.",
		},
		sleeves = {
			"Your box is on its way!",
			"Carry it to a shelf. Customers love sleeves!",
		},
		expand = {
			"Your box is on its way!",
			"Carry it to a shelf. Deck Boxes sell for more!",
		},
		boosterBox = {
			"Your box is on its way!",
			"Put it on a shelf. It sells for a lot!",
		},
	} :: { [string]: { string } },

	-- A lesson teaching its new thing, by where the player is (%s: the thing's name, or the Build tab's)
	TEACH = {
		default = "Tap Manage.",
		trayOpen = "Tap Shop.",
		tab = "Tap %s.",
		tile = "Tap the %s!",
		placing = "Put it on the floor and tap to place!",
		computer = "Walk to the computer.",
		orderOpen = "Tap Order on %s!",
		closeWindow = "Tap the X to close this window.",
	} :: { [string]: string },

	-- The stuck helper's nudges (Util/LessonRules.nudge)
	NUDGES = {
		order = "Your shelves are empty. Let's order packs!",
		stock = "A box is waiting! Pick it up.",
	} :: { [string]: string },

	NAME = "Pish", -- on the talk card
	NEXT = "Next",
	BYE = "Bye!", -- the goodbye's last button

	-- The small Skip button and the tour card it opens (round 3, owner's pick A: "just put a skip icon on the top right
	-- and if they click it. the progress and discouragement element shows up"); `tour` takes the step and the count
	-- Town Pish's hellos to a player who comes near (owner 2026-11-12; %s: their name)
	GREETS = {
		"Woof! Hi, %s!",
		"%s! Welcome back to town!",
		"Hi %s! Sold any cards today?",
		"Arf! %s! Pet me for luck!",
	},
	-- ... and to a supporter ("Support the dev", owner 2026-11-12: the town dogs thank you)
	THANKS = {
		"Thank you, %s! 💛",
		"%s, you made our day! 💛",
		"Woof! Our hero, %s! 💛",
	},
	LABELS = {
		tour = "Pish's Tour · %d of %d",
		skip = "Skip",
		tourGift = "Finish the tour for Pish's gift!",
		keepGoing = "Keep going",
		skipYes = "Skip tour",
		close = "Tap the X to close this window.", -- a window the step doesn't use is open (TutorialController)
		petMe = "pet me for luck!",
		arrivalName = "Pish!", -- his name card as he pops out of the stars (Util/DogMagic.banner)
		arrivalRole = "Your shop buddy",
		replayAsk = "Want my shop tour again?",
		replayYes = "Yes!",
		replayNo = "Not now", -- under Town Pish's name at your shop, once your first visit is done
	} :: { [string]: string },
}
