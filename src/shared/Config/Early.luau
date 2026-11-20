--!strict
-- The early game never makes you wait (owner 2026-11-20: "optimize early game, players should NOT wait for something
-- in early game"; Util/EarlyRules). While a shop is new (the same window as its customer boost, Config/Customers
-- NEW_SHOP: in full up to shop level `fullUntil`, fading to nothing by `goneAt`) its waits are short and grow to their
-- normal lengths. Plain data, Lune-tested.
return {
	fullUntil = 8,
	goneAt = 15,
	delivery = 3, -- seconds an order takes (Config/Stock DELIVERY_SECONDS later)
	rest = 60, -- seconds a fainted creature rests (Config/Combat REST_SECONDS later); the spring still triples it
	stationWait = 0.25, -- of a station's timer (Config/Upgrades WAITS: the Condenser, the Grading Station, the Forge)
}
