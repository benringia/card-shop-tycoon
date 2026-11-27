--!strict
-- What now? hints (spec 2026-11-27-what-now-hints-design; owner 2026-11-27: "never let a player go idle", look 1): a
-- player who has done nothing for a while gets one tip, Pish's face and words in a white bubble on the gold arrow that
-- points at the one best next thing (client HintController and Util/HintBubble, Util/HintRules). Seconds and px.
local Hints = {}

-- Checked in this order; the first that's true is the tip (HintRules.holds says when each is)
Hints.ORDER = { "register", "claim", "stock", "order", "station", "build", "packs", "boss", "quest", "hunt" }

-- What Pish says (the quest tip's words are the quest itself: QuestRemind.words). Plain ASCII and ·, 46 characters at
-- most once a count or a name is in
Hints.WORDS = {
	register = "Customers are waiting! Ring them up.",
	claim = { one = "A quest is done! Claim it.", many = "%d quests are done! Claim them." },
	stock = "Put your box on a shelf!",
	order = "Order packs to sell!",
	station = { Condenser = "Your new star is ready! Take it out.", GradingStation = "Your graded card is ready! Take it out." },
	build = "You can build the %s!",
	packs = { one = "Open your pack!", many = "Open your %d packs!" },
	boss = { ready = "You're strong enough for the %s!", loot = "The %s's loot is ready!" },
	hunt = "Hunt monsters in the Wild!",
}

Hints.FIRST = 60 -- never in the first minute after joining
Hints.IDLE = 30 -- stood still this long
Hints.LOST = 120 -- or this long with nothing earned (cash and XP unchanged), walking around or not
Hints.GAP = 120 -- between two tips
Hints.REPEAT = 300 -- the same tip not again sooner (its x mutes it for the session)
Hints.SHOW = 20 -- a tip stays this long
Hints.WALK_SHOW = 45 -- a tip to walk to (the Wild portal, a boss's portal)
Hints.SPOT_HEIGHT = 9 -- studs over the ground the arrow over a spot in the world hangs

-- The bubble (Util/HintBubble, HintRules.bubbleAt): `gap` from the arrow, `margin` inside the screen, its `height`,
-- Pish's `face`, the words' `text` size, the x's look and its finger-sized `tap` area
Hints.BUBBLE = { gap = 6, margin = 8, height = 46, face = 36, text = 18, x = 26, tap = 48 }
-- Pish's sticker (Config/HudMascot's peek picture: the HUD's mascot can change, the guide stays Pish)
Hints.FACE = "rbxassetid://125657246581399"

return Hints
