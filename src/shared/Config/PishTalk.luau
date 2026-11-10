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
			intro = { "You're a real shop owner now!", "Need me later? Tap Manage, then Pish. Bye bye!" },
			now = {},
		},
	} :: { [string]: StepTalk },

	-- A lesson visit's line (Config/Pish LESSONS ids)
	LESSONS = {
		sleeves = "New at the computer: Card Sleeves!",
		sword = "You got a sword! Try it in the Wild!",
		condenser = "The Card Condenser is here! Find it in Shop.",
		forge = "The Forge is here! Build it from Shop.",
		expand = "Deck Boxes are here! Order them at the computer.",
		boosterBox = "Booster Boxes are in! Order one at the computer.",
		grading = "The Grading Station is here! Build it from Shop.",
		jobs = "Your cards can work now! Tap Jobs.",
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
	LABELS = {
		tour = "Pish's Tour · %d of %d",
		skip = "Skip",
		tourGift = "Finish the tour for Pish's gift!",
		keepGoing = "Keep going",
		skipYes = "Skip tour",
		close = "Tap the X to close this window.", -- a window the step doesn't use is open (TutorialController)
		petMe = "pet me for luck!", -- under Town Pish's name at your shop, once your first visit is done
	} :: { [string]: string },
}
