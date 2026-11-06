--!strict
-- Binder: a real 3D ring binder lying open on a desk (Util/BinderDesk; spec 2026-10-29-3d-binder-design.md), one
-- set at a time (divider tabs on its right edge). Spread 1 is the set's cover and page 1; later spreads are two
-- pages of 3 x 3 pockets, owned cards in colour with counts, missing ones as "?" slots. Turn pages with the arrows
-- or Q/E; Filters (F) narrow and sort the pages while the camera moves the binder aside.
-- Only the pockets on the open spread are drawn (and their effects run), so a big collection stays cheap.
-- Tap an owned card to see it large. Cards earn money only from a showcase, so the binder just
-- shows what you have; cards on display in your cases count towards completion.
-- The server sends the binder whenever it changes; displayed cards are read from your plot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Collection = require(Config:WaitForChild("Collection"))
local BinderCovers = require(Config:WaitForChild("BinderCovers"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local Desk = require(Config:WaitForChild("BinderDesk"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local BinderSpreads = require(Shared:WaitForChild("Util"):WaitForChild("BinderSpreads"))
local PageCurl = require(Shared:WaitForChild("Util"):WaitForChild("PageCurl"))
local BinderGesture = require(Shared:WaitForChild("Util"):WaitForChild("BinderGesture"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local Bosses = require(Config:WaitForChild("Bosses"))
local Weapons = require(Config:WaitForChild("Weapons"))
local WeaponRules = require(Shared:WaitForChild("Util"):WaitForChild("WeaponRules"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Place = require(Shared:WaitForChild("Util"):WaitForChild("Place"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local WeaponFace = require(ClientUtil:WaitForChild("WeaponFace"))
local CardTips = require(ClientUtil:WaitForChild("CardTips"))
local BossTints = require(ClientUtil:WaitForChild("BossTints"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local BinderDesk = require(ClientUtil:WaitForChild("BinderDesk"))
local PageTurner = require(ClientUtil:WaitForChild("PageTurner"))
local UIController = require(Controllers:WaitForChild("UIController"))
local RarityGuideController = require(Controllers:WaitForChild("RarityGuideController"))
local CardDetailController = require(Controllers:WaitForChild("CardDetailController"))
local WeaponDetailController = require(Controllers:WaitForChild("WeaponDetailController"))

type Card = typeof(Cards.List[1])
type Owned = { normal: number, foil: number }
type Stacks = { [string]: { [string]: Owned } } -- cardId -> grade -> counts
type Beast = { id: string, cardId: string, foil: boolean, level: number, xp: number, stars: number, grade: string }
-- One row in the card view: a stack of plain copies (one grade, foil or not) or a levelled card
type Entry = { key: string, power: number, value: number, beast: Beast?, grade: string, foil: boolean, count: number }

type Tile = {
	card: Card,
	root: Frame, -- sits in a pocket slot on a page canvas (BinderDesk); input comes from picking, not the frame
	inner: Frame,
	stroke: UIStroke,
	countLabel: TextLabel,
	levelLabel: TextLabel, -- best grade and best levelled copy, e.g. "S · Lv 12"
	drawn: string?, -- what its face shows (renderTile redraws only when this changes: building faces is costly)
}

-- A pocket is the card plus a chip row under it (copies owned, best grade and level), in page-canvas pixels
-- (a page is Desk.PAGE_PIXELS_PER_STUD px a stud, about 1.6 canvas px to a screen px on a desktop)
local CARD_ASPECT = 0.7
local CHIP_ROW = 44
local CHIP_TEXT = 32
local POCKETS_PER_PAGE = Desk.POCKETS.columns * Desk.POCKETS.rows
local TOOLTIP_WIDTH = 260
local TOOLTIP_GAP = 8
local ALL_FILTER, OWNED_FILTER, MISSING_FILTER = "All", "Owned", "Missing"
local PAGE_KEYS = { [Enum.KeyCode.Q] = -1, [Enum.KeyCode.E] = 1 }
local BINDER_KEY = Enum.KeyCode.B
local BAG_KEY = Enum.KeyCode.I -- inventory: the Bag window
local BAG_PRIORITY_MARGIN = 100 -- above every built-in binding (the camera's I zoom included)
local VALUE_COLOR = Color3.fromRGB(120, 230, 120)

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

-- The Armory (weapons round 1, Task 10): a third set holding a card per Config/Weapons weapon (WeaponFace draws
-- them), owned ones from WeaponsChanged, locked ones with their forge progress from the Bag's counts
local ARMORY = "Armory"
local ownedWeapons: { [string]: WeaponRules.Owned } = {}
local equippedWeapon = Weapons.STARTER
local armoryItems: { [string]: number } = {}
local armoryCards: { Card } = {}
for index, weapon in Weapons.WEAPONS do
	table.insert(armoryCards, {
		id = `weapon:{weapon.id}`,
		name = weapon.name,
		number = index,
		set = ARMORY,
		rarity = weapon.rarity,
		element = weapon.element or "None",
		weaponId = weapon.id,
	} :: any)
end

-- A set's cards (the Armory's are its weapons)
local function setCards(set: string): { Card }?
	return if set == ARMORY then armoryCards else Cards.BySet[set]
end

-- The weapon an Armory card stands for (nil for a creature card)
local function weaponOf(card: Card): string?
	return (card :: any).weaponId
end
local coverPage: Frame
local coverProgress: TextLabel
local coverArt: ImageLabel
local coverLogo: Frame
local coverLogoSet: string? = nil -- the set the logo is drawn for
local coverValue: TextLabel
local progressName: TextLabel
local progressCount: TextLabel
local progressValue: TextLabel
local progressFill: Frame
local filtersPanel: Frame
local setFiltersOpen: (open: boolean) -> ()
local setInspecting: (on: boolean) -> ()
local renderBag: () -> ()
local getSetArt: (set: string) -> string?
local drawCoverLogo: (lines: { string }, fill: { { number } }, drop: { number }) -> ()
local COVER_LINE = 0.11 -- one line of the cover's logo, as a share of the cover's height
-- 105607.4 -> "105,607" (the cover's worth, whole dollars)
local function wholeDollars(value: number): string
	local text = tostring(math.floor(math.max(0, value)))
	return (string.gsub(string.reverse((string.gsub(string.reverse(text), "(%d%d%d)", "%1,"))), "^,", ""))
end
local rarityGuideButton: TextButton
local filterButton: TextButton
-- The Filters window's switches (round 3, "tidy column"): each shows the current choice; set in buildFilters
local chooseShow: (string) -> () = function() end
local chooseSort: (string) -> () = function() end
local rarityTags: { [string]: (boolean) -> () } = {}
local filterCount: TextLabel? = nil -- "32 of 35 cards"
local filterSearch: TextBox? = nil
local rarityPicks: { [string]: boolean } = {} -- none picked = every rarity
local showFilter = ALL_FILTER -- All, Owned or Missing
local sortBy = "Set" -- Set (card number), Value, Copies or Rarity
local bagOverlay: Frame -- the Bag window (built in buildBag; its own window since round 3)
local bagFit: UIScale -- shrinks the Bag's content to fit small screens
local counter: Frame -- the page counter under the binder
local pageLabel: TextLabel
local spreadIndex = 1 -- the spread the pages show (or are turning from)
local targetSpread = 1 -- where page requests lead; turns run until the pages get there
local redrawQueued = false -- a redraw asked for mid-turn, done once the pages stop
-- A page held by its edge and dragged across: where it goes, how far it is (0-1) and how fast it moves
local dragging: { forward: boolean, to: number, t: number, speed: number, at: number }? = nil
local pocketsPerPage = POCKETS_PER_PAGE
local progressCard: Frame
local arrowLanes: { Frame } = {}
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
	local weaponId = string.match(cardId, "^weapon:(.+)$")
	if weaponId then
		return ownedWeapons[weaponId] ~= nil or weaponId == Weapons.STARTER
	end
	local owned, onDisplay = getOwnedCounts(cardId)
	return owned + onDisplay > 0
end

-- Draws one pocket; true when its face had to be built (it changed), false when only its chips were updated
-- An Armory pocket: the weapon's card, "Equipped" on the one in hand
local function renderWeaponTile(tile: Tile, weaponId: string): boolean
	local record = ownedWeapons[weaponId]
	local have, need = WeaponRules.makeProgress(Weapons, weaponId, armoryItems)
	local progress = if not record and have and need then { have = have, need = need } else nil
	local drawn = WeaponFace.key(weaponId, record, progress)
	local built = tile.drawn ~= drawn
	if built then
		WeaponFace.render(tile.inner, tile.stroke, weaponId, record, progress)
		tile.drawn = drawn
	end
	local mine = record ~= nil or weaponId == Weapons.STARTER
	tile.levelLabel.Visible = false
	tile.countLabel.Visible = mine
	tile.countLabel.Size = UDim2.new(1, 0, 0, CHIP_ROW - 3)
	tile.countLabel.Text = if equippedWeapon == weaponId then "Equipped" else "Owned"
	return built
end

local function renderTile(tile: Tile): boolean
	local weaponId = weaponOf(tile.card)
	if weaponId then
		return renderWeaponTile(tile, weaponId)
	end
	local cardId = tile.card.id
	local inBinder = getCount(collection, cardId)
	local shown = getCount(displayed, cardId)
	local owned, onDisplay = getOwnedCounts(cardId)
	if owned + onDisplay == 0 then
		local built = tile.drawn ~= "missing"
		if built then
			CardFace.renderMissing(tile.inner, tile.stroke, tile.card)
			tile.drawn = "missing"
		end
		tile.countLabel.Visible = false
		tile.levelLabel.Visible = false
		return built
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
	local foil = inBinder.foil + shown.foil > 0 or hasFoilBeast
	local drawn = `{foil}:{growth.level}:{growth.stars}:{growth.grade}`
	local built = tile.drawn ~= drawn
	if built then
		CardFace.render(tile.inner, tile.stroke, tile.card, foil, true, growth)
		tile.drawn = drawn
	end
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
	tile.levelLabel.Text = table.concat(parts, " · ")
	tile.levelLabel.Visible = #parts > 0
	-- With chips the count shrinks to the left part of the row
	local short = #parts > 0
	tile.countLabel.Size = UDim2.new(if short then 0.36 else 1, 0, 0, CHIP_ROW - 3)
	tile.countLabel.Text = if owned == 0 then "shown" elseif short then `x{owned}` else `Owned {owned}`
	return built
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
		table.insert(if BinderSpreads.side(index, offset, pocketsPerPage) == "Left" then left else right, tile)
	end
	return left, right
end

-- Puts a page's tiles into its pocket slots, in order, and draws them
local function placeTiles(list: { Tile }, side: BinderDesk.Side)
	for index, tile in list do
		tile.root.Parent = BinderDesk.slot(side, index)
		renderTile(tile)
	end
end

-- Takes a tile off the pages; its face stays built, so it comes back without a redraw
local function unplace(tile: Tile)
	tile.root.Parent = nil
end

-- Builds the faces of the cards not on the pages, a few a frame (the open set first, then the others), so turning to
-- them or opening another set later only moves them (building nine faces at once costs a frame of 40-70 ms on a
-- SurfaceGui). A newer warm-up replaces a running one.
local WARM_PER_FRAME = 2
local warmGeneration = 0
local function warmTiles()
	warmGeneration += 1
	local generation = warmGeneration
	local order = {}
	for _, tile in tiles do
		if tile.card.set == currentSet then
			table.insert(order, tile)
		end
	end
	for _, tile in tiles do
		if tile.card.set ~= currentSet then
			table.insert(order, tile)
		end
	end
	task.spawn(function()
		local built = 0
		for _, tile in order do
			if generation ~= warmGeneration then
				return
			end
			if not tile.root.Parent and renderTile(tile) then
				built += 1
				if built % WARM_PER_FRAME == 0 then
					RunService.Heartbeat:Wait()
				end
			end
		end
	end)
end

-- Which page a placed tile is on
local function sideOf(tile: Tile): BinderDesk.Side?
	local slot = tile.root.Parent
	if not slot then
		return nil
	end
	local left = BinderDesk.pages()
	return if slot.Parent == left then "Left" else "Right"
end

-- Shows one page of a spread: its tiles in the pocket slots (spread 1's left page is the cover)
local function showSide(side: BinderDesk.Side, spread: number)
	local left, right = getSpreadTiles(spread)
	local list = if side == "Left" then left else right
	local keep: { [Tile]: boolean } = {}
	for _, tile in list do
		keep[tile] = true
	end
	for _, tile in tiles do
		if not keep[tile] and sideOf(tile) == side then
			unplace(tile)
		end
	end
	placeTiles(list, side)
	if side == "Left" then
		coverPage.Visible = spread == 1
	end
end

-- A page's cards as light cards for a page in motion (PageTurner)
local function liteFace(list: { Tile }): BinderDesk.Face
	local face: BinderDesk.Face = {}
	for index, tile in list do
		local card = tile.card
		face[index] = {
			image = CardFace.artImage(card),
			rim = CardFace.getRarityColor(card.rarity),
			missing = not isCollected(card.id),
			number = card.number,
		}
	end
	return face
end

local function updatePageLabel()
	pageLabel.Text = BinderSpreads.label(spreadIndex, BinderSpreads.pages(#visibleTiles, pocketsPerPage))
end

-- Puts the tiles of a spread into the pages at once and draws them; the rest wait off the pages, blank. While a
-- page turns (or is held) the redraw waits until the pages stop.
local function showSpread(index: number)
	if PageTurner.busy() or dragging then
		redrawQueued = true
		return
	end
	spreadIndex = math.clamp(index, 1, getSpreadCount())
	targetSpread = spreadIndex
	showSide("Left", spreadIndex)
	showSide("Right", spreadIndex)
	updatePageLabel()
end

-- Lifts the page between the shown spread and `to` (one step away): the page under it shows `to` at once, the
-- lifted page carries the cards it leaves and the ones it lands with. Returns which way it turns and those faces.
local function liftPage(to: number): (boolean, BinderDesk.Face, BinderDesk.Face)
	local forward = to > spreadIndex
	local fromLeft, fromRight = getSpreadTiles(spreadIndex)
	local toLeft, toRight = getSpreadTiles(to)
	local leaving = liteFace(if forward then fromRight else fromLeft)
	local arriving = liteFace(if forward then toLeft else toRight)
	showSide(if forward then "Right" else "Left", to)
	return forward, leaving, arriving
end

-- A turned page has landed: the page it landed on shows `to` too
local function land(to: number, forward: boolean)
	spreadIndex = to
	showSide(if forward then "Left" else "Right", to)
	updatePageLabel()
end

-- Turns one page at a time toward targetSpread, quicker the further there is to go (PageCurl.turnSeconds), so
-- quick presses riffle through; a redraw asked for meanwhile happens once the pages stop
local function pump()
	if PageTurner.busy() or dragging then
		return
	end
	targetSpread = math.clamp(targetSpread, 1, getSpreadCount())
	if targetSpread == spreadIndex then
		if redrawQueued then
			redrawQueued = false
			showSpread(spreadIndex)
		end
		return
	end
	local to = spreadIndex + (if targetSpread > spreadIndex then 1 else -1)
	local seconds = PageCurl.turnSeconds(Desk.TURN_SECONDS, math.abs(targetSpread - spreadIndex), Desk.MAX_SPEEDUP)
	local forward, leaving, arriving = liftPage(to)
	PageTurner.play(forward, leaving, arriving, seconds, function()
		land(to, forward)
		-- The next page lifts a frame later, so landing and lifting don't share one frame's work
		task.defer(function()
			RunService.Heartbeat:Wait()
			pump()
		end)
	end)
end

-- A page request: one spread on (1) or back (-1), never past the ends
local function turnBy(step: number)
	targetSpread = PageCurl.step(targetSpread, step, getSpreadCount())
	pump()
end

-- Picks the page up by its outer edge (forward: the right page); false when there's no page that way
local function beginDrag(forward: boolean): boolean
	local to = spreadIndex + (if forward then 1 else -1)
	if PageTurner.busy() or dragging or to < 1 or to > getSpreadCount() then
		return false
	end
	local _, leaving, arriving = liftPage(to)
	PageTurner.grab(forward, leaving, arriving)
	dragging = { forward = forward, to = to, t = 0, speed = 0, at = os.clock() }
	return true
end

-- The held page follows the pointer across the binder
local function moveDrag(point: Vector2)
	local drag = dragging
	local offset = BinderDesk.spineOffset(point)
	if not drag or not offset then
		return
	end
	local t = PageCurl.dragTurn(offset, Desk.PAGE_SIZE.X, drag.forward)
	local now = os.clock()
	if now > drag.at then
		drag.speed = (t - drag.t) / (now - drag.at)
	end
	drag.t, drag.at = t, now
	PageTurner.pose(t)
end

-- Lets the held page go: a tap or a page past halfway (or flicked on) finishes the turn, else it falls back
local function endDrag(tapped: boolean)
	local drag = dragging
	if not drag then
		return
	end
	local speed = if os.clock() - drag.at < 0.1 then drag.speed else 0
	local finish = tapped or PageCurl.finishes(drag.t, speed, Desk.FINISH_SPEED)
	PageTurner.release(finish, function(finished)
		dragging = nil
		if finished then
			land(drag.to, drag.forward)
			targetSpread = spreadIndex
		else
			showSide(if drag.forward then "Right" else "Left", spreadIndex) -- the page under it as it was
		end
		pump()
	end)
end

-- Lights up the Filters panel's choices
local function refreshFilterButtons()
	chooseShow(showFilter)
	chooseSort(sortBy)
	for rarity, set in rarityTags do
		set(rarityPicks[rarity] == true)
	end
	local count = filterCount
	if count then
		count.Text = `{#visibleTiles} of {#(setCards(currentSet) or {})} {if currentSet == ARMORY then "weapons" else "cards"}` -- the open set's, not every set's
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
	warmTiles()
end

-- The current set's cover page, set tabs and the progress card
local function refreshSet()
	local owned, total, value = 0, 0, 0
	for _, card in setCards(currentSet) or {} do
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
	if coverLogoSet ~= currentSet then
		coverLogoSet = currentSet
		local cover = BinderCovers.SETS[currentSet]
		if cover then
			drawCoverLogo(cover.lines, cover.fill, cover.drop)
		else
			drawCoverLogo({ string.upper(currentSet) }, { { 255, 255, 255 }, { 255, 240, 220 }, { 255, 225, 190 } }, { 60, 40, 30 })
		end
	end
	coverProgress.Text = `{owned} / {total}`
	coverValue.Text = if currentSet == ARMORY then "Weapons" else `Worth ${wholeDollars(value)}`
	progressName.Text = currentSet
	progressCount.Text = `📖 {owned} / {total}`
	progressValue.Text = if currentSet == ARMORY then "" else string.format("$%.2f", value)
	progressFill.Size = UDim2.fromScale(if total > 0 then owned / total else 0, 1)
	progressFill.BackgroundColor3 = color
	local sets = {}
	for _, set in Collection.SETS do
		if setCards(set) then
			table.insert(sets, set)
		end
	end
	BinderDesk.setTabs(sets, Collection.SET_COLORS, currentSet)
end

local function refresh()
	displayed = readDisplayedCards()
	refreshSet()
	applyFilter()
	CardDetailController.Refresh()
end

local function openSet(set: string)
	if not setCards(set) then
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

-- The pocket a placed tile sits in: its page and slot number
local function slotOf(tile: Tile): (BinderDesk.Side?, number?)
	local slot = tile.root.Parent
	if not slot then
		return nil, nil
	end
	local page = slot.Parent
	local left = BinderDesk.pages()
	local index = tonumber(string.match(slot.Name, "^Slot(%d+)$"))
	return if page == left then "Left" else "Right", index
end

-- Beside the hovered card (round 5, spec section 2): right of its pocket, else left of it, else above or under it;
-- never over that card, though it may cover its neighbours. The binder's rects are in GUI space, like the tooltip's
-- screen.
local function placeTooltip()
	local tile = tooltipTile
	if not tile or not tooltip.Visible then
		return
	end
	local side, index = slotOf(tile)
	if not side or not index then
		return
	end
	local screen = tooltip.Parent :: GuiObject
	local origin = screen.AbsolutePosition
	local pocket = BinderDesk.pocketRect(side, index)
	local anchor = { x = pocket.x - origin.X, y = pocket.y - origin.Y, w = pocket.w, h = pocket.h }
	local spot = UiLayout.beside(
		anchor,
		{ w = tooltip.AbsoluteSize.X, h = tooltip.AbsoluteSize.Y },
		{ w = screen.AbsoluteSize.X, h = screen.AbsoluteSize.Y },
		TOOLTIP_GAP,
		anchor
	)
	tooltip.Position = UDim2.fromOffset(spot.x, spot.y)
end

-- touch: a finger held on the card (phones have no mouse)
local function showTooltip(tile: Tile, touch: boolean?)
	-- No tooltip through the open card view, the Bag or the rarity guide, nor on weapons (their card says it all)
	if weaponOf(tile.card) or not (UserInputService.MouseEnabled or touch) or not tile.root.Parent or CardDetailController.IsOpen() or bagOverlay.Visible or RarityGuideController.IsOpen() then
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
	local weaponId = weaponOf(card)
	if weaponId then
		WeaponDetailController.Open(weaponId)
		return
	end
	-- The card view lays itself out by the camera's field of view: give it the normal one before it opens
	BinderDesk.setInspecting(true)
	CardDetailController.Open(card)
	if not CardDetailController.IsOpen() then
		BinderDesk.setInspecting(false)
		return
	end
	if hintToast then
		UIController.Dismiss(hintToast) -- "Tap a card, then ..." is done once a card is open
		hintToast = nil
	end
end

local function buildTile(card: Card): Tile
	local button = Instance.new("Frame")
	button.Name = card.id
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1

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

	-- Chip text shrinks to fit ("B · Lv 4 · Job")
	for _, chip in { countLabel, levelLabel } do
		chip.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = CHIP_TEXT
		fit.Parent = chip
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 3)
		pad.PaddingRight = UDim.new(0, 3)
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingBottom = UDim.new(0, 2)
		pad.Parent = chip
	end

	return { card = card, root = button, inner = inner, stroke = stroke, countLabel = countLabel, levelLabel = levelLabel }
end

-- The card view (CardDetailController): while a card is inspected the tabs, binder buttons and counter hide and the
-- camera goes to the card view's stage (BinderDesk.setInspecting)
function setInspecting(on: boolean)
	counter.Visible = not on
	for _, arrows in arrowLanes do
		arrows.Visible = not on and panel.AbsoluteSize.X >= Collection.BOOK.NARROW_BELOW
	end
	BinderDesk.setInspecting(on)
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

-- Bag: the item inventory (Config/Items), the binder's second tab. A centred inventory window: a grid of slots
-- on the left (items with a count badge, the rest empty), the chosen item's details on the right.
local bagGrid: ScrollingFrame
local bagDetail: Frame
local bagCount: TextLabel
local bagPalette: UIKit.Palette -- the Bag window's cream colours (UIKit.colorsFor), set in buildBag
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
		local hint = bagLabel(bagDetail, "Your items show here. Tap one to see what it does.", Enum.Font.FredokaOne, 16, bagPalette.inkSoft, 24, 60)
		hint.TextXAlignment = Enum.TextXAlignment.Center
		return
	end
	-- The item big on a cream circle (a boss item ringed in its boss's tint), its name and how many you have
	local tint = bossMark(selectedItem)
	local halo = Instance.new("Frame")
	halo.AnchorPoint = Vector2.new(0.5, 0)
	halo.Position = UDim2.new(0.5, 0, 0, 12)
	halo.Size = UDim2.fromOffset(84, 84)
	halo.BackgroundColor3 = bagPalette.slotEmpty
	halo.ZIndex = 33
	halo.Parent = bagDetail
	UIKit.corner(halo, 42)
	UIKit.outline(halo, tint or bagPalette.rowEdge, 3)
	local icon = Icon.make(halo, info.icon, UDim2.fromOffset(62, 62))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 34
	Icon.set(icon, info.icon)
	tintIcon(icon, tint)
	local name = bagLabel(bagDetail, info.name, Enum.Font.FredokaOne, 20, bagPalette.ink, 102, 26)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local owned = bagLabel(bagDetail, `You have {bagItems[selectedItem] or 0}`, Enum.Font.FredokaOne, 15, bagPalette.hint, 128, 20)
	owned.TextXAlignment = Enum.TextXAlignment.Center
	-- What it does / where to get it / how to use it, as cream boxes
	local y = 154
	-- A pack item (Config/Items `open`, the level-up packs): Open it here. The server checks and rolls it; only the main
	-- game has the pack opening, so elsewhere the button isn't offered.
	local openId = selectedItem
	if info.open and (bagItems[openId] or 0) > 0 and not Place.isFrontier() and not Place.isDungeon() then
		local open = UIKit.button(bagDetail, "Open", UIKit.Colors.Accent)
		open.AnchorPoint = Vector2.new(0.5, 0)
		open.Position = UDim2.new(0.5, 0, 0, y)
		open.Size = UDim2.fromOffset(160, 48)
		open.ZIndex = 34
		open.Activated:Connect(function()
			if player:GetAttribute("PackOpeningBusy") == true then
				UIController.Notify("Finish this pack first.", true)
				return
			end
			Remotes.OpenBagPack:FireServer(openId)
			bagOverlay.Visible = false -- out of the way of the pack opening
		end)
		y += 58
	end
	-- With the Open button there, "How to use it" (tap Open) would only repeat it, and there's no room for it
	local howTo = if y > 154 then nil else info.use
	for _, section in { { title = "What it does", text = info.description }, { title = "Where to get it", text = info.source }, { title = "How to use it", text = howTo } } do
		if section.text then
			local box = Instance.new("Frame")
			box.Position = UDim2.fromOffset(12, y)
			box.Size = UDim2.new(1, -24, 0, 62)
			box.BackgroundColor3 = bagPalette.slotEmpty
			box.ZIndex = 33
			box.Parent = bagDetail
			UIKit.corner(box, 10)
			UIKit.outline(box, bagPalette.rowEdge, 2)
			local heading = bagLabel(box, section.title, Enum.Font.FredokaOne, 14, bagPalette.hint, 6, 18)
			heading.Position = UDim2.fromOffset(10, 6)
			heading.Size = UDim2.new(1, -20, 0, 18)
			local body = bagLabel(box, section.text, Enum.Font.Gotham, 13, bagPalette.ink, 26, 32)
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
	slot.BackgroundColor3 = if filled then bagPalette.row else bagPalette.slotEmpty
	slot.ZIndex = 32
	slot.Parent = bagGrid
	UIKit.corner(slot, 14)
	local selected = filled and id == selectedItem
	UIKit.outline(slot, if selected then UIStyle.GOLD else bagPalette.rowEdge, if selected then 3 else 2) -- the chosen one: a gold ring
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
	local countSize = math.max(15, math.ceil(14 / math.max(bagFit.Scale, 0.1)))
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
	badge.BackgroundColor3 = UIStyle.BABY.lilac.deep -- a lilac chip with white text (cotton candy count chips)
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

-- The Bag (owner 2026-11-03, round 3): its own window over the town, like the others (one at a time: opening it
-- closes the binder), built with UIKit.panel; its content (the slots and the chosen item's details) sits under the
-- header in a frame that shrinks to fit small screens
local function buildBag(screen: Instance)
	local list: ScrollingFrame
	bagOverlay, list = UIKit.panel(screen, "Bag", "Bag", "Bag")
	list:Destroy()
	local limit = bagOverlay:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	Icon.header(bagOverlay, "Bag", UIKit.HEADER_HEIGHT)
	bagPalette = UIKit.colorsFor(bagOverlay)
	local header = bagOverlay:FindFirstChild("Header") :: Frame
	bagCount = UIKit.label(header, "", Enum.Font.FredokaOne, 16, Color3.new(1, 1, 1))
	bagCount.AnchorPoint = Vector2.new(1, 0.5)
	bagCount.Position = UDim2.new(1, -64, 0.5, 0) -- clear of the round close button
	bagCount.Size = UDim2.fromOffset(160, 24)
	bagCount.TextXAlignment = Enum.TextXAlignment.Right
	bagCount.ZIndex = header.ZIndex + 2
	UIKit.outlined(bagCount, 2)

	local inner = Vector2.new(BAG.WINDOW.X, BAG.WINDOW.Y - UIKit.HEADER_HEIGHT)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Position = UDim2.fromOffset(0, UIKit.HEADER_HEIGHT)
	content.Size = UDim2.fromOffset(inner.X, inner.Y)
	content.ZIndex = bagOverlay.ZIndex + 1
	content.Parent = bagOverlay
	bagFit = Instance.new("UIScale")
	bagFit.Parent = content
	local function fitWindow()
		local room = (screen :: GuiBase2d).AbsoluteSize
		local scale = math.min(1, (room.X - 24) / BAG.WINDOW.X, (room.Y - 84) / BAG.WINDOW.Y)
		bagFit.Scale = scale
		bagOverlay.Size = UDim2.fromOffset(inner.X * scale, UIKit.HEADER_HEIGHT + inner.Y * scale)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWindow)
	fitWindow()
	bagOverlay:GetPropertyChangedSignal("Visible"):Connect(function()
		if bagOverlay.Visible then
			hideTooltip()
			renderBag()
		end
	end)

	local top = 12
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
	bagGrid.Parent = content
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
	bagDetail.BackgroundColor3 = bagPalette.row
	bagDetail.ZIndex = 32
	bagDetail.Parent = content
	UIKit.corner(bagDetail, 14)
	UIKit.outline(bagDetail, bagPalette.rowEdge, 2)

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

-- A small heading in the Filters window ("SHOW", "SORT BY", "RARITY")
local function sectionLabel(parent: Instance, order: number, text: string)
	local label = UIKit.label(parent, text, Enum.Font.FredokaOne, Collection.FILTERS.heading, UIKit.colorsFor(parent).hint)
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, Collection.FILTERS.headingRow)
	label.TextYAlignment = Enum.TextYAlignment.Bottom
end

-- Back to every card: All, by set, every rarity, no search
local function clearFilters()
	showFilter = ALL_FILTER
	sortBy = "Set"
	rarityPicks = {}
	searchText = ""
	local search = filterSearch
	if search then
		search.Text = ""
	end
	spreadIndex = 1
	applyFilter()
end

-- The Filters window on the right (owner 2026-11-03, round 3 pick A "tidy column"): a cotton candy window with the
-- search box, SHOW and SORT BY as two segmented switches, the rarities as small dot tags, and at the bottom how many
-- cards match and Clear all. The binder moves aside while it's open.
local function buildFilters(parent: Frame)
	local look = Collection.FILTERS
	filtersPanel = Instance.new("Frame")
	filtersPanel.Name = "Filters"
	-- Between the close / Filters buttons (top right) and the set progress card (bottom right)
	filtersPanel.AnchorPoint = Vector2.new(1, 0)
	filtersPanel.Visible = false
	filtersPanel.ZIndex = look.zIndex -- over the binder's close and magnifier when it takes the full height
	filtersPanel.Parent = parent
	-- As tall as its content: under the binder's corner buttons where it fits, else from near the top (over them),
	-- scrolling on a landscape phone (UiLayout.filtersFrame)
	local bodyHeight = UiLayout.filtersBody(look, BabyColors.SEGMENTED.hit, BabyColors.DOT_TAG.hit)
	local function placeFilters()
		local top, height = UiLayout.filtersFrame(parent.AbsoluteSize.Y, look, bodyHeight)
		filtersPanel.Position = UDim2.new(1, -16, 0, top)
		filtersPanel.Size = UDim2.fromOffset(Collection.FILTERS_WIDTH, height)
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeFilters)
	placeFilters()
	UIKit.creamWindow(filtersPanel)
	local palette = UIKit.colorsFor(filtersPanel)
	local header, title = UIKit.header(filtersPanel, "Filters", "Bag") -- the pink band
	local headerIcon = Icon.make(header, "Search", UDim2.fromOffset(30, 30))
	headerIcon.AnchorPoint = Vector2.new(0, 0.5)
	headerIcon.Position = UDim2.new(0, 14, 0.5, 0)
	headerIcon.ZIndex = header.ZIndex + 2
	title.Position += UDim2.fromOffset(36, 0)
	local close = UIKit.closeButton(filtersPanel)
	close.Activated:Connect(function()
		setFiltersOpen(false)
	end)

	-- Room inside every edge, so outlines and glows never get cut off
	local body = Instance.new("ScrollingFrame")
	body.Position = UDim2.fromOffset(look.inset, UIKit.HEADER_HEIGHT + look.inset)
	body.Size = UDim2.new(1, -look.inset * 2, 1, -(UIKit.HEADER_HEIGHT + look.inset * 2 + look.footer))
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = palette.hint
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ZIndex = filtersPanel.ZIndex
	body.Parent = filtersPanel
	local room = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		(room :: any)[side] = UDim.new(0, look.edge)
	end
	room.PaddingRight = UDim.new(0, look.edge + 6) -- and the scroll bar
	room.Parent = body
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, look.gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.LayoutOrder = 1
	search.Size = UDim2.new(1, 0, 0, look.search)
	search.BackgroundColor3 = palette.row
	search.ClearTextOnFocus = false
	search.PlaceholderText = "Search name or #"
	search.Text = ""
	search.Font = Enum.Font.GothamBold
	search.TextSize = 14
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.TextColor3 = palette.ink
	search.PlaceholderColor3 = palette.inkSoft
	search.Parent = body
	UIKit.corner(search, look.search / 2)
	UIKit.outline(search, palette.rowEdge, 2)
	local searchPad = Instance.new("UIPadding")
	searchPad.PaddingLeft = UDim.new(0, 38)
	searchPad.Parent = search
	local glass = Icon.make(search, "Search", UDim2.fromOffset(20, 20))
	glass.AnchorPoint = Vector2.new(0, 0.5)
	glass.Position = UDim2.new(0, -28, 0.5, 0)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		spreadIndex = 1
		applyFilter()
	end)
	filterSearch = search

	sectionLabel(body, 2, "SHOW")
	local show
	show, chooseShow = UIKit.segmented(body, { ALL_FILTER, OWNED_FILTER, MISSING_FILTER }, function(value)
		showFilter = value
		spreadIndex = 1
		applyFilter()
	end)
	show.LayoutOrder = 3
	sectionLabel(body, 4, "SORT BY")
	local sort
	sort, chooseSort = UIKit.segmented(body, { "Set", "Value", "Copies", "Rarity" }, function(value)
		sortBy = value
		spreadIndex = 1
		applyFilter()
	end)
	sort.LayoutOrder = 5
	sectionLabel(body, 6, "RARITY")
	local chips = Instance.new("Frame")
	chips.LayoutOrder = 7
	chips.Size = UDim2.new(1, 0, 0, 0)
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.BackgroundTransparency = 1
	chips.Parent = body
	local flow = Instance.new("UIListLayout")
	flow.FillDirection = Enum.FillDirection.Horizontal
	flow.Wraps = true
	flow.Padding = UDim.new(0, look.gap)
	flow.SortOrder = Enum.SortOrder.LayoutOrder
	flow.Parent = chips
	local rarities: { string } = {}
	for name in Rarities.Tiers do
		table.insert(rarities, name)
	end
	table.sort(rarities, function(a, b)
		return Rarities.Tiers[a].order < Rarities.Tiers[b].order
	end)
	for index, rarity in rarities do
		local tag, set = UIKit.dotTag(chips, rarity, Rarities.Tiers[rarity].color)
		tag.LayoutOrder = index
		tag.Activated:Connect(function()
			rarityPicks[rarity] = if rarityPicks[rarity] then nil else true
			spreadIndex = 1
			applyFilter()
		end)
		rarityTags[rarity] = set
	end

	-- How many cards match, and Clear all
	local foot = Instance.new("Frame")
	foot.Name = "Footer"
	foot.BackgroundTransparency = 1
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.new(0, look.inset + look.edge, 1, -look.inset)
	foot.Size = UDim2.new(1, -(look.inset + look.edge) * 2, 0, look.footer)
	foot.ZIndex = filtersPanel.ZIndex
	foot.Parent = filtersPanel
	local count = UIKit.label(foot, "", Enum.Font.GothamBold, 13, palette.inkSoft)
	count.Size = UDim2.new(0.6, 0, 1, 0)
	count.TextYAlignment = Enum.TextYAlignment.Center
	filterCount = count
	local clear = Instance.new("TextButton")
	clear.Name = "ClearAll"
	clear.AnchorPoint = Vector2.new(1, 0.5)
	clear.Position = UDim2.new(1, 0, 0.5, 0)
	clear.Size = UDim2.new(0.4, 0, 0, UIStyle.MIN_TAP)
	clear.BackgroundTransparency = 1
	clear.Font = Enum.Font.FredokaOne
	clear.TextSize = 15
	clear.Text = "Clear all"
	clear.TextXAlignment = Enum.TextXAlignment.Right
	clear.TextColor3 = UIStyle.BABY.pink.deep
	clear.Parent = foot
	clear.Activated:Connect(clearFilters)
end

-- Where the binder goes on screen (viewport pixels, Roblox's top bar strip included): the biggest binder shape
-- between a top and bottom margin and lanes either side; on phones the full height between slim lanes of compact
-- buttons (placeCorners); between the top and bottom rows when the corners would run into it; left of the Filters
-- panel while it's open. The camera fits the 3D binder (tabs included) into it (BinderDesk.frame).
local function getBookRect(filtersOpen: boolean): UiLayout.Rect
	local look = Collection.BOOK
	local camera = workspace.CurrentCamera
	local area = camera.ViewportSize
	local inset = area.Y - panel.AbsoluteSize.Y
	local aspect = BinderDesk.aspect()
	local function fit(left: number, right: number, top: number, bottom: number): UiLayout.Rect
		local width = math.max(200, area.X - left - right)
		local height = math.max(140, area.Y - top - bottom)
		if width / height > aspect then
			width = height * aspect
		else
			height = width / aspect
		end
		return {
			x = left + (area.X - left - right - width) / 2,
			y = top + (area.Y - top - bottom - height) / 2,
			w = width,
			h = height,
		}
	end
	local narrow = area.X < look.NARROW_BELOW
	local filters = if filtersOpen then Collection.FILTERS_WIDTH + 32 else 0
	if narrow then
		return fit(look.NARROW_LEFT, math.max(look.NARROW_RIGHT, filters), look.MARGIN, look.MARGIN_BOTTOM)
	end
	if filtersOpen then
		return fit(look.CORNER_LEFT, filters + look.SIDE_LANE, look.TOP_BAND + inset, look.BOTTOM_BAND)
	end
	local rect = fit(look.SIDE_LANE, look.SIDE_LANE, look.MARGIN, look.MARGIN_BOTTOM)
	if rect.x < look.CORNER_LEFT or rect.x + rect.w > area.X - look.CORNER_RIGHT then
		rect = fit(look.SIDE_LANE, look.SIDE_LANE, look.TOP_BAND + inset, look.BOTTOM_BAND)
	end
	return rect
end

-- The corner buttons: full size in the corners on roomy screens; compact icons in slim side lanes on phones
local function placeCorners(narrow: boolean)
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

-- The page counter just under the binder and an arrow either side of it (GUI space: the rect is viewport pixels)
local function placeAround(rect: UiLayout.Rect)
	local inset = workspace.CurrentCamera.ViewportSize.Y - panel.AbsoluteSize.Y
	local bottom = rect.y + rect.h - inset
	counter.Position = UDim2.fromOffset(rect.x + rect.w / 2, bottom + 6)
	local middle = rect.y + rect.h / 2 - inset
	arrowLanes[1].Position = UDim2.fromOffset(rect.x - 20, middle)
	arrowLanes[2].Position = UDim2.fromOffset(rect.x + rect.w + 20, middle)
end

local function layoutBook()
	placeCorners(workspace.CurrentCamera.ViewportSize.X < Collection.BOOK.NARROW_BELOW)
	local rect = getBookRect(filtersPanel.Visible)
	BinderDesk.frame(rect, false)
	placeAround(rect)
	progressCard.Visible = not (bagOverlay and bagOverlay.Visible) and panel.AbsoluteSize.X >= Collection.BOOK.PROGRESS_FROM
	local roomy = panel.AbsoluteSize.X >= Collection.BOOK.NARROW_BELOW
	for _, arrows in arrowLanes do
		arrows.Visible = roomy and not (bagOverlay and bagOverlay.Visible)
	end
end

function setFiltersOpen(open: boolean)
	local rect = getBookRect(open)
	BinderDesk.frame(rect, true)
	placeAround(rect)
	if open then
		filtersPanel.Visible = true
		Motion.popIn(filtersPanel)
	else
		Motion.popOut(filtersPanel, function()
			filtersPanel.Visible = false
		end)
	end
end

-- The art for a set's cover: its creature-free painting (Config/BinderCovers; spec 2026-11-04-round4-design section 1)
function getSetArt(set: string): string?
	local cover = BinderCovers.SETS[set]
	return if cover then cover.art else nil
end

-- One label of the cover's text, scaled to its box
local function coverLabel(parent: Instance, text: string, color: Color3, zIndex: number): TextLabel
	local label = UIKit.label(parent, text, Enum.Font.FredokaOne, 40, color)
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true -- (setting TextWrapped false afterwards would turn TextScaled off again)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.ZIndex = zIndex
	return label
end

-- The set's name as a candy logo, one line per `lines` entry: a shadow copy in the drop colour a little lower, a thick
-- white outline copy, and the fill on top (a top-to-bottom gradient of the three fill colours). Outlines scale with
-- the cover.
function drawCoverLogo(lines: { string }, fill: { { number } }, drop: { number })
	for _, child in coverLogo:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local function rgb(value: { number }): Color3
		return Color3.fromRGB(value[1], value[2], value[3])
	end
	local base = coverArt.ZIndex + 3
	-- Every line is the same height whatever the count (a one-line name isn't blown up); the star pill sits under it
	coverLogo.Size = UDim2.fromScale(0.84, COVER_LINE * #lines)
	local pill = coverProgress.Parent :: Frame
	pill.Position = UDim2.fromScale(0.5, coverLogo.Position.Y.Scale + COVER_LINE * #lines + 0.02)
	for index, text in lines do
		local line = Instance.new("Frame")
		line.Name = "Line" .. index
		line.BackgroundTransparency = 1
		line.Position = UDim2.fromScale(0, (index - 1) / #lines)
		line.Size = UDim2.fromScale(1, 1 / #lines)
		line.ZIndex = base
		line.Parent = coverLogo
		local shadow = coverLabel(line, text, rgb(drop), base)
		shadow.Name = "Drop"
		shadow.Position = UDim2.fromScale(0, 0.07)
		local outline = coverLabel(line, text, Color3.new(1, 1, 1), base + 1)
		outline.Name = "Outline"
		local face = coverLabel(line, text, Color3.new(1, 1, 1), base + 2)
		face.Name = "Fill"
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(fill[1])),
			ColorSequenceKeypoint.new(0.55, rgb(fill[2])),
			ColorSequenceKeypoint.new(1, rgb(fill[3])),
		})
		gradient.Parent = face
		local strokes: { UIStroke } = {}
		for _, label in { shadow, outline } do
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Color = label.TextColor3
			stroke.Parent = label
			table.insert(strokes, stroke)
		end
		local function fit()
			for _, stroke in strokes do
				stroke.Thickness = math.max(2, line.AbsoluteSize.Y * 0.09)
			end
		end
		line:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	end
end

-- A white pill on the cover (the star progress, the worth): `icon` (a Config/UIIcons name) before the text
local function coverPill(name: string, position: UDim2, width: number, icon: string?): TextLabel
	local pill = Instance.new("Frame")
	pill.Name = name
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = position
	pill.Size = UDim2.fromScale(width, 0.062)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.ZIndex = coverArt.ZIndex + 3
	pill.Parent = coverPage
	UIKit.corner(pill, 999)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(0, 0, 0)
	edge.Transparency = 0.8
	edge.Thickness = 2
	edge.Parent = pill
	local textLeft = 0.08
	if icon then
		local mark = Icon.make(pill, icon, UDim2.fromScale(0.7, 0.7))
		mark.AnchorPoint = Vector2.new(0, 0.5)
		mark.Position = UDim2.fromScale(0.07, 0.5)
		mark.SizeConstraint = Enum.SizeConstraint.RelativeYY
		mark.ZIndex = pill.ZIndex + 1
		Icon.set(mark, icon)
		textLeft = 0.24
	end
	local text = UIKit.label(pill, "", Enum.Font.FredokaOne, 20, UIStyle.CREAM.INK)
	text.Position = UDim2.fromScale(textLeft, 0.14)
	text.Size = UDim2.fromScale(1 - textLeft - 0.08, 0.72)
	text.TextScaled = true
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.ZIndex = pill.ZIndex + 1
	return text
end

-- The set's cover on spread 1's left page (spec 2026-11-04-round4-design section 1): the set's painting over the whole
-- cover (leather in the set's colour when there is none), dark fades at the top and bottom, a thin white frame, the
-- candy logo, a white star pill (owned / total) under it and the worth in a white pill at the bottom.
-- Drawn on the left page's canvas (BinderDesk), over its pocket slots.
local function buildCover(canvas: Frame)
	coverPage = Instance.new("Frame")
	coverPage.Name = "Cover"
	coverPage.AnchorPoint = Vector2.new(0.5, 0.5)
	coverPage.Position = UDim2.fromScale(0.5, 0.5)
	coverPage.Size = UDim2.fromScale(0.92, 0.95)
	coverPage.BackgroundColor3 = Color3.new(1, 1, 1)
	coverPage.ZIndex = 10
	coverPage.Parent = canvas
	UIKit.corner(coverPage, 10)
	local leather = Instance.new("UIGradient")
	leather.Name = "Leather"
	leather.Rotation = 60
	leather.Parent = coverPage
	-- Full art: the painting fills the cover, under everything else
	coverArt = Instance.new("ImageLabel")
	coverArt.Name = "Art"
	coverArt.Size = UDim2.fromScale(1, 1)
	coverArt.BackgroundTransparency = 1
	coverArt.ScaleType = Enum.ScaleType.Crop
	coverArt.ZIndex = coverPage.ZIndex + 1
	coverArt.Parent = coverPage
	UIKit.corner(coverArt, 10)
	-- Dark fades into the art behind the logo and the worth, so they read on any picture
	for _, fade in { { name = "TopFade", y = 0, h = 0.42, rotation = 90, from = 0.3 }, { name = "BottomFade", y = 0.72, h = 0.28, rotation = -90, from = 0.4 } } do
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
			NumberSequenceKeypoint.new(0, fade.from),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = strip
	end

	local emboss = Instance.new("Frame")
	emboss.Name = "Emboss"
	emboss.Position = UDim2.fromScale(0.035, 0.025)
	emboss.Size = UDim2.fromScale(0.93, 0.95)
	emboss.BackgroundTransparency = 1
	emboss.ZIndex = coverArt.ZIndex + 2
	emboss.Parent = coverPage
	UIKit.corner(emboss, 10)
	UIKit.outline(emboss, Color3.new(1, 1, 1), 2).Transparency = 0.5

	coverLogo = Instance.new("Frame")
	coverLogo.Name = "Logo"
	coverLogo.AnchorPoint = Vector2.new(0.5, 0)
	coverLogo.Position = UDim2.fromScale(0.5, 0.045)
	coverLogo.Size = UDim2.fromScale(0.84, COVER_LINE * 2)
	coverLogo.BackgroundTransparency = 1
	coverLogo.ZIndex = coverArt.ZIndex + 3
	coverLogo.Parent = coverPage
	coverProgress = coverPill("Progress", UDim2.fromScale(0.5, 0.285), 0.4, "Star")
	coverValue = coverPill("Worth", UDim2.fromScale(0.5, 0.9), 0.66)
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
	-- The binder keeps its dark look (spec 2026-11-03-cream-windows-design), but its screen's buttons take the cotton
	-- candy look (spec 2026-11-03-cotton-candy-ui-design): the close button, the magnifier, the arrows, the tabs, the
	-- Rarity guide, the filters' buttons
	panel, list = UIKit.panel(parent, "Binder", "Binder", nil, "dark", true)
	list:Destroy() -- the binder uses pages instead of a scrolling list
	-- Full screen and see-through: the 3D binder on its desk fills the screen behind (BinderDesk)
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundTransparency = 1
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

	-- The pages are canvases on the 3D binder; the cover sits on the left one
	local leftCanvas = BinderDesk.pages()
	buildCover(leftCanvas)

	-- Page counter just under the binder like a binder tab, an arrow either side (Q/E one spread); placeAround
	-- moves them with the binder
	counter = Instance.new("Frame")
	counter.Name = "Counter"
	counter.AnchorPoint = Vector2.new(0.5, 0)
	counter.Size = UDim2.fromOffset(128, 36)
	counter.BackgroundColor3 = Color3.fromRGB(20, 28, 60)
	counter.ZIndex = panel.ZIndex + 2
	counter.Parent = panel
	UIKit.corner(counter, 20)
	pageLabel = UIKit.label(counter, "", Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	pageLabel.Size = UDim2.fromScale(1, 1)
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center

	for index, step in { -1, 1 } do
		local lane = Instance.new("Frame")
		lane.AnchorPoint = Vector2.new(if step < 0 then 1 else 0, 0.5)
		lane.Size = UDim2.fromOffset(64, 64)
		lane.BackgroundTransparency = 1
		lane.ZIndex = panel.ZIndex + 2
		lane.Parent = panel
		arrowLanes[index] = lane
		arrowButton(lane, if step < 0 then "<" else ">", if step < 0 then "Q" else "E", function()
			turnBy(step)
		end).Size = UDim2.fromScale(1, 1)
	end

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
	rarityGuideButton.Activated:Connect(function()
		hideTooltip()
		RarityGuideController.Open()
	end)

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
		table.insert(tiles, buildTile(card))
	end
	for _, card in armoryCards do
		table.insert(tiles, buildTile(card))
	end
	WeaponDetailController.SetSource(function()
		return { owned = ownedWeapons, equipped = equippedWeapon, items = armoryItems }
	end)
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
	-- The X closes the card view back to the binder, then the binder
	UIKit.setBackStep(panel, function(): boolean
		if not CardDetailController.IsOpen() then
			return false
		end
		CardDetailController.Close()
		return true
	end)
	buildBag(panel.Parent :: Instance) -- the Bag's own window, on the same screen
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutBook)
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutBook)
	layoutBook()
	refreshSet()
	applyFilter()
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		hideTooltip()
		Hud.setHidden("Binder", panel.Visible)
		if panel.Visible then
			BinderDesk.show()
			layoutBook()
		else
			CardDetailController.Close() -- closes the inspector too
			BinderDesk.hide()
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

-- Inventory: open or close the Bag window (opening it closes the binder: one window at a time)
local function toggleBag()
	bagOverlay.Visible = not bagOverlay.Visible
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
	PageTurner.build() -- before the first turn, so it doesn't lay out its strips mid-turn
	buildButtons()
	RarityGuideController.SetCollected(isCollected)
	refresh()

	-- Pointer gestures on the binder. A pointer over a card lights its pocket and shows its tooltip (a finger: hold
	-- it there without moving). A tap on a card lifts it out of its sleeve into the card view; a tap elsewhere on a
	-- page, on a "?" or an empty pocket turns that way; a swipe across turns too. A press on a page's outer edge that
	-- moves toward the spine picks the page up and drags it over. One pointer owns a press at a time (BinderGesture):
	-- a second finger can't take over a dragged page, and a release that never came is ended on the next press.
	local gesture = BinderGesture.new()
	local press: { pick: BinderDesk.Pick?, edge: boolean?, drag: boolean, held: boolean }? = nil -- what the press is doing
	local heldStep: number? = nil -- Q or E held: keep turning
	local heldNext = 0
	local hoverKey = ""
	local function interactive(): boolean
		return panel.Visible and not bagOverlay.Visible and not CardDetailController.IsOpen() and not RarityGuideController.IsOpen()
	end
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	-- Each finger is its own pointer; the mouse's button and movement are one
	local function pointerId(input: InputObject): unknown
		return if input.UserInputType == Enum.UserInputType.Touch then input else "mouse"
	end
	local function pageStep(side: BinderDesk.Side): number
		return if side == "Right" then 1 else -1
	end
	local function tileAt(side: BinderDesk.Side, index: number): Tile?
		local left, right = getSpreadTiles(spreadIndex)
		return (if side == "Left" then left else right)[index]
	end
	local function clearHover()
		if hoverKey ~= "" then
			hoverKey = ""
			BinderDesk.highlight(nil, nil)
			hideTooltip()
		end
	end
	local function hover(point: Vector2)
		local pick = if interactive() and not PageTurner.busy() then BinderDesk.pick(point) else nil
		if pick and pick.kind == "pocket" then
			local tile = tileAt(pick.side, pick.index)
			if tile then
				local key = `{pick.side}{pick.index}`
				if key ~= hoverKey then
					hoverKey = key
					BinderDesk.highlight(pick.side, pick.index)
					showTooltip(tile)
				end
				return
			end
		end
		clearHover()
	end
	local function pickCard(side: BinderDesk.Side, index: number, tile: Tile)
		clearHover()
		BinderDesk.lift(side, index, liteFace({ tile })[1], function()
			openDetail(tile.card)
		end)
	end
	-- Ends what a press was doing without acting on it: a held page falls back or finishes as it lies, a hold's
	-- tooltip goes (a lost release, the binder closing, the window losing focus)
	local function dropPress()
		local pressed = press
		press = nil
		if pressed and pressed.drag then
			endDrag(false)
		end
		if pressed and pressed.held then
			BinderDesk.highlight(nil, nil)
			hideTooltip()
		end
	end
	local function resetInput()
		BinderGesture.cancel(gesture)
		dropPress()
		heldStep = nil
		clearHover()
	end
	local function onPress(input: InputObject)
		local id = pointerId(input)
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local accepted, stale = BinderGesture.press(gesture, id, point.X, point.Y, os.clock())
		if not accepted then
			return -- another finger has the binder
		end
		if stale then
			dropPress() -- its release never came
		end
		clearHover()
		local pick = BinderDesk.pick(point)
		if pick and pick.kind == "tab" then
			BinderGesture.release(gesture, id)
			if not PageTurner.busy() and not dragging then
				openSet(pick.set)
			end
			return
		end
		local edge: boolean? = nil
		if pick and (pick.kind == "page" or pick.kind == "pocket") then
			local outer = if pick.side == "Right" then pick.u >= 1 - Desk.DRAG_EDGE else pick.u <= Desk.DRAG_EDGE
			edge = if outer then pick.side == "Right" else nil
		end
		local pressed = { pick = pick, edge = edge, drag = false, held = false }
		press = pressed
		-- A finger held still on a card shows its tooltip until it lifts (one that moves is a swipe)
		if input.UserInputType == Enum.UserInputType.Touch and pick and pick.kind == "pocket" then
			local tile = tileAt(pick.side, pick.index)
			task.delay(UIStyle.LONG_PRESS, function()
				if press == pressed and not pressed.drag and tile and BinderGesture.canHold(gesture, id, Desk.TAP_PIXELS) then
					pressed.held = true
					BinderDesk.highlight(pick.side, pick.index)
					showTooltip(tile, true)
				end
			end)
		end
	end
	local function onMove(input: InputObject)
		local point = Vector2.new(input.Position.X, input.Position.Y)
		if not BinderGesture.move(gesture, pointerId(input), point.X, point.Y, Desk.TAP_PIXELS) then
			return -- not the pointer that pressed
		end
		local pressed = press
		local owner = gesture.press
		if not pressed or not owner then
			return
		end
		if pressed.drag then
			moveDrag(point)
			return
		end
		local forward = pressed.edge
		local dx = point.X - owner.startX
		if forward ~= nil and not pressed.held and (if forward then dx < -Desk.TAP_PIXELS else dx > Desk.TAP_PIXELS) then
			pressed.drag = beginDrag(forward)
			if pressed.drag then
				moveDrag(point)
			end
		end
	end
	local function onRelease(input: InputObject)
		local ended = BinderGesture.release(gesture, pointerId(input))
		if not ended then
			return -- not the pointer that pressed
		end
		local pressed = press
		press = nil
		if not pressed then
			return
		end
		if pressed.held then
			BinderDesk.highlight(nil, nil)
			hideTooltip()
			return
		end
		local dx, dy = input.Position.X - ended.startX, input.Position.Y - ended.startY
		local tapped = PageCurl.isTap(dx, dy, os.clock() - ended.at, Desk.TAP_PIXELS, Desk.TAP_SECONDS)
		if pressed.drag then
			endDrag(tapped)
			return
		end
		local pick = pressed.pick
		if tapped and pick and pick.kind == "page" then
			turnBy(pageStep(pick.side))
		elseif tapped and pick and pick.kind == "pocket" then
			local tile = tileAt(pick.side, pick.index)
			if tile and isCollected(tile.card.id) and not PageTurner.busy() then
				pickCard(pick.side, pick.index, tile)
			elseif not tile or not isCollected(tile.card.id) then
				turnBy(pageStep(pick.side)) -- a "?" or an empty pocket turns the page
			end
		elseif not tapped then
			local step = PageCurl.swipe(dx, dy, Desk.SWIPE_PIXELS)
			if step then
				turnBy(step)
			end
		end
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
		if not interactive() or isTyping() then
			return
		end
		if isPointer(input) then
			onPress(input)
			return
		end
		local step = PAGE_KEYS[input.KeyCode]
		if step then
			clearHover()
			turnBy(step)
			heldStep, heldNext = step, os.clock() + Desk.HOLD_REPEAT * 2
		elseif input.KeyCode == Enum.KeyCode.F then
			setFiltersOpen(not filtersPanel.Visible)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if BinderGesture.active(gesture) then
			onMove(input)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Over a button or window the 3D binder isn't what's pointed at
			if gameProcessed then
				clearHover()
			else
				hover(Vector2.new(input.Position.X, input.Position.Y))
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) then
			onRelease(input)
		elseif PAGE_KEYS[input.KeyCode] == heldStep then
			heldStep = nil
		end
	end)
	-- Closing the binder or leaving the window ends any press or held key, so nothing carries on by itself
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			resetInput()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(resetInput)
	RunService.Heartbeat:Connect(function()
		local step = heldStep
		if step and os.clock() >= heldNext then
			if interactive() then
				turnBy(step)
			end
			heldNext = os.clock() + Desk.HOLD_REPEAT
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
	-- The Armory: owned weapons and the one in hand
	Remotes.WeaponsChanged.OnClientEvent:Connect(function(state: unknown)
		if typeof(state) ~= "table" then
			return
		end
		local data = state :: any
		ownedWeapons = if typeof(data.owned) == "table" then data.owned else {}
		equippedWeapon = if typeof(data.equipped) == "string" then data.equipped else Weapons.STARTER
		if panel.Visible then
			refresh()
		end
		WeaponDetailController.Refresh()
	end)
	Remotes.WeaponsChanged:FireServer() -- the weapons now, if their first send came before this listened
	-- A fight starting (an elite, an aggro zone) closes the binder (and the card view) so the fight camera takes over
	Remotes.BattleStarted.OnClientEvent:Connect(function()
		if panel.Visible then
			toggle()
		end
	end)
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
		armoryItems = bagItems
		if currentSet == ARMORY and panel.Visible then
			refresh() -- forge progress on the locked weapons
		end
		WeaponDetailController.Refresh()
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
