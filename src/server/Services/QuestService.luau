--!strict
-- Daily quests (owner 2026-11-17: "yes do the three now"; Config/Quests, Util/QuestRules): three a day once Pish's first
-- visit is over (like the gifts), rolled for the shop's level each UTC day; what the player does counts toward them
-- (sales, packs ripped, boxes stocked, creature level-ups, fights won: heard from the services here) and a claim pays
-- cash and shop XP through EconomyService, the bonus chest's items through ItemService. Tells the client the day's
-- quests (Remotes.QuestState) and plays each claim's moment (Remotes.QuestClaim). Saved as data.quests. In every place:
-- fights in the Frontier and the Dungeon count too.
-- Weekly quests (owner 2026-11-17: "what players do after daily quests?", look A): three more for each Monday-to-Monday
-- UTC week, rolled the same way with goals a week long, counting the same play; all three done opens the Weekly Chest
-- (Config/Quests WEEKLY). Saved as data.weekly; sent with the day's (the view's `week`).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Quests = require(Config:WaitForChild("Quests"))
local Items = require(Config:WaitForChild("Items"))
local QuestRules = require(Shared:WaitForChild("Util"):WaitForChild("QuestRules"))
local GiftRules = require(Shared:WaitForChild("Util"):WaitForChild("GiftRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local Funnel = require(ServerUtil:WaitForChild("Funnel"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local QuestService = {}

local states: { [Player]: QuestRules.State } = {}
local weeks: { [Player]: QuestRules.Week } = {}
local playing: { [Player]: boolean } = {} -- their first visit is done: quests count
local watchers: { [Player]: RBXScriptConnection } = {}
local claimLimit = RateLimiter.new(0.4)
local askLimit = RateLimiter.new(1)
local rng = Random.new()

local REFUSALS = {
	notDone = "Finish this quest first, then claim it.",
	claimed = "You already claimed that one. New quests come tomorrow!",
	unknown = "That quest is gone. Here are today's.",
}
local WEEK_REFUSALS = {
	notDone = "Finish all three weekly quests to open the Weekly Chest.",
	claimed = "You opened this week's chest! New weekly quests come on Monday.",
}

local function today(): number
	return GiftRules.dayOf(os.time())
end

-- Monday-to-Monday UTC weeks, the gifts' weeks
local function thisWeek(): number
	return GiftRules.weekOf(today())
end

local function rolls(): { number }
	local list = {}
	for index = 1, #Quests.KINDS do
		list[index] = rng:NextNumber()
	end
	return list
end

-- Their first visit is done: the prologue seen and Pish's tutorial over (TutorialDone in the main game; the saved
-- tutorial elsewhere)
local function firstVisitDone(data: PlayerData): boolean
	local tutorial = data.tutorial :: any
	return data.seenPrologue == true and typeof(tutorial) == "table" and tutorial.firstVisit ~= "todo"
end

-- The day's quests and the week's to the client; `finished` / `weekFinished`: a quest that was just done (a toast)
local function send(player: Player, finished: number?, weekFinished: number?)
	local state, week = states[player], weeks[player]
	if not state or not week then
		return
	end
	local view: QuestRules.View? = nil
	if playing[player] then
		local made = QuestRules.view(state, Quests, EconomyService.GetLevel(player))
		made.week = QuestRules.weekView(week, Quests)
		view = made
	end
	Remotes.QuestState:FireClient(player, view, finished, weekFinished)
end

-- Today's quests and this week's: rolled for the shop's level on a new UTC day or week
local function refresh(player: Player)
	local state, week = states[player], weeks[player]
	if not state or not week then
		return
	end
	local level = EconomyService.GetLevel(player)
	local after = QuestRules.refresh(state, today(), Quests, level, rolls())
	local afterWeek = QuestRules.refreshWeek(week, thisWeek(), Quests, level, rolls())
	if after ~= state or afterWeek ~= week then
		states[player] = after
		weeks[player] = afterWeek
		send(player)
	end
end

-- Play counted toward today's quests and this week's (`event`: a Config/Quests EVENTS name); a quest it finishes is
-- told (a toast)
function QuestService.Add(player: Player, event: string, amount: number)
	local state, week = states[player], weeks[player]
	if not state or not week or not playing[player] then
		return
	end
	local after, done = QuestRules.add(state, Quests, event, amount)
	local afterWeek, weekDone = QuestRules.addWeek(week, Quests, event, amount)
	if after == state and afterWeek == week then
		return
	end
	states[player] = after
	weeks[player] = afterWeek
	send(player, done[1], weekDone[1])
end

local function grant(player: Player, cash: number, xp: number, items: { { item: string, count: number } })
	if cash > 0 then
		EconomyService.AddCash(player, cash)
	end
	if xp > 0 then
		EconomyService.AddXP(player, xp)
	end
	for _, entry in items do
		local given = ItemService.GiveItem(player, entry.item, entry.count)
		if given < entry.count then
			local info = Items.ITEMS[entry.item]
			Remotes.Notify:FireClient(player, `Your Bag is full: {entry.count - given} {if info then info.name else entry.item} didn't fit.`, true)
		end
	end
end

local function onClaim(player: Player, which: unknown)
	if not claimLimit(player) then
		return
	end
	local state = states[player]
	if not state then
		return
	end
	if not playing[player] then
		Blocked.tell(player, "Finish your first visit with Pish to start daily quests.", { title = "Quests" })
		return
	end
	if which == "week" then
		local week = weeks[player]
		if not week then
			return
		end
		local after, why = QuestRules.claimChest(week)
		if not after then
			Blocked.tell(player, WEEK_REFUSALS[why or "notDone"] or WEEK_REFUSALS.notDone, { title = "Weekly Quests" })
			return
		end
		weeks[player] = after
		grant(player, 0, 0, Quests.WEEKLY.CHEST)
		Remotes.QuestClaim:FireClient(player, "week", 0, 0, Quests.WEEKLY.CHEST)
		send(player)
		return
	end
	if which == "bonus" then
		local after, why = QuestRules.claimBonus(state)
		if not after then
			Blocked.tell(player, if why == "claimed" then "You opened today's Quest Chest! New quests come tomorrow." else "Claim all three quests to open the chest.", { title = "Quests" })
			return
		end
		states[player] = after
		grant(player, 0, 0, Quests.BONUS)
		Remotes.QuestClaim:FireClient(player, "bonus", 0, 0, Quests.BONUS)
		send(player)
		return
	end
	if typeof(which) ~= "number" or which ~= math.floor(which) then
		return
	end
	local after, why = QuestRules.claim(state, which)
	if not after then
		Blocked.tell(player, REFUSALS[why or "unknown"] or REFUSALS.unknown, { title = "Quests" })
		send(player)
		return
	end
	states[player] = after
	local pay = QuestRules.reward(Quests, EconomyService.GetLevel(player))
	grant(player, pay.cash, pay.xp, {})
	Funnel.step(player, "FirstQuestClaimed")
	Remotes.QuestClaim:FireClient(player, which, pay.cash, pay.xp, {})
	send(player)
end

local function load(player: Player, data: PlayerData)
	states[player] = QuestRules.clean(data.quests, Quests)
	weeks[player] = QuestRules.cleanWeek(data.weekly, Quests)
	playing[player] = firstVisitDone(data)
	-- Pish's tour ends while they play (main game): today's quests start now
	watchers[player] = player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		local done = player:GetAttribute("TutorialDone") == true
		if done ~= playing[player] then
			playing[player] = done
			send(player)
		end
	end)
	refresh(player)
	send(player)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their quests
