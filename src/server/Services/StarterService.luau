--!strict
-- The Starter Pack (spec 2026-11-28-robux-round-design, Config/Starter): counts an hour of play after Pish's first visit
-- in the main place (saved: data.starter.played), sends its card once it's due (Util/StarterRules.offerDue: never shown,
-- not owned, not where Roblox restricts paid random items), once a session until the client says it showed (then saved
-- `shown`), and gives its luck when it's bought (MonetizationService.OnUnlockGrant; the Sunny Shop look and the Shop
-- Starter title come from owning it). Started in every place so a purchase anywhere gets its luck.
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Starter = require(Shared:WaitForChild("Config"):WaitForChild("Starter"))
local StarterRules = require(Shared:WaitForChild("Util"):WaitForChild("StarterRules"))
local PaidRandomRules = require(Shared:WaitForChild("Util"):WaitForChild("PaidRandomRules"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local LuckService = require(Services:WaitForChild("LuckService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

local StarterService = {}

local KEY = "StarterPack"

local states: { [Player]: StarterRules.State } = {}
local restricted: { [Player]: boolean } = {} -- Roblox's policy, read once a session; unknown counts as not due yet
local sent: { [Player]: boolean } = {} -- the card sent this session (sent again next session until it's shown)
local shownLimit = RateLimiter.new(1)

-- Roblox's policy for paid random items (the Starter Pack holds luck), read once at load
local function readPolicy(player: Player)
	local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	if states[player] then
		restricted[player] = PaidRandomRules.restricted(ok, info)
	end
end

local function offer(player: Player)
	sent[player] = true
	Remotes.StarterOffer:FireClient(player)
end

-- One second of play, then the card if it's due and not sent this session
local function tick(player: Player, mainPlace: boolean)
	local state = states[player]
	if not state then
		return
	end
	state.played = StarterRules.played(state.played, player:GetAttribute("TutorialDone") == true, mainPlace, Starter)
	local blocked = restricted[player]
	if sent[player] or blocked == nil or player:GetAttribute("DataLoaded") ~= true then
		return
	end
	if StarterRules.offerDue(state, MonetizationService.HasPass(player, KEY), blocked, Starter) then
		offer(player)
	end
end

-- Studio and the owner's test save (DevService /starter): the card now, whatever the counters; or the counters reset
function StarterService.Dev(player: Player, action: string): string?
	local state = states[player]
	if not state then
		return nil
	end
	if action == "offer" then
		offer(player)
		return "Starter card sent: it shows at the next calm moment"
	elseif action == "reset" then
		state.played = 0
		state.shown = false
		sent[player] = nil
		return "Starter card reset: it comes after an hour of play"
	end
	return nil
end

function StarterService.Start()
	DataService.Register({
		name = "StarterService",
		load = function(player: Player, data: any)
			states[player] = StarterRules.clean(data.starter, Starter)
			task.spawn(readPolicy, player)
		end,
		-- nothing for a player this never loaded, so a failed load can't wipe their counter
		save = function(player: Player, data: any)
			local state = states[player]
			if state then
				data.starter = { played = state.played, shown = state.shown }
			end
		end,
		unload = function(player: Player)
			states[player] = nil
			restricted[player] = nil
			sent[player] = nil
		end,
	})
	-- its luck when it's bought (Config/Starter LUCK); false while LuckService hasn't loaded the player: Roblox asks again
	MonetizationService.OnUnlockGrant(KEY, function(player: Player): boolean
		return LuckService.Give(player, Starter.LUCK.strength, Starter.LUCK.seconds)
	end)
	-- the client showed the card (only one this session sent): never again
	Remotes.StarterOffer.OnServerEvent:Connect(function(player: Player)
		local state = states[player]
		if state and sent[player] and shownLimit(player) then
			state.shown = true
		end
	end)
	task.spawn(function()
		local mainPlace = not Place.isFrontier() and not Place.isDungeon()
		while true do
			task.wait(Starter.TICK)
			for player in states do
				tick(player, mainPlace)
			end
		end
	end)
end

return StarterService
