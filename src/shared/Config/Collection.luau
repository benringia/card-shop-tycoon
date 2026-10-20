--!strict
-- Binder and quick sell. See DESIGN.md section 5.6.
return {
	QUICK_SELL_RATE = 0.7, -- fraction of market value paid when selling a card back
	MIN_SELL_PRICE = 0.01,
	SELL_COOLDOWN = 0.1, -- seconds between sell requests per player
	REQUEST_COOLDOWN = 2, -- seconds between "send me my collection" requests
}
