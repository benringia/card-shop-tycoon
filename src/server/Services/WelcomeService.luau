--!strict
-- Whether a player has seen the first-visit welcome cinematic (Portal Worlds spec; saved as data.seenWelcome). Shows it
-- to the client as the player attribute SeenWelcome once their data loads; the client plays the cinematic while it's
-- false and says when it's done (Remotes.WelcomeSeen). Players from before the cinematic count as having seen it
-- (Migrations v13).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local WelcomeService = {}

local SEEN_COOLDOWN = 1 -- seconds between WelcomeSeen requests

local seen: { [Player]: boolean } = {}
local allowSeen = RateLimiter.new(SEEN_COOLDOWN)

local function setSeen(player: Player, value: boolean)
	seen[player] = value
	player:SetAttribute("SeenWelcome", value)
end

-- Studio's /intro: play it again
function WelcomeService.Replay(player: Player)
	if seen[player] ~= nil then
		setSeen(player, false)
	end
end

local function load(player: Player, data: PlayerData)
	setSeen(player, data.seenWelcome == true)
end

local function save(player: Player, data: PlayerData)
	local value = seen[player]
	if value ~= nil then
		data.seenWelcome = value
	end
end

local function unload(player: Player)
	seen[player] = nil
end

function WelcomeService.Start()
	DataService.Register({ name = "WelcomeService", load = load, save = save, unload = unload })
	Remotes.WelcomeSeen.OnServerEvent:Connect(function(player)
		if allowSeen(player) and seen[player] ~= nil then
			setSeen(player, true)
		end
	end)
end

return WelcomeService
