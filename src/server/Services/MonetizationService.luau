--!strict
-- Game passes: whether a player owns one (cached per session) and reacting to purchases.
-- Each owned pass is mirrored as a player attribute Has<PassKey> (e.g. HasExtraJobSlot) for the client.
-- A failed Roblox check counts as "not owned" and is retried on the next check, so it never errors.
-- Studio: the DevPass_<PassKey> attribute (toggled by /jobslot) stands in for owning the pass.
-- Some pass keys are also sold as one-time developer products (Config/Monetization UNLOCKS, owner 2026-11-14: the Extra
-- Job Slot; 2026-11-28: the Starter Pack): a bought one is saved (data.unlocks) and counts as owning the pass; its
-- purchase opens only while it isn't owned (remote BuyUnlock, Util/UnlockRules), so it's never sold twice. One that holds
-- something chance-based (Monetization CHANCE) isn't sold where Roblox restricts paid random items. Every pass and
-- unlock granted plays its win card (Monetization WIN_KINDS, StoreWinController).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local UnlockRules = require(Shared:WaitForChild("Util"):WaitForChild("UnlockRules"))
local PaidRandomRules = require(Shared:WaitForChild("Util"):WaitForChild("PaidRandomRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Services = script.Parent :: Instance
local DataService = require(Services:WaitForChild("DataService"))
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local Blocked = require(ServerUtil:WaitForChild("Blocked"))

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {} -- only successful checks are cached
local retryAt: { [Player]: { [string]: number } } = {} -- failed checks: don't ask Roblox again before this
local passChangedCallbacks: { (player: Player, passKey: string) -> () } = {}
local unlocks: { [Player]: { [string]: boolean } } = {} -- one-time unlocks bought (saved), once loaded
local unlockGrants: { [string]: (player: Player) -> boolean } = {} -- what an unlock gives besides owning it
local buyLimit = RateLimiter.new(2)

local NOT_SOLD_HERE = "Not sold where you live."

-- The win card for a pass or unlock just granted (Config/Luck WIN)
local function winCard(player: Player, key: string)
	local kind = Monetization.WIN_KINDS[key]
	if kind then
		Remotes.StoreWin:FireClient(player, kind, 0)
	end
end

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

-- What an unlock gives besides owning it, run once per purchase before it counts as bought (the Starter Pack's luck,
-- StarterService); false when it can't go through yet, so Roblox asks again
function MonetizationService.OnUnlockGrant(key: string, grant: (player: Player) -> boolean)
	unlockGrants[key] = grant
end

-- Studio only (DevService /pass): a pass or unlock as if bought (its grant and win card) or taken away again
function MonetizationService.DevGrant(player: Player, key: string, on: boolean)
	if not RunService:IsStudio() or Monetization.PASSES[key] == nil then
		return
	end
	MonetizationService.SetDevPass(player, key, on)
	if on then
		local grant = unlockGrants[key]
		if grant then
			grant(player)
		end
		winCard(player, key)
	end
end

-- Opens a one-time unlock's purchase (the Store, the Jobs panel, the Starter card) while it's for sale: known, made, not
-- owned yet, and not chance-based where paid random items are restricted (the big locked card says so)
local function onBuyUnlock(player: Player, key: unknown)
	if typeof(key) ~= "string" or not buyLimit(player) then
		return
	end
	local bought = unlocks[player]
	if not bought or check(player, key) then
		return -- not loaded yet, or owned: the button says "Owned"
	end
	local productId = PurchaseService.ProductId(key)
	if not UnlockRules.canBuy(bought, key, productId, Monetization.UNLOCKS) then
		return
	end
	if UnlockRules.chanceBased(key, Monetization) then
		local ok, info = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
		if PaidRandomRules.restricted(ok, info) then
			Blocked.tell(player, NOT_SOLD_HERE)
			return
		end
	end
	MarketplaceService:PromptProductPurchase(player, productId)
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
			local grant = unlockGrants[key]
			local granted = UnlockRules.apply(bought, key, if grant
				then function(): boolean
					return grant(player)
				end
				else nil)
			if not granted then
				return false -- its grant can't go through yet: Roblox asks again
			end
			refresh(player, key)
			winCard(player, key)
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
			if id ~= 0 and id == passId then
				owned[player] = owned[player] or {}
				owned[player][passKey] = true
				if retryAt[player] then
					retryAt[player][passKey] = nil
				end
				refresh(player, passKey)
				winCard(player, passKey)
			end
		end
	end)
end

return MonetizationService
