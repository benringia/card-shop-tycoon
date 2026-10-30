--!strict
-- Travel between the main game and the Frontier place (battles part 3a). Both places run this. A teleport is a
-- leave: the normal leave path ends any fight and saves, and ProfileStore hands the save to the next server.
-- Main game: a plaza portal opens the menu (Explore, or Join a friend who is in a Frontier server).
-- Frontier: the entrance's Return portal and the client's home button teleport back to the main game.
-- Dungeon: the home button (and leaving the run) teleports back to the Frontier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Places = require(Shared:WaitForChild("Config"):WaitForChild("Places"))
local Town = require(Shared:WaitForChild("Config"):WaitForChild("Town"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local PortalTrails = require(Shared:WaitForChild("Util"):WaitForChild("PortalTrails"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local FrontierService = {}

local allowTravel = RateLimiter.new(Places.TRAVEL_COOLDOWN)

local function tell(player: Player, message: string)
	Remotes.FrontierTravel:FireClient(player, { message = message })
end

local function teleport(player: Player, placeId: number, options: TeleportOptions?)
	if RunService:IsStudio() then
		tell(player, "Teleports only work in the published game.")
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not ok then
		warn(`[FrontierService] teleport failed for {player.Name}: {err}`)
		tell(player, "The teleport didn't work. Try again in a moment.")
	end
end

-- Where a friend is right now, if it's a Frontier server: its instance id
local function friendFrontierServer(player: Player, friendUserId: number): string?
	local okFriend, isFriend = pcall(function()
		return player:IsFriendsWith(friendUserId)
	end)
	if not okFriend or not isFriend then
		return nil
	end
	local okWhere, _, _, placeId, instanceId = pcall(function()
		return TeleportService:GetPlayerPlaceInstanceAsync(friendUserId)
	end)
	if okWhere and placeId == Places.FRONTIER_PLACE_ID and typeof(instanceId) == "string" and instanceId ~= "" then
		return instanceId
	end
	return nil
end

-- The menu's choices only count from beside the Frontier portal, so the walk there can't be skipped
local function atPortal(player: Player): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false
	end
	local spot = Places.FRONTIER_PORTAL
	return PortalTrails.near({ x = root.Position.X, z = root.Position.Z }, { x = spot.x, z = spot.z }, Town.PORTAL_REACH)
end

local function onTravel(player: Player, where: unknown, friendUserId: unknown)
	if not allowTravel(player) then
		return
	end
	if where == "home" then
		if Place.isDungeon() then
			teleport(player, Places.FRONTIER_PLACE_ID)
		elseif Place.isFrontier() then
			teleport(player, Places.MAIN_PLACE_ID)
		end
		return
	end
	if Place.isFrontier() or Place.isDungeon() then
		return -- Explore / Join friend are main-game choices
	elseif not atPortal(player) then
		tell(player, "Walk to the Frontier portal at Frostpeak to travel.")
	elseif Places.FRONTIER_PLACE_ID == 0 then
		tell(player, "The Frontier is coming soon!")
	elseif where == "explore" then
		teleport(player, Places.FRONTIER_PLACE_ID)
	elseif where == "friend" then
		if typeof(friendUserId) ~= "number" or friendUserId ~= math.floor(friendUserId) or friendUserId <= 0 then
			return
		end
		local instanceId = friendFrontierServer(player, friendUserId)
		if not instanceId then
			tell(player, "That friend isn't in the Frontier any more.")
			return
		end
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = instanceId
		teleport(player, Places.FRONTIER_PLACE_ID, options)
	end
end

-- The Dungeon: back to the Frontier (a run's end, leaving it, the home button). In Studio it only says so.
function FrontierService.ReturnToFrontier(player: Player)
	teleport(player, Places.FRONTIER_PLACE_ID)
end

function FrontierService.Start()
	Remotes.FrontierTravel.OnServerEvent:Connect(onTravel)
	-- Failures Roblox reports after the teleport started (server full, shut down...): the player is still here
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn(`[FrontierService] teleport failed for {player.Name}: {result} {message}`)
		tell(player, if result == Enum.TeleportResult.GameFull then "That server is full. Try again or Explore instead."
			else "The teleport didn't work. Try again in a moment.")
	end)
	if Place.isDungeon() then
		WildService.SetHomeHandler(FrontierService.ReturnToFrontier)
		return
	elseif Place.isFrontier() then
		WildService.SetHomeHandler(function(player)
			teleport(player, Places.MAIN_PLACE_ID)
		end)
		return
	end
	local plaza = workspace:FindFirstChild("Plaza") or Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = workspace
	local spot = Places.FRONTIER_PORTAL
	local facing = PortalTrails.areaFacing(Town.PORTAL_AREAS, "Frontier")
	WildService.BuildPortal(plaza, "The Frontier", Vector3.new(spot.x, spot.y, spot.z), Vector3.new(facing.x, 0, facing.z), "Travel", function(player)
		Remotes.FrontierTravel:FireClient(player, { open = true })
	end)
end

return FrontierService
