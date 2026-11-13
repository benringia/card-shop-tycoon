--!strict
-- Turts' rug shop (spec 2026-11-13-turts-shop-design, Config/Turts, Util/TurtsRules): the owner's dog sells 3 offers
-- from a rug that moves round the town. Every 8 minutes, on the same clock in every server, a restock rolls 3 offers
-- (seeded from the restock number and a server-only salt, Util/TurtsSeed, so every server shows the same ones) and
-- moves him to a new spot (corners and plaza edges taking turns). Each player can buy each offer once per restock
-- (saved: data.turts, so a rejoin or a server hop never resets it); Robux "restock now" gives that player a fresh roll
-- until the next restock. Server authoritative: prices from config, the buy checked here (in stock, not bought, near
-- him, the cash), refusals through Util/Blocked. Clients draw him, his rug and their own offers (TurtsController) from
-- the marker workspace.TurtsNpc.Turts (attributes Spot, SpotName, RestockIndex, Excited, MovedAt) and Remotes.TurtsStock.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Turts = require(Shared:WaitForChild("Config"):WaitForChild("Turts"))
local TurtsRules = require(Shared:WaitForChild("Util"):WaitForChild("TurtsRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local WildService = require(Services:WaitForChild("WildService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local TurtsSeed = require(ServerUtil:WaitForChild("TurtsSeed"))

local TurtsService = {}

local REACH_SLACK = 4 -- studs past his prompt's range a buy still counts (the player stepped back as they tapped)

local states: { [Player]: TurtsRules.State } = {}
local currentIndex = 0
local globalStock: { string } = {}
local marker: Part
local devShift = 0 -- /turts move: spots further along than the clock's
local buyLimit = RateLimiter.new(0.5)
local restockLimit = RateLimiter.new(2)

local function randomFrom(random: Random): () -> number
	return function()
		return random:NextNumber()
	end
end

local function endsAt(index: number): number
	return (index + 1) * Turts.RESTOCK_SECONDS
end

-- Tells a player their stock: the offers on the rug for them, what they bought, when it restocks
local function send(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state = TurtsRules.refresh(state, currentIndex)
	states[player] = state
	Remotes.TurtsStock:FireClient(player, currentIndex, TurtsRules.stockFor(state, currentIndex, globalStock), state.bought, endsAt(currentIndex))
end

-- The street's top under (x, z): the rug lies on it
local function groundAt(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { marker }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), params)
	return if hit then hit.Position.Y else 0.1
end

local function place(spotIndex: number)
	local spot = Turts.SPOTS[spotIndex]
	local y = groundAt(spot.x, spot.z)
	marker.CFrame = CFrame.lookAt(Vector3.new(spot.x, y, spot.z), Vector3.new(spot.face.x, y, spot.face.z))
	marker:SetAttribute("Spot", spotIndex)
	marker:SetAttribute("SpotName", spot.name)
	marker:SetAttribute("MovedAt", os.time())
end

local function excite()
	marker:SetAttribute("Excited", ((marker:GetAttribute("Excited") :: number?) or 0) + 1)
end

-- A toast for everyone in town (not in the Wild)
local function announce(message: string)
	for _, player in Players:GetPlayers() do
		if not WildService.IsInWild(player) then
			Remotes.Notify:FireClient(player, message, false)
		end
	end
end

local function spotFor(index: number): number
	return TurtsRules.spotFor(index, Turts.SPOTS, randomFrom(Random.new(TurtsSeed.of(index) + 1)))
end

local function restock(index: number, told: boolean)
	currentIndex = index
	globalStock = TurtsRules.roll(Turts.OFFERS, Turts.PICKS, randomFrom(Random.new(TurtsSeed.of(index))))
	marker:SetAttribute("RestockIndex", index)
	place(spotFor(index + devShift))
	if told then
		excite()
		announce(`Turts set up shop by {marker:GetAttribute("SpotName")}!`)
	end
	for player in states do
		send(player)
	end
end

local function nearHim(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - marker.Position).Magnitude <= Turts.PROMPT_RANGE + REACH_SLACK
end

local REFUSALS = {
	restocked = "Turts restocked! Have a look at what's new.",
	notInStock = "That's not on Turts' rug right now.",
	bought = "You already bought that from Turts this restock.",
}

local function onBuy(player: Player, offerId: unknown)
	if typeof(offerId) ~= "string" or not buyLimit(player) then
		return
	end
	local state = states[player]
	local offer = Turts.OFFERS[offerId]
	if not state or not offer then
		return
	end
	if not nearHim(player) then
		Blocked.tell(player, "Walk up to Turts' rug to buy from him.", { title = "Turts' shop" })
		return
	end
	state = TurtsRules.refresh(state, currentIndex)
	states[player] = state
	local ok, why = TurtsRules.canBuy(state, currentIndex, TurtsRules.stockFor(state, currentIndex, globalStock), offerId)
	if not ok then
		Blocked.tell(player, REFUSALS[why :: string] or "Turts can't sell that now.", { title = "Turts' shop" })
		send(player)
		return
	end
	if not EconomyService.TrySpend(player, offer.price) then
		Blocked.tell(player, `{offer.name} costs ${offer.price}.`, { title = "Not enough cash" })
		return
	end
	local given = ItemService.GiveItem(player, offer.item, offer.count)
	if given < offer.count then
		-- the Bag can't hold them all: the cash back for what didn't fit, nothing marked bought
		EconomyService.AddCash(player, math.floor(offer.price * (offer.count - given) / offer.count))
		if given == 0 then
			Blocked.tell(player, `Your Bag is full of {offer.name}.`, { title = "Turts' shop" })
			return
		end
	end
	table.insert(state.bought, offerId)
	if offer.excited then
		excite()
	end
	Remotes.Notify:FireClient(player, `Bought {offer.name} from Turts!`, false)
	send(player)
end

-- A fresh roll of offers for one player until the next restock (Robux "restock now", /turts restock); what they
-- bought before is cleared with it, since it's a new stock
local function rollFor(player: Player, offers: { string }?): boolean
	local state = states[player]
	if not state then
		return false
	end
	state = TurtsRules.refresh(state, currentIndex)
	state.personal = { index = currentIndex, offers = offers or TurtsRules.roll(Turts.OFFERS, Turts.PICKS, randomFrom(Random.new())) }
	state.bought = {}
	states[player] = state
	excite()
	send(player)
	return true
end

-- Studio: a new roll for `player` now
function TurtsService.DevRestock(player: Player)
	rollFor(player, nil)
end

-- Studio: he moves to his next spot now (the stock stays)
function TurtsService.DevMove()
	devShift += 1
	place(spotFor(currentIndex + devShift))
	excite()
	announce(`Turts set up shop by {marker:GetAttribute("SpotName")}!`)
end

-- Studio: `offerId` first in `player`'s stock now; false for an unknown offer
function TurtsService.DevOffer(player: Player, offerId: string): boolean
	if not Turts.OFFERS[offerId] then
		return false
	end
	local state = states[player]
	if not state then
		return false
	end
	local stock = table.clone(TurtsRules.stockFor(TurtsRules.refresh(state, currentIndex), currentIndex, globalStock))
	local at = table.find(stock, offerId)
	if at then
		table.remove(stock, at)
	end
	table.insert(stock, 1, offerId)
	while #stock > Turts.PICKS do
		table.remove(stock)
	end
	return rollFor(player, stock)
end

function TurtsService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "TurtsNpc"
	marker = Instance.new("Part")
	marker.Name = "Turts"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(2, 1, 2)
	marker.Parent = folder
	folder.Parent = workspace
	restock(TurtsRules.restockIndex(os.time(), Turts.RESTOCK_SECONDS), false)

	DataService.Register({
		name = "Turts",
		load = function(player, data)
			local saved = data.turts
			states[player] = TurtsRules.refresh({
				index = saved.index,
				bought = table.clone(saved.bought),
				personal = if saved.personal then { index = saved.personal.index, offers = table.clone(saved.personal.offers) } else nil,
			}, currentIndex)
			send(player)
		end,
		save = function(player, data)
			local state = states[player]
			if not state then
				return -- never loaded: keep what's saved
			end
			data.turts = {
				index = state.index,
				bought = table.clone(state.bought),
				personal = if state.personal then { index = state.personal.index, offers = table.clone(state.personal.offers) } else nil,
			}
		end,
		unload = function(player)
			states[player] = nil
		end,
	})

	Remotes.TurtsBuy.OnServerEvent:Connect(onBuy)
	Remotes.TurtsStock.OnServerEvent:Connect(send) -- a client asking again (its window opened before the stock came)
	Remotes.TurtsRestockNow.OnServerEvent:Connect(function(player)
		if not restockLimit(player) then
			return
		end
		local productId = PurchaseService.ProductId(Turts.PRODUCT)
		if productId == 0 then
			return -- not created yet: the button says "Coming soon"
		end
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
	PurchaseService.OnProduct(Turts.PRODUCT, function(player)
		return rollFor(player, nil)
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local index = TurtsRules.restockIndex(os.time(), Turts.RESTOCK_SECONDS)
			if index ~= currentIndex then
				restock(index, true)
			end
		end
	end)
end

return TurtsService
