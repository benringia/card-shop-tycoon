--!strict
-- Where the Card Festival Square's pieces stand (Config/Plaza): polar places round the spring, each piece's footprint
-- for the clearance tests, the bulbs along a sagging string light, the lotus fountain's petals, the cafe chairs and
-- the plants in the edge planters. Pure, Lune-tested; Server/Util/PlazaBuild and BloomFountain build from it.
export type Point = { x: number, z: number }
export type Vec = { x: number, y: number, z: number }
export type Footprint = { kind: string, x: number, z: number, radius: number }
-- A giant card: where its foot stands, how far it leans (degrees, + to the left), how far behind the middle it stands
export type FanCard = { x: number, z: number, width: number, height: number, lean: number, back: number, offset: number }
-- A petal: its foot, middle and tip (studs from the fountain's foot), turned `angle` degrees round the fountain
export type Petal = { angle: number, base: Vec, centre: Vec, tip: Vec }
-- An outer lotus petal also carries its element and where its gem's water lands in the pool
export type ElementPetal = Petal & { element: string, color: { number }, land: Vec }
-- A chair round a cafe table (from the spring) and the unit direction it faces (at the table's middle)
export type Chair = { x: number, z: number, faceX: number, faceZ: number }
export type Plant = { kind: string, model: string, x: number, z: number, height: number, yaw: number }

local PlazaLayout = {}

-- angle in degrees (0 = +X, 90 = +Z), r in studs from the spring
function PlazaLayout.at(angle: number, r: number): Point
	local a = math.rad(angle)
	return { x = math.cos(a) * r, z = math.sin(a) * r }
end

-- The giant cards side by side along the fan's plinth, facing cfg.FAN.face: the middle one straight and in front, the
-- others leaning out and standing a little further back the further out they are
function PlazaLayout.fanCards(cfg: any): { FanCard }
	local fan = cfg.FAN
	local centre = PlazaLayout.at(fan.angle, fan.r)
	local fx, fz = fan.face.x - centre.x, fan.face.z - centre.z
	local length = math.sqrt(fx * fx + fz * fz)
	fx, fz = fx / length, fz / length
	-- CFrame.lookAt's right side when looking along (fx, fz)
	local rx, rz = -fz, fx
	local cards = {}
	local count = #fan.cards
	for index, spec in fan.cards do
		local offset = index - (count + 1) / 2
		local back = math.abs(offset) * fan.depthStep
		table.insert(cards, {
			x = centre.x + rx * offset * fan.step - fx * back,
			z = centre.z + rz * offset * fan.step - fz * back,
			width = spec.height / 1.4,
			height = spec.height,
			lean = -offset * fan.lean,
			back = back,
			offset = offset,
		})
	end
	return cards
end

-- The pieces of each edge planter's curve as footprints, one every cfg.PLANTERS.piece degrees, ends included
local function planterPieces(cfg: any, place: (string, number, number, number) -> ())
	local planters = cfg.PLANTERS
	for _, arc in planters.arcs do
		local count = math.max(1, math.ceil((arc[2] - arc[1]) / planters.piece))
		for index = 0, count do
			place("planter", arc[1] + (arc[2] - arc[1]) * index / count, planters.r, planters.width / 2)
		end
	end
end

function PlazaLayout.footprints(cfg: any): { Footprint }
	local list: { Footprint } = {}
	local function add(kind: string, angle: number, r: number, radius: number)
		local p = PlazaLayout.at(angle, r)
		table.insert(list, { kind = kind, x = p.x, z = p.z, radius = radius })
	end
	for _, card in PlazaLayout.fanCards(cfg) do
		table.insert(list, { kind = "giant card", x = card.x, z = card.z, radius = card.width / 2 })
	end
	for _, stall in cfg.STALLS do
		add("stall", stall.angle, stall.r, cfg.STALL.reach)
	end
	for _, angle in cfg.TABLES.angles do
		add("table", angle, cfg.TABLES.r, cfg.TABLE.reach)
	end
	for _, angle in cfg.LAMPS.angles do
		add("lamp", angle, cfg.LAMPS.r, cfg.LAMPS.reach)
	end
	for _, tree in cfg.TREES do
		add("potted tree", tree.angle, tree.r, cfg.TREE_REACH)
	end
	planterPieces(cfg, add)
	return list
end

-- `count` petals evenly round the fountain from `offset` degrees, each leaning out ring.lean degrees from upright from
-- a foot ring.r out at ring.y, ring.length long
function PlazaLayout.petalRing(ring: any, count: number, offset: number): { Petal }
	local petals = {}
	local lean = math.rad(ring.lean)
	for index = 1, count do
		local angle = offset + (index - 1) * 360 / count
		local out = PlazaLayout.at(angle, 1)
		local base = { x = out.x * ring.r, y = ring.y, z = out.z * ring.r }
		local function along(distance: number): Vec
			return {
				x = base.x + out.x * math.sin(lean) * distance,
				y = base.y + math.cos(lean) * distance,
				z = base.z + out.z * math.sin(lean) * distance,
			}
		end
		table.insert(petals, { angle = angle, base = base, centre = along(ring.length / 2), tip = along(ring.length) })
	end
	return petals
end

-- The lotus's outer petals, one per element, the first along +X; each gem's water lands fountain.jet.land studs out
-- on its own side of the pool
function PlazaLayout.petals(fountain: any): { ElementPetal }
	local list = {}
	for index, petal in PlazaLayout.petalRing(fountain.petal, #fountain.elements, 0) do
		local element = fountain.elements[index]
		local land = PlazaLayout.at(petal.angle, fountain.jet.land)
		table.insert(list, {
			angle = petal.angle,
			base = petal.base,
			centre = petal.centre,
			tip = petal.tip,
			element = element.name,
			color = element.color,
			land = { x = land.x, y = fountain.pool.y, z = land.z },
		})
	end
	return list
end

-- The chairs round cafe table `index` (cfg.TABLES.angles), turned a little differently at each table
function PlazaLayout.chairs(cfg: any, index: number): { Chair }
	local t = cfg.TABLE
	local angle = cfg.TABLES.angles[index]
	local middle = PlazaLayout.at(angle, cfg.TABLES.r)
	local chairs = {}
	for chair = 1, t.chairs do
		local around = PlazaLayout.at(angle * 7 + chair / t.chairs * 360, 1)
		table.insert(chairs, {
			x = middle.x + around.x * t.chairRadius,
			z = middle.z + around.z * t.chairRadius,
			faceX = -around.x,
			faceZ = -around.z,
		})
	end
	return chairs
end

-- Bushes and flowers along the middle of each edge planter, one every PLANTERS.step studs (ends kept a step in),
-- skipping spots within PLANTERS.clear of a lamp or tree; kinds follow PLANTERS.pattern, models cycle through the
-- lists, each turned a different way
function PlazaLayout.planterPlants(cfg: any): { Plant }
	local planters = cfg.PLANTERS
	local taken: { Point } = {}
	for _, angle in cfg.LAMPS.angles do
		table.insert(taken, PlazaLayout.at(angle, cfg.LAMPS.r))
	end
	for _, tree in cfg.TREES do
		table.insert(taken, PlazaLayout.at(tree.angle, tree.r))
	end
	local plants = {}
	local spot = 0
	for _, arc in planters.arcs do
		local length = math.rad(arc[2] - arc[1]) * planters.r
		local count = math.floor(length / planters.step) - 1
		for index = 1, count do
			local p = PlazaLayout.at(arc[1] + (arc[2] - arc[1]) * index / (count + 1), planters.r)
			local free = true
			for _, other in taken do
				if math.sqrt((p.x - other.x) ^ 2 + (p.z - other.z) ^ 2) < planters.clear then
					free = false
					break
				end
			end
			if free then
				spot += 1
				local kind = planters.pattern[(spot - 1) % #planters.pattern + 1]
				local models = if kind == "bush" then planters.bushes else planters.flowers
				table.insert(plants, {
					kind = kind,
					model = models[(spot - 1) % #models + 1],
					x = p.x,
					z = p.z,
					height = if kind == "bush" then planters.bushHeight else planters.flowerHeight,
					yaw = (spot * 137) % 360,
				})
			end
		end
	end
	return plants
end

-- The sag of a Beam whose two attachments point straight down: its cubic Bezier's middle drops 0.75 x CurveSize, so
-- the wire's CurveSize for a given sag
function PlazaLayout.curveFor(sag: number): number
	return sag / 0.75
end

-- Bulbs along a string light from a to b that sags `sag` studs in the middle, one every `spacing` studs (ends left out).
-- The same curve the wire's Beam draws (attachments pointing down, CurveSize = curveFor(sag)).
function PlazaLayout.stringLight(a: Vec, b: Vec, sag: number, spacing: number): { Vec }
	local c = PlazaLayout.curveFor(sag)
	local p1 = { x = a.x, y = a.y - c, z = a.z }
	local p2 = { x = b.x, y = b.y - c, z = b.z }
	local length = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2 + (b.z - a.z) ^ 2)
	local count = math.max(1, math.floor(length / spacing))
	local bulbs = {}
	for index = 1, count - 1 do
		local t = index / count
		local u = 1 - t
		local function axis(k: string): number
			return u * u * u * (a :: any)[k] + 3 * u * u * t * (p1 :: any)[k] + 3 * u * t * t * (p2 :: any)[k] + t * t * t * (b :: any)[k]
		end
		table.insert(bulbs, { x = axis("x"), y = axis("y"), z = axis("z") })
	end
	return bulbs
end

return PlazaLayout
