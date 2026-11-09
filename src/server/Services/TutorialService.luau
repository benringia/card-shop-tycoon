--!strict
-- The first visit with Pish, on the server (spec 2026-11-09-tutorial-pish-design 5, 6, 9, 11): each player's saved
-- tutorial table (Util/TutorialRules), the step they're on (player attribute TutorialStep, "" when none; TutorialDone
-- once it's done or skipped), steps completed from what the game sees them do (a pack opened, the rack placed, stock
-- ordered and shelved, a customer at the counter, the sale, the gift opened, Pish's goodbye), Pish's two gifts (his
-- first pack and the end gift, each once), the customer he sends, and the onboarding funnel. The client's Pish and cues
-- read the attributes (Client/Controllers/TutorialController). It starts once the welcome flight is over
-- (SeenWelcome). Saves Pish's luck time too (PishService keeps it while they play).
-- Lesson visits (spec 8): a level-up marks the lessons it unlocks as waiting (saved false in `lessons`, so ones gained
-- in the Frontier or the Dungeon, StartLessonsOnly, wait for the town); the client shows them when the player is free
-- and says when each is done. The stuck helper: a new player's first hour, Pish comes to point at what to do next.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pish = require(Shared:WaitForChild("Config"):WaitForChild("Pish"))
local LessonRules = require(Shared:WaitForChild("Util"):WaitForChild("LessonRules"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PackService = require(Services:WaitForChild("PackService"))
local PishService = require(Services:WaitForChild("PishService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local StockService = require(Services:WaitForChild("StockService"))

type Saved = TutorialRules.Saved

local TutorialService = {}

local ACTION_COOLDOWN = 0.5 -- seconds between TutorialAction requests
local ACTIONS = { skip = true, replay = true, bye = true, lessonShown = true, lessonDone = true }
local STUCK_CHECK = 10 -- seconds between stuck checks

local STEPS = Pish.STEPS
local LESSON_IDS: { [string]: boolean } = {}
for _, lesson in Pish.LESSONS do
	LESSON_IDS[lesson.id] = true
end

local inTown = false -- Start (the main game) rather than StartLessonsOnly
local states: { [Player]: Saved } = {}
local begun: { [Player]: boolean } = {} -- the first visit is running (the welcome flight is over)
local newcomers: { [Player]: number } = {} -- os.clock() a new player (first visit not done at load) joined
local lastActive: { [Player]: number } = {} -- os.clock() of their last order, restock, sale or opened pack
local lastNudge: { [Player]: number } = {}
local allowAction = RateLimiter.new(ACTION_COOLDOWN)

local function log(callback: () -> ())
	-- Analytics never stops the game (it can't be reached in some Studio sessions)
	pcall(callback)
end

local function publish(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local step = if begun[player] then TutorialRules.current(state, STEPS) else nil
	player:SetAttribute("TutorialStep", step or "")
	player:SetAttribute("TutorialDone", state.firstVisit ~= "todo")
	Remotes.TutorialState:FireClient(player, {
		firstVisit = state.firstVisit,
		step = state.step,
		giftClaimed = state.giftClaimed,
		lessons = LessonRules.pending(Pish.LESSONS, state.lessons), -- waiting to be shown, in level order
	})
end

local function logLesson(player: Player, event: string, lessonId: string)
	log(function()
		AnalyticsService:LogCustomEvent(player, event, 0, { [Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = lessonId })
	end)
end

-- A level-up marks the lessons it unlocks as waiting (in the town the client is told at once)
local function queueLessons(player: Player, fromLevel: number, toLevel: number, tell: boolean)
	local state = states[player]
	if not state then
		return
	end
	local due = LessonRules.due(Pish.LESSONS, fromLevel, toLevel, state.lessons)
	if #due == 0 then
		return
	end
	for _, id in due do
		state.lessons[id] = false
	end
	if tell then
		publish(player)
	end
end

local function markActive(player: Player)
	lastActive[player] = os.clock()
end

-- The stuck helper: a new player past the first visit, quiet a while with a box waiting or nothing on the shelves
local function checkStuck(player: Player)
	local state = states[player]
	local joined = newcomers[player]
	if not state or not joined or state.firstVisit == "todo" then
		return
	end
	local now = os.clock()
	local kind = LessonRules.nudge(Pish.STUCK, {
		played = now - joined,
		quiet = now - (lastActive[player] or joined),
		sinceNudge = now - (lastNudge[player] or -math.huge),
		boxWaiting = StockService.HasWaitingBox(player),
		shelvesStocked = StockService.ShelvesStocked(player),
	})
	if kind then
		lastNudge[player] = now
		Remotes.TutorialState:FireClient(player, { nudge = kind })
	end
end

local function ownsRack(player: Player): boolean
	for _, shelf in PlacementService.GetShelves(player) do
		if shelf.def.id == Pish.RACK then
			return true
		end
	end
	return false
end

local record: (player: Player, stepId: string) -> ()

-- What happens as a step becomes the one to do: Pish's gifts (each once), the customer he sends; a step the shop has
-- already done (a replay with racks and stock) completes straight away
local function enter(player: Player, stepId: string)
	local state = states[player]
	if not state then
		return
	end
	if stepId == "giftPack" and not state.firstGiven then
		state.firstGiven = true
		ItemService.GiveItem(player, Pish.FIRST_ITEM, 1)
	elseif stepId == "buildRack" and ownsRack(player) then
		task.defer(record, player, "buildRack")
	elseif stepId == "stockRack" and StockService.ShelvesStocked(player) then
		task.defer(record, player, "stockRack")
	elseif stepId == "customer" then
		CustomerService.SpawnForTest(player, "plain")
	elseif stepId == "gift" and not state.giftClaimed then
		state.giftClaimed = true
		ItemService.GiveItem(player, Pish.GIFT_ITEM, 1)
		log(function()
			AnalyticsService:LogCustomEvent(player, "PishGiftClaimed")
		end)
	end
end

record = function(player: Player, stepId: string)
	local state = states[player]
	if not state then
		return
	end
	local after, done = TutorialRules.record(state, STEPS, stepId)
	states[player] = after
	if #done == 0 then
		return -- nothing completed (a step for later, one already passed, or not in the tutorial): nothing to send
	end
	for _, id in done do
		local index = table.find(STEPS, id) :: number
		log(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, index, id)
		end)
	end
	if after.firstVisit == "todo" and after.step > #STEPS then
		states[player] = TutorialRules.finish(after)
	end
	publish(player)
	local current = if begun[player] then TutorialRules.current(states[player], STEPS) else nil
	if current then
		enter(player, current)
	end
end

-- Starts (or resumes) the first visit once the welcome flight is over
local function begin(player: Player)
	local state = states[player]
	if not state or begun[player] or player:GetAttribute("SeenWelcome") ~= true then
		return
	end
	begun[player] = true
	publish(player)
	local current = TutorialRules.current(state, STEPS)
	if current then
		enter(player, current)
	end
end

local function onAction(player: Player, action: unknown, lessonId: unknown, used: unknown)
	if not allowAction(player) or typeof(action) ~= "string" or not ACTIONS[action] then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if action == "skip" and state.firstVisit == "todo" then
		states[player] = TutorialRules.skip(state)
		log(function()
			AnalyticsService:LogCustomEvent(player, "TutorialSkipped", state.step)
		end)
		publish(player)
	elseif action == "replay" and state.firstVisit ~= "todo" then
		states[player] = TutorialRules.replay(state)
		begun[player] = nil
		begin(player)
	elseif action == "bye" then
		record(player, "bye")
	elseif typeof(lessonId) ~= "string" or not LESSON_IDS[lessonId] or state.lessons[lessonId] ~= false then
		return -- the lesson actions below are only for a lesson waiting to be shown
	elseif action == "lessonShown" then
		logLesson(player, "LessonShown", lessonId)
	elseif action == "lessonDone" then
		TutorialService.LessonDone(player, lessonId, used == true)
	end
end

-- A lesson visit is over (it left after LESSON_SECONDS, or the player used the new thing): never shown again
function TutorialService.LessonDone(player: Player, lessonId: string, used: boolean)
	local state = states[player]
	if not state or state.lessons[lessonId] ~= false then
		return
	end
	state.lessons[lessonId] = true
	if used then
		logLesson(player, "LessonUsed", lessonId)
	end
	publish(player)
end

-- Studio's /tutorial lesson <id>: that lesson waits to be shown again
function TutorialService.QueueLesson(player: Player, lessonId: string)
	local state = states[player]
	if state and LESSON_IDS[lessonId] then
		state.lessons[lessonId] = false
		publish(player)
	end
end

function TutorialService.GetState(player: Player): Saved?
	return states[player]
end

-- Studio's /tutorial reset: a new player's first visit (gifts not given yet)
function TutorialService.Reset(player: Player)
	if not states[player] then
		return
	end
	states[player] = TutorialRules.read({}, STEPS)
	begun[player] = nil
	begin(player)
	publish(player)
end

-- Studio's /tutorial step <n>: jump to a step
function TutorialService.SetStep(player: Player, step: number)
	local state = states[player]
	if not state then
		return
	end
	local after = TutorialRules.replay(state)
	after.step = math.clamp(math.floor(step), 1, #STEPS)
	states[player] = after
	begun[player] = nil
	begin(player)
	publish(player)
end

local function load(player: Player, data: DataService.PlayerData)
	local state = TutorialRules.read(data.tutorial, STEPS)
	states[player] = state
	PishService.SetLuckAt(player, state.pishLuckAt)
	local untilTime = state.pishLuckAt + Pish.LUCK.seconds
	if state.pishLuckAt > 0 and untilTime > os.time() then
		player:SetAttribute("PishLuckUntil", untilTime)
		PackService.SetLuck(player, untilTime)
	end
	if not inTown then
		return -- the Frontier or the Dungeon: lessons are only marked here (StartLessonsOnly)
	end
	if state.firstVisit == "todo" then
		newcomers[player] = os.clock()
	end
	publish(player)
	begin(player)
end

local function save(player: Player, data: DataService.PlayerData)
	local state = states[player]
	if not state then
		return -- never loaded: keep what's saved
	end
	data.tutorial = {
		firstVisit = state.firstVisit,
		step = state.step,
		early = table.clone(state.early),
		firstGiven = state.firstGiven,
		giftClaimed = state.giftClaimed,
		lessons = table.clone(state.lessons),
		pishLuckAt = PishService.GetLuckAt(player),
	}
end

local function unload(player: Player)
	states[player] = nil
	begun[player] = nil
	newcomers[player] = nil
	lastActive[player] = nil
	lastNudge[player] = nil
end

-- The Frontier and the Dungeon: only the saved table (kept as it is) and the lessons a level-up there unlocks, marked
-- waiting for the town
function TutorialService.StartLessonsOnly()
	DataService.Register({ name = "TutorialService", load = load, save = save, unload = unload })
	EconomyService.OnLevelUp(function(player, fromLevel, toLevel)
		queueLessons(player, fromLevel, toLevel, false)
	end)
end

function TutorialService.Start()
	inTown = true
	DataService.Register({ name = "TutorialService", load = load, save = save, unload = unload })
	Remotes.TutorialAction.OnServerEvent:Connect(onAction)
	EconomyService.OnLevelUp(function(player, fromLevel, toLevel)
		queueLessons(player, fromLevel, toLevel, true)
	end)
	task.spawn(function()
		while true do
			task.wait(STUCK_CHECK)
			for player in newcomers do
				checkStuck(player)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("SeenWelcome"):Connect(function()
			begin(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("SeenWelcome"):Connect(function()
			begin(player)
		end)
	end

	PackService.OnOpened(function(player, _, itemId)
		markActive(player)
		if itemId == Pish.FIRST_ITEM then
			record(player, "giftPack")
		elseif itemId == Pish.GIFT_ITEM then
			record(player, "gift")
		end
	end)
	PlacementService.OnPlaced(function(player, shelfId)
		if shelfId == Pish.RACK then
			record(player, "buildRack")
		end
	end)
	StockService.OnOrdered(function(player, productId)
		markActive(player)
		if productId == Pish.ORDER_PRODUCT then
			record(player, "orderStock")
		end
	end)
	StockService.OnStocked(function(player)
		markActive(player)
		record(player, "stockRack")
	end)
	CustomerService.OnReachedCounter(function(customer)
		record(customer.owner, "customer")
	end)
	RegisterService.OnSaleCompleted(function(customer)
		markActive(customer.owner)
		record(customer.owner, "ringUp")
	end)
end

return TutorialService
