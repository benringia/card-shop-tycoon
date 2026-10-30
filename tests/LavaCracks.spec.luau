--!strict
-- The caldera's glowing cracks (caldera spec 2026-10-31): branching cracks down the canyon's cliff faces and across its
-- floor, laid out by Util/LavaCracks from Config/Scenery CRACKS; SceneryService snaps them onto the terrain as glowing
-- strips. Off the trail, away from the portal, capped, and the same every server start.
local town = require("../src/shared/Config/Town")
local scenery = require("../src/shared/Config/Scenery")
local LavaCracks = require("../src/shared/Util/LavaCracks")
local expect = require("./lib/expect")

local CRACKS = scenery.CRACKS

-- A seeded 0..1 random (Lune has no Random): the game passes Random.new(SEED):NextNumber
local function lcg(seed: number): () -> number
	local state = seed
	return function(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

local function arenaArea()
	for _, area in town.PORTAL_AREAS do
		if area.key == "Arena" then
			return area
		end
	end
	error("no Arena area")
end

local function segmentDistance(p, a, b): number
	local dx, dz = b.x - a.x, b.z - a.z
	local t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((p.x - (a.x + dx * t)) ^ 2 + (p.z - (a.z + dz * t)) ^ 2)
end

local function build()
	return LavaCracks.all(CRACKS, town, lcg(CRACKS.SEED))
end

return {
	["wall cracks stay on their wall"] = function()
		local walls = build()
		for _, wall in CRACKS.WALLS do
			for _, segment in walls[wall.name] do
				for _, point in { segment.a, segment.b } do
					assert(point.along >= 0 and point.along <= 1, `{wall.name}: along {point.along}`)
					assert(point.y >= wall.low - 1e-9 and point.y <= wall.high + 1e-9, `{wall.name}: y {point.y}`)
				end
				assert(segment.width >= CRACKS.WIDTH[1] - 1e-9 and segment.width <= CRACKS.WIDTH[2] + 1e-9, `width {segment.width}`)
			end
		end
	end,

	["floor cracks stay off the trail and away from the portal"] = function()
		local _, floor = build()
		local area = arenaArea()
		local portal = area.trail[#area.trail]
		local box = CRACKS.FLOOR
		local clearTrail = town.TRAIL.WIDTH / 2 + 2
		assert(#floor > 0, "the floor has cracks")
		for _, segment in floor do
			for _, point in { segment.a, segment.b } do
				assert(math.abs(point.x - box.centre.x) <= box.size.x / 2 + 1e-9, `x {point.x} outside the floor`)
				assert(math.abs(point.z - box.centre.z) <= box.size.z / 2 + 1e-9, `z {point.z} outside the floor`)
				for index = 2, #area.trail do
					local d = segmentDistance(point, area.trail[index - 1], area.trail[index])
					assert(d >= clearTrail - 1e-9, `crack at {point.x}, {point.z} is {d} from the trail`)
				end
				local toPortal = math.sqrt((point.x - portal.x) ^ 2 + (point.z - portal.z) ^ 2)
				assert(toPortal >= town.PORTAL_SCENERY_CLEAR - 1e-9, `crack at {point.x}, {point.z} crowds the portal`)
			end
		end
	end,

	["cracks are capped and repeatable"] = function()
		local walls, floor = build()
		local total = #floor
		for _, list in walls do
			total += #list
		end
		assert(total <= CRACKS.MAX_SEGMENTS, `{total} segments`)
		local walls2, floor2 = build()
		expect.equal(#floor2, #floor, "the floor's count")
		for index, segment in floor do
			expect.equal(floor2[index].a.x, segment.a.x, "a floor segment's start")
			expect.equal(floor2[index].b.z, segment.b.z, "a floor segment's end")
		end
		for name, list in walls do
			expect.equal(#walls2[name], #list, `{name}'s count`)
		end
	end,

	["every wall gets cracks"] = function()
		local walls = build()
		for _, wall in CRACKS.WALLS do
			assert(walls[wall.name] and #walls[wall.name] >= wall.count, `{wall.name} has too few segments`)
		end
	end,
}
