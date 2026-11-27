--!strict
-- Main quests (owner 2026-11-18: "when items like forge is unlocked and the players couldnt afford it yet, add it to
-- their main quests"; look A; Config/MainQuests, Util/MainQuestRules): which main quest items each player has built,
-- told to the client as the ShopBuilt attribute (its quest strip's main row picks the goal from it, the cash and the
-- level), and the first build of each paying its share of shop XP once, with its moment on the client
-- (Remotes.MainQuestDone). Saved as data.mainQuests (the items already paid). Every place reads the saved layout at load
-- (the Frontier's strip shows the main row too); the main game follows placements and sales as they happen. Items
-- already standing in the shop at load count as paid, so selling one and placing it again never pays twice. A quest
-- stays done once its item was built: selling the item never opens it again (owner 2026-11-21: "buying then selling
-- the accessory hook resets the main quest to buy accessory hook again"; MainQuestRules.doneText).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local MainQuests = require(Config:WaitForChild("MainQuests"))
local Shelves = require(Config:WaitForChild("Shelves"))
local MainQuestRules = require(Shared:WaitForChild("Util"):WaitForChild("MainQuestRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DevAccess = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("DevAccess"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))

type PlayerData = DataService.PlayerData

local MainQuestService = {}

local ATTRIBUTE = "ShopBuilt" -- the main quest items built once or standing in the shop ("Forge,WallShelf"; MainQuestRules.doneText)

local paid: { [Player]: { [string]: boolean } } = {}
local built: { [Player]: { [string]: boolean } } = {}

local function publish(player: Player)
	local set, done = built[player], paid[player]
	if set and done then
		player:SetAttribute(ATTRIBUTE, MainQuestRules.doneText(done, set))
	end
end

-- The main quest items in a saved layout
local function fromLayout(layout: any): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if typeof(layout) ~= "table" then
		return set
	end
	for _, saved in layout do
		local id = if typeof(saved) == "table" then saved.shelfId else nil
		if typeof(id) == "string" and MainQuestRules.isItem(MainQuests, id) then
			set[id] = true
		end
	end
	return set
end

-- A shelf placed: a main quest item now stands in the shop; its first build pays (the moment fires before the
-- attribute changes, so the row celebrates this item before the next goal slides in)
local function onPlaced(player: Player, shelfId: string)
	local set, done = built[player], paid[player]
	if not set or not done or not MainQuestRules.isItem(MainQuests, shelfId) then
		return
	end
	local after, first = MainQuestRules.markBuilt(done, MainQuests, shelfId)
	if first then
		paid[player] = after
		local def = Shelves.ById[shelfId]
		local xp = MainQuestRules.reward(MainQuests, if def then def.cost else 0)
		EconomyService.AddXP(player, xp)
		Remotes.MainQuestDone:FireClient(player, shelfId, xp)
	end
	set[shelfId] = true
	publish(player)
end

-- A shelf sold: it stands in the shop only while another copy does (its quest stays done: `paid` keeps it)
local function onSold(player: Player, shelfId: string, shelves: { any })
	local set = built[player]
	if not set or not MainQuestRules.isItem(MainQuests, shelfId) then
		return
	end
	local still = false
	for _, shelf in shelves do
		if shelf.def.id == shelfId then
			still = true
			break
		end
	end
	set[shelfId] = if still then true else nil
	publish(player)
end

local function load(player: Player, data: PlayerData)
	local done = MainQuestRules.clean(data.mainQuests, MainQuests)
	local set = fromLayout(data.layout)
	for id in set do
		done[id] = true -- standing in the shop already: never pays (again)
	end
	paid[player] = done
	built[player] = set
	publish(player)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe the list
local function save(player: Player, data: PlayerData)
	local done = paid[player]
	if done then
		data.mainQuests = MainQuestRules.toSave(done)
	end
end

local function unload(player: Player)
	paid[player] = nil
	built[player] = nil
end

-- Studio (/mainquest reset): every first build pays again (sell one and place it to see the moment); the line to tell
-- them, or nil for usage
function MainQuestService.Dev(player: Player, action: string): string?
	if not DevAccess.can(player) or action ~= "reset" or not paid[player] then
		return nil
	end
	paid[player] = {}
	return "Main quests: every first build pays again (Studio)"
end

function MainQuestService.Start()
	DataService.Register({ name = "MainQuestService", load = load, save = save, unload = unload })
	if Place.isFrontier() or Place.isDungeon() then
		return -- no shop here: the saved layout is all there is
	end
	local PlacementService = require(Services:WaitForChild("PlacementService")) :: any
	PlacementService.OnPlaced(onPlaced)
	PlacementService.OnSold(function(player: Player, shelfId: string)
		onSold(player, shelfId, PlacementService.GetShelves(player))
	end)
end

return MainQuestService
