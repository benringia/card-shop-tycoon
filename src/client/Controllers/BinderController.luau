--!strict
-- Binder: a full-screen book per set (set tabs on its edge). Spread 1 is the set's cover and page 1; later
-- spreads are two pages of pockets, owned cards in colour with counts, missing ones as "?" slots. Turn pages
-- with the arrows or Q/E (A/D: first/last); Filters (F) narrow and sort the pages while the book shrinks aside.
-- Hovering a pocket with a mouse shows a tooltip.
-- Only the pockets on the open spread are drawn, so a big collection stays cheap.
-- Tap an owned card to see it large. Cards earn money only from a showcase, so the binder just
-- shows what you have; cards on display in your cases count towards completion.
-- The server sends the binder whenever it changes; displayed cards are read from your plot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local Items = require(Config:WaitForChild("Items"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Collection = require(Config:WaitForChild("Collection"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BinderSpreads = require(Shared:WaitForChild("Util"):WaitForChild("BinderSpreads"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local Bosses = require(Config:WaitForChild("Bosses"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))
local BossTints = require(ClientUtil:WaitForChild("BossTints"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local PocketLayout = require(ClientUtil:WaitForChild("PocketLayout"))
local UIController = require(Controllers:WaitForChild("UIController"))
local RarityGuideController = require(Controllers:WaitForChild("RarityGuideController"))
local CardDetailController = require(Controllers:WaitForChild("CardDetailController"))

type Card = typeof(Cards.List[1])
type Owned = { normal: number, foil: number }
type Stacks = { [string]: { [string]: Owned } } -- cardId -> grade -> counts
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One row in the card view: a stack of plain copies (one grade, foil or not) or a levelled card
type Entry = { key: string, power: number, value: number, beast: Beast?, grade: string, foil: boolean, count: number }

type Tile = {
	card: Card,
	button: TextButton,
	inner: Frame,
	stroke: UIStroke,
	countLabel: TextLabel,
	levelLabel: TextLabel, -- best grade and best levelled copy, e.g. "S · Lv 12"
}

-- A pocket is the card plus a chip row under it (copies owned, best grade and level)
local CARD_ASPECT = 0.7
local CHIP_ROW = 22 -- pixels
local SMALL_POCKET = 90 -- pixels wide: smaller pockets show only the copies chip
-- 3 x 3 pockets like a real binder; short screens get fewer, bigger pockets (3 a page at least, so the
-- card text stays readable)
local POCKET_OPTIONS: PocketLayout.Options = {
	aspect = 0.63, -- pocket width / height: a 0.7 card plus the chip row
	gap = 6,
	preferredColumns = 3,
	preferredRows = 3,
	minWidth = 90,
	maxColumns = 5,
	maxRows = 3,
	minPockets = 3,
}
local TOOLTIP_WIDTH = 260
local TOOLTIP_GAP = 8
local ALL_FILTER, OWNED_FILTER, MISSING_FILTER = "All", "Owned", "Missing"
local PAGE_KEYS = { [Enum.KeyCode.Q] = -1, [Enum.KeyCode.E] = 1 }
local BINDER_KEY = Enum.KeyCode.B
local BAG_KEY = Enum.KeyCode.I -- inventory: the binder's Bag tab
local BAG_PRIORITY_MARGIN = 100 -- above every built-in binding (the camera's I zoom included)
local VALUE_COLOR = Color3.fromRGB(120, 230, 120)
local COVER_TEXT = Color3.fromRGB(255, 250, 240)

local player = Players.LocalPlayer

local BinderController = {}

local graded: Stacks = {}
local collection: { [string]: Owned } = {} -- graded, summed per card
local beasts: { [string]: Beast } = {}
local working: { [string]: string } = {} -- beastId -> job, for cards working in the shop
local partied: { [string]: boolean } = {} -- beastId -> in the party
local hintToast: number? = nil -- toast from BinderController.Open, hidden once a card is tapped
local displayed: { [string]: Owned } = {}
local tiles: { Tile } = {}
local panel: Frame
local currentSet = Collection.SETS[1]
local book: Frame
local bookHolder: Frame
local bookScale: UIScale
local coverPage: Frame
local coverTitle: TextLabel
local coverProgress: TextLabel
local coverEmblem: TextLabel
local coverArt: ImageLabel
local coverFill: Frame
local coverValue: TextLabel
local setTabs: { [string]: TextButton } = {}
local progressName: TextLabel
local progressCount: TextLabel
local progressValue: TextLabel
local progressFill: Frame
local filtersPanel: Frame
local setFiltersOpen: (open: boolean) -> ()
local setInspecting: (on: boolean) -> ()
local renderBag: () -> ()
local buildCase: () -> ()
local buildSpine: () -> ()
local getSetArt: (set: string) -> string?
local rarityGuideButton: TextButton
local filterButton: TextButton
local showButtons: { [string]: TextButton } = {}
local sortButtons: { [string]: TextButton } = {}
local rarityChips: { [string]: TextButton } = {}
local rarityPicks: { [string]: boolean } = {} -- none picked = every rarity
local showFilter = ALL_FILTER -- All, Owned or Missing
local sortBy = "Set" -- Set (card number), Value, Copies or Rarity
local bagOverlay: Frame -- the Bag tab (built in buildBag); the card tooltip stays off while it shows
local cardsTab: TextButton -- the Cards / Bag tabs (built in buildBag)
local bagTab: TextButton
local pages: { Frame } = {} -- left and right page
local pageLabel: TextLabel
local spreadIndex = 1
local pocketsPerPage = POCKET_OPTIONS.preferredColumns * POCKET_OPTIONS.preferredRows
local pageGrids: { UIGridLayout } = {}
local progressCard: Frame
local backdropGui: ScreenGui -- the dimmed world behind the binder (off while a card is inspected)
local bookGui: ScreenGui -- the book's own full-screen layer, so it can rise into Roblox's top bar strip
local arrowLanes: { Frame } = {}
-- The page turn (flipTo): a sheet lying over the turning page that carries its cards as it folds
local flipSheet: Frame
local flipContent: Frame
local flipShade: Frame
local flipLift: UIScale -- the page swelling a little as it lifts toward the viewer
local flipShadow: Frame -- the lifted page's shadow on the page underneath
local flipShadowFade: UIGradient
local flipping = false
local queuedSpread: number? = nil -- a redraw asked for mid-turn, done when the turn ends
local visibleTiles: { Tile } = {} -- tiles that pass the search and filter, in card order
local searchText = ""
local tooltip: Frame
local tooltipTile: Tile? = nil -- the pocket the tooltip describes

local plotConnections: { RBXScriptConnection } = {}
local refreshQueued = false

local function getCount(source: { [string]: Owned }, cardId: string): Owned
	return source[cardId] or { normal = 0, foil = 0 }
end

-- This card's levelled cards in the binder, strongest (Power) first
local function getRaised(cardId: string): { Beast }
	local list: { Beast } = {}
	for _, beast in beasts do
		if beast.cardId == cardId then
			table.insert(list, beast)
		end
	end
	local card = Cards.ById[cardId]
	table.sort(list, function(a, b)
		return BeastRules.getPower(card, a.foil, a.level, a.stars, a.grade) > BeastRules.getPower(card, b.foil, b.level, b.stars, b.grade)
	end)
	return list
end

local function sumGrades(stacks: Stacks): { [string]: Owned }
	local summed: { [string]: Owned } = {}
	for cardId, byGrade in stacks do
		local total = { normal = 0, foil = 0 }
		for _, owned in byGrade do
			total.normal += owned.normal
			total.foil += owned.foil
		end
		summed[cardId] = total
	end
	return summed
end

-- Every row for this card: plain stacks per grade and foil, plus levelled cards, strongest first
local function getEntries(card: Card): { Entry }
	local entries: { Entry } = {}
	for grade, owned in graded[card.id] or {} do
		for _, foil in { true, false } do
			local count = if foil then owned.foil else owned.normal
			if count > 0 then
				table.insert(entries, {
					key = `stack:{grade}:{foil}`,
					power = BeastRules.getPower(card, foil, 1, BeastRules.START_STARS, grade),
					value = BeastRules.getValue(card, foil, 1, BeastRules.START_STARS, grade),
					grade = grade,
					foil = foil,
					count = count,
				})
			end
		end
	end
	for _, beast in getRaised(card.id) do
		table.insert(entries, {
			key = beast.id,
			power = BeastRules.getPower(card, beast.foil, beast.level, beast.stars, beast.grade),
			value = BeastRules.getValue(card, beast.foil, beast.level, beast.stars, beast.grade),
			beast = beast,
			grade = beast.grade,
			foil = beast.foil,
			count = 1,
		})
	end
	table.sort(entries, function(a, b)
		if a.power ~= b.power then
			return a.power > b.power
		end
		return a.value > b.value
	end)
	return entries
end

-- Best grade owned of this card (plain or levelled), or nil
local function getBestGrade(cardId: string): string?
	local best: string? = nil
	local function consider(grade: string)
		if not best or BeastRules.getGradeRank(grade) > BeastRules.getGradeRank(best) then
			best = grade
		end
	end
	for grade, owned in graded[cardId] or {} do
		if owned.normal + owned.foil > 0 then
			consider(grade)
		end
	end
	for _, beast in getRaised(cardId) do
		consider(beast.grade)
	end
	return best
end

-- Cards currently in this player's own cases, read from the card parts on their plot
local function readDisplayedCards(): { [string]: Owned }
	local counts: { [string]: Owned } = {}
	local plotId = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
	if not plot then
		return counts
	end
	for _, part in plot:GetDescendants() do
		local cardId = part:GetAttribute("CardId")
		if typeof(cardId) == "string" and part:GetAttribute("OwnerUserId") == player.UserId then
			local owned = counts[cardId] or { normal = 0, foil = 0 }
			counts[cardId] = owned
			if part:GetAttribute("Foil") == true then
				owned.foil += 1
			else
				owned.normal += 1
			end
		end
	end
	return counts
end

local function addCardFrame(parent: Instance): (Frame, UIStroke)
	local inner = Instance.new("Frame")
	inner.Name = "Face"
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = parent
	UIKit.corner(inner, 8)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner
	return inner, stroke
end

-- Copies of this card the player has: in the binder (plain + levelled) and on display
local function getOwnedCounts(cardId: string): (number, number)
	local inBinder = getCount(collection, cardId)
	local shown = getCount(displayed, cardId)
	return inBinder.normal + inBinder.foil + #getRaised(cardId), shown.normal + shown.foil
end

local function isCollected(cardId: string): boolean
	local owned, onDisplay = getOwnedCounts(cardId)
	return owned + onDisplay > 0
end

-- Draws one pocket (only called for pockets on the open spread)
local function renderTile(tile: Tile)
	local cardId = tile.card.id
	local inBinder = getCount(collection, cardId)
	local shown = getCount(displayed, cardId)
	local owned, onDisplay = getOwnedCounts(cardId)
	if owned + onDisplay == 0 then
		CardFace.renderMissing(tile.inner, tile.stroke, tile.card)
		tile.countLabel.Visible = false
		tile.levelLabel.Visible = false
		return
	end
	local raised = getRaised(cardId)
	local hasFoilBeast = false
	for _, beast in raised do
		hasFoilBeast = hasFoilBeast or beast.foil
	end
	-- The tile shows the stats of the best copy: the strongest levelled one, else a plain one of the best grade
	local bestGrade = getBestGrade(cardId)
	local strongest = raised[1]
	local growth = if strongest
		then { level = strongest.level, stars = strongest.stars, grade = strongest.grade }
		else { level = 1, stars = BeastRules.START_STARS, grade = bestGrade or BeastRules.DEFAULT_GRADE }
	CardFace.render(tile.inner, tile.stroke, tile.card, inBinder.foil + shown.foil > 0 or hasFoilBeast, true, growth)
	-- Total copies in the binder; the chip shows the best grade and best levelled one (details in the card view)
	tile.countLabel.Visible = true
	local parts = {}
	if bestGrade then
		table.insert(parts, bestGrade)
	end
	if raised[1] then
		table.insert(parts, `Lv {raised[1].level}`)
	end
	for _, beast in raised do
		if working[beast.id] then
			table.insert(parts, "Job")
			break
		end
	end
	for _, beast in raised do
		if partied[beast.id] then
			table.insert(parts, "Party")
			break
		end
	end
	-- Tiny pockets (small phones) keep just the count: the second chip's text would not fit
	local roomy = (pageGrids[1] and pageGrids[1].CellSize.X.Offset or 0) >= SMALL_POCKET
	tile.levelLabel.Text = table.concat(parts, " · ")
	tile.levelLabel.Visible = roomy and #parts > 0
	-- With chips the count shrinks to the left part of the row
	local short = roomy and #parts > 0
	tile.countLabel.Size = UDim2.new(if short then 0.36 else 1, 0, 0, CHIP_ROW - 3)
	tile.countLabel.Text = if owned == 0 then "shown" elseif short then `x{owned}` else `Owned {owned}`
end

local function passesFilter(card: Card): boolean
	if card.set ~= currentSet then
		return false
	end
	if searchText ~= "" then
		local query = string.lower(searchText)
		local number = tonumber((string.gsub(query, "#", "")))
		local nameMatch = string.find(string.lower(card.name), query, 1, true) ~= nil
		if not nameMatch and number ~= card.number then
			return false
		end
	end
	if showFilter == OWNED_FILTER and not isCollected(card.id) then
		return false
	elseif showFilter == MISSING_FILTER and isCollected(card.id) then
		return false
	end
	if next(rarityPicks) ~= nil and not rarityPicks[card.rarity] then
		return false
	end
	return true
end

-- Best value among your copies of a card (0 if you have none)
local function getBestValue(card: Card): number
	local best = 0
	for _, entry in getEntries(card) do
		best = math.max(best, entry.value)
	end
	return best
end

local function sortTiles(list: { Tile })
	local keys: { [Tile]: number } = {}
	for _, tile in list do
		local card = tile.card
		if sortBy == "Value" then
			keys[tile] = -getBestValue(card)
		elseif sortBy == "Copies" then
			local owned, onDisplay = getOwnedCounts(card.id)
			keys[tile] = -(owned + onDisplay)
		elseif sortBy == "Rarity" then
			local tier = Rarities.Tiers[card.rarity]
			keys[tile] = -(if tier then tier.order else 0)
		else
			keys[tile] = 0
		end
	end
	table.sort(list, function(a, b)
		if keys[a] ~= keys[b] then
			return keys[a] < keys[b]
		end
		return a.card.number < b.card.number
	end)
end

local function getSpreadCount(): number
	return BinderSpreads.count(#visibleTiles, pocketsPerPage)
end

-- The tiles a spread shows on its left and right page, in pocket order.
-- Spread 1 is the set's cover (left page) and page 1 (right page).
local function getSpreadTiles(index: number): ({ Tile }, { Tile })
	local first, last = BinderSpreads.cards(index, #visibleTiles, pocketsPerPage)
	local left, right = {}, {}
	for position = first, last do
		local tile = visibleTiles[position]
		local offset = position - first
		tile.button.LayoutOrder = offset
		table.insert(if BinderSpreads.side(index, offset, pocketsPerPage) == "Left" then left else right, tile)
	end
	return left, right
end

local function placeTiles(list: { Tile }, parent: Instance)
	for _, tile in list do
		tile.button.Parent = parent
		renderTile(tile)
	end
end

local function getTilesOn(parent: Instance): { Tile }
	local list = {}
	for _, tile in tiles do
		if tile.button.Parent == parent then
			table.insert(list, tile)
		end
	end
	return list
end

local function updatePageLabel()
	pageLabel.Text = BinderSpreads.label(spreadIndex, BinderSpreads.pages(#visibleTiles, pocketsPerPage))
end

-- Puts the tiles of a spread into the pages at once and draws them; the rest wait off-screen
local function showSpread(index: number)
	if flipping then
		queuedSpread = index
		return
	end
	spreadIndex = math.clamp(index, 1, getSpreadCount())
	local left, right = getSpreadTiles(spreadIndex)
	for _, tile in tiles do
		tile.button.Parent = nil
	end
	placeTiles(left, pages[1])
	placeTiles(right, pages[2])
	coverPage.Visible = spreadIndex == 1
	updatePageLabel()
end

-- Where the sheet and its shadow sit: against the spine on the given side, the cards held at the spine edge
local function dockSheet(side: BinderSpreads.Side)
	local onRight = side == "Right"
	flipSheet.AnchorPoint = Vector2.new(if onRight then 0 else 1, 0.5)
	flipSheet.Position = if onRight then UDim2.new(0.5, 10, 0.5, 0) else UDim2.new(0.5, -10, 0.5, 0)
	flipContent.AnchorPoint = Vector2.new(if onRight then 0 else 1, 0.5)
	flipContent.Position = UDim2.fromScale(if onRight then 0 else 1, 0.5)
	flipShadow.AnchorPoint = flipSheet.AnchorPoint
	flipShadow.Position = flipSheet.Position
	-- Darkest against the page's edge, fading away from the spine
	flipShadowFade.Rotation = if onRight then 0 else 180
end

-- One frame of the turn. turn: 0 (flat on its first side) to 1 (flat on the other). The page rotates about the
-- spine: seen from the front its width follows cos(angle); it swells a little as it lifts toward the viewer,
-- darkens as it turns edge-on, and its shadow stretches across the page underneath.
local function poseSheet(turn: number, size: Vector2)
	local look = Collection.BOOK
	local angle = turn * math.pi
	local lift = math.sin(angle)
	local width = math.abs(math.cos(angle)) * size.X
	flipSheet.Size = UDim2.fromOffset(width, size.Y)
	flipLift.Scale = 1 + look.FLIP_LIFT * lift
	-- Front face darkens as it turns away; the back face starts dim and brightens as it lands
	local shade = if turn < 0.5 then look.FLIP_SHADE * lift else look.FLIP_SHADE * lift * 0.7
	flipShade.BackgroundTransparency = 1 - shade
	flipShadow.Size = UDim2.fromOffset(width + size.X * look.FLIP_SHADOW * lift, size.Y)
	flipShadow.BackgroundTransparency = 1 - 0.55 * lift
end

-- Turns to a spread like a real page: the turning page (with its cards) rotates about the spine, then lands on
-- the other side showing the next cards, its back. Everything else updates at once (showSpread).
local function flipTo(index: number)
	if flipping then
		return
	end
	local target = math.clamp(index, 1, getSpreadCount())
	local side = BinderSpreads.turningSide(spreadIndex, target)
	if not side or not panel.Visible then
		showSpread(target)
		return
	end
	flipping = true
	local look = Collection.BOOK
	local forward = side == "Right"
	local turning = pages[if forward then 2 else 1]
	local landing = pages[if forward then 1 else 2]
	local newLeft, newRight = getSpreadTiles(target)
	-- In the book's own pixels: the book is scaled down while Filters are open
	local size = turning.AbsoluteSize / bookScale.Scale
	flipContent.Size = UDim2.fromOffset(size.X, size.Y)

	-- The sheet lifts the turning page's cards; the new cards wait underneath it
	dockSheet(side)
	local leaving = getTilesOn(turning)
	for _, tile in leaving do
		tile.button.Parent = flipContent
	end
	placeTiles(if forward then newRight else newLeft, turning)
	if not forward and target == 1 then
		coverPage.Visible = true -- the cover is under the left page that turns away
	end
	local arriving = if forward then newLeft else newRight
	poseSheet(0, size)
	flipSheet.Visible = true
	flipShadow.Visible = true

	local started = os.clock()
	local flippedOver = false
	local done = Instance.new("BindableEvent")
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - started) / look.FLIP_SECONDS)
		-- Ease in and out: slow lift, quick swing over the spine, soft landing
		local turn = t * t * (3 - 2 * t)
		if turn >= 0.5 and not flippedOver then
			-- Edge-on at the spine: the sheet now shows its back (the next cards) on the other side
			flippedOver = true
			for _, tile in leaving do
				tile.button.Parent = nil
			end
			dockSheet(if forward then "Left" else "Right")
			placeTiles(arriving, flipContent)
		end
		poseSheet(turn, size)
		if t >= 1 then
			connection:Disconnect()
			done:Fire()
		end
	end)
	done.Event:Wait()
	done:Destroy()

	for _, tile in getTilesOn(landing) do
		tile.button.Parent = nil
	end
	for _, tile in arriving do
		tile.button.Parent = landing
	end
	flipSheet.Visible = false
	flipShadow.Visible = false
	flipLift.Scale = 1
	spreadIndex = target
	coverPage.Visible = target == 1
	updatePageLabel()
	flipping = false
	local queued = queuedSpread
	if queued then
		queuedSpread = nil
		showSpread(queued)
	end
end

-- Lights up the Filters panel's choices
local function refreshFilterButtons()
	for value, button in showButtons do
		button.BackgroundColor3 = if value == showFilter then UIKit.Colors.Accent else UIKit.Colors.Row
	end
	for value, button in sortButtons do
		button.BackgroundColor3 = if value == sortBy then UIKit.Colors.Accent else UIKit.Colors.Row
	end
	for rarity, chip in rarityChips do
		local tier = Rarities.Tiers[rarity]
		local color = if tier then tier.color else UIKit.Colors.Accent
		chip.BackgroundColor3 = if rarityPicks[rarity] then color else UIKit.Colors.Row
	end
end

-- Re-applies search, filters and sort, then redraws the open spread (keeping the page when possible)
local function applyFilter()
	visibleTiles = {}
	for _, tile in tiles do
		if passesFilter(tile.card) then
			table.insert(visibleTiles, tile)
		end
	end
	sortTiles(visibleTiles)
	refreshFilterButtons()
	showSpread(spreadIndex)
end

-- The current set's cover page, set tabs and the progress card
local function refreshSet()
	local owned, total, value = 0, 0, 0
	for _, card in Cards.BySet[currentSet] or {} do
		total += 1
		if isCollected(card.id) then
			owned += 1
		end
		for _, entry in getEntries(card) do
			value += entry.value * entry.count
		end
	end
	local color = Collection.SET_COLORS[currentSet] or UIKit.Colors.Accent
	local art = getSetArt(currentSet)
	local leather = coverPage:FindFirstChild("Leather") :: UIGradient
	leather.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.12), color:Lerp(Color3.new(0, 0, 0), 0.35))
	coverArt.Image = art or ""
	coverEmblem.Visible = art == nil
	coverTitle.Text = string.upper(currentSet)
	coverProgress.Text = `{owned} / {total} collected`
	coverFill.Size = UDim2.fromScale(if total > 0 then owned / total else 0, 1)
	coverValue.Text = string.format("Worth $%.2f", value)
	coverEmblem.Text = Collection.SET_EMBLEMS[currentSet] or "✨"
	progressName.Text = currentSet
	progressCount.Text = `📖 {owned} / {total}`
	progressValue.Text = string.format("$%.2f", value)
	progressFill.Size = UDim2.fromScale(if total > 0 then owned / total else 0, 1)
	progressFill.BackgroundColor3 = color
	for set, tab in setTabs do
		local active = set == currentSet
		tab.BackgroundColor3 = if active then (Collection.SET_COLORS[set] or UIKit.Colors.Accent) else UIKit.Colors.Row
		-- The open set's tab sticks out a little further
		tab.Size = UDim2.fromOffset(Collection.BOOK.TAB_WIDTH + (if active then 20 else 12), Collection.BOOK.TAB_HEIGHT)
	end
end

local function refresh()
	displayed = readDisplayedCards()
	refreshSet()
	applyFilter()
	CardDetailController.Refresh()
end

local function openSet(set: string)
	if not Cards.BySet[set] then
		return
	end
	currentSet = set
	spreadIndex = 1
	refresh()
end

-- Tooltip (mouse only) -------------------------------------------------------------------------------

-- What the tooltip shows for a card: copies, best grade and level, strongest Power and the worth range
local function tooltipInfo(card: Card): CardTips.CardInfo
	local owned, onDisplay = getOwnedCounts(card.id)
	local entries = getEntries(card)
	local raised = getRaised(card.id)
	local low, high = math.huge, 0
	for _, entry in entries do
		low = math.min(low, entry.value)
		high = math.max(high, entry.value)
	end
	return {
		card = card,
		owned = owned,
		onDisplay = onDisplay,
		bestGrade = getBestGrade(card.id),
		bestLevel = if raised[1] then raised[1].level else nil,
		power = if entries[1] then entries[1].power else nil,
		worthLow = if entries[1] then low else nil,
		worthHigh = if entries[1] then high else nil,
	}
end

-- Level with its pocket, just outside the book (right of it, else left; else above or under the pocket), never over it
local function placeTooltip()
	local tile = tooltipTile
	if not tile or not tooltip.Visible then
		return
	end
	local screen = tooltip.Parent :: GuiObject
	local origin = screen.AbsolutePosition
	local button = tile.button
	local spot = UiLayout.beside(
		{ x = book.AbsolutePosition.X - origin.X, y = button.AbsolutePosition.Y - origin.Y, w = book.AbsoluteSize.X, h = button.AbsoluteSize.Y },
		{ w = tooltip.AbsoluteSize.X, h = tooltip.AbsoluteSize.Y },
		{ w = screen.AbsoluteSize.X, h = screen.AbsoluteSize.Y },
		TOOLTIP_GAP,
		-- no room either side of the book: above or under the pocket itself
		{ x = button.AbsolutePosition.X - origin.X, y = button.AbsolutePosition.Y - origin.Y, w = button.AbsoluteSize.X, h = button.AbsoluteSize.Y }
	)
	tooltip.Position = UDim2.fromOffset(spot.x, spot.y)
end

local function showTooltip(tile: Tile)
	-- Pockets under the open card view still get mouse events; no tooltip through it
	if not UserInputService.MouseEnabled or not tile.button.Parent or CardDetailController.IsOpen() or bagOverlay.Visible then
		return
	end
	tooltipTile = tile
	CardTips.card(tooltip, tooltipInfo(tile.card))
	tooltip.Visible = true
	placeTooltip()
end

local function hideTooltip()
	tooltip.Visible = false
	tooltipTile = nil
end

local function openDetail(card: Card)
	CardDetailController.Open(card)
	if CardDetailController.IsOpen() and hintToast then
		UIController.Dismiss(hintToast) -- "Tap a card, then ..." is done once a card is open
		hintToast = nil
	end
end

local function buildTile(card: Card, parent: Instance): Tile
	local button = Instance.new("TextButton")
	button.Name = card.id
	button.LayoutOrder = card.number
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = parent

	-- The card on top, keeping its shape, in a plastic sleeve; the chips sit in the row under it
	local holder = Instance.new("Frame")
	holder.Name = "CardHolder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, -CHIP_ROW)
	holder.Parent = button
	local sleeve = Instance.new("Frame")
	sleeve.Name = "Sleeve"
	sleeve.AnchorPoint = Vector2.new(0.5, 0)
	sleeve.Position = UDim2.fromScale(0.5, 0)
	sleeve.Size = UDim2.fromScale(1, 1)
	sleeve.BackgroundColor3 = Collection.BOOK.SLEEVE
	sleeve.Parent = holder
	UIKit.corner(sleeve, 8)
	UIKit.outline(sleeve, Collection.BOOK.SLEEVE_EDGE, 1.5)
	local sleeveShape = Instance.new("UIAspectRatioConstraint")
	sleeveShape.AspectRatio = CARD_ASPECT
	sleeveShape.Parent = sleeve
	local inner, stroke = addCardFrame(holder)
	inner.AnchorPoint = Vector2.new(0.5, 0)
	inner.Position = UDim2.fromScale(0.5, 0)
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = CARD_ASPECT
	shape.Parent = inner
	-- The plastic's glint, a soft diagonal band over the card
	local glint = Instance.new("Frame")
	glint.Name = "Glint"
	glint.AnchorPoint = Vector2.new(0.5, 0)
	glint.Position = UDim2.fromScale(0.5, 0)
	glint.Size = UDim2.fromScale(1, 1)
	glint.BackgroundColor3 = Color3.new(1, 1, 1)
	glint.BorderSizePixel = 0
	glint.ZIndex = 20
	glint.Parent = holder
	UIKit.corner(glint, 8)
	local glintShape = Instance.new("UIAspectRatioConstraint")
	glintShape.AspectRatio = CARD_ASPECT
	glintShape.Parent = glint
	local glintBand = Instance.new("UIGradient")
	glintBand.Rotation = 35
	glintBand.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, Collection.BOOK.SLEEVE_SHINE),
		NumberSequenceKeypoint.new(0.32, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	glintBand.Parent = glint

	local countLabel = UIKit.label(button, "", Enum.Font.GothamBold, 13, UIKit.Colors.Text)
	countLabel.Name = "Count"
	countLabel.AnchorPoint = Vector2.new(0, 1)
	countLabel.Position = UDim2.fromScale(0, 1)
	countLabel.Size = UDim2.new(1, 0, 0, CHIP_ROW - 3)
	countLabel.TextXAlignment = Enum.TextXAlignment.Center
	countLabel.TextColor3 = Collection.BOOK.INK
	countLabel.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	countLabel.ZIndex = 3
	UIKit.corner(countLabel, 8)
	UIKit.outline(countLabel, Collection.BOOK.EDGE, 1.5)

	local levelLabel = UIKit.label(button, "", Enum.Font.GothamBold, 12, UIKit.Colors.Text)
	levelLabel.Name = "Level"
	levelLabel.AnchorPoint = Vector2.new(1, 1)
	levelLabel.Position = UDim2.fromScale(1, 1)
	levelLabel.Size = UDim2.new(0.62, 0, 0, CHIP_ROW - 3)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.TextColor3 = Color3.fromRGB(210, 225, 255)
	levelLabel.BackgroundColor3 = Color3.fromRGB(45, 70, 150)
	levelLabel.Visible = false
	levelLabel.ZIndex = 3
	UIKit.corner(levelLabel, 8)
	UIKit.outline(levelLabel, Color3.fromRGB(90, 120, 210), 1.5)

	-- Chip text shrinks to fit narrow pockets ("B · Lv 4 · Job")
	for _, chip in { countLabel, levelLabel } do
		chip.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 13
		fit.Parent = chip
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingRight = UDim.new(0, 3)
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingBottom = UDim.new(0, 2)
		pad.Parent = chip
	end

	local tile: Tile = { card = card, button = button, inner = inner, stroke = stroke, countLabel = countLabel, levelLabel = levelLabel }
	button.Activated:Connect(function()
		hideTooltip()
		openDetail(card)
	end)
	button.MouseEnter:Connect(function()
		showTooltip(tile)
	end)
	button.MouseLeave:Connect(hideTooltip)
	return tile
end

-- The card view (CardDetailController): while a card is inspected the book, backdrop, tabs and binder buttons hide
-- so the 3D card shows
function setInspecting(on: boolean)
	cardsTab.Visible = not on
	bagTab.Visible = not on
	-- The 3D card needs the world undimmed
	backdropGui.Enabled = panel.Visible and not on
	bookHolder.Visible = not on
	for _, name in { "FilterButton", "SetProgress", "RarityGuide" } do
		local item = panel:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.Visible = not on
		end
	end
	if on and filtersPanel.Visible then
		setFiltersOpen(false)
	end
end

-- Sizes the pockets for the pages' size on screen; a layout change re-pages the binder
local function fitPockets()
	local page = pages[1]
	if not page then
		return
	end
	-- In the book's own pixels: the book is scaled down while Filters are open
	local scale = if bookScale then bookScale.Scale else 1
	local layout = PocketLayout.choose(page.AbsoluteSize.X / scale, page.AbsoluteSize.Y / scale, POCKET_OPTIONS)
	for _, grid in pageGrids do
		grid.CellSize = UDim2.fromOffset(layout.width, layout.height)
		grid.FillDirectionMaxCells = layout.columns
	end
	local perPage = layout.columns * layout.rows
	if perPage ~= pocketsPerPage then
		-- Keep the first card of the current spread in view
		local firstCard = BinderSpreads.cards(spreadIndex, #visibleTiles, pocketsPerPage)
		pocketsPerPage = perPage
		local spread = 1
		while spread < BinderSpreads.count(#visibleTiles, pocketsPerPage) do
			local _, last = BinderSpreads.cards(spread, #visibleTiles, pocketsPerPage)
			if last >= firstCard then
				break
			end
			spread += 1
		end
		spreadIndex = spread
		if coverPage then
			showSpread(spreadIndex)
		end
	elseif coverPage then
		showSpread(spreadIndex) -- same pockets, new size: redraw so the chips fit
	end
end

-- Bag: the item inventory (Config/Items), the binder's second tab. A centred inventory window: a grid of slots
-- on the left (items with a count badge, the rest empty), the chosen item's details on the right.
local bagGrid: ScrollingFrame
local bagDetail: Frame
local bagCount: TextLabel
local bagItems: { [string]: number } = {}
local selectedItem: string? = nil

local BAG = {
	SLOTS = 20, -- slots always drawn (more appear if needed)
	COLUMNS = 5,
	SLOT = 84, -- pixels, square
	GAP = 8,
	EDGE = 4, -- padding round the grid so an outline isn't clipped
	DETAIL_WIDTH = 280,
	WINDOW = Vector2.new(5 * 84 + 4 * 8 + 32 + 280 + 16, 484), -- grid + padding + details
	SLOT_COLOR = UIStyle.ROW, -- a filled slot: lighter slate so items stand out
	EMPTY_COLOR = Color3.fromRGB(22, 28, 42),
	EMPTY_EDGE = UIStyle.EDGE,
	BADGE = UIStyle.EDGE,
	INK = Color3.fromRGB(244, 241, 233),
	SUBTEXT = Color3.fromRGB(150, 158, 178),
}

-- A boss item's tint and ladder number (key fragments: the boss they open; trophies: the boss beaten), or nil
local function bossMark(id: string): (Color3?, number?)
	local index = ItemRules.bossOf(id, Bosses.LADDER)
	if not index then
		return nil, nil
	end
	return BossTints.key(Bosses.LADDER[index]), index
end

local function tintIcon(holder: Frame, color: Color3?)
	local glyph = holder:FindFirstChild("Glyph")
	if color and glyph and glyph:IsA("ImageLabel") then
		glyph.ImageColor3 = color
	end
end

local function bagLabel(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3, y: number, height: number): TextLabel
	local label = UIKit.label(parent, text, font, size, color)
	label.Position = UDim2.fromOffset(16, y)
	label.Size = UDim2.new(1, -32, 0, height)
	label.TextWrapped = true
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.ZIndex = 34
	return label
end

local function ownedItemIds(): { string }
	local ids = {}
	for id in Items.ITEMS do
		if (bagItems[id] or 0) > 0 then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function renderBagDetail()
	for _, child in bagDetail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local info = if selectedItem then Items.ITEMS[selectedItem] else nil
	if not info or not selectedItem then
		local hint = bagLabel(bagDetail, "Your items show here. Tap one to see what it does.", Enum.Font.FredokaOne, 16, BAG.SUBTEXT, 24, 60)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	-- The item big on a dark circle (a boss item in its boss's tint), its name and how many you have
	local tint = bossMark(selectedItem)
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0)
	halo.Position = UDim2.new(0.5, 0, 0, 12)
	halo.Size = UDim2.fromOffset(84, 84)
	halo.BackgroundColor3 = UIStyle.PANEL
	halo.ZIndex = 33
	halo.Parent = bagDetail
	UIKit.corner(halo, 42)
	UIKit.outline(halo, tint or UIStyle.EDGE, 3)
	local icon = Icon.make(halo, info.icon, UDim2.fromOffset(62, 62))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 34
	Icon.set(icon, info.icon)
	tintIcon(icon, tint)
	local name = bagLabel(bagDetail, info.name, Enum.Font.FredokaOne, 20, BAG.INK, 102, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.outlined(name, 2)
	local owned = bagLabel(bagDetail, `You have {bagItems[selectedItem] or 0}`, Enum.Font.FredokaOne, 15, UIStyle.HINT, 128, 20)
	owned.TextXAlignment = Enum.TextXAlignment.Center
	-- What it does / where to get it / how to use it, as dark boxes
	local y = 154
	for _, section in { { title = "What it does", text = info.description }, { title = "Where to get it", text = info.source }, { title = "How to use it", text = info.use } } do
		if section.text then
			local box = Instance.new("Frame")
			box.Position = UDim2.fromOffset(12, y)
			box.Size = UDim2.new(1, -24, 0, 62)
			box.BackgroundColor3 = UIStyle.PANEL
			box.ZIndex = 33
			box.Parent = bagDetail
			UIKit.corner(box, 10)
			UIKit.outline(box, UIStyle.EDGE, 2)
			local heading = bagLabel(box, section.title, Enum.Font.FredokaOne, 14, UIStyle.HINT, 6, 18)
			heading.Position = UDim2.fromOffset(10, 6)
			heading.Size = UDim2.new(1, -20, 0, 18)
			local body = bagLabel(box, section.text, Enum.Font.Gotham, 13, BAG.INK, 26, 32)
			body.Position = UDim2.fromOffset(10, 26)
			body.Size = UDim2.new(1, -20, 0, 32)
			y += 68
		end
	end
end

-- One inventory slot: a filled one (icon and a count badge) or an empty one
local function addSlot(order: number, id: string?)
	local filled = id ~= nil
	local slot = Instance.new("TextButton")
	slot.Name = if id then id else "Empty"
	slot.Text = ""
	slot.LayoutOrder = order
	slot.AutoButtonColor = filled
	slot.Active = filled
	slot.BackgroundColor3 = if filled then BAG.SLOT_COLOR else BAG.EMPTY_COLOR
	slot.ZIndex = 32
	slot.Parent = bagGrid
	UIKit.corner(slot, 14)
	local selected = filled and id == selectedItem
	UIKit.outline(slot, if selected then UIStyle.HINT else BAG.EMPTY_EDGE, if selected then 3 else 2)
	if not id then
		return
	end
	local info = Items.ITEMS[id]
	local icon = Icon.make(slot, info.icon, UDim2.fromScale(0.62, 0.62))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.46)
	icon.ZIndex = 33
	Icon.set(icon, info.icon)
	-- Boss items: tinted for their boss, its ladder number in the corner, so every key looks different
	-- The window shrinks to fit small screens (UIScale); counts and numbers stay at least 14 px tall on screen
	local fit = bagOverlay:FindFirstChildOfClass("UIScale")
	local countSize = math.max(15, math.ceil(14 / (if fit then math.max(fit.Scale, 0.1) else 1)))
	local tint, bossNumber = bossMark(id)
	tintIcon(icon, tint)
	if tint and bossNumber then
		local chip = UIKit.pill(slot, tostring(bossNumber), tint)
		chip.Position = UDim2.fromOffset(4, 4)
		chip.Size = UDim2.fromOffset(0, countSize + 5)
		chip.TextSize = countSize
		chip.ZIndex = 35
	end
	local badge = UIKit.label(slot, `x{bagItems[id]}`, Enum.Font.FredokaOne, countSize, Color3.fromRGB(255, 255, 255))
	badge.AnchorPoint = Vector2.new(1, 1)
	badge.Position = UDim2.new(1, -4, 1, -4)
	badge.Size = UDim2.fromOffset(0, countSize + 5)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.TextWrapped = false -- wrapping at no width showed a bare "x"
	badge.BackgroundColor3 = BAG.BADGE
	badge.BackgroundTransparency = 0
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.ZIndex = 34
	UIKit.outlined(badge, 1.5)
	UIKit.corner(badge, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = badge
	slot.Activated:Connect(function()
		selectedItem = id
		renderBag()
	end)
end

function renderBag()
	for _, child in bagGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local ids = ownedItemIds()
	if selectedItem and not table.find(ids, selectedItem) then
		selectedItem = nil
	end
	selectedItem = selectedItem or ids[1]
	local slots = math.max(BAG.SLOTS, math.ceil(#ids / BAG.COLUMNS) * BAG.COLUMNS)
	for order = 1, slots do
		addSlot(order, ids[order])
	end
	bagCount.Text = `{#ids} / {slots} slots`
	renderBagDetail()
end

local function showTab(bag: boolean)
	if bag then
		hideTooltip()
	end
	bagOverlay.Visible = bag
	-- The book draws on its own layer, so the Bag would leave it showing around the edges; the book's corner
	-- buttons (Filters, Rarity guide, progress) would peek out under the Bag too
	bookGui.Enabled = panel.Visible and not bag
	for _, name in { "FilterButton", "RarityGuide" } do
		local item = panel:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.Visible = not bag
		end
	end
	if bag and filtersPanel.Visible then
		setFiltersOpen(false)
	end
	progressCard.Visible = not bag and panel.AbsoluteSize.X >= Collection.BOOK.PROGRESS_FROM
	cardsTab.BackgroundColor3 = if bag then UIKit.Colors.Row else UIKit.Colors.Accent
	bagTab.BackgroundColor3 = if bag then UIKit.Colors.Accent else UIKit.Colors.Row
	for button, open in { [cardsTab] = not bag, [bagTab] = bag } do
		local name = button:FindFirstChild("Name", true) :: TextLabel?
		if name then
			name.TextColor3 = if open then Color3.new(1, 1, 1) else BAG.INK
		end
	end
	if bag then
		renderBag()
	end
end

local function buildBag(parent: Frame)
	-- Two tabs in the header, next to the title
	-- An icon and a name side by side, centred on the tab (the name turns white on the open tab: showTab)
	local function tab(icon: string, text: string, x: number): TextButton
		local button = UIKit.button(parent, "", UIKit.Colors.Row)
		button.Position = UDim2.fromOffset(x, 10)
		button.Size = UDim2.fromOffset(116, 48)
		button.ZIndex = 12
		local row = Instance.new("Frame")
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.45)
		row.Size = UDim2.fromScale(0, 1)
		row.AutomaticSize = Enum.AutomaticSize.X
		row.BackgroundTransparency = 1
		row.ZIndex = 13
		row.Parent = button
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		local picture = Icon.make(row, icon, UDim2.fromOffset(28, 28))
		picture.LayoutOrder = 1
		picture.ZIndex = 13
		local name = UIKit.label(row, text, Enum.Font.FredokaOne, 16, BAG.INK)
		name.Name = "Name"
		name.LayoutOrder = 2
		name.Size = UDim2.fromScale(0, 1)
		name.AutomaticSize = Enum.AutomaticSize.X
		name.TextWrapped = false
		name.ZIndex = 13
		return button
	end
	cardsTab = tab("Cards", "Cards", 16)
	bagTab = tab("Bag", "Bag", 138)

	-- The window, centred; scaled down to fit small screens
	bagOverlay = Instance.new("Frame")
	bagOverlay.Name = "Bag"
	bagOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
	bagOverlay.Position = UDim2.fromScale(0.5, 0.5)
	bagOverlay.Size = UDim2.fromOffset(BAG.WINDOW.X, BAG.WINDOW.Y)
	bagOverlay.BackgroundColor3 = UIStyle.PANEL
	bagOverlay.Visible = false
	bagOverlay.ZIndex = 30
	bagOverlay.Parent = parent
	UIKit.corner(bagOverlay, 16)
	UIKit.outline(bagOverlay, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local fit = Instance.new("UIScale")
	fit.Parent = bagOverlay
	local function fitWindow()
		local room = parent.AbsoluteSize
		fit.Scale = math.min(1, (room.X - 24) / BAG.WINDOW.X, (room.Y - 84) / BAG.WINDOW.Y)
		-- The middle of the whole screen: this screen starts below Roblox's top bar strip
		local inset = GuiService:GetGuiInset().Y
		bagOverlay.Position = UDim2.new(0.5, 0, 0.5, -inset / 2)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWindow)
	fitWindow()

	local header, title = UIKit.header(bagOverlay, "Bag", "Bag")
	header.ZIndex = 31
	title.ZIndex = 32
	title.Position = UDim2.fromOffset(62, 0)
	local headerIcon = Icon.make(header, "Bag", UDim2.fromOffset(40, 40))
	headerIcon.AnchorPoint = Vector2.new(0, 0.5)
	headerIcon.Position = UDim2.new(0, 14, 0.5, 0)
	headerIcon.ZIndex = 32
	bagCount = UIKit.label(header, "", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	bagCount.AnchorPoint = Vector2.new(1, 0.5)
	bagCount.Position = UDim2.new(1, -18, 0.5, 0)
	bagCount.Size = UDim2.fromOffset(160, 24)
	bagCount.TextXAlignment = Enum.TextXAlignment.Right
	bagCount.ZIndex = 32
	UIKit.outlined(bagCount, 2)

	local top = UIKit.HEADER_HEIGHT + 12
	bagGrid = Instance.new("ScrollingFrame")
	bagGrid.Name = "Slots"
	bagGrid.Position = UDim2.fromOffset(16 - BAG.EDGE, top - BAG.EDGE)
	bagGrid.Size = UDim2.new(0, BAG.COLUMNS * BAG.SLOT + (BAG.COLUMNS - 1) * BAG.GAP + 8 + BAG.EDGE * 2, 1, -(top + 16) + BAG.EDGE * 2)
	bagGrid.BackgroundTransparency = 1
	bagGrid.BorderSizePixel = 0
	bagGrid.ScrollBarThickness = 4
	bagGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bagGrid.CanvasSize = UDim2.new()
	bagGrid.ZIndex = 31
	bagGrid.Parent = bagOverlay
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(BAG.SLOT, BAG.SLOT)
	grid.CellPadding = UDim2.fromOffset(BAG.GAP, BAG.GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = bagGrid
	-- Room inside the scrolling grid's clip for the selected slot's outline
	local edge = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(edge :: any)[side] = UDim.new(0, BAG.EDGE)
	end
	edge.Parent = bagGrid

	bagDetail = Instance.new("Frame")
	bagDetail.Name = "Details"
	bagDetail.AnchorPoint = Vector2.new(1, 0)
	bagDetail.Position = UDim2.new(1, -16, 0, top)
	bagDetail.Size = UDim2.new(0, BAG.DETAIL_WIDTH, 1, -(top + 16))
	bagDetail.BackgroundColor3 = UIStyle.ROW
	bagDetail.ZIndex = 32
	bagDetail.Parent = bagOverlay
	UIKit.corner(bagDetail, 14)
	UIKit.outline(bagDetail, UIStyle.EDGE, 2)

	cardsTab.Activated:Connect(function()
		showTab(false)
	end)
	bagTab.Activated:Connect(function()
		showTab(true)
	end)
	parent:GetPropertyChangedSignal("Visible"):Connect(function()
		if not parent.Visible then
			showTab(false)
		end
	end)
	showTab(false)
end

-- A small dark key hint on a button's corner ("Q", "E")
local function addKeyChip(button: GuiObject, key: string)
	local chip = Instance.new("TextLabel")
	chip.Name = "Key"
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Position = UDim2.new(1, 10, 1, 10)
	chip.Size = UDim2.fromOffset(24, 24)
	chip.BackgroundColor3 = Color3.fromRGB(20, 28, 60)
	chip.Font = Enum.Font.FredokaOne
	chip.Text = key
	chip.TextSize = 14
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.ZIndex = button.ZIndex + 2
	chip.Parent = button
	UIKit.corner(chip, 6)
	UIKit.outline(chip, Color3.new(1, 1, 1), 1.5)
end

local function choiceRow(parent: Instance, order: number, values: { string }, onPick: (string) -> ()): { [string]: TextButton }
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundTransparency = 1
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row
	local buttons: { [string]: TextButton } = {}
	for index, value in values do
		local button = UIKit.button(row, value, UIKit.Colors.Row)
		button.LayoutOrder = index
		button.Size = UDim2.new(1 / #values, -6, 1, 0)
		button.TextSize = 15
		button.Activated:Connect(function()
			onPick(value)
		end)
		buttons[value] = button
	end
	return buttons
end

local function sectionLabel(parent: Instance, order: number, text: string)
	local label = UIKit.label(parent, text, Enum.Font.FredokaOne, 18, UIKit.Colors.Text)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 24)
end

-- The Filters panel on the right: search, Show, Sort by, rarity chips. The book shrinks aside while it's open.
local function buildFilters(parent: Frame)
	filtersPanel = Instance.new("Frame")
	filtersPanel.Name = "Filters"
	-- Between the close / Filters buttons (top right) and the set progress card (bottom right)
	filtersPanel.AnchorPoint = Vector2.new(1, 0)
	filtersPanel.Position = UDim2.new(1, -16, 0, 84)
	filtersPanel.Size = UDim2.new(0, Collection.FILTERS_WIDTH, 1, -(84 + 100))
	filtersPanel.BackgroundColor3 = UIKit.Colors.Panel
	filtersPanel.Visible = false
	filtersPanel.ZIndex = 6
	filtersPanel.Parent = parent
	UIKit.corner(filtersPanel, 16)
	UIKit.outline(filtersPanel, Color3.new(1, 1, 1), 3)
	UIKit.header(filtersPanel, "Filters")
	local close = UIKit.closeButton(filtersPanel)
	close.Activated:Connect(function()
		setFiltersOpen(false)
	end)

	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(14, UIKit.HEADER_HEIGHT + 10)
	body.Size = UDim2.new(1, -28, 1, -(UIKit.HEADER_HEIGHT + 20))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ZIndex = filtersPanel.ZIndex
	body.Parent = filtersPanel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.LayoutOrder = 1
	search.Size = UDim2.new(1, 0, 0, 44)
	search.BackgroundColor3 = UIKit.Colors.Row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "🔍 Search name or #"
	search.Text = ""
	search.Font = Enum.Font.GothamBold
	search.TextSize = 15
	search.TextColor3 = UIKit.Colors.Text
	search.PlaceholderColor3 = UIKit.Colors.Subtext
	search.Parent = body
	UIKit.corner(search, 12)
	UIKit.outline(search)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		spreadIndex = 1
		applyFilter()
	end)

	sectionLabel(body, 2, "Show")
	showButtons = choiceRow(body, 3, { ALL_FILTER, OWNED_FILTER, MISSING_FILTER }, function(value)
		showFilter = value
		spreadIndex = 1
		applyFilter()
	end)
	sectionLabel(body, 4, "Sort by")
	sortButtons = choiceRow(body, 5, { "Set", "Value", "Copies", "Rarity" }, function(value)
		sortBy = value
		spreadIndex = 1
		applyFilter()
	end)
	sectionLabel(body, 6, "Rarity")
	local chips = Instance.new("Frame")
	chips.LayoutOrder = 7
	chips.Size = UDim2.new(1, 0, 0, 0)
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.BackgroundTransparency = 1
	chips.Parent = body
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -4, 0, 40)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = chips
	local rarities: { string } = {}
	for name in Rarities.Tiers do
		table.insert(rarities, name)
	end
	table.sort(rarities, function(a, b)
		return Rarities.Tiers[a].order < Rarities.Tiers[b].order
	end)
	for index, rarity in rarities do
		local chip = UIKit.button(chips, rarity, UIKit.Colors.Row)
		chip.LayoutOrder = index
		chip.TextSize = 15
		chip.Activated:Connect(function()
			rarityPicks[rarity] = if rarityPicks[rarity] then nil else true
			spreadIndex = 1
			applyFilter()
		end)
		rarityChips[rarity] = chip
	end
end

-- Opens or closes the Filters panel; the book shrinks and slides left to make room
-- Where the book sits: as big as its binder shape fits between the top row, bottom row and arrow lanes,
-- centred there, or (Filters open) shrunk into the room left of the Filters panel, arrows included
local function getBookLayout(filtersOpen: boolean): (UDim2, UDim2, number)
	local look = Collection.BOOK
	-- The whole screen, top bar strip included (the book's layer ignores the inset); the rows' bands count
	-- from below the strip, where the buttons are
	local area = bookGui.AbsoluteSize
	local inset = area.Y - panel.AbsoluteSize.Y
	-- The biggest binder shape between a top and bottom margin, and the lanes either side
	local lane = if area.X < look.NARROW_BELOW then look.NARROW_LANE else look.SIDE_LANE
	local function fit(top: number, bottom: number): (number, number, number)
		local width = math.max(200, area.X - lane * 2)
		local height = math.max(140, area.Y - top - bottom)
		if width / height > look.ASPECT then
			width = height * look.ASPECT
		else
			height = width / look.ASPECT
		end
		return width, height, top + (area.Y - top - bottom) / 2
	end
	if area.X < look.NARROW_BELOW then
		-- Phones: the full height, between slim lanes of compact buttons (placeCorners)
		local leftLane = look.NARROW_LEFT + look.TAB_WIDTH
		local room = area.X - leftLane - look.NARROW_RIGHT
		local width = math.max(200, room)
		local height = math.max(140, area.Y - look.MARGIN - look.MARGIN_BOTTOM)
		if width / height > look.ASPECT then
			width = height * look.ASPECT
		else
			height = width / look.ASPECT
		end
		local centreY = look.MARGIN + (area.Y - look.MARGIN - look.MARGIN_BOTTOM) / 2
		local size = UDim2.fromOffset(width, height)
		if not filtersOpen then
			return size, UDim2.fromOffset(leftLane + room / 2, centreY), 1
		end
		local besideFilters = area.X - Collection.FILTERS_WIDTH - 32 - look.NARROW_LEFT
		local scale = math.min(1, besideFilters / (width + look.TAB_WIDTH))
		return size, UDim2.fromOffset(look.NARROW_LEFT + besideFilters / 2 + look.TAB_WIDTH * scale / 2, centreY), scale
	end
	local width, height, centreY = fit(look.MARGIN, look.MARGIN_BOTTOM)
	local left = (area.X - width) / 2 - look.TAB_WIDTH
	local right = (area.X + width) / 2
	if left < look.CORNER_LEFT or right > area.X - look.CORNER_RIGHT then
		width, height, centreY = fit(look.TOP_BAND + inset, look.BOTTOM_BAND)
	end
	local size = UDim2.fromOffset(width, height)
	if not filtersOpen then
		return size, UDim2.new(0.5, 0, 0, centreY), 1
	end
	-- Between the left corner buttons (Cards, Bag) and the Filters panel
	local room = area.X - Collection.FILTERS_WIDTH - 32 - look.CORNER_LEFT
	local scale = math.min(1, room / (width + lane * 2))
	return size, UDim2.fromOffset(look.CORNER_LEFT + room / 2, centreY), scale
end

-- The corner buttons: full size in the corners on roomy screens; compact icons in slim side lanes on phones
local function placeCorners(narrow: boolean)
	for index, tab in { cardsTab, bagTab } do
		tab.Position = if narrow then UDim2.fromOffset(12, 10 + (index - 1) * 56) else UDim2.fromOffset(16 + (index - 1) * 122, 10)
		tab.Size = if narrow then UDim2.fromOffset(64, 48) else UDim2.fromOffset(116, 48)
		local name = tab:FindFirstChild("Name", true)
		if name and name:IsA("GuiObject") then
			name.Visible = not narrow
		end
	end
	rarityGuideButton.Size = if narrow then UDim2.fromOffset(64, 48) else UDim2.fromOffset(170, 44)
	rarityGuideButton.Text = if narrow then "" else "Rarity guide"
	local guidePad = rarityGuideButton:FindFirstChildOfClass("UIPadding")
	if guidePad then
		guidePad.PaddingLeft = UDim.new(0, if narrow then 0 else 30)
	end
	local guideIcon = rarityGuideButton:FindFirstChild("Icon") :: GuiObject?
	if guideIcon then
		guideIcon.AnchorPoint = if narrow then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5)
		guideIcon.Position = if narrow then UDim2.fromScale(0.5, 0.45) else UDim2.new(0, -22, 0.45, 0) -- in the left padding, before the text
	end
	filterButton.Position = if narrow then UDim2.new(1, -16, 0, 76) else UDim2.new(1, -84, 0, 16)
end

local function layoutBook()
	placeCorners(bookGui.AbsoluteSize.X < Collection.BOOK.NARROW_BELOW)
	local size, position, scale = getBookLayout(filtersPanel.Visible)
	bookHolder.Size = size
	bookHolder.Position = position
	bookScale.Scale = scale
	progressCard.Visible = not (bagOverlay and bagOverlay.Visible) and panel.AbsoluteSize.X >= Collection.BOOK.PROGRESS_FROM
	local roomy = panel.AbsoluteSize.X >= Collection.BOOK.NARROW_BELOW
	for _, arrows in arrowLanes do
		arrows.Visible = roomy
	end
end

function setFiltersOpen(open: boolean)
	local info = TweenInfo.new(Collection.BOOK.SLIDE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local _, position, scale = getBookLayout(open)
	TweenService:Create(bookScale, info, { Scale = scale }):Play()
	TweenService:Create(bookHolder, info, { Position = position }):Play()
	if open then
		filtersPanel.Visible = true
		Motion.popIn(filtersPanel)
	else
		Motion.popOut(filtersPanel, function()
			filtersPanel.Visible = false
		end)
	end
end

local function makePage(book: Frame, isLeft: boolean): Frame
	local page = Instance.new("Frame")
	page.Name = if isLeft then "LeftPage" else "RightPage"
	page.Position = if isLeft then UDim2.new(0, 14, 0, 14) else UDim2.new(0.5, 10, 0, 14)
	page.Size = UDim2.new(0.5, -24, 1, -28)
	page.BackgroundColor3 = Collection.BOOK.PAGE_COLOR
	page.Parent = book
	UIKit.corner(page, 10)
	UIKit.outline(page, Collection.BOOK.EDGE, 1.5)

	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(POCKET_OPTIONS.gap, POCKET_OPTIONS.gap)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirectionMaxCells = POCKET_OPTIONS.preferredColumns
	grid.Parent = page
	table.insert(pageGrids, grid)
	page:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPockets)
	return page
end

-- The art for a set's cover: the front of the pack that sells it (none for sets without a pack)
function getSetArt(set: string): string?
	for _, pack in Packs.ById do
		if pack.name == set and pack.art and pack.kind ~= "Deck" then
			return pack.art
		end
	end
	return nil
end

-- The set's cover over spread 1's left page: the pack art over the whole cover (leather in the set's colour when
-- there is none), dark fades behind a title band (name and progress) and the set's worth, an embossed border. It sits on the book, not in the page
-- (the page's grid would size it like a pocket).
local function buildCover(page: Frame)
	coverPage = Instance.new("Frame")
	coverPage.Name = "Cover"
	coverPage.Position = page.Position
	coverPage.Size = page.Size
	coverPage.BackgroundColor3 = Color3.new(1, 1, 1)
	coverPage.ZIndex = page.ZIndex + 1
	coverPage.Parent = page.Parent
	UIKit.corner(coverPage, 10)
	local leather = Instance.new("UIGradient")
	leather.Name = "Leather"
	leather.Rotation = 60
	leather.Parent = coverPage
	-- Full art: the pack art fills the cover, under everything else
	coverArt = Instance.new("ImageLabel")
	coverArt.Name = "Art"
	coverArt.Size = UDim2.fromScale(1, 1)
	coverArt.BackgroundTransparency = 1
	coverArt.ScaleType = Enum.ScaleType.Crop
	coverArt.ZIndex = coverPage.ZIndex + 1
	coverArt.Parent = coverPage
	UIKit.corner(coverArt, 10)
	coverEmblem = UIKit.label(coverArt, "", Enum.Font.FredokaOne, 80, COVER_TEXT)
	coverEmblem.AnchorPoint = Vector2.new(0.5, 0.5)
	coverEmblem.Position = UDim2.fromScale(0.5, 0.55)
	coverEmblem.Size = UDim2.fromScale(0.5, 0.5)
	coverEmblem.SizeConstraint = Enum.SizeConstraint.RelativeXX
	coverEmblem.TextScaled = true
	coverEmblem.TextXAlignment = Enum.TextXAlignment.Center
	coverEmblem.ZIndex = coverArt.ZIndex + 1
	-- Dark fades into the art behind the title and the worth, so the text reads on any picture
	for _, fade in { { name = "TopFade", y = 0, h = 0.4, rotation = 90 }, { name = "BottomFade", y = 0.7, h = 0.3, rotation = -90 } } do
		local strip = Instance.new("Frame")
		strip.Name = fade.name
		strip.Position = UDim2.fromScale(0, fade.y)
		strip.Size = UDim2.fromScale(1, fade.h)
		strip.BackgroundColor3 = Color3.new(0, 0, 0)
		strip.BorderSizePixel = 0
		strip.ZIndex = coverArt.ZIndex + 1
		strip.Parent = coverPage
		UIKit.corner(strip, 10)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = fade.rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = strip
	end

	local emboss = Instance.new("Frame")
	emboss.Name = "Emboss"
	emboss.Position = UDim2.fromScale(0.05, 0.035)
	emboss.Size = UDim2.fromScale(0.9, 0.93)
	emboss.BackgroundTransparency = 1
	emboss.ZIndex = coverArt.ZIndex + 2
	emboss.Parent = coverPage
	UIKit.corner(emboss, 10)
	UIKit.outline(emboss, Color3.new(1, 1, 1), 2).Transparency = 0.6

	local band = Instance.new("Frame")
	band.Name = "TitleBand"
	band.Position = UDim2.fromScale(0.05, 0.1)
	band.Size = UDim2.fromScale(0.9, 0.2)
	band.BackgroundColor3 = Color3.new(0, 0, 0)
	band.BackgroundTransparency = 1
	band.BorderSizePixel = 0
	band.ZIndex = coverArt.ZIndex + 2
	band.Parent = coverPage
	-- Warm off-white: plain white would be taken as UIKit's auto colour and turn navy on the cover's base
	coverTitle = UIKit.label(band, "", Enum.Font.FredokaOne, 40, COVER_TEXT)
	coverTitle.Position = UDim2.fromScale(0.05, 0.06)
	coverTitle.Size = UDim2.fromScale(0.9, 0.5)
	coverTitle.TextScaled = true
	coverTitle.TextXAlignment = Enum.TextXAlignment.Center
	coverTitle.ZIndex = band.ZIndex + 1
	coverProgress = UIKit.label(band, "", Enum.Font.FredokaOne, 24, Color3.fromRGB(255, 230, 200))
	coverProgress.Position = UDim2.fromScale(0.05, 0.6)
	coverProgress.Size = UDim2.fromScale(0.9, 0.32)
	coverProgress.TextScaled = true
	coverProgress.TextXAlignment = Enum.TextXAlignment.Center
	coverProgress.ZIndex = band.ZIndex + 1

	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.Position = UDim2.fromScale(0.18, 0.85)
	track.Size = UDim2.fromScale(0.64, 0.025)
	track.BackgroundColor3 = Color3.new(0, 0, 0)
	track.BackgroundTransparency = 0.5
	track.ZIndex = coverArt.ZIndex + 2
	track.Parent = coverPage
	UIKit.corner(track, 6)
	coverFill = Instance.new("Frame")
	coverFill.Size = UDim2.fromScale(0, 1)
	coverFill.BackgroundColor3 = Color3.fromRGB(255, 230, 160)
	coverFill.ZIndex = track.ZIndex + 1
	coverFill.Parent = track
	UIKit.corner(coverFill, 6)
	coverValue = UIKit.label(coverPage, "", Enum.Font.FredokaOne, 24, COVER_TEXT)
	coverValue.Position = UDim2.fromScale(0.1, 0.885)
	coverValue.Size = UDim2.fromScale(0.8, 0.055)
	coverValue.TextScaled = true
	coverValue.TextXAlignment = Enum.TextXAlignment.Center
	coverValue.ZIndex = coverArt.ZIndex + 2
	-- A dark outline keeps the cover text readable over bright art
	for _, label in { coverTitle, coverProgress, coverValue } do
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(40, 20, 10)
		stroke.Thickness = 2
		stroke.Transparency = 0.25
		stroke.Parent = label
	end
end

-- The sheet that turns (flipTo): page-coloured, clipping a page-sized holder for the turning cards, with a
-- shade that darkens as it folds edge-on
local function buildFlipSheet()
	local look = Collection.BOOK
	flipSheet = Instance.new("Frame")
	flipSheet.Name = "TurningPage"
	flipSheet.BackgroundColor3 = look.PAGE_COLOR
	flipSheet.ClipsDescendants = true
	flipSheet.Visible = false
	flipSheet.ZIndex = pages[1].ZIndex + 2
	flipSheet.Parent = book
	UIKit.corner(flipSheet, 14)
	UIKit.outline(flipSheet, look.EDGE, 1.5)
	flipContent = Instance.new("Frame")
	flipContent.Name = "Cards"
	flipContent.BackgroundTransparency = 1
	flipContent.ZIndex = flipSheet.ZIndex
	flipContent.Parent = flipSheet
	local grid = pageGrids[1]:Clone()
	grid.Parent = flipContent
	table.insert(pageGrids, grid)
	flipShade = Instance.new("Frame")
	flipShade.Name = "Shade"
	flipShade.Size = UDim2.fromScale(1, 1)
	flipShade.BackgroundColor3 = Color3.fromRGB(20, 26, 50)
	flipShade.BackgroundTransparency = 1
	flipShade.BorderSizePixel = 0
	flipShade.ZIndex = flipSheet.ZIndex + 5
	flipShade.Parent = flipSheet
	local shadeGlint = Instance.new("UIGradient") -- the edge nearest the spine catches the light
	shadeGlint.Transparency = NumberSequence.new(0, 0.35)
	shadeGlint.Parent = flipShade
	flipLift = Instance.new("UIScale")
	flipLift.Parent = flipSheet

	flipShadow = Instance.new("Frame")
	flipShadow.Name = "TurnShadow"
	flipShadow.BackgroundColor3 = Color3.new(0, 0, 0)
	flipShadow.BorderSizePixel = 0
	flipShadow.Visible = false
	flipShadow.ZIndex = flipSheet.ZIndex - 1
	flipShadow.Parent = book
	flipShadowFade = Instance.new("UIGradient")
	flipShadowFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	flipShadowFade.Parent = flipShadow
end

-- The binder's case: dark leather with a soft sheen and a stitched seam just inside its edge
function buildCase()
	local look = Collection.BOOK
	book.BackgroundColor3 = Color3.new(1, 1, 1)
	book.ZIndex = panel.ZIndex
	book.Parent = bookHolder
	UIKit.corner(book, 20)
	UIKit.outline(book, look.CASE_DARK, 3)
	local leather = Instance.new("UIGradient")
	leather.Color = ColorSequence.new(look.CASE, look.CASE_DARK)
	leather.Rotation = 70
	leather.Parent = book
	local seam = Instance.new("Frame")
	seam.Name = "Stitching"
	seam.Position = UDim2.fromOffset(6, 6)
	seam.Size = UDim2.new(1, -12, 1, -12)
	seam.BackgroundTransparency = 1
	seam.ZIndex = book.ZIndex
	seam.Parent = book
	UIKit.corner(seam, 16)
	UIKit.outline(seam, look.STITCH, 1.5).Transparency = 0.45
end

-- A chrome bar down the middle with three rings over it, holding the pages
function buildSpine()
	local look = Collection.BOOK
	local rail = Instance.new("Frame")
	rail.Name = "Spine"
	rail.AnchorPoint = Vector2.new(0.5, 0)
	rail.Position = UDim2.new(0.5, 0, 0, 22)
	rail.Size = UDim2.new(0, 14, 1, -44)
	rail.BackgroundColor3 = Color3.new(1, 1, 1)
	rail.ZIndex = book.ZIndex + 6
	rail.Parent = book
	UIKit.corner(rail, 7)
	local railShine = Instance.new("UIGradient")
	railShine.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, look.CHROME[2]),
		ColorSequenceKeypoint.new(0.4, look.CHROME[1]),
		ColorSequenceKeypoint.new(1, look.CHROME[2]),
	})
	railShine.Parent = rail
	for _, y in { 0.2, 0.5, 0.8 } do
		local ring = Instance.new("Frame")
		ring.Name = "Ring"
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, y)
		ring.Size = UDim2.new(0.075, 0, 0.065, 0) -- scales with the book
		ring.BackgroundTransparency = 1
		ring.ZIndex = book.ZIndex + 7
		ring.Parent = book
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = ring
		local metal = UIKit.outline(ring, Color3.new(1, 1, 1), 3)
		local shine = Instance.new("UIGradient")
		shine.Color = ColorSequence.new(look.CHROME[1], look.CHROME[2])
		shine.Rotation = 90
		shine.Parent = metal
	end
end

-- A round arrow button beside the book, with its key chip
local function arrowButton(parent: Instance, text: string, key: string, onClick: () -> ()): TextButton
	local button = UIKit.button(parent, text, UIKit.Colors.Accent)
	button.Size = UDim2.fromOffset(64, 64)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 30
	addKeyChip(button, key)
	button.Activated:Connect(onClick)
	return button
end

local function buildPanel(parent: Instance)
	local list: ScrollingFrame
	panel, list = UIKit.panel(parent, "Binder", "Binder")
	list:Destroy() -- the binder uses pages instead of a scrolling list
	-- Full screen, the world dimmed behind; no header (the book is the screen)
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 1
	-- The dimmed backdrop is its own screen that covers Roblox's top bar strip too (a normal screen starts below
	-- it), drawn behind the binder; the buttons stay below the bar
	backdropGui = Instance.new("ScreenGui")
	backdropGui.Name = "BinderBackdrop"
	backdropGui.IgnoreGuiInset = true
	backdropGui.ResetOnSpawn = false
	backdropGui.DisplayOrder = -1
	backdropGui.Enabled = false
	backdropGui.Parent = player:WaitForChild("PlayerGui")
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = Collection.BOOK.BACKDROP_TRANSPARENCY
	backdrop.BorderSizePixel = 0
	backdrop.Active = true -- clicks on the backdrop don't reach the world
	backdrop.Parent = backdropGui
	bookGui = Instance.new("ScreenGui")
	bookGui.Name = "BinderBook"
	bookGui.IgnoreGuiInset = true
	bookGui.ResetOnSpawn = false
	bookGui.DisplayOrder = -1 -- under the main screen, so its panels (Rarity guide, tooltips) open over the book
	bookGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	bookGui.Enabled = false
	bookGui.Parent = backdropGui.Parent
	backdropGui.DisplayOrder = -2
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		backdropGui.Enabled = panel.Visible and bookHolder.Visible
		bookGui.Enabled = panel.Visible and not bagOverlay.Visible
	end)
	local sizeLimit = panel:FindFirstChildOfClass("UISizeConstraint")
	if sizeLimit then
		sizeLimit:Destroy()
	end
	for _, name in { "Header", "Title" } do
		local item = panel:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
	local edge = panel:FindFirstChildOfClass("UIStroke")
	if edge then
		edge:Destroy()
	end
	local corner = panel:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Destroy()
	end
	local close = panel:FindFirstChild("Close") :: GuiObject?
	if close then
		close.Position = UDim2.new(1, -16, 0, 16)
	end

	-- The book: holder keeps the shape and position (it slides when Filters open), the scale shrinks it
	bookHolder = Instance.new("Frame")
	bookHolder.Name = "BookHolder"
	bookHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	bookHolder.Position = UDim2.fromScale(0.5, 0.5)
	bookHolder.Size = UDim2.fromScale(0.8, 0.8) -- layoutBook sizes it to the screen
	bookHolder.BackgroundTransparency = 1
	bookHolder.ZIndex = panel.ZIndex
	bookHolder.Parent = bookGui
	bookScale = Instance.new("UIScale")
	bookScale.Parent = bookHolder

	book = Instance.new("Frame")
	book.Name = "Book"
	book.Size = UDim2.fromScale(1, 1)
	buildCase()
	pages = { makePage(book, true), makePage(book, false) }
	buildCover(pages[1])
	buildFlipSheet()
	buildSpine()

	-- Set tabs: bookmarks sticking out of the book's left edge, tucked under it
	local tabIndex = 0
	local look = Collection.BOOK
	for _, set in Collection.SETS do
		if Cards.BySet[set] then
			local tab = UIKit.button(bookHolder, string.gsub(string.upper(set), " ", "\n"), UIKit.Colors.Row)
			tab.Name = "SetTab" .. string.gsub(set, " ", "")
			tab.AnchorPoint = Vector2.new(1, 0)
			tab.Position = UDim2.new(0, 12, 0, 40 + tabIndex * (look.TAB_HEIGHT + 8))
			tab.Size = UDim2.fromOffset(look.TAB_WIDTH + 12, look.TAB_HEIGHT)
			tab.TextScaled = true
			tab.TextWrapped = true
			tab.ZIndex = book.ZIndex - 1
			local tabPadding = tab:FindFirstChildOfClass("UIPadding")
			if tabPadding then
				tabPadding.PaddingLeft = UDim.new(0, 6)
				tabPadding.PaddingRight = UDim.new(0, 18) -- the tucked-in part
			end
			tab.Activated:Connect(function()
				openSet(set)
			end)
			setTabs[set] = tab
			tabIndex += 1
		end
	end

	-- Page counter on the book's bottom edge like a binder tab, an arrow either side (Q/E one spread)
	local counter = Instance.new("Frame")
	counter.Name = "Counter"
	counter.AnchorPoint = Vector2.new(0.5, 0)
	counter.Position = UDim2.new(0.5, 0, 1, 6) -- just under the book, clear of the pockets
	counter.Size = UDim2.fromOffset(128, 36)
	counter.BackgroundColor3 = Color3.fromRGB(20, 28, 60)
	counter.ZIndex = book.ZIndex + 8
	counter.Parent = bookHolder
	UIKit.corner(counter, 20)
	pageLabel = UIKit.label(counter, "", Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	pageLabel.Size = UDim2.fromScale(1, 1)
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center

	local leftArrows = Instance.new("Frame")
	leftArrows.AnchorPoint = Vector2.new(1, 0.5)
	leftArrows.Position = UDim2.new(0, -(Collection.BOOK.TAB_WIDTH + 24), 0.5, 0) -- clear of the set tabs
	leftArrows.Size = UDim2.fromOffset(64, 64)
	leftArrows.BackgroundTransparency = 1
	leftArrows.Parent = bookHolder
	local leftList = Instance.new("UIListLayout")
	leftList.Padding = UDim.new(0, 16)
	leftList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftList.Parent = leftArrows
	table.insert(arrowLanes, leftArrows)
	arrowButton(leftArrows, "<", "Q", function()
		task.spawn(flipTo, spreadIndex - 1)
	end).LayoutOrder = 1

	local rightArrows = leftArrows:Clone()
	for _, child in rightArrows:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	rightArrows.AnchorPoint = Vector2.new(0, 0.5)
	rightArrows.Position = UDim2.new(1, 20, 0.5, 0)
	rightArrows.Parent = bookHolder
	table.insert(arrowLanes, rightArrows)
	arrowButton(rightArrows, ">", "E", function()
		task.spawn(flipTo, spreadIndex + 1)
	end).LayoutOrder = 1

	-- Filters (F), top right next to the close button
	filterButton = UIKit.button(panel, "", UIKit.Colors.Row)
	local filterIcon = Icon.make(filterButton, "Search", UDim2.fromOffset(28, 28))
	filterIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	filterIcon.Position = UDim2.fromScale(0.5, 0.45)
	filterIcon.ZIndex = filterButton.ZIndex + 1
	filterButton.Name = "FilterButton"
	filterButton.AnchorPoint = Vector2.new(1, 0)
	filterButton.Position = UDim2.new(1, -84, 0, 16)
	filterButton.Size = UDim2.fromOffset(52, 52)
	filterButton.TextSize = 24
	addKeyChip(filterButton, "F")
	filterButton.Activated:Connect(function()
		setFiltersOpen(not filtersPanel.Visible)
	end)
	buildFilters(panel)

	-- Set progress, bottom right
	local progress = Instance.new("Frame")
	progress.Name = "SetProgress"
	progress.AnchorPoint = Vector2.new(1, 1)
	progress.Position = UDim2.new(1, -12, 1, -6)
	progress.Size = UDim2.fromOffset(280, 46)
	progress.BackgroundColor3 = Collection.BOOK.CASE
	progress.ZIndex = panel.ZIndex + 1
	progress.Parent = panel
	progressCard = progress
	UIKit.corner(progress, 12)
	UIKit.outline(progress, Collection.BOOK.EDGE, 2)
	progressName = UIKit.label(progress, "", Enum.Font.FredokaOne, 20, Collection.BOOK.INK)
	progressName.Position = UDim2.fromOffset(12, 2)
	progressName.Size = UDim2.new(1, -110, 0, 22)
	progressValue = UIKit.label(progress, "", Enum.Font.FredokaOne, 20, VALUE_COLOR)
	progressValue.AnchorPoint = Vector2.new(1, 0)
	progressValue.Position = UDim2.new(1, -12, 0, 2)
	progressValue.Size = UDim2.fromOffset(100, 22)
	progressValue.TextXAlignment = Enum.TextXAlignment.Right
	progressCount = UIKit.label(progress, "", Enum.Font.FredokaOne, 16, Collection.BOOK.SUBTEXT)
	progressCount.Position = UDim2.fromOffset(12, 24)
	progressCount.Size = UDim2.fromOffset(110, 20)
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 124, 0, 31)
	track.Size = UDim2.new(1, -144, 0, 8)
	track.BackgroundColor3 = Color3.fromRGB(60, 66, 88)
	track.Parent = progress
	UIKit.corner(track, 4)
	progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.Parent = track
	UIKit.corner(progressFill, 4)

	-- Rarity guide, bottom left
	rarityGuideButton = UIKit.button(panel, "Rarity guide", UIKit.Colors.Row)
	rarityGuideButton.Name = "RarityGuide"
	rarityGuideButton.AnchorPoint = Vector2.new(0, 1)
	rarityGuideButton.Position = UDim2.new(0, 12, 1, -6)
	rarityGuideButton.Size = UDim2.fromOffset(170, 44)
	rarityGuideButton.TextSize = 17
	rarityGuideButton.Font = Enum.Font.FredokaOne
	local guideIcon = Icon.make(rarityGuideButton, "Info", UDim2.fromOffset(26, 26))
	guideIcon.ZIndex = rarityGuideButton.ZIndex + 1
	rarityGuideButton.Activated:Connect(RarityGuideController.Open)

	tooltip = Instance.new("Frame")
	tooltip.Name = "BinderTooltip"
	tooltip.Size = UDim2.fromOffset(TOOLTIP_WIDTH, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.Y
	tooltip.BackgroundColor3 = UIStyle.PANEL
	tooltip.ZIndex = 50
	tooltip.Visible = false
	tooltip.Parent = parent
	UIKit.corner(tooltip, 12)
	UIKit.outline(tooltip, UIStyle.EDGE, UIStyle.EDGE_THICKNESS)
	local tooltipPadding = Instance.new("UIPadding")
	tooltipPadding.PaddingTop = UDim.new(0, 10)
	tooltipPadding.PaddingBottom = UDim.new(0, 10)
	tooltipPadding.PaddingLeft = UDim.new(0, 10)
	tooltipPadding.PaddingRight = UDim.new(0, 10)
	tooltipPadding.Parent = tooltip
	tooltip:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTooltip) -- it sizes itself after its content

	for _, card in Cards.List do
		table.insert(tiles, buildTile(card, panel))
	end
	CardDetailController.Build(panel, {
		getEntries = getEntries,
		displayedCount = function(cardId: string): number
			local shown = getCount(displayed, cardId)
			return shown.normal + shown.foil
		end,
		stacks = function(cardId: string)
			return graded[cardId] or {}
		end,
		working = function()
			return working
		end,
		partied = function()
			return partied
		end,
		beasts = function()
			return beasts
		end,
		setInspecting = setInspecting,
	})
	buildBag(panel) -- before the first layout: it places the Cards / Bag tabs
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBook)
	bookGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBook)
	layoutBook()
	fitPockets()
	refreshSet()
	applyFilter()
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		hideTooltip()
		Hud.setHidden("Binder", panel.Visible)
		if not panel.Visible then
			CardDetailController.Close() -- closes the inspector too
		end
		if not panel.Visible and filtersPanel.Visible then
			filtersPanel.Visible = false
			layoutBook()
		end
	end)
end

local function onCollectionChanged(payload: { stacks: Stacks, beasts: { [string]: Beast } })
	if typeof(payload) ~= "table" then
		return
	end
	graded = if typeof(payload.stacks) == "table" then payload.stacks else {}
	collection = sumGrades(graded)
	beasts = if typeof(payload.beasts) == "table" then payload.beasts else {}
	working = if typeof((payload :: any).working) == "table" then (payload :: any).working else {}
	partied = if typeof((payload :: any).partied) == "table" then (payload :: any).partied else {}
	refresh()
end

-- Typing in a text box or the chat bar (the chat bar isn't a TextBox the game can see)
local function isTyping(): boolean
	if UserInputService:GetFocusedTextBox() then
		return true
	end
	local chatBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	return chatBar ~= nil and chatBar.IsFocused
end

local function toggle()
	CardDetailController.Close()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refresh() -- displayed cards may have sold since last time
	end
end

-- Inventory: open the binder on the Bag tab, or close it if the Bag is already showing
local function toggleBag()
	if panel.Visible and bagOverlay.Visible then
		toggle()
	else
		if not panel.Visible then
			toggle()
		end
		showTab(true)
	end
end

-- Bottom-centre tiles: Cards (the binder) and Bag
local function buildButtons()
	Hud.tile({ id = "Cards", icon = "Cards", label = "Cards", key = "B", group = "Bottom", order = 1, onClick = toggle })
	Hud.tile({ id = "Bag", icon = "Bag", label = "Bag", key = "I", group = "Bottom", order = 2, onClick = toggleBag })
end

-- Batches bursts of card parts appearing or leaving into one refresh
local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(function()
		refreshQueued = false
		refresh()
	end)
end

-- Refreshes when a card goes on display, sells or comes off, so "on display" counts stay right
local function watchOwnPlot()
	for _, connection in plotConnections do
		connection:Disconnect()
	end
	table.clear(plotConnections)
	local plotId = player:GetAttribute("PlotId")
	if typeof(plotId) ~= "number" then
		return
	end
	local shelves = workspace:WaitForChild("Plots"):WaitForChild("Plot" .. plotId):WaitForChild("Shelves")
	local function onChanged(instance: Instance)
		if instance:GetAttribute("CardId") ~= nil then
			queueRefresh()
		end
	end
	table.insert(plotConnections, shelves.DescendantAdded:Connect(onChanged))
	table.insert(plotConnections, shelves.DescendantRemoving:Connect(onChanged))
	queueRefresh()
end

-- The cards in the player's binder (not counting ones on display), summed over grades
function BinderController.GetCollection(): { [string]: Owned }
	return collection
end

-- The plain copies in the binder by card, then grade
function BinderController.GetGradedStacks(): Stacks
	return graded
end

-- The player's levelled cards (not counting ones on display)
-- Cards working a shop job: beastId -> job
function BinderController.GetWorking(): { [string]: string }
	return working
end

-- Opens the binder on its pages (from the Jobs or Party panel), with a hint saying what to do next
function BinderController.Open(hint: string?)
	if not panel.Visible then
		toggle()
	end
	if hint then
		hintToast = UIController.Notify(hint, false, 4)
	end
end

-- Cards in the party: beastId -> true
function BinderController.GetPartied(): { [string]: boolean }
	return partied
end

function BinderController.GetBeasts(): { [string]: Beast }
	return beasts
end

function BinderController.Start()
	local screenGui = UIController.GetScreenGui()
	buildPanel(screenGui)
	buildButtons()
	refresh()

	-- Phones: a swipe across the open binder turns the page (left = next)
	if Collection.BOOK.SWIPE then
		UserInputService.TouchSwipe:Connect(function(direction)
			if not panel.Visible or bagOverlay.Visible or CardDetailController.IsOpen() or RarityGuideController.IsOpen() then
				return
			end
			if direction == Enum.SwipeDirection.Left then
				task.spawn(flipTo, spreadIndex + 1)
			elseif direction == Enum.SwipeDirection.Right then
				task.spawn(flipTo, spreadIndex - 1)
			end
		end)
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == BINDER_KEY then
			toggle()
			return
		end
		-- Windows over the binder (the Rarity guide) keep the keys
		if not panel.Visible or bagOverlay.Visible or CardDetailController.IsOpen() or isTyping() or RarityGuideController.IsOpen() then
			return
		end
		local step = PAGE_KEYS[input.KeyCode]
		if step then
			task.spawn(flipTo, spreadIndex + step)
		elseif input.KeyCode == Enum.KeyCode.F then
			setFiltersOpen(not filtersPanel.Visible)
		end
	end)
	-- I opens the Bag. Roblox's camera binds I (zoom) through ContextActionService and swallows it before
	-- InputBegan sees it, so the Bag binds there too, above the camera's priority. Bound actions never fire
	-- while the player types (chat, text boxes).
	ContextActionService:BindActionAtPriority("OpenBag", function(_, state)
		if state ~= Enum.UserInputState.Begin or isTyping() then
			return Enum.ContextActionResult.Pass
		end
		toggleBag()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + BAG_PRIORITY_MARGIN, BAG_KEY)

	Remotes.CollectionChanged.OnClientEvent:Connect(onCollectionChanged)
	-- Party slot names in the "Which party slot?" chooser
	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.slots) ~= "table" then
			return
		end
		local slots = {}
		for _, entry in payload.slots do
			if typeof(entry) == "table" and typeof(entry.slot) == "number" and typeof(entry.beastId) == "string" then
				slots[entry.slot] = entry.beastId
			end
		end
		CardDetailController.SetPartySlots(slots)
	end)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items)
		bagItems = if typeof(items) == "table" then items else {}
		if bagOverlay.Visible then
			renderBag()
		end
	end)
	Remotes.RequestCollection:FireServer()
	Remotes.RequestParty:FireServer()
	Remotes.RequestItems:FireServer()
	player:GetAttributeChangedSignal("PlotId"):Connect(watchOwnPlot)
	task.spawn(watchOwnPlot)
end

return BinderController
