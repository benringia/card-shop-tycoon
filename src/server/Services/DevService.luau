--!strict
-- Studio-only chat commands for testing: /cash <amount>, /xp <amount>, /level <level>, /testpack,
-- /beastxp <amount> (XP for your best levelled card, or your rarest plain card),
-- /givecard <number> <amount> (plain copies of card #number, each with a rolled grade, for the Condenser),
-- /jobslot (toggle owning the Extra Job Slot pass), /wild (travel to the wild map), /rest (wake resting cards),
-- /elite (an elite monster next to you, at your summoned card's level), /arena (go to the arena stands),
-- /frontierdrop (a Star Shard and a random Frontier card), /raritypack [foil] (one card of each rarity, to
-- see every pack reveal), /legendarys [foil] (a Grade S copy of every Legendary).
-- Does nothing outside Studio, so live players never get these commands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Wild = require(Shared:WaitForChild("Util"):WaitForChild("Place")).getWorld() -- the Frontier's zones there
local Levels = require(Config:WaitForChild("Levels"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local ArenaService = require(Services:WaitForChild("ArenaService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local CardService = require(Services:WaitForChild("CardService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local PackService = require(Services:WaitForChild("PackService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WildService = require(Services:WaitForChild("WildService"))

type CommandHandler = (player: Player, text: string) -> ()

local DevService = {}

local function parseAmount(text: string): number?
	local amount = tonumber(string.match(text, "%s+(%S+)") or "")
	if amount == nil or amount ~= amount or amount <= 0 or amount == math.huge then
		return nil
	end
	return amount
end

local function addCommand(folder: Instance, alias: string, handler: CommandHandler)
	local command = Instance.new("TextChatCommand")
	command.Name = "Dev" .. alias
	command.PrimaryAlias = "/" .. alias
	command.Parent = folder

	command.Triggered:Connect(function(textSource: TextSource, text: string)
		local player = Players:GetPlayerByUserId(textSource.UserId)
		if player then
			handler(player, text)
		end
	end)
end

-- Wraps an economy function so the command reads its amount from the chat text
local function withAmount(apply: (player: Player, amount: number) -> ...any): CommandHandler
	return function(player: Player, text: string)
		local amount = parseAmount(text)
		if amount then
			apply(player, amount)
		end
	end
end

local function jumpToLevel(player: Player, level: number)
	if level < 1 or level > Levels.LEVEL_LIMIT then
		return
	end
	local required = LevelRules.getRequiredXp(level)
	local current = player:GetAttribute("XP")
	local missing = required - (if typeof(current) == "number" then current else 0)
	if missing > 0 then
		EconomyService.AddXP(player, missing)
	end
end

-- Highest-rarity levelled card (then highest level); otherwise the rarest plain copy, best grade and foil first
local function pickXpTarget(player: Player): CardService.XpTarget?
	local best: CardService.Beast? = nil
	local bestScore = -1
	for _, beast in CardService.GetBeasts(player) do
		local tier = Rarities.Tiers[Cards.ById[beast.cardId].rarity]
		local score = (if tier then tier.order else 0) * 100 + beast.level
		if score > bestScore then
			best, bestScore = beast, score
		end
	end
	if best then
		return best.id
	end
	local stacks = CardService.GetStacks(player)
	for _, card in Cards.RarestFirst do
		local byGrade = stacks[card.id] or {}
		for index = #BeastRules.GRADES, 1, -1 do
			local grade = BeastRules.GRADES[index]
			local owned = byGrade[grade]
			if owned and owned.foil > 0 then
				return { cardId = card.id, foil = true, grade = grade }
			elseif owned and owned.normal > 0 then
				return { cardId = card.id, foil = false, grade = grade }
			end
		end
	end
	return nil
end

-- Studio stand-in for buying or refunding the Extra Job Slot pass
local function toggleJobSlot(player: Player)
	local owns = MonetizationService.HasPass(player, "ExtraJobSlot")
	MonetizationService.SetDevPass(player, "ExtraJobSlot", not owns)
	Remotes.Notify:FireClient(player, if owns then "Extra Job Slot pass removed (Studio)" else "Extra Job Slot pass added (Studio)", false)
end

-- An elite at your summoned card's level, a few studs in front of you, from the zone that fits that level
local function spawnElite(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not root then
		return
	end
	local party = PartyService.GetParty(player)
	local leaderId = if party and party.summoned then party.slots[party.summoned] else nil
	local leader = if leaderId then CardService.GetBeast(player, leaderId) else nil
	local level = if leader then leader.level else 1
	local zone = Wild.ZONES[1]
	for _, candidate in Wild.ZONES do
		if level >= candidate.minLevel then
			zone = candidate
		end
	end
	local species = zone.species[math.random(1, #zone.species)]
	WildService.SpawnAt(root.Position + root.CFrame.LookVector * 10, species, math.clamp(level, zone.minLevel, zone.maxLevel), true)
end

local MAX_GIVE_CARDS = 500 -- per /givecard, so a typo can't flood the save

-- "/givecard 30 70": 70 plain copies of card #30, each rolling its grade like a pack pull
local function giveCards(player: Player, text: string)
	local numberText, amountText = string.match(text, "%s+(%d+)%s+(%d+)")
	local card = if numberText then Cards.List[tonumber(numberText) :: number] else nil
	local amount = math.clamp(tonumber(amountText or "") or 0, 0, MAX_GIVE_CARDS)
	if not card or amount <= 0 then
		Remotes.Notify:FireClient(player, "Usage: /givecard <card number> <amount>", true)
		return
	end
	local results = {}
	local rng = Random.new()
	for _ = 1, amount do
		table.insert(results, { cardId = card.id, foil = false, grade = BeastRules.rollGrade(rng:NextNumber()) })
	end
	CardService.AddFresh(player, results)
	Remotes.Notify:FireClient(player, `Gave {amount} {card.name}`, false)
end

-- A Grade S copy of every Legendary (foil with "foil" in the text), to see their display effects
local function giveSupremeLegendaries(player: Player, text: string)
	local foil = string.find(string.lower(text), "foil") ~= nil
	local results = {}
	for _, card in Cards.List do
		if card.rarity == "Legendary" then -- packs and Frontier
			table.insert(results, { cardId = card.id, foil = foil, grade = "S" })
		end
	end
	CardService.AddFresh(player, results)
	Remotes.Notify:FireClient(player, `Gave {#results} Grade S Legendaries`, false)
end

local function grantBeastXp(player: Player, amount: number)
	local target = pickXpTarget(player)
	local beast = if target then CardService.AddXP(player, target, amount) else nil
	if not beast then
		Remotes.Notify:FireClient(player, "No card in your binder to give XP to.", true)
		return
	end
	local card = Cards.ById[beast.cardId]
	Remotes.Notify:FireClient(player, `{card.name} is now {BeastRules.describeGrowth(beast.level, beast.stars)}`, false)
end

function DevService.Start()
	if not RunService:IsStudio() then
		return
	end

	local folder = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	addCommand(folder, "cash", withAmount(EconomyService.AddCash))
	addCommand(folder, "xp", withAmount(EconomyService.AddXP))
	addCommand(folder, "level", withAmount(jumpToLevel))
	addCommand(folder, "beastxp", withAmount(grantBeastXp))
	addCommand(folder, "givecard", giveCards)
	addCommand(folder, "jobslot", toggleJobSlot)
	addCommand(folder, "wild", function(player)
		WildService.TravelToWild(player)
	end)
	addCommand(folder, "rest", function(player)
		BattleService.ClearResting(player)
	end)
	addCommand(folder, "elite", spawnElite)
	addCommand(folder, "frontierdrop", function(player)
		ItemService.GiveItem(player, "starShard", 1)
		local pool = Cards.BySet.Frontier
		local card = pool[math.random(1, #pool)]
		CardService.AddFresh(player, { { cardId = card.id, foil = false, grade = BeastRules.rollGrade(math.random()) } })
		Remotes.Notify:FireClient(player, `+1 Star Shard and a {card.name} (Studio)`, false)
		if card.rarity == "Epic" or card.rarity == "Legendary" then
			Remotes.PullAnnouncement:FireAllClients(player.DisplayName, card.id, false, "frontier", player.UserId) -- the reveal
		end
	end)
	addCommand(folder, "arena", function(player)
		ArenaService.TravelToStands(player)
	end)
	addCommand(folder, "testpack", function(player)
		PackService.OpenTestPack(player)
	end)
	addCommand(folder, "legendarys", giveSupremeLegendaries)
	addCommand(folder, "raritypack", function(player, text)
		PackService.OpenRarityPack(player, string.find(string.lower(text), "foil") ~= nil)
	end)
	print("[DevService] Studio commands enabled: /cash <amount>, /xp <amount>, /level <level>, /beastxp <amount>, /givecard <number> <amount>, /jobslot, /wild, /rest, /elite, /arena, /frontierdrop, /testpack, /raritypack [foil], /legendarys [foil]")
end

return DevService
