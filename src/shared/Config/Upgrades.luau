--!strict
-- Timed station upgrades (owner 2026-11-12: "forge, condenser, and grading station should have a waiting time on
-- upgrades, the higher the upgrade the longer wait time. also with an option to pay robux for instant upgrade"; his
-- picks: waits up to 1 hour, crafting the longest; spec 2026-11-12-timed-upgrades-revive-design). Seconds. Plain data.
return {
	WAITS = {
		star = { 30, 120, 360, 900, 1800 }, -- the Condenser, to 1 star ... 5 stars
		-- the Grading Station, to that grade: 10 min, 30 min, 1 h for a Very Rare (owner 2026-11-20: "Grading a
		-- rare/stronger card should take 45mins to hours"; 1 min, 8 min, 25 min before). With its rarity: a Common 5 /
		-- 15 / 30 min, a Rare 7.5 / 22 / 45, an Epic 15 / 45 / 90, a Legendary 20 min / 1 h / 2 h
		grade = { B = 600, A = 1800, S = 3600 },
		level = { 15, 30, 60, 120, 240, 420, 600, 900, 1320, 1800 }, -- the Forge's Upgrade, to +1 ... +10
		reforge = 1200,
		craft = 3600, -- making a weapon: the longest (owner: "I think crafting needs the longest")
	},
	-- The rarer the card or weapon, the longer every wait (owner 2026-11-20: "adjust upgrade times. the rarer/stronger
	-- the item the longer the wait time for upgraade"): WAITS times its rarity's factor (the tables are a Very Rare's),
	-- in whole seconds, never over MAX_WAIT. A Common's first star takes 15 s, a Legendary's fifth 1 hour, crafting a
	-- Legendary weapon 2 hours. The stronger the upgrade the longer, as before (the tables). UpgradeRules.seconds.
	RARITY_TIMES = { Common = 0.5, Rare = 0.75, ["Very Rare"] = 1, Epic = 1.5, Legendary = 2 },
	MAX_WAIT = 7200,
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
