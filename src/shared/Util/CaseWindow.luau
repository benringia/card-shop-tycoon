--!strict
-- The card cases' window in words and sizes (owner 2026-11-21: "in glass cases make sure grades are noticeable too.
-- redesign glass cases window", his pick A of three mockups, "the case itself"; "also do the same for collector
-- case"; client ShowcaseController): every slot a big card with its grade across it, a yellow price tag under it and
-- two words on how it sells; one bar under them for the tapped card. Pure (Lune-tested: tests/CaseWindow).
local CaseWindow = {}

-- Pixels before the window's own scale
CaseWindow.LOOK = {
	most = 6, -- cards in a row
	gap = 10, -- between cards
	shape = 0.7, -- a card's width for its height
	under = 52, -- under a card: its price tag and its words
	minWidth = 56, -- a card is never narrower (six still stand in a row beside a phone's bar)
	wordsFrom = 70, -- a card this wide or wider has room for "GRADE S"; a narrower one wears the letter
	nearMarket = 1.5, -- a price up to this many times the card's worth is amber, over it red
}

-- "$3,000", "$1,200.50", "$2.50": commas in the thousands; under $1,000 always with cents, over it only when there
-- are some
function CaseWindow.money(amount: number): string
	local cents = math.round(amount * 100)
	local whole, part = cents // 100, cents % 100
	local digits = string.reverse((string.gsub(string.reverse(tostring(whole)), "(%d%d%d)", "%1,")))
	if string.sub(digits, 1, 1) == "," then
		digits = string.sub(digits, 2)
	end
	if whole >= 1000 and part == 0 then
		return `${digits}`
	end
	return string.format("$%s.%02d", digits, part)
end

-- The grade across a card `width` px wide: "GRADE S", or the letter alone where the words don't fit (LOOK.wordsFrom)
function CaseWindow.gradeWords(grade: string, width: number?): string
	return if width and width < CaseWindow.LOOK.wordsFrom then grade else `GRADE {grade}`
end

-- How a card sells at its price, and the colour to say it in ("good", "fair", "bad"; "hold": it waits for its price).
-- `kind`: the case's (Config/Shelves): "CustomerCards" shows `tag`, the Prices window's own words for this price
-- (PriceRules.getTag); "PlayerCards" the price against what the card is worth. `ratio`: price / worth
function CaseWindow.sells(kind: string, tag: string, ratio: number, held: boolean): (string, string)
	if held then
		return "Set its price", "hold"
	end
	local tone = if ratio <= 1 + 1e-6 then "good" elseif ratio <= CaseWindow.LOOK.nearMarket then "fair" else "bad"
	if kind == "CustomerCards" then
		return tag, tone
	end
	local percent = math.round(math.abs(ratio - 1) * 100)
	if percent == 0 then
		return "Fair price", tone
	end
	return `{percent}% {if ratio < 1 then "under" else "over"}`, tone
end

-- The bar's line about the tapped card: what it is worth, its rarity, and what is special about this copy
function CaseWindow.worthLine(view: { market: number, rarity: string, foil: boolean, level: number, stars: number }): string
	local parts = { `Worth {CaseWindow.money(view.market)}`, view.rarity }
	if view.foil then
		table.insert(parts, "Foil")
	end
	if view.level > 1 then
		table.insert(parts, `Lv {view.level}`)
	end
	if view.stars > 0 then
		table.insert(parts, `{view.stars} star{if view.stars == 1 then "" else "s"}`)
	end
	return table.concat(parts, " · ")
end

-- The bar's small line: who buys it, and that a new card waits for Done
function CaseWindow.hint(kind: string, held: boolean): string
	local who = if kind == "PlayerCards" then "Players" else "Customers"
	if held then
		return `{who} can't buy it until you press Done.`
	end
	return if kind == "PlayerCards" then "Players buy it at this price. Tap the price to type one." else "Customers buy it at this price."
end

-- How many cards stand in a row
function CaseWindow.columns(capacity: number): number
	return math.clamp(capacity, 1, CaseWindow.LOOK.most)
end

-- One slot's size in a pane `width` x `height` with `columns` across and `rows` down: `w` wide, its card `face` tall,
-- `h` with the tag and the words under it. As wide as the row lets it, shrunk to fit the height where it can (never
-- under LOOK.minWidth: then the pane scrolls)
function CaseWindow.tile(width: number, height: number, columns: number, rows: number): { w: number, face: number, h: number }
	local look = CaseWindow.LOOK
	local w = math.floor((width - (columns - 1) * look.gap) / columns)
	local room = (height - (rows - 1) * look.gap) / rows - look.under
	local byHeight = math.floor(room * look.shape)
	w = math.max(look.minWidth, math.min(w, byHeight))
	local face = math.floor(w / look.shape)
	return { w = w, face = face, h = face + look.under }
end

return CaseWindow
