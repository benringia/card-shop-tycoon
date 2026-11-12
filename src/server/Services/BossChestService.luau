--!strict
-- The boss chests (spec docs/superpowers/specs/2026-11-11-boss-chests-design.md; Config/BossChests, Util/ChestRules):
-- after a full-loot win of a boss with a weapon, three chests on the player's reveal stage. Everything is decided and
-- given at the win (BossService rolls the weapon as before and calls Prepare): no drop, and this rolls the material and
-- puts it in the Bag; the two other chests' contents are made too (shown, never given). The client only sends the
-- index of the chest it tapped; the answer puts the player's own result there. Not picked in time, the server opens one.
-- A weapon's reveal, light column and announcement (onOpen) come when its chest opens; a player who left first still
-- has it, and the others still hear of an Epic or Legendary.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BossChests = require(Config:WaitForChild("BossChests"))
local Victory = require(Config:WaitForChild("Victory"))
local Weapons = require(Config:WaitForChild("Weapons"))
local ChestRules = require(Shared:WaitForChild("Util"):WaitForChild("ChestRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local ItemService = require(Services:WaitForChild("ItemService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

local BossChestService = {}

local OPEN_COOLDOWN = 0.5

type Entry = { set: ChestRules.Set, payload: any?, onOpen: ((payload: any, here: boolean) -> ())? }

local entries: { [Player]: Entry } = {}
local allowOpen = RateLimiter.new(OPEN_COOLDOWN)
local rng = Random.new()

-- Whether this player has the weapon (before this win's drop, which is given before the chests are made: a drop
-- shows no "?" anyway)
local function owns(player: Player, weaponId: string): boolean
	return WeaponService.GetOwned(player, weaponId) ~= nil
end

local function rolls(): { number }
	return { rng:NextNumber(), rng:NextNumber(), rng:NextNumber() }
end

-- Opens this player's set at `index`: their screen gets the row, and a weapon's reveal and announcement go out (`here`
-- false: they're leaving, so only the announcement)
local function open(player: Player, entry: Entry, index: number, here: boolean)
	if entry.set.opened then
		return
	end
	entry.set.opened = true
	if entries[player] == entry then
		entries[player] = nil
	end
	if here and player.Parent then
		local contents = ChestRules.layout(index, entry.set.mine, entry.set.others)
		Remotes.BossChestOpened:FireClient(player, { id = entry.set.id, index = index, contents = contents })
	end
	local onOpen = entry.onOpen
	if entry.set.mine.kind == "weapon" and entry.payload and onOpen then
		-- On screen, the chest opens first and then the cinematic takes the stage
		if here then
			task.delay(BossChests.REVEAL_AFTER, onOpen, entry.payload, true)
		else
			onOpen(entry.payload, false)
		end
	end
end

-- Keeps a new set, offers it after the victory screen and opens one itself if nobody picks in time; a set still waiting
-- from an earlier win opens first (nothing is lost)
local function offer(player: Player, entry: Entry)
	local older = entries[player]
	if older then
		open(player, older, ChestRules.autoIndex(rng:NextNumber(), BossChests.COUNT), true)
	end
	entries[player] = entry
	task.delay(Victory.SECONDS, function()
		if entries[player] ~= entry or not player.Parent then
			return
		end
		Remotes.BossChests:FireClient(player, { id = entry.set.id, bossId = entry.set.bossId, seconds = BossChests.PICK_SECONDS })
		task.delay(BossChests.PICK_SECONDS + BossChests.GRACE_SECONDS, function()
			if entries[player] == entry then
				open(player, entry, ChestRules.autoIndex(rng:NextNumber(), BossChests.COUNT), true)
			end
		end)
	end)
end

-- A win's chests (BossService): `payload` is the weapon BossService already gave (nil: no drop, so the material is
-- rolled and given here: always on a full-loot win, at `factor`'s chance on a reduced one, else the chest is empty for
-- `reason`). `onOpen(payload, here)` runs when a weapon's chest opens (its reveal and announcement; `here` false when
-- the player is leaving).
function BossChestService.Prepare(player: Player, bossId: string, weaponId: string, payload: any?, factor: number, reason: string?, onOpen: (payload: any, here: boolean) -> ())
	local material = Weapons.MATERIALS[bossId]
	if not material then
		-- No material to show (a config gap): the weapon's moment as before, no chests
		if payload then
			task.delay(Victory.SECONDS, onOpen, payload, true)
		end
		return
	end
	local mine = ChestRules.mine(weaponId, payload ~= nil, material, factor, rng:NextNumber(), rng:NextNumber(), BossChests.MATERIAL, reason)
	if mine.kind == "material" and mine.count then
		ItemService.GiveItem(player, material, mine.count)
	end
	local set: ChestRules.Set = {
		id = HttpService:GenerateGUID(false),
		bossId = bossId,
		weaponId = weaponId,
		mine = mine,
		others = ChestRules.others(ChestRules.showsMystery(payload ~= nil, owns(player, weaponId)), weaponId, material, rolls(), BossChests.MATERIAL),
		opened = false,
	}
	offer(player, { set = set, payload = payload, onOpen = onOpen })
end

-- Studio's /chests: a set that gives nothing (kind "drop": the reveal of a new Grade A copy, on this screen only;
-- "miss": material; "strong" / "tired": a reduced win's empty chest)
function BossChestService.Preview(player: Player, bossId: string, weaponId: string, kind: string)
	local material = Weapons.MATERIALS[bossId]
	if not material then
		return
	end
	local dropped = kind == "drop"
	local reduced = kind == "strong" or kind == "tired"
	local mine = ChestRules.mine(weaponId, dropped, material, if reduced then 0 else 1, 1, rng:NextNumber(), BossChests.MATERIAL, if reduced then kind else nil)
	local set: ChestRules.Set = {
		id = HttpService:GenerateGUID(false),
		bossId = bossId,
		weaponId = weaponId,
		mine = mine,
		others = ChestRules.others(ChestRules.showsMystery(dropped, owns(player, weaponId)), weaponId, material, rolls(), BossChests.MATERIAL),
		opened = false,
	}
	local payload = if dropped then { weaponId = weaponId, grade = "A", refund = 0, material = material } else nil
	offer(player, {
		set = set,
		payload = payload,
		onOpen = function(shown, here)
			if here and player.Parent then
				Remotes.WeaponDropped:FireClient(player, shown)
			end
		end,
	})
end

local function onOpenChest(player: Player, id: unknown, index: unknown)
	if not allowOpen(player) then
		return
	end
	local entry = entries[player]
	local picked = ChestRules.validIndex(index, BossChests.COUNT)
	if not entry or not picked or not ChestRules.canOpen(entry.set, id) then
		return
	end
	open(player, entry, picked, true)
end

function BossChestService.Start()
	Remotes.OpenBossChest.OnServerEvent:Connect(onOpenChest)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry then
			-- They keep what they won; a weapon still gets its announcement
			open(player, entry, 1, false)
			entries[player] = nil
		end
	end)
end

return BossChestService
