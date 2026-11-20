--!strict
-- Weekly events (owner 2026-11-19: "suggest a recurring scheduled events", then "build the weekend events"): the same
-- every week on UTC days, so nobody has to run them; each boosts something the game already has, nothing is sold, and a
-- missed day comes back next week. DAYS by weekday (1 Monday .. 7 Sunday; Util/EventRules). The proposed weekdays
-- (Market Monday, Wild Wednesday, Forge Friday) and the Rush Hour aren't built yet. Plain data: tests/EventRules.
--   lootCooldown: a boss's loot timer times this (Bosses.LOOT_COOLDOWN; BossService)
--   chestMaterial: more of its material in the boss chest you pick (BossChestService)
--   luck: free luck once that day, its time added like a gift's (LuckService.Give; EventService)
--   line: what it does (the chip's tooltip); toast: said once when you arrive or the day turns
export type Event = {
	id: string,
	name: string,
	icon: string, -- a Config/UIIcons name or an emoji
	line: string,
	toast: string,
	again: string?, -- the toast when its luck was given earlier today
	board: string?, -- the Boss Ladder's line while it's on (BossBoardController)
	note: string?, -- a boss win's victory note while it's on (VictoryRules.notes)
	lootCooldown: number?,
	chestMaterial: number?,
	luck: { strength: string, seconds: number }?,
}

local DAYS: { [number]: Event } = {
	[6] = {
		id = "bossRush",
		name = "Boss Rush",
		icon = "Trophy",
		line = "Boss loot twice as fast, and 1 more material in boss chests.",
		toast = "🏆 Boss Rush today! Boss loot twice as fast, +1 material in boss chests.",
		board = "Boss Rush today: loot twice as fast, +1 material in chests",
		note = "Boss Rush: loot twice as fast today",
		lootCooldown = 0.5,
		chestMaterial = 1,
	},
	[7] = {
		id = "luckySunday",
		name = "Lucky Sunday",
		icon = "🍀",
		line = "30 minutes of free 2x Luck on your packs when you start playing.",
		toast = "🍀 Lucky Sunday! You got 30 minutes of free 2x Luck on your packs.",
		again = "🍀 Lucky Sunday! Today's free 2x Luck is already yours.",
		luck = { strength = "x2", seconds = 30 * 60 },
	},
}

return {
	DAYS = DAYS,
	CHECK_SECONDS = 20, -- how often the server looks at the day (a new day's toast, Sunday's luck)
	JOIN_DELAY = 12, -- seconds after your save loads before the day's toast (past the loading screen)
	-- The chip under the quests (EventController; computers only, CompactHud.phonePieces): gold while an event is on,
	-- plain while it counts down to the next; `tip`: its tooltip's last line; `minScreen`: on a window shorter than
	-- this the chip would sit on the cash and weapon corner (the quests, Turts' chip and it reach 380 px down; the
	-- corner starts 160 px from the bottom: 540 in all), so it stays away
	-- `soon`: the chip shows on an event's day and from this many seconds before it (owner 2026-11-21, "I want to clean
	-- up": "Next: Boss Rush in 1d 2h" was nothing to act on; EventRules.chipShown)
	CHIP = { height = 30, icon = 22, textSize = 14, gap = 6, tip = "It comes back every week.", minScreen = 550, soon = 3600 },
}
