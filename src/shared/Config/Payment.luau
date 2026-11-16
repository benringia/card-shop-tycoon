--!strict
-- The register's payment step (owner 2026-11-16: "can we make an immersive cashier system? where players go into the
-- cashier and type/click the actual total and change of the customer? like TCG Card Shop Simulator"). After Charge the
-- customer pays: by card (you type the total on the card machine) or cash (they hand over the next bill up and you
-- count the change out of the drawer). Plain data, read by Util/PaymentRules (Lune-tested), RegisterService (checks
-- every answer) and RegisterStationController (the register in first person: Config/RegisterStation). Money is in
-- whole cents.
return {
	-- the chance a customer pays by card (the rest pay cash), by type (Config/Customers TYPES)
	CARD_CHANCE = { default = 0.5, kid = 0.25, bigSpender = 0.85 } :: { [string]: number },
	BILLS = { 500, 1000, 2000, 5000, 10000 }, -- the customer hands over the smallest of these above the total
	BIG_ROUND = 5000, -- past the biggest bill: the total rounded up to the next $50 above it
	DRAWER = { 2000, 1000, 500, 100, 25, 10, 5, 1 }, -- what you give change in, bills then coins
	MAX_PIECES = 40, -- the most bills and coins one answer may hold
	MAX_TYPED = 8, -- characters the card machine takes ("12345.67")
	ANSWER_COOLDOWN = 0.3, -- seconds between answers per player
	HOLD_SECONDS = 1, -- while you pay, the customer's patience is topped up this often (a slow count never loses a sale)
	-- what the register's screen says to a wrong answer
	LINES = {
		wrongCard = "That's not the total. Check the register!",
		short = "Not enough change yet.",
		over = "That's too much! Tap some to take it back.",
	},
}
