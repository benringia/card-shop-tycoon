--!strict
-- Developer products' Robux prices on this client, asked once each in the background (spec
-- 2026-11-12-timed-upgrades-revive-design): "Finish now · R$ 10" (Util/JobPanel), "Revive here · R$ 15"
-- (KnockoutController).
local MarketplaceService = game:GetService("MarketplaceService")

local ProductPrice = {}

local prices: { [string]: number } = {} -- "<kind>:<id>" -> Robux; -1 while asking or when it couldn't be read

local function priceOf(id: number, infoType: Enum.InfoType): number?
	if id == 0 then
		return nil
	end
	local key = `{infoType.Name}:{id}`
	local known = prices[key]
	if known then
		return if known > 0 then known else nil
	end
	prices[key] = -1
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id, infoType)
		end)
		prices[key] = if ok and info and typeof(info.PriceInRobux) == "number" then info.PriceInRobux else -1
	end)
	return nil
end

-- A product's price in Robux, or nil while unknown (asked the first time; id 0 is a product not created yet). Live,
-- because managed pricing can change it on Creator Hub
function ProductPrice.of(productId: number): number?
	return priceOf(productId, Enum.InfoType.Product)
end

-- A game pass's price in Robux, the same way (the Store's Extra Job Slot)
function ProductPrice.ofPass(passId: number): number?
	return priceOf(passId, Enum.InfoType.GamePass)
end

-- Calls `apply(price)` once the price is known: now when it's cached, else as soon as Roblox answers (looked at once a
-- second, `tries` times, default 10); never for id 0. For buttons drawn once (the Starter card, the Bag's Quick Open
-- offer, the Welcome back card's Night Shift row) that would otherwise keep their placeholder words
function ProductPrice.whenKnown(id: number, pass: boolean, apply: (price: number) -> (), tries: number?)
	if id == 0 then
		return
	end
	local read = if pass then ProductPrice.ofPass else ProductPrice.of
	local price = read(id)
	if price then
		apply(price)
		return
	end
	task.spawn(function()
		for _ = 1, tries or 10 do
			task.wait(1)
			local known = read(id)
			if known then
				apply(known)
				return
			end
		end
	end)
end

return ProductPrice
