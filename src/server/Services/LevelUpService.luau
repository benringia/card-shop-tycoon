--!strict
-- Level-ups beyond the cash (spec 2026-11-04-round4-design sections 8-9): the pack every PACK_EVERY levels
-- (Config/Levels PACK_ITEM, a Bag item), opening those packs from the Bag (remote OpenBagPack), and telling every client
-- about a level-up so the light pillar plays (remote LevelUpFx): a shop's waits while its player fights (several merge
-- into one), a creature's goes out at once. EconomyService pays the cash and calls OnLevelUp; CardService.AddXP calls
-- OnBeastLevelUp; this service never changes cash or XP.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Util = Shared:WaitForChild("Util")
local Levels = require(Config:WaitForChild("Levels"))
local LevelUpFx = require(Config:WaitForChild("LevelUpFx"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local ItemRules = require(Util:WaitForChild("ItemRules"))
local LevelUpRules = require(Util:WaitForChild("LevelUpRules"))
local Place = require(Util:WaitForChild("Place"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

local LevelUpService = {}

local allowOpen = RateLimiter.new(Levels.PACK_OPEN_COOLDOWN)
local held: { [Player]: LevelUpRules.Pending } = {} -- shop level-ups waiting for their player's fight to end
local freeAt: { [Player]: number } = {} -- os.clock a boss fight's end screen is over (LevelUpRules.freeAt)
local seenFighting: { [Player]: number } = {} -- os.clock the release loop last saw them in a fight
-- PackService runs only in the main game; required there in Start
local PackService: { OpenItemPack: (player: Player, productId: string) -> boolean }? = nil
-- PvP fights run in ArenaService (main game only), outside BattleService's fights
local ArenaService: { IsBusy: (player: Player) -> boolean }? = nil

local function sendShop(player: Player, levels: LevelUpRules.Pending)
	Remotes.LevelUpFx:FireAllClients({ kind = "shop", userId = player.UserId, from = levels.from, to = levels.to })
end

local function onLevelUp(player: Player, from: number, to: number)
	local packs = LevelUpRules.rewards(Levels, from, to).packs
	if packs > 0 then
		ItemService.GiveItem(player, Levels.PACK_ITEM, packs)
	end
	-- The pillar never plays mid-fight (a glowing circle underfoot reads as "dodge"): it waits for the fight to end
	held[player] = LevelUpRules.merge(held[player], from, to)
end

local function inAnyFight(player: Player): boolean
	return BattleService.IsFighting(player) or (ArenaService ~= nil and ArenaService.IsBusy(player))
end

-- Sends the held shop level-ups of everyone back in the world: out of the fight for a whole check (the fight-ended
-- handlers run deferred, after the fight is cleared) and past a boss fight's end screen
local function releaseHeld()
	while true do
		task.wait(LevelUpFx.HOLD_CHECK_SECONDS)
		local now = os.clock()
		for player, levels in held do
			if not player.Parent then
				held[player] = nil
			elseif inAnyFight(player) then
				seenFighting[player] = now
			elseif now - (seenFighting[player] or 0) >= LevelUpFx.HOLD_CHECK_SECONDS and now >= (freeAt[player] or 0) then
				held[player] = nil
				sendShop(player, levels)
			end
		end
	end
end

-- A boss fight's members get its end screen (the victory screen, or the defeat countdown) before a held level-up plays
local function onFightEnded(monster: any, result: string, hpLeft: { [Player]: any }, stillIn: { Player })
	local boss = monster.boss ~= nil
	local at = LevelUpRules.freeAt(LevelUpFx, os.clock(), boss, result)
	for player in hpLeft do
		freeAt[player] = at
	end
	for _, player in stillIn do
		freeAt[player] = at
	end
end

local function onBeastLevelUp(player: Player, beast: CardService.Beast, from: number, to: number, source: string?)
	local card = Cards.ById[beast.cardId]
	Remotes.LevelUpFx:FireAllClients({
		kind = "creature",
		userId = player.UserId,
		beastId = beast.id,
		element = if card then card.element else nil,
		from = from,
		to = to,
		fromFight = source == "fight",
	})
end

-- Studio testing (DevService /levelfx and /beastlevelfx): the effect alone, no XP or rewards
function LevelUpService.PreviewShop(player: Player, level: number)
	sendShop(player, { from = math.max(1, level - 1), to = level })
end

function LevelUpService.PreviewCreature(player: Player, beastId: string, level: number, element: string?)
	Remotes.LevelUpFx:FireAllClients({ kind = "creature", userId = player.UserId, beastId = beastId, element = element, from = level, to = level + 1, fromFight = false })
end

-- A Bag pack: only in the main game (PackService and the opening stage live there), never mid-fight
local function onOpenBagPack(player: Player, itemId: unknown)
	if not allowOpen(player) then
		return
	end
	local productId, floor, stingy = ItemRules.openablePack(Items, itemId)
	if not productId then
		return
	end
	local blocked = LevelUpRules.openBlocked(BattleService.IsFighting(player), ArenaService ~= nil and ArenaService.IsBusy(player))
	if blocked then
		Remotes.Notify:FireClient(player, blocked, true)
		return
	end
	if not ItemService.TakeItem(player, itemId :: string, 1) then
		return
	end
	if not PackService or not PackService.OpenItemPack(player, productId, floor, itemId :: string, stingy) then
		ItemService.GiveItem(player, itemId :: string, 1) -- not a pack after all: give it back
	end
end

function LevelUpService.Start()
	EconomyService.OnLevelUp(onLevelUp)
	CardService.OnBeastLevelUp(onBeastLevelUp)
	BattleService.OnFightEnded(onFightEnded)
	Players.PlayerRemoving:Connect(function(player)
		held[player] = nil
		freeAt[player] = nil
		seenFighting[player] = nil
	end)
	task.spawn(releaseHeld)
	if not Place.isFrontier() and not Place.isDungeon() then
		PackService = require(Services:WaitForChild("PackService")) :: any
		ArenaService = require(Services:WaitForChild("ArenaService")) :: any
		Remotes.OpenBagPack.OnServerEvent:Connect(onOpenBagPack)
	end
end

return LevelUpService
