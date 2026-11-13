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
-- Does nothing outside Studio, so live players never get these commands.
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
local TutorialService = require(Services:WaitForChild("TutorialService"))
local CombatTutorialService = require(Services:WaitForChild("CombatTutorialService"))
local SwordService = require(Services:WaitForChild("SwordService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local KnockoutService = require(Services:WaitForChild("KnockoutService"))
local SupportService = require(Services:WaitForChild("SupportService"))
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
local RateLimiter = require((Services.Parent :: Instance):WaitForChild("Util"):WaitForChild("RateLimiter"))

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

local function addCommand(folder: Instance, alias: string, handler: CommandHandler)
	handlersByAlias[alias] = handler
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

-- "/chests meadowWarden [drop|miss|strong|tired]": that boss's three chests on your screen now, nothing given (a drop
-- shows a new Grade A copy's reveal; strong / tired: a reduced win's empty chest); miss when left out (spec
-- 2026-11-11-boss-chests-design)
local function previewChests(player: Player, text: string)
	local bossId, kind = string.match(text, "%s+([%w_]+)%s*(%a*)")
	local weaponId = if bossId then BossService.WeaponOf(bossId) else nil
	local kinds = { drop = true, miss = true, strong = true, tired = true }
	if not bossId or not weaponId or (kind ~= "" and not kinds[kind]) then
		Remotes.Notify:FireClient(player, "Usage: /chests <boss id with a built weapon> [drop|miss|strong|tired] (meadowWarden, prismHydra)", true)
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
	CardService.AddBeast(player, {
		id = HttpService:GenerateGUID(false),
		cardId = found.id,
		foil = foil,
		level = Beasts.MAX_LEVEL,
		xp = 0,
		stars = Beasts.MAX_STARS,
		grade = Beasts.GRADES[#Beasts.GRADES],
	})
	Remotes.Notify:FireClient(player, `Gave a maxed {if foil then "foil " else ""}{found.name} (Lv {Beasts.MAX_LEVEL}, {Beasts.MAX_STARS} stars, Grade {Beasts.GRADES[#Beasts.GRADES]})`, false)
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
	addCommand(folder, "item", giveItems)
	addCommand(folder, "weapon", giveWeapon)
	addCommand(folder, "material", giveMaterial)
	addCommand(folder, "weapondrop", forceWeaponDrop)
	addCommand(folder, "chests", previewChests)
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
		DungeonService.WinRoom()
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
	addCommand(folder, "jobtired", function(player)
		JobService.ToggleTiredForTest(player)
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
		for _, list in { Music.WILD.areas, Music.WILD.arenas, (Music :: any).FRONTIER.areas, (Music :: any).FRONTIER.arenas, { Music.OPENING, (Music :: any).WELCOME } } do
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
			Remotes.Notify:FireClient(player, "Usage: /superfx <inferno|magmaslam|tidalshield|tidalblessing|stampede|eclipse|riftstep|supernova|thunderstorm|devour> [C|B|A|S]", true)
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
		WildService.SetPhantomPlayers(count)
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
		if not kind or not CustomerService.SpawnForTest(player, kind, if card then card.id else nil, inHand) then
			Remotes.Notify:FireClient(player, "Usage: /customer <plain|kid|collector|bargain|bigSpender> [card for a collector, rarity for a kid]", true)
		end
	end)
	-- The tutorial with Pish (spec 2026-11-09-tutorial-pish-design): /tutorial reset (a new player's first visit, gifts
	-- not given), /tutorial step <1-8>, /tutorial lesson <id> (that lesson visit again: sleeves, sword, condenser, forge,
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
			TutorialService.QueueLesson(player, lessonId)
		else
			Remotes.Notify:FireClient(player, "Usage: /tutorial reset | /tutorial step <1-8> | /tutorial lesson <id>", true)
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
	-- The same commands for Studio's scripting tools, which can't type in chat:
	-- ServerStorage.DevCommand:Invoke(player, "/item gradingSeal 5"). Studio only, like the chat commands.
	local function run(player: Player, text: string): boolean
		local alias = string.match(text, "^/(%w+)")
		local handler = if alias then handlersByAlias[alias] else nil
		if not handler or typeof(player) ~= "Instance" or not player:IsA("Player") then
			return false
		end
		handler(player, text)
		return true
	end
	local runner = Instance.new("BindableFunction")
	runner.Name = "DevCommand"
	runner.OnInvoke = run
	runner.Parent = game:GetService("ServerStorage")
	-- The admin panel's buttons (AdminPanelController). Only connected here, in Studio: the live game ignores them.
	local allowPanel = RateLimiter.new(AdminPanel.COMMAND_COOLDOWN)
	Remotes.DevPanel.OnServerEvent:Connect(function(player, text)
		if allowPanel(player) and typeof(text) == "string" and #text <= AdminPanel.COMMAND_MAX_LENGTH then
			run(player, text)
		end
	end)
	print("[DevService] Studio commands enabled: /cash <amount>, /xp <amount>, /level <level>, /setxp <xp>, /beastxp <amount>, /givecard <number> <amount>, /item <id> <amount>, /weapon <id> [grade] [level], /material <boss id> <amount>, /weapondrop <boss id>, /chests <boss id> [drop|miss|strong|tired], /boss <n> [fight|group], /jobslot, /jobtired, /wild, /rest, /tire, /bosshp <1-100>, /townchikin, /turts <restock|move|offer <id>>, /elite, /knockout, /support <0-3>, /titles forget, /review <outcome>, /arena, /frontierdrop, /testpack, /raritypack [foil], /legendarys [foil], /maxcard <name> [foil], /crowd <0-60>, /customer <type> [card|rarity], /serve, /decor <look id|pieces>, /loading <main|wild|frontier|dungeon>, /swordpopup, /buttonnames, /music [place] <n> [volume], /summonsound <n>, /unsummonsound <n>, /levelfx [level], /beastlevelfx, /levelsound <1-3> [volume], /victorysound <1-3>, /movefx <rain|vine|orbs|curse> [C|B|A|S] [big], /superfx <move> [C|B|A|S], /attackfx [C|B|A|S], /skillfx <sword> [cut1|cut2|cut3|skill] [level], /room <2-4>, /winroom, /puzzle <solve|beams|plates|lock>, /tap <piece>, /dungeonfx <intro|introshort|roar|glimpse>")
end

return DevService
