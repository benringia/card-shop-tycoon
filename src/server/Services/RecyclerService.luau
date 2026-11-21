--!strict
-- The Recycler (Config/Recycler, Util/RecycleRules; owner 2026-11-21: "can we have add a recycler. that can make extra
-- cards turn into upgrade materials. make sure the costs are fair"): the owner's window (client RecyclerController)
-- asks to recycle one rarity's pile or every pile, into materials or into coins (Remotes.Recycle). The server works
-- the extras out again from the binder itself (never from the client), takes exactly the copies that go and puts what
-- they make in the machine as a timed job (UpgradeJobService "recycler": one at a time; the materials and the cash are
-- given when its time is up, also while away; Finish now works on it), which tells the window what was made
-- (Remotes.Recycled). Nothing to make, a busy machine, or no room in the Bag, shows the big locked card
-- (Util/Blocked), never a silent no. Nothing of its own is saved: the job is UpgradeJobService's.
-- Never a creature (owner 2026-11-21: "make sure players cant accidentally recycle their most powerful creatures. or
-- the creatures they've been using"): only plain copies go; every creature the player has (in the binder, the party,
-- a job, a station or a case) keeps the copies it can still use; and the press carries the list the window showed and
-- the player confirmed, which caps what is taken card by card (RecycleRules.trimToShown).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Recycler = require(Config:WaitForChild("Recycler"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Grading = require(Config:WaitForChild("Grading"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local Early = require(Config:WaitForChild("Early"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local RecycleRules = require(Shared:WaitForChild("Util"):WaitForChild("RecycleRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local CardService = require(Services:WaitForChild("CardService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local UpgradeJobService = require(Services:WaitForChild("UpgradeJobService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local Blocked = require(ServerUtil:WaitForChild("Blocked"))

local RecyclerService = {}

local allow = RateLimiter.new(Recycler.ACTION_COOLDOWN)

local function rarityOf(cardId: string): string?
	local card = Cards.ById[cardId]
	return if card then card.rarity else nil
end

-- Every creature this player has, wherever it is: the binder's (with the party's, the workers' and the fighters'), the
-- ones in a station (the Condenser, the Grading Station) and the ones on display in a case
local function creaturesOf(player: Player): { { cardId: string, stars: number, grade: string } }
	local list: { { cardId: string, stars: number, grade: string } } = {}
	for _, beast in CardService.GetBeasts(player) do
		table.insert(list, { cardId = beast.cardId, stars = beast.stars, grade = beast.grade })
	end
	for _, held in UpgradeJobService.HeldCards(player) do
		table.insert(list, held)
	end
	for _, shelf in PlacementService.GetShelves(player) do
		for _, displayed in shelf.cards do
			local beast = displayed.beast
			if beast then
				table.insert(list, { cardId = beast.cardId, stars = beast.stars, grade = beast.grade })
			end
		end
	end
	return list
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil and root:IsA("BasePart") and (root.Position - part.Position).Magnitude <= Recycler.USE_DISTANCE
end

-- `rarity`: one pile ("Rare"), or nil for every pile; `mode`: "materials" or "coins"; `shown`: the list the player
-- confirmed ("card:grade" = copies; RecycleRules.shownMap)
local function onRecycle(player: Player, uid: unknown, rarity: unknown, mode: unknown, shown: unknown)
	if typeof(uid) ~= "string" or (rarity ~= nil and typeof(rarity) ~= "string") or not RecycleRules.modeOk(mode) or not allow(player) then
		return
	end
	local confirmed = RecycleRules.readShown(shown)
	if not confirmed then
		return
	end
	if rarity ~= nil and not Recycler.RECIPES[rarity :: string] then
		return
	end
	local shelf = PlacementService.GetShelf(player, uid)
	if not shelf or shelf.def.kind ~= "Recycler" or not isNear(player, shelf.part) then
		return
	end
	-- one conversion at a time (refused before anything is taken)
	local left = UpgradeJobService.Left(player, "recycler")
	if left then
		Blocked.tell(player, UpgradeRules.busyText(Upgrades.STATIONS.recycler, left))
		return
	end
	-- worked out here from the binder and every creature, then cut back to what the player saw and confirmed
	local piles = RecycleRules.trimToShown(RecycleRules.piles(Recycler, Beasts, Grading, CardService.GetStacks(player) :: any, creaturesOf(player), rarityOf), confirmed)
	local takes: { RecycleRules.Take }, gains: { RecycleRules.Gain }, cash = {}, {}, 0
	if mode == "coins" then
		takes, cash = RecycleRules.coinPlan(Recycler, piles, rarity :: string?)
	else
		takes, gains = RecycleRules.plan(Recycler, piles, rarity :: string?)
	end
	if #gains == 0 and cash <= 0 then
		Blocked.tell(player, "Nothing to recycle now: your cards changed since you looked. Check the list again.")
		return
	end
	for _, gain in gains do
		if ItemService.GetCount(player, gain.item) + gain.count > Items.MAX_STACK then
			local words = Recycler.ITEM_WORDS[gain.item]
			Blocked.tell(player, `Your Bag can't hold that many more {if words then words[2] else "of those"}. Use some first.`)
			return
		end
	end
	if not CardService.TakeFreshMany(player, takes) then
		return
	end
	-- the cards are in: what they make waits in the machine (a new shop's wait is shorter, like the other stations')
	local now = os.time()
	local seconds = EarlyRules.stationWait(RecycleRules.seconds(Recycler, gains, cash), tonumber(player:GetAttribute("Level")) or 1, Early)
	if not UpgradeJobService.Begin(player, "recycler", RecycleRules.job(gains, cash, now, seconds) :: any) then
		-- (the machine was free a moment ago: never lose what went in)
		warn(`[RecyclerService] {player.Name}: the Recycler was busy after the check; giving the result at once`)
		for _, gain in gains do
			ItemService.GiveItem(player, gain.item, gain.count)
		end
		if cash > 0 then
			EconomyService.AddCash(player, cash)
		end
		Remotes.Recycled:FireClient(player, gains, cash)
		return
	end
	Remotes.Notify:FireClient(player, `Recycling: {RecycleRules.makes(Recycler, gains, cash)} in {UpgradeRules.clock(seconds)}`, false)
end

function RecyclerService.Start()
	Remotes.Recycle.OnServerEvent:Connect(onRecycle)
end

return RecyclerService
