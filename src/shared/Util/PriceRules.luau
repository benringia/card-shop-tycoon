--!strict
-- Price rules shared by the pricing UI (hints) and the server (validation, customer decisions).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PricingConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pricing"))

export type Band = typeof(PricingConfig.BUY_BANDS[1])

local EPSILON = 1e-6

local PriceRules = {}

function PriceRules.getDefault(marketPrice: number): number
	return math.round(marketPrice * PricingConfig.DEFAULT_MARKUP * 100) / 100
end

-- Rounds to cents and keeps the price inside the allowed range
function PriceRules.clamp(price: number, marketPrice: number): number
	local rounded = math.round(price * 100) / 100
	return math.clamp(rounded, PricingConfig.MIN_PRICE, marketPrice * PricingConfig.MAX_MARKUP)
end

-- The buy band for this price, or nil when customers won't buy at all
function PriceRules.getBand(price: number, marketPrice: number): Band?
	local ratio = price / marketPrice
	for _, band in PricingConfig.BUY_BANDS do
		if ratio <= band.maxRatio + EPSILON then
			return band
		end
	end
	return nil
end

return PriceRules
