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
local SkillText = require(Shared:WaitForChild("Util"):WaitForChild("SkillText"))
local ElementNames = require(Shared:WaitForChild("Util"):WaitForChild("ElementNames"))
local ElementNamesConfig = require(Shared:WaitForChild("Config"):WaitForChild("ElementNames"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))
local BattleSim = require(Util:WaitForChild("BattleSim"))
local Blocked = require(Util:WaitForChild("Blocked"))

type PlayerData = DataService.PlayerData
export type Owned = WeaponRules.Owned

local WeaponService = {}

local owned: { [Player]: { [string]: Owned } } = {} -- loaded players only
local equipped: { [Player]: string } = {}
-- weapons in the Forge (UpgradeJobService): out of the switch and not equippable till their job is done (spec
-- 2026-11-12-timed-upgrades-revive-design)
local locked: { [Player]: { [string]: boolean } } = {}
-- the prologue's lent weapon (PrologueService): in hand whatever the shop level, never saved or in the switch
local lent: { [Player]: { id: string, record: Owned } } = {}
local isFighting: (Player) -> boolean = function()
	return false
end
local onSwap: (Player) -> () = function() end
local allowEquip = RateLimiter.new(Weapons.EQUIP_COOLDOWN)
local allowRequest = RateLimiter.new(Weapons.REQUEST_COOLDOWN)

-- BattleService hands its check in (it requires this service, so this one can't require it)
function WeaponService.SetFightCheck(check: (Player) -> boolean)
	isFighting = check
end

-- BattleService's swap lock: told when a player in a fight switches weapon (the quick switch, spec
-- 2026-11-07-weapons-round2-design 6)
function WeaponService.SetSwapHook(hook: (Player) -> ())
	onSwap = hook
end

-- The weapon in hand: nil below the sword's shop level, otherwise the equipped one (the Steel Sword by default)
function WeaponService.GetEquipped(player: Player): string?
	local borrowed = lent[player]
	if borrowed then
		return borrowed.id
	end
	-- the first sword: from Chikin after his first fight (CombatTutorialService sets SwordGiven), or at its shop level
	if not WeaponRules.swordReady(EconomyService.GetLevel(player), Swords.UNLOCK_SHOP_LEVEL, player:GetAttribute("SwordGiven") == true) then
		return nil
	end
	return equipped[player] or Weapons.STARTER
end

function WeaponService.IsLoaded(player: Player): boolean
	return owned[player] ~= nil
end

function WeaponService.GetOwned(player: Player, weaponId: string): Owned?
	local borrowed = lent[player]
	if borrowed and borrowed.id == weaponId then
		return borrowed.record
	end
	local mine = owned[player]
	return if mine then mine[weaponId] else nil
end

-- The equipped weapon's Power: every sword cut and skill hit is multiplied by it
-- Every weapon the player owns, by id (not a lent one); empty while their save isn't loaded
function WeaponService.GetAll(player: Player): { [string]: Owned }
	return owned[player] or {}
end

function WeaponService.Power(player: Player): number
	local weaponId = WeaponService.GetEquipped(player)
	if not weaponId then
		return Weapons.STARTER_POWER
	end
	local record = WeaponService.GetOwned(player, weaponId)
	return WeaponRules.power(Weapons, weaponId, if record then record.grade else "C", if record then record.level else 0)
end

-- A sword hit's weapon (WeaponRules.hitInfo): `weaponId`, the one the cut or skill started with (default: the one in
-- hand), at its grade, bonded or not with the creature fighting for the player
function WeaponService.HitInfo(player: Player, creatureElement: string?, weaponId: string?): BattleSim.SwordWeapon
	local id = weaponId or WeaponService.GetEquipped(player) or Weapons.STARTER
	local record = WeaponService.GetOwned(player, id)
	return WeaponRules.hitInfo(Weapons, id, if record then record.grade else "C", creatureElement)
end

