--!strict
-- Deliveries as numbers (owner 2026-11-23, mockups A, 1 and 3; Config/Delivery): the packenship.co van's trip down the
-- street (where it is at any moment on the server's clock, so every player sees it at the same place), its stop on the
-- lane past the pad, the boxes' times and arcs, the packs a stocked box splits into, the waiting chip's words. Pure,
-- Lune-tested (tests/DeliveryRules): StockService times the boxes, DeliveryController draws the rest.
local DeliveryRules = {}

export type Trip = { firstHop: number, hopGap: number, hopTime: number, linger: number, speed: number, brake: number }
export type Route = { inDistance: number, outDistance: number }
export type Point = { x: number, y: number, z: number }

-- The lane's middle from the pad's middle, studs toward the street: across the rest of the sidewalk the pad stands
-- on, the gap off the curb and half the van. `padCentre`: the pad's middle from the shop's front edge
function DeliveryRules.laneOffset(lane: { padCentre: number, sidewalk: number, curb: number, vanWidth: number }): number
	return lane.sidewalk - lane.padCentre + lane.curb + lane.vanWidth / 2
end

-- When each box leaves the van, seconds after it stops (the server makes the box then and the clients fly it in)
function DeliveryRules.hopTimes(count: number, trip: Trip): { number }
	local times = {}
	for index = 1, count do
		times[index] = trip.firstHop + (index - 1) * trip.hopGap
	end
	return times
end

-- How long the van stands at the curb: until its last box has landed, then a moment more (the bell, the beep)
function DeliveryRules.stay(count: number, trip: Trip): number
	return trip.firstHop + math.max(count - 1, 0) * trip.hopGap + trip.hopTime + trip.linger
end

-- How far a van slowing to a stop over `brake` s (or speeding up over it) goes in `seconds` from standing
local function eased(seconds: number, trip: Trip): number
	local brake = trip.brake
	if seconds <= brake then
		return 0.5 * trip.speed / brake * seconds * seconds
	end
	return 0.5 * trip.speed * brake + trip.speed * (seconds - brake)
end

-- Where the van is along its lane at `now` (the server's clock): studs from its stop, negative while it's coming, 0
-- while it stands there, positive as it leaves
function DeliveryRules.offset(now: number, arrive: number, leave: number, trip: Trip): number
	if now < arrive then
		return -eased(arrive - now, trip)
	elseif now <= leave then
		return 0
	end
	return eased(now - leave, trip)
end

-- The street's length behind and ahead of a stop at `stopX`, for a van driving `direction` (1: toward +x, -1: toward
-- -x) on a street from -halfLength to halfLength, its ends `endInset` short
function DeliveryRules.route(stopX: number, direction: number, halfLength: number, endInset: number): Route
	local edge = halfLength - endInset
	local entry = -direction * edge
	local exit = direction * edge
	return { inDistance = math.abs(stopX - entry), outDistance = math.abs(exit - stopX) }
end

-- How solid the van is at `offset` (0 hidden, 1 solid): only on the street, fading in over `fade` studs at the end it
-- comes from and out at the end it leaves by
function DeliveryRules.opacity(offset: number, route: Route, fade: number): number
	if offset < -route.inDistance or offset > route.outDistance then
		return 0
	end
	local fromEntry = offset + route.inDistance
	local toExit = route.outDistance - offset
	return math.clamp(math.min(fromEntry, toExit) / fade, 0, 1)
end

-- A point on a hop's arc at `share` (0..1) of the way: a straight line from `from` to `to`, lifted by a parabola
-- `peak` studs over the higher end at its middle
function DeliveryRules.hopPoint(from: Point, to: Point, share: number, peak: number): Point
	local s = math.clamp(share, 0, 1)
	local top = math.max(from.y, to.y) + peak
	-- the straight line's height at the middle, and how much the arc adds there
	local middle = (from.y + to.y) / 2
	local lift = (top - middle) * 4 * s * (1 - s)
	return {
		x = from.x + (to.x - from.x) * s,
		y = from.y + (to.y - from.y) * s + lift,
		z = from.z + (to.z - from.z) * s,
	}
end

-- A stocked box's units as up to `items` hopping packs, each standing for its share (as even as can be, the bigger
-- shares first) so the rolling count lands on what was added
function DeliveryRules.shares(added: number, items: number): { number }
	local count = math.min(math.max(added, 0), items)
	local list = {}
	if count <= 0 then
		return list
	end
	local base = added // count
	local extra = added - base * count
	for index = 1, count do
		list[index] = base + (if index <= extra then 1 else 0)
	end
	return list
end

-- The chip over your pad
function DeliveryRules.waitingWords(count: number): string
	return if count == 1 then "1 box waiting" else `{count} boxes waiting`
end

-- Whether the chip shows: boxes wait and you stand `distance` studs from your pad (nil: no character or pad). It shows
-- within `chip.near` and, once `shown`, stays until you're past `chip.far`, so it never flickers at the edge
function DeliveryRules.chipShows(count: number, distance: number?, shown: boolean, chip: { near: number, far: number }): boolean
	if count <= 0 or distance == nil then
		return false
	end
	return distance <= (if shown then chip.far else chip.near)
end

return DeliveryRules
