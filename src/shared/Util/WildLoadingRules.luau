--!strict
-- The Wild's loading screen's progress (Config/WildLoading; owner 2026-11-05: "make sure everything is loaded before
-- player can walk in"): which step it's on, how full the bar is and whether it can close. Pure (callers pass the
-- config in), so tests/ can run it in Lune.
local WildLoadingRules = {}

-- ground: you've arrived and there's ground under you; scenery: the valley round you has its meshes and textures;
-- monsters: the monsters' models; sounds: the area's music and ambience
export type Status = { ground: boolean, scenery: boolean, monsters: boolean, sounds: boolean }

-- Each step and what it waits for, in Config/WildLoading STEPS order
WildLoadingRules.ORDER = { "ground", "scenery", "monsters", "sounds" }

-- arrivedFor: seconds since you arrived in the valley (nil: still on the way); shownFor: seconds the screen has been up.
-- Returns (step 1-4, or 5 once all are in; the bar's share; finished: it may close). The step follows the first thing
-- still loading. It closes once everything is in and it has been up MIN_SECONDS, MAX_SECONDS after you arrived
-- whatever is left, or after WAIT_SECONDS if you never arrive.
-- The sounds the trip loads (and keeps loaded a while): the arrival area's music and ambience, and every boss arena's
-- battle music and ambience (owner 2026-11-09: "make sure all effects/models etc are loaded before any fight starts"),
-- each once
function WildLoadingRules.sounds(music: any, wildValley: any): { string }
	local list: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(id: any)
		if typeof(id) == "string" and string.sub(id, 1, 13) == "rbxassetid://" and not seen[id] then
			seen[id] = true
			table.insert(list, id)
		end
	end
	local arrival = music.WILD.areas[1]
	add(arrival.tracks[1])
	add(arrival.ambient and arrival.ambient.id)
	for _, arena in music.WILD.arenas do
		add(arena.tracks[1])
	end
	for _, dressing in wildValley.ARENA_DRESSING do
		add(dressing.sound and dressing.sound.id)
	end
	return list
end

function WildLoadingRules.progress(status: Status, arrivedFor: number?, shownFor: number, cfg: any): (number, number, boolean)
	local order = WildLoadingRules.ORDER
	local step = #order + 1
	for index, key in order do
		if arrivedFor == nil or not (status :: any)[key] then
			step = index
			break
		end
	end
	local share = (step - 1) / #order
	if arrivedFor == nil then
		return step, share, shownFor >= cfg.WAIT_SECONDS
	end
	local loaded = step > #order and shownFor >= cfg.MIN_SECONDS
	return step, share, loaded or arrivedFor >= cfg.MAX_SECONDS
end

return WildLoadingRules
