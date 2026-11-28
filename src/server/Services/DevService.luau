--!strict
-- Studio-only chat commands for testing: /cash <amount>, /xp <amount>, /level <level>, /setxp <xp>, /testpack,
-- /beastxp <amount> (XP for your best levelled card, or your rarest plain card),
-- /givecard <number> <amount> (plain copies of card #number, each with a rolled grade, for the Condenser),
-- /jobslot (toggle owning the Extra Job Slot pass), /wild (travel to the wild map), /rest (wake resting cards),
-- /elite (an elite monster next to you, at your summoned card's level), /arena (go to the arena stands),
-- /frontierdrop (a Star Shard and a random Frontier card), /raritypack [foil] (one card of each rarity, to
-- see every pack reveal), /legendarys [foil] (a Grade S copy of every Legendary), /item <id> <amount> (any item),
-- /boss <n> [fight|group] (to boss n's arena gate; with fight or group, use that gate prompt there),
-- /maxcard <name or number> [foil] (one copy at max level, max stars and Grade S), /crowd <0-60> (players counted in
-- every Wild valley biome on top of the real ones, to see its monsters grow), /customer <type> [card id or number] (a
-- customer of that type now: plain, kid, collector, bargain, bigSpender; a collector wanting that card; a kid whose
-- rip has a card of that rarity (rare, veryrare, epic, legendary) and who offers it if it's Very Rare or better),
-- /serve (scan everything on the counter and press Charge, as the owner behind the register). Add "hand" to /customer
-- and it arrives holding its shopping list (empty shelves; nothing is taken from or put back on them).
-- The chat commands (and ServerStorage.DevCommand) exist only in Studio. The admin panel's buttons work in Studio and,
-- in the published game, for the game's owner on their test save only (owner 2026-11-27, spec
-- 2026-11-27-live-admin-creator-design): every request goes through Util/DevAccess first, so no other player can run
-- one (theirs get no reply), the owner's real save is refused with a locked card, and a command that changes other
-- players' game waits until the owner is alone or in their own private server.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Shelves = require(Config:WaitForChild("Shelves"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local Bulk = require(Config:WaitForChild("Bulk"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))
local DayCycle = require(Shared:WaitForChild("Util"):WaitForChild("DayCycle"))
local Cycle = require(Shared:WaitForChild("Config"):WaitForChild("DayCycle"))
local Wild = Place.getWorld() -- the Frontier's zones there
local Levels = require(Config:WaitForChild("Levels"))
local LevelUpFx = require(Config:WaitForChild("LevelUpFx"))
local PishConfig = require(Config:WaitForChild("Pish"))
local SuperFxConfig = require(Config:WaitForChild("SuperFx"))
local SwordSkillFx = require(Config:WaitForChild("SwordSkillFx"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Weapons = require(Config:WaitForChild("Weapons"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local AdminPanel = require(Config:WaitForChild("AdminPanel"))
local Music = require(Config:WaitForChild("Music"))
local Party = require(Config:WaitForChild("Party"))
local MusicRules = require(Shared:WaitForChild("Util"):WaitForChild("MusicRules"))
local Victory = require(Shared:WaitForChild("Config"):WaitForChild("Victory"))

local Services = script.Parent :: Instance
local ArenaService = require(Services:WaitForChild("ArenaService"))
local WelcomeService = require(Services:WaitForChild("WelcomeService"))
local PishService = require(Services:WaitForChild("PishService"))
local TownChikinService = require(Services:WaitForChild("TownChikinService"))
local TurtsService = require(Services:WaitForChild("TurtsService"))
local GiftService = require(Services:WaitForChild("GiftService"))
local TutorialService = require(Services:WaitForChild("TutorialService"))
local CombatTutorialService = require(Services:WaitForChild("CombatTutorialService"))
local SwordService = require(Services:WaitForChild("SwordService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local KnockoutService = require(Services:WaitForChild("KnockoutService"))
local SupportService = require(Services:WaitForChild("SupportService"))
local LuckService = require(Services:WaitForChild("LuckService"))
local TitleService = require(Services:WaitForChild("TitleService"))
local ReviewService = require(Services:WaitForChild("ReviewService"))
local JobService = require(Services:WaitForChild("JobService"))
local BossChestService = require(Services:WaitForChild("BossChestService"))
local BossService = require(Services:WaitForChild("BossService"))
local CardService = require(Services:WaitForChild("CardService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local OfferService = require(Services:WaitForChild("OfferService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local LevelUpService = require(Services:WaitForChild("LevelUpService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local WeaponService = require(Services:WaitForChild("WeaponService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local PackService = require(Services:WaitForChild("PackService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WildService = require(Services:WaitForChild("WildService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))
local DungeonPuzzleService = require(Services:WaitForChild("DungeonPuzzleService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local DecorService = require(Services:WaitForChild("DecorService"))
local WindowService = require(Services:WaitForChild("WindowService"))
local RoomService = require(Services:WaitForChild("RoomService"))
local DataService = require(Services:WaitForChild("DataService"))
local ServerUtil = (Services.Parent :: Instance):WaitForChild("Util")
local RateLimiter = require(ServerUtil:WaitForChild("RateLimiter"))
local DevAccess = require(ServerUtil:WaitForChild("DevAccess"))
local SaveSlots = require(ServerUtil:WaitForChild("SaveSlots"))

type CommandHandler = (player: Player, text: string) -> ()

local DevService = {}

local function parseAmount(text: string): number?
	local amount = tonumber(string.match(text, "%s+(%S+)") or "")
	if amount == nil or amount ~= amount or amount <= 0 or amount == math.huge then
		return nil
	end
	return amount
end

local handlersByAlias: { [string]: CommandHandler } = {}

-- A command's handler, and in Studio its chat command (`folder` is nil in the published game: no chat commands there)
local function addCommand(folder: Instance?, alias: string, handler: CommandHandler)
	handlersByAlias[alias] = handler
	if not folder then
		return
	end
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

-- Runs a command's text ("/item gradingSeal 5"); false when there's no such command
local function run(player: Player, text: string): boolean
	local alias = string.match(text, "^/(%w+)")
	local handler = if alias then handlersByAlias[alias] else nil
	if not handler or typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	handler(player, text)
	return true
end

-- The same commands for Studio's scripting tools, which can't type in chat:
-- ServerStorage.DevCommand:Invoke(player, "/item gradingSeal 5"). Studio only, like the chat commands.
local function makeStudioRunner()
	if not RunService:IsStudio() then
		return
	end
	local runner = Instance.new("BindableFunction")
	runner.Name = "DevCommand"
	runner.OnInvoke = run
	runner.Parent = game:GetService("ServerStorage")
end

local allowPanel = RateLimiter.new(AdminPanel.COMMAND_COOLDOWN)

-- An admin panel button (AdminPanelController): DevAccess decides before anything runs. In the published game each
-- command the owner runs is written to the server log (the Developer Console shows it)
local function onPanel(player: Player, text: unknown)
	if typeof(text) ~= "string" or #text > AdminPanel.COMMAND_MAX_LENGTH or not allowPanel(player) then
		return
	end
	local alias = string.match(text, "^/(%w+)") or ""
	local ok, reason = DevAccess.check(player, alias)
	if not ok then
		DevAccess.refuse(player, reason)
		return
	end
	if not RunService:IsStudio() then
		print(`[Admin] {player.Name}: {text}`)
	end
	run(player, text)
end

-- The published game's Admin mark (AdminPanelController builds the tile from it): only the game's owner gets it,
-- "open" on their test save, "mainSave" on the real one (its tile shows how to get to the test save)
local function markAdmin(player: Player)
	if RunService:IsStudio() or not SaveSlots.isOwner(player.UserId, game.CreatorId, game.CreatorType.Name) then
		return
	end
	player:SetAttribute("AdminAccess", if DataService.IsTestSlot(player) then "open" else "mainSave")
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
	if level < 1 or level > Levels.MAX_LEVEL then
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

-- Luck as if bought from the Store (Config/Luck): /luck <x2|x3> [minutes], /luck clear
local function giveLuck(player: Player, text: string)
	local strength, minutes = string.match(text, "^%S+%s+(%S+)%s*(%S*)")
	if strength == "clear" then
		LuckService.DevGive(player, "x2", 0)
		Remotes.Notify:FireClient(player, "Bought luck cleared (Studio)", false)
		return
	end
	local count = tonumber(minutes) or 30
	if not strength or not LuckService.DevGive(player, strength, count * 60) then
		Remotes.Notify:FireClient(player, "Usage: /luck <x2|x3> [minutes] or /luck clear", true)
		return
	end
	Remotes.Notify:FireClient(player, `{strength} luck: {count} more minutes (Studio)`, false)
end

-- Studio stand-in for buying (its grant and win card) or taking away a Robux round pass or the Starter Pack (spec
-- 2026-11-28-robux-round-design): /pass <VIP|QuickOpen|NightShift|StarterPack> [on|off] (no on/off: toggle)
local PASS_KEYS = { "VIP", "QuickOpen", "NightShift", "StarterPack" }
local function devPass(player: Player, text: string)
	local key, state = string.match(text, "^%S+%s+(%S+)%s*(%S*)")
	if not key or not table.find(PASS_KEYS, key) or (state ~= "" and state ~= "on" and state ~= "off") then
		Remotes.Notify:FireClient(player, "Usage: /pass <VIP|QuickOpen|NightShift|StarterPack> [on|off]", true)
		return
	end
	local on = if state == "" then not MonetizationService.HasPass(player, key) else state == "on"
	MonetizationService.DevGrant(player, key, on)
	Remotes.Notify:FireClient(player, `{key} {if on then "on" else "off"} (Studio)`, false)
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
local KO_RANGE = 80 -- studs: /ko's reach

-- "/givecard 30 70": 70 plain copies of card #30, each rolling its grade like a pack pull
local MAX_GIVE_ITEMS = 999 -- per /item
local MAX_CROWD = 60 -- /crowd: a full server

-- "/item gradingSeal 5": items for testing (any Config/Items id)
local function giveItems(player: Player, text: string)
	local id, amountText = string.match(text, "%s+([%w_]+)%s+(%d+)")
	local amount = math.clamp(tonumber(amountText or "") or 0, 0, MAX_GIVE_ITEMS)
	if not id or amount <= 0 then
		Remotes.Notify:FireClient(player, "Usage: /item <item id> <amount>", true)
		return
	end
	local given = ItemService.GiveItem(player, id, amount)
	Remotes.Notify:FireClient(player, if given > 0 then `Gave {given} {id}` else `Unknown item {id}`, given <= 0)
end

-- "/weapon verdantBlade S 4": that weapon at that grade (C by default) and level (0), set exactly (owned or not)
local function giveWeapon(player: Player, text: string)
	local id, gradeText, levelText = string.match(text, "^/%w+%s+([%w_]+)%s*(%a?)%s*(%d*)")
	local weapon = if id then Weapons.ById[id] else nil
	if not weapon or not weapon.ready or weapon.id == Weapons.STARTER then
		Remotes.Notify:FireClient(player, "Usage: /weapon <weapon id> [C|B|A|S] [0-10]", true)
		return
	end
	local grade = string.upper(gradeText or "")
	grade = if BeastRules.isGrade(grade) then grade else "C"
	local level = math.clamp(tonumber(levelText) or 0, 0, Weapons.MAX_LEVEL)
	WeaponService.SetForTesting(player, weapon.id, grade, level)
	Remotes.Notify:FireClient(player, `Gave the {weapon.name}, Grade {grade} +{level}`, false)
end

-- Weapons round 4 part 2: "/mutation offer [rarity] [id]": a mutation offered on the weapon in hand now, its reveal
-- and choice (a rarity word: common, rare, veryrare, epic, legendary; a Config/Mutations id; else rolled); "/mutation
-- set [rarity] [id]": put on it at once; "/mutation clear": taken off with any choice waiting. Mutation Essence:
-- "/item mutationEssence <n>"
local function devMutation(player: Player, text: string)
	local Mutations = require(Config:WaitForChild("Mutations")) :: any
	local MutationRules = require(Shared:WaitForChild("Util"):WaitForChild("MutationRules")) :: any
	local rarities = { common = "Common", rare = "Rare", veryrare = "Very Rare", epic = "Epic", legendary = "Legendary" }
	local words = string.split(string.lower(text), " ")
	local action = words[2]
	local weaponId = WeaponService.GetEquipped(player)
	if not weaponId or weaponId == Weapons.STARTER or not WeaponService.GetAll(player)[weaponId] then
		Remotes.Notify:FireClient(player, "Hold a weapon you own (not the Steel Sword) first.", true)
		return
	end
	if action == "clear" then
		WeaponService.SetMutation(player, weaponId, nil)
		Remotes.Notify:FireClient(player, "Mutation taken off", false)
		return
	end
	local rarity, id = nil, nil
	for index = 3, #words do
		local word = words[index]
		if rarities[word] then
			rarity = rarities[word]
		end
		for _, entry in Mutations.LIST do
			if string.lower(entry.id) == word then
				id = entry.id
			end
		end
	end
	local rng = Random.new()
	local rolled = MutationRules.roll(Mutations, rng:NextNumber(), rng:NextNumber())
	local mutation = { id = id or rolled.id, rarity = rarity or rolled.rarity }
	if action == "set" then
		WeaponService.SetMutation(player, weaponId, mutation)
		Remotes.Notify:FireClient(player, `Mutation: {MutationRules.words(Mutations, mutation).short}`, false)
	elseif action == "offer" then
		local offer = WeaponService.Offer(player, weaponId, mutation, "drop")
		if offer then
			Remotes.MutationOffered:FireClient(player, offer)
		end
	else
		Remotes.Notify:FireClient(player, "Usage: /mutation <offer|set|clear> [common|rare|veryrare|epic|legendary] [mutation id]", true)
	end
end

-- "/weapondrop meadowWarden": that boss's weapon drops for you now, through the real drop (the cinematic, a refund
-- when you have it). "/weapondrop meadowWarden preview [grade]": only the cinematic of a new drop (its card turning
-- over), nothing given, to see it when you already own the weapon. "/weapondrop meadowWarden beacon": the light
-- column others nearby see of a new drop, in front of you
local function forceWeaponDrop(player: Player, text: string)
	local bossId, preview, grade = string.match(text, "%s+([%w_]+)%s*(%a*)%s*(%a?)")
	local weaponId = if bossId then BossService.WeaponOf(bossId) else nil
	if not weaponId then
		Remotes.Notify:FireClient(player, "Usage: /weapondrop <boss id with a built weapon> [preview [C|B|A|S]] (meadowWarden, prismHydra)", true)
		return
	end
	if preview == "preview" then
		local shown = if BeastRules.isGrade(string.upper(grade)) then string.upper(grade) else "A"
		Remotes.WeaponDropped:FireClient(player, { weaponId = weaponId, grade = shown, refund = 0, material = Weapons.MATERIALS[bossId] })
		return
	elseif preview == "beacon" then
		-- What others nearby see of a new drop: its light column 12 studs in front of you (as if someone else won it)
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			Remotes.WeaponBeacon:FireClient(player, 0, weaponId, root.Position + root.CFrame.LookVector * 12)
		end
		return
	end
	BossService.DropWeapon(player, weaponId)
end

-- "/chests meadowWarden [drop|miss]": that boss's three chests on your screen now, nothing given (a drop shows a new
-- Grade A copy's reveal); miss when left out (spec 2026-11-11-boss-chests-design)
local function previewChests(player: Player, text: string)
	local bossId, kind = string.match(text, "%s+([%w_]+)%s*(%a*)")
	local weaponId = if bossId then BossService.WeaponOf(bossId) else nil
	local kinds = { drop = true, miss = true }
	if not bossId or not weaponId or (kind ~= "" and not kinds[kind]) then
		Remotes.Notify:FireClient(player, "Usage: /chests <boss id with a built weapon> [drop|miss] (meadowWarden, prismHydra)", true)
		return
	end
	BossChestService.Preview(player, bossId, weaponId, if kind == "" then "miss" else kind)
end

-- "/material meadowWarden 20": a boss's weapon material (Config/Weapons MATERIALS)
local function giveMaterial(player: Player, text: string)
	local bossId, amountText = string.match(text, "%s+([%w_]+)%s+(%d+)")
	local material = if bossId then Weapons.MATERIALS[bossId] else nil
	local amount = math.clamp(tonumber(amountText or "") or 0, 0, MAX_GIVE_ITEMS)
	if not material or amount <= 0 then
		Remotes.Notify:FireClient(player, "Usage: /material <boss id> <amount>", true)
		return
	end
	local given = ItemService.GiveItem(player, material, amount)
	Remotes.Notify:FireClient(player, `Gave {given} {material}`, given <= 0)
end

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
		table.insert(results, { cardId = card.id, foil = false, grade = BeastRules.rollGrade(rng:NextNumber(), card.rarity) })
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

-- /maxcard <name or number> [foil]: one copy at the top of everything (max level, max stars, best grade)
-- A maxed copy of `card` in the binder (max level, max stars, the best grade); its id
local function addMaxed(player: Player, card: any, foil: boolean): string
	local beast = CardService.AddBeast(player, {
		id = HttpService:GenerateGUID(false),
		cardId = card.id,
		foil = foil,
		level = Beasts.MAX_LEVEL,
		xp = 0,
		stars = Beasts.MAX_STARS,
		grade = Beasts.GRADES[#Beasts.GRADES],
	})
	return beast.id
end

local function giveMaxCard(player: Player, text: string)
	local query = string.lower(string.gsub(string.gsub(text, "^%s*/?%a+%s*", ""), "%s+foil%s*$", ""))
	local foil = string.find(string.lower(text), "%sfoil%s*$") ~= nil
	local number = tonumber(query)
	local found = nil
	for _, card in Cards.List do
		if (number and card.number == number) or string.lower(card.name) == query then
			found = card
		end
	end
	if not found and query ~= "" then
		for _, card in Cards.List do
			if string.find(string.lower(card.name), query, 1, true) then
				found = found or card
			end
		end
	end
	if not found then
		Remotes.Notify:FireClient(player, "Usage: /maxcard <card name or number> [foil]", true)
		return
	end
	addMaxed(player, found, foil)
	Remotes.Notify:FireClient(player, `Gave a maxed {if foil then "foil " else ""}{found.name} (Lv {Beasts.MAX_LEVEL}, {Beasts.MAX_STARS} stars, Grade {Beasts.GRADES[#Beasts.GRADES]})`, false)
end

-- Every weapon (the Steel Sword aside) at `weapon`'s grade and level, each with a mutation of its rarity (the kind
-- rolled): so switching to a creature's element unlocks its ultimate
local function giveFootageWeapons(player: Player, weapon: { grade: string, level: number, mutation: string })
	local Mutations = require(Config:WaitForChild("Mutations")) :: any
	local MutationRules = require(Shared:WaitForChild("Util"):WaitForChild("MutationRules")) :: any
	local rng = Random.new()
	for weaponId in Weapons.ById do
		if weaponId ~= Weapons.STARTER then
			WeaponService.SetForTesting(player, weaponId, weapon.grade, weapon.level)
			local rolled = MutationRules.roll(Mutations, rng:NextNumber(), rng:NextNumber())
			WeaponService.SetMutation(player, weaponId, { id = rolled.id, rarity = weapon.mutation })
		end
	end
end

-- One Footage step, checked like a button press (Golden hour's /time needs the owner alone or in their own private
-- server); false, after the refusal's card, when it can't run
local function footageStep(player: Player, command: string): boolean
	local ok, reason = DevAccess.check(player, string.match(command, "^/(%w+)") or "")
	if not ok then
		DevAccess.refuse(player, reason)
		return false
	end
	run(player, command)
	return true
end

-- "/footage <late|shop|golden>": the admin panel's one-tap setups for recording (Config/AdminPanel FOOTAGE; spec
-- 2026-11-27-live-admin-creator-design)
local function runFootage(player: Player, text: string)
	local which = string.match(text, "^/%w+%s+(%a+)")
	local preset = if which then (AdminPanel.FOOTAGE :: any)[which] else nil
	if not preset then
		Remotes.Notify:FireClient(player, "Usage: /footage <late|shop|golden>", true)
		return
	end
	if which == "late" then
		TutorialService.SkipForTesting(player)
		CombatTutorialService.SkipForTesting(player)
		local steps = { `/level {preset.level}`, `/cash {preset.cash}`, "/legendarys" }
		for index = 1, #Bosses.LADDER do
			table.insert(steps, `/bossbeaten {index} on`)
		end
		for _, command in steps do
			if not footageStep(player, command) then
				return
			end
		end
		local party = {}
		for _, name in preset.party do
			for _, card in Cards.List do
				if card.name == name then
					table.insert(party, addMaxed(player, card, false))
				end
			end
		end
		PartyService.SetSlotsForTesting(player, party)
		giveFootageWeapons(player, preset.weapon)
	else
		for _, command in preset.commands do
			if not footageStep(player, command) then
				return
			end
		end
		if which == "shop" then
			-- every Products shelf full of the first product it takes
			local Products = require(Config:WaitForChild("Products")) :: any
			for _, shelf in PlacementService.GetShelves(player) do
				if shelf.def.kind == "Products" then
					for _, product in Products.List do
						if (PlacementService.AddStock(shelf, product.id, shelf.def.capacity)) > 0 then
							break
						end
					end
				end
			end
		end
	end
	Remotes.Notify:FireClient(player, `Footage: {which} ready.`, false)
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
	-- Chat commands only in Studio; the published game keeps just the handlers, for the owner's panel (onPanel)
	local folder: Instance? = if RunService:IsStudio() then (TextChatService:FindFirstChild("TextChatCommands") or TextChatService) else nil
	addCommand(folder, "cash", withAmount(EconomyService.AddCash))
	-- A shop that can't restock (Config/Broke): /broke [cash] empties your shelves and boxes and sets your cash to
	-- that (default $8, down too). Under a box's cost Pish's help comes within a few seconds; a little over it,
	-- spending and opening your last packs are refused
	addCommand(folder, "broke", function(player, text)
		local cash = tonumber(string.match(text, "^/%w+%s+([%d%.]+)")) or 8
		for _, shelf in PlacementService.GetShelves(player) do
			if shelf.units > 0 then
				PlacementService.TakeStock(shelf, shelf.units)
			end
		end
		local StockService = require(script.Parent:WaitForChild("StockService")) :: any
		StockService.ClearForTesting(player)
		PlacementService.ClearRacksForTesting(player) -- stored boxes are stock too (StockService.GetBoxStock)
		EconomyService.SetCashForTesting(player, cash)
		Remotes.Notify:FireClient(player, string.format("No stock left, cash $%.2f (Studio)", cash), false)
	end)
	-- your Products shelves filled with a product (each to that many units, or full), to see how it stands on them
	addCommand(folder, "stock", function(player, text)
		local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products")) :: any
		local productId, amount = string.match(text, "^/%w+%s+(%S+)%s*(%d*)")
		if not productId or not Products.ById[productId] then
			Remotes.Notify:FireClient(player, "Usage: /stock <product id> [units a shelf] (FirstSparkPack, FirstSparkBox, CardSleeves, DeckBox...)", true)
			return
		end
		local total = 0
		for _, shelf in PlacementService.GetShelves(player) do
			if shelf.def.kind == "Products" then
				total += (PlacementService.AddStock(shelf, productId, tonumber(amount) or shelf.def.capacity))
			end
		end
		Remotes.Notify:FireClient(player, `Stocked {total} {productId} (Studio)`, false)
	end)
	addCommand(folder, "xp", withAmount(EconomyService.AddXP))
	addCommand(folder, "level", withAmount(jumpToLevel))
	addCommand(folder, "setxp", function(player, text)
		local xp = tonumber(string.match(text, "%s+(%S+)") or "")
		if not xp or xp ~= xp or xp < 0 or xp == math.huge then
			Remotes.Notify:FireClient(player, "Usage: /setxp <total XP, 0 or more> (sets it, down too; no rewards)", true)
			return
		end
		EconomyService.SetXPForTesting(player, xp)
	end)
	addCommand(folder, "beastxp", withAmount(grantBeastXp))
	addCommand(folder, "givecard", giveCards)
	-- "/bulk 120": a free Bulk Bin in your shop (when there's room) and that many plain Grade C Commons in your binder
	-- (100 by default), extras for its Add extras prompt (Config/Bulk)
	addCommand(folder, "bulk", function(player, text)
		local amount = math.clamp(tonumber(string.match(text, "%s+(%d+)") or "") or 100, 0, MAX_GIVE_CARDS)
		local placed = PlacementService.DevPlace(player, Bulk.SHELF)
		local commons = Cards.ByRarity.Common or {}
		local results = {}
		for index = 1, if #commons > 0 then amount else 0 do
			table.insert(results, { cardId = commons[(index - 1) % #commons + 1].id, foil = false, grade = "C" })
		end
		CardService.AddFresh(player, results)
		Remotes.Notify:FireClient(player, `{if placed then "A Bulk Bin is in your shop" else "No room for another bin"}; {#results} plain Commons in your binder.`, false)
	end)
	addCommand(folder, "item", giveItems)
	addCommand(folder, "weapon", giveWeapon)
	addCommand(folder, "material", giveMaterial)
	addCommand(folder, "weapondrop", forceWeaponDrop)
	addCommand(folder, "mutation", devMutation)
	addCommand(folder, "chests", previewChests)
	-- "/event <bossRush|luckySunday|off|auto|luck>": that weekly event on now for everyone here (off: none, auto: the
	-- calendar again), with its toast; luck: Lucky Sunday's free luck can be given again today (Config/Events)
	addCommand(folder, "event", function(player: Player, text: string)
		local EventService = require(Services:WaitForChild("EventService")) :: any
		local line = EventService.Dev(player, string.match(text, "%s+(%a+)") or "")
		print(`[DevService] {line or "Usage: /event <bossRush|luckySunday|off|auto|luck>"}`)
	end)
	-- "/codes reset": every Store code can be used again by you (Config/Codes)
	addCommand(folder, "codes", function(player: Player, _text: string)
		local CodeService = require(Services:WaitForChild("CodeService")) :: any
		print(`[DevService] {if CodeService.DevReset(player) then "Your codes can be used again" else "Codes aren't loaded here"}`)
	end)
	-- "/bossreset": what buying the boss reset does (Bosses.RESET): every running boss loot timer ends, its toast; free
	addCommand(folder, "bossreset", function(player: Player, _text: string)
		BossService.ResetTimers(player)
	end)
	-- "/bosstimer <1-7> <seconds>": that boss's loot timer runs out in that many seconds, to see its notice
	-- (Bosses.LOOT_READY: the toast, the Bosses tile's count, the Phone ping)
	addCommand(folder, "bosstimer", function(player: Player, text: string)
		local index, seconds = string.match(text, "^/%w+%s+(%d+)%s+(%d+)")
		if not index or not BossService.DevSetLootIn(player, tonumber(index) :: number, tonumber(seconds) :: number) then
			Remotes.Notify:FireClient(player, `Usage: /bosstimer <1-{#Bosses.LADDER}> <seconds>`, true)
			return
		end
		Remotes.Notify:FireClient(player, `Loot timer ends in {seconds} s.`, false)
	end)
	addCommand(folder, "boss", function(player, text)
		local index = tonumber(string.match(text, "%s+(%d+)") or "") or 0
		local gate = BossService.GetGate(index)
		local elsewhere = Bosses.BOSSES[Bosses.LADDER[index] or ""]
		if not gate and elsewhere then
			Remotes.Notify:FireClient(player, `That boss is in the {elsewhere.place}.`, true)
		elseif not gate then
			Remotes.Notify:FireClient(player, `Usage: /boss <1-{#Bosses.LADDER}> [fight|group]`, true)
		else
			-- To the gate first: its prompts only work up close
			WildService.TravelToWild(player, gate)
			local use = if string.find(text, "fight") then "fight" elseif string.find(text, "group") then "group" else nil
			if use then
				task.wait(0.5) -- the move settles before the gate checks the distance
				BossService.UseGate(player, index, use == "group")
			end
		end
	end)
	addCommand(folder, "room", function(player, text)
		local room = tonumber(string.match(text, "%s+(%d+)") or "")
		if not Place.isDungeon() or not room then
			Remotes.Notify:FireClient(player, "Usage (Dungeon window): /room <2-4> (4: the Hydra's chamber)", true)
			return
		end
		DungeonService.SkipTo(room, player)
	end)
	addCommand(folder, "winroom", function(player)
		if not Place.isDungeon() then
			Remotes.Notify:FireClient(player, "Usage (Dungeon window): /winroom (the room the run is at, won)", true)
			return
		end
		DungeonService.WinRoom(player)
	end)
	addCommand(folder, "puzzle", function(player, text)
		local kind = string.match(text, "%s+(%a+)")
		if not Place.isDungeon() or not kind then
			Remotes.Notify:FireClient(player, "Usage (Dungeon window): /puzzle solve (the puzzle the run is at) or /puzzle <beams|plates|lock> (go to it)", true)
			return
		end
		if kind == "solve" then
			DungeonService.SolvePuzzle(player)
		else
			DungeonService.SkipToPuzzle(kind, player)
		end
	end)
	addCommand(folder, "dungeonfx", function(player, text)
		local kind = string.match(text, "%s+(%a+)")
		local known = { intro = true, introshort = true, roar = true, glimpse = true }
		if not Place.isDungeon() or not kind or not known[kind] then
			Remotes.Notify:FireClient(player, "Usage (Dungeon window): /dungeonfx <intro|introshort|roar|glimpse>", true)
			return
		end
		player:SetAttribute("DungeonFxTest", `{kind}:{os.clock()}`) -- the Dungeon's intro and ambience controllers play it
	end)
	addCommand(folder, "tap", function(player, text)
		local name = string.match(text, "%s+(%S+)")
		local gate = if name then tonumber(string.match(name, "^RoomGate(%d)$")) else nil
		if Place.isDungeon() and gate then
			DungeonService.TapGate(player, gate)
			return
		end
		if not Place.isDungeon() or not name or not DungeonPuzzleService.Tap(player, name) then
			Remotes.Notify:FireClient(player, "Usage (Dungeon window): /tap <piece> (Mirror1, Plate2, SecretWall, LockCrystal_Tide, Chest_beams...)", true)
		end
	end)
	addCommand(folder, "jobslot", toggleJobSlot)
	addCommand(folder, "pass", devPass)
	addCommand(folder, "luck", giveLuck)
	addCommand(folder, "jobtired", function(player)
		JobService.ToggleTiredForTest(player)
	end)
	-- The prologue (spec 2026-11-14-prologue-hydra-design): /prologue plays it now on your screen; /prologue reset
	-- makes your save unseen so it plays on your next join
	addCommand(folder, "prologue", function(player, text)
		if string.match(text, "reset") then
			WelcomeService.ResetPrologue(player)
			Remotes.Notify:FireClient(player, "The prologue plays on your next join (Studio)", false)
		else
			WelcomeService.ReplayPrologue(player)
		end
	end)
	addCommand(folder, "intro", function(player)
		WelcomeService.Replay(player)
	end)
	-- "/decor <look id>": that shop look owned and in use; "/decor pieces": one of every decor piece in your shop's
	-- free cells, as many as fit (shop decor, spec 2026-11-14-shop-decor-design)
	addCommand(folder, "decor", function(player, text)
		local arg = string.match(text, "^/%w+%s+(%w+)")
		if arg == "pieces" then
			local placed = 0
			for _, def in Shelves.List do
				if def.kind == "Decor" and PlacementService.DevPlace(player, def.id) then
					placed += 1
				end
			end
			Remotes.Notify:FireClient(player, `Placed {placed} decor pieces.`, false)
			return
		end
		if arg and DecorService.SetLookForDev(player, arg) then
			Remotes.Notify:FireClient(player, `Shop look: {arg}.`, false)
			return
		end
		Remotes.Notify:FireClient(player, "Usage: /decor <CozyWood|CandyPastel|EnchantedForest|NeonArcade|CrystalCave|StarryNight|pieces>", true)
	end)
	-- "/window <style> <left|right> <at>": that window put in your shop for free, wherever it fits (shop windows,
	-- spec 2026-11-14-shop-windows-design)
	addCommand(folder, "window", function(player, text)
		local style, side, at = string.match(text, "^/%w+%s+(%w+)%s+(%a+)%s+(%-?[%d%.]+)")
		local ok, why = false, nil
		if style and side and at then
			ok, why = WindowService.DevPlace(player, style, side, tonumber(at) :: number)
		end
		if ok then
			Remotes.Notify:FireClient(player, `Window: {style} on the {side} wall.`, false)
		else
			Remotes.Notify:FireClient(player, `Usage: /window <Square|Wide|Arched|Porthole|Stained> <left|right> <at>{if why then " (" .. why .. ")" else ""}`, true)
		end
	end)
	-- "/shoproom <open|lock|fill> [backRoom|gallery|all]": the shop rooms opened or locked for free (no lesson; locking
	-- moves what stood inside out), or the shop filled with Small Pack Racks up to its cap (spec
	-- 2026-11-23-shop-rooms-design; `/room` is the Dungeon's)
	addCommand(folder, "shoproom", function(player, text)
		local action, which = string.match(text, "^/%w+%s+(%a+)%s*(%a*)")
		if action == "fill" then
			local placed = 0
			while placed < 60 and PlacementService.DevPlace(player, "SmallPackRack") do
				placed += 1
			end
			Remotes.Notify:FireClient(player, `Shop rooms: {placed} Small Pack Racks placed.`, false)
			return
		end
		if action == "open" or action == "lock" then
			local room = if which == nil or which == "" then "all" else which
			local ok, why = RoomService.DevSet(player, room, action == "open")
			if ok then
				Remotes.Notify:FireClient(player, `Shop rooms: {room} {if action == "open" then "open" else "locked"}.`, false)
				return
			end
			Remotes.Notify:FireClient(player, `Usage: /shoproom <open|lock|fill> [backRoom|gallery|all] ({why})`, true)
			return
		end
		Remotes.Notify:FireClient(player, "Usage: /shoproom <open|lock|fill> [backRoom|gallery|all]", true)
	end)
	-- "/storage <place|fill [product id]|clear>" (spec 2026-11-24-storage-racks-design): a free storage rack in your shop,
	-- your racks filled with full boxes (that product, else a mix of the orderable ones) or emptied
	addCommand(folder, "storage", function(player, text)
		local action, productId = string.match(text, "^/%w+%s+(%a+)%s*([%w_]*)")
		if action == "place" then
			local ok = PlacementService.DevPlace(player, "StorageRack")
			Remotes.Notify:FireClient(player, if ok then "Storage: a rack placed." else "Storage: no room, or 4 racks already.", not ok)
			return
		end
		if action == "fill" then
			local Products = require(Shared:WaitForChild("Config"):WaitForChild("Products")) :: any
			local kinds: { string } = {}
			if productId and Products.ById[productId] then
				kinds = { productId }
			else
				for _, product in Products.List do
					if not product.bulk and not product.unlockBoss then
						table.insert(kinds, product.id)
					end
				end
			end
			local stored = 0
			for _, rack in PlacementService.GetRacks(player) do
				-- kind by kind, a few each, so each kind sits together as stored boxes do
				local each = math.ceil(rack.def.capacity / #kinds)
				local full = false
				for _, kind in kinds do
					for _ = 1, each do
						if not PlacementService.StoreInRack(rack, kind, Products.ById[kind].unitsPerBox) then
							full = true
							break
						end
						stored += 1
					end
					if full then
						break
					end
				end
			end
			Remotes.Notify:FireClient(player, `Storage: {stored} {if stored == 1 then "box" else "boxes"} stored.`, false)
			return
		end
		if action == "clear" then
			PlacementService.ClearRacksForTesting(player)
			Remotes.Notify:FireClient(player, "Storage: racks emptied.", false)
			return
		end
		Remotes.Notify:FireClient(player, "Usage: /storage <place|fill [product id]|clear>", true)
	end)
	-- "/loading <main|wild|frontier|dungeon>": that place's loading screen played on your screen (LoadingController)
	addCommand(folder, "loading", function(player, text)
		local kind = string.match(text, "^/%w+%s+(%a+)")
		if kind ~= "main" and kind ~= "wild" and kind ~= "frontier" and kind ~= "dungeon" then
			Remotes.Notify:FireClient(player, "Usage: /loading <main|wild|frontier|dungeon>", true)
			return
		end
		player:SetAttribute("LoadingPreview", `{kind}:{os.clock()}`)
	end)
	addCommand(folder, "swordpopup", function(player)
		SwordService.ResetPopup(player)
	end)
	addCommand(folder, "buttonnames", function(player)
		SwordService.ResetFights(player)
	end)
	-- Hear one of a place's music options wherever you are (MusicController loops it while the attributes are set):
	-- "/music <n> [volume]" the town's, "/music <place> <n> [volume]" the Wild's (meadow, gorge, ridge, warden, brood,
	-- colossus) or the Frontier's (frostwood, stormpeak, rift, tyrant, sovereign, devourer), "/music [place] 0" back to the
	-- normal music
	addCommand(folder, "music", function(player, text)
		local counts: { [string]: number } = { [Music.TOWN.key] = #Music.TOWN.options }
		local keys = { Music.TOWN.key }
		local prologue = (Music :: any).PROLOGUE
		local prologueParts = { prologue.lair, prologue.fight, prologue.taken, prologue.wake }
		for _, list in { Music.WILD.areas, Music.WILD.arenas, (Music :: any).FRONTIER.areas, (Music :: any).FRONTIER.arenas, { Music.OPENING, (Music :: any).WELCOME, (Music :: any).FRONTIER.fight }, prologueParts } do
			for _, place in list do
				counts[place.key] = #place.options
				table.insert(keys, place.key)
			end
		end
		local key, index, volume = MusicRules.parsePreview(text, counts)
		if not key or not index then
			Remotes.Notify:FireClient(player, `Usage: /music [{table.concat(keys, "|")}] <option> [volume], 0 for the normal music`, true)
			return
		end
		local place = MusicRules.find(Music, key)
		player:SetAttribute("MusicPreviewPlace", if index > 0 then key else nil)
		player:SetAttribute("MusicPreview", if index > 0 then index else nil)
		player:SetAttribute("MusicPreviewVolume", volume)
		local line = if index > 0 then `Music {key} {index}: {place.options[index].name} at volume {volume or place.volume}` else "Music: back to the normal tracks"
		Remotes.Notify:FireClient(player, line, false)
	end)
	-- Hear a summon or unsummon sound option; it's used for your summons until "<command> 0" (SummonFx reads the picks)
	local function soundPick(command: string, kind: string, attribute: string): CommandHandler
		return function(player, text)
			local options = Party.SUMMON_SOUNDS.options[kind]
			local _, index, volume = MusicRules.parsePreview(text, { town = #options })
			if not index then
				Remotes.Notify:FireClient(player, `Usage: /{command} <1-{#options}> [volume], /{command} 0 for the normal one`, true)
				return
			end
			player:SetAttribute(attribute, if index > 0 then index else nil)
			player:SetAttribute(attribute .. "Volume", volume)
			if index > 0 then
				player:SetAttribute("SoundPreview", `{kind}|{os.clock()}`)
			end
			local line = if index > 0 then `{kind} sound {index}: {options[index].name}` else `{kind} sound: back to the normal one`
			Remotes.Notify:FireClient(player, line, false)
		end
	end
	addCommand(folder, "summonsound", soundPick("summonsound", "summon", "SummonSoundPick"))
	addCommand(folder, "unsummonsound", soundPick("unsummonsound", "unsummon", "UnsummonSoundPick"))
	-- The level-up pillar (Config/LevelUpFx): the effect alone (no XP, no rewards), and its sound options
	addCommand(folder, "levelfx", function(player, text)
		local asked = tonumber(string.match(text, "%s+(%d+)") or "")
		local current = player:GetAttribute("Level")
		local level = asked or (if typeof(current) == "number" then current else 2)
		LevelUpService.PreviewShop(player, math.clamp(math.floor(level), 2, Levels.MAX_LEVEL))
	end)
	addCommand(folder, "beastlevelfx", function(player)
		for _, marker in workspace:GetDescendants() do
			local beastId = marker:GetAttribute("BeastId")
			if marker:IsA("BasePart") and marker:GetAttribute("OwnerUserId") == player.UserId and typeof(beastId) == "string" then
				local beast = CardService.GetBeast(player, beastId)
				local card = if beast then Cards.ById[beast.cardId] else nil
				if beast and card then
					LevelUpService.PreviewCreature(player, beastId, beast.level, card.element)
					return
				end
			end
		end
		Remotes.Notify:FireClient(player, "Summon a creature first.", true)
	end)
	-- The Pet button moves (spec 2026-11-05-pet-moves-design): one at a grade on your summoned creature against a dummy,
	-- played by your client (MovePreviewController)
	addCommand(folder, "movefx", function(player, text)
		local move = string.match(text, "^/%w+%s+(%a+)")
		local grade = string.upper(string.match(text, "^/%w+%s+%a+%s+(%a)%f[%A]") or "S")
		local moves = { rain = true, vine = true, orbs = true, curse = true }
		if not move or not moves[move] or not ({ C = true, B = true, A = true, S = true })[grade] then
			Remotes.Notify:FireClient(player, "Usage: /movefx <rain|vine|orbs|curse> [C|B|A|S] [big]", true)
			return
		end
		local summoned = false
		for _, marker in workspace:GetDescendants() do
			if marker:IsA("BasePart") and marker:GetAttribute("OwnerUserId") == player.UserId and typeof(marker:GetAttribute("BeastId")) == "string" then
				summoned = true
				break
			end
		end
		if not summoned then
			Remotes.Notify:FireClient(player, "Summon a creature first.", true)
			return
		end
		Remotes.MovePreview:FireClient(player, { move = move, grade = grade, big = string.find(text, "%sbig") ~= nil })
	end)
	-- Three basic attacks at a grade from your summoned creature at a dummy, played by your client (MovePreviewController)
	addCommand(folder, "attackfx", function(player, text)
		local grade = string.upper(string.match(text, "^/%w+%s+(%a)%f[%A]") or "S")
		if not ({ C = true, B = true, A = true, S = true })[grade] then
			Remotes.Notify:FireClient(player, "Usage: /attackfx [C|B|A|S]", true)
			return
		end
		local summoned = false
		for _, marker in workspace:GetDescendants() do
			if marker:IsA("BasePart") and marker:GetAttribute("OwnerUserId") == player.UserId and typeof(marker:GetAttribute("BeastId")) == "string" then
				summoned = true
				break
			end
		end
		if not summoned then
			Remotes.Notify:FireClient(player, "Summon a creature first.", true)
			return
		end
		Remotes.MovePreview:FireClient(player, { attack = true, grade = grade })
	end)
	-- The super moves (spec 2026-11-05-super-moves-design): one at a grade on your summoned creature against a dummy,
	-- with the caster's cinematic, played by your client (MovePreviewController)
	addCommand(folder, "superfx", function(player, text)
		local name = string.lower(string.match(text, "^/%w+%s+(%a+)") or "")
		local grade = string.upper(string.match(text, "^/%w+%s+%a+%s+(%a)%f[%A]") or "S")
		local look: string? = nil
		for id in SuperFxConfig.LOOKS do
			if string.lower(id) == name then
				look = id
			end
		end
		if not look or not ({ C = true, B = true, A = true, S = true })[grade] then
			Remotes.Notify:FireClient(player, "Usage: /superfx <inferno|magmaslam|tidalshield|tidalblessing|stampede|eclipse|riftstep|supernova|thunderstorm|devour|seedclubslam|worldbloom> [C|B|A|S]", true)
			return
		end
		local summoned = false
		for _, marker in workspace:GetDescendants() do
			if marker:IsA("BasePart") and marker:GetAttribute("OwnerUserId") == player.UserId and typeof(marker:GetAttribute("BeastId")) == "string" then
				summoned = true
				break
			end
		end
		if not summoned then
			Remotes.Notify:FireClient(player, "Summon a creature first.", true)
			return
		end
		Remotes.MovePreview:FireClient(player, { super = look, grade = grade })
	end)
	-- The round 1 swords' effects (spec 2026-11-06-sword-skills-design 7): your character casts a sword's cut or skill at
	-- a dummy in front of you, coloured and scaled like that weapon at that level (Grade S), played by your client
	-- (MovePreviewController). "/skillfx sunforged skill", "/skillfx tide cut3 10"
	addCommand(folder, "skillfx", function(player, text)
		local name = string.lower(string.match(text, "^/%w+%s+(%a+)") or "")
		local move = string.lower(string.match(text, "^/%w+%s+%a+%s+(%w+)") or "skill")
		local level = tonumber(string.match(text, "%s(%d+)%s*$") or "0") or 0
		local weaponId = SwordSkillFx.PREVIEW[name]
		local weapon = if weaponId then Weapons.ById[weaponId] else nil
		if not weapon or not weapon.moveset or not ({ cut1 = true, cut2 = true, cut3 = true, skill = true })[move] then
			Remotes.Notify:FireClient(player, "Usage: /skillfx <sunforged|verdant|prism|forge|ember|tide|bloom|volt|shade|spear|halberd|trident|lance> [cut1|cut2|cut3|skill] [level]", true)
			return
		end
		Remotes.MovePreview:FireClient(player, {
			skillFx = weapon.moveset,
			weapon = weaponId,
			move = move,
			grade = "S",
			level = math.clamp(math.floor(level), 0, Weapons.MAX_LEVEL),
		})
	end)
	addCommand(folder, "levelsound", function(player, text)
		-- Round 5: pick one of the level-up sound sets (Config/LevelUpFx SOUNDS.sets) and hear it once
		local sets = LevelUpFx.SOUNDS.sets
		local _, index, volume = MusicRules.parsePreview(text, { town = #sets })
		if not index then
			Remotes.Notify:FireClient(player, `Usage: /levelsound <1-{#sets}> [volume], 0 for the default`, true)
			return
		end
		player:SetAttribute("LevelSoundSet", if index > 0 then index else nil)
		player:SetAttribute("LevelSoundVolume", if index > 0 then volume else nil)
		local line = if index > 0 then `Level sound {index}: {sets[index].name}` else "Level sound: back to the default"
		Remotes.Notify:FireClient(player, line, false)
		if index > 0 then
			local current = player:GetAttribute("Level")
			LevelUpService.PreviewShop(player, if typeof(current) == "number" then math.max(2, current) else 2)
		end
	end)
	addCommand(folder, "victorysound", function(player, text)
		-- The boss win's sting (Config/Victory WIN_OPTIONS): pick one by ear; heard once now (VictoryScreen) and on your
		-- next wins this session
		local options = Victory.WIN_OPTIONS
		local _, index = MusicRules.parsePreview(text, { town = #options })
		if not index then
			Remotes.Notify:FireClient(player, `Usage: /victorysound <1-{#options}>, 0 for the default`, true)
			return
		end
		player:SetAttribute("VictorySound", if index > 0 then index else nil)
		local line = if index > 0 then `Victory sound {index}: {options[index].name}` else "Victory sound: back to the default"
		Remotes.Notify:FireClient(player, line, false)
	end)
	addCommand(folder, "time", function(player, text)
		local phase = string.match(text, "%s+(%a+)")
		local known = false
		for _, entry in Cycle.PHASES do
			known = known or entry.name == phase
		end
		if not known or typeof(workspace:GetAttribute("DayCycleStart")) ~= "number" then
			Remotes.Notify:FireClient(player, "Usage (main town): /time <morning|afternoon|sunset|night|dawn>", true)
			return
		end
		workspace:SetAttribute("DayCycleStart", DayCycle.startFor(Cycle, phase :: string, workspace:GetServerTimeNow()))
	end)
	addCommand(folder, "wild", function(player)
		WildService.TravelToWild(player)
	end)
	addCommand(folder, "crowd", function(player, text)
		local count = tonumber(string.match(text, "%s+(%d+)") or "")
		if not count or count > MAX_CROWD then
			Remotes.Notify:FireClient(player, `Usage: /crowd <0-{MAX_CROWD}> (players counted in every Wild biome)`, true)
			return
		end
		WildService.SetPhantomPlayers(player, count)
		Remotes.Notify:FireClient(player, `The Wild counts {count} extra players in every biome.`, false)
	end)
	addCommand(folder, "rest", function(player)
		BattleService.ClearResting(player)
	end)
	addCommand(folder, "tire", function(player)
		BattleService.TireParty(player)
	end)
	addCommand(folder, "bosshp", function(player, text)
		local percent = tonumber(string.match(text, "/%w+%s+(%d+)")) or 0
		if percent < 1 or percent > 100 or not BattleService.SetBossHpShare(player, percent / 100) then
			Remotes.Notify:FireClient(player, "/bosshp <1-100>: in a boss fight.", true)
		end
	end)
	addCommand(folder, "elite", spawnElite)
	-- your next monster win drops a card: its loot beam (owner 2026-11-18, pick C; Config/CardLoot)
	addCommand(folder, "carddrop", function(player)
		BattleService.ForceDropForTest(player)
		Remotes.Notify:FireClient(player, "Your next monster win drops a card", false)
	end)
	-- your next boss loot win drops a Frontier card (owner 2026-11-21: the Frontier's bosses drop Frontier cards; any
	-- boss, here only): its gold tile on the victory screen, then the "FRONTIER CARD!" reveal, then the chests
	-- /bossbeaten <n> on|off: boss n counts as beaten and opened (a beaten Frontier or Dungeon boss's Take me there
	-- teleports; owner 2026-11-21); off puts back what it was (with no on before: never beaten, never opened). Turn it
	-- off again after: it's saved
	addCommand(folder, "bossbeaten", function(player, text)
		local number, word = string.match(text, "^/%w+%s+(%d+)%s*(%a*)")
		local BossService = require(script.Parent:WaitForChild("BossService")) :: any
		local on = word ~= "off"
		local done = number ~= nil and BossService.DevSetBeaten(player, tonumber(number), on)
		Remotes.Notify:FireClient(player, if done then `Boss {number} {if on then "beaten" else "not beaten"} (Studio)` else "Usage: /bossbeaten <1-7> on|off", not done)
	end)
	addCommand(folder, "bosscard", function(player)
		local BossService = require(script.Parent:WaitForChild("BossService")) :: any
		BossService.ForceCardForTest(player)
		Remotes.Notify:FireClient(player, "Your next boss loot win drops a Frontier card", false)
	end)
	-- a beaten monster's knockout without the fight (owner 2026-11-18, pick A; Config/MonsterKO): the nearest monster not
	-- in a fight flies off away from you; "/ko elite" the nearest elite
	addCommand(folder, "ko", function(player, text)
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		local markers = workspace:FindFirstChild("Monsters")
		if not root or not markers then
			return
		end
		local wantElite = string.match(text, "^/%w+%s+elite") ~= nil
		local best: WildService.Monster? = nil
		local bestDistance = KO_RANGE
		for _, marker in markers:GetChildren() do
			local monster = WildService.GetMonster(marker:GetAttribute("MonsterId") :: any)
			if monster and marker:IsA("BasePart") and not monster.boss and not monster.fightingPlayer and (monster.elite or not wantElite) then
				local distance = (marker.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = monster, distance
				end
			end
		end
		if not best then
			Remotes.Notify:FireClient(player, if wantElite then "No elite near you: /elite brings one" else "No monster near you: walk up to one", true)
			return
		end
		WildService.Lock(best, player)
		WildService.KnockOut(best, root.Position)
	end)
	-- knocked out on the spot as after a lost fight in a dangerous place: the countdown, Revive here (in the Wild; at
	-- home the countdown ends at once)
	-- "Support the dev" as if bought: that tier's gift (aura, titles, thanks), or 0 for none again
	addCommand(folder, "support", function(player, text)
		local tier = tonumber(string.match(text, "/%w+%s+(%d+)"))
		if not tier or tier > 3 or not SupportService.SetForTest(player, tier) then
			Remotes.Notify:FireClient(player, "/support <0-3>", true)
		end
	end)
	-- every title earned so far is new again: its "New title!" card, the dot, Pish's lesson (once more: /tutorial lesson titles)
	addCommand(folder, "titles", function(player, text)
		if string.match(text, "^/%w+%s+forget") == nil or not TitleService.ForgetForTest(player) then
			Remotes.Notify:FireClient(player, "/titles forget", true)
		end
	end)
	-- a customer's post in the phone's Reviews app, as if they just had that visit (paid, happyMoment, annoyed,
	-- gaveUp, noStock)
	addCommand(folder, "review", function(player, text)
		local outcome = string.match(text, "^/%w+%s+(%w+)")
		if not outcome or not ReviewService.PostForTest(player, outcome) then
			Remotes.Notify:FireClient(player, "/review <paid|happyMoment|annoyed|gaveUp|noStock>", true)
		end
	end)
	addCommand(folder, "knockout", function(player)
		if Place.isDungeon() or not WildService.IsInWild(player) then
			Remotes.Notify:FireClient(player, "/knockout: in the Wild or the Frontier.", true)
			return
		end
		KnockoutService.KnockOut(player)
	end)
	addCommand(folder, "serve", function(player)
		if not RegisterService.ServeForTest(player) then
			Remotes.Notify:FireClient(player, "Nobody at the register.", true)
		end
	end)
	local KID_RIPS = { rare = "Rare", veryrare = "Very Rare", vr = "Very Rare", epic = "Epic", legendary = "Legendary" }
	addCommand(folder, "customer", function(player, text)
		local kind, extra = string.match(text, "^/%w+%s+(%w+)%s*(%w*)")
		local inHand = string.find(string.lower(text), "%shand") ~= nil
		local rip = if kind == "kid" and extra then KID_RIPS[string.lower(extra)] else nil
		if rip then
			OfferService.ForceNextKidRip(player, rip)
		end
		local card = if kind == "collector" and extra and extra ~= "" then (Cards.ById[extra] or Cards.List[tonumber(extra) or 0]) else nil
		-- /customer plain all | stocked: wants one of every product the shop can stock (a missed product) or of every
		-- product on its shelves now ("Found it all!")
		local wants = if kind == "plain" and extra then string.lower(extra) else nil
		local wanted = if card then card.id elseif wants == "all" or wants == "stocked" then wants else nil
		if not kind or not CustomerService.SpawnForTest(player, kind, wanted, inHand) then
			Remotes.Notify:FireClient(player, "Usage: /customer <plain|kid|collector|bargain|bigSpender> [card for a collector, rarity for a kid, all or stocked for plain]", true)
		end
	end)
	-- The tutorial with Pish (spec 2026-11-09-tutorial-pish-design): /tutorial reset (a new player's first visit, gifts
	-- not given), /tutorial step <1-9>, /tutorial lesson <id> (that lesson visit again: sleeves, sword, condenser, forge,
	-- expand, boosterBox, grading, jobs), /pish (Town Pish comes to you), /pishluck (petting him gives luck again now)
	addCommand(folder, "tutorial", function(player, text)
		local word, value = string.match(text, "^/%w+%s+(%w+)%s*(%w*)")
		word = if word then string.lower(word) else nil
		local lessonId: string? = nil
		for _, lesson in PishConfig.LESSONS do
			if value and string.lower(lesson.id) == string.lower(value) then
				lessonId = lesson.id
			end
		end
		if word == "reset" then
			TutorialService.Reset(player)
		elseif word == "step" and tonumber(value) then
			TutorialService.SetStep(player, tonumber(value) :: number)
		elseif word == "lesson" and lessonId then
			if lessonId == "variety" and player:GetAttribute("MissedProduct") == nil then
				player:SetAttribute("MissedProduct", "CardSleeves") -- his first line names a product
			end
			TutorialService.QueueLesson(player, lessonId)
		else
			Remotes.Notify:FireClient(player, "Usage: /tutorial reset | /tutorial step <1-9> | /tutorial lesson <id>", true)
		end
	end)
	-- Chikin's combat tutorial (spec 2026-11-10-chikin-combat-tutorial-design): /chikin reset (a new player's tour, after
	-- Pish's), /chikin step <1-11> (that step)
	addCommand(folder, "chikin", function(player, text)
		local word, value = string.match(text, "^/%w+%s+(%w+)%s*(%w*)")
		word = if word then string.lower(word) else nil
		if word == "reset" then
			CombatTutorialService.Reset(player)
		elseif word == "step" and tonumber(value) then
			CombatTutorialService.SetStep(player, tonumber(value) :: number)
		else
			Remotes.Notify:FireClient(player, "Usage: /chikin reset | /chikin step <1-11>", true)
		end
	end)
	addCommand(folder, "pish", function(player)
		PishService.ComeTo(player)
	end)
	addCommand(folder, "pishluck", function(player)
		PishService.SetLuckAt(player, 0)
	end)
	addCommand(folder, "townchikin", function(player)
		TownChikinService.ComeTo(player)
		TownChikinService.SetCourageAt(player, 0) -- petting gives Courage again now
	end)
	-- Turts' rug shop: /turts restock (a new roll for you now), /turts move (he moves now), /turts offer <id> (that
	-- offer in your stock now; ids in Config/Turts OFFERS)
	addCommand(folder, "turts", function(player, text)
		local word, value = string.match(text, "^/%w+%s+(%w+)%s*([%w_]*)")
		word = if word then string.lower(word) else nil
		if word == "restock" then
			TurtsService.DevRestock(player)
		elseif word == "move" then
			TurtsService.DevMove()
		elseif word == "offer" and value and TurtsService.DevOffer(player, value) then
			return
		else
			warn("[DevService] /turts restock | move | offer <id>")
		end
	end)
	-- Daily, weekly and monthly gifts (Config/Gifts): /gift ready (today's now), /gift day <1-7> (that day's gift ready),
	-- /gift week <n> | month <n> (days claimed this week or month: the chest earned at its target), /gift reset,
	-- /gift tutorial (play time counting on or off), /gift win <daily|big|weekly|monthly> (only its win moment)
	addCommand(folder, "gift", function(player, text)
		local word, value = string.match(text, "^/%w+%s+(%w+)%s*(%w*)")
		local said = if word then GiftService.Dev(player, string.lower(word), if value ~= "" then string.lower(value) else nil) else nil
		if said then
			Remotes.Notify:FireClient(player, said, false)
		else
			Remotes.Notify:FireClient(player, "Usage: /gift ready | day <1-7> | week <n> | month <n> | reset | tutorial | win <daily|big|weekly|monthly>", true)
		end
	end)
	-- Daily quests (Config/Quests): /quests done (every quest of today done, ready to claim), /quests new (a new day's)
	-- /quests week (every weekly quest done, the Weekly Chest ready), /quests newweek (a new week's)
	addCommand(folder, "quests", function(player, text)
		local word = string.match(text, "^/%w+%s+(%w+)")
		local QuestService = require(script.Parent:WaitForChild("QuestService")) :: any
		local said = if word then QuestService.Dev(player, string.lower(word)) else nil
		Remotes.Notify:FireClient(player, said or "Usage: /quests done | new | week | newweek", said == nil)
	end)
	-- What now? hints (Config/Hints, client HintController): /hint <kind> shows that tip on its target now, whatever the
	-- shop's state
	addCommand(folder, "hint", function(player, text)
		local Hints = require(Config:WaitForChild("Hints")) :: any
		local kind = string.match(text, "^/%w+%s+(%a+)")
		if not kind or not table.find(Hints.ORDER, kind) then
			Remotes.Notify:FireClient(player, `Usage: /hint <{table.concat(Hints.ORDER, "|")}>`, true)
			return
		end
		player:SetAttribute("HintPreview", `{kind}:{os.clock()}`)
	end)
	-- The coin sound whenever cash goes up (Config/CoinSound OPTIONS, owner 2026-11-19): /coinsound <n> picks one by ear
	-- (heard once now and on every earning), 0 for the default
	addCommand(folder, "coinsound", function(player, text)
		local options = require(Config:WaitForChild("CoinSound")).OPTIONS
		local pick = tonumber(string.match(text, "^/%w+%s+(%d+)"))
		if not pick or pick > #options then
			Remotes.Notify:FireClient(player, `Usage: /coinsound <1-{#options}>, 0 for the default`, true)
			return
		end
		player:SetAttribute("CoinSoundPick", if pick > 0 then pick else nil)
		local heard = player:GetAttribute("CoinSoundPreview")
		player:SetAttribute("CoinSoundPreview", (if typeof(heard) == "number" then heard else 0) + 1)
		Remotes.Notify:FireClient(player, if pick > 0 then `Coin sound {pick}: {options[pick].name}` else "Coin sound: back to the default", false)
	end)
	-- Main quests (Config/MainQuests): /mainquest reset (every first build pays its shop XP again: sell one, place it)
	addCommand(folder, "mainquest", function(player, text)
		local word = string.match(text, "^/%w+%s+(%w+)")
		local MainQuestService = require(script.Parent:WaitForChild("MainQuestService")) :: any
		local said = if word then MainQuestService.Dev(player, string.lower(word)) else nil
		Remotes.Notify:FireClient(player, said or "Usage: /mainquest reset", said == nil)
	end)
	-- Welcome-back earnings (Config/Offline): /away <minutes> sells as if you'd been away that long (the stock really goes)
	addCommand(folder, "away", function(player, text)
		local minutes = tonumber(string.match(text, "^/%w+%s+(%d+)"))
		local OfflineService = require(script.Parent:WaitForChild("OfflineService")) :: any
		local said = if minutes then OfflineService.Dev(player, minutes) else nil
		Remotes.Notify:FireClient(player, said or "Usage: /away <minutes>", said == nil)
	end)
	addCommand(folder, "frontierdrop", function(player)
		ItemService.GiveItem(player, "starShard", 1)
		local pool = Cards.BySet.Frontier
		local card = pool[math.random(1, #pool)]
		CardService.AddFresh(player, { { cardId = card.id, foil = false, grade = BeastRules.rollGrade(math.random(), card.rarity) } })
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
	addCommand(folder, "maxcard", giveMaxCard)
	addCommand(folder, "raritypack", function(player, text)
		PackService.OpenRarityPack(player, string.find(string.lower(text), "foil") ~= nil)
	end)
	addCommand(folder, "footage", runFootage)
	-- The published game's Admin tile: a bare "/admin" (the owner's real save sends it) only answers with the refusal
	addCommand(folder, "admin", function(player: Player, _text: string)
		Remotes.Notify:FireClient(player, "Admin is open: pick a button.", false)
	end)
	makeStudioRunner()
	Remotes.DevPanel.OnServerEvent:Connect(onPanel)
	DataService.Register({
		name = "DevService",
		load = markAdmin,
		save = function() end,
		unload = function() end,
	})
	if not RunService:IsStudio() then
		return
	end
	print("[DevService] Studio commands enabled: /cash <amount>, /broke [cash], /xp <amount>, /level <level>, /setxp <xp>, /beastxp <amount>, /givecard <number> <amount>, /bulk [cards], /item <id> <amount>, /weapon <id> [grade] [level], /material <boss id> <amount>, /weapondrop <boss id>, /chests <boss id> [drop|miss], /bossreset, /event <bossRush|luckySunday|off|auto|luck>, /codes reset, /boss <n> [fight|group], /jobslot, /pass <VIP|QuickOpen|NightShift|StarterPack> [on|off], /luck <x2|x3> [minutes] | clear, /prologue [reset], /jobtired, /wild, /rest, /tire, /bosshp <1-100>, /townchikin, /turts <restock|move|offer <id>>, /gift <ready|day n|week n|month n|reset|tutorial|win kind>, /elite, /knockout, /support <0-3>, /titles forget, /review <outcome>, /arena, /frontierdrop, /testpack, /raritypack [foil], /legendarys [foil], /maxcard <name> [foil], /crowd <0-60>, /customer <type> [card|rarity], /serve, /decor <look id|pieces>, /window <style> <side> <at>, /shoproom <open|lock|fill> [room|all], /storage <place|fill [product]|clear>, /loading <main|wild|frontier|dungeon>, /swordpopup, /buttonnames, /music [place] <n> [volume], /summonsound <n>, /unsummonsound <n>, /levelfx [level], /beastlevelfx, /levelsound <1-4> [volume], /victorysound <1-3>, /movefx <rain|vine|orbs|curse> [C|B|A|S] [big], /superfx <move> [C|B|A|S], /attackfx [C|B|A|S], /skillfx <sword> [cut1|cut2|cut3|skill] [level], /room <2-4>, /winroom, /puzzle <solve|beams|plates|lock>, /tap <piece>, /dungeonfx <intro|introshort|roar|glimpse>, /hint <kind>")
end

return DevService
