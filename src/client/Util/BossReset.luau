--!strict
-- The Robux reset of every boss loot timer (Config/Bosses RESET; owner 2026-11-19, pick A: one buy ends every boss's
-- timer, its words say so): whether its button shows here (the product made, paid random items allowed where this
-- player lives, a timer with RESET.minLeft to go), its Robux price, and the buy, which the server checks again
-- (BossService). Its buttons: the boss victory screen (BattleController) and the boss board (BossBoardController).
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bosses = require(Shared:WaitForChild("Config"):WaitForChild("Bosses"))
local Monetization = require(Shared:WaitForChild("Config"):WaitForChild("Monetization"))
local BossRules = require(Shared:WaitForChild("Util"):WaitForChild("BossRules"))
local PaidRandomRules = require(Shared:WaitForChild("Util"):WaitForChild("PaidRandomRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ProductPrice = require((script.Parent :: Instance):WaitForChild("ProductPrice"))

local BossReset = {}

export type State = "offer" | "soon" | "hidden"

-- Hidden until Roblox says paid random items are sold here (a policy that can't be read counts as no)
local allowed = false
task.spawn(function()
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(Players.LocalPlayer)
	end)
	allowed = not PaidRandomRules.restricted(ok, info)
end)

local function productId(): number
	local id = (Monetization.PRODUCTS :: any)[Bosses.RESET.product]
	return if typeof(id) == "number" then id else 0
end

ProductPrice.of(productId()) -- asked now, so the first button already shows this player's price

-- Its button for these loot timers (seconds left on each boss): "offer", "soon" (the product isn't made yet: "Coming
-- soon") or "hidden"
function BossReset.state(lootIns: { number }): State
	if not allowed or not BossRules.resetOffered(lootIns, Bosses.RESET.minLeft) then
		return "hidden"
	end
	return if productId() == 0 then "soon" else "offer"
end

-- Its Robux price, nil while Roblox hasn't said (set on Creator Hub)
function BossReset.price(): number?
	return ProductPrice.of(productId())
end

-- Opens Roblox's purchase window (the server checks everything again first)
function BossReset.buy()
	if productId() ~= 0 then
		Remotes.BossResetBuy:FireServer()
	end
end

-- The victory screen's button for a boss win whose loot timer has `lootIn` seconds left, or nil
function BossReset.victoryAction(lootIn: number): any?
	if BossReset.state({ lootIn }) ~= "offer" then
		return nil
	end
	return { text = Bosses.RESET.button, under = Bosses.RESET.under, price = BossReset.price, onPress = BossReset.buy }
end

return BossReset
