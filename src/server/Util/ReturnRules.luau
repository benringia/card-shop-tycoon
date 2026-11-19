--!strict
-- A customer who leaves without paying puts their stock back (CustomerService.restoreItems: a haggle turned down, a
-- given-up wait). The shelf it came from may be gone, full or holding something else by then, so the units go to the
-- owner's other shelves of that product (the service's loop: PlacementService.AddStock takes what fits) and what fits
-- nowhere is paid back at what it cost: nothing is ever lost. Pure, Lune-tested.
local ReturnRules = {}

type Product = { boxCost: number, unitsPerBox: number, marketPrice: number, bulk: boolean? }

-- The cash for units that fit nowhere: what they cost wholesale; a Bulk Bin's handful (never bought) at its price
function ReturnRules.refund(product: Product?, units: number): number
	if not product or units <= 0 then
		return 0
	end
	local each = if product.bulk or product.unitsPerBox <= 0 then product.marketPrice else product.boxCost / product.unitsPerBox
	return math.round(each * units * 100) / 100
end

return ReturnRules
