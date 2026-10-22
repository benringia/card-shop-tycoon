--!strict
-- Binder pages and spreads (pure, Lune-tested). Spread 1 is the set's cover on the left and page 1 on the
-- right; every later spread is two pages of pockets.
local BinderSpreads = {}

function BinderSpreads.pages(cardCount: number, pocketsPerPage: number): number
	if cardCount <= 0 then
		return 0
	end
	return math.ceil(cardCount / pocketsPerPage)
end

function BinderSpreads.count(cardCount: number, pocketsPerPage: number): number
	local after = math.max(0, cardCount - pocketsPerPage)
	return 1 + math.ceil(after / (pocketsPerPage * 2))
end

-- The card indexes a spread shows (first > last when it shows none)
function BinderSpreads.cards(spread: number, cardCount: number, pocketsPerPage: number): (number, number)
	if spread <= 1 then
		return 1, math.min(pocketsPerPage, cardCount)
	end
	local first = pocketsPerPage + (spread - 2) * pocketsPerPage * 2 + 1
	return first, math.min(first + pocketsPerPage * 2 - 1, cardCount)
end

-- "1 / 14" on the cover spread, "2-3 / 14" after (one number when the last spread has one page)
function BinderSpreads.label(spread: number, totalPages: number): string
	if totalPages <= 0 then
		return "0 / 0"
	end
	if spread <= 1 then
		return `1 / {totalPages}`
	end
	local left = spread * 2 - 2
	local right = math.min(spread * 2 - 1, totalPages)
	if right <= left then
		return `{left} / {totalPages}`
	end
	return `{left}-{right} / {totalPages}`
end

return BinderSpreads
