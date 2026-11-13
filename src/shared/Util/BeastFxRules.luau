--!strict
-- Maths for the creatures' element auras (Util/BeastAura on the client): which bones carry it so it covers the whole
-- body, how much of it this screen shows (the budget), the Divine halo's ring and orbs. Points are plain { x, y, z }
-- tables. Pure, Lune-tested.
export type Point = { number }
-- How much of its aura a creature shows on this screen: `rate` times its tier's particles, and which extras
export type Shown = { rate: number, ground: boolean, light: boolean, dust: boolean, embers: boolean, halo: boolean }

local BeastFxRules = {}

local function distance(a: Point, b: Point): number
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Up to `count` indexes into `points`, spread as far apart as possible: the point furthest from the middle first,
-- then each time the one furthest from all picked so far
function BeastFxRules.spread(points: { Point }, count: number): { number }
	local total = #points
	if total == 0 or count <= 0 then
		return {}
	end
	local middle = { 0, 0, 0 }
	for _, point in points do
		middle = { middle[1] + point[1] / total, middle[2] + point[2] / total, middle[3] + point[3] / total }
	end
	local nearest: { number } = {}
	for index, point in points do
		nearest[index] = distance(point, middle)
	end
	local picked: { number } = {}
	for _ = 1, math.min(count, total) do
		local best, bestGap = 0, -1
		for index, gap in nearest do
			if gap > bestGap then
				best, bestGap = index, gap
			end
		end
		table.insert(picked, best)
		for index, point in points do
			nearest[index] = math.min(nearest[index], distance(point, points[best]))
		end
		nearest[best] = -1
	end
	return picked
end

-- The bone on the other side of the body: Left and Right swapped in its name ("Ear_Left_0" -> "Ear_Right_0"), nil for
-- a bone on the middle line
function BeastFxRules.mirrorName(name: string): string?
	if string.find(name, "Left", 1, true) then
		return (string.gsub(name, "Left", "Right"))
	elseif string.find(name, "Right", 1, true) then
		return (string.gsub(name, "Right", "Left"))
	end
	return nil
end

-- `picked` (indexes into `names`) plus the mirror of every picked side bone that has one, so the fire burns on both
-- ears, both feet, never just one; no index twice
function BeastFxRules.withMirrors(names: { string }, picked: { number }): { number }
	local byName: { [string]: number } = {}
	for index, name in names do
		byName[name] = index
	end
	local out, seen = {}, {}
	local function add(index: number)
		if not seen[index] then
			seen[index] = true
			table.insert(out, index)
		end
	end
	for _, index in picked do
		add(index)
		local mirror = BeastFxRules.mirrorName(names[index])
		if mirror and byName[mirror] then
			add(byName[mirror])
		end
	end
	return out
end

-- The aura tier a copy wears (Config/BeastFx BY_RARITY): by its card's rarity and grade; nil for none
function BeastFxRules.tier(cfg: any, rarity: string, grade: string?): string?
	local row = cfg.BY_RARITY[rarity]
	if not row then
		return nil
	end
	return (if grade then row[grade] else nil) or row.any
end

-- The size an aura's effects are drawn at for a creature of `size` (height / 3 studs) wearing `tier`: never under
-- cfg.MIN_SCALE, so a small creature's aura still shows
function BeastFxRules.scale(cfg: any, size: number, tier: any): number
	return math.max(size, cfg.MIN_SCALE) * tier.size
end

-- How much of its tier's aura a creature shows here (owner 2026-11-13: "pets that glows alot on boss battles specially
-- on full party I think will be heavy", "Light touch" for others, "without affecting flexing too much"): your own, and
-- another player's outside your boss fight, all of it; another player's in your boss fight (`bossFight`) `others` of
-- its particles, without ground flames, light, dust or embers (its look and a Divine halo kept); with low graphics or a
-- struggling frame rate (`low`) `low` of them, yours too. `tier` is a Config/BeastFx TIERS entry, `budget` its BUDGET
function BeastFxRules.budget(tier: any, budget: any, mine: boolean, bossFight: boolean, low: boolean): Shown
	local shown: Shown = {
		rate = 1,
		ground = tier.ground == true,
		light = true,
		dust = tier.dust == true,
		embers = tier.divine == true,
		halo = tier.divine == true,
	}
	local cuts = {}
	if bossFight and not mine then
		table.insert(cuts, budget.others)
	end
	if low then
		table.insert(cuts, budget.low)
	end
	for _, cut in cuts do
		shown.rate *= cut.rate
		shown.ground = shown.ground and cut.ground
		shown.light = shown.light and cut.light
		shown.dust = shown.dust and cut.dust
		shown.embers = shown.embers and cut.embers
	end
	return shown
end

-- `count` points evenly round a flat circle of `radius`, turned `angle` radians: { x, y } in the circle's plane
-- (a grade S Legendary's halo of flames)
function BeastFxRules.ring(count: number, radius: number, angle: number): { { number } }
	local points = {}
	for index = 0, count - 1 do
		local at = angle + index * 2 * math.pi / count
		table.insert(points, { math.cos(at) * radius, math.sin(at) * radius })
	end
	return points
end

-- Where orb `index` of `count` circling a creature is at `time`: { x, y, z } from its feet, evenly spaced round a
-- circle of `radius` at `height`, one lap every `seconds`, bobbing up and down by `bob`
function BeastFxRules.orbit(index: number, count: number, time: number, seconds: number, radius: number, height: number, bob: number): Point
	local at = 2 * math.pi * (time / seconds + (index - 1) / count)
	return { math.cos(at) * radius, height + math.sin(at * 2 + index) * bob, math.sin(at) * radius }
end

return BeastFxRules
