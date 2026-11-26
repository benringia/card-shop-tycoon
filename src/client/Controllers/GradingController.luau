--!strict
-- Grading Station window, the put-a-card-in shape since 2026-11-26 (owner: "Grading station is confusing too. same with
-- the condenser, there should be an "Upgrade" tab where the player put the specific card they want to upgrade, then,
-- the option to use upgrade materialls will then show the user. remove search", "change "Make it Grade A" to "Upgrade"
-- then the cost. remove the cost anywhere else", and the grade swap and "Keep a different copy" dropped; the mockups of
-- artifact 72BD8xZJT75xL5ityfY621; Util/StationPick builds the shape, Config/Grading WINDOW its words). Tabs: Upgrade
-- and Ready (a gold count). Upgrade: a slot on the left ("Put a card in"); a tap opens the card picker over the window
-- (your cards with extra copies as tiles, Ready ones first); a card picked shows its copies that can still go up
-- (owner 2026-11-26: "when I click on a card, it then should let me pick which copy ... do the same in grading"; one
-- such copy goes straight in), and the copy picked sits in the slot with Change card. On the right its picture recipe
-- (the arrow in the middle; Util/Recipe, words in
-- Util/CondenseRules): one sentence ("Use 2 extra Voidmaw to make it Grade A!"), the copies that go in as little cards,
-- an arrow, the card with its new grade beating under it and how much Power it adds; then the USE row's three tiles:
-- the extra copies (your weakest, picked for you), Grading Seals (a tap puts them in the empty spots, or takes them
-- out) and Gold Seals (a tap pays the cash with one); and the big button pinned at the box's bottom, "Upgrade $2,500"
-- with how long it takes: the only place the cost shows. Ready: the cards that can go up now; a tap puts one in. A
-- finished grade waits here like the Condenser's star (Util/DoneReveal, the GradingDone attribute). Upgrade asks the
-- server, which re-checks everything and takes the cash; the binder sync redraws the window. Opened from your own
-- Grading Station's prompt with the slot empty; closes when you walk away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local GradingConfig = require(Config:WaitForChild("Grading"))
local StationLook = require(Config:WaitForChild("StationLook"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CondenseRules = require(Shared:WaitForChild("Util"):WaitForChild("CondenseRules"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local JobPanel = require(ClientUtil:WaitForChild("JobPanel"))
local DoneReveal = require(ClientUtil:WaitForChild("DoneReveal"))
local Recipe = require(ClientUtil:WaitForChild("Recipe"))
local StationJobs = require(ClientUtil:WaitForChild("StationJobs"))
local StationPick = require(ClientUtil:WaitForChild("StationPick"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One copy that can be graded: a levelled card, or a stack of plain copies (one grade, foil or not)
type Candidate = { key: string, beast: Beast?, foil: boolean, grade: string, level: number, stars: number, count: number, power: number }

local WORDS = GradingConfig.WINDOW
local UPGRADE_TAB, READY_TAB = WORDS.TABS[1], WORDS.TABS[2]
local PANEL_MAX_SIZE = Vector2.new(820, 540)
local DETAIL_FACE_SIZE = Vector2.new(96, 137)
local DISTANCE_CHECK_SECONDS = 0.5
local RECIPE = Recipe.LOOK -- the recipe on the right (Util/Recipe, shared with the Condenser)
local EDGE = 12 -- the box's pieces keep this far from its edges, so no outline or lifted button is cut
local USE_TALL = 58 -- a USE tile (a phone's: USE_PHONE)
local USE_PHONE = 46
local USE_GAP = 8
local POWER_ROOM = 96 -- a computer's +Power pill beside the card
-- A phone (owner 2026-11-21: on a 705 x 338 phone the window was 241 px tall): the window takes nearly the whole screen,
-- the recipe is smaller and the USE tiles stand in a column beside it
local PHONE_FACE = Vector2.new(66, 94)
local PHONE_LEFT = 0.56 -- the recipe's share of the box's width on a phone
local PHONE_UNDER = 26 -- a phone's row under the recipe (the grade it becomes, +Power)

local player = Players.LocalPlayer

local GradingController = {}

local panel: Frame
local window: StationPick.Window
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local machine: BasePart? = nil
local tab = UPGRADE_TAB
-- The picker over the window: "cards" (pick a card) or "copies" (that card's copies that can still go up: which one is
-- graded; owner 2026-11-26: "when I click on a card, it then should let me pick which copy of that card would I want to
-- use. do the same in grading"); nil: none. `copiesBack`: where Back goes from the copies
local picking: string? = nil
local pickCard: string? = nil
local copiesBack = "cards"
local selectedCardId: string? = nil -- the card in the slot
local mainKey: string? = nil -- the copy in the slot, followed after a plain copy moves up a grade; nil = the default
local inFlight = false -- an Upgrade request is waiting for the server; the button stays locked
local inFlightToken = 0
local useSeals = false -- Grading Seals fill missing duplicates (up to half a step)
local sealCount = 0 -- from ItemsChanged
local useGold = false -- a Gold Seal pays the step's cash (not a Legendary's A to S)
local goldCount = 0

local function makeFace(parent: Instance, card: Card, foil: boolean, showValue: boolean, growth: CardFace.Growth?)
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = parent
	UIKit.corner(face, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, foil, showValue, growth)
end

local function getCash(): number
	local cash = player:GetAttribute("Cash")
	return if typeof(cash) == "number" then cash else 0
end

local function formatCash(amount: number): string
	local whole = tostring(math.floor(amount))
	local withCommas = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (withCommas:gsub("^,", ""))
end

-- Every copy of this card that could be graded, highest grade first (the copy you'd most want at S), then strongest
local function getCandidates(card: Card): { Candidate }
	local candidates: { Candidate } = {}
	local working = BinderController.GetWorking()
	for id, beast in BinderController.GetBeasts() do
		if beast.cardId == card.id and not working[id] then -- working cards can't be graded
			table.insert(candidates, {
				key = beast.id,
				beast = beast,
				foil = beast.foil,
				grade = beast.grade,
				level = beast.level,
				stars = beast.stars,
				count = 1,
				power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade),
			})
		end
	end
	for grade, owned in BinderController.GetGradedStacks()[card.id] or {} do
		for _, foil in { true, false } do
			local count = if foil then owned.foil else owned.normal
			if count > 0 then
				table.insert(candidates, {
					key = `stack:{grade}:{foil}`,
					foil = foil,
					grade = grade,
					level = 1,
					stars = BeastRules.START_STARS,
					count = count,
					power = BeastRules.getPower(card, foil, 1, BeastRules.START_STARS, grade),
				})
			end
		end
	end
	CondenseRules.sortMainChoices(candidates)
	return candidates
end

local function asMain(main: Candidate): CondenseRules.Main
	return { beast = main.beast ~= nil, foil = main.foil, grade = main.grade, stars = main.stars }
end

local function getPlan(card: Card, main: Candidate): (CondenseRules.GradePlan?, string?)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	return CondenseRules.gradePlan(GradingConfig, Beasts, card.rarity, byGrade, asMain(main), if useSeals then sealCount else nil)
end

-- The default main copy: the first one that can still go up a grade
local function defaultMain(candidates: { Candidate }): Candidate?
	for _, candidate in candidates do
		if CondenseRules.nextGrade(Beasts.GRADES, candidate.grade) then
			return candidate
		end
	end
	return candidates[1]
end

local function isReady(card: Card): boolean
	local main = defaultMain(getCandidates(card))
	if not main then
		return false
	end
	local plan = getPlan(card, main)
	return plan ~= nil and getCash() >= plan.cash
end

-- Cards you own two or more copies of, below Grade S. Rarest first.
local function getGradableCards(): { Card }
	local result: { Card } = {}
	for _, card in Cards.RarestFirst do
		local copies, belowTop = 0, false
		for _, candidate in getCandidates(card) do
			copies += candidate.count
			if CondenseRules.nextGrade(Beasts.GRADES, candidate.grade) then
				belowTop = true
			end
		end
		if belowTop and copies >= 2 then
			table.insert(result, card)
		end
	end
	return result
end

-- The copy in the slot: the one followed after a grade-up, else the default
local function chosenMain(card: Card): Candidate?
	local candidates = getCandidates(card)
	for _, candidate in candidates do
		if candidate.key == mainKey then
			return candidate
		end
	end
	return defaultMain(candidates)
end

-- A finished grade waiting in the Grading Station: its reveal over the window (Util/DoneReveal), set up in Start
local refreshDone: (opened: boolean?) -> () = function() end

local render: () -> ()

-- Right side ------------------------------------------------------------------------------------------------------

-- One USE tile: its title and small line; `lit` while it's in, `tap` nil: not tappable
local function useTile(parent: Instance, name: string, order: number, title: string, sub: string, lit: boolean, tap: (() -> ())?)
	local on = StationLook.USE_ON
	local tile = Instance.new("TextButton")
	tile.Name = name
	tile.LayoutOrder = order
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.BackgroundColor3 = if lit then StationPick.rgb(on.fill) else palette.row
	tile.Parent = parent
	UIKit.corner(tile, 14)
	UIKit.outline(tile, if lit then StationPick.rgb(on.edge) else palette.rowEdge, 2)
	local phone = UIKit.isShort()
	local top = UIKit.label(tile, title, Enum.Font.GothamBold, if phone then 12 else 13, palette.ink)
	top.Name = "Title"
	top.Position = UDim2.fromOffset(10, if phone then 6 else 7)
	top.Size = UDim2.new(1, -16, 0, if phone then 15 else 17)
	top.TextWrapped = false
	top.TextTruncate = Enum.TextTruncate.AtEnd
	-- its small line: one line in a phone's wide tile, two in a computer's narrow one
	local small = UIKit.label(tile, sub, Enum.Font.GothamBold, 11, palette.inkSoft)
	small.Name = "Sub"
	small.Position = UDim2.fromOffset(10, if phone then 23 else 25)
	small.Size = UDim2.new(1, -16, 0, if phone then 15 else 28)
	small.TextWrapped = not phone
	small.TextYAlignment = Enum.TextYAlignment.Top
	small.TextTruncate = Enum.TextTruncate.AtEnd
	if tap then
		tile.Activated:Connect(tap)
	end
end

local function renderPane(card: Card, chosen: Candidate)
	local pane = window.pane
	StationPick.clear(pane)
	local phone = UIKit.isShort()
	local face = if phone then PHONE_FACE else DETAIL_FACE_SIZE
	local paneWide = StationPick.width(window, pane)
	if paneWide < 120 then
		paneWide = if phone then 320 else 480 -- not laid out yet
	end
	local leftWide = if phone then math.floor(paneWide * PHONE_LEFT) else paneWide

	-- What goes in: the plan's copies and seals when the grade can be raised, else the copies there are (and, with the
	-- seals in, as many as may stand in)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	local main = asMain(chosen)
	local plan = getPlan(card, chosen)
	local nextGrade = CondenseRules.nextGrade(Beasts.GRADES, chosen.grade)
	local step = if nextGrade then CondenseRules.gradeStepCost(GradingConfig, card.rarity, nextGrade) else nil
	local need = if step then step.copies else 0
	local have = math.min(need, CondenseRules.gradeHave(Beasts, byGrade, main))
	local share = GradingConfig.MAX_SEAL_SHARE or 0
	local sealsIn = if plan then plan.seals elseif useSeals then math.max(0, math.min(sealCount, math.floor(need * share), need - have)) else 0
	local copiesIn = if plan then need - plan.seals else have
	local offers = CondenseRules.shardOffers(need, have, sealCount, share, useSeals)
	local missing = if plan or not nextGrade then 0 else need - copiesIn - sealsIn
	local could = not useSeals and plan == nil and nextGrade ~= nil and (CondenseRules.gradePlan(GradingConfig, Beasts, card.rarity, byGrade, main, sealCount)) ~= nil
	local cash = getCash()
	local price = if step then step.cash else 0
	local goldAllowed = nextGrade ~= nil and CondenseRules.goldSealAllowed(card.rarity, nextGrade)
	local goldPays = useGold and goldCount > 0 and goldAllowed
	local affordable = goldPays or cash >= price
	local canGrade = plan ~= nil and affordable and not inFlight

	-- one sentence: what will happen (never the cash: the button shows it)
	local sentence = CondenseRules.gradeSay({ name = card.name, grade = nextGrade, copies = copiesIn, seals = sealsIn, missing = missing })
	-- (one line or two: the recipe moves up under a short one, so the whole box fits over the button)
	local saySize = if phone then 14 else 19
	local sayTall = math.clamp(StationPick.textTall(sentence, saySize, Enum.Font.FredokaOne, leftWide - 2 * EDGE) + 4, if phone then 20 else 26, if phone then 40 else 52)
	local say = UIKit.label(pane, sentence, Enum.Font.FredokaOne, saySize, palette.ink)
	say.Name = "Say"
	say.Position = UDim2.fromOffset(EDGE, 8)
	say.Size = UDim2.fromOffset(leftWide - 2 * EDGE, sayTall)
	say.TextWrapped = true
	say.TextXAlignment = Enum.TextXAlignment.Center
	local y = sayTall + 14

	-- The recipe: the spots, an arrow, the card that gets the grade (alone once it is Grade S); a computer's +Power
	-- beside the card, a phone's under the spots. The card is as big as the box has room for over the USE row and the
	-- button (a short window's smaller)
	local useRoom = if phone or not nextGrade then 0 else 16 + USE_TALL + 8
	local under = if phone then PHONE_UNDER else RECIPE.under
	local faceTall = math.clamp(StationPick.height(window, pane) - y - under - useRoom - 2, if phone then 56 else 84, face.Y)
	face = Vector2.new(math.floor(faceTall * face.X / face.Y), faceTall)
	local powerBeside = not phone and nextGrade ~= nil
	local slotsWide = math.clamp(leftWide - 2 * EDGE - RECIPE.arrow - face.X - (if powerBeside then POWER_ROOM else 0) - 8, 100, 280)
	local recipe = Instance.new("Frame")
	recipe.Name = "Recipe"
	recipe.BackgroundTransparency = 1
	recipe.AnchorPoint = Vector2.new(0.5, 0)
	recipe.Position = UDim2.fromOffset(leftWide / 2 - (if powerBeside then POWER_ROOM / 2 else 0), y)
	recipe.Size = UDim2.fromOffset(face.X, face.Y + under) -- widened once the spots are in
	recipe.Parent = pane
	local faceHolder = Instance.new("Frame")
	faceHolder.Name = "Keeps"
	faceHolder.AnchorPoint = Vector2.new(1, 0)
	faceHolder.Position = UDim2.fromScale(1, 0)
	faceHolder.Size = UDim2.fromOffset(face.X, face.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = recipe
	makeFace(faceHolder, card, chosen.foil, false, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })
	-- under the card: the grade it becomes, beating (or the one it has, at the top)
	local gradePill = UIKit.pill(recipe, BeastRules.describeGrade(nextGrade or chosen.grade), UIKit.Colors.Accent, UIKit.Colors.Ink)
	gradePill.Name = "Grade"
	gradePill.AnchorPoint = Vector2.new(0.5, 0.5) -- it beats about its middle, clear of the card
	gradePill.Position = UDim2.new(1, -face.X / 2, 0, face.Y + under / 2 + 1)
	if nextGrade then
		Recipe.beat(gradePill)
	end

	local spots: { GuiObject } = {}
	if nextGrade then
		local grid, used = Recipe.grid(recipe, need, CondenseRules.slotColumns(need), Vector2.new(slotsWide, face.Y), StationLook.RECIPE_SPOT_TALL)
		-- the spots, the arrow in the middle of its room, the card: the whole row centred
		recipe.Size = UDim2.fromOffset(used + RECIPE.arrow + face.X, face.Y + under)
		local copies: { CondenseRules.Take } = {}
		for _, take in if plan then plan.takes else CondenseRules.pick(Beasts.GRADES, byGrade, main, copiesIn) do
			for _ = 1, take.count do
				table.insert(copies, take)
			end
		end
		for index, kind in CondenseRules.slots(need, copiesIn, sealsIn, offers) do
			local take = copies[index]
			local spot = Recipe.spot(grid, if kind == "shard" then "item" else kind, {
				order = index,
				palette = palette,
				image = if kind == "copy" then CardFace.artImage(card) else nil,
				foil = take ~= nil and take.foil,
				icon = "GradingSeal",
				onTap = function()
					useSeals = kind == "offer"
					render()
				end,
			})
			if kind == "copy" or kind == "shard" then
				table.insert(spots, spot)
			end
		end
		Recipe.arrow(recipe, used + RECIPE.arrow / 2, face.Y / 2)
		-- how much stronger the card gets
		local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, chosen.stars, nextGrade)
		local power = UIKit.pill(recipe, `+{math.max(0, powerAfter - chosen.power)} Power`, palette.good, Color3.new(1, 1, 1))
		power.Name = "Power"
		if powerBeside then
			power.AnchorPoint = Vector2.new(0, 0.5)
			power.Position = UDim2.new(1, 10, 0, face.Y / 2)
		else
			power.AnchorPoint = Vector2.new(0.5, 0)
			power.Position = UDim2.fromOffset(used / 2, face.Y + 4)
		end
	end
	y += face.Y + under + 4

	-- The USE row (owner 2026-11-26: "the option to use upgrade materialls will then show the user"): the copies picked
	-- for you, Grading Seals and Gold Seals, each a tile with a small line saying what it does or what a tap does. A
	-- computer's under the recipe, three across; a phone's in a column beside it
	if nextGrade then
		local useX, useY, useWide = if phone then leftWide else EDGE, if phone then 4 else y, if phone then paneWide - leftWide - EDGE else paneWide - 2 * EDGE
		local label = UIKit.label(pane, WORDS.USE, Enum.Font.GothamBold, 11, palette.inkSoft)
		label.Name = "Use"
		label.Position = UDim2.fromOffset(useX + 2, useY)
		label.Size = UDim2.fromOffset(useWide, 14)
		local row = Instance.new("Frame")
		row.Name = "UseTiles"
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(useX, useY + 16)
		row.Size = UDim2.fromOffset(useWide, if phone then 3 * USE_PHONE + 2 * USE_GAP else USE_TALL)
		row.Parent = pane
		local grid = Instance.new("UIGridLayout")
		-- (three across with a pixel to spare: cells that fill the row exactly wrap the third)
		grid.CellSize = if phone then UDim2.new(1, 0, 0, USE_PHONE) else UDim2.new(1 / 3, -USE_GAP, 0, USE_TALL)
		grid.CellPadding = UDim2.fromOffset(USE_GAP, USE_GAP)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = row
		local copiesTitle, copiesSub = CondenseRules.copiesTile(copiesIn)
		useTile(row, "Copies", 1, copiesTitle, copiesSub, copiesIn > 0, nil)
		local sealTitle, sealSub = CondenseRules.sealTile({ have = sealCount, on = useSeals, used = sealsIn, offers = offers, could = could, missing = missing, max = false })
		useTile(row, "Seals", 2, sealTitle, sealSub, sealsIn > 0, if useSeals or offers > 0 then function()
			useSeals = not useSeals
			render()
		end else nil)
		local goldTitle, goldSub = CondenseRules.goldTile(goldCount, goldPays, goldAllowed)
		useTile(row, "Gold", 3, goldTitle, goldSub, goldPays, if goldAllowed and goldCount > 0 then function()
			useGold = not useGold
			render()
		end else nil)
	end

	-- The big button pinned at the box's bottom: "Upgrade $2,500" and how long it takes, or what's missing
	local seconds = if nextGrade then EarlyRules.stationWait(UpgradeRules.seconds(Upgrades, "grade", nextGrade, card.rarity), tonumber(player:GetAttribute("Level")) or 1, Early) else 0
	local buttonText, buttonSub = CondenseRules.gradeButton({ inFlight = inFlight, grade = nextGrade, cash = formatCash(price), have = formatCash(cash), affordable = affordable, missing = missing, seconds = seconds, gold = goldPays })
	local gradeButton = StationPick.bigButton(window, buttonText, buttonSub, canGrade)
	gradeButton.Name = "GradeUp"
	gradeButton.Activated:Connect(function()
		local part = machine
		if not canGrade or inFlight or not part then
			return
		end
		Recipe.flyIn(panel, spots, faceHolder)
		-- Locked until the binder sync arrives (or a timeout if the server refused), so a second tap can't send the
		-- same stale request
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(GradingConfig.IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
		local beast = chosen.beast
		if beast then
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id, nil, nil, useSeals, goldPays)
		else
			-- A plain copy moves up to the next grade's stack: keep following it there
			mainKey = `stack:{plan and plan.grade or chosen.grade}:{chosen.foil}`
			Remotes.GradeUp:FireServer(part:GetAttribute("ShelfUid"), card.id, nil, chosen.foil, chosen.grade, useSeals, goldPays)
		end
		render()
	end)
end

-- The slot and the picker ---------------------------------------------------------------------------------------------

-- A copy goes in the slot (from the picker's copies step, or a card with one copy to grade from the picker or the
-- Ready tab): the Upgrade tab shows it with its recipe. `key` nil: the card's default copy
local function putIn(cardId: string, key: string?)
	if selectedCardId ~= cardId or mainKey ~= key then
		useSeals = false
		useGold = false
	end
	selectedCardId = cardId
	mainKey = key
	picking = nil
	tab = UPGRADE_TAB
	render()
end

local function openPicker()
	picking = "cards"
	render()
end

-- The copies of a card that can still go up a grade, the best grade first
local function gradeable(card: Card): { Candidate }
	local copies: { Candidate } = {}
	for _, candidate in getCandidates(card) do
		if CondenseRules.nextGrade(Beasts.GRADES, candidate.grade) then
			table.insert(copies, candidate)
		end
	end
	return copies
end

-- A card picked: its copies to choose from (Back goes to `back`: "cards" or "close"), or with one copy straight in
local function pickCardCopies(cardId: string, back: string)
	local card = Cards.ById[cardId]
	local copies = if card then gradeable(card) else {}
	if #copies <= 1 then
		putIn(cardId, if copies[1] then copies[1].key else nil)
		return
	end
	picking = "copies"
	pickCard = cardId
	copiesBack = back
	render()
end

-- The picker's copies step: every copy of the card that can still go up a grade, each with its stars, "You have 2" or
-- "Lv 12" and a gold Ready!, "2 more" or "Need cash"; the one in the slot lit. Nil: none left
local function copyTilesFor(card: Card, busy: boolean): { StationPick.CopyTile }?
	local copies = gradeable(card)
	if #copies == 0 then
		return nil
	end
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	local inSlot = if card.id == selectedCardId then chosenMain(card) else nil
	local cash = getCash()
	local tiles: { StationPick.CopyTile } = {}
	for _, candidate in copies do
		local upTo = CondenseRules.nextGrade(Beasts.GRADES, candidate.grade)
		local cost = if upTo then CondenseRules.gradeStepCost(GradingConfig, card.rarity, upTo) else nil
		local owned = CondenseRules.gradeHave(Beasts, byGrade, asMain(candidate))
		local cashOk = cost == nil or cash >= cost.cash
		local tagText, tagKind = CondenseRules.gradeRowTag(owned, if cost then cost.copies else 0, upTo, (getPlan(card, candidate)) ~= nil and cashOk, cashOk)
		table.insert(tiles, {
			key = candidate.key,
			grade = BeastRules.describeGrade(candidate.grade),
			gradeColor = CardDesign.GRADE_COLORS[candidate.grade] or CardDesign.GRADE_COLORS.C,
			foil = candidate.foil,
			label = CondenseRules.copyLabel({ beast = candidate.beast ~= nil, level = candidate.level, count = candidate.count }),
			stars = candidate.stars,
			maxStars = BeastRules.MAX_STARS,
			tag = if tagKind == "ready" and busy then nil else tagText,
			gold = tagKind == "ready",
			chosen = inSlot ~= nil and inSlot.key == candidate.key,
			draw = function(holder: Frame)
				makeFace(holder, card, candidate.foil, false, { level = candidate.level, stars = candidate.stars, grade = candidate.grade })
			end,
			onTap = function()
				putIn(card.id, candidate.key)
			end,
		})
	end
	return tiles
end

-- The cards as tiles: each one's tag from its default copy (a gold Ready!, "2 more", Need cash or Top grade; no Ready!
-- while the station counts a job down). A tap shows its copies (`back`: where their Back goes)
local function tilesFor(cards: { Card }, ready: { [string]: boolean }, busy: boolean, back: string): { StationPick.Tile }
	local tiles: { StationPick.Tile } = {}
	local cash = getCash()
	for _, card in cards do
		local main = defaultMain(getCandidates(card))
		local nextGrade = if main then CondenseRules.nextGrade(Beasts.GRADES, main.grade) else nil
		local step = if nextGrade then CondenseRules.gradeStepCost(GradingConfig, card.rarity, nextGrade) else nil
		local need = if step then step.copies else 0
		local have = if main then math.min(need, CondenseRules.gradeHave(Beasts, BinderController.GetGradedStacks()[card.id] or {}, asMain(main))) else 0
		local tagText, tagKind = CondenseRules.gradeRowTag(have, need, nextGrade, ready[card.id] == true, step == nil or cash >= step.cash)
		table.insert(tiles, {
			card = card,
			tag = if tagKind == "ready" and busy then nil else tagText,
			gold = tagKind == "ready",
			onTap = function()
				pickCardCopies(card.id, back)
			end,
		})
	end
	return tiles
end

render = function()
	if not panel.Visible then
		return
	end
	local all = getGradableCards()
	local ready: { [string]: boolean } = {}
	local readyCards: { Card } = {}
	local selected: Card? = nil
	for _, card in all do
		if isReady(card) then
			ready[card.id] = true
			table.insert(readyCards, card)
		end
		if card.id == selectedCardId then
			selected = card
		end
	end
	-- the card in the slot that left the list (now Grade S, or its copies gone) stays while it's still yours, or while
	-- the station holds it (its only copy inside a job comes back with its new grade); else the slot empties
	local busy = StationJobs.get("grading") ~= nil
	if not selected and selectedCardId then
		local card = Cards.ById[selectedCardId]
		if card and (busy or #getCandidates(card) > 0) then
			selected = card
		else
			selectedCardId = nil
		end
	end
	window.setTabs(tab, if busy then nil else #readyCards)
	if picking == "copies" then
		local card = if pickCard then Cards.ById[pickCard] else nil
		local copies = if card then copyTilesFor(card, busy) else nil
		if card and copies then
			local title, line = CondenseRules.pickSay(card.name, "grade")
			StationPick.show(window, "copies", title, line)
			StationPick.copyTiles(window, copies)
			return
		end
		picking = "cards" -- its copies are gone: back to the cards
	end
	if picking == "cards" then
		-- Ready cards first, keeping rarest-first order inside each group
		local sorted: { Card } = table.clone(readyCards)
		for _, card in all do
			if not ready[card.id] then
				table.insert(sorted, card)
			end
		end
		StationPick.show(window, "picking")
		StationPick.tiles(window, window.pickerGrid, tilesFor(sorted, ready, busy, "cards"), WORDS.PICK_NONE)
		return
	elseif tab == READY_TAB then
		StationPick.show(window, "ready")
		StationPick.tiles(window, window.readyGrid, tilesFor(readyCards, ready, busy, "close"), WORDS.READY_NONE)
		return
	end
	StationPick.show(window, "tab")
	local chosen = if selected then chosenMain(selected) else nil
	if not selected or not chosen then
		StationPick.slot(window, nil, openPicker)
		StationPick.emptyPane(window, 2)
		return
	end
	local card, main = selected :: Card, chosen :: Candidate
	StationPick.slot(window, function(holder: Frame)
		makeFace(holder, card, main.foil, false, { level = main.level, stars = main.stars, grade = main.grade })
	end, openPicker)
	renderPane(card, main)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- Opens the window for your own Grading Station, the slot empty
function GradingController.Open(part: BasePart)
	machine = part
	StationPick.layout(window)
	tab = UPGRADE_TAB
	picking = nil
	pickCard = nil
	selectedCardId = nil
	mainKey = nil
	inFlight = false
	panel.Visible = true
	render()
	refreshDone(true) -- a grade still waiting shows again each time the window opens, until it's taken out
end

-- Closes once the owner walks away or the machine is moved or sold
local function watchDistance()
	while true do
		task.wait(DISTANCE_CHECK_SECONDS)
		local part = machine
		if part and panel.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > GradingConfig.USE_DISTANCE then
				close()
			end
		end
	end
end

function GradingController.Start()
	local screenGui = UIController.GetScreenGui()
	local list: ScrollingFrame
	panel, list = UIKit.panel(screenGui, "GradingStation", "🏅 Grading Station", StationLook.GRADING.band)
	JobPanel.attach(panel, "grading") -- a job inside: its card over the actions (spec 2026-11-12-timed-upgrades-revive-design)
	-- a finished grade's reveal: over everything in the window (above the job veil), until Take it out
	refreshDone = DoneReveal.attach(panel, { attribute = "GradingDone", station = "grading", seen = Remotes.GradingSeen, kind = "grade", heading = GradingConfig.DONE_HEADING })
	palette = UIKit.colorsFor(panel)
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	window = StationPick.build(panel, list, StationLook.GRADING, WORDS, function(value: string)
		if tab ~= value then
			tab = value
			render()
		end
	end, function()
		-- Back: from a card's copies to the cards (or out, after the Ready tab); from the cards out
		picking = if picking == "copies" and copiesBack == "cards" then "cards" else nil
		render()
	end, nil)

	-- a job starting or ending: the Ready tags follow
	StationJobs.onChanged(function()
		render()
	end)
	-- Seals come and go with the item inventory
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		local count = if typeof(items) == "table" then items.gradingSeal else nil
		sealCount = if typeof(count) == "number" then count else 0
		if sealCount == 0 then
			useSeals = false
		end
		local gold = if typeof(items) == "table" then items.goldSeal else nil
		goldCount = if typeof(gold) == "number" then gold else 0
		if goldCount == 0 then
			useGold = false
		end
		if panel.Visible then
			render()
		end
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the seal count, whatever order the controllers start in
	-- Grading changes the binder (and the cash): redraw
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(function() -- after BinderController has stored the new binder
			inFlight = false
			render()
		end)
	end)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if panel.Visible then
			render()
		end
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return GradingController
