--!strict
-- Storage racks (spec docs/superpowers/specs/2026-11-24-storage-racks-design.md): where a stored box goes, which box
-- comes out, the rack's `Stored` attribute, a saved rack cleaned on load, the stock clipboard's lines and words, the
-- prompt's words and a restocker's picks. Pure (no requires, no Roblox APIs): callers pass Config/Storage in, so
-- tests/StorageRules runs it in Lune.
local StorageRules = {}

export type Box = { productId: string, units: number }
export type Stored = { [number]: Box } -- spot -> box
export type Line = { productId: string, name: string, boxes: number, units: number, words: string, tally: string }
export type ShelfView = { uid: string, units: number, capacity: number, productId: string?, accepts: { string }? }
export type RackView = { uid: string, stored: Stored }
export type Pick = { rack: string, slot: number, shelf: string, productId: string }
export type Spots = { x: { number }, decks: { number }, boxHeight: number }

local function sortedSlots(stored: Stored): { number }
	local slots: { number } = {}
	for slot in stored do
		table.insert(slots, slot)
	end
	table.sort(slots)
	return slots
end

local function firstFree(stored: Stored, capacity: number, from: number): number?
	for slot = from, capacity do
		if not stored[slot] then
			return slot
		end
	end
	return nil
end

function StorageRules.count(stored: Stored): number
	local count = 0
	for _ in stored do
		count += 1
	end
	return count
end

-- The spot a new box of `productId` goes to: the first free one after the last box of its kind, else the first free
-- one; nil when the rack is full
function StorageRules.slotFor(stored: Stored, capacity: number, productId: string): number?
	local last = 0
	for slot = 1, capacity do
		local box = stored[slot]
		if box and box.productId == productId then
			last = slot
		end
	end
	if last > 0 then
		local after = firstFree(stored, capacity, last + 1)
		if after then
			return after
		end
	end
	return firstFree(stored, capacity, 1)
end

-- The box of `productId` that comes out first: the one with the fewest units (a half-used box), then the lowest spot
function StorageRules.takeSlot(stored: Stored, productId: string): number?
	local best: number? = nil
	local bestUnits = math.huge
	for _, slot in sortedSlots(stored) do
		local box = stored[slot]
		if box.productId == productId and box.units < bestUnits then
			best, bestUnits = slot, box.units
		end
	end
	return best
end

-- The rack's `Stored` attribute: "slot:productId:units" joined by ";", spots in order
function StorageRules.encode(stored: Stored): string
	local parts: { string } = {}
	for _, slot in sortedSlots(stored) do
		local box = stored[slot]
		table.insert(parts, `{slot}:{box.productId}:{box.units}`)
	end
	return table.concat(parts, ";")
end

function StorageRules.decode(text: unknown, capacity: number): Stored
	local stored: Stored = {}
	if typeof(text) ~= "string" then
		return stored
	end
	for part in string.gmatch(text, "[^;]+") do
		local slotText, productId, unitsText = string.match(part, "^(%d+):([%w_]+):(%d+)$")
		local slot, units = tonumber(slotText), tonumber(unitsText)
		if slot and productId and units and slot >= 1 and slot <= capacity and units >= 1 and not stored[slot] then
			stored[slot] = { productId = productId, units = units }
		end
	end
	return stored
end

