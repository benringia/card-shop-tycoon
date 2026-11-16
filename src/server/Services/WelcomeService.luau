--!strict
-- Whether a player has seen the first-visit welcome cinematic (Portal Worlds spec; saved as data.seenWelcome). Shows it
-- to the client as the player attribute SeenWelcome once their data loads; the client plays the cinematic while it's
-- false and says when it's done (Remotes.WelcomeSeen). Players from before the cinematic count as having seen it
-- (Migrations v13). The prologue before it the same way (spec 2026-11-14-prologue-hydra-design; data.seenPrologue,
-- attribute SeenPrologue, Remotes.PrologueSeen; saves from before it count it as seen, Migrations v29); the welcome
-- flight waits for it (WelcomeController).
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
local prologueSeen: { [Player]: boolean } = {}
local allowSeen = RateLimiter.new(SEEN_COOLDOWN)
local allowPrologueSeen = RateLimiter.new(SEEN_COOLDOWN)

local function setSeen(player: Player, value: boolean)
	seen[player] = value
	player:SetAttribute("SeenWelcome", value)
end

local function setPrologueSeen(player: Player, value: boolean)
	prologueSeen[player] = value
	player:SetAttribute("SeenPrologue", value)
end

-- Whether the prologue may play for this player now (not seen yet, or Studio's /prologue): PrologueService's check
-- The prologue counted as seen by the server (PrologueService: its lent loadout's time ran out)
function WelcomeService.FinishPrologue(player: Player)
	if prologueSeen[player] ~= nil then
		setPrologueSeen(player, true)
	end
end

function WelcomeService.PrologueOpen(player: Player): boolean
	return prologueSeen[player] == false and player:GetAttribute("SeenPrologue") == false
end

-- Studio's /prologue: play it now on their screen (it says when it's done, as on a first join)
function WelcomeService.ReplayPrologue(player: Player)
	if prologueSeen[player] ~= nil then
		setPrologueSeen(player, false)
		Remotes.PrologueReplay:FireClient(player)
	end
end

-- Studio's /prologue reset: unseen, so it plays on the next join
function WelcomeService.ResetPrologue(player: Player)
	if prologueSeen[player] ~= nil then
		prologueSeen[player] = false -- saved as unseen; the attribute stays so it doesn't start now
	end
end

-- Studio's /intro: play it again
function WelcomeService.Replay(player: Player)
	if seen[player] ~= nil then
		setSeen(player, false)
	end
end

local function load(player: Player, data: PlayerData)
	setPrologueSeen(player, data.seenPrologue == true)
	setSeen(player, data.seenWelcome == true)
end

local function save(player: Player, data: PlayerData)
	local value = seen[player]
	if value ~= nil then
		data.seenWelcome = value
	end
	local prologue = prologueSeen[player]
	if prologue ~= nil then
		data.seenPrologue = prologue
	end
end

local function unload(player: Player)
	seen[player] = nil
	prologueSeen[player] = nil
end

function WelcomeService.Start()
	DataService.Register({ name = "WelcomeService", load = load, save = save, unload = unload })
	Remotes.WelcomeSeen.OnServerEvent:Connect(function(player)
		if allowSeen(player) and seen[player] ~= nil then
			setSeen(player, true)
		end
	end)
	Remotes.PrologueSeen.OnServerEvent:Connect(function(player)
		if allowPrologueSeen(player) and prologueSeen[player] ~= nil then
			setPrologueSeen(player, true)
		end
	end)
end

return WelcomeService
