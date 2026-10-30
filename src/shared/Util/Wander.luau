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

-- Where an animal running laps round a circle (the plaza's puppy round the gazebo) heads next, from `angle` degrees:
-- 30 to maxArc degrees on, a quarter of the time back the other way
function Wander.orbitTarget(angle: number, maxArc: number, rng: Rng): number
	local turn = rng:NextNumber(math.min(30, maxArc), maxArc)
	if rng:NextNumber(0, 1) < 0.25 then
		turn = -turn
	end
	return angle + turn
end

-- One move along the circle (r studs round) toward the target angle at `speed` studs a second, never past it; true
-- once it's there. Following the curve (not a straight line) keeps it clear of whatever stands inside the circle.
function Wander.orbitStep(angle: number, target: number, r: number, speed: number, dt: number): (number, boolean)
	local move = math.deg(speed * dt / r)
	local left = target - angle
	if math.abs(left) <= move then
		return target, true
	end
	return angle + (if left > 0 then move else -move), false
end

-- The point on a circle r studs round home at `angle` degrees
function Wander.circlePoint(home: Point, r: number, angle: number): Point
	local a = math.rad(angle)
	return { x = home.x + math.cos(a) * r, z = home.z + math.sin(a) * r }
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