local function save(player: Player, data: PlayerData)
	local state = states[player]
	if not state then
		return
	end
	local list = {}
	for index, quest in state.list do
		list[index] = table.clone(quest)
	end
	data.quests = { day = state.day, list = list, bonus = state.bonus }
	local week = weeks[player]
	if week then
		local weekList = {}
		for index, quest in week.list do
			weekList[index] = table.clone(quest)
		end
		data.weekly = { week = week.week, list = weekList, chest = week.chest }
	end
end

local function unload(player: Player)
	local watcher = watchers[player]
	if watcher then
		watcher:Disconnect()
		watchers[player] = nil
	end
	states[player] = nil
	weeks[player] = nil
	playing[player] = nil
end

-- Studio (/quests): `action` on `player`'s quests; the line to tell them, or nil for usage. done: every quest done;
-- new: a new day's quests now; week: every weekly quest done (the Weekly Chest ready); newweek: a new week's quests
function QuestService.Dev(player: Player, action: string): string?
	local state, week = states[player], weeks[player]
	if not state or not week then
		return nil
	end
	if action == "done" then
		local after = table.clone(state)
		after.list = {}
		for index, quest in state.list do
			after.list[index] = table.clone(quest)
			after.list[index].progress = quest.goal
		end
		states[player] = after
	elseif action == "new" then
		states[player] = QuestRules.refresh(QuestRules.fresh(), today(), Quests, EconomyService.GetLevel(player), rolls())
	elseif action == "week" then
		local after = table.clone(week)
		after.list = {}
		for index, quest in week.list do
			after.list[index] = table.clone(quest)
			after.list[index].progress = quest.goal
		end
		weeks[player] = after
	elseif action == "newweek" then
		weeks[player] = QuestRules.refreshWeek(QuestRules.freshWeek(), thisWeek(), Quests, EconomyService.GetLevel(player), rolls())
	else
		return nil
	end
	playing[player] = true
	send(player)
	return `Quests: {action} (Studio)`
end

function QuestService.Start()
	DataService.Register({ name = "QuestService", load = load, save = save, unload = unload })
	Remotes.QuestClaim.OnServerEvent:Connect(onClaim)
	Remotes.QuestState.OnServerEvent:Connect(function(player)
		if askLimit(player) then
			send(player) -- a client asking again (its tracker built before the state came)
		end
	end)
	-- What counts, from the game
	BattleService.OnFightEnded(function(monster: any, result: string, _hpLeft: any, stillIn: { Player })
		if result ~= "win" then
			return
		end
		for _, player in stillIn do
			QuestService.Add(player, if monster.boss then "winBoss" else "winWild", 1)
		end
	end)
	CardService.OnBeastLevelUp(function(player: Player, _beast: any, from: number, to: number)
		QuestService.Add(player, "levelCreature", to - from)
	end)
	if not Place.isFrontier() and not Place.isDungeon() then
		local RegisterService = require(Services:WaitForChild("RegisterService")) :: any
		local PackService = require(Services:WaitForChild("PackService")) :: any
		local StockService = require(Services:WaitForChild("StockService")) :: any
		RegisterService.OnSaleCompleted(function(customer: any, _bought: any, _byWorker: boolean, total: number)
			local owner = customer.owner
			QuestService.Add(owner, "serve", 1)
			QuestService.Add(owner, "earn", math.floor(total))
		end)
		PackService.OnOpened(function(player: Player)
			QuestService.Add(player, "rip", 1)
		end)
		StockService.OnStocked(function(player: Player)
			QuestService.Add(player, "stock", 1)
		end)
	end
	-- A new UTC day (or week) while they play: today's quests (and this week's)
	task.spawn(function()
		while true do
			task.wait(Quests.TICK)
			for _, player in Players:GetPlayers() do
				if states[player] then
					refresh(player)
				end
			end
		end
	end)
end

return QuestService
