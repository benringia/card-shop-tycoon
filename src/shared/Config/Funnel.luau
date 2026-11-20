--!strict
-- The new player's first session as Roblox's onboarding funnel (server Util/Funnel; Creator Hub -> Analytics ->
-- Funnels): each step logged once, numbered by its place here (owner 2026-11-17: track where Friday's playtesters quit).
-- Pish's tour steps (Config/Pish STEPS) sit in his order after the welcome flight; LEVELS are shop levels logged as
-- "Level<n>" the first time the shop reaches them. Plain data (tests/Funnel).
return {
	ONBOARDING = {
		"Joined", -- a new save loaded (the prologue not seen yet)
		"PrologueStarted",
		"PrologueFight", -- the Hydra fight with the lent cards
		"PrologueTaken", -- the Hydra took the cards
		"PrologueDone", -- woke in town (or skipped in act 3)
		"WelcomeFlightDone", -- right after PrologueDone since the flight went (2026-11-20); kept so the steps don't renumber
		-- Pish's tour (Config/Pish STEPS, in order)
		"giftPack",
		"summonPal",
		"buildRack",
		"orderStock",
		"stockRack",
		"customer",
		"ringUp",
		"gift",
		"bye",
		-- on their own
		"FirstWildWin",
		"Level3",
		"FirstQuestClaimed",
		"Level5",
		"Level8", -- the first job slot (the cashier)
		"Level10",
	},
	LEVELS = { 3, 5, 8, 10 },
}
