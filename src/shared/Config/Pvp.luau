--!strict
-- PvP challenges and the arena (battles part 2 spec). Plain data only (positions are { x, y, z } tables) so
-- Lune tests can load this file.
return {
	CHALLENGE_DISTANCE = 8, -- studs between the players for the Challenge prompt (and the server check)
	CHALLENGE_SECONDS = 15, -- the target has this long to answer
	CHALLENGE_COOLDOWN = 10, -- seconds between challenges from one player
	DECLINE_BLOCK_SECONDS = 30, -- after a decline, that pair can't challenge again for this long
	CAP_PER_LEVEL = 50, -- bet cap = this x the lower shop level (and never more than either player's cash)
	BET_STEP = 5,
	BET_PRESETS = { 0, 10, 25, 50 }, -- 0 = Friendly
	RETURN_SECONDS = 10, -- after the result, both go home
	COUNTDOWN_SECONDS = 3, -- 3, 2, 1, FIGHT! once both players are on the pad
	ACTION_COOLDOWN = 0.5, -- remote rate limit

	-- The arena: one pad, far from the plots and the wild
	ARENA_ORIGIN = { x = 0, y = 0, z = -1200 },
	ARENA_PORTAL = { x = -104, y = 0, z = 0 }, -- plaza: the other end of the street from the wild portal
	PAD_SIZE = 40, -- studs across
	SPAWN_OFFSET = 14, -- each player stands this far from the pad centre, on opposite sides
	LEASH_RADIUS = 18, -- players may roam this far from their spawn spot during a fight
	CREATURE_SPACING = 4, -- studs between a player's creatures in their line
	POWER_REFRESH_SECONDS = 2, -- how often each player's PartyPower attribute is refreshed
}
