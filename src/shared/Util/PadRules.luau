--!strict
-- The delivery pad's stacks (owner 2026-11-20: "when there is alot of boxes piled up, and the players just want to take
-- the one on top. it's dificult. make it better"). Boxes used to fill a 2x2 grid layer by layer in the order they came,
-- every box with its own Pick up prompt, so a pile showed whichever prompt was nearest: often a box at the bottom.
-- Now each product has its own stack (a second one when the first is full) and only the top box of a stack can be
-- picked up, its prompt saying what it is and how many wait. Pure, Lune-tested: StockService passes each waiting box's
-- product in pad order.
local PadRules = {}

export type Place = { column: number, level: number } -- column 1..columns, level 0 at the bottom

-- Where each waiting box stands. A box joins its product's stack while that has room (`high` boxes), else it starts a
-- stack on the first empty column; with no column empty it goes on the lowest stack with room, then the lowest of all
function PadRules.arrange(products: { string }, columns: number, high: number): { Place }
	local owner: { [number]: string } = {}
	local count: { [number]: number } = {}
	for column = 1, columns do
		count[column] = 0
	end
	local places: { Place } = {}
	for _, product in products do
		local chosen: number? = nil
		for column = 1, columns do
			if owner[column] == product and count[column] < high then
				chosen = column
				break
			end
		end
		if not chosen then
			for column = 1, columns do
				if count[column] == 0 then
					chosen = column
					break
				end
			end
		end
		if not chosen then
			for _, roomOnly in { true, false } do
				for column = 1, columns do
					local fits = not roomOnly or count[column] < high
					if fits and (chosen == nil or count[column] < count[chosen :: number]) then
						chosen = column
					end
				end
				if chosen then
					break
				end
			end
		end
		local column = chosen or 1
		if count[column] == 0 then
			owner[column] = product
		end
		table.insert(places, { column = column, level = count[column] })
		count[column] += 1
	end
	return places
end

-- Which boxes can be picked up: the top one of each stack (by index into the list `arrange` was given)
function PadRules.tops(places: { Place }): { [number]: boolean }
	local highest: { [number]: number } = {}
	for index, place in places do
		local current = highest[place.column]
		if current == nil or place.level > places[current].level then
			highest[place.column] = index
		end
	end
	local tops: { [number]: boolean } = {}
	for _, index in highest do
		tops[index] = true
	end
	return tops
end

-- A stack's prompt: what's in it, and how many boxes of it wait on the pad when there's more than one
function PadRules.label(name: string, waiting: number): string
	return if waiting > 1 then `{name} · {waiting} boxes` else name
end

return PadRules
