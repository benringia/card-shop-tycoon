--!strict
-- The weapons a player owns and the one in hand (spec 2026-11-06-weapons-round1-design). Saved as
-- weapons = { [weaponId] = { grade, level, mutation?, pending? } } and equippedWeapon; the Steel Sword is everyone's
-- and never saved. From shop level Swords.UNLOCK_SHOP_LEVEL the character carries the equipped weapon: attributes Sword
-- (the weapon id), SwordGrade, SwordLevel and SwordMutation (its mutation's rarity), which clients draw from. The
-- client gets WeaponsChanged on load and every change. Forging, upgrading and drops call Give / SetLevel; mutations
-- come through Offer (a boss's drop of a weapon you have, the Forge's Mutate: weapons round 4 part 2) and the player's
-- ChooseMutation; only this service changes the table.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))
local Mutations = require(Shared:WaitForChild("Config"):WaitForChild("Mutations"))
local Swords = require(Shared:WaitForChild("Config"):WaitForChild("Swords"))
local MutationRules = require(Shared:WaitForChild("Util"):WaitForChild("MutationRules"))
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
type Mutation = MutationRules.Mutation
type Pending = MutationRules.Pending
-- A mutation offered on a weapon (a boss drop of one you have, the Forge's Mutate): `applied` when the weapon had
-- none (it's on at once), else it waits as the record's `pending` until ChooseMutation with this `id`. `essence`: what
-- the one you don't keep turns into either way (take: the old one's, keep: the new one's); none for a Forge roll
-- (`source` "forge": Essence comes only from boss drops, owner 2026-11-26)
export type Offer = {
	id: string,
	weaponId: string,
	grade: string, -- the weapon as it is (the reveal draws it so)
	level: number,
	mutation: Mutation,
	have: Mutation?,
	applied: boolean,
	essence: { take: number, keep: number },
	source: string,
}

local WeaponService = {}

local owned: { [Player]: { [string]: Owned } } = {} -- loaded players only
local equipped: { [Player]: string } = {}
-- the id of each weapon's waiting offer (fresh every session; the waiting mutation itself is saved on the record)
local offerIds: { [Player]: { [string]: string } } = {}
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
local allowChoose = RateLimiter.new(Weapons.REQUEST_COOLDOWN)

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

-- What the weapon in hand's mutation does in a fight (MutationRules.Stats; neutral without one, and for the prologue's
-- lent weapon). BattleService asks at a fight's start and on a switch; never for the arena.
function WeaponService.MutationStats(player: Player): MutationRules.Stats
	local weaponId = WeaponService.GetEquipped(player)
	local record = if weaponId and not lent[player] then WeaponService.GetOwned(player, weaponId) else nil
	return MutationRules.stats(Mutations, if record then record.mutation else nil)
end

-- The character's Sword, SwordGrade, SwordLevel and SwordMutation (its mutation's rarity: the blade's rim) attributes
-- from the weapon in hand
function WeaponService.ApplyAttributes(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local weaponId = WeaponService.GetEquipped(player)
	local record = if weaponId then WeaponService.GetOwned(player, weaponId) else nil
	local mutation = if record and not lent[player] then record.mutation else nil
	character:SetAttribute("Sword", weaponId)
	character:SetAttribute("SwordGrade", if record then record.grade else nil)
	character:SetAttribute("SwordLevel", if record then record.level else nil)
	character:SetAttribute("SwordMutation", if mutation then mutation.rarity else nil)
end

local function copyMutation(mutation: Mutation?): Mutation?
	return if mutation then { id = mutation.id, rarity = mutation.rarity } else nil
end

-- A waiting mutation with its Forge mark (a Forge roll's choice gives no Essence, after a rejoin too)
local function copyPending(pending: Pending?): Pending?
	return if pending then { id = pending.id, rarity = pending.rarity, forge = if pending.forge then true else nil } else nil
end

-- Every owned weapon as plain data (the save and the client)
local function snapshot(player: Player): { [string]: Owned }
	local copy = {}
	for id, record in owned[player] or {} do
		copy[id] = { grade = record.grade, level = record.level, mutation = copyMutation(record.mutation), pending = copyPending(record.pending) }
	end
	return copy
end

local function giveEssence(player: Player, amount: number)
	if amount > 0 then
		ItemService.GiveItem(player, Mutations.ESSENCE_ITEM, amount)
	end
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
	-- offers: each waiting mutation's offer id, so the client can ask the player (WeaponRevealController)
	Remotes.WeaponsChanged:FireClient(player, {
		owned = snapshot(player),
		equipped = equipped[player] or Weapons.STARTER,
		locked = locked[player] or {},
		offers = table.clone(offerIds[player] or {}),
	})
	WeaponService.ApplyAttributes(player)
end

-- What `offer` shows the player (WeaponRevealController.Mutation)
local function offerOf(weaponId: string, record: Owned, id: string, mutation: Mutation, applied: boolean, source: string): Offer
	local none = applied or source == "forge"
	return {
		id = id,
		weaponId = weaponId,
		grade = record.grade,
		level = record.level,
		mutation = { id = mutation.id, rarity = mutation.rarity },
		have = if applied then nil else copyMutation(record.mutation),
		applied = applied,
		essence = {
			take = if none then 0 else MutationRules.essence(Mutations, record.mutation),
			keep = if none then 0 else MutationRules.essence(Mutations, mutation),
		},
		source = source,
	}
end

-- A mutation offered on an owned weapon (a boss's drop of one you have, the Forge's Mutate; not the Steel Sword): on at
-- once when the weapon has none, else it waits (saved, a Forge roll's marked) for ChooseMutation. A choice still
-- waiting on the same weapon is settled as Keep current first (its Essence given, none for a Forge roll's). Nil when
-- the weapon isn't owned.
function WeaponService.Offer(player: Player, weaponId: string, mutation: Mutation, source: "drop" | "forge"): Offer?
	local mine = owned[player]
	local record = if mine then mine[weaponId] else nil
	if not record or weaponId == Weapons.STARTER then
		return nil
	end
	local ids = offerIds[player] or {}
	offerIds[player] = ids
	if record.pending then
		local kept, essence = MutationRules.resolve(Mutations, record.mutation, record.pending, false)
		record.mutation = kept
		record.pending = nil
		ids[weaponId] = nil
		giveEssence(player, essence)
	end
	local id = HttpService:GenerateGUID(false)
	local applied = record.mutation == nil
	local offer = offerOf(weaponId, record, id, mutation, applied, source)
	if applied then
		record.mutation = { id = mutation.id, rarity = mutation.rarity }
	else
		record.pending = { id = mutation.id, rarity = mutation.rarity, forge = if source == "forge" then true else nil }
		ids[weaponId] = id
	end
	WeaponService.Changed(player)
	return offer
end

-- Every choice still waiting, as offers (the client asks them after a join)
function WeaponService.Pending(player: Player): { Offer }
	local list = {}
	for weaponId, id in offerIds[player] or {} do
		local record = WeaponService.GetOwned(player, weaponId)
		if record and record.pending then
			table.insert(list, offerOf(weaponId, record, id, record.pending, false, if record.pending.forge then "forge" else "waiting"))
		end
	end
	return list
end

-- Studio's /mutation: this weapon's mutation set (nil clears it and any choice waiting)
function WeaponService.SetMutation(player: Player, weaponId: string, mutation: Mutation?)
	local record = WeaponService.GetOwned(player, weaponId)
	if not record or lent[player] then
		return
	end
	record.mutation = copyMutation(mutation)
	if not mutation then
		record.pending = nil
		local ids = offerIds[player]
		if ids then
			ids[weaponId] = nil
		end
	end
	WeaponService.Changed(player)
end

-- Take new or Keep current (owner's mockups): only for the offer waiting on that weapon now; the other turns into
-- Essence after a boss's drop (a Forge roll's into nothing: MutationRules.resolve)
local function onChoose(player: Player, weaponId: unknown, offerId: unknown, take: unknown)
	if not allowChoose(player) or typeof(weaponId) ~= "string" or typeof(offerId) ~= "string" or typeof(take) ~= "boolean" then
		return
	end
	local mine = owned[player]
	local record = if mine then mine[weaponId] else nil
	local ids = offerIds[player]
	if not record or not record.pending or not ids or ids[weaponId] ~= offerId then
		return -- answered already or not theirs: nothing changes
	end
	local kept, essence = MutationRules.resolve(Mutations, record.mutation, record.pending, take)
	record.mutation = kept
	record.pending = nil
	ids[weaponId] = nil
	giveEssence(player, essence)
	WeaponService.Changed(player)
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
	local old = mine[weaponId]
	mine[weaponId] = {
		grade = grade,
		level = math.clamp(math.floor(level), 0, Weapons.MAX_LEVEL),
		mutation = if old then old.mutation else nil,
		pending = if old then old.pending else nil,
	}
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

local function readMutation(value: unknown): Mutation?
	return MutationRules.read(Mutations, value)
end

local function load(player: Player, data: PlayerData)
	local mine, equip, dropped = WeaponRules.read(Weapons, data.weapons, data.equippedWeapon, readMutation)
	if #dropped > 0 then
		warn(`[WeaponService] {player.Name}: unknown weapons dropped: {table.concat(dropped, ", ")}`)
	end
	owned[player] = mine
	equipped[player] = equip
	-- a choice left waiting last time (they left before answering) is asked again: a fresh offer id for it
	local ids = {}
	for weaponId, record in mine do
		if record.pending then
			ids[weaponId] = HttpService:GenerateGUID(false)
		end
	end
	offerIds[player] = ids
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
	offerIds[player] = nil
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
	Remotes.ChooseMutation.OnServerEvent:Connect(onChoose)
	Remotes.WeaponsChanged.OnServerEvent:Connect(function(player)
		if allowRequest(player) then
			WeaponService.Changed(player)
		end
	end)
end

return WeaponService
