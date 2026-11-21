--!strict
-- Card Condenser panel: two panes (spec 2026-11-04-round4-design section 3): a toolbar (search and All / Ready / Need
-- copies), the cards you can condense on the left as slim rows, the chosen card's recipe on the right.
-- A picture recipe since 2026-11-20 (owner: "make this window easier to understand and more immersive. a kid wouldnt
-- understand this"; pick A of artifact R2UZgNndUJZ4pENFTrc6T8; words and spots in Util/CondenseRules): one sentence
-- ("Squish 4 extra Reefray into this one. It gets a star!"), the copies that go in as little cards, an arrow, the
-- card that keeps the star with its stars under it (the new one beating), "+40 Power", and one big "Add a star!"
-- with how long it takes. No Value, no grade talk. Star Shards are tapped into empty spots (and tapped out again).
-- "Keep a different copy" is a small link. A row shows its stars and a gold Ready!, "3 more" with a bar, or All
-- stars. On Add a star the copies fly into the card. Condense asks the server, which re-checks everything; the
-- binder sync redraws the panel. Opened from your own Condenser's prompt; closes when you walk away. A finished star
-- waits here (the player's CondenserDone attribute): opening the window shows the card with its new star popping in
-- and Take it out. The list keeps its scroll through a redraw.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Early = require(Config:WaitForChild("Early"))
local EarlyRules = require(Shared:WaitForChild("Util"):WaitForChild("EarlyRules"))
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local CondenserConfig = require(Config:WaitForChild("Condenser"))
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
local DoneReveal = require(ClientUtil:WaitForChild("DoneReveal"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type Card = typeof(Cards.List[1])
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One copy that can be the main card: a levelled card, or a stack of plain copies (one grade, foil or not)
type Candidate = { key: string, beast: Beast?, foil: boolean, grade: string, level: number, stars: number, count: number, power: number }

local PANEL_MAX_SIZE = Vector2.new(820, 540)
local LIST_WIDTH_SCALE = 0.5
local ROW_HEIGHT = 66
local MAIN_ROW_HEIGHT = 48 -- tap target minimum
local THUMBNAIL_SIZE = Vector2.new(40, 56)
local DETAIL_FACE_SIZE = Vector2.new(96, 137)
local DISTANCE_CHECK_SECONDS = 0.5
local ALL_FILTER, READY_FILTER, RAISING_FILTER = "All", "Ready", "Need copies"
local TOOLBAR_TOP = UIKit.HEADER_HEIGHT + 8
local SEARCH_WIDTH = 200
local SEARCH_HEIGHT = 40
local LIST_TOP = TOOLBAR_TOP + BabyColors.SEGMENTED.hit + 8
local EDGE = 12 -- px either side of the pane's buttons: room for their hover grow, so nothing is cut off
local STAR_SIZE = 20
local ROW_STAR = 13 -- px: a list row's little stars
local BAR_HEIGHT = 6
local RECIPE = Recipe.LOOK -- the recipe on the right: its spots, arrow and button (Util/Recipe, shared with the other stations)
local CONDENSE_HEIGHT = RECIPE.button
-- A phone (owner 2026-11-21, the night's device check: on a 705 x 338 phone the window was 241 px tall with 105 for
-- its list and its recipe, the big button far under the fold): the window takes nearly the whole screen, the rows over
-- the list go, the recipe is smaller and the big button sits pinned under the pane (`actionBar`), as in the Forge
local PHONE_FACE = Vector2.new(66, 94)
local PHONE_SAY = 38 -- the sentence's room (two lines of smaller words)
local PHONE_TITLE_ROOM = 236 -- the header band: the title on the left, the filter switch, the close button
local PHONE_CLOSE_ROOM = 66

local player = Players.LocalPlayer

local CondenserController = {}

local panel: Frame
local palette: UIKit.Palette -- the cream window's colours (UIKit.colorsFor), set in Start
local readyBadge: TextLabel -- "2 ready" in the band
local list: ScrollingFrame
local pane: ScrollingFrame
local actionBar: Frame -- a phone: the big button, pinned under the pane
local search: TextBox
local switchHolder: Frame
local setFilter: (string) -> () = function() end
local machine: BasePart? = nil
local selectedCardId: string? = nil
local searchText = ""
local activeFilter = ALL_FILTER -- All, Ready (can take a star now) or Raising (in the list, not ready yet)
local mainKey: string? = nil -- chosen main copy (Candidate.key); nil = the default choice
local choosingMain = false -- Change: the copies to keep show in place of the buttons
local inFlight = false -- a Condense request is waiting for the server; the button stays locked
local useShards = false -- Star Shards fill missing duplicates (up to half a star's cost)
local listToTop = false -- the next render starts the list at its top (render)
local shardCount = 0 -- from ItemsChanged
local inFlightToken = 0
-- A plain main being condensed: the levelled card it becomes is selected once it arrives
local awaitingNewCard: { before: { [string]: boolean }, cardId: string, foil: boolean, grade: string }? = nil

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

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

local function addLabel(parent: GuiObject, text: string, position: UDim2, size: UDim2, font: Enum.Font, textSize: number, color: Color3): TextLabel
	local label = UIKit.label(parent, text, font, textSize, color)
	label.Position = position
	label.Size = size
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
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

-- Whether the default main copy of this card can take a star right now (Star Shards count only while the toggle is on)
local function isReady(card: Card): boolean
	local main = getCandidates(card)[1]
	return main ~= nil and (getPlan(card, main)) ~= nil
end

-- Search by name or number, then the switch: All, Ready (can take a star now) or Raising (the rest)
local function passesFilter(card: Card): boolean
	if searchText ~= "" then
		local query = string.lower(searchText)
		local number = tonumber((string.gsub(query, "#", "")))
		if not string.find(string.lower(card.name), query, 1, true) and number ~= card.number then
			return false
		end
	end
	if activeFilter == READY_FILTER then
		return isReady(card)
	elseif activeFilter == RAISING_FILTER then
		-- still short of copies: not a card that already has every star
		local main = getCandidates(card)[1]
		return not isReady(card) and (main == nil or main.stars < BeastRules.MAX_STARS)
	end
	return true
end

-- Cards you're raising (any levelled or starred copy, even with no duplicates yet, so you can see what
-- the next star needs) and cards with two or more plain copies. Rarest first.
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

local render: () -> ()

-- Right side ------------------------------------------------------------------------------------------

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

-- Keep a different copy: every copy that could keep the star as a row (its grade, level and stars, how many plain
-- ones, its Power), the chosen one ringed; a tap keeps that one. Returns the y under the last row
local function mainChoices(candidates: { Candidate }, chosen: Candidate, y: number): number
	for _, candidate in candidates do
		local row = Instance.new("TextButton")
		row.Name = "Copy_" .. candidate.key
		row.AnchorPoint = Vector2.new(0.5, 0) -- grows evenly under the mouse (the grow follows the anchor)
		row.Position = UDim2.new(0.5, 0, 0, y)
		row.Size = UDim2.new(1, -2 * EDGE, 0, MAIN_ROW_HEIGHT)
		row.BackgroundColor3 = palette.row
		row.Text = ""
		row.Parent = pane
		UIKit.corner(row, 10)
		UIKit.outline(row, if candidate.key == chosen.key then UIKit.Colors.Accent else palette.rowEdge, 2)
		local title = `{if candidate.foil then "FOIL · " else ""}{BeastRules.describeGrade(candidate.grade)} · {BeastRules.describeGrowth(candidate.level, candidate.stars)}`
		if not candidate.beast then
			title ..= ` · x{candidate.count}`
		end
		addLabel(row, title, UDim2.fromOffset(10, 0), UDim2.new(1, -100, 1, 0), Enum.Font.GothamBold, 13, palette.ink)
		local power = addLabel(row, `Power {candidate.power}`, UDim2.new(1, -94, 0, 0), UDim2.new(0, 86, 1, 0), Enum.Font.GothamBold, 12, palette.power)
		power.TextXAlignment = Enum.TextXAlignment.Right
		row.Activated:Connect(function()
			mainKey = candidate.key
			choosingMain = false
			render()
		end)
		y += MAIN_ROW_HEIGHT + 6
	end
	return y
end

local function renderPane(card: Card?)
	clear(pane)
	clear(actionBar)
	local phone = UIKit.isShort()
	local face = if phone then PHONE_FACE else DETAIL_FACE_SIZE
	local sayTop = if phone then PHONE_SAY else RECIPE.top
	if not card then
		local hint = UIKit.label(pane, CondenserConfig.EXPLAIN .. " Pick a card on the left.", Enum.Font.GothamBold, 14, palette.inkSoft)
		hint.Position = UDim2.fromOffset(EDGE, 10)
		hint.Size = UDim2.new(1, -2 * EDGE, 0, 60)
		hint.TextWrapped = true
		return
	end
	local candidates = getCandidates(card)
	-- A plain main just became a levelled card: keep condensing that card
	local waiting = awaitingNewCard
	if waiting and waiting.cardId == card.id then
		local newId = CondenseRules.findNewCard(waiting.before, BinderController.GetBeasts(), card.id, waiting.foil, waiting.grade)
		if newId then
			mainKey = newId
			awaitingNewCard = nil
		end
	end
	local main: Candidate? = nil
	for _, candidate in candidates do
		if candidate.key == mainKey then
			main = candidate
		end
	end
	main = main or candidates[1]
	if not main then
		return
	end
	local chosen = main :: Candidate

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

	-- one sentence: what will happen
	local sentence = if choosingMain then "Which copy keeps the star? Tap it." else CondenseRules.say({ name = card.name, copies = copiesIn, shards = shardsIn, missing = missing, max = atMax, maxStars = BeastRules.MAX_STARS })
	local say = UIKit.label(pane, sentence, Enum.Font.FredokaOne, if phone then 13 else 16, palette.ink)
	say.Name = "Say"
	say.Position = UDim2.fromOffset(EDGE, 6)
	say.Size = UDim2.new(1, -2 * EDGE, 0, sayTop - 10)
	say.TextWrapped = true
	say.TextXAlignment = Enum.TextXAlignment.Center

	local y = sayTop
	-- Keep a different copy: the copies that could keep the star, in place of the recipe
	if choosingMain then
		y = mainChoices(candidates, chosen, y)
		local back = UIKit.button(pane, "Back", UIKit.Colors.Secondary)
		back.AnchorPoint = Vector2.new(0.5, 0)
		back.Position = UDim2.new(0.5, 0, 0, y + 4)
		back.Size = UDim2.fromOffset(160, 48)
		back.Activated:Connect(function()
			choosingMain = false
			render()
		end)
		return
	end

	-- The recipe: the spots, an arrow, the card that keeps the star (alone once it has every star)
	local wide = if atMax then face.X else RECIPE.slots.X + RECIPE.arrow + face.X
	local recipe = Instance.new("Frame")
	recipe.Name = "Recipe"
	recipe.BackgroundTransparency = 1
	recipe.AnchorPoint = Vector2.new(0.5, 0)
	recipe.Position = UDim2.new(0.5, 0, 0, y)
	recipe.Size = UDim2.fromOffset(wide, face.Y + RECIPE.under)
	recipe.Parent = pane
	local faceHolder = Instance.new("Frame")
	faceHolder.Name = "Keeps"
	faceHolder.AnchorPoint = Vector2.new(1, 0)
	faceHolder.Position = UDim2.fromScale(1, 0)
	faceHolder.Size = UDim2.fromOffset(face.X, face.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = recipe
	makeFace(faceHolder, card, chosen.foil, false, { level = chosen.level, stars = chosen.stars, grade = chosen.grade })
	local stars = starRow(recipe, UDim2.new(), chosen.stars, not atMax, STAR_SIZE)
	stars.AnchorPoint = Vector2.new(0.5, 0)
	stars.Position = UDim2.new(1, -face.X / 2, 0, face.Y + 8)

	local spots: { GuiObject } = {}
	if not atMax then
		local grid = Recipe.grid(recipe, need, CondenseRules.slotColumns(need), Vector2.new(RECIPE.slots.X, face.Y))
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
		Recipe.arrow(recipe, RECIPE.slots.X + RECIPE.arrow / 2, face.Y / 2)
		-- how much stronger it gets, under the spots
		local powerAfter = BeastRules.getPower(card, chosen.foil, chosen.level, nextStars, chosen.grade)
		local chip = UIKit.pill(recipe, `+{math.max(0, powerAfter - chosen.power)} Power`, palette.good, Color3.new(1, 1, 1))
		chip.Name = "Power"
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.fromOffset(RECIPE.slots.X / 2, face.Y + 6)
	end
	y += face.Y + RECIPE.under + 10

	-- The big button: Add a star! and how long it takes, or what's missing
	local canCondense = takes ~= nil and not inFlight
	local seconds = EarlyRules.stationWait(UpgradeRules.seconds(Upgrades, "star", nextStars, card.rarity), tonumber(player:GetAttribute("Level")) or 1, Early)
	local buttonText, buttonSub = CondenseRules.buttonWords({ ready = takes ~= nil, inFlight = inFlight, max = atMax, missing = missing, seconds = seconds })
	local condense = UIKit.button(if phone then actionBar else pane, buttonText, if canCondense then UIKit.Colors.Accent else UIKit.Colors.Locked)
	condense.Name = "AddStar"
	condense.AnchorPoint = Vector2.new(0.5, 0) -- grows evenly under the mouse, inside the pane's EDGE
	condense.Position = UDim2.new(0.5, 0, 0, if phone then 4 else y)
	condense.Size = UDim2.new(1, -2 * EDGE, 0, CONDENSE_HEIGHT)
	condense.AutoButtonColor = canCondense
	Recipe.words(condense, buttonText, buttonSub)
	condense.Activated:Connect(function()
		local part = machine
		if not canCondense or inFlight or not part then
			return
		end
		Recipe.flyIn(panel, spots, faceHolder)
		-- Locked until the binder sync arrives (or a timeout if the server refused), so a second tap
		-- can't send the same stale request
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
	if not phone then
		y += CONDENSE_HEIGHT + 8
	end

	-- what a tap on a spot does with Star Shards, when there is something to say
	local shardLine = CondenseRules.shardWords({ have = shardCount, on = useShards, used = shardsIn, offers = offers, could = could, missing = missing, max = atMax })
	if shardLine then
		local caption = UIKit.label(pane, shardLine, Enum.Font.GothamBold, 13, if could then palette.good else palette.inkSoft)
		caption.Name = "Shards"
		caption.Position = UDim2.fromOffset(EDGE, y)
		caption.Size = UDim2.new(1, -2 * EDGE, 0, 34)
		caption.TextWrapped = true
		caption.TextXAlignment = Enum.TextXAlignment.Center
		y += 38
	end

	-- for players who mind which copy keeps the star (its grade, its level): a small link
	if #candidates > 1 then
		local change = Instance.new("TextButton")
		change.Name = "Change"
		change.AnchorPoint = Vector2.new(0.5, 0)
		change.Position = UDim2.new(0.5, 0, 0, y)
		change.Size = UDim2.fromOffset(220, 44)
		change.BackgroundTransparency = 1
		change.Font = Enum.Font.GothamBold
		change.TextSize = 13
		change.RichText = true
		change.Text = "<u>Keep a different copy</u>"
		change.TextColor3 = palette.hint
		change.Parent = pane
		change.Activated:Connect(function()
			choosingMain = true
			render()
		end)
		y += 44
	end
	local bottom = Instance.new("Frame") -- keeps room under the last button for its hover grow
	bottom.BackgroundTransparency = 1
	bottom.Position = UDim2.fromOffset(0, y + EDGE)
	bottom.Size = UDim2.fromOffset(1, 1)
	bottom.Parent = pane
end

-- Left side -------------------------------------------------------------------------------------------

local function buildCardRow(card: Card, order: number)
	local candidates = getCandidates(card)
	local strongest = candidates[1]
	local ready = isReady(card)
	local need = if strongest then BeastRules.getCondenseCost(strongest.stars) or 0 else 0
	local have = if strongest then CondenseRules.countDuplicates(BinderController.GetGradedStacks()[card.id] or {}, asMain(strongest), Beasts) else 0
	local tagText, tagKind, share = CondenseRules.rowTag(have, need, ready)
	local row = Instance.new("TextButton")
	row.Name = "Card_" .. card.id
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = palette.row
	row.Text = ""
	row.Parent = list
	UIKit.corner(row, 12)
	local selected = card.id == selectedCardId
	UIKit.outline(row, if selected then UIKit.Colors.Accent else palette.rowEdge, if selected then 3 else 2)
	local thumbnail = Instance.new("Frame")
	thumbnail.Position = UDim2.fromOffset(8, 5)
	thumbnail.Size = UDim2.fromOffset(THUMBNAIL_SIZE.X, THUMBNAIL_SIZE.Y)
	thumbnail.BackgroundTransparency = 1
	thumbnail.Parent = row
	makeFace(thumbnail, card, strongest ~= nil and strongest.foil, false)

	local textX = THUMBNAIL_SIZE.X + 18
	-- no Ready tag while the machine counts a job down (owner 2026-11-20: "it says Ready when it's still counting down")
	local tagged = tagKind ~= "ready" or StationJobs.get("condenser") == nil
	addLabel(row, card.name, UDim2.fromOffset(textX, 8), UDim2.new(1, -(textX + (if tagged then 84 else 10)), 0, 20), Enum.Font.FredokaOne, 16, palette.ink)
	-- its stars, and on the right a gold Ready!, how many more copies it needs, or All stars
	starRow(row, UDim2.fromOffset(textX, 31), if strongest then strongest.stars else 0, false, ROW_STAR)
	if tagged then
		local gold = tagKind == "ready"
		local tag = UIKit.pill(row, tagText, if gold then UIKit.Colors.Accent else palette.track, if gold then UIKit.Colors.Ink else palette.inkSoft)
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -10, 0, 8)
		tag.TextSize = 12
	end
	-- a bar while copies are missing: how far along
	if tagKind == "wait" then
		local track = Instance.new("Frame")
		track.Name = "Copies"
		track.Position = UDim2.fromOffset(textX, 51)
		track.Size = UDim2.new(1, -(textX + 12), 0, BAR_HEIGHT)
		track.BackgroundColor3 = palette.track
		track.Parent = row
		UIKit.corner(track, BAR_HEIGHT / 2)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(share, 1)
		fill.BackgroundColor3 = palette.good
		fill.Parent = track
		UIKit.corner(fill, BAR_HEIGHT / 2)
	end

	row.Activated:Connect(function()
		if selectedCardId ~= card.id then
			selectedCardId = card.id
			mainKey = nil
			choosingMain = false
			awaitingNewCard = nil
		end
		render()
	end)
end

render = function()
	if not panel.Visible then
		return
	end
	-- The list stays where the player scrolled it (owner 2026-11-20: "clicking a card sends me back to the top of the
	-- window": every render rebuilds the rows, and an emptied list snaps to its top). `listToTop`: a new filter or
	-- search, or the window just opened, starts at the top
	local listAt = if listToTop then Vector2.zero else list.CanvasPosition
	listToTop = false
	clear(list)
	setFilter(activeFilter) -- the switch shows the current choice (UIKit.segmented leaves that to us)
	local all = getCondensableCards()
	local readyCount = 0
	local ready: { [string]: boolean } = {}
	for _, card in all do
		if isReady(card) then
			ready[card.id] = true
			readyCount += 1
		end
	end
	-- Ready cards first (keeping rarest-first order inside each group)
	local cards: { Card } = {}
	for _, card in all do
		-- the card on the pane stays, whatever the filter (the Star Shards switch changes which cards are ready)
		if CondenseRules.keepsRow(passesFilter(card), card.id == selectedCardId) then
			table.insert(cards, card)
		end
	end
	local position: { [string]: number } = {}
	for index, card in cards do
		position[card.id] = index
	end
	table.sort(cards, function(a, b)
		if (ready[a.id] == true) ~= (ready[b.id] == true) then
			return ready[a.id] == true
		end
		return position[a.id] < position[b.id]
	end)
	readyBadge.Text = `{readyCount} can get a star`
	-- (a phone's header band holds the filter switch: no badge there)
	readyBadge.Visible = not UIKit.isShort() and readyCount > 0 and StationJobs.get("condenser") == nil
	local selected: Card? = nil
	for _, card in cards do
		if card.id == selectedCardId then
			selected = card
		end
	end
	selected = selected or cards[1]
	selectedCardId = if selected then selected.id else nil
	for order, card in cards do
		buildCardRow(card, order)
	end
	list.CanvasPosition = listAt
	game:GetService("RunService").Heartbeat:Once(function() -- and once the rebuilt rows are laid out
		if list.Parent then
			list.CanvasPosition = listAt
		end
	end)
	if #cards == 0 then
		local filtering = searchText ~= "" or activeFilter ~= ALL_FILTER
		local message = if filtering then "No cards match." else "No duplicates yet. Rip more packs!"
		local empty = UIKit.label(list, message, Enum.Font.GothamBold, 15, palette.inkSoft)
		empty.Size = UDim2.new(1, -10, 0, 40)
	end
	renderPane(selected)
end

local function close()
	panel.Visible = false
	machine = nil
end

-- A finished star waiting in the Condenser: its reveal over the window (Util/DoneReveal), set up in Start
local refreshDone: (opened: boolean?) -> () = function() end

-- Opens the panel for your own Condenser
-- The window's pieces for this screen: a computer's rows over the list, or a phone's bigger window with the filter
-- switch up in the header band and the big button's bar under the pane
local function layout()
	local phone = UIKit.isShort()
	panel.Size = if phone then UDim2.fromScale(0.97, 0.96) else UDim2.fromScale(0.94, 0.86)
	local top = if phone then UIKit.HEADER_HEIGHT + 8 else LIST_TOP
	search.Visible = not phone
	if phone then
		switchHolder.Position = UDim2.fromOffset(PHONE_TITLE_ROOM, (UIKit.HEADER_HEIGHT - BabyColors.SEGMENTED.hit) / 2)
		switchHolder.Size = UDim2.new(1, -(PHONE_TITLE_ROOM + PHONE_CLOSE_ROOM), 0, BabyColors.SEGMENTED.hit)
	else
		switchHolder.Position = UDim2.fromOffset(16 + SEARCH_WIDTH + 10, TOOLBAR_TOP)
		switchHolder.Size = UDim2.new(1, -(16 + SEARCH_WIDTH + 10 + 16), 0, BabyColors.SEGMENTED.hit)
	end
	local bar = if phone then CONDENSE_HEIGHT + 12 else 0
	list.Position = UDim2.fromOffset(12, top)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(top + 12))
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, top)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(top + 12 + bar))
	actionBar.Visible = phone
	actionBar.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 1, -12)
	actionBar.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 0, bar)
end

function CondenserController.Open(part: BasePart)
	machine = part
	layout()
	selectedCardId = nil
	mainKey = nil
	choosingMain = false
	awaitingNewCard = nil
	inFlight = false
	listToTop = true
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
	panel, list = UIKit.panel(screenGui, "Condenser", "Card Condenser")
	JobPanel.attach(panel, "condenser") -- a job inside: its card over the actions (spec 2026-11-12-timed-upgrades-revive-design)
	palette = UIKit.colorsFor(panel)
	panel.Size = UDim2.fromScale(0.94, 0.86)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit.MaxSize = PANEL_MAX_SIZE
	end
	Icon.header(panel, "Condenser", UIKit.HEADER_HEIGHT)
	local header = panel:FindFirstChild("Header", true) :: Frame
	readyBadge = UIKit.label(header, "", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	readyBadge.AnchorPoint = Vector2.new(1, 0.5)
	readyBadge.Position = UDim2.new(1, -64, 0.5, 0) -- clear of the round close button
	readyBadge.Size = UDim2.fromOffset(190, 24)
	readyBadge.TextXAlignment = Enum.TextXAlignment.Right
	readyBadge.ZIndex = header.ZIndex + 2

	-- The toolbar: search by name or #number, then All / Ready / Raising
	search = Instance.new("TextBox")
	search.Name = "Search"
	search.Position = UDim2.fromOffset(16, TOOLBAR_TOP + (BabyColors.SEGMENTED.hit - SEARCH_HEIGHT) / 2)
	search.Size = UDim2.fromOffset(SEARCH_WIDTH, SEARCH_HEIGHT)
	search.BackgroundColor3 = palette.row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search name or #"
	search.Text = ""
	search.Font = Enum.Font.Gotham
	search.TextSize = 14
	search.TextColor3 = palette.ink
	search.PlaceholderColor3 = palette.inkSoft
	search.Parent = panel
	UIKit.corner(search, SEARCH_HEIGHT / 2)
	UIKit.outline(search, palette.rowEdge, 2)
	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, 14)
	searchPadding.PaddingRight = UDim.new(0, 14)
	searchPadding.Parent = search
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		selectedCardId = nil -- ...and so does a search
		listToTop = true
		render()
	end)
	switchHolder = Instance.new("Frame")
	switchHolder.Name = "Show"
	switchHolder.BackgroundTransparency = 1
	switchHolder.Position = UDim2.fromOffset(16 + SEARCH_WIDTH + 10, TOOLBAR_TOP)
	switchHolder.Size = UDim2.new(1, -(16 + SEARCH_WIDTH + 10 + 16), 0, BabyColors.SEGMENTED.hit)
	switchHolder.ZIndex = panel.ZIndex + 3 -- over the header band and its title on a phone
	switchHolder.Parent = panel
	local _, pick = UIKit.segmented(switchHolder, { ALL_FILTER, READY_FILTER, RAISING_FILTER }, function(value)
		activeFilter = value
		selectedCardId = nil -- a filter you chose shows its own cards (the pane's card only stays through the shards switch)
		listToTop = true
		render()
	end)
	setFilter = pick
	setFilter(activeFilter)

	list.Position = UDim2.fromOffset(12, LIST_TOP)
	list.Size = UDim2.new(LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))
	-- Room round the rows for the chosen row's ring and a row growing under the mouse (nothing cut off)
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, EDGE + 6) -- a row grows to the right (its anchor is top-left in the list)
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 6)
	listPadding.Parent = list

	pane = Instance.new("ScrollingFrame")
	pane.Name = "Details"
	pane.Position = UDim2.new(LIST_WIDTH_SCALE, 6, 0, LIST_TOP)
	pane.Size = UDim2.new(1 - LIST_WIDTH_SCALE, -18, 1, -(LIST_TOP + 12))
	pane.BackgroundColor3 = palette.slotEmpty -- a deeper cream; its rows are white
	pane.BackgroundTransparency = 0
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 4
	pane.CanvasSize = UDim2.new()
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.Parent = panel
	UIKit.corner(pane, 12)
	actionBar = Instance.new("Frame")
	actionBar.Name = "Action"
	actionBar.BackgroundTransparency = 1
	actionBar.AnchorPoint = Vector2.new(0, 1)
	actionBar.Visible = false
	actionBar.Parent = panel

	-- A finished star's reveal: over everything in the window (above the job veil), until Take it out
	-- a job starting or ending: the Ready tags and a waiting star follow
	StationJobs.onChanged(function()
		render()
		refreshDone()
	end)
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
