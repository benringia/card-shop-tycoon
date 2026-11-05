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

-- Whether this type buys at `price` against `market`: its band (past the last band counts as one more), shifted
-- `tolerance` bands cheaper; past the last band it never buys, else the band's chance (raised by a perk) against roll
function CustomerTypes.buys(cfg: any, kind: string, price: number, market: number, roll: number, perkBonus: number, bands: { Band }): boolean
	if market <= 0 then
		return false
	end
	local ratio = price / market
	local index = #bands + 1
	for i, band in bands do
		if ratio <= band.maxRatio + 1e-9 then
			index = i
			break
		end
	end
	index = math.max(1, index - CustomerTypes.tolerance(cfg, kind))
	local band = bands[index]
	if not band then
		return false
	end
	return band.chance * (1 + perkBonus) > roll
end

return CustomerTypes
