--!strict
-- Daily, weekly and monthly gifts (spec 2026-11-15-daily-gifts-design, Config/Gifts, Util/GiftRules). Counts each
-- player's play time per UTC day once their first visit is done (the prologue and Pish's tutorial; in every place),
-- tells them what's ready (Remotes.GiftState) and, in the main game, hands a claimed gift out: cash through
-- EconomyService, items through ItemService, luck through LuckService (as if bought, its Store card skipped: the gift's
-- own win moment shows it). All gifts are fixed (nothing rolled); the client only asks for "daily" | "weekly" |
-- "monthly", the rules decide. Saved as data.gifts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Gifts = require(Config:WaitForChild("Gifts"))
local Items = require(Config:WaitForChild("Items"))
local Luck = require(Config:WaitForChild("Luck"))
local GiftRules = require(Shared:WaitForChild("Util"):WaitForChild("GiftRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local GiftService = {}

local states: { [Player]: GiftRules.State } = {}
local playing: { [Player]: boolean } = {} -- their first visit is done: play time counts
local watchers: { [Player]: RBXScriptConnection } = {}
local claimLimit = RateLimiter.new(1)
local askLimit = RateLimiter.new(1)

-- Main game only (the claim hands out items and luck, whose services live there)
local EconomyService: any = nil
local ItemService: any = nil
local LuckService: any = nil
local BattleService: any = nil

local REFUSALS = {
	claimed = "You opened today's gift! Come back tomorrow for the next one.",
	wait = "Keep playing! Your gift is almost ready.",
	notEarned = "Open more daily gifts to fill this chest.",
}

local function today(): number
	return GiftRules.dayOf(os.time())
end

local function send(player: Player)
	local state = states[player]
	if state then
		Remotes.GiftState:FireClient(player, GiftRules.view(state, today(), Gifts), playing[player] == true)
	end
end

-- Their first visit is done: the prologue seen and Pish's tutorial over (TutorialService's TutorialDone in the main
-- game; the saved tutorial elsewhere)
local function firstVisitDone(data: PlayerData): boolean
	local tutorial = data.tutorial :: any
	return data.seenPrologue == true and typeof(tutorial) == "table" and tutorial.firstVisit ~= "todo"
end

local function grant(player: Player, reward: GiftRules.Reward)
	if reward.cash and reward.cash > 0 then
		EconomyService.AddCash(player, reward.cash)
	end
	for _, item in reward.items or {} do
		local given = ItemService.GiveItem(player, item.item, item.count)
		if given < item.count then
			local info = Items.ITEMS[item.item]
			Remotes.Notify:FireClient(player, `Your Bag is full: {item.count - given} {if info then info.name else item.item} didn't fit.`, true)
		end
	end
	if reward.luck then
		LuckService.Give(player, reward.luck.strength, reward.luck.seconds)
	end
end

local function announce(message: string)
	for _, other in Players:GetPlayers() do
		Remotes.Notify:FireClient(other, message, false)
	end
end

-- Hands a claimed gift out and plays its win moment (the chests it earned play right after it, on the client)
local function claim(player: Player, kind: GiftRules.Kind)
	local state = states[player]
	if not state then
		return
	end
	local day = today()
	local ok, why = GiftRules.canClaim(state, kind, day, Gifts)
	if not ok then
		Blocked.tell(player, REFUSALS[why or ""] or "That gift isn't ready yet.", { title = "Gifts" })
		send(player)
		return
	end
	local index = GiftRules.view(state, day, Gifts).day
	local after, reward, earned = GiftRules.claim(state, kind, day, Gifts)
	states[player] = after
	grant(player, reward)
	Remotes.GiftClaim:FireClient(player, kind, index, GiftRules.lines(reward, Items, Luck), earned)
	if kind == "monthly" then
		local message = string.gsub(Gifts.MONTHLY.announce, "{name}", function()
			return player.DisplayName -- a function: a "%" in a name is never read as a gsub capture
		end)
		announce(message)
	end
	send(player)
end

local function onClaim(player: Player, kind: unknown)
	if (kind ~= "daily" and kind ~= "weekly" and kind ~= "monthly") or not claimLimit(player) then
		return
	end
	if not states[player] then
		return
	end
	if not playing[player] then
		Blocked.tell(player, "Finish your first visit with Pish to start getting gifts.", { title = "Gifts" })
		return
	end
	if BattleService.IsFighting(player) then
		Blocked.tell(player, "Open your gift after the fight.", { title = "Gifts" })
		return
	end
	claim(player, kind :: GiftRules.Kind)
end

local function load(player: Player, data: PlayerData)
	states[player] = GiftRules.refresh(GiftRules.clean(data.gifts), today())
	playing[player] = firstVisitDone(data)
	-- the tutorial ends while they play (main game): their time starts counting now
	watchers[player] = player:GetAttributeChangedSignal("TutorialDone"):Connect(function()
		local done = player:GetAttribute("TutorialDone") == true
		if done ~= playing[player] then
			playing[player] = done
			send(player)
		end
	end)
	send(player)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their gifts
local function save(player: Player, data: PlayerData)
	local state = states[player]
	if state then
		data.gifts = table.clone(state)
	end
end

local function unload(player: Player)
	local watcher = watchers[player]
	if watcher then
		watcher:Disconnect()
		watchers[player] = nil
	end
	states[player] = nil
	playing[player] = nil
end

-- Studio (/gift, the admin panel's "Gifts"): `action` on `player`'s gifts; the line to tell them, or nil for usage.
-- win <daily|big|weekly|monthly>: only that win moment, nothing given
function GiftService.Dev(player: Player, action: string, value: string?): string?
	local state = states[player]
	if not state then
		return nil
	end
	local amount = tonumber(value)
	local day = today()
	local now = GiftRules.refresh(state, day)
	if action == "win" then
		local index = if value == "big" then #Gifts.DAILY else GiftRules.view(now, day, Gifts).day
		local kind = if value == "weekly" or value == "monthly" then value else "daily"
		local reward = if kind == "weekly" then Gifts.WEEKLY.reward elseif kind == "monthly" then Gifts.MONTHLY.reward else Gifts.DAILY[index]
		Remotes.GiftClaim:FireClient(player, kind, index, GiftRules.lines(reward, Items, Luck), { week = false, month = false })
		return `Gift win moment: {kind} (Studio, nothing given)`
	elseif action == "ready" then
		now.played = Gifts.PLAY_SECONDS
		if now.lastDay == day then
			now.lastDay = day - 1
		end
	elseif action == "day" and amount and amount >= 1 and amount <= #Gifts.DAILY then
		now.streak = math.floor(amount) - 1
		now.played = Gifts.PLAY_SECONDS
		now.lastDay = day - 1
	elseif action == "week" and amount and amount >= 0 then
		now.weekDays = math.floor(amount)
		now.weekEarned = now.weekDays >= Gifts.WEEKLY.days
	elseif action == "month" and amount and amount >= 0 then
		now.monthDays = math.floor(amount)
		now.monthEarned = now.monthDays >= GiftRules.monthTarget(Gifts, now.month)
	elseif action == "reset" then
		now = GiftRules.refresh(GiftRules.fresh(), day)
	elseif action == "tutorial" then
		playing[player] = not playing[player]
		send(player)
		return `Gift time counting: {playing[player]} (Studio)`
	else
		return nil
	end
	states[player] = now
	send(player)
	return `Gifts: {action} {value or ""} (Studio)`
end

function GiftService.Start()
	DataService.Register({ name = "GiftService", load = load, save = save, unload = unload })
	if not Place.isFrontier() and not Place.isDungeon() then
		EconomyService = require(Services:WaitForChild("EconomyService"))
		ItemService = require(Services:WaitForChild("ItemService"))
		LuckService = require(Services:WaitForChild("LuckService"))
		BattleService = require(Services:WaitForChild("BattleService"))
		Remotes.GiftClaim.OnServerEvent:Connect(onClaim)
	end
	Remotes.GiftState.OnServerEvent:Connect(function(player)
		if askLimit(player) then
			send(player) -- a client asking again (its window opened before the state came)
		end
	end)
	-- Play time counts while they're here; each gift's ready moment and each new UTC day are told
	task.spawn(function()
		local last = os.clock()
		local lastDay = today()
		while true do
			task.wait(Gifts.TICK)
			local now = os.clock()
			local elapsed = now - last
			last = now
			local day = today()
			local newDay = day ~= lastDay
			lastDay = day
			for player, state in states do
				local wasReady = GiftRules.view(state, day, Gifts).ready
				if playing[player] then
					states[player] = GiftRules.addPlay(state, day, elapsed)
				end
				if newDay or GiftRules.view(states[player], day, Gifts).ready ~= wasReady then
					send(player)
				end
			end
		end
	end)
end

return GiftService