-- A super pressed (owner 2026-11-19: Epic and Legendary supers need a weapon of the creature's element; no exceptions
-- since weapons round 4, the Prism Blade included): the scale the weapon in hand fires it at (WeaponRules.superScale), or nil after the locked card
-- saying which weapon it needs. `cardName`: the creature's card, `element`: its element key.
function WeaponService.SuperScale(player: Player, cardName: string, element: string): number?
	local weaponId = WeaponService.GetEquipped(player)
	if not weaponId or not WeaponRules.superUnlocked(Weapons, weaponId, element) then
		local plain = ElementNames.display(element, ElementNamesConfig)
		Blocked.tell(player, SkillText.superLocked(cardName, plain), { title = Weapons.SUPER.lockedTitle })
		return nil
	end
	local record = WeaponService.GetOwned(player, weaponId)
	return WeaponRules.superScale(Weapons, weaponId, if record then record.grade else "C", if record then record.level else 0)
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

-- The prologue: `weaponId` at `record` in hand until EndLend (the character's attributes follow; nothing is saved)
function WeaponService.Lend(player: Player, weaponId: string, record: Owned)
	if not owned[player] or not Weapons.ById[weaponId] then
		return
	end
	lent[player] = { id = weaponId, record = { grade = record.grade, level = record.level } }
	WeaponService.ApplyAttributes(player)
end

function WeaponService.EndLend(player: Player)
	if lent[player] then
		lent[player] = nil
		WeaponService.ApplyAttributes(player)
	end
end

function WeaponService.IsLent(player: Player): boolean
	return lent[player] ~= nil
end

-- Tells the client and refreshes the character after any change
function WeaponService.Changed(player: Player)
	if not owned[player] then
		return
	end
	Remotes.WeaponsChanged:FireClient(player, { owned = snapshot(player), equipped = equipped[player] or Weapons.STARTER, locked = locked[player] or {} })
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

-- Studio's /weapon: owns this weapon at exactly this grade and level
function WeaponService.SetForTesting(player: Player, weaponId: string, grade: string, level: number)
	local mine = owned[player]
	if not mine or not Weapons.ById[weaponId] then
		return
	end
	mine[weaponId] = { grade = grade, level = math.clamp(math.floor(level), 0, Weapons.MAX_LEVEL) }
	WeaponService.Changed(player)
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
	if lent[player] then
		Blocked.tell(player, "You can't switch weapons right now.")
		return
	end
	local weapon = Weapons.ById[weaponId]
	if not weapon or not weapon.ready or not WeaponService.GetEquipped(player) then
		return
	end
	local blocked = WeaponRules.equipBlock(EconomyService.GetLevel(player), Swords.UNLOCK_SHOP_LEVEL, player:GetAttribute("SwordGiven") == true)
	if blocked then
		Remotes.Notify:FireClient(player, blocked, true)
		return
	end
	if weaponId ~= Weapons.STARTER and not WeaponService.GetOwned(player, weaponId) then
		return
	end
	if WeaponService.IsLocked(player, weaponId) then
		Blocked.tell(player, `Your {weapon.name} is in the Forge.`)
		return
	end
	local switched = equipped[player] ~= weaponId
	equipped[player] = weaponId
	WeaponService.Changed(player)
	-- a switch mid-fight costs SWAP_SECONDS with no cut or skill (BattleService)
	if switched and isFighting(player) then
		onSwap(player)
	end
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
	locked[player] = nil
	lent[player] = nil
end

-- A weapon going into the Forge (or back out): while locked it can't be equipped and leaves the switch; the one in hand
-- swaps for the Steel Sword
function WeaponService.SetLocked(player: Player, weaponId: string, isLocked: boolean)
	local mine = locked[player] or {}
	locked[player] = mine
	mine[weaponId] = if isLocked then true else nil
	if isLocked and equipped[player] == weaponId then
		equipped[player] = Weapons.STARTER
	end
	WeaponService.Changed(player)
end

function WeaponService.IsLocked(player: Player, weaponId: string): boolean
	local mine = locked[player]
	return mine ~= nil and mine[weaponId] == true
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
