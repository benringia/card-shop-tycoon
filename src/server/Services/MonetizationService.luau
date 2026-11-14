--!strict
-- Game passes: whether a player owns one (cached per session) and reacting to purchases.
-- Each owned pass is mirrored as a player attribute Has<PassKey> (e.g. HasExtraJobSlot) for the client.
-- A failed Roblox check counts as "not owned" and is retried on the next check, so it never errors.
-- Studio: the DevPass_<PassKey> attribute (toggled by /jobslot) stands in for owning the pass.
-- Some pass keys are also sold as one-time developer products (Config/Monetization UNLOCKS, owner 2026-11-14: the Extra
-- Job Slot): a bought one is saved (data.unlocks) and counts as owning the pass; its purchase opens only while it isn't
-- owned (remote BuyUnlock, Util/UnlockRules), so it's never sold twice.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local UnlockRules = require(Shared:WaitForChild("Util"):WaitForChild("UnlockRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {} -- only successful checks are cached
local retryAt: { [Player]: { [string]: number } } = {} -- failed checks: don't ask Roblox again before this
local passChangedCallbacks: { (player: Player, passKey: string) -> () } = {}
local unlocks: { [Player]: { [string]: boolean } } = {} -- one-time unlocks bought (saved), once loaded
local buyLimit = RateLimiter.new(2)

local function check(player: Player, passKey: string): boolean
	if RunService:IsStudio() and player:GetAttribute(`DevPass_{passKey}`) == true then
		return true
	end
	local bought = unlocks[player]
	if bought and bought[passKey] then
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

-- Opens a one-time unlock's purchase (the Store, the Jobs panel) while it's for sale: known, made, not owned yet
local function onBuyUnlock(player: Player, key: unknown)
	if typeof(key) ~= "string" or not buyLimit(player) then
		return
	end
	local bought = unlocks[player]
	if not bought or check(player, key) then
		return -- not loaded yet, or owned: the button says "Owned"
	end
	local productId = PurchaseService.ProductId(key)
	if UnlockRules.canBuy(bought, key, productId, Monetization.UNLOCKS) then
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end

function MonetizationService.Start()
	DataService.Register({
		name = "MonetizationService",
		load = function(player, data)
			unlocks[player] = UnlockRules.clean(data.unlocks, Monetization.UNLOCKS)
			for key in unlocks[player] do
				refresh(player, key)
			end
		end,
		-- nothing for a player this never loaded, so a failed load can't wipe what they bought
		save = function(player, data)
			local bought = unlocks[player]
			if bought then
				data.unlocks = table.clone(bought)
			end
		end,
		unload = function(player)
			unlocks[player] = nil
		end,
	})
	for _, key in Monetization.UNLOCKS do
		PurchaseService.OnProduct(key, function(player: Player): boolean
			local bought = unlocks[player]
			if not bought then
				return false -- not loaded here yet: Roblox asks again
			end
			bought[key] = true
			refresh(player, key)
			if key == "ExtraJobSlot" then
				Remotes.StoreWin:FireClient(player, "jobslot", 0) -- its win card
			end
			return true
		end)
	end
	Remotes.BuyUnlock.OnServerEvent:Connect(onBuyUnlock)
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
