--!strict
-- PvP challenges and the arena (battles part 2 spec). Plain data only (positions are { x, y, z } tables) so
-- Lune tests can load this file.
return {
	-- PvP opens in the first update, a week after launch (owner 2026-11-13: "I need to put on alot of planning to make
	-- the pvp good"): while false the plaza Arena portal says SOON instead of taking you to the stands, the Challenge
	-- prompt isn't made (ChallengeController) and the server refuses challenges (ArenaService); the duel titles still
	-- show. Studio's /arena still goes to the stands.
	OPEN = false,
	SOON = {
		sign = "Coming soon",
		title = "Coming soon!",
		icon = "⚔️",
		text = "The Arena opens in our first update: duel other players with your creatures!",
	},
	CHALLENGE_DISTANCE = 8, -- studs between the players for the Challenge prompt (and the server check)
	CHALLENGE_SECONDS = 15, -- the target has this long to answer
	CHALLENGE_COOLDOWN = 10, -- seconds between challenges from one player
	DECLINE_BLOCK_SECONDS = 30, -- after a decline, that pair can't challenge again for this long
	CAP_PER_LEVEL = 25, -- bet cap = this x the lower shop level (and never more than either player's cash)
	BET_STEP = 5,
	BET_PRESETS = { 0, 10, 25, 50 }, -- 0 = Friendly
	RETURN_SECONDS = 10, -- after the result, both go home
	COUNTDOWN_SECONDS = 3, -- 3, 2, 1, FIGHT! once both players are on the pad
	ACTION_COOLDOWN = 0.5, -- remote rate limit

	-- The arena: one pad, far from the plots and the wild
	ARENA_ORIGIN = { x = 0, y = 0, z = -1200 },
	WATCH_RADIUS = 60, -- studs from the arena's centre: players this close see the fight's attacks (Remotes.ArenaWatch)
	ARENA_PORTAL = { x = -205, y = 0, z = 0 }, -- at the end of Ember Canyon, west of town (Town.PORTAL_AREAS)
	PAD_SIZE = 40, -- studs across
	SPAWN_OFFSET = 14, -- each player stands this far from the pad centre, on opposite sides
	LEASH_RADIUS = 18, -- players may roam this far from their spawn spot during a fight
	CREATURE_SPACING = 4, -- studs between a player's creatures in their line
	POWER_REFRESH_SECONDS = 2, -- how often each player's PartyPower attribute is refreshed
}
