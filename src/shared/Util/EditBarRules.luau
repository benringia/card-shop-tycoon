--!strict
-- The Edit bar's contents (owner 2026-11-23, mockup C "Action bar": the shop's Edit window, a plain list of rows, gave
-- way to the thing lit up in the world and its own candy tiles at the bottom centre, like Drop and Rip when you carry a
-- box; "change RECYCLE to USE"). What each placed thing offers, in plain words: its name, a status chip, one hint line
-- and its tiles: its own use first (Remove stock, Cards, a machine's Use), then Move, then its way out (Sell for money,
-- held down; a trophy back to the Bag; a poster taken down). A tile can rest ("off": nothing to do) or be locked (Sell
-- before it's empty); a tap on either says why. Pure, Lune-tested (tests/EditBarRules): EditBarController draws it,
-- BuildController and WindowController describe their things.
local EditBarRules = {}

export type Kind =
	"Products"
	| "Bin"
	| "CustomerCards"
	| "PlayerCards"
	| "Condenser"
	| "Grading"
	| "Forge"
	| "Recycler"
	| "Trophy"
	| "Decor"
	| "Window"
	| "Poster"

-- A machine's job: seconds left on a running one, or a finished one waiting to be taken out
export type Machine = { working: number?, done: boolean? }

export type Thing = {
	kind: Kind,
	name: string,
	capacity: number?, -- product units, card slots, a Bulk Bin's handfuls
	units: number?, -- a product shelf's stock (a Bulk Bin's handfuls)
	product: string?, -- the product on it
	cards: number?, -- a card case's cards
	refund: number?, -- what selling it gives back
	decor: number?, -- a decor piece's points
	machine: Machine?,
}

export type TileId = "use" | "cards" | "unstock" | "move" | "sell" | "bag" | "takeDown"
export type Tile = {
	id: TileId,
	label: string, -- on the tile, short
	sub: string, -- the line under it
	state: "ready" | "off" | "locked",
	hold: boolean, -- held down to do it: selling for money
	why: string?, -- what a tap says when the tile rests or is locked
}
export type Tone = "empty" | "full" | "good" | "busy" | "ready" | "plain"
export type Chip = { text: string, tone: Tone }
export type Bar = { name: string, chip: Chip, hint: string, tiles: { Tile } }

-- Each machine's one line (the hint) and its kind of job
local MACHINE_HINTS: { [string]: string } = {
	Condenser = "Turns spare copies into stars.",
	Grading = "Raises a card's grade.",
	Forge = "Makes and upgrades weapons.",
	Recycler = "Turns extra cards into upgrade materials.",
}

-- "$50", "$2,500", "$12.50": whole dollars without cents, thousands with commas
function EditBarRules.money(amount: number): string
	local cents = math.floor(amount * 100 + 0.5)
	local whole = cents // 100
	local digits = tostring(whole)
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if grouped:sub(1, 1) == "," then
		grouped = grouped:sub(2)
	end
	local rest = cents % 100
	if rest == 0 then
		return `${grouped}`
	end
	return string.format("$%s.%02d", grouped, rest)
end

-- "1:28"
local function clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function move(sub: string): Tile
	return { id = "move", label = "Move", sub = sub, state = "ready", hold = false }
end

-- Sell for money, held down; locked (with `why`) until the thing is empty
local function sell(thing: Thing, why: string?): Tile
	return {
		id = "sell",
		label = "Sell",
		sub = if why then "Empty it first" else `+{EditBarRules.money(thing.refund or 0)}`,
		state = if why then "locked" else "ready",
		hold = true,
		why = why,
	}
end

local function stockBar(thing: Thing, bin: boolean): Bar
	local units = thing.units or 0
	local capacity = thing.capacity or 0
	local stocked = units > 0
	local hint = if bin
		then (if stocked then "Customers buy handfuls of 5." else "Put your extra Commons in it.")
		else (if stocked then `Selling {thing.product or "stock"}.` else "Carry a box here to stock it.")
	return {
		name = thing.name,
		chip = if stocked
			then { text = if bin then `{units} / {capacity} handfuls` else `{units} / {capacity}`, tone = "full" }
			else { text = `Empty · 0 / {capacity}`, tone = "empty" },
		hint = hint,
		tiles = {
			{
				id = "unstock",
				label = "Remove",
				sub = if stocked then "Box it up" else "Nothing on it",
				state = if stocked then "ready" else "off",
				hold = false,
				why = if stocked then nil else "Nothing on it to box up.",
			},
			move("Stock stays on"),
			sell(thing, if stocked then "Take the stock off first: Remove boxes it up." else nil),
		},
	}
end

local function caseBar(thing: Thing): Bar
	local cards = thing.cards or 0
	local capacity = thing.capacity or 0
	local buyers = if thing.kind == "PlayerCards" then "Other players" else "Customers"
	return {
		name = thing.name,
		chip = if cards > 0
			then { text = `{cards} / {capacity} cards`, tone = "full" }
			else { text = `Empty · 0 / {capacity}`, tone = "empty" },
		hint = if cards > 0 then `{buyers} buy them at your prices.` else "Put cards on show to sell them.",
		tiles = {
			{ id = "cards", label = "Cards", sub = if cards > 0 then "Show and price" else "Put some in", state = "ready", hold = false },
			move("Cards stay in"),
			sell(thing, if cards > 0 then "Take the cards out of this case first." else nil),
		},
	}
end

local function machineBar(thing: Thing): Bar
	local job = thing.machine
	local chip: Chip = if job and job.working
		then { text = `Working · {clock(job.working)}`, tone = "busy" }
		elseif job and job.done then { text = "Done! Open it", tone = "ready" }
		else { text = "Ready to use", tone = "good" }
	return {
		name = thing.name,
		chip = chip,
		hint = MACHINE_HINTS[thing.kind] or "",
		tiles = {
			{ id = "use", label = "Use", sub = "Open it", state = "ready", hold = false },
			move("Pick a new spot"),
			sell(thing, nil),
		},
	}
end

function EditBarRules.bar(thing: Thing): Bar
	local kind = thing.kind
	if kind == "Products" or kind == "Bin" then
		return stockBar(thing, kind == "Bin")
	elseif kind == "CustomerCards" or kind == "PlayerCards" then
		return caseBar(thing)
	elseif MACHINE_HINTS[kind] then
		return machineBar(thing)
	elseif kind == "Trophy" then
		local boss = (string.gsub(thing.name, " Trophy$", ""))
		return {
			name = thing.name,
			chip = { text = "Trophy", tone = "plain" },
			hint = `Won by beating the {boss}.`,
			tiles = {
				move("Pick a new spot"),
				{ id = "bag", label = "To Bag", sub = "Keep it safe", state = "ready", hold = false },
			},
		}
	elseif kind == "Poster" then
		return {
			name = thing.name,
			chip = { text = "Poster · free", tone = "plain" },
			hint = "Free to take down and put back up.",
			tiles = {
				move("Pick a new spot"),
				{ id = "takeDown", label = "Take down", sub = "It's free", state = "ready", hold = false },
			},
		}
	elseif kind == "Window" then
		return {
			name = thing.name,
			chip = { text = "Window", tone = "plain" },
			hint = "Slide it to any spot on your walls.",
			tiles = { move("Pick a new spot"), sell(thing, nil) },
		}
	end
	-- Decor
	return {
		name = thing.name,
		chip = { text = `Decor +{thing.decor or 0}`, tone = "good" },
		hint = "Makes your shop look nicer.",
		tiles = { move("Pick a new spot"), sell(thing, nil) },
	}
end

return EditBarRules
