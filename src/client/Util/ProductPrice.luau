--!strict
-- Developer products' Robux prices on this client, asked once each in the background (spec
-- 2026-11-12-timed-upgrades-revive-design): "Finish now · R$ 10" (Util/JobPanel), "Revive here · R$ 15"
-- (KnockoutController).
local MarketplaceService = game:GetService("MarketplaceService")

local ProductPrice = {}

local prices: { [number]: number } = {} -- product id -> Robux; -1 while asking or when it couldn't be read

-- A product's price in Robux, or nil while unknown (asked the first time; id 0 is a product not created yet)
function ProductPrice.of(productId: number): number?
	if productId == 0 then
		return nil
	end
	local known = prices[productId]
	if known then
		return if known > 0 then known else nil
	end
	prices[productId] = -1
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		prices[productId] = if ok and info and typeof(info.PriceInRobux) == "number" then info.PriceInRobux else -1
	end)
	return nil
end

return ProductPrice
