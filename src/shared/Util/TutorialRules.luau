--!strict
-- The first visit's progress (spec 2026-11-09-tutorial-pish-design 5, 6, 9): the saved tutorial table read safely, the
-- step that's current, steps done early waiting their turn, skipping and replaying (the gifts are never given twice).
-- Pure: `steps` is Config/Pish STEPS. Every function returns a new table; the one passed in is left alone.

export type Saved = {
	firstVisit: "todo" | "done" | "skipped",
	step: number, -- the current step's index (steps beyond the last: all done)
	early: { [string]: boolean }, -- steps the player did before their turn
	firstGiven: boolean, -- Pish's first pack was given
	giftClaimed: boolean, -- his end gift was given
	customerSent: boolean, -- the customer he sends at step 5 came (once ever; missing in a save reads false)
	lessons: { [string]: boolean }, -- lesson visits (Config/Pish LESSONS ids): true seen, false due and waiting
	pishLuckAt: number, -- os.time of the last luck from petting him (0: never)
}

local TutorialRules = {}

local VISITS = { todo = true, done = true, skipped = true }

local function copy(saved: Saved): Saved
	local early, lessons = {}, {}
	for id, value in saved.early do
		early[id] = value
	end
	for id, value in saved.lessons do
		lessons[id] = value
	end
	return {
		firstVisit = saved.firstVisit,
		step = saved.step,
		early = early,
		firstGiven = saved.firstGiven,
		giftClaimed = saved.giftClaimed,
		customerSent = saved.customerSent,
		lessons = lessons,
		pishLuckAt = saved.pishLuckAt,
	}
end

-- A saved table made safe: a missing first visit is a new player's ("todo"); anything else unknown counts as done, so
-- nobody is ever forced through it by bad data
function TutorialRules.read(raw: any, steps: { string }): Saved
	local data = if typeof(raw) == "table" then raw else {}
	local visit = data.firstVisit
	local firstVisit = if visit == nil then "todo" elseif typeof(visit) == "string" and VISITS[visit] then visit else "done"
	local step = data.step
	local whole = typeof(step) == "number" and step == math.floor(step) and step >= 1
	local known = {}
	for _, id in steps do
		known[id] = true
	end
	local early = {}
	if typeof(data.early) == "table" then
		for id, value in data.early do
			if known[id] and value == true then
				early[id] = true
			end
		end
	end
	local lessons = {}
	if typeof(data.lessons) == "table" then
		for id, value in data.lessons do
			if typeof(id) == "string" and typeof(value) == "boolean" then
				lessons[id] = value -- false: due, waiting to be shown (Util/LessonRules.pending)
			end
		end
	end
	local luckAt = data.pishLuckAt
	return {
		firstVisit = firstVisit :: any,
		step = if whole then math.min(step, #steps) else 1,
		early = early,
		firstGiven = data.firstGiven == true,
		giftClaimed = data.giftClaimed == true,
		customerSent = data.customerSent == true,
		lessons = lessons,
		pishLuckAt = if typeof(luckAt) == "number" and luckAt >= 0 and luckAt < math.huge then luckAt else 0,
	}
end

-- The step to do now (nil when the first visit isn't on)
function TutorialRules.current(saved: Saved, steps: { string }): string?
	if saved.firstVisit ~= "todo" then
		return nil
	end
	return steps[saved.step]
end

-- The player did `stepId`: the current one completes (and any done early right after it); a later one waits its
-- turn; one already passed changes nothing. Returns the new state and the steps completed now, in order.
function TutorialRules.record(saved: Saved, steps: { string }, stepId: string): (Saved, { string })
	local after = copy(saved)
	local done = {}
	if after.firstVisit ~= "todo" then
		return after, done
	end
	local index = table.find(steps, stepId)
	if not index or index < after.step then
		return after, done
	end
	if index > after.step then
		after.early[stepId] = true
		return after, done
	end
	table.insert(done, stepId)
	after.step += 1
	while steps[after.step] and after.early[steps[after.step]] do
		local id = steps[after.step]
		after.early[id] = nil
		table.insert(done, id)
		after.step += 1
	end
	return after, done
end

-- Skipped: it ends where it was (the step stays, for the funnel)
function TutorialRules.skip(saved: Saved): Saved
	local after = copy(saved)
	after.firstVisit = "skipped"
	after.early = {}
	return after
end

-- Played again from the start (the Pish button): the gifts already given stay given
function TutorialRules.replay(saved: Saved): Saved
	local after = copy(saved)
	after.firstVisit = "todo"
	after.step = 1
	after.early = {}
	return after
end

-- Pish sends his own customer (step "customer") once ever: a skip and a replay, however often, wait for a customer
-- who comes by themselves, so replaying never brings anything for free (final review I1)
function TutorialRules.sendsCustomer(saved: Saved): boolean
	return not saved.customerSent
end

function TutorialRules.customerSent(saved: Saved): Saved
	local after = copy(saved)
	after.customerSent = true
	return after
end

function TutorialRules.finish(saved: Saved): Saved
	local after = copy(saved)
	after.firstVisit = "done"
	after.early = {}
	return after
end

-- What the server sees of the player's shop and Bag when a step becomes the one to do
export type ShopFacts = { firstPackHeld: boolean, giftHeld: boolean, ownsRack: boolean, shelvesStocked: boolean }

-- A step done before it came up (a replay, an old save) completes at once: Pish's pack or gift given before and no
-- longer in the Bag (they're never given twice), a rack already built, shelves already stocked
function TutorialRules.doneAlready(saved: Saved, stepId: string, facts: ShopFacts): boolean
	if stepId == "giftPack" then
		return saved.firstGiven and not facts.firstPackHeld
	elseif stepId == "gift" then
		return saved.giftClaimed and not facts.giftHeld
	elseif stepId == "buildRack" then
		return facts.ownsRack
	elseif stepId == "stockRack" then
		return facts.shelvesStocked
	end
	return false
end

return TutorialRules
