--!strict
-- The Pet button moves' look choices (spec 2026-11-05-pet-moves-design), Roblox-free (Lune-tested): which grade's look
-- plays, and the vines' paths. `cfg` is Config/MoveFx.
local MoveFxRules = {}

local GRADES = { C = true, B = true, A = true, S = true }
local RANK = { C = 1, B = 2, A = 3, S = 4 }

-- The grade whose look plays: C for a creature with no grade (or an unknown one); with the low-graphics switch off
-- (`extrasOn` false), never richer than cfg.LOW_GRAPHICS_GRADE
function MoveFxRules.grade(grade: string?, extrasOn: boolean, cfg: any): string
	local picked = if grade and GRADES[grade] then grade else "C"
	local cap = cfg.LOW_GRAPHICS_GRADE
	if not extrasOn and RANK[picked] > RANK[cap] then
		return cap
	end
	return picked
end

-- One move's look ("RAIN", "VINES", "ORBS" or "CURSE") at the grade that plays
function MoveFxRules.look(cfg: any, move: string, grade: string?, extrasOn: boolean): any
	return cfg[move][MoveFxRules.grade(grade, extrasOn, cfg)]
end

-- How far from a target's axis its vines wind: just inside its box's half-width (bodies are rounder than their box),
-- or without a model a share of its height; between 0.9 and 14 studs
function MoveFxRules.wrapRadius(halfWidth: number?, height: number): number
	local radius = if halfWidth then halfWidth * 0.9 else height * 0.32
	return math.clamp(radius, 0.9, 14)
end

-- Vine `index` of `count` climbing round a target: `steps + 1` points on a helix of `radius` round its axis (the
-- origin), from the ground (y 0) up to `height`, starting `index / count` of a turn round and winding `turns` turns
function MoveFxRules.vinePath(index: number, count: number, height: number, radius: number, turns: number, steps: number): { { x: number, y: number, z: number } }
	local points = {}
	local start = index / count * 2 * math.pi
	for step = 0, steps do
		local t = step / steps
		local angle = start + turns * 2 * math.pi * t
		table.insert(points, { x = math.cos(angle) * radius, y = height * t, z = math.sin(angle) * radius })
	end
	return points
end

return MoveFxRules
