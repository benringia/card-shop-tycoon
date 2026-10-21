--!strict
-- Game passes: whether a player owns one (cached per session) and reacting to purchases.
-- Each owned pass is mirrored as a player attribute Has<PassKey> (e.g. HasExtraJobSlot) for the client.
-- A failed Roblox check counts as "not owned" and is retried on the next check, so it never errors.
-- Studio: the DevPass_<PassKey> attribute (toggled by /jobslot) stands in for owning the pass.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Monetization = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Monetization"))

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {} -- only successful checks are cached
local retryAt: { [Player]: { [string]: number } } = {} -- failed checks: don't ask Roblox again before this
local passChangedCallbacks: { (player: Player, passKey: string) -> () } = {}

local function check(player: Player, passKey: string): boolean
	if RunService:IsStudio() and player:GetAttribute(`DevPass_{passKey}`) == true then
		return true
	end
	local passId = Monetization.PASSES[passKey]
	if typeof(passId) ~= "number" or passId == 0 then
		return false
	end
	local cache = owned[player]
	if cache and cache[passKey] ~= nil then
		return cache[passKey]
	end
	-- Backoff after a failure so an outage doesn't mean a Roblox call every status update
	local failures = retryAt[player]
	if failures and failures[passKey] and os.clock() < failures[passKey] then
		return false
	end
	local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
	if not ok then
		warn(`[MonetizationService] pass check failed for {player.Name}: {result}`)
		retryAt[player] = retryAt[player] or {}
		retryAt[player][passKey] = os.clock() + Monetization.CHECK_RETRY_SECONDS
		return false
	end
	if failures then
		failures[passKey] = nil
	end
	owned[player] = owned[player] or {}
	owned[player][passKey] = result == true
	return result == true
end

-- Re-checks a pass and updates the player's attribute; tells listeners if it changed
local function refresh(player: Player, passKey: string)
	local before = player:GetAttribute(`Has{passKey}`) == true
	local now = check(player, passKey)
	player:SetAttribute(`Has{passKey}`, now)
	if before ~= now then
		for _, callback in passChangedCallbacks do
			task.spawn(callback, player, passKey)
		end
	end
end

function MonetizationService.HasPass(player: Player, passKey: string): boolean
	return check(player, passKey)
end

-- True while the last ownership check failed and is waiting to retry (Roblox couldn't answer)
function MonetizationService.IsCheckFailing(player: Player, passKey: string): boolean
	if not owned[player] or owned[player][passKey] == nil then
		check(player, passKey)
	end
	local failures = retryAt[player]
	return failures ~= nil and failures[passKey] ~= nil
end

function MonetizationService.OnPassChanged(callback: (player: Player, passKey: string) -> ())
	table.insert(passChangedCallbacks, callback)
end

-- Studio only (DevService): pretend to own or not own a pass
function MonetizationService.SetDevPass(player: Player, passKey: string, value: boolean)
	if not RunService:IsStudio() then
		return
	end
	player:SetAttribute(`DevPass_{passKey}`, value)
	refresh(player, passKey)
end

function MonetizationService.Start()
	local function onPlayerAdded(player: Player)
		for passKey in Monetization.PASSES do
			task.spawn(refresh, player, passKey)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		retryAt[player] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for passKey, id in Monetization.PASSES do
			if id == passId then
				owned[player] = owned[player] or {}
				owned[player][passKey] = true
				if retryAt[player] then
					retryAt[player][passKey] = nil
				end
				refresh(player, passKey)
			end
		end
	end)
end

return MonetizationService
