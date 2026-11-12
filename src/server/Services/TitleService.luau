--!strict
-- The title over a player's name (owner 2026-11-12: "add TITLES tab on the character menu, I'm planning to add titles
-- system"; 2026-11-13: "add more titles that is obtainable in game. also add a notification when a new title is
-- unlocked"; Config/Titles, Util/TitleRules). What earns titles is gathered here (boss clears and the Dungeon's secret,
-- the best "Support the dev" gift, the shop level, lifetime counters, cards owned, duels won) and checked every
-- CHECK_SECONDS and when a boss, a gift or a level changes it. A title once earned stays earned (saved data.titles
-- `known`, so it holds in every place even where a count isn't here, the arena's duels); a newly earned one is told
-- (Remotes.TitleUnlocked: the "New title!" card, OnUnlocked: Pish's lesson) and marked new (`fresh`, the dot on the
-- character button) till the Titles tab is seen (Remotes.TitlesSeen). The first load after this came counts what's
-- earned already without telling (`seeded`). The picked one is saved (data.title, "" = automatic); the Title and
-- TitleId attributes show it over their head in every place (TitleController); the Titles tab lists every title with
-- how far a locked one is (Remotes.Titles) and picks one (Remotes.EquipTitle, only an earned one).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Titles = require(Config:WaitForChild("Titles"))
local Cards = require(Config:WaitForChild("Cards"))
local TitleRules = require(Shared:WaitForChild("Util"):WaitForChild("TitleRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local BossService = require(Services:WaitForChild("BossService"))
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local SupportService = require(Services:WaitForChild("SupportService"))
local Blocked = require(Util:WaitForChild("Blocked"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local TitleService = {}

type State = { equipped: string, known: { string }, fresh: { string }, seeded: boolean }

local states: { [Player]: State } = {} -- loaded players only
local unlockListeners: { (player: Player, id: string) -> () } = {}
local pvpWins: (player: Player) -> number = function()
	return 0 -- the main game's ArenaService hands its count in (UsePvpWins); elsewhere a duel title holds by `known`
end
local allow = RateLimiter.new(Titles.EQUIP_COOLDOWN) -- equips
local allowAsk = RateLimiter.new(Titles.EQUIP_COOLDOWN) -- the window asking for the list (its own, so an equip right after opening isn't dropped)
local allowSeen = RateLimiter.new(1)

-- How many cards each set has (by id prefix: FS First Spark, FR Frontier)
local SET_TOTALS: { [string]: number } = {}
for _, card in Cards.List do
	local prefix = string.sub(card.id, 1, 2)
	SET_TOTALS[prefix] = (SET_TOTALS[prefix] or 0) + 1
end

local function names(list: unknown): { string }
	local clean = {}
	if typeof(list) == "table" then
		for _, id in list :: any do
			if typeof(id) == "string" and Titles.ById[id] then
				table.insert(clean, id)
			end
		end
	end
	return clean
end

-- What earns titles now: BossService's progress (or the one it just reported) and the rest
local function progressOf(player: Player, boss: TitleRules.Progress?): TitleRules.Progress
	local base = boss or BossService.Progress(player)
	local owned = CardService.GetOwnedCardIds(player)
	local count, sets, rarities = 0, {}, {}
	for cardId in owned do
		local card = Cards.ById[cardId]
		if card then
			count += 1
			local prefix = string.sub(cardId, 1, 2)
			local set = sets[prefix] or { have = 0, total = SET_TOTALS[prefix] or 0 }
			set.have += 1
			sets[prefix] = set
			rarities[card.rarity] = (rarities[card.rarity] or 0) + 1
		end
	end
	return {
		cleared = base.cleared,
		secret = base.secret,
		supporter = SupportService.Best(player),
		level = EconomyService.GetLevel(player),
		stats = {
			packsOpened = DataService.GetStat(player, "packsOpened"),
			customersServed = DataService.GetStat(player, "customersServed"),
			totalEarned = DataService.GetStat(player, "totalEarned"),
		},
		cards = count,
		sets = sets,
		rarities = rarities,
		pvpWins = pvpWins(player),
	}
end

-- The client's list: every title earned (now or before), the picked one, the new ones, and how far each locked one is
local function send(player: Player, state: State, earned: { string }, progress: TitleRules.Progress)
	local far = {}
	for _, id in Titles.ORDER do
		if not table.find(earned, id) then
			local have, need = TitleRules.progress(Titles, progress, id)
			far[id] = { have = have, need = need }
		end
	end
	Remotes.Titles:FireClient(player, { earned = earned, equipped = state.equipped, fresh = state.fresh, progress = far })
end

-- Looks at what's earned: a title earned for the first time is told and marked new; the title over the name and (with
-- `tell`) the client's list are brought up to date
local function refresh(player: Player, boss: TitleRules.Progress?, tell: boolean?)
	local state = states[player]
	if not state or not player.Parent then
		return
	end
	local progress = progressOf(player, boss)
	local now = TitleRules.earned(Titles, progress)
	local newly = TitleRules.newly(now, state.known)
	local changed = #newly > 0
	if not state.seeded then
		-- the first look since titles were saved: what they had already isn't news
		state.known = TitleRules.merge(Titles, state.known, now)
		state.seeded = true
		newly = {}
	elseif changed then
		state.known = TitleRules.merge(Titles, state.known, now)
		for _, id in newly do
			if not table.find(state.fresh, id) then
				table.insert(state.fresh, id)
			end
			Remotes.TitleUnlocked:FireClient(player, id)
			for _, listener in unlockListeners do
				task.spawn(listener, player, id)
			end
		end
	end
	local earned = state.known
	local shown = TitleRules.shown(Titles, state.equipped, earned)
	player:SetAttribute("Title", if shown then Titles.ById[shown].name else nil)
	player:SetAttribute("TitleId", shown)
	if tell or changed then
		send(player, state, earned, progress)
	end
end

local function load(player: Player, data: any)
	local saved = data.title
	local titles = if typeof(data.titles) == "table" then data.titles else {}
	states[player] = {
		equipped = if typeof(saved) == "string" and #saved <= Titles.MAX_SAVED then saved else "",
		known = names(titles.known),
		fresh = names(titles.fresh),
		seeded = titles.seeded == true,
	}
	refresh(player, nil, true)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their titles
local function save(player: Player, data: any)
	local state = states[player]
	if not state then
		return
	end
	data.title = state.equipped
	data.titles = { known = table.clone(state.known), fresh = table.clone(state.fresh), seeded = state.seeded }
end

local function unload(player: Player)
	states[player] = nil
end

local function onEquip(player: Player, id: unknown)
	local state = states[player]
	if typeof(id) ~= "string" or #id > Titles.MAX_SAVED or not state or not allow(player) then
		return
	end
	if not TitleRules.canEquip(id, state.known) then
		local title = Titles.ById[id]
		Blocked.tell(player, if title then `{title.how} to earn {title.name}.` else "That title doesn't exist.")
		return
	end
	state.equipped = id
	refresh(player, nil, true)
end

-- Told when a player earns a title for the first time (TutorialService: Pish's lesson)
function TitleService.OnUnlocked(listener: (player: Player, id: string) -> ())
	table.insert(unlockListeners, listener)
end

-- The main game's ArenaService: duels won (the duel titles)
function TitleService.UsePvpWins(getter: (player: Player) -> number)
	pvpWins = getter
end

-- Studio's /titles forget: every title earned so far is new again (its card, the dot, Pish's lesson)
function TitleService.ForgetForTest(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	end
	state.known = {}
	state.fresh = {}
	state.seeded = true
	refresh(player, nil, true)
	return true
end

function TitleService.Start()
	DataService.Register({ name = "TitleService", load = load, save = save, unload = unload })
	BossService.OnProgress(function(player: Player, progress: TitleRules.Progress)
		refresh(player, progress)
	end)
	SupportService.OnChanged(function(player: Player)
		refresh(player)
	end)
	EconomyService.OnLevelUp(function(player: Player)
		refresh(player)
	end)
	Remotes.Titles.OnServerEvent:Connect(function(player: Player)
		if allowAsk(player) then
			refresh(player, nil, true)
		end
	end)
	Remotes.EquipTitle.OnServerEvent:Connect(onEquip)
	-- the Titles tab seen: nothing's new any more
	Remotes.TitlesSeen.OnServerEvent:Connect(function(player: Player)
		local state = states[player]
		if state and allowSeen(player) and #state.fresh > 0 then
			state.fresh = {}
			refresh(player, nil, true)
		end
	end)
	-- counters change all the time (a sale, a pack): a look every few seconds
	task.spawn(function()
		while true do
			task.wait(Titles.CHECK_SECONDS)
			for _, player in Players:GetPlayers() do
				refresh(player)
			end
		end
	end)
end

return TitleService
