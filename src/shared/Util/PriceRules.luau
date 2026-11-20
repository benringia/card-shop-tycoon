--!strict
-- Price rules shared by the pricing UI (hints) and the server (validation, customer decisions).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PricingConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pricing"))
local CustomerTypes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("CustomerTypes"))

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

-- The chance a plain customer buys at this price: it slides inside a band (Config/Pricing BUY_BANDS,
-- CustomerTypes.chance), so use this, never a band's own `chance`
function PriceRules.getChance(price: number, marketPrice: number): number
	return CustomerTypes.plainChance(price, marketPrice, PricingConfig.BUY_BANDS)
end

-- The Prices window's short words for this price ("Always buy", "33% buy", "Won't buy")
function PriceRules.getTag(price: number, marketPrice: number): string
	return CustomerTypes.priceTag(price, marketPrice, PricingConfig.BUY_BANDS, PricingConfig.NEVER_TAG)
end

return PriceRules
