--!strict
-- Chikin's combat tutorial on the server (spec docs/superpowers/specs/2026-11-10-chikin-combat-tutorial-design.md), in
-- the main game: each player's saved table (data.combat, the same shape as Pish's, Util/TutorialRules on Config/Chikin
-- STEPS), the step they're on (player attributes CombatStep, "" when none, and CombatDone), and steps completed from
-- what the game sees: a card in the party, a creature summoned, the player in the Wild valley, a wild fight over (won,
-- lost, run from or timed out; the result in ChikinFightResult), shop level 4, and his hellos and goodbyes ended by
-- their last Next (the client's "next"). It begins once Pish's first visit is over (done or skipped) and the welcome
-- flight has played. Skip ends it; the peeking Pish's card replays it. Nothing in it is a reward.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Chikin = require(Config:WaitForChild("Chikin"))
local WildValleyConfig = require(Config:WaitForChild("WildValley"))
local Bosses = require(Config:WaitForChild("Bosses"))
local TutorialRules = require(Shared:WaitForChild("Util"):WaitForChild("TutorialRules"))
local WildValley = require(Shared:WaitForChild("Util"):WaitForChild("WildValley"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local TownChikinService = require(Services:WaitForChild("TownChikinService"))

type Saved = TutorialRules.Saved

local CombatTutorialService = {}

local ACTION_COOLDOWN = 0.5 -- seconds between CombatTutorialAction requests
local ACTIONS = { next = true, skip = true, replay = true }
local FUNNEL = "CombatTutorial"

local STEPS = Chikin.STEPS
local states: { [Player]: Saved } = {}
local begun: { [Player]: boolean } = {}
local allowAction = RateLimiter.new(ACTION_COOLDOWN)

local function log(callback: () -> ())
	pcall(callback) -- analytics never stops the game
end

-- Pish's first visit is on (a new player's, or replayed from the peeking Pish): Chikin stays out of it (final review I1)
local function pishLeading(player: Player): boolean
	local pish = TutorialService.GetState(player)
	return pish == nil or pish.firstVisit == "todo"
end

local function publish(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local step = if begun[player] and not pishLeading(player) then TutorialRules.current(state, STEPS) else nil
	player:SetAttribute("CombatStep", step or "")
	player:SetAttribute("CombatDone", state.firstVisit ~= "todo")
end

local function inWild(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local x, z = root.Position.X, root.Position.Z
	return WildValley.zoneAt(WildValleyConfig, { x = x, z = z }) ~= nil
		or WildValley.arenaZoneAt(WildValleyConfig, Bosses.ARENA_COPIES, x, z) ~= nil
end

-- A step done from what the game sees now: the party has a card, a creature is summoned, the player is in the Wild,
-- the shop is level 4 (a step that's already true when it comes up is done at once)
local function seenDone(player: Player, stepId: string): boolean
	if stepId == "party" or stepId == "summon" then
		local party = PartyService.GetParty(player)
		if not party then
			return false
		end
		return if stepId == "party" then next(party.slots) ~= nil else party.summoned ~= nil
	elseif stepId == "wild" or stepId == "wild2" then
		return inWild(player)
	elseif stepId == Chikin.WAIT_STEP then
		return EconomyService.GetLevel(player) >= Chikin.SWORD_LEVEL
	end
	return false
end

local function record(player: Player, stepId: string)
	local state = states[player]
	if not state then
		return
	end
	local after, done = TutorialRules.record(state, STEPS, stepId)
	states[player] = after
	if #done == 0 then
		return
	end
	for _, id in done do
		local index = table.find(STEPS, id) :: number
		log(function()
			AnalyticsService:LogFunnelStepEvent(player, FUNNEL, nil, index, id)
		end)
	end
	if after.firstVisit == "todo" and after.step > #STEPS then
		states[player] = TutorialRules.finish(after)
	end
	publish(player)
end

-- Starts (or resumes) the tour once Pish's first visit is over and the welcome flight has played
local function begin(player: Player)
	local state = states[player]
	if not state or begun[player] or player:GetAttribute("SeenWelcome") ~= true or pishLeading(player) then
		return
	end
	-- His first step is the party, so he waits for a card to put in it (Pish's tour skipped before his present was
	-- opened: final review I2)
	if next(CardService.GetOwnedCardIds(player)) == nil then
		return
	end
	begun[player] = true
	publish(player)
end

local function check(player: Player)
	begin(player)
	local state = states[player]
	if not state or not begun[player] then
		return
	end
	publish(player) -- Pish's replay starting or ending shows or hides his step
	if pishLeading(player) then
		return
	end
	local current = TutorialRules.current(state, STEPS)
	-- A new fight on a fight step: the last one's result is gone (the sword fight's "try another one" line clears)
	if (current == "fight" or current == "fight2") and BattleService.IsFighting(player) and player:GetAttribute("ChikinFightResult") ~= nil then
		player:SetAttribute("ChikinFightResult", nil)
	end
	-- His sword visit teaches what Pish's sword lesson would (one dog, not two)
	if current == "sword" then
		TutorialService.MarkLessonSeen(player, "sword")
	end
	if current and seenDone(player, current) then
		record(player, current)
	end
end

-- A wild fight over for this player: the fight step done, its result for his lines
local function fightOver(player: Player, result: string)
	local state = states[player]
	local current = if state and begun[player] then TutorialRules.current(state, STEPS) else nil
	if current == "fight" or current == "fight2" then
		player:SetAttribute("ChikinFightResult", result)
		if result == "win" or not Chikin.WIN_TO_PASS[current] then
			record(player, current)
		end
	end
end

local function onAction(player: Player, action: unknown)
	if not allowAction(player) or typeof(action) ~= "string" or not ACTIONS[action] then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	local current = if begun[player] then TutorialRules.current(state, STEPS) else nil
	if action == "next" then
		if current and Chikin.FINISH_STEPS[current] then
			record(player, current)
		end
	elseif action == "skip" and state.firstVisit == "todo" then
		states[player] = TutorialRules.skip(state)
		log(function()
			AnalyticsService:LogCustomEvent(player, "CombatTutorialSkipped", state.step)
		end)
		publish(player)
	elseif action == "replay" and state.firstVisit ~= "todo" then
		states[player] = TutorialRules.replay(state)
		begun[player] = nil
		begin(player)
	end
end

-- Studio's /chikin reset: a new player's tour; /chikin step <n>: that step
function CombatTutorialService.Reset(player: Player)
	if states[player] then
		states[player] = TutorialRules.read({}, STEPS)
		begun[player] = nil
		begin(player)
		publish(player)
	end
end

function CombatTutorialService.SetStep(player: Player, step: number)
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
	states[player] = TutorialRules.read(data.combat, STEPS)
	-- the shared table's pishLuckAt is Town Chikin's last Courage here (petting gives nothing until it's loaded)
	TownChikinService.SetCourageAt(player, states[player].pishLuckAt)
	publish(player)
	begin(player)
end

local function save(player: Player, data: DataService.PlayerData)
	local state = states[player]
	if not state then
		return -- never loaded: keep what's saved
	end
	data.combat = {
		firstVisit = state.firstVisit,
		step = state.step,
		early = table.clone(state.early),
		firstGiven = state.firstGiven,
		giftClaimed = state.giftClaimed,
		customerSent = state.customerSent,
		lessons = table.clone(state.lessons),
		pishLuckAt = TownChikinService.GetCourageAt(player),
	}
end

local function unload(player: Player)
	states[player] = nil
	begun[player] = nil
	TownChikinService.ForgetCourage(player)
end

function CombatTutorialService.Start()
	DataService.Register({ name = "CombatTutorialService", load = load, save = save, unload = unload })
	Remotes.CombatTutorialAction.OnServerEvent:Connect(onAction)
	BattleService.OnFightEnded(function(_monster, result, _hpLeft, stillIn)
		for _, player in stillIn do
			fightOver(player, result)
		end
	end)
	BattleService.OnMemberLeft(function(player)
		fightOver(player, "run")
	end)

	task.spawn(function()
		while true do
			task.wait(Chikin.CHECK_SECONDS)
			for player in states do
				if player.Parent then
					check(player)
				end
			end
		end
	end)
end

return CombatTutorialService
