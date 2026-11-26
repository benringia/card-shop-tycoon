--!strict
-- Card Condenser window, the put-a-card-in shape since 2026-11-26 (owner: "remove the "ALL" tabs and "Need Copies tap".
-- The first tab is now "Condense" or something where the players put the card they want to condense. the condenser
-- then autofills the extra cards(weakest)"; the mockups of artifact 72BD8xZJT75xL5ityfY621; Util/StationPick builds the
-- shape, Config/Condenser WINDOW its words). Tabs: Condense and Ready (a gold count). Condense: a slot on the left ("Put
-- a card in"); a tap opens the card picker over the window (your cards with extra copies as tiles, Ready ones first),
-- and the card picked sits in the slot with Change card. On the right its picture recipe (since 2026-11-20, owner: "a
-- kid wouldnt understand this"; words and spots in Util/CondenseRules): one sentence ("Squish 4 extra Reefray into this
-- one. It gets a star!"), "Filled in for you: your 4 weakest extras" (the copies the server would take, never one
-- better than the card), the copies as little cards, an arrow, the card with its stars (the new one beating), "+40
-- Power" and "Pick other copies" (which copy gets the star: Recipe.copyPicker, the best grade first), and the big "Add a
-- star!" pinned at the box's bottom with how long it takes. Star Shards are tapped into empty spots (and out again).
-- Ready: the cards that can take a star now; a tap puts one in. On Add a star the copies fly into the card. Condense
-- asks the server, which re-checks everything; the binder sync redraws the window. Opened from your own Condenser's
-- prompt with the slot empty; closes when you walk away. A finished star waits here (the player's CondenserDone
-- attribute): opening the window shows the card with its new star popping in and Take it out.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local CondenserConfig = require(Config:WaitForChild("Condenser"))
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
local Recipe = require(ClientUtil:WaitForChild("Recipe"))
local StationJobs = require(ClientUtil:WaitForChild("StationJobs"))
local StationPick = require(ClientUtil:WaitForChild("StationPick"))
local DoneReveal = require(ClientUtil:WaitForChild("DoneReveal"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One copy that can be the main card: a levelled card, or a stack of plain copies (one grade, foil or not)
type Candidate = { key: string, beast: Beast?, foil: boolean, grade: string, level: number, stars: number, count: number, power: number }

local WORDS = CondenserConfig.WINDOW
local CONDENSE_TAB, READY_TAB = WORDS.TABS[1], WORDS.TABS[2]
local PANEL_MAX_SIZE = Vector2.new(820, 540)
local DETAIL_FACE_SIZE = Vector2.new(96, 137)
local DISTANCE_CHECK_SECONDS = 0.5
local EDGE = 12 -- px either side of the box's pieces: room for their hover grow, so nothing is cut off
local STAR_SIZE = 20
local RECIPE = Recipe.LOOK -- the recipe's spots, arrow and button (Util/Recipe, shared with the other stations)
local CAPTION = 30 -- a small line under the recipe (the better copies kept safe, what Star Shards do): two lines' room
local OTHER_HIT = 48 -- Pick other copies: a finger-sized tap round its small chip
local ROW_TALL = 40 -- a computer's row under the recipe (+Power, Pick other copies), its chip's tap reaching past it
-- A phone (owner 2026-11-21: on a 705 x 338 phone the window was 241 px tall): the window takes nearly the whole screen,
-- the recipe is smaller and what goes with it sits in a column beside it
local PHONE_FACE = Vector2.new(66, 94)
local PHONE_LEFT = 0.58 -- the recipe's share of the box's width on a phone
local PHONE_UNDER = 20 -- a phone's row under the recipe (the card's stars)

local player = Players.LocalPlayer

local CondenserController = {}

local panel: Frame
local window: StationPick.Window
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local machine: BasePart? = nil
local tab = CONDENSE_TAB
local picking = false -- the card picker shows over the window
local selectedCardId: string? = nil -- the card in the slot
local mainKey: string? = nil -- chosen main copy (Candidate.key); nil = the default choice
local choosingMain = false -- Pick other copies: the copies show in place of the recipe
local inFlight = false -- a Condense request is waiting for the server; the button stays locked
local useShards = false -- Star Shards fill missing duplicates (up to half a star's cost)
local shardCount = 0 -- from ItemsChanged
local inFlightToken = 0
-- A plain main being condensed: the levelled card it becomes is selected once it arrives
local awaitingNewCard: { before: { [string]: boolean }, cardId: string, foil: boolean, grade: string }? = nil

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

-- Every copy of this card that could be the main card, strongest first
local function getCandidates(card: Card): { Candidate }
	local candidates: { Candidate } = {}
	local working = BinderController.GetWorking()
	for id, beast in BinderController.GetBeasts() do
		if beast.cardId == card.id and not working[id] then -- working cards can't be condensed
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

local function getPlan(card: Card, main: Candidate): ({ CondenseRules.Take }?, string?, number)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	local shards = if useShards then shardCount else nil
	return CondenseRules.plan(Beasts, byGrade, asMain(main), shards)
end

-- Whether the default main copy of this card can take a star right now (Star Shards count only while they're in)
local function isReady(card: Card): boolean
	local main = getCandidates(card)[1]
	return main ~= nil and (getPlan(card, main)) ~= nil
end

-- Cards you're raising (any levelled or starred copy, even with no duplicates yet, so you can see what the next star
-- needs) and cards with two or more plain copies. Rarest first.
local function getCondensableCards(): { Card }
	local result: { Card } = {}
	for _, card in Cards.RarestFirst do
		local plain, levelled = 0, 0
		for _, candidate in getCandidates(card) do
			if candidate.beast then
				levelled += 1
			else
				plain += candidate.count
			end
		end
		if plain >= 2 or levelled > 0 then
			table.insert(result, card)
		end
	end
	return result
end

-- The copy in the slot: the one picked with Pick other copies, else the default (strongest); a plain main just
-- condensed follows the levelled card it became
local function chosenMain(card: Card): (Candidate?, { Candidate })
	local candidates = getCandidates(card)
	local waiting = awaitingNewCard
	if waiting and waiting.cardId == card.id then
		local newId = CondenseRules.findNewCard(waiting.before, BinderController.GetBeasts(), card.id, waiting.foil, waiting.grade)
		if newId then
			mainKey = newId
			awaitingNewCard = nil
		end
	end
	for _, candidate in candidates do
		if candidate.key == mainKey then
			return candidate, candidates
		end
	end
	return candidates[1], candidates
end

local render: () -> ()

-- Right side ------------------------------------------------------------------------------------------------------

-- A row of stars `size` px each: the ones it has, the rest faint; `adding`: the next one shines and beats (the star
-- this adds)
local function starRow(parent: Instance, position: UDim2, stars: number, adding: boolean, size: number): Frame
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.fromOffset(BeastRules.MAX_STARS * (size + 3) - 3, size)
	row.Parent = parent
	for index = 1, BeastRules.MAX_STARS do
		local star = Icon.make(row, "Star", UDim2.fromOffset(size, size))
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromOffset((index - 1) * (size + 3) + size / 2, size / 2)
		Icon.set(star, "Star")
		local glyph = star:FindFirstChild("Glyph")
		local new = adding and index == stars + 1
		if glyph and glyph:IsA("ImageLabel") then
			glyph.ImageTransparency = if index <= stars or new then 0 else 0.8
		end
		if new then
			Recipe.beat(star)
		end
	end
	return row
end

-- One spot of the recipe: a copy going in (its card's picture, gold-edged for a foil), a Star Shard standing in (tap:
-- take the shards out), an empty spot that offers one (tap: use them), or an empty one
local function buildSpot(parent: Instance, kind: string, card: Card, take: CondenseRules.Take?, order: number): GuiObject
	return Recipe.spot(parent, if kind == "shard" then "item" else kind, {
		order = order,
		palette = palette,
		image = if kind == "copy" then CardFace.artImage(card) else nil,
		foil = take ~= nil and take.foil,
		icon = "Shard",
		onTap = function()
			useShards = kind == "offer"
			render()
		end,
	})
end

-- A small line of words (the better copies kept safe, what Star Shards do), centred in `wide` px from `x`
local function caption(name: string, text: string, x: number, y: number, wide: number, color: Color3)
	local line = UIKit.label(window.pane, text, Enum.Font.GothamBold, 13, color)
	line.Name = name
	line.Position = UDim2.fromOffset(x + EDGE, y)
	line.Size = UDim2.fromOffset(wide - 2 * EDGE, CAPTION)
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.TextYAlignment = Enum.TextYAlignment.Top
end

-- "Pick other copies": a small white chip in a finger-sized tap area
local function otherCopiesChip(parent: Instance, order: number)
	local hit = Instance.new("TextButton")
	hit.Name = "OtherCopies"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.LayoutOrder = order
	hit.Size = UDim2.fromOffset(150, OTHER_HIT)
	hit.Parent = parent
	local chip = UIKit.label(hit, WORDS.OTHER, Enum.Font.FredokaOne, 13, palette.inkSoft)
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.fromScale(0.5, 0.5)
	chip.Size = UDim2.new(1, 0, 0, 30)
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = palette.row
	chip.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.corner(chip, 16)
	UIKit.outline(chip, StationPick.rgb(StationLook.BOX), 2)
	hit.Activated:Connect(function()
		choosingMain = true
		render()
	end)
end

local function renderPane(card: Card, chosen: Candidate, candidates: { Candidate })
	local pane = window.pane
	StationPick.clear(pane)
	StationPick.fullPane(window, choosingMain) -- the copy picker takes the whole box (its own Back, no big button)
	local phone = UIKit.isShort()
	local face = if phone then PHONE_FACE else DETAIL_FACE_SIZE
	local paneWide = StationPick.width(window, pane)
	if paneWide < 120 then
		paneWide = if phone then 320 else 480 -- not laid out yet
	end

	-- What goes in: the plan's copies and shards when the star can be added, else the copies there are (and, with the
	-- shards in, as many as may stand in)
	local byGrade = BinderController.GetGradedStacks()[card.id] or {}
	local takes, _, shardsUsed = getPlan(card, chosen)
	local atMax = chosen.stars >= BeastRules.MAX_STARS
	local need = if atMax then 0 else BeastRules.getCondenseCost(chosen.stars) or 0
	local have = math.min(need, CondenseRules.countDuplicates(byGrade, asMain(chosen), Beasts))
	local share = Beasts.MAX_SHARD_SHARE or 0
	local shardsIn = if takes then shardsUsed elseif useShards then math.max(0, math.min(shardCount, math.floor(need * share), need - have)) else 0
	local copiesIn = if takes then need - shardsUsed else have
	local offers = CondenseRules.shardOffers(need, have, shardCount, share, useShards)
	local missing = if takes or atMax then 0 else need - copiesIn - shardsIn
	local could = not useShards and takes == nil and not atMax and (CondenseRules.plan(Beasts, byGrade, asMain(chosen), shardCount)) ~= nil
	local nextStars = math.min(chosen.stars + 1, BeastRules.MAX_STARS)
	-- a phone: the recipe on the left of the box, what goes with it in a column on the right
	local leftWide = if phone and not choosingMain then math.floor(paneWide * PHONE_LEFT) else paneWide

	-- one sentence: what will happen
	local pickSay, pickSub = CondenseRules.pickSay(card.name, "star")
	local sentence = if choosingMain then pickSay else CondenseRules.say({ name = card.name, copies = copiesIn, shards = shardsIn, missing = missing, max = atMax, maxStars = BeastRules.MAX_STARS })
	-- (one line or two: the recipe moves up under a short one, so the whole box fits over the button; a phone's short
	-- box puts it at the top of the side column and the recipe at the very top)
	local sideSay = phone and not choosingMain
	local saySize = if phone then 13 else 19
	local say = UIKit.label(pane, sentence, Enum.Font.FredokaOne, saySize, palette.ink)
	say.Name = "Say"
	say.TextWrapped = true
	say.TextXAlignment = Enum.TextXAlignment.Center
	local y = 6
	if not sideSay then
		local sayTall = math.clamp(StationPick.textTall(sentence, saySize, Enum.Font.FredokaOne, leftWide - 2 * EDGE) + 4, if phone then 20 else 26, if phone then 40 else 52)
		say.Position = UDim2.fromOffset(EDGE, 8)
		say.Size = UDim2.fromOffset(leftWide - 2 * EDGE, sayTall)
		y = sayTall + 14
	end
	local under = if phone then PHONE_UNDER else RECIPE.under

	-- Pick other copies: every copy that could get the star as a picture, in place of the recipe
	if choosingMain then
		local tiles: { Recipe.CopyTile } = {}
		for _, candidate in candidates do
			local full = candidate.stars >= BeastRules.MAX_STARS
			local cost = if full then 0 else BeastRules.getCondenseCost(candidate.stars) or 0
			local tagText, tagKind = CondenseRules.rowTag(CondenseRules.countDuplicates(byGrade, asMain(candidate), Beasts), cost, (getPlan(card, candidate)) ~= nil)
			table.insert(tiles, {
				key = candidate.key,
				grade = BeastRules.describeGrade(candidate.grade),
				gradeColor = CardDesign.GRADE_COLORS[candidate.grade] or CardDesign.GRADE_COLORS.C,
				foil = candidate.foil,
				label = CondenseRules.copyLabel({ beast = candidate.beast ~= nil, level = candidate.level, count = candidate.count }),
				stars = candidate.stars,
				tag = tagText,
				gold = tagKind == "ready",
				chosen = candidate.key == chosen.key,
				draw = function(holder: Frame)
					makeFace(holder, card, candidate.foil, false, { level = candidate.level, stars = candidate.stars, grade = candidate.grade })
				end,
			})
		end
		Recipe.copyPicker(pane, {
			panel = panel,
			y = y,
			edge = EDGE,
			face = PHONE_FACE,
			maxStars = BeastRules.MAX_STARS,
			palette = palette,
			sub = pickSub,
			tiles = tiles,
			columnsFor = CondenseRules.pickColumns,
			onPick = function(key: string)
				mainKey = key
				choosingMain = false
				render()
			end,
			onBack = function()
				choosingMain = false
				render()
			end,
		})
		return
	end

	-- "Filled in for you: your 4 weakest extras" (a computer's over the recipe; a phone's in the side column)
	local fill = CondenseRules.fillChip(copiesIn)
	local filled = StationLook.FILLED
	local function fillChip(parent: Instance, order: number?): TextLabel?
		if not fill then
			return nil
		end
		local chip = UIKit.pill(parent, fill, StationPick.rgb(filled.fill), StationPick.rgb(filled.ink))
		chip.Name = "Filled"
		chip.LayoutOrder = order or 0
		chip.TextSize = if phone then 11 else 13
		return chip
	end
	if not phone then
		local chip = fillChip(pane)
		if chip then
			chip.AnchorPoint = Vector2.new(0.5, 0)
			chip.Position = UDim2.new(0, leftWide / 2, 0, y)
			y += 32
		end
	end

	-- The recipe: the spots, an arrow, the card that keeps the star (alone once it has every star). The card is as big
	-- as the box has room for over the button (a short window's smaller)
	local faceTall = math.clamp(StationPick.height(window, pane) - y - under - 4, if phone then 56 else 96, face.Y)
	face = Vector2.new(math.floor(faceTall * face.X / face.Y), faceTall)
	local slotsWide = math.clamp(leftWide - 2 * EDGE - RECIPE.arrow - face.X - 8, if phone then 90 else 110, 300)
	local wide = if atMax then face.X else slotsWide + RECIPE.arrow + face.X
	local recipe = Instance.new("Frame")
	recipe.Name = "Recipe"
	recipe.BackgroundTransparency = 1
	recipe.AnchorPoint = Vector2.new(0.5, 0)
	recipe.Position = UDim2.fromOffset(leftWide / 2, y)
	recipe.Size = UDim2.fromOffset(wide, face.Y + under)
	recipe.Parent = pane
	local faceHolder = Instance.new("Frame")
	faceHolder.Name = "Keeps"
	faceHolder.AnchorPoint = Vector2.new(1, 0)
	faceHolder.Position = UDim2.fromScale(1, 0)
	faceHolder.Size = UDim2.fromOffset(face.X, face.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = recipe
	makeFace(faceHolder, card, chosen.foil, false, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })
	local starSize = if phone then 12 else STAR_SIZE
	local stars = starRow(recipe, UDim2.new(), chosen.stars, not atMax, starSize)
	stars.AnchorPoint = Vector2.new(0.5, 0)
	stars.Position = UDim2.new(1, -face.X / 2, 0, face.Y + (if phone then 4 else 6))

	local spots: { GuiObject } = {}
	if not atMax then
		local grid = Recipe.grid(recipe, need, CondenseRules.slotColumns(need), Vector2.new(slotsWide, face.Y), StationLook.RECIPE_SPOT_TALL)
		-- the copies going in, one by one, in the order they're used
		local copies: { CondenseRules.Take } = {}
		for _, take in takes or CondenseRules.pick(Beasts.GRADES, byGrade, asMain(chosen), copiesIn) do
			for _ = 1, take.count do
				table.insert(copies, take)
			end
		end
		for index, kind in CondenseRules.slots(need, copiesIn, shardsIn, offers) do
			local spot = buildSpot(grid, kind, card, copies[index], index)
			if kind == "copy" or kind == "shard" then
				table.insert(spots, spot)
			end
		end
		Recipe.arrow(recipe, slotsWide + RECIPE.arrow / 2, face.Y / 2)
	end
	y += face.Y + under + 6

	-- What goes with it: how much stronger it gets and Pick other copies (a computer's under the spots, beside the
	-- card's stars; a phone's in the side column under the sentence and the fill chip; with every star, under the card)
	local side = Instance.new("Frame")
	side.Name = "Extras"
	side.BackgroundTransparency = 1
	local sideLayout = Instance.new("UIListLayout")
	sideLayout.FillDirection = if phone then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sideLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	sideLayout.Padding = UDim.new(0, if phone then 4 else 10)
	sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sideLayout.Parent = side
	if phone then
		sideLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		side.AutomaticSize = Enum.AutomaticSize.Y
		side.Position = UDim2.fromOffset(leftWide, 6)
		side.Size = UDim2.fromOffset(paneWide - leftWide - 4, 0)
		side.Parent = pane
		say.Parent = side
		say.LayoutOrder = 0
		say.AutomaticSize = Enum.AutomaticSize.Y
		say.Size = UDim2.new(1, -8, 0, 0)
		local chip = fillChip(side, 1)
		if chip then
			chip.TextWrapped = true
			chip.AutomaticSize = Enum.AutomaticSize.Y
			chip.Size = UDim2.new(1, -8, 0, 0)
		end
	elseif atMax then
		side.Position = UDim2.fromOffset(0, y)
		side.Size = UDim2.new(1, 0, 0, ROW_TALL)
		side.Parent = pane
		y += ROW_TALL
	else
		side.Position = UDim2.fromOffset(0, face.Y + 2)
		side.Size = UDim2.fromOffset(slotsWide, RECIPE.under)
		side.Parent = recipe
	end
	if not atMax then
		local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, nextStars, chosen.grade)
		local power = UIKit.pill(side, `+{math.max(0, powerAfter - chosen.power)} Power`, palette.good, Color3.new(1, 1, 1))
		power.Name = "Power"
		power.LayoutOrder = 2
	end
	if #candidates > 1 then
		otherCopiesChip(side, 3)
	end
	-- small lines under it all (a phone's at the end of the side column)
	local captionY = y
	local function addCaption(name: string, text: string, color: Color3, order: number)
		if phone then
			local line = UIKit.label(side, text, Enum.Font.GothamBold, 11, color)
			line.Name = name
			line.LayoutOrder = order
			line.AutomaticSize = Enum.AutomaticSize.Y
			line.Size = UDim2.new(1, -8, 0, 0)
			line.TextXAlignment = Enum.TextXAlignment.Center
			return
		end
		caption(name, text, 0, captionY, paneWide, color)
		captionY += CAPTION + 2
	end
	-- copies are missing while better ones sit unused: they are safe, said once
	local safeLine = if missing > 0 then CondenseRules.safeWords(CondenseRules.betterCopies(byGrade, asMain(chosen), Beasts)) else nil
	if safeLine then
		addCaption("Safe", safeLine, palette.inkSoft, 4)
	end
	-- what a tap on a spot does with Star Shards, when there is something to say
	local shardLine = CondenseRules.shardWords({ have = shardCount, on = useShards, used = shardsIn, offers = offers, could = could, missing = missing, max = atMax })
	if shardLine then
		addCaption("Shards", shardLine, if could then palette.good else palette.inkSoft, 5)
	end

	-- The big button pinned at the box's bottom: Add a star! and how long it takes, or what's missing
	local canCondense = takes ~= nil and not inFlight
	local seconds = EarlyRules.stationWait(UpgradeRules.seconds(Upgrades, "star", nextStars, card.rarity), tonumber(player:GetAttribute("Level")) or 1, Early)
	local buttonText, buttonSub = CondenseRules.buttonWords({ ready = takes ~= nil, inFlight = inFlight, max = atMax, missing = missing, seconds = seconds })
	local condense = StationPick.bigButton(window, buttonText, buttonSub, canCondense)
	condense.Name = "AddStar"
	condense.Activated:Connect(function()
		local part = machine
		if not canCondense or inFlight or not part then
			return
		end
		Recipe.flyIn(panel, spots, faceHolder)
		-- Locked until the binder sync arrives (or a timeout if the server refused), so a second tap can't send the
		-- same stale request
		inFlight = true
		inFlightToken += 1
		local token = inFlightToken
		task.delay(CondenserConfig.IN_FLIGHT_TIMEOUT, function()
			if token == inFlightToken and inFlight then
				inFlight = false
				render()
			end
		end)
		local beast = chosen.beast
		if beast then
			Remotes.Condense:FireServer(part:GetAttribute("ShelfUid"), card.id, beast.id, nil, nil, useShards)
		else
			local before: { [string]: boolean } = {}
			for id in BinderController.GetBeasts() do
				before[id] = true
			end
			awaitingNewCard = { before = before, cardId = card.id, foil = chosen.foil, grade = chosen.grade }
			Remotes.Condense:FireServer(part:GetAttribute("ShelfUid"), card.id, nil, chosen.foil, chosen.grade, useShards)
		end
		render()
	end)
end

-- The slot and the picker ---------------------------------------------------------------------------------------------

-- A card goes in the slot (from the picker or the Ready tab): the Condense tab shows it with its recipe
local function putIn(cardId: string)
	if selectedCardId ~= cardId then
		mainKey = nil
		choosingMain = false
		awaitingNewCard = nil
		useShards = false
	end
	selectedCardId = cardId
	picking = false
	tab = CONDENSE_TAB
	render()
end

local function openPicker()
	picking = true
	render()
end

-- The cards as tiles: each one's tag from its default copy (a gold Ready!, "3 more" or All stars; no Ready! while the
-- machine counts a job down: owner 2026-11-20, "it says Ready when it's still counting down")
local function tilesFor(cards: { Card }, ready: { [string]: boolean }, busy: boolean): { StationPick.Tile }
	local tiles: { StationPick.Tile } = {}
	for _, card in cards do
		local strongest = getCandidates(card)[1]
		local need = if strongest then BeastRules.getCondenseCost(strongest.stars) or 0 else 0
		local have = if strongest then CondenseRules.countDuplicates(BinderController.GetGradedStacks()[card.id] or {}, asMain(strongest), Beasts) else 0
		local tagText, tagKind = CondenseRules.rowTag(have, need, ready[card.id] == true)
		table.insert(tiles, {
			card = card,
			tag = if tagKind == "ready" and busy then nil else tagText,
			gold = tagKind == "ready",
			onTap = function()
				putIn(card.id)
			end,
		})
	end
	return tiles
end

render = function()
	if not panel.Visible then
		return
	end
	local all = getCondensableCards()
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
	local busy = StationJobs.get("condenser") ~= nil
	-- the card in the slot that left the list stays while you still have a copy, or while the machine holds it (its
	-- only copy inside a job comes back with its new star); else the slot empties
	if not selected and selectedCardId then
		local card = Cards.ById[selectedCardId]
		if card and (busy or #getCandidates(card) > 0) then
			selected = card
		else
			selectedCardId = nil
		end
	end
	window.setTabs(tab, if busy then nil else #readyCards)
	if picking then
		-- Ready cards first, keeping rarest-first order inside each group
		local sorted: { Card } = table.clone(readyCards)
		for _, card in all do
			if not ready[card.id] then
				table.insert(sorted, card)
			end
		end
		StationPick.show(window, "picking")
		StationPick.tiles(window, window.pickerGrid, tilesFor(sorted, ready, busy), WORDS.PICK_NONE)
		return
	elseif tab == READY_TAB then
		StationPick.show(window, "ready")
		StationPick.tiles(window, window.readyGrid, tilesFor(readyCards, ready, busy), WORDS.READY_NONE)
		return
	end
	StationPick.show(window, "tab")
	if not selected then
		StationPick.slot(window, nil, openPicker)
		StationPick.emptyPane(window, 4)
		return
	end
	local card = selected :: Card
	local chosen, candidates = chosenMain(card)
	if not chosen then
		StationPick.slot(window, nil, openPicker)
		StationPick.emptyPane(window, 4)
		return
	end
	local main = chosen :: Candidate
	StationPick.slot(window, function(holder: Frame)
		makeFace(holder, card, main.foil, false, { level = main.level, stars = main.stars, grade = main.grade })
	end, openPicker)
	renderPane(card, main, candidates)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- A finished star waiting in the Condenser: its reveal over the window (Util/DoneReveal), set up in Start
local refreshDone: (opened: boolean?) -> () = function() end

-- Opens the window for your own Condenser, the slot empty
function CondenserController.Open(part: BasePart)
	machine = part
	StationPick.layout(window)
	tab = CONDENSE_TAB
	picking = false
	selectedCardId = nil
	mainKey = nil
	choosingMain = false
	awaitingNewCard = nil
	inFlight = false
	panel.Visible = true
	render()
	refreshDone(true) -- a star still waiting shows again each time the window opens, until it's taken out
end

-- Closes once the owner walks away or the machine is moved or sold
local function watchDistance()
	while true do
		task.wait(DISTANCE_CHECK_SECONDS)
		local part = machine
		if part and panel.Visible then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not part:IsDescendantOf(workspace) or not root or (root.Position - part.Position).Magnitude > CondenserConfig.USE_DISTANCE then
				close()
			end
		end
	end
end

function CondenserController.Start()
	local screenGui = UIController.GetScreenGui()
	local list: ScrollingFrame
	panel, list = UIKit.panel(screenGui, "Condenser", "Card Condenser", StationLook.CONDENSER.band)
	JobPanel.attach(panel, "condenser") -- a job inside: its card over the actions (spec 2026-11-12-timed-upgrades-revive-design)
	palette = UIKit.colorsFor(panel)
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	local icon = Icon.header(panel, "Condenser", UIKit.HEADER_HEIGHT)
	window = StationPick.build(panel, list, StationLook.CONDENSER, WORDS, function(value: string)
		if tab ~= value then
			tab = value
			choosingMain = false
			render()
		end
	end, function()
		picking = false
		render()
	end, icon)

	-- a job starting or ending: the Ready tags and a waiting star follow
	StationJobs.onChanged(function()
		render()
		refreshDone()
	end)
	-- A finished star's reveal: over everything in the window (above the job veil), until Take it out
	refreshDone = DoneReveal.attach(panel, { attribute = "CondenserDone", station = "condenser", seen = Remotes.CondenserSeen, kind = "star", heading = CondenserConfig.DONE_HEADING })

	-- Condensing changes the binder; redraw with the new counts and stars
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		local count = if typeof(items) == "table" then items.starShard else nil
		shardCount = if typeof(count) == "number" then count else 0
		if shardCount == 0 then
			useShards = false
		end
		if panel.Visible then
			render()
		end
	end)
	Remotes.RequestItems:FireServer() -- our own copy of the shard count, whatever order the controllers start in
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(function() -- after BinderController has stored the new binder
			inFlight = false
			render()
		end)
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			machine = nil
		end
	end)
	task.spawn(watchDistance)
end

return CondenserController
