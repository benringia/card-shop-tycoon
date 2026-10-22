--!strict
-- Travel between the main game and the Frontier place (battles part 3a). Both places run this. A teleport is a
-- leave: the normal leave path ends any fight and saves, and ProfileStore hands the save to the next server.
-- Main game: a plaza portal opens the menu (Explore, or Join a friend who is in a Frontier server).
-- Frontier: the entrance's Return portal and the client's home button teleport back to the main game.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Places = require(Shared:WaitForChild("Config"):WaitForChild("Places"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
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

local function onTravel(player: Player, where: unknown, friendUserId: unknown)
	if not allowTravel(player) then
		return
	end
	if where == "home" then
		if Place.isFrontier() then
			teleport(player, Places.MAIN_PLACE_ID)
		end
		return
	end
	if Place.isFrontier() then
		return -- Explore / Join friend are main-game choices
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

function FrontierService.Start()
	Remotes.FrontierTravel.OnServerEvent:Connect(onTravel)
	-- Failures Roblox reports after the teleport started (server full, shut down...): the player is still here
	TeleportService.TeleportInitFailed:Connect(function(player, result, message)
		warn(`[FrontierService] teleport failed for {player.Name}: {result} {message}`)
		tell(player, if result == Enum.TeleportResult.GameFull then "That server is full. Try again or Explore instead."
			else "The teleport didn't work. Try again in a moment.")
	end)
	if Place.isFrontier() then
		WildService.SetHomeHandler(function(player)
			teleport(player, Places.MAIN_PLACE_ID)
		end)
		return
	end
	local plaza = workspace:FindFirstChild("Plaza") or Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = workspace
	local spot = Places.FRONTIER_PORTAL
	WildService.BuildPortal(plaza, "The Frontier", Vector3.new(spot.x, spot.y, spot.z), Vector3.new(-1, 0, 0), "Travel", function(player)
		Remotes.FrontierTravel:FireClient(player, { open = true })
	end)
end

return FrontierService
