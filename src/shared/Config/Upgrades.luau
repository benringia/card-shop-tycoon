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
	TIERS = { { name = "S", upTo = 300 }, { name = "M", upTo = 1200 }, { name = "L", upTo = 3600 } },
	STATIONS = { condenser = "Condenser", grading = "Grading Station", forge = "Forge" },
}
