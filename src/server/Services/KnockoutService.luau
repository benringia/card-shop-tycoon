--!strict
-- Knocked out in the Wild (spec 2026-11-12-timed-upgrades-revive-design): a lost fight in a dangerous place leaves you
-- where you fell, unable to move, with the "Knocked out!" screen (client KnockoutController) counting
-- Combat.DANGER.knockout.seconds down. At 0, or "Wake at the spring", you wake at the spring (WildService.SendToSpring);
-- "Revive here" (the Revive developer product, PurchaseService) stands you up on the spot with your cards rested. The
-- countdown waits while the purchase prompt is open (Util/KnockoutRules, `promptWait` seconds at most). Monsters leave
-- a knocked-out player alone, and for `grace` seconds after a revive (BattleService's fight check).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local KnockoutRules = require(Shared:WaitForChild("Util"):WaitForChild("KnockoutRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local PurchaseService = require(Services:WaitForChild("PurchaseService"))
local WildService = require(Services:WaitForChild("WildService"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local KnockoutService = {}

type State = {
	startedAt: number,
	pausedFor: number,
	pausedAt: number?, -- the Revive prompt opened then (the countdown waits)
	humanoid: Humanoid,
	walkSpeed: number,
	jumpPower: number,
	jumpHeight: number,
}

local LOOK = Combat.DANGER.knockout
local out: { [Player]: State } = {}
local calmUntil: { [Player]: number } = {} -- just revived: monsters leave them alone till then
local allowChoice = RateLimiter.new(0.5)
-- BattleService.ClearResting, handed in by BattleService.Start (BattleService requires this module)
local wake: (player: Player) -> () = function() end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function timeLeft(state: State, now: number): number
	return KnockoutRules.left(state.startedAt, KnockoutRules.pausedFor(state.pausedAt, state.pausedFor, now, LOOK.promptWait), now, LOOK.seconds)
end

-- The screen: seconds left and whether it's waiting on the prompt, or nil when it's over
local function send(player: Player)
	local state = out[player]
	Remotes.Knockout:FireClient(player, if state then { left = timeLeft(state, os.clock()), paused = state.pausedAt ~= nil } else nil)
end

-- Out of the knockout: movement back (the same body only; a new one starts fresh), the screen gone
local function release(player: Player)
	local state = out[player]
	if not state then
		return
	end
	out[player] = nil
	if humanoidOf(player) == state.humanoid then
		state.humanoid.WalkSpeed = state.walkSpeed
		state.humanoid.JumpPower = state.jumpPower
		state.humanoid.JumpHeight = state.jumpHeight
	end
	if player.Parent then
		send(player)
	end
end

local function toSpring(player: Player)
	release(player)
	if player.Parent and WildService.SendToSpring(player) then
		Remotes.Notify:FireClient(player, LOOK.wokeAtSpring, false)
	end
end

-- The Revive product: up where you fell with your cards rested; bought after waking (the prompt outlived the
-- countdown): your cards rested all the same. Always granted.
local function revive(player: Player): boolean
	wake(player)
	if out[player] then
		release(player)
		calmUntil[player] = os.clock() + LOOK.grace
		Remotes.Notify:FireClient(player, LOOK.revived, false)
	else
		Remotes.Notify:FireClient(player, LOOK.rested, false)
	end
	return true
end

-- A lost fight in a dangerous place (BattleService): down where you fell, the countdown starts
function KnockoutService.KnockOut(player: Player)
	if out[player] then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		WildService.SendToSpring(player) -- no body to hold down
		return
	end
	out[player] = {
		startedAt = os.clock(),
		pausedFor = 0,
		humanoid = humanoid,
		walkSpeed = humanoid.WalkSpeed,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
	}
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	send(player)
end

function KnockoutService.IsOut(player: Player): boolean
	return out[player] ~= nil
end

-- Whether monsters leave this player alone: knocked out, or revived a moment ago
function KnockoutService.IsSpared(player: Player): boolean
	return out[player] ~= nil or (calmUntil[player] or 0) > os.clock()
end

function KnockoutService.SetWake(handler: (player: Player) -> ())
	wake = handler
end

function KnockoutService.Start()
	PurchaseService.OnProduct("Revive", revive)
	Remotes.KnockoutChoice.OnServerEvent:Connect(function(player: Player, choice: unknown)
		local state = out[player]
		if not state or not allowChoice(player) then
			return
		end
		if choice == "spring" then
			toSpring(player)
		elseif choice == "revive" then
			local productId = PurchaseService.ProductId("Revive")
			if productId == 0 then
				return -- not created yet: the button says "Coming soon"
			end
			if not state.pausedAt then
				state.pausedAt = os.clock()
				send(player)
			end
			MarketplaceService:PromptProductPurchase(player, productId)
		end
	end)
	-- The prompt closed without buying: the countdown runs on (bought: ProcessReceipt stands them up; if that never
	-- comes, the pause runs out after `promptWait`)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
		local player = Players:GetPlayerByUserId(userId)
		local state = if player then out[player] else nil
		if not player or not state or not state.pausedAt or isPurchased or productId ~= PurchaseService.ProductId("Revive") then
			return
		end
		local now = os.clock()
		state.pausedFor = KnockoutRules.pausedFor(state.pausedAt, state.pausedFor, now, LOOK.promptWait)
		state.pausedAt = nil
		send(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		out[player] = nil
		calmUntil[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for player, state in table.clone(out) do
				if humanoidOf(player) ~= state.humanoid or not WildService.IsInWild(player) then
					release(player) -- a new body (a reset), or home another way: up already
				elseif timeLeft(state, now) <= 0 then
					toSpring(player)
				end
			end
		end
	end)
end

return KnockoutService
