--!strict
-- The loading screen on join and during teleports ("card fan", option C): three cards fanning out over a slim gold bar
-- and the step it's on, until the character, the save, the summoned creature and the fight gear are ready
-- (ReplicatedFirst/LoadingScreen shows it, Controllers/LoadingController drives it, Util/LoadingRules decides).
-- Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	TITLE = "Cardshop Simulator",
	FAN_CARDS = { "Infernox", "Solarion", "Abyssal Koi" }, -- card paintings (Config/CardArt SMALL), left to right
	FAN_DEGREES = 24, -- how far the side cards swing out
	FAN_SECONDS = 1.6, -- one swing out (then back)
	BACKGROUND = { top = rgb(27, 42, 74), bottom = rgb(13, 20, 36) },
	CARD_EDGE = rgb(255, 210, 122),
	BAR_COLOR = rgb(255, 210, 122),
	NOTE_COLOR = rgb(255, 210, 122),
	-- Steps in order: the character, the save, the summoned creature, the fight gear (art, sounds, moves)
	FIRST_STEP = { Main = "Opening your shop...", Frontier = "Opening the Frontier...", Dungeon = "Opening the Dungeon..." },
	STEPS = { "Getting everything ready...", "Loading your cards...", "Waking up your creature...", "Getting the fight gear ready..." },
	READY = "Ready!",
	SLOW_SECONDS = 6, -- the save still loading after this: say why
	SLOW_NOTE = "Your save is still closing on another server, almost there!",
	MAX_SECONDS = 30, -- fades anyway after this, so nobody is stuck
	FADE_SECONDS = 0.6,
	TIP_SECONDS = 4, -- each tip shows this long
	TIPS = {
		"Tip: dodge when the ground glows!",
		"Tip: higher stars make your creature's perk stronger.",
		"Tip: swap creatures to change your fight perk.",
		"Tip: grade S cards are worth the most.",
	},
}
