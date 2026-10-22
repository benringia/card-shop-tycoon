--!strict
-- Card Condenser: the owner combines duplicates of a card into one main copy for +1 star.
-- The client names the main copy (a levelled card's ID, or a plain copy's foil and grade); the server
-- checks the machine, distance and ownership, and CardService.Condense works out and takes the
-- duplicates from current state (Util/CondenseRules), so a forged or stale request changes nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CondenserConfig = require(Config:WaitForChild("Condenser"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local ItemService = require(Services:WaitForChild("ItemService"))

local SHARD_ID = "starShard"
local PlacementService = require(Services:WaitForChild("PlacementService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local CondenserService = {}

local allowAction = RateLimiter.new(CondenserConfig.ACTION_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function describeReason(reason: string?): string
	if reason == "max" then
		return "Already at max stars."
	elseif reason == "working" then
		return "That card is working. Unassign it first."
	elseif reason == "fighting" then
		return "That card is in a fight."
	end
	local have, need = string.match(reason or "", "^short:(%d+):(%d+)$")
	if have and need then
		return `Not enough duplicates: have {have}, need {need}.`
	end
	return "You don't have that card."
end

local function onCondense(player: Player, shelfUid: unknown, cardId: unknown, mainBeastId: unknown, mainFoil: unknown, mainGrade: unknown, useShards: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(shelfUid) ~= "string" or typeof(cardId) ~= "string" then
		return
	end
	local card = Cards.ById[cardId]
	local shelf = PlacementService.GetShelf(player, shelfUid)
	if not card or not shelf or not PlacementService.IsCondenser(shelf) then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (root.Position - shelf.part.Position).Magnitude > CondenserConfig.USE_DISTANCE then
		notify(player, "Get closer to the Condenser.", true)
		return
	end

	local target: CardService.XpTarget
	if typeof(mainBeastId) == "string" then
		target = mainBeastId
	elseif typeof(mainFoil) == "boolean" and BeastRules.isGrade(mainGrade) then
		target = { cardId = cardId, foil = mainFoil, grade = mainGrade :: string }
	else
		return
	end

	-- Recounted here: the client's number is only a preview
	local shards = if useShards == true then ItemService.GetCount(player, SHARD_ID) else 0
	local beast, reason, shardsUsed = CardService.Condense(player, cardId, target, shards)
	if not beast then
		notify(player, describeReason(reason), true)
		return
	end
	-- Same step, no yields: the shards counted above are still there
	if shardsUsed > 0 then
		ItemService.TakeItem(player, SHARD_ID, shardsUsed)
	end
	local shardText = if shardsUsed > 0 then ` (used {shardsUsed} Star Shard{if shardsUsed == 1 then "" else "s"})` else ""
	notify(player, `{card.name} is now {BeastRules.describeGrowth(beast.level, beast.stars)}!{shardText}`, false)
end

function CondenserService.Start()
	Remotes.Condense.OnServerEvent:Connect(onCondense)
end

return CondenserService
