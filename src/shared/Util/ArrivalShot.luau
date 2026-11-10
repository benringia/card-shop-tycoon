--!strict
-- Pish's arrival shot (owner 2026-11-10: "the camera be first close to pish's feet while running then slowly panning to
-- his face then zoom out when he's already near you"): by how far into his run he is (0 to 1), where the close camera
-- sits beside him (`up`, `side`, `ahead` in studs from his feet, `lookUp` the height it looks at) and how far it has
-- zoomed out to the wide shot of the two of you (`wide`, 0 to 1). Pure: `cfg` is Config/Pish ARRIVAL.
export type Framing = { up: number, side: number, ahead: number, lookUp: number }
export type Config = {
	feet: Framing,
	face: Framing,
	panFrom: number,
	panTo: number,
	wideFrom: number,
	from: number,
	minRun: number,
	wallGap: number,
	wideClear: number,
}
export type Shot = { up: number, side: number, ahead: number, lookUp: number, wide: number }

local ArrivalShot = {}

-- 0 before `from`, 1 after `to`, eased in and out between
local function ease(value: number, from: number, to: number): number
	local t = math.clamp((value - from) / (to - from), 0, 1)
	return t * t * (3 - 2 * t)
end

function ArrivalShot.at(progress: number, cfg: Config): Shot
	local pan = ease(progress, cfg.panFrom, cfg.panTo)
	local function blend(key: string): number
		local a, b = (cfg.feet :: any)[key] :: number, (cfg.face :: any)[key] :: number
		return a + (b - a) * pan
	end
	return {
		up = blend("up"),
		side = blend("side"),
		ahead = blend("ahead"),
		lookUp = blend("lookUp"),
		wide = ease(progress, cfg.wideFrom, 1),
	}
end

-- Which way his run comes from: `clear` is how far each way (in the order to try, in front first) is free of walls
-- and shelves. The first way clear for the whole run plus `wallGap`, at `from`; else the longest, stopping `wallGap`
-- short of what's there (at least `minRun`). Returns its index and the run's length
function ArrivalShot.pickRun(clear: { number }, cfg: Config): (number, number)
	local longest, longestIndex = -math.huge, 1
	for index, length in clear do
		if length >= cfg.from + cfg.wallGap then
			return index, cfg.from
		end
		if length > longest then
			longest, longestIndex = length, index
		end
	end
	return longestIndex, math.max(cfg.minRun, longest - cfg.wallGap)
end

-- Which side of his run the camera rides on: 1 (the first side) unless the other has fewer things in the way
function ArrivalShot.pickSide(blockedFirst: number, blockedOther: number): number
	return if blockedOther < blockedFirst then -1 else 1
end

-- Which of the wide shot's angles to use: `free` is the share of each angle's view (in the order to try) clear of
-- walls; the first clear to `wideClear`, else the clearest
function ArrivalShot.pickWide(free: { number }, cfg: Config): number
	local best, bestIndex = -math.huge, 1
	for index, share in free do
		if share >= cfg.wideClear then
			return index
		end
		if share > best then
			best, bestIndex = share, index
		end
	end
	return bestIndex
end

return ArrivalShot
