--!strict
-- Card Condenser: combines duplicates of a card into one main copy for +1 star.
-- Star costs live in Config/Beasts (STAR_COSTS); which copies are used is in Util/CondenseRules.
return {
	ACTION_COOLDOWN = 0.5, -- seconds between condense requests per player (server)
	USE_DISTANCE = 12, -- studs: how close the owner must stand to use it (server check, panel closes past it)
	IN_FLIGHT_TIMEOUT = 2, -- seconds the Condense button stays locked waiting for the server (client)
}
