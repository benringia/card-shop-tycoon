--!strict
-- Where the Card Festival Square's pieces stand (Config/Plaza): polar places round the spring, each piece's footprint
-- for the clearance tests, and the bulbs along a sagging string light. Pure, Lune-tested; Server/Util/PlazaBuild
-- builds from it.
export type Point = { x: number, z: number }
export type Vec = { x: number, y: number, z: number }
export type Footprint = { kind: string, x: number, z: number, radius: number }
-- A giant card: where its foot stands, how far it leans (degrees, + to the left), how far behind the middle it stands
export type FanCard = { x: number, z: number, width: number, height: number, lean: number, back: number, offset: number }

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
		add("potted tree", tree.angle, tree.r, cfg.PLANTER.radius)
	end
	return list
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
