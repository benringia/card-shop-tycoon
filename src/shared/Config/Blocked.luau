--!strict
-- The locked card and locked prompts (client BlockedController; owner 2026-11-12: "let the player know what the
-- requirements are ... apply this to the entire game")
return {
	ICON = "🔒",
	TITLE = "Not yet!",
	BACK = { 30, 20, 40 },
	EDGE = { 255, 120, 110 },
	SECONDS = 3.5, -- how long the card stays
	REPEAT_SECONDS = 1.5, -- the same refusal again within this: no second card
	SOUND = { id = "rbxassetid://9116223893", volume = 0.35, pitch = 0.7 }, -- the objective chime, low: a soft "no"
	-- An answer, not a refusal (Blocked.tell's tone "info": the healing spring's "How it works"): the same card with a
	-- water-blue edge and title, no shake, the chime at its own pitch
	INFO = { EDGE = { 110, 205, 255 }, SOUND = { id = "rbxassetid://9116223893", volume = 0.3, pitch = 1.25 } },
	PROMPT_ACTION = "Locked",
	PROMPT_OBJECT = "🔒 Shop level {level} needed",
}
