--!strict
-- The weapons a player owns and the one in hand (spec 2026-11-06-weapons-round1-design). Saved as
-- weapons = { [weaponId] = { grade, level } } and equippedWeapon; the Steel Sword is everyone's and never saved.
-- From shop level Swords.UNLOCK_SHOP_LEVEL the character carries the equipped weapon: attributes Sword (the weapon
-- id), SwordGrade and SwordLevel, which clients draw from. The client gets WeaponsChanged on load and every change.
-- Forging, upgrading and drops call Give / SetLevel; only this service changes the table.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local Swords = require(Shared:WaitForChild("Config"):WaitForChild("Swords"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData
export type Owned = WeaponRules.Owned

local WeaponService = {}

local owned: { [Player]: { [string]: Owned } } = {} -- loaded players only
local equipped: { [Player]: string } = {}
local isFighting: (Player) -> boolean = function()
	return false
end
local allowEquip = RateLimiter.new(Weapons.EQUIP_COOLDOWN)
local allowRequest = RateLimiter.new(Weapons.REQUEST_COOLDOWN)

-- BattleService hands its check in (it requires this service, so this one can't require it)
function WeaponService.SetFightCheck(check: (Player) -> boolean)
	isFighting = check
end

-- The weapon in hand: nil below the sword's shop level, otherwise the equipped one (the Steel Sword by default)
function WeaponService.GetEquipped(player: Player): string?
	if EconomyService.GetLevel(player) < Swords.UNLOCK_SHOP_LEVEL then
		return nil
	end
	return equipped[player] or Weapons.STARTER
end

function WeaponService.GetOwned(player: Player, weaponId: string): Owned?
	local mine = owned[player]
	return if mine then mine[weaponId] else nil
end

-- The equipped weapon's Power: every sword cut and skill hit is multiplied by it
function WeaponService.Power(player: Player): number
	local weaponId = WeaponService.GetEquipped(player)
	if not weaponId then
		return Weapons.STARTER_POWER
	end
	local record = WeaponService.GetOwned(player, weaponId)
	return WeaponRules.power(Weapons, weaponId, if record then record.grade else "C", if record then record.level else 0)
end

-- The character's Sword, SwordGrade and SwordLevel attributes from the weapon in hand
function WeaponService.ApplyAttributes(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local weaponId = WeaponService.GetEquipped(player)
	local record = if weaponId then WeaponService.GetOwned(player, weaponId) else nil
	character:SetAttribute("Sword", weaponId)
	character:SetAttribute("SwordGrade", if record then record.grade else nil)
	character:SetAttribute("SwordLevel", if record then record.level else nil)
end

local function snapshot(player: Player): { [string]: Owned }
	local copy = {}
	for id, record in owned[player] or {} do
		copy[id] = { grade = record.grade, level = record.level }
	end
	return copy
end

-- Tells the client and refreshes the character after any change
function WeaponService.Changed(player: Player)
	if not owned[player] then
		return
	end
	Remotes.WeaponsChanged:FireClient(player, { owned = snapshot(player), equipped = equipped[player] or Weapons.STARTER })
	WeaponService.ApplyAttributes(player)
end

-- Gives a weapon (forged, reforged or dropped): the new record (nil when nothing changed) and the material refund,
-- already paid (a drop of one you own turns into its material)
function WeaponService.Give(player: Player, weaponId: string, grade: string, how: "forge" | "reforge" | "drop"): (Owned?, number)
	local mine = owned[player]
	if not mine or not Weapons.ById[weaponId] then
		return nil, 0
	end
	local record, refund = WeaponRules.give(mine, weaponId, grade, how, Weapons)
	if record then
		mine[weaponId] = record
	end
	if refund > 0 then
		local material = WeaponRules.material(Weapons, weaponId)
		if material then
			ItemService.GiveItem(player, material, refund)
		end
	end
	if record then
		WeaponService.Changed(player)
	end
	return record, refund
end

-- An upgrade: the owned weapon's new level (whole, 0..MAX_LEVEL)
function WeaponService.SetLevel(player: Player, weaponId: string, level: number)
	local record = WeaponService.GetOwned(player, weaponId)
	if not record then
		return
	end
	record.level = math.clamp(math.floor(level), 0, Weapons.MAX_LEVEL)
	WeaponService.Changed(player)
end

local function onEquip(player: Player, weaponId: unknown)
	if not allowEquip(player) or typeof(weaponId) ~= "string" or not owned[player] then
		return
	end
	local weapon = Weapons.ById[weaponId]
	if not weapon or not weapon.ready or isFighting(player) or not WeaponService.GetEquipped(player) then
		return
	end
	if weaponId ~= Weapons.STARTER and not WeaponService.GetOwned(player, weaponId) then
		return
	end
	equipped[player] = weaponId
	WeaponService.Changed(player)
end

local function load(player: Player, data: PlayerData)
	local mine, equip, dropped = WeaponRules.read(Weapons, data.weapons, data.equippedWeapon)
	if #dropped > 0 then
		warn(`[WeaponService] {player.Name}: unknown weapons dropped: {table.concat(dropped, ", ")}`)
	end
	owned[player] = mine
	equipped[player] = equip
	WeaponService.Changed(player)
end

-- Nothing for a player this service never loaded, so a failed load can't wipe their weapons
local function save(player: Player, data: PlayerData)
	if not owned[player] then
		return
	end
	data.weapons = snapshot(player)
	data.equippedWeapon = equipped[player] or Weapons.STARTER
end

local function unload(player: Player)
	owned[player] = nil
	equipped[player] = nil
end

function WeaponService.Start()
	DataService.Register({ name = "WeaponService", load = load, save = save, unload = unload })
	Remotes.EquipWeapon.OnServerEvent:Connect(onEquip)
	Remotes.WeaponsChanged.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			WeaponService.Changed(player)
		end
	end)
end

return WeaponService
