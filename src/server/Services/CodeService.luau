--!strict
-- Codes (owner 2026-11-19: "yes do code box"; Config/Codes, Util/CodeRules): the Store's code box sends what the player
-- typed; this checks it (a real code, not used by them, not ended), pays its small gift and remembers it (saved as
-- data.codes, the codes used). The client only ever learns the answer for the code it sent: codes aren't sent to it.
-- Guessing is slowed by the cooldown; a code is public anyway and works once a player. Nothing is paid unless the
-- whole gift fits (a full Bag keeps the code unused). Main game only (the Store lives in the town's Phone).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Codes = require(Config:WaitForChild("Codes"))
local Items = require(Config:WaitForChild("Items"))
local Luck = require(Config:WaitForChild("Luck"))
local CodeRules = require(Shared:WaitForChild("Util"):WaitForChild("CodeRules"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local BattleService = require(Services:WaitForChild("BattleService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local LuckService = require(Services:WaitForChild("LuckService"))
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))

type PlayerData = DataService.PlayerData

local CodeService = {}

local MAX_TYPED = Codes.MAX_LENGTH * 2 -- what's typed may hold spaces and dashes before it's cleaned

local redeemed: { [Player]: { string } } = {}
local allowTry = RateLimiter.new(Codes.COOLDOWN)

-- `reward`: a redeemed code's gift (its cash, items and luck: plain data), for its win moment (client Util/CodeBox)
local function answer(player: Player, ok: boolean, message: string, reward: any?)
	Remotes.CodeResult:FireClient(player, ok, message, reward)
end

-- Whether every item of a gift fits in this player's Bag (a stack's limit: ItemRules.add)
local function fits(player: Player, items: { { item: string, count: number } }?): boolean
	for _, grant in items or {} do
		local have: ItemRules.Items = { [grant.item] = ItemService.GetCount(player, grant.item) }
		local _, added = ItemRules.add(Items, have, grant.item, grant.count)
		if added < grant.count then
			return false
		end
	end
	return true
end

local function onRedeem(player: Player, typed: unknown)
	local used = redeemed[player]
	if not used or not allowTry(player) then
		return -- their save isn't loaded here, or they're trying too fast (the box waits out the cooldown itself)
	end
	if typeof(typed) ~= "string" or #typed > MAX_TYPED then
		answer(player, false, Codes.TEXT.unknown)
		return
	end
	local code = CodeRules.normalize(typed, Codes.MAX_LENGTH)
	local result, entry = CodeRules.check(Codes, used, code, os.time())
	if result ~= "ok" or not entry or not code then
		local text = (Codes.TEXT :: { [string]: string })[if code == nil and typed ~= "" then "unknown" else result]
		answer(player, false, text or Codes.TEXT.unknown)
		return
	end
	if BattleService.IsFighting(player) then
		answer(player, false, Codes.TEXT.busy)
		return
	end
	local reward = entry.reward
	if not fits(player, reward.items) then
		answer(player, false, "Your Bag is full. Make room, then use the code again.")
		return
	end
	-- remembered first, so nothing below can pay it twice
	table.insert(used, code)
	if reward.cash and reward.cash > 0 then
		EconomyService.AddCash(player, reward.cash)
	end
	for _, grant in reward.items or {} do
		ItemService.GiveItem(player, grant.item, grant.count)
	end
	if reward.luck then
		LuckService.Give(player, reward.luck.strength, reward.luck.seconds)
	end
	answer(player, true, `{Codes.TEXT.ok} {CodeRules.gotLine(reward, Items, Luck)}`, reward)
end

local function load(player: Player, data: PlayerData)
	redeemed[player] = CodeRules.clean(data.codes, Codes.MAX_LENGTH)
end

-- Nothing for a player this service never loaded, so a failed load can't hand their codes back
local function save(player: Player, data: PlayerData)
	local used = redeemed[player]
	if used then
		data.codes = table.clone(used)
	end
end

local function unload(player: Player)
	redeemed[player] = nil
end

-- Studio's /codes reset: every code can be used again by this player
function CodeService.DevReset(player: Player): boolean
	if not redeemed[player] then
		return false
	end
	redeemed[player] = {}
	return true
end

function CodeService.Start()
	DataService.Register({ name = "CodeService", load = load, save = save, unload = unload })
	Remotes.RedeemCode.OnServerEvent:Connect(onRedeem)
end

return CodeService
