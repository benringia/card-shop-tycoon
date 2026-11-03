--!strict
-- The loading screen's progress (Config/LoadingScreen): which step it's on, how full the bar is, whether it's done and
-- whether a slow save gets its note. Pure (callers pass the config in), so tests/ can run it in Lune.
local LoadingRules = {}

-- art: your own cards' paintings have downloaded (the binder opens with every face drawn); shop: the product models,
-- icons, pack fronts, covers and effect textures a first window shows (round 4: nothing pops in after the screen)
export type Status = { character: boolean, data: boolean, art: boolean, shop: boolean, creature: boolean, gear: boolean }

-- Each step and what it waits for: the cards step is the save and your cards' paintings
local ORDER = { { "character" }, { "data", "art" }, { "shop" }, { "creature" }, { "gear" } }

-- (step 1-4, or 5 once all are done; the bar's share; done: all done or out of time; slow: the save still loading
-- after SLOW_SECONDS). The bar follows the first step not done, so a later one finishing early doesn't jump it ahead.
function LoadingRules.progress(status: Status, elapsed: number, cfg: any): (number, number, boolean, boolean)
	local step = #ORDER + 1
	for index, keys in ORDER do
		for _, key in keys do
			if not (status :: any)[key] then
				step = index
				break
			end
		end
		if step == index then
			break
		end
	end
	local done = step > #ORDER or elapsed >= cfg.MAX_SECONDS
	local slow = not status.data and elapsed >= cfg.SLOW_SECONDS
	return step, (step - 1) / #ORDER, done, slow
end

-- Whether every fetch has finished one way or another (Enum.AssetFetchStatus names): a failed or timed-out asset
-- counts as done, so one bad id can't hold the screen for MAX_SECONDS on every join
function LoadingRules.settled(statuses: { string }): boolean
	for _, status in statuses do
		if status ~= "Success" and status ~= "Failure" and status ~= "TimedOut" then
			return false
		end
	end
	return true
end

-- The card ids in a CollectionChanged payload: its plain stacks' and its individual cards', each once
function LoadingRules.ownedCardIds(payload: any): { string }
	local ids, seen = {}, {}
	local function add(id: any)
		if typeof(id) == "string" and not seen[id] then
			seen[id] = true
			table.insert(ids, id)
		end
	end
	if typeof(payload) ~= "table" then
		return ids
	end
	if typeof(payload.stacks) == "table" then
		for id in payload.stacks do
			add(id)
		end
	end
	if typeof(payload.beasts) == "table" then
		for _, beast in payload.beasts do
			if typeof(beast) == "table" then
				add(beast.cardId)
			end
		end
	end
	return ids
end

-- The words for a step; the first is the place's own ("Opening your shop..." in the main game)
function LoadingRules.stepText(step: number, placeKind: string, cfg: any): string
	if step > #cfg.STEPS then
		return cfg.READY
	elseif step == 1 and cfg.FIRST_STEP[placeKind] then
		return cfg.FIRST_STEP[placeKind]
	end
	return cfg.STEPS[step]
end

return LoadingRules