-- A saved rack's boxes made safe: unknown kinds dropped (as the pad's loader does), units floored and kept to what a
-- box holds, a box with a bad or taken spot moved to the spot StorageRules.slotFor gives it. What doesn't fit comes back
-- as extras for the caller to put on the pad or pay back: never lost.
function StorageRules.clean(saved: unknown, capacity: number, unitsPerBox: { [string]: number }): (Stored, { Box })
	local stored: Stored = {}
	local extras: { Box } = {}
	if typeof(saved) ~= "table" then
		return stored, extras
	end
	local later: { Box } = {}
	for _, entry in saved :: { any } do
		if typeof(entry) ~= "table" or typeof(entry.productId) ~= "string" or typeof(entry.units) ~= "number" or entry.units ~= entry.units then
			continue
		end
		local most = unitsPerBox[entry.productId]
		if not most then
			continue
		end
		local units = math.min(math.floor(entry.units), most)
		if units < 1 then
			continue
		end
		local box: Box = { productId = entry.productId, units = units }
		local slot = entry.slot
		if typeof(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= capacity and not stored[slot] then
			stored[slot] = box
		else
			table.insert(later, box)
		end
	end
	for _, box in later do
		local slot = StorageRules.slotFor(stored, capacity, box.productId)
		if slot then
			stored[slot] = box
		else
			table.insert(extras, box)
		end
	end
	return stored, extras
end

-- The stock clipboard's lines: one per kind, in the order their first box sits on the rack, with a tally mark per box
-- and the units inside in words
function StorageRules.lines(stored: Stored, names: { [string]: string }, units: { [string]: { string } }): { Line }
	local lines: { Line } = {}
	local byProduct: { [string]: Line } = {}
	for _, slot in sortedSlots(stored) do
		local box = stored[slot]
		local line = byProduct[box.productId]
		if not line then
			line = { productId = box.productId, name = names[box.productId] or box.productId, boxes = 0, units = 0, words = "", tally = "" }
			byProduct[box.productId] = line
			table.insert(lines, line)
		end
		line.boxes += 1
		line.units += box.units
	end
	for _, line in lines do
		local words = units[line.productId]
		local noun = if words then (if line.units == 1 then words[1] else words[2]) else line.productId
		line.words = `{line.units} {noun}`
		line.tally = string.rep("I", line.boxes)
	end
	return lines
end

-- The rack's E prompt: Store with the carried kind's name (or "Rack full" said before you press), else Open with how
-- many boxes it holds
function StorageRules.prompt(count: number, capacity: number, carrying: string?, words: any): (string, string)
	if carrying then
		if count >= capacity then
			return words.store, string.format(words.full, count, capacity)
		end
		return words.store, carrying
	end
	local what = if count <= 0 then words.empty elseif count == 1 then words.oneBox else string.format(words.boxes, count)
	return words.open, string.format(words.rackCount, what)
end

-- The sheet's line under its title: the spots used, and the restocker that last stocked the rack
-- The clipboard's away-selling stamp for a rack holding `count` boxes (spec 2026-11-24-shop-variety-design): with a
-- Restocker working, "+30 MIN / AWAY SELLING" (active), else "NEEDS A / RESTOCKER"; nil for an empty rack
function StorageRules.awayStamp(count: number, restockers: number, minutes: number, words: any): (string?, boolean)
	if count <= 0 then
		return nil, false
	end
	if restockers > 0 then
		return string.format(words.awayStamp, minutes), true
	end
	return words.needsStamp, false
end

function StorageRules.subtitle(count: number, capacity: number, worker: string?, words: any): string
	local text = string.format(words.spots, count, capacity)
	if worker and worker ~= "" then
		text ..= string.format(words.countedBy, worker)
	end
	return text
end

function StorageRules.isLow(units: number, capacity: number, share: number): boolean
	return units <= capacity * share
end

local function takes(shelf: ShelfView, productId: string): boolean
	return shelf.accepts == nil or table.find(shelf.accepts, productId) ~= nil
end

-- A restocker's rack-to-shelf trip: the emptiest selling shelf at `share` full or less whose kind sits on a rack, else
-- the first empty shelf that takes a racked kind; the rack box is StorageRules.takeSlot's
function StorageRules.restockPick(shelves: { ShelfView }, racks: { RackView }, share: number): Pick?
	local low: { { shelf: ShelfView, fill: number, index: number } } = {}
	for index, shelf in shelves do
		local productId = shelf.productId
		if productId and shelf.units > 0 and shelf.units < shelf.capacity and StorageRules.isLow(shelf.units, shelf.capacity, share) then
			table.insert(low, { shelf = shelf, fill = shelf.units / math.max(shelf.capacity, 1), index = index })
		end
	end
	table.sort(low, function(a, b)
		if a.fill ~= b.fill then
			return a.fill < b.fill
		end
		return a.index < b.index
	end)
	for _, entry in low do
		local productId = entry.shelf.productId :: string
		for _, rack in racks do
			local slot = StorageRules.takeSlot(rack.stored, productId)
			if slot then
				return { rack = rack.uid, slot = slot, shelf = entry.shelf.uid, productId = productId }
			end
		end
	end
	for _, shelf in shelves do
		if shelf.units <= 0 then
			for _, rack in racks do
				for _, spot in sortedSlots(rack.stored) do
					local productId = rack.stored[spot].productId
					if takes(shelf, productId) then
						local slot = StorageRules.takeSlot(rack.stored, productId) :: number
						return { rack = rack.uid, slot = slot, shelf = shelf.uid, productId = productId }
					end
				end
			end
		end
	end
	return nil
end

-- A restocker storing a pad box: the nearest rack with a free spot
function StorageRules.pickRack(racks: { { uid: string, free: number, distance: number } }): string?
	local best: string? = nil
	local bestDistance = math.huge
	for _, rack in racks do
		if rack.free > 0 and rack.distance < bestDistance then
			best, bestDistance = rack.uid, rack.distance
		end
	end
	return best
end

-- Where a box stands on its spot, in the rack part's space: its x across, and the height of its middle from the part's
-- middle (the part is `rackHeight` tall and stands on the floor)
function StorageRules.spot(slot: number, spots: Spots, rackHeight: number): (number, number)
	local across = #spots.x
	local deck = spots.decks[math.ceil(slot / across)] or spots.decks[#spots.decks]
	local x = spots.x[(slot - 1) % across + 1]
	return x, -rackHeight / 2 + deck + spots.boxHeight / 2
end

return StorageRules
