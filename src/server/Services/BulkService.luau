--!strict
-- The Bulk Bin (Config/Bulk, Util/BulkRules; owner 2026-11-17: "what happens when a really active player ... end up like
-- 1000 common cards", then "lets do C"): the owner's Add extras prompt opens the bin's window (client
-- BulkBinController; owner 2026-11-26, pick B: the extras shown first, a tap keeps a card out), whose Put in sends
-- Remotes.FillBulkBin with the cards kept out; the binder's other extra Commons go in, whole handfuls of Bulk.PER that
-- fit, as stock of Bulk.PRODUCT (PlacementService.AddStock); customers then buy the handfuls like any product. The
-- extras are worked out again here from the binder as it is: the window's list is never trusted. A bin with nothing to
-- add or no room shows the big locked card (Util/Blocked), never a silent no.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bulk = require(Config:WaitForChild("Bulk"))
local Cards = require(Config:WaitForChild("Cards"))
local StockConfig = require(Config:WaitForChild("Stock"))
local BulkRules = require(Shared:WaitForChild("Util"):WaitForChild("BulkRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local CardService = require(Services:WaitForChild("CardService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local Blocked = require(ServerUtil:WaitForChild("Blocked"))

local BulkService = {}

local allow = RateLimiter.new(1)

local function rarityOf(cardId: string): string?
	local card = Cards.ById[cardId]
	return if card then card.rarity else nil
end

local function isNear(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil and root:IsA("BasePart") and (root.Position - part.Position).Magnitude <= StockConfig.INTERACT_DISTANCE
end

local function isCard(cardId: string): boolean
	return Cards.ById[cardId] ~= nil
end

local function onFill(player: Player, uid: unknown, keepOutList: unknown)
	if typeof(uid) ~= "string" or not allow(player) then
		return
	end
	-- at most one entry per card: anything longer, or not a plain list of ids, is no real window's
	local keepOut = BulkRules.readKeepOut(keepOutList, isCard, #Cards.List)
	if not keepOut then
		return
	end
	local shelf = PlacementService.GetShelf(player, uid)
	if not shelf or shelf.def.id ~= Bulk.SHELF or not isNear(player, shelf.part) then
		return
	end
	local room = shelf.def.capacity - shelf.units
	if room <= 0 then
		Blocked.tell(player, `This Bulk Bin is full ({shelf.def.capacity} handfuls). Customers buy them one at a time, or place another bin.`)
		return
	end
	local takes, total = BulkRules.extras(CardService.GetStacks(player), rarityOf, Bulk, keepOut)
	local handfuls, cards = BulkRules.fill(total, room, Bulk.PER)
	if handfuls <= 0 then
		local kept = if next(keepOut) then " you didn't keep out" else ""
		Blocked.tell(player, `No extra Commons{kept} to add yet. The bin takes Commons past the {Bulk.KEEP} you keep of each card, {Bulk.PER} at a time (never foils, Grade A or S).`)
		return
	end
	if not CardService.TakeFreshMany(player, BulkRules.trim(takes, cards)) then
		return
	end
	local added = PlacementService.AddStock(shelf, Bulk.PRODUCT, handfuls)
	if added < handfuls then
		warn(`[BulkService] {player.Name}: {handfuls - added} handfuls had no room after the check`) -- (the room was checked above)
	end
	Remotes.Notify:FireClient(player, `{cards} extra Commons went in your Bulk Bin: {added} handfuls for your customers!`, false)
end

function BulkService.Start()
	Remotes.FillBulkBin.OnServerEvent:Connect(onFill)
end

return BulkService
