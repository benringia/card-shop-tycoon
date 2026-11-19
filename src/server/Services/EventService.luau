--!strict
-- Weekly events (owner 2026-11-19: "build the weekend events"; Config/Events, Util/EventRules, Util/EventNow): the same
-- every week on UTC days, nobody runs them. This service tells a player the day's event once they've arrived (and when
-- the day turns while they play) and gives Lucky Sunday's free luck once a UTC day (saved as data.events.luckDay, so a
-- rejoin or another place can't give it twice). What an event changes is read where it applies, from EventNow and
-- EventRules (BossService: the loot timer and the victory note; BossChestService: the chests' material), never from
-- here: this service needs LuckService, which the boss services' own requires lead back to. Players in their first visit (the prologue, Pish's tour) hear nothing
-- until it's over. Studio: /event (DevService) sets the override EventNow reads.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Config"):WaitForChild("Events"))
local EventNow = require(Shared:WaitForChild("Util"):WaitForChild("EventNow"))
local EventRules = require(Shared:WaitForChild("Util"):WaitForChild("EventRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local LuckService = require(Services:WaitForChild("LuckService"))

type PlayerData = DataService.PlayerData

local EventService = {}

local states: { [Player]: { luckDay: number } } = {}
local ready: { [Player]: boolean } = {} -- their first visit is done (GiftService's rule)
local since: { [Player]: number } = {} -- os.clock they loaded (or finished the tour) at
local told: { [Player]: string } = {} -- the day and event they were last told of here
local watchers: { [Player]: RBXScriptConnection } = {}

-- Their first visit is done: the prologue seen and Pish's tutorial over (TutorialDone in the main game; the saved
-- tutorial elsewhere)
local function firstVisitDone(data: PlayerData): boolean
	local tutorial = data.tutorial :: any
	return data.seenPrologue == true and typeof(tutorial) == "table" and tutorial.firstVisit ~= "todo"
end

-- Tells this player of the day's event if they haven't heard here yet, and gives its luck if today's wasn't given
local function greet(player: Player)
	local state = states[player]
	if not state or not ready[player] or os.clock() - (since[player] or 0) < Events.JOIN_DELAY then
		return
	end
	local event = EventNow.today()
	local day = EventRules.dayNumber(EventNow.unix())
	local key = if event then `{day}:{event.id}` else ""
	if told[player] == key then
		return
	end
	told[player] = key
	if not event then
		return
	end
	local gifted = false
	local gift = EventRules.luckGift(event, state.luckDay, day)
	if gift and LuckService.Give(player, gift.strength, gift.seconds) then
		state.luckDay = day
		gifted = true
	end
	Remotes.Notify:FireClient(player, EventRules.toast(event, gifted), false)
end

local function load(player: Player, data: PlayerData)
	states[player] = EventRules.clean(data.events)
	ready[player] = firstVisitDone(data)
	since[player] = os.clock()
	-- the tour ends while they play (main game): the day's event is told a moment later
	watchers[player] = player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		local done = player:GetAttribute("TutorialDone") == true
		if done and not ready[player] then
			since[player] = os.clock()
		end
		ready[player] = done
	end)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe the day
local function save(player: Player, data: PlayerData)
	local state = states[player]
	if state then
		data.events = { luckDay = state.luckDay }
	end
end

local function unload(player: Player)
	local watcher = watchers[player]
	if watcher then
		watcher:Disconnect()
		watchers[player] = nil
	end
	states[player] = nil
	ready[player] = nil
	since[player] = nil
	told[player] = nil
end

-- Studio (/event, the admin panel's "Events"): `id` an event's id forces it, "off" none, "auto" the calendar again;
-- everyone here is told of the change. "luck": Lucky Sunday's luck can be given again today. The line to print, or nil
-- for usage
function EventService.Dev(player: Player, id: string): string?
	if not RunService:IsStudio() then
		return nil
	end
	if id == "luck" then
		local state = states[player]
		if state then
			state.luckDay = -1
			told[player] = nil
			since[player] = 0
			greet(player)
		end
		return "Lucky Sunday's luck can be given again today"
	end
	local known = id == "off" or id == "auto"
	for _, event in Events.DAYS do
		known = known or event.id == id
	end
	if not known then
		return nil
	end
	workspace:SetAttribute(EventNow.OVERRIDE, if id == "auto" then nil else id)
	for listed in states do
		told[listed] = nil
		since[listed] = 0
		greet(listed)
	end
	local event = EventNow.today()
	return `Event now: {if event then event.name else "none"}`
end

function EventService.Start()
	DataService.Register({ name = "EventService", load = load, save = save, unload = unload })
	task.spawn(function()
		while true do
			task.wait(Events.CHECK_SECONDS)
			for player in states do
				greet(player)
			end
		end
	end)
end

return EventService
