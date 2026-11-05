--!strict
-- Customer types (spec 2026-11-06-customers-design): which type walks in (Config/Customers TYPES, TYPE_ORDER) and
-- whether a type buys at a price. Pure (Lune-tested): the price bands come in as an argument (Config/Pricing
-- BUY_BANDS), since a pure module can't require its siblings.
local CustomerTypes = {}

export type Context = { hasShowcase: boolean, shopLevel: number }
export type Band = { maxRatio: number, chance: number }

local function allowed(spec: any, context: Context): boolean
	if spec.needsShowcase and not context.hasShowcase then
		return false
	end
	return spec.minLevel == nil or context.shopLevel >= spec.minLevel
end

-- The type of the next customer for a roll in [0, 1): the types this shop can have, by weight, in TYPE_ORDER
function CustomerTypes.pick(cfg: any, context: Context, roll: number): string
	local total = 0
	for _, kind in cfg.TYPE_ORDER do
		local spec = cfg.TYPES[kind]
		if allowed(spec, context) then
			total += spec.weight
		end
	end
	local left = math.clamp(roll, 0, 0.999999) * total
	local last = "plain"
	for _, kind in cfg.TYPE_ORDER do
		local spec = cfg.TYPES[kind]
		if allowed(spec, context) then
			last = kind
			left -= spec.weight
			if left < 0 then
				return kind
			end
		end
	end
	return last
end

-- How many price bands higher than a plain customer this type still buys in
function CustomerTypes.tolerance(cfg: any, kind: string): number
	local spec = cfg.TYPES[kind]
	return if spec and spec.tolerance then spec.tolerance else 0
end

-- The band a price falls in for this type: its index in `bands` (past the last band, more bands follow as wide as the
-- last one), shifted `tolerance` bands cheaper; past the last band means it won't buy
local function shiftedBand(cfg: any, kind: string, price: number, market: number, bands: { Band }): number
	if market <= 0 or #bands == 0 then
		return #bands + 1
	end
	local ratio = price / market
	local index: number? = nil
	for i, band in bands do
		if ratio <= band.maxRatio + 1e-9 then
			index = i
			break
		end
	end
	if not index then
		local last = bands[#bands].maxRatio
		local width = last - (if #bands > 1 then bands[#bands - 1].maxRatio else 0)
		index = #bands + math.max(1, math.ceil((ratio - last) / math.max(width, 1e-6) - 1e-9))
	end
	return math.max(1, (index :: number) - CustomerTypes.tolerance(cfg, kind))
end

-- Whether this type won't buy at all at `price` (past its last band): the annoyed bubble
function CustomerTypes.outOfReach(cfg: any, kind: string, price: number, market: number, bands: { Band }): boolean
	return shiftedBand(cfg, kind, price, market, bands) > #bands
end

-- Whether this type buys at `price` against `market`: its shifted band's chance (raised by a perk) against roll
function CustomerTypes.buys(cfg: any, kind: string, price: number, market: number, roll: number, perkBonus: number, bands: { Band }): boolean
	local band = bands[shiftedBand(cfg, kind, price, market, bands)]
	if not band then
		return false
	end
	return band.chance * (1 + perkBonus) > roll
end

return CustomerTypes
