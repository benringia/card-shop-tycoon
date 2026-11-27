--!strict
-- Shop rooms (spec docs/superpowers/specs/2026-11-23-shop-rooms-design.md; Config/ShopRooms, Util/ShopRooms): each
-- player's unlocked rooms (saved `rooms`), shown on their plot (PlotService.SetRooms), and the UnlockRoom remote: the
-- owner at a locked door, at the room's shop level, pays its price and the door opens for good. An open room is more
-- floor, one more customer at a time and more shelves (CustomerService and PlacementService read the plot's rooms).
-- Every refusal is a big locked card (Util/Blocked).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local RoomsConfig = require(Config:WaitForChild("ShopRooms"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Placement = require(Config:WaitForChild("Placement"))
local ShopRooms = require(Shared:WaitForChild("Util"):WaitForChild("ShopRooms"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local DevAccess = require(ServerUtil:WaitForChild("DevAccess"))
local Blocked = require(ServerUtil:WaitForChild("Blocked"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local RoomService = {}

local GRID = ShopRooms.grid(PlotConfig.WIDTH, PlotConfig.DEPTH, Placement.GRID_SIZE)

local roomsOf: { [Player]: { string } } = {}
local limit = RateLimiter.new(1)

local function apply(player: Player, animate: boolean)
	local plot = PlotService.GetPlot(player)
	local list = roomsOf[player]
	if plot and list then
		PlotService.SetRooms(plot, ShopRooms.openSet(list), animate)
	end
end

-- Where a room's door stands on this player's plot
local function doorPosition(player: Player, roomId: string): Vector3?
	local plot = PlotService.GetPlot(player)
	if not plot then
		return nil
	end
	for _, door in ShopRooms.doors(RoomsConfig, GRID) do
		if door.room == roomId then
			return (plot.floor.CFrame * CFrame.new(door.x, 0, door.z)).Position
		end
	end
	return nil
end

local function onUnlock(player: Player, roomId: unknown)
	local list = roomsOf[player]
	if typeof(roomId) ~= "string" or not list or not limit(player) then
		return
	end
	local room = RoomsConfig.ROOMS[roomId]
	local door = if room then doorPosition(player, roomId) else nil
	if not room or not door then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") or (root.Position - door).Magnitude > RoomsConfig.DOOR_REACH then
		Blocked.tell(player, "Walk up to the door to open it.")
		return
	end
	local ok, why = ShopRooms.canUnlock(RoomsConfig, roomId, ShopRooms.openSet(list), EconomyService.GetLevel(player), EconomyService.GetCash(player))
	if not ok then
		Blocked.tell(player, why or "That room can't open yet.")
		return
	end
	-- the check, the spend and the list with no yield between them: a second press finds the room open
	local spent, told = EconomyService.TrySpend(player, room.price)
	if not spent then
		if not told then -- the spend guard already said why (cash kept for restocking)
			Blocked.tell(player, ShopRooms.priceWords(RoomsConfig, roomId))
		end
		return
	end
	table.insert(list, roomId)
	roomsOf[player] = ShopRooms.clean(RoomsConfig, list)
	apply(player, true)
	TutorialService.MarkLessonSeen(player, roomId) -- Pish never teaches a room already open
	Remotes.Notify:FireClient(player, string.format(RoomsConfig.UNLOCKED, room.name), false)
end

-- Studio's "/shoproom open|lock <room|all>" (DevService): rooms opened or locked for free, no lesson; locking moves
-- anything standing in the room out to the nearest open spot (PlacementService.Refit). False and why when it can't
function RoomService.DevSet(player: Player, which: string, open: boolean): (boolean, string?)
	if not DevAccess.can(player) then
		return false, "Admin only."
	end
	local list = roomsOf[player]
	if not list then
		return false, "Your shop hasn't loaded."
	end
	if which ~= "all" and not RoomsConfig.ROOMS[which] then
		return false, "That room doesn't exist."
	end
	local set = ShopRooms.openSet(list)
	for _, id in RoomsConfig.ORDER do
		if which == "all" or which == id then
			set[id] = if open then true else nil
		end
	end
	local nextList = {}
	for _, id in RoomsConfig.ORDER do
		if set[id] then
			table.insert(nextList, id)
		end
	end
	roomsOf[player] = nextList
	apply(player, open)
	if not open then
		PlacementService.Refit(player)
	end
	return true, nil
end

function RoomService.Start()
	DataService.Register({
		name = "Rooms",
		load = function(player, data)
			roomsOf[player] = ShopRooms.clean(RoomsConfig, data.rooms)
			apply(player, false)
		end,
		save = function(player, data)
			local list = roomsOf[player]
			if not list then
				return -- never loaded: keep what's saved
			end
			data.rooms = table.clone(list)
		end,
		unload = function(player)
			roomsOf[player] = nil
		end,
	})
	Remotes.UnlockRoom.OnServerEvent:Connect(onUnlock)
end

return RoomService
