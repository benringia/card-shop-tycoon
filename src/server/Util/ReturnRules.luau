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

-- The owner's toast after a deal turned down (owner 2026-11-19: "when I decline a bargainer. add an indication that
-- the cards were back on the shelves"): what went back on the shelves, each product once, at most `most` names; nil
-- when nothing did (all of it refunded: returnStock's own toast says so)
ReturnRules.WORDS = { lead = "Back on your shelves: ", more = " and more", most = 3, pop = "+%d back" }

function ReturnRules.backLine(stock: { { name: string, units: number } }, cards: number): string?
	local order: { string } = {}
	local units: { [string]: number } = {}
	for _, entry in stock do
		if entry.units > 0 then
			if not units[entry.name] then
				table.insert(order, entry.name)
			end
			units[entry.name] = (units[entry.name] or 0) + entry.units
		end
	end
	local parts: { string } = {}
	for _, name in order do
		table.insert(parts, `{units[name]} {name}`)
	end
	if cards > 0 then
		table.insert(parts, if cards == 1 then "1 card" else `{cards} cards`)
	end
	if #parts == 0 then
		return nil
	end
	local words = ReturnRules.WORDS
	local shown = table.move(parts, 1, math.min(#parts, words.most), 1, {})
	return words.lead .. table.concat(shown, ", ") .. (if #parts > words.most then words.more else "")
end

-- The tag that pops over a shelf stock went back to
function ReturnRules.popText(units: number): string?
	return if units > 0 then string.format(ReturnRules.WORDS.pop, units) else nil
end

return ReturnRules
