--!strict
-- The first visit with Pish, on the server (spec 2026-11-09-tutorial-pish-design 5, 6, 9, 11): each player's saved
-- tutorial table (Util/TutorialRules), the step they're on (player attribute TutorialStep, "" when none; TutorialDone
-- once it's done or skipped), steps completed from what the game sees them do (a pack opened, the rack placed, stock
-- ordered and shelved, a customer at the counter, the sale, the gift opened, Pish's goodbye), Pish's two gifts (his
-- first pack and the end gift, each once), the customer he sends, and the onboarding funnel. The client's Pish and cues
-- read the attributes (Client/Controllers/TutorialController). It starts once the welcome flight is over
-- (SeenWelcome). Saves Pish's luck time too (PishService keeps it while they play).
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Pish = require(Shared:WaitForChild("Config"):WaitForChild("Pish"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local DataService = require(Services:WaitForChild("DataService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PackService = require(Services:WaitForChild("PackService"))
local PishService = require(Services:WaitForChild("PishService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local StockService = require(Services:WaitForChild("StockService"))

type Saved = TutorialRules.Saved

local TutorialService = {}

local ACTION_COOLDOWN = 0.5 -- seconds between TutorialAction requests
local ACTIONS = { skip = true, replay = true, bye = true, lessonDone = true }

local STEPS = Pish.STEPS
local states: { [Player]: Saved } = {}
local begun: { [Player]: boolean } = {} -- the first visit is running (the welcome flight is over)
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
	Remotes.TutorialState:FireClient(player, { firstVisit = state.firstVisit, step = state.step, giftClaimed = state.giftClaimed })
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

local function onAction(player: Player, action: unknown, lessonId: unknown)
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
	elseif action == "lessonDone" and typeof(lessonId) == "string" and #lessonId <= 40 then
		TutorialService.LessonDone(player, lessonId)
	end
end

-- A lesson visit was seen (Task 9 fills the lesson queue in)
function TutorialService.LessonDone(player: Player, lessonId: string)
	local state = states[player]
	if state then
		state.lessons[lessonId] = true
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
end

function TutorialService.Start()
	DataService.Register({ name = "TutorialService", load = load, save = save, unload = unload })
	Remotes.TutorialAction.OnServerEvent:Connect(onAction)
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
		if productId == Pish.ORDER_PRODUCT then
			record(player, "orderStock")
		end
	end)
	StockService.OnStocked(function(player)
		record(player, "stockRack")
	end)
	CustomerService.OnReachedCounter(function(customer)
		record(customer.owner, "customer")
	end)
	RegisterService.OnSaleCompleted(function(customer)
		record(customer.owner, "ringUp")
	end)
end

return TutorialService
