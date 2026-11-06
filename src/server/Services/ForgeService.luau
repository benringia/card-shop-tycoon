--!strict
-- The Forge (spec 2026-11-06-weapons-round1-design 4): a machine in the owner's shop, like the Condenser. Forging
-- makes a weapon (a Forge Sword in the element picked, a boss weapon from its material, a Masterwork from its recipe),
-- a reforge rolls a new grade and keeps the better one, an upgrade adds a level. The server checks the machine, the
-- distance, the shop level and the costs from its own numbers (Util/WeaponRules), takes the cash then the items (all
-- or nothing), rolls the grade (BeastRules, like cards) and gives it through WeaponService. One request at a time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Items = require(Config:WaitForChild("Items"))
local Weapons = require(Config:WaitForChild("Weapons"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Action = "forge" | "reforge" | "upgrade"
type Cost = WeaponRules.Cost

local ForgeService = {}

local allowRequest = RateLimiter.new(Weapons.FORGE_COOLDOWN)
local busy: { [Player]: boolean } = {}
local rng = Random.new()

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message, true)
end

-- The player's own Forge machine, close enough to use
local function atForge(player: Player, shelfUid: unknown): boolean
	if typeof(shelfUid) ~= "string" then
		return false
	end
	local shelf = PlacementService.GetShelf(player, shelfUid)
	if not shelf or not PlacementService.IsForge(shelf) then
		return false
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (root.Position - shelf.part.Position).Magnitude > Weapons.FORGE_DISTANCE then
		notify(player, "Get closer to the Forge.")
		return false
	end
	return true
end

-- What's missing, in words: "Not enough Warden Heartwood (9/15)"
local function shortfall(player: Player, cost: Cost, missing: string): string
	if missing == "cash" then
		return `Not enough cash (${math.floor(EconomyService.GetCash(player))}/${cost.cash})`
	end
	local item = Items.ITEMS[missing]
	return `Not enough {if item then item.name else missing} ({ItemService.GetCount(player, missing)}/{cost.items[missing]})`
end

-- Takes the cost: checked first against what the player has, then the cash, then each item; anything already taken
-- goes back if a later take fails
local function take(player: Player, cost: Cost): boolean
	local counts = {}
	for id in cost.items do
		counts[id] = ItemService.GetCount(player, id)
	end
	local canPay, missing = WeaponRules.pay(cost, EconomyService.GetCash(player), counts)
	if not canPay then
		notify(player, shortfall(player, cost, missing or "cash"))
		return false
	end
	if cost.cash > 0 and not EconomyService.TrySpend(player, cost.cash) then
		notify(player, shortfall(player, cost, "cash"))
		return false
	end
	local taken: { [string]: number } = {}
	for id, n in cost.items do
		if not ItemService.TakeItem(player, id, n) then
			for takenId, takenCount in taken do
				ItemService.GiveItem(player, takenId, takenCount)
			end
			if cost.cash > 0 then
				EconomyService.AddCash(player, cost.cash)
			end
			notify(player, shortfall(player, cost, id))
			return false
		end
		taken[id] = n
	end
	return true
end

-- Gives a taken cost back (an error after paying: the player keeps what they had)
local function refund(player: Player, cost: Cost)
	for id, n in cost.items do
		ItemService.GiveItem(player, id, n)
	end
	if cost.cash > 0 then
		EconomyService.AddCash(player, cost.cash)
	end
end

-- The cost of this action on this weapon, or nil (with a message when the player can fix it)
local function costOf(player: Player, action: Action, weapon: Weapons.Weapon): Cost?
	local owned = WeaponService.GetOwned(player, weapon.id)
	if action == "forge" then
		if owned then
			notify(player, `You have the {weapon.name}. Reforge it for a new grade.`)
			return nil
		end
		return WeaponRules.makeCost(Weapons, weapon.id)
	elseif not owned then
		notify(player, `Forge the {weapon.name} first.`)
		return nil
	elseif action == "reforge" then
		if not WeaponRules.canReforge(owned) then
			notify(player, `Your {weapon.name} is already Grade S.`)
			return nil
		end
		return WeaponRules.reforgeCost(Weapons, weapon.id)
	elseif owned.level >= Weapons.MAX_LEVEL then
		notify(player, `The {weapon.name} is already +{Weapons.MAX_LEVEL}.`)
		return nil
	end
	return WeaponRules.upgradeCost(Weapons, weapon.id, owned.level + 1)
end

-- What the paid action does: a level up, or a grade rolled and given (forge, reforge); returns what ForgeResult tells
-- the client
local function give(player: Player, action: Action, weapon: Weapons.Weapon): { [string]: any }
	if action == "upgrade" then
		local owned = WeaponService.GetOwned(player, weapon.id) :: WeaponService.Owned
		local level = owned.level + 1
		WeaponService.SetLevel(player, weapon.id, level)
		return { action = action, weaponId = weapon.id, grade = owned.grade, level = level, kept = false, owned = owned.grade }
	end
	local grade = BeastRules.rollGrade(rng:NextNumber(), weapon.rarity)
	local record = WeaponService.Give(player, weapon.id, grade, action)
	local now = WeaponService.GetOwned(player, weapon.id)
	return {
		action = action,
		weaponId = weapon.id,
		grade = grade,
		level = if now then now.level else 0,
		kept = record == nil, -- a reforge that didn't beat the grade it had
		owned = if now then now.grade else grade, -- the grade it has now
	}
end

local function perform(player: Player, action: Action, weapon: Weapons.Weapon, shelfUid: unknown)
	if not WeaponService.IsLoaded(player) or not atForge(player, shelfUid) then
		return
	end
	if not WeaponRules.unlocked(Weapons, weapon.id, EconomyService.GetLevel(player)) then
		notify(player, `The {weapon.name} opens at shop level {Weapons.FORGE_UNLOCK_LEVEL}.`)
		return
	end
	local cost = costOf(player, action, weapon)
	if not cost or not take(player, cost) then
		return
	end
	-- Paid: the weapon is given, or (anything failing on the way) the cost goes back
	local ok, result = pcall(give, player, action, weapon)
	if not ok then
		refund(player, cost)
		notify(player, "The Forge hiccuped. Nothing was spent.")
		error(result, 0)
	end
	Remotes.ForgeResult:FireClient(player, result)
end

-- Every request: rate-limited, a built weapon, one at a time per player (the flag clears on every path)
local function handle(action: Action)
	return function(player: Player, shelfUid: unknown, weaponId: unknown)
		if not allowRequest(player) or busy[player] or typeof(weaponId) ~= "string" then
			return
		end
		local weapon = Weapons.ById[weaponId]
		if not weapon or not weapon.ready then
			return
		end
		busy[player] = true
		local ok, err = pcall(perform, player, action, weapon, shelfUid)
		busy[player] = nil
		if not ok then
			warn(`[ForgeService] {action} {weaponId} for {player.Name} failed: {err}`)
		end
	end
end

function ForgeService.Start()
	Remotes.ForgeWeapon.OnServerEvent:Connect(handle("forge"))
	Remotes.UpgradeWeapon.OnServerEvent:Connect(handle("upgrade"))
	Remotes.ReforgeWeapon.OnServerEvent:Connect(handle("reforge"))
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return ForgeService
