--!strict
-- Grading Station: the owner raises one copy's grade a step for plain duplicates of the same card plus cash.
-- The client names the main copy (a levelled card's ID, or a plain copy's foil and grade); the server checks the
-- machine, distance and ownership, and CardService.GradeUp works out the duplicates and cash from current state
-- (Util/CondenseRules.gradePlan) and takes the cash through EconomyService, so a forged or stale request changes
-- nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local GradingConfig = require(Config:WaitForChild("Grading"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

local GradingService = {}

local allowAction = RateLimiter.new(GradingConfig.ACTION_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function describeReason(reason: string?): string
	if reason == "max" then
		return "Already Grade S."
	elseif reason == "working" then
		return "That card is working. Unassign it first."
	elseif reason == "fighting" then
		return "That card is in a fight."
	end
	local have, need = string.match(reason or "", "^short:(%d+):(%d+)$")
	if have and need then
		return `Not enough duplicates: have {have}, need {need}.`
	end
	local cash = string.match(reason or "", "^cash:(%d+)$")
	if cash then
		local withCommas = string.gsub(string.reverse(cash), "(%d%d%d)", "%1,")
		return `Not enough cash: grading costs ${(string.gsub(string.reverse(withCommas), "^,", ""))}.`
	end
	return "You don't have that card."
end

local function onGradeUp(player: Player, shelfUid: unknown, cardId: unknown, mainBeastId: unknown, mainFoil: unknown, mainGrade: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(shelfUid) ~= "string" or typeof(cardId) ~= "string" then
		return
	end
	local card = Cards.ById[cardId]
	local shelf = PlacementService.GetShelf(player, shelfUid)
	if not card or not shelf or not PlacementService.IsGradingStation(shelf) then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root or (root.Position - shelf.part.Position).Magnitude > GradingConfig.USE_DISTANCE then
		notify(player, "Get closer to the Grading Station.", true)
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

	-- The cash is recomputed and taken inside the same step as the cards: the client's preview is never trusted
	local grade, reason = CardService.GradeUp(player, cardId, target, function(cash)
		return EconomyService.TrySpend(player, cash)
	end)
	if not grade then
		notify(player, describeReason(reason), true)
		return
	end
	notify(player, `{card.name} is now {BeastRules.describeGrade(grade)}!`, false)
end

function GradingService.Start()
	Remotes.GradeUp.OnServerEvent:Connect(onGradeUp)
end

return GradingService
