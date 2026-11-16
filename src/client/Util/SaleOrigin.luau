--!strict
-- Where a sale's coins and shop XP sparks start on screen (viewport pixels): the register's screen while you man it
-- (owner 2026-11-16: "money should be visible while I'm using cash register ... the same with exp"; your character is
-- hidden in first person, so they can't start from it). RegisterStationController sets it while manned; the shop XP
-- sparks (PartyBarController) and the coins (Util/CoinBurst) read it. Nil: they start from you as before.
local SaleOrigin = {}

local provider: (() -> Vector2?)? = nil

function SaleOrigin.set(get: (() -> Vector2?)?)
	provider = get
end

function SaleOrigin.get(): Vector2?
	return if provider then provider() else nil
end

return SaleOrigin
