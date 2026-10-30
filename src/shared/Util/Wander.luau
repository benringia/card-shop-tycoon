--!strict
-- An ambient animal wandering round its home (Portal Worlds spec): pick a point in the ring between `avoid` and
-- `radius` from home (or a little further round a circle, for one running laps), walk to it without passing it,
-- pause, pick again. Pure, Lune-tested; homes in Config/Ambient
-- CRITTERS, TownCritterController moves the animals.
export type Point = { x: number, z: number }
export type Rng = { NextNumber: (any, number, number) -> number }

local Wander = {}

-- A point spread evenly over the ring round home (avoid: studs kept clear in the middle, e.g. the spring)
function Wander.target(home: Point, radius: number, avoid: number?, rng: Rng): Point
	local inner = avoid or 0
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(rng:NextNumber(inner * inner, radius * radius))
	return { x = home.x + math.cos(angle) * distance, z = home.z + math.sin(angle) * distance }
end

-- The next point for an animal running round a circle `r` studs from home (the plaza's puppy round the fountain), from
-- where it stands at `angle` degrees: 10 to maxArc degrees on, now and then back the other way, so the straight walk
-- there stays close to the circle. Returns the point and its angle.
function Wander.orbitTarget(home: Point, r: number, angle: number, maxArc: number, rng: Rng): (Point, number)
	local turn = rng:NextNumber(math.min(10, maxArc), maxArc)
	if rng:NextNumber(0, 1) < 0.25 then
		turn = -turn
	end
	local nextAngle = angle + turn
	local a = math.rad(nextAngle)
	return { x = home.x + math.cos(a) * r, z = home.z + math.sin(a) * r }, nextAngle
end

-- One move toward the target at `speed` studs a second; true once it's there
function Wander.step(pos: Point, target: Point, speed: number, dt: number): (Point, boolean)
	local dx, dz = target.x - pos.x, target.z - pos.z
	local distance = math.sqrt(dx * dx + dz * dz)
	local move = speed * dt
	if distance <= move then
		return { x = target.x, z = target.z }, true
	end
	return { x = pos.x + dx / distance * move, z = pos.z + dz / distance * move }, false
end

return Wander
