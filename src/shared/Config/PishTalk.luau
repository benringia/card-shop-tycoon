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
				-- a phone's Bag is an app in the Phone (spec 2026-11-25-pish-first-steps-design 3): shut, then open
				phone = "I brought you a present! Tap the Phone.",
				trayOpen = "Tap Bag.",
				bagOpen = "Tap my present!",
				picked = "Now tap Open!",
			},
		},
		-- the present's best card just joined the party (PartyService.GiveFirstPal); owner 2026-11-17: "When the player
		-- opens their first card. Pish will then ask the player to summon them"
		summonPal = {
			intro = { "Wow! Your best card joined your party!" },
			now = { default = "Tap your new pal to call it out!" },
		},
		buildRack = {
			intro = { "Your pal follows you everywhere now!" },
			now = {
				-- outside your shop: his trail leads you in first (spec 2026-11-25-pish-first-steps-design 4)
				outside = "Let's go inside!",
				default = "Shops need shelves! Tap the Phone.",
				trayOpen = "Tap Shop.",
				shopOpen = "Pick the Small Pack Rack.",
				placing = "Put it on the floor and tap to place!",
			},
		},
		orderStock = {
			intro = { "Empty shelves don't sell. Let's order packs!" },
			now = {
				default = "Walk to the computer.",
				-- the order computer's cart (owner 2026-11-21): the packs into the cart, then Order now
				orderOpen = "Add First Spark packs to your cart!",
				orderCart = "Now tap Order now!",
			},
		},
		stockRack = {
			intro = {},
			now = {
				default = "Your box is here! Pick it up.",
				coming = "Your packs are on the way!",
				carrying = "Now put the packs on your rack!",
			},
		},
		customer = {
			intro = {},
			now = { default = "Look, a customer! Let them shop." },
		},
		-- his first sale walks through the register (owner 2026-11-16: "include the use of cash register on pish's
		-- tutorial"): man it, scan, Charge, then the change from the drawer (his customer always pays cash)
		ringUp = {
			intro = { "Your first customer! Let's use the register." },
			now = {
				default = "Walk to your register and tap Man the register!",
				-- on it with cards still to scan (owner 2026-11-16: tell them to click the cards)
				scan = "Tap each card on the counter to scan it!",
				charge = "All scanned! Tap the green Charge button.",
				-- the payment step (Config/Payment); exact change gives itself
				payCard = "They pay by card! Type the total, then OK.",
				payCash = "They paid cash! Tap money to give back the change.",
			},
		},
		gift = {
			intro = { "You made your first sale! Here's my gift: a special pack!" },
			now = {
				default = "Open it in your Bag!",
				phone = "Open it in your Bag! Tap the Phone.",
				trayOpen = "Tap Bag.",
				bagOpen = "Tap my gift!",
				picked = "Now tap Open!",
			},
		},
		bye = {
			-- owner 2026-11-16: encourage ripping packs for shop XP (a rip gives what selling the pack would)
			intro = {
				"You're a real shop owner now!",
				"Sell and rip packs to grow your shop level!",
				"My buddy Chikin will teach you to fight!",
				-- (it said "Tap me on your party bar": he hasn't been there since 2026-11-13, and a computer's HUD dropped
				-- him on 2026-11-21; Town Pish walks the plaza and petting him gives luck)
				"Find me in town! Pet me for luck. Bye!",
			},
			now = {},
		},
	} :: { [string]: StepTalk },

	-- A lesson visit's line (Config/Pish LESSONS ids)
	-- Each lesson visit's first line (what's new and why); a shelf or stock lesson then teaches it with TEACH
	LESSONS = {
		showcase = "Sell your spare cards in a Glass Showcase!",
		collectorCase = "Sell cards to other players in a Collector Case!",
		sword = "You got a sword! Try it in the Wild!",
		condenser = "The Card Condenser is here! It powers up cards.",
		storageRack = "Storage racks are here! Keep extra boxes in them.",
		forge = "The Forge is here! Make and upgrade weapons.",
		bulkBin = "The Bulk Bin is here! Sell your extra Commons.",
		recycler = "New machine: the Recycler! It eats extra cards.",
		backRoom = "The Back Room can open now! More floor, more customers.",
		gallery = "The Gallery can open now! More floor, more customers.",
		grading = "The Grading Station is here! Grade your cards.",
		jobs = "Your cards can work now! Tap Jobs on your Phone.",
		trophy = "You won a trophy! Show it off in your shop.",
		titles = "You earned a title! Tap your face to equip it.",
		prices = "Set your own prices! Tap Prices on your Phone.",
		spring = "Your pal fainted! The healing spring wakes it up fast.",
		-- {product}: the product the customer missed (TalkRules.product; Config/Customers VARIETY.names)
		variety = "That customer wanted {product}!",
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
		bulkBin = {
			"Walk up and press Add extras.",
			"Your extra Commons go in, 5 to a handful.",
			"Customers buy them! You keep 2 of each card.",
		},
		recycler = {
			"Walk up and press Recycle.",
			"Extra cards turn into upgrade stuff or coins!",
			"Cards you still need always stay safe.",
		},
		condenser = {
			"Put spare copies of a card in here.",
			"They give that card more stars and Power!",
		},
		storageRack = {
			"Carry a box over and press Store.",
			"Press Open to see the sheet and take one back.",
			"Restockers fill racks when your shelves are full!",
			-- away selling with racks (spec 2026-11-24-shop-variety-design)
			"Full racks keep your shop selling while you're away!",
		},
		-- "Customers love choice" (spec 2026-11-24-shop-variety-design), his paws at the order computer
		variety = {
			"That customer wanted {product}!",
			"Shops with every product get more customers!",
			"Customers who find it all pay 10% extra!",
			"Order some here. Bye!",
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
		-- in the Prices window (owner 2026-11-16: "let pish teach players how to set prices"; Config/Pricing BUY_BANDS)
		-- the Jobs window is open (owner 2026-11-21: Pish introduces jobs the moment they unlock)
		jobs = {
			"A card with a job works in your shop for you!",
			"The Restocker fills shelves. The Cashier sells!",
			"Tap Pick a card, choose one, then Assign job.",
			"A working card can't fight. Take it off any time!",
		},
		prices = {
			"Tap + or - to change a price.",
			"At market price, customers almost always buy!",
			"Higher earns more, but fewer will buy.",
		},
	} :: { [string]: { string } },

	-- A lesson teaching its new thing, by where the player is (%s: the thing's name, or the Build tab's)
	TEACH = {
		default = "Tap the Phone.",
		trayOpen = "Tap Shop.",
		tab = "Tap %s.",
		tile = "Tap the %s!",
		-- the tile is further down the list (owner 2026-11-16: the paw pointed at nothing at the bottom)
		scroll = "Scroll down to find the %s!",
		placing = "Put it on the floor and tap to place!",
		computer = "Walk to the computer.",
		orderOpen = "Add %s to your cart!",
		orderCart = "Now tap Order now!", -- it's in the cart: the order computer's Order now
		closeWindow = "Tap the X to close this window.",
		leaveRegister = "Tap Leave to step off the register.",
		-- the trophy lesson (trophies are placed from the Bag, owner 2026-11-17): the Bag, the trophy's slot (`tile`), Place
		bag = "Tap your Bag.",
		bagApp = "Tap Bag.", -- a phone's Bag, an app in the open Phone
		bagPlace = "Tap Place!",
	} :: { [string]: string },

	-- The stuck helper's nudges (Util/LessonRules.nudge)
	NUDGES = {
		order = "Your shelves are empty. Let's order packs!",
		stock = "A box is waiting! Pick it up.",
	} :: { [string]: string },

	-- The talk card is easy to notice and never waits on a press (owner 2026-11-20: "My friend says tutorial is hard
	-- to notice. fix it too. and people hardly press next on tutorial"; Util/TalkRules, client Util/TutorialTalk).
	-- DESKTOP: times bigger on a computer, on top of the HUD's own growth (Config/HudGrow); a phone keeps its small
	-- card (owner 2026-11-11: its screen is crowded). A new line pops in from POP of its size, flashes a gold edge
	-- (`pad` px outside the card, `thickness` px, `beats` flashes fading over `seconds`) and plays a soft chime.
	CARD = {
		DESKTOP = 1.3,
		POP = 0.8,
		GLOW = { seconds = 1.8, beats = 3, thickness = 5, pad = 4, color = { 255, 207, 74 } },
		SOUND = { id = "rbxassetid://9116223893", volume = 0.22, pitch = 1.5 }, -- the objective chime, higher and soft
	},
	-- A plain Next presses itself: once the line is typed it stays `base` s plus `perLetter` a letter (from `min` to
	-- `max`) while a bar fills on the button, then moves on as a press would. Got it!, Bye! and Chikin's Go! send
	-- someone off, so they wait for the player.
	AUTO_NEXT = { base = 1.8, perLetter = 0.09, min = 2.6, max = 7.5 },
	-- The gold ring round the card's button once the line is typed (the tutorial's "press here", Config/Cues RING):
	-- `pad` px off it, `thickness` px, pulsing between the `pulse` transparencies every `beat` s
	NEXT_RING = { pad = 4, thickness = 4, pulse = { 0, 0.65 }, beat = 0.9, color = { 255, 207, 74 } },
	-- The bar that fills on Next: `height` px, `inset` px from the button's sides and bottom
	NEXT_BAR = { height = 5, inset = 8, transparency = 0.45 },

	NAME = "Pish", -- on the talk card
	NEXT = "Next",
	BYE = "Bye!", -- the goodbye's last button
	-- a lesson's or nudge's button that sends him off (owner 2026-11-18: "add close or 'ill keep that in mind' that will
	-- make pish go away. or 'dont remind me again'"): the lesson is done, the nudges stop for the session
	GOT_IT = "Got it!",

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
		-- on the register while the step needs the HUD (the gift in the Bag after his first sale; the register hides it)
		leaveRegister = "Tap Leave to step off the register.",
		petMe = "pet me for luck!",
		arrivalName = "Pish!", -- his name card as he pops out of the stars (Util/DogMagic.banner)
		arrivalRole = "Your shop buddy",
		replayAsk = "Want my shop tour again?",
		replayYes = "Yes!",
		replayNo = "Not now", -- under Town Pish's name at your shop, once your first visit is done
	} :: { [string]: string },
}
