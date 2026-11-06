--!strict
-- Town walkers (spec 2026-11-06-customers-design, phase 2): which open shop a strolling customer picks (by rating, and
-- a collector by the card it wants), the stops along the town's street and where it stops next. Pure (Lune-tested):
-- reads Config/Customers WALKERS (cfg) and Config/Town LAYOUT (town), passed in.
local WalkerRules = {}

export type Shop = { id: number, rating: number, open: boolean, hasWanted: boolean }
export type Stop = { kind: string, free: boolean }
export type Point = { x: number, z: number }
-- The shop rows (Config/Plots): two rows of perRow plots facing each other across the street, centred on x = 0
export type World = { perRow: number, plotWidth: number, plotDepth: number, gap: number, streetWidth: number, spring: Point }
-- kind: "window" (a shop's sidewalk), "road", "plaza" or "bench"; it stands at (x, z) looking at (faceX, faceZ)
export type TownStop = { kind: string, x: number, z: number, faceX: number, faceZ: number }

-- Every stop a walker strolls between, spread along the whole street (owner 2026-11-06: "walk all over the town
-- streets", not crowding the fountain)
function WalkerRules.townStops(cfg: any, town: any, world: World): { TownStop }
	local walkers = cfg.WALKERS
	local layout = town.LAYOUT
	local stops: { TownStop } = {}
	local spring = world.spring
	local sidewalkZ = world.streetWidth / 2 - layout.SIDEWALK / 2
	for _, side in { -1, 1 } do
		for col = 0, world.perRow - 1 do
			local door = (col - (world.perRow - 1) / 2) * (world.plotWidth + world.gap)
			for _, offset in walkers.windowOffsets do
				local x = door + offset
				table.insert(stops, { kind = "window", x = x, z = side * sidewalkZ, faceX = x, faceZ = side * world.streetWidth })
			end
		end
		for index, x in walkers.roadXs do
			-- Half look up the street, half down it
			local along = if index % 2 == 0 then 10 else -10
			table.insert(stops, { kind = "road", x = x, z = side * walkers.roadZ, faceX = x + along, faceZ = side * walkers.roadZ })
		end
	end
	local function ring(kind: string, radius: number, degrees: number)
		local angle = math.rad(degrees)
		local x, z = spring.x + math.cos(angle) * radius, spring.z + math.sin(angle) * radius
		table.insert(stops, { kind = kind, x = x, z = z, faceX = spring.x, faceZ = spring.z })
	end
	for _, degrees in walkers.plazaAngles do
		ring("plaza", walkers.plazaRadius, degrees)
	end
	for _, degrees in layout.BENCH_ANGLES do
		ring("bench", layout.BENCH_RADIUS, degrees)
	end
	return stops
end

-- Where walkers walk in and out: both ends of the street, on its middle line
function WalkerRules.exits(cfg: any, town: any): { Point }
	local x = town.LAYOUT.STREET_HALF_LENGTH - cfg.WALKERS.exitInset
	return { { x = -x, z = 0 }, { x = x, z = 0 } }
end

-- The exit nearest (x, z)
function WalkerRules.nearestExit(exits: { Point }, x: number, z: number): number
	local best, bestDistance = 1, math.huge
	for index, exit in exits do
		local distance = (exit.x - x) ^ 2 + (exit.z - z) ^ 2
		if distance < bestDistance then
			best, bestDistance = index, distance
		end
	end
	return best
end

-- An open shop, weighted by rating^ratingPower, times wantedBonus where a collector's card is on show; nil if none
function WalkerRules.chooseShop(cfg: any, shops: { Shop }, roll: number): number?
	local walkers = cfg.WALKERS
	local weights: { number } = {}
	local total = 0
	for index, shop in shops do
		local weight = 0
		if shop.open then
			weight = math.max(shop.rating, 0) ^ walkers.ratingPower * (if shop.hasWanted then walkers.wantedBonus else 1)
		end
		weights[index] = weight
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local left = math.clamp(roll, 0, 0.999999) * total
	local last: number? = nil
	for index, shop in shops do
		if weights[index] > 0 then
			last = shop.id
			left -= weights[index]
			if left < 0 then
				return shop.id
			end
		end
	end
	return last
end

local function pick(indices: { number }, roll: number): number
	return indices[math.clamp(math.floor(roll * #indices) + 1, 1, #indices)]
end

-- The next free stop: a free bench sitChance of the time (or whenever only benches are free), else another free stop;
-- nil when everything is taken
function WalkerRules.nextStop(cfg: any, stops: { Stop }, roll: number): number?
	local benches: { number } = {}
	local others: { number } = {}
	for index, stop in stops do
		if stop.free then
			table.insert(if stop.kind == "bench" then benches else others, index)
		end
	end
	local sitChance = cfg.WALKERS.sitChance
	if #benches > 0 and (roll < sitChance or #others == 0) then
		return pick(benches, if roll < sitChance then roll / sitChance else roll)
	end
	if #others > 0 then
		return pick(others, if roll >= sitChance then (roll - sitChance) / (1 - sitChance) else roll)
	end
	return nil
end

return WalkerRules
