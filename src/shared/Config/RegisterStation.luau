--!strict
-- Manning the register (owner 2026-11-16: "when I go to a cash register, I want the option like 'Man the cashier'. I
-- will then switch to first person with the UI of an actual cash register ... when I get off the cash register, I will
-- then switch back to third person"; like TCG Card Shop Simulator; modern, to match the shop). The register unit on the
-- counter (server: Util/RegisterBuild) has a screen facing the cashier, a cash drawer that slides out toward them and a
-- card machine; RegisterStationController drives it in first person. Plain data (colours { r, g, b }, offsets in studs
-- from the counter top's centre: +X along the counter, +Y up, +Z toward the cashier) so Lune tests can read it.
return {
	PROMPT = { action = "Man the register", object = "Register", hold = 0, distance = 9 },
	LEAVE = "Leave",
	-- The register's body (owner 2026-11-16: "you can use meshy to draw the cash register"): ReplicatedStorage.PropModels
	-- .RegisterBody, a MeshPart from tools/blender/build_register.py (assets/blender/Register/RegisterBody.fbx, imported in
	-- Studio and saved as assets/props/RegisterBody.rbxm), scaled to `width` studs, its front (-Z as imported) turned to
	-- the cashier. Without it, a code-built body of the same shape stands in. Its numbers below are the model's
	-- (RegisterBody_measure.json) at that width: its base 2.6 studs wide, its bigger screen (owner 2026-11-16: "the
	-- display doesnt fit the screen. make the screen bigger so the display fits") a little wider
	BODY = { model = "RegisterBody", width = 2.79 },
	-- The unit, at the counter's left end (Town.COUNTER REGISTER: x and width)
	UNIT = {
		x = -1.7,
		housing = { size = { 2.6, 0.75, 1.63 }, z = 0 }, -- the base the drawer slides out of
		-- the pole: the screen stands high, clear above the card machine (owner 2026-11-16: "give change and card machine
		-- overlapping")
		stand = { size = { 0.5, 1.4, 0.3 }, z = -0.15 },
		-- the screen's front: its size (the game's display, just inside the bezel's rim), the centre of its face (x, up,
		-- toward the cashier), how far it leans back and the display's corner radius (the bezel's)
		screen = { size = { 2.68, 1.635 }, centre = { 0, 2.64, 0.05 }, tilt = 28.6, corner = 0.1 },
		drawer = { size = { 2.36, 0.38, 1.48 }, closedZ = 0, openZ = 1.55, seconds = 0.35 },
		-- the dark opening on the base's front while the drawer is out (the body's own drawer face shows when it's in)
		cavity = { size = { 2.3, 0.4 }, y = 0.24, z = 0.82 },
		-- the card machine on the base's front right, under the screen, clear of the scan items on the counter
		card = { x = -1.0, y = 0.75, z = 0.5, size = { 1.15, 0.16, 0.9 }, tilt = 45 }, -- stood up toward the cashier
	},
	COLORS = {
		body = { 246, 246, 250 }, -- the shop's white
		trim = { 44, 46, 58 }, -- the shop's charcoal
		screen = { 24, 26, 36 },
		accent = { 162, 116, 255 }, -- lilac, the UI's
		bill = { 120, 196, 132 },
		coin = { 240, 200, 90 },
		tray = { 58, 62, 72 },
	},
	-- The first-person view (offsets from the counter top's centre, like UNIT), a pose for each step: the eye over the
	-- cashier's step looking down at the unit, the scan items and the customer; face to face with the screen for Charge;
	-- leaning in to the card machine for a card; over the open drawer (the screen's "Give back" still in view) for cash.
	-- A phone gets its own closer poses (owner 2026-11-16: "optimize it for phone, buttons are too small for phone"):
	-- the screen's buttons, the keys and the money at least about 44 points tall there
	CAMERA = {
		poses = {
			default = { eye = { -0.9, 3.8, 3.4 }, look = { -0.95, 1.35, -0.45 } },
			charge = { eye = { -1.7, 3.89, 2.33 }, look = { -1.7, 2.6, 0.05 } },
			card = { eye = { -1.1, 2.45, 1.95 }, look = { -1.15, 1.45, 0.25 } },
			cash = { eye = { -1.65, 3.7, 3.9 }, look = { -1.7, 1.0, 0.5 } },
		},
		phonePoses = {
			default = { eye = { -0.95, 3.45, 3.0 }, look = { -0.95, 1.6, -0.35 } },
			charge = { eye = { -1.7, 3.5, 1.63 }, look = { -1.7, 2.6, 0.05 } },
			card = { eye = { -1.0, 1.7, 1.05 }, look = { -1.0, 1.17, 0.52 } },
			cash = { eye = { -1.7, 3.3, 3.35 }, look = { -1.7, 1.85, 1.25 } }, -- the screen's top to the coins in one view
		},
		fov = 70,
		seconds = 0.45,
	},
	-- Exact change gives itself after this long (no small button to find on a phone; a kid sees "Exact!" first)
	AUTO_GIVE_SECONDS = 0.7,
	-- Money given lands on the counter in a row, right of the card machine
	-- (notes lie lengthwise, toward the cashier, so each one is its own tap)
	-- as the drawer's own notes and coins with their pictures (owner 2026-11-19: "add money model on the cashier for
	-- moneys at the table"; they were plain green bars and gold discs): `perRow` across, a note NOTE_ASPECT wide for its
	-- length, `rowGap` between rows
	GIVEN = { x = 0.35, z = 0.55, step = 0.47, perRow = 4, rowGap = 0.06, billSize = { 0.42, 0.02, 0.61 }, coinSize = { 0.035, 0.32, 0.32 } },
	-- Tapping money (owner 2026-11-20: "make clicking on moneys on the cashier more immersive"; it popped onto the
	-- counter with no sound): a tapped note or coin flies `fly` seconds out of its drawer slot in an arc `arc` studs
	-- high (a coin flips `flips` times, a note tilts `tilt` degrees) and lands on the counter; tapped there it flies
	-- `back` seconds home. Each has its sound: `cut` seconds of a longer clip, its pitch `pitchStep` higher with every
	-- piece on the counter up to `pitchMax` (RegisterStationRules.givePitch), `backPitch` going back. Its value pops
	-- over it ("+$1") and rises `pop.rise` studs; the stack under your mouse glows (`hover`); the exact change glows
	-- mint (`exact`) before it gives itself. Sounds: Pro Sound Effects, Roblox-licensed, not heard by the owner yet.
	GIVE_FX = {
		fly = 0.22,
		back = 0.18,
		arc = 0.55,
		flips = 1,
		tilt = 22,
		pop = { seconds = 0.75, rise = 0.5, width = 110, height = 34 },
		sounds = {
			note = { id = "rbxassetid://9113726249", volume = 0.35, cut = 0.32 }, -- Cash Counting Paper Money Constant 3
			coin = { id = "rbxassetid://9113850236", volume = 0.3, cut = 0.55 }, -- Coin Throws 9 (a single quarter)
			pitchStep = 0.04,
			pitchMax = 1.3,
			backPitch = 0.85,
		},
		hover = { color = { 255, 201, 63 }, fill = 0.75 },
		exact = { color = { 95, 224, 164 }, fill = 0.35, seconds = 0.6 },
	},
	SCREEN_PIXELS = 300, -- SurfaceGui PixelsPerStud on the screen and the keypad
	-- The screen's one big line for each situation (owner 2026-11-16: "improve the registers UI ... it is also currently
	-- confusing for the kids"; round 2 mockup approved): it is the guide, so there's no hint strip
	SAY = {
		idle = "Waiting for a customer...",
		scan = "👇 Tap each card on the counter",
		charge = "All scanned!",
		offer = "They want to make a deal!",
		card = "💳 They pay by card!",
		cash = "💵 They paid cash!",
	},
	SCREEN = {
		title = "Register",
		today = "Today: %d %s · %s", -- 1 sale, 2 sales
		totalSoFar = "Total so far",
		total = "Total",
		charge = "CHARGE %s",
		cardType = "Type this on the card machine 👉",
		gave = "They gave %s",
		cashTotal = "Total %s",
		giveBack = "Give back",
		givingOf = "Giving %s of %s",
		drawer = "👇 drawer",
		give = "GIVE CHANGE",
		keypadLabel = "CARD · AMOUNT",
		-- the card machine asleep (owner 2026-11-19: "make the card machine unusable when it's not supposed to be used")
		keypadOff = "💳 💤",
		keypadOffHint = "Wakes up when someone pays by card",
		keypadType = "TYPE %s",
		exact = "✔️ EXACT!",
		more = "+ %d more",
	},
	-- The screen's colours (a dark POS screen: a lilac bar, butter for what to do now, mint for done)
	SCREEN_COLORS = {
		back = { 28, 30, 44 },
		panel = { 38, 42, 60 },
		ink = { 240, 242, 250 },
		soft = { 167, 174, 200 },
		barFrom = { 122, 82, 224 },
		barTo = { 162, 116, 255 },
		now = { 255, 201, 63 },
		nowInk = { 58, 42, 0 },
		done = { 47, 77, 64 },
		doneInk = { 95, 224, 164 },
		go = { 95, 224, 164 },
		goInk = { 18, 48, 31 },
		off = { 74, 79, 102 },
		bad = { 255, 120, 130 },
		gold = { 58, 47, 18 },
	},
	-- Leave, at the top-left corner below Roblox's buttons, clear of the drawer and the card machine. In the soft
	-- cotton candy look with an icon and its key in a white circle, like the HUD's tiles (owner 2026-11-21: "make
	-- this LEAVE button in cashier consistent with the rest of the buttons. and add a hotkey"): `icon` (Config/UIIcons,
	-- turned to point left) and `key`, which leaves too (RegisterStationRules.leaveKey). The key was X in a white
	-- circle on the button's corner, which read as a close button (owner 2026-11-21: "hotkey X look like a close ...
	-- change the design so that the X will not look like close button"): now L for Leave, drawn as a square keyboard
	-- key (`cap` px, with a lip) inside the button after the word
	LEAVE_PILL = { x = 16, y = 64, width = 176, height = 52, icon = "Next", key = "L", cap = 26 },
	-- The drawer's pictures (tools/ui-art/make_money.py, assets/ui/money; our own play money, uploaded 2026-11-16)
	MONEY_IMAGES = {
		-- notes: the portrait drawer notes (drawer_<cents>.png: lying lengthwise, the value huge and upright)
		[2000] = "rbxassetid://118928129916715",
		[1000] = "rbxassetid://115663991659645",
		[500] = "rbxassetid://73348385105758",
		[100] = "rbxassetid://80710123230198",
		[25] = "rbxassetid://117179753203365",
		[10] = "rbxassetid://83644348253275",
		[5] = "rbxassetid://114737860492723",
		[1] = "rbxassetid://122188690103546",
	} :: { [number]: string },
	-- Each note's and coin's colour (their pictures' own: tools/ui-art/make_money.py), for the stack under the picture
	MONEY_COLORS = {
		[2000] = { 244, 140, 82 },
		[1000] = { 158, 112, 236 },
		[500] = { 82, 162, 236 },
		[100] = { 92, 196, 132 },
		[25] = { 244, 196, 72 },
		[10] = { 206, 212, 224 },
		[5] = { 186, 198, 214 },
		[1] = { 212, 128, 78 },
	} :: { [number]: { number } },
	-- Coins' sizes against the cup (the quarter biggest, the dime smallest, like real ones)
	COIN_SIZES = { [25] = 0.86, [10] = 0.66, [5] = 0.76, [1] = 0.7 } :: { [number]: number },
	NOTE_STACK = 3, -- notes in each compartment's little stack
	NOTE_ASPECT = 352 / 512, -- a drawer note's width over its length (its picture's)
	NOTE_ROW = 0.58, -- the notes' share of the drawer's depth (the coins take the rest)
	COIN_STACK = 3,
	-- The change guide (owner 2026-11-20: "can we just add a permanent guide/highlight for the change/give back? some
	-- kids doesnt do well with math"; it showed after 5 s stuck, owner 2026-11-16): the next note or coin to give glows
	-- gold from the moment the customer pays, a pointer bobbing over it (Util/RegisterStationRules nextPiece, guideOn).
	-- Following it always lands on the exact change
	HELPER_SECONDS = 0,
	-- the pointer: a gold pill over the glowing stack on your screen saying how many taps of it are left ("Tap 3x",
	-- then "Tap 2x", "Tap 1x": owner 2026-11-20, "so that kids will understand it more"; RegisterStationRules
	-- .tapsLeft; `text` takes the count); px wide and tall, studs up the screen from the stack and `toward` the
	-- camera, its bob and its seconds; it pops to `pop` times its size when the count changes
	HELPER_TAG = { text = "Tap %dx", width = 112, height = 40, lift = 0.5, toward = 0.5, bob = 0.14, seconds = 0.45, pop = 1.25, ink = { 60, 32, 12 } },
	-- A sale while you man the register (owner 2026-11-16: "money should be visible while I'm using cash register. with
	-- immersive animation/effects when someone buys something. the same with exp"; mockup approved): the screen flashes
	-- "SOLD! +$12.50" for `soldSeconds`, coins (`coins` fewest and most: more for a bigger sale, RegisterStationRules
	-- .saleCoins) burst out of the register and fly `flySeconds` each, `stagger` apart, arcing `lift` px up, into your
	-- cash pill, which counts up as they land; the XP sparks start from the register too (Util/SaleOrigin). Pixels.
	SALE_FX = {
		soldSeconds = 1.6,
		soldWords = "SOLD! +%s",
		coins = { 4, 12 },
		flySeconds = 0.75,
		stagger = 0.06,
		lift = 140,
		coinSize = 44,
		spread = 70, -- px the coins burst out to before they fly
		rollSeconds = 0.45, -- the cash pill's count-up
		soldColor = { 87, 211, 154 },
	},
	HELPER_COLOR = { 255, 201, 63 },
}
