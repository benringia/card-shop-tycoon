--!strict
-- Timed station upgrades (owner 2026-11-12: "forge, condenser, and grading station should have a waiting time on
-- upgrades, the higher the upgrade the longer wait time. also with an option to pay robux for instant upgrade"; his
-- picks: waits up to 1 hour, crafting the longest; spec 2026-11-12-timed-upgrades-revive-design). Seconds. Plain data.
return {
	WAITS = {
		star = { 30, 120, 360, 900, 1800 }, -- the Condenser, to 1 star ... 5 stars
		grade = { B = 60, A = 480, S = 1500 }, -- the Grading Station, to that grade
		level = { 15, 30, 60, 120, 240, 420, 600, 900, 1320, 1800 }, -- the Forge's Upgrade, to +1 ... +10
		reforge = 1200,
		craft = 3600, -- making a weapon: the longest (owner: "I think crafting needs the longest")
	},
	-- "Finish now" (Robux developer products SkipS / SkipM / SkipL, Config/Monetization PRODUCTS): the tier a job's time
	-- left falls in
	-- a finished Forge job while the Forge is closed (owner 2026-11-12: "the cinematic should only appear when I open
	-- forge. only add the notification when its done and the forge is not open"; ForgeController)
	FORGE_READY = "Your {name} is ready! Open the Forge to see it.",
	-- a finished Condenser job: its card is back in your binder, and its new star waits to be shown until you open
	-- the Condenser (owner 2026-11-20: "I need a better notification inside the condenser after the timer is done, that
	-- is waiting for me to reopen the condenser"; CondenserService, CondenserController)
	CONDENSER_READY = "{name} is ready! Open the Condenser to take it out.",
	GRADING_READY = "{name} is ready! Open the Grading Station to take it out.",
	-- The reveal in a station's window (client Util/DoneReveal): the card `face` px, its new star or grade popping in
	-- `delay` seconds after it shows over `pop` seconds with a soft bell (Pro Sound Effects "Synth Sparkle Tone High
	-- Pitch Bell Tone Ding 4", one of the summon's vetted options), and its button
	REVEAL = {
		button = "Take it out",
		delay = 0.45,
		pop = 0.4,
		ding = { id = "rbxassetid://9126073001", volume = 0.3, pitch = 0.9 },
		width = 340,
		height = 396,
		face = { 115, 164 },
	},
	-- What says "Ready!" over a machine (StationTimerController): the player attribute a finished job leaves
	READY_ATTRIBUTES = { condenser = "CondenserDone", grading = "GradingDone", forge = "ForgeDone" },
	TIERS = { { name = "S", upTo = 300 }, { name = "M", upTo = 1200 }, { name = "L", upTo = 3600 } },
	STATIONS = { condenser = "Condenser", grading = "Grading Station", forge = "Forge" },
}
