--!strict
-- The checkout as one box on the shop's grid (testers 2026-11-26: "Make the cash register Moveable", the owner's pick A;
-- spec docs/superpowers/specs/2026-11-26-movable-register-design.md): the counter, the cashier's step behind it and the
-- customers' queue in front move together, and stay in the hall. Pure, Lune-tested.
local CheckoutLayout = {}

-- Studs: as wide as its widest piece, from the queue's end (its front) to the step's back; `registerZ`: how far the
-- counter's middle sits from the box's middle toward its back (the cashier's side)
export type Box = { width: number, depth: number, registerZ: number }

-- `counter`: the counter part's size across (x) and deep (z); `step`: the cashier's step, `staffBehind` from the
-- counter's back edge to its middle; `queue`: the customers' line in front of the counter
function CheckoutLayout.box(counter: { x: number, z: number }, step: { width: number, depth: number }, staffBehind: number, queue: { width: number, length: number }): Box
	local back = math.max(counter.z / 2, counter.z / 2 + staffBehind + step.depth / 2)
	local front = counter.z / 2 + queue.length
	return { width = math.max(counter.x, step.width, queue.width), depth = back + front, registerZ = (front - back) / 2 }
end

-- The box from Config/Plots (REGISTER_SIZE, QUEUE_ZONE_*) and Config/Town (COUNTER STEP, STAFF_BEHIND)
function CheckoutLayout.fromConfig(plots: any, town: any): Box
	local counter = plots.REGISTER_SIZE
	return CheckoutLayout.box({ x = counter.X, z = counter.Z }, town.COUNTER.STEP, town.COUNTER.STAFF_BEHIND, {
		width = plots.QUEUE_ZONE_WIDTH,
		length = plots.QUEUE_ZONE_LENGTH,
	})
end

-- A piece of it from the box's middle (studs; +z toward the cashier's side, y up): the move ghost draws these
export type Piece = { name: string, x: number, y: number, z: number, w: number, h: number, d: number }

-- The counter, the cashier's step on the floor behind it and the queue's strip on the floor in front, as the real ones
-- stand (PlotService builds them round the counter)
function CheckoutLayout.pieces(plots: any, town: any, box: Box): { Piece }
	local counter = plots.REGISTER_SIZE
	local step = town.COUNTER.STEP
	local floor = -counter.Y / 2
	local length = plots.QUEUE_ZONE_LENGTH
	return {
		{ name = "Counter", x = 0, y = 0, z = box.registerZ, w = counter.X, h = counter.Y, d = counter.Z },
		{ name = "Step", x = 0, y = floor + step.height / 2, z = box.registerZ + counter.Z / 2 + town.COUNTER.STAFF_BEHIND, w = step.width, h = step.height, d = step.depth },
		{ name = "Queue", x = 0, y = floor + 0.05, z = box.registerZ - (counter.Z + length) / 2, w = plots.QUEUE_ZONE_WIDTH, h = 0.1, d = length },
	}
end

-- Whether a footprint `d` cells deep from row `gridZ` stays in the hall (its rows 0 to hallRows - 1, from the street):
-- never in a room or its wall, open or not
function CheckoutLayout.inHall(gridZ: number, d: number, hallRows: number): boolean
	return gridZ >= 0 and gridZ + d <= hallRows
end

return CheckoutLayout
