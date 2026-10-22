--!strict
-- The item inventory (battles part 3a): the only place items change. Saved as items = { [itemId] = count };
-- Config/Items lists what exists. The client gets ItemsChanged(items) on load and on every change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local ItemService = {}

local inventories: { [Player]: ItemRules.Items } = {}
local allowRequest = RateLimiter.new(1)

local function sync(player: Player)
	local items = inventories[player]
	if items then
		Remotes.ItemsChanged:FireClient(player, items)
	end
end

function ItemService.GetCount(player: Player, id: string): number
	local items = inventories[player]
	return if items then items[id] or 0 else 0
end

-- Adds up to n of an item (never past the stack limit); returns how many were added
function ItemService.GiveItem(player: Player, id: string, n: number): number
	local items = inventories[player]
	if not items then
		return 0
	end
	local updated, added = ItemRules.add(Items, items, id, n)
	if added > 0 then
		inventories[player] = updated
		sync(player)
	end
	return added
end

-- Takes n of an item if the player has that many; false (and nothing taken) otherwise
function ItemService.TakeItem(player: Player, id: string, n: number): boolean
	local items = inventories[player]
	local updated = if items then ItemRules.take(items, id, n) else nil
	if not updated then
		return false
	end
	inventories[player] = updated
	sync(player)
	return true
end

local function load(player: Player, data: PlayerData)
	inventories[player] = ItemRules.sanitize(Items, data.items)
	sync(player)
end

local function save(player: Player, data: PlayerData)
	local items = inventories[player]
	if items then
		data.items = table.clone(items)
	end
end

local function unload(player: Player)
	inventories[player] = nil
end

function ItemService.Start()
	DataService.Register({ name = "ItemService", load = load, save = save, unload = unload })
	Remotes.RequestItems.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			sync(player)
		end
	end)
end

return ItemService
