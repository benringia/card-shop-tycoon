--!strict
-- Places, moves and sells shelves on a player's plot, and holds what is on each shelf: stock units
-- on product shelves, displayed cards on card cases (ShowcaseService handles the card actions).
-- Shelf parts carry attributes (ShelfUid, ShelfId, GridX, GridZ, Rotation, Refund) for the client.
-- Displayed card parts carry CardId, Foil, Grade, Price, Slot, ShelfUid, OwnerUserId, ShelfKind, Level, Stars, BeastId.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Shelves = require(Config:WaitForChild("Shelves"))
local Products = require(Config:WaitForChild("Products"))
local PlacementConfig = require(Config:WaitForChild("Placement"))
local Rarities = require(Config:WaitForChild("Rarities"))
local CardEffects = require(Config:WaitForChild("CardEffects"))
local ShowcaseConfig = require(Config:WaitForChild("Showcase"))
local Town = require(Config:WaitForChild("Town"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local PlacementGrid = require(Shared:WaitForChild("Util"):WaitForChild("PlacementGrid"))
local CellSearch = require(Shared:WaitForChild("Util"):WaitForChild("CellSearch"))
local Props = require(Shared:WaitForChild("Util"):WaitForChild("Props"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local ShelfStock = require(Shared:WaitForChild("Util"):WaitForChild("ShelfStock"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local CardService = require(Services:WaitForChild("CardService"))
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local RateLimiter = require(Util:WaitForChild("RateLimiter"))

type Plot = typeof(PlotService.GetPlots()[1])
type ShelfDef = typeof(Shelves.List[1])
type PlayerData = DataService.PlayerData
type SavedShelf = DataService.SavedShelf
type SavedCard = DataService.SavedCard
type SavedCell = DataService.SavedCell

type Beast = CardService.Beast
-- A card in a case slot: a plain copy (beast = nil) or a specific levelled card. grade is the copy's
-- grade (for a levelled card, the same as beast.grade).
export type DisplayedCard = { cardId: string, foil: boolean, grade: string, price: number, beast: Beast? }

export type PlacedShelf = {
	uid: string,
	owner: Player,
	def: ShelfDef,
	gridX: number,
	gridZ: number,
	rotation: number,
	productId: string?,
	units: number,
	cards: { [number]: DisplayedCard }, -- card cases: slot → card on display
	cardParts: { [number]: Part },
	paid: number, -- what the player spent, for the sell-back refund
	part: Part,
	label: TextLabel,
	visual: Model?, -- shelves with a prop (Shelves def.prop): the prop drawn on the invisible hitbox part
	stockBoxes: { Part }, -- Products shelves: boxes showing how full it is (ShelfStock)
}

local KIND_LABELS = {
	CustomerCards = "For customers",
	PlayerCards = "For players",
}

local PlacementService = {}

local layouts: { [Player]: { [string]: PlacedShelf } } = {}
local allowAction = RateLimiter.new(PlacementConfig.ACTION_COOLDOWN)

local function notify(player: Player, message: string, isError: boolean)
	Remotes.Notify:FireClient(player, message, isError)
end

local function isGridInteger(value: unknown): boolean
	return typeof(value) == "number" and value == math.floor(value) and math.abs(value) < 1e4
end

local function isValidRotation(value: unknown): boolean
	return isGridInteger(value) and (value :: number) >= 0 and (value :: number) < PlacementConfig.ROTATION_STEPS
end

local function countShelves(layout: { [string]: PlacedShelf }): number
	local count = 0
	for _ in layout do
		count += 1
	end
	return count
end

local function getRefund(shelf: PlacedShelf): number
	return math.floor(shelf.paid * PlacementConfig.SELL_REFUND * 100) / 100
end

local function isCardCase(def: ShelfDef): boolean
	return def.kind == "CustomerCards" or def.kind == "PlayerCards"
end

local function isCondenser(def: ShelfDef): boolean
	return def.kind == "Condenser"
end

local function countCards(shelf: PlacedShelf): number
	local count = 0
	for _ in shelf.cards do
		count += 1
	end
	return count
end

local STOCK_SLOTS = #Town.SHELF_STOCK.LEVELS * Town.SHELF_STOCK.PER_LEVEL

local function toVec(vector: Vector3): ShelfStock.Vec
	return { x = vector.X, y = vector.Y, z = vector.Z }
end

-- Products shelves show up to STOCK_SLOTS boxes in the product's colour, filling from the bottom level
local function updateStockBoxes(shelf: PlacedShelf)
	if shelf.def.kind ~= "Products" then
		return
	end
	local product = if shelf.productId then Products.ById[shelf.productId] else nil
	local count = if product then ShelfStock.boxCount(shelf.units, shelf.def.capacity, STOCK_SLOTS) else 0
	local boxes = shelf.stockBoxes
	while #boxes > count do
		local box = table.remove(boxes)
		if box then
			box:Destroy()
		end
	end
	if not product then
		return
	end
	local size = ShelfStock.boxSize(toVec(shelf.def.size), Town.SHELF_STOCK)
	local slots = ShelfStock.slots(toVec(shelf.def.size), Town.SHELF_STOCK)
	local color = product.color
	for index = 1, count do
		local box = boxes[index]
		if not box then
			box = Instance.new("Part")
			box.Name = "StockBox"
			box.Anchored = true
			box.CanCollide = false
			box.CanQuery = false
			box.CanTouch = false
			box.Material = Enum.Material.SmoothPlastic
			box.Parent = shelf.part
			boxes[index] = box
		end
		local slot = slots[index]
		box.Size = Vector3.new(size.x, size.y, size.z)
		box.Color = Color3.fromRGB(color[1], color[2], color[3])
		box.CFrame = shelf.part.CFrame * CFrame.new(slot.x, slot.y, slot.z)
	end
end

local function updateLabel(shelf: PlacedShelf)
	if isCondenser(shelf.def) then
		shelf.label.Text = shelf.def.name
		return
	end
	if isCardCase(shelf.def) then
		shelf.label.Text = `{KIND_LABELS[shelf.def.kind]} · {countCards(shelf)}/{shelf.def.capacity}`
		return
	end
	updateStockBoxes(shelf)
	local product = if shelf.productId then Products.ById[shelf.productId] else nil
	if not product or shelf.units <= 0 then
		shelf.label.Text = `Empty\n0/{shelf.def.capacity}`
		return
	end
	local price = PricingService.GetPrice(shelf.owner, product.id)
	shelf.label.Text = string.format("%s\n%d/%d · $%.2f", product.name, shelf.units, shelf.def.capacity, price)
end

-- Card slots sit just in front of the case's front face, in a grid below its label
local function getSlotCFrame(shelf: PlacedShelf, slot: number): CFrame
	local columns = ShowcaseConfig.SLOT_COLUMNS
	local rows = math.ceil(shelf.def.capacity / columns)
	local col = (slot - 1) % columns
	local row = (slot - 1) // columns
	if shelf.visual and shelf.def.cardsFlat then
		-- Lying on the bed under the glass, back row first, leaning up toward the front
		local flat = ShowcaseConfig.FLAT
		local size = shelf.part.Size
		local x = (col - (columns - 1) / 2) * flat.SPACING.X
		local z = ((rows - 1) / 2 - row) * flat.SPACING.Y
		local y = -size.Y / 2 + flat.BED * size.Y + ShowcaseConfig.CARD_SIZE.Z
		return shelf.part.CFrame * CFrame.new(x, y, z) * CFrame.Angles(math.rad(90 - flat.TILT), 0, 0)
	end
	local x = (col - (columns - 1) / 2) * ShowcaseConfig.SLOT_SPACING.X
	local y = ((rows - 1) / 2 - row) * ShowcaseConfig.SLOT_SPACING.Y + ShowcaseConfig.SLOTS_OFFSET_Y
	local z = -(shelf.part.Size.Z + ShowcaseConfig.CARD_SIZE.Z) / 2 - 0.02
	if shelf.visual then
		-- Inside the glass: behind the front face, standing on the cabinet's shelves
		z = -shelf.part.Size.Z / 2 + ShowcaseConfig.CASED_CARD_INSET
		y += ShowcaseConfig.CASED_CARD_RAISE
	end
	return shelf.part.CFrame * CFrame.new(x, y, z)
end

local function addCardText(parent: Instance, text: string, y: number, height: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0.05, y)
	label.Size = UDim2.fromScale(0.9, height)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = parent
	return label
end

local function getGrowth(displayed: DisplayedCard): (number, number, string)
	local beast = displayed.beast
	return if beast then beast.level else 1, if beast then beast.stars else BeastRules.START_STARS, displayed.grade
end

local function buildCardPart(shelf: PlacedShelf, slot: number, displayed: DisplayedCard): Part
	local card = Cards.ById[displayed.cardId]
	local part = Instance.new("Part")
	part.Name = "DisplayedCard" .. slot
	part.Anchored = true
	part.CanCollide = false
	part.Size = if shelf.visual and shelf.def.cardsFlat then ShowcaseConfig.CARD_SIZE * ShowcaseConfig.FLAT.SCALE else ShowcaseConfig.CARD_SIZE
	part.Color = Cards.ELEMENTS[card.element] or Color3.new(0.3, 0.3, 0.3)
	part.Material = if displayed.foil then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CFrame = getSlotCFrame(shelf, slot)
	part:SetAttribute("CardId", displayed.cardId)
	part:SetAttribute("Foil", displayed.foil)
	part:SetAttribute("Price", displayed.price)
	part:SetAttribute("Slot", slot)
	part:SetAttribute("ShelfUid", shelf.uid)
	part:SetAttribute("OwnerUserId", shelf.owner.UserId)
	part:SetAttribute("ShelfKind", shelf.def.kind)
	local level, stars, grade = getGrowth(displayed)
	part:SetAttribute("Grade", grade)
	part:SetAttribute("Level", level)
	part:SetAttribute("Stars", stars)
	part:SetAttribute("BeastId", if displayed.beast then displayed.beast.id else nil)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Thickness = 4
	stroke.Color = Rarities.Tiers[card.rarity].color
	stroke.Parent = frame

	-- Frontier cards: darker element colour, a white border the client turns into a moving aurora, a ribbon
	local frontier = card.set == "Frontier"
	local aurora = CardEffects.FRONTIER.AURORA
	if frontier then
		part.Color = part.Color:Lerp(Color3.new(0, 0, 0), CardEffects.FRONTIER.BACKGROUND_DARKEN)
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 6
	end
	addCardText(frame, card.name, 0.04, 0.2)
	if frontier then
		addCardText(frame, if displayed.foil then "FOIL FRONTIER" else "FRONTIER", 0.25, 0.12).TextColor3 = aurora[3]
	elseif displayed.foil then
		addCardText(frame, "FOIL", 0.25, 0.12)
	end
	if displayed.beast then
		addCardText(frame, BeastRules.describeGrowth(level, stars), 0.38, 0.13)
	end
	addCardText(frame, `{card.rarity} · {BeastRules.describeGrade(grade)}`, 0.53, 0.14).TextColor3 = if frontier then aurora[1] else Rarities.Tiers[card.rarity].color
	addCardText(frame, string.format("$%.2f", displayed.price), 0.72, 0.22).Name = "PriceLabel"

	part.Parent = shelf.part
	return part
end

-- A price change updates the existing part, so buyers looking at it don't see it vanish and reappear
local function renderCardSlot(shelf: PlacedShelf, slot: number)
	local existing = shelf.cardParts[slot]
	local displayed = shelf.cards[slot]
	if existing and displayed
		and existing:GetAttribute("CardId") == displayed.cardId
		and existing:GetAttribute("Foil") == displayed.foil
		and existing:GetAttribute("Grade") == displayed.grade
		and existing:GetAttribute("BeastId") == (if displayed.beast then displayed.beast.id else nil)
	then
		existing:SetAttribute("Price", displayed.price)
		local priceLabel = existing:FindFirstChild("PriceLabel", true)
		if priceLabel and priceLabel:IsA("TextLabel") then
			priceLabel.Text = string.format("$%.2f", displayed.price)
		end
		return
	end

	if existing then
		existing:Destroy()
		shelf.cardParts[slot] = nil
	end
	if displayed then
		shelf.cardParts[slot] = buildCardPart(shelf, slot, displayed)
	end
end

local function positionShelf(plot: Plot, shelf: PlacedShelf)
	shelf.part.CFrame = plot.floor.CFrame
		* PlacementGrid.getLocalCFrame(shelf.def.size, shelf.gridX, shelf.gridZ, shelf.rotation)
	shelf.part:SetAttribute("GridX", shelf.gridX)
	shelf.part:SetAttribute("GridZ", shelf.gridZ)
	shelf.part:SetAttribute("Rotation", shelf.rotation)
	for slot, part in shelf.cardParts do
		part.CFrame = getSlotCFrame(shelf, slot)
	end
	if shelf.visual then
		shelf.visual:PivotTo(shelf.part.CFrame * CFrame.new(0, -shelf.def.size.Y / 2, 0))
	end
	updateStockBoxes(shelf)
end

local function buildLabel(part: Part, def: ShelfDef): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part

	local label = Instance.new("TextLabel")
	-- Card cases keep most of the face free for the cards
	label.Size = UDim2.fromScale(1, if isCardCase(def) then ShowcaseConfig.LABEL_HEIGHT else 0.4)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	return label
end

local function createShelf(
	player: Player,
	plot: Plot,
	def: ShelfDef,
	gridX: number,
	gridZ: number,
	rotation: number,
	paid: number
): PlacedShelf
	local uid = HttpService:GenerateGUID(false)

	local part = Instance.new("Part")
	part.Name = def.id
	part.Anchored = true
	part.Size = def.size
	part.Color = def.color
	part.Material = if isCardCase(def)
		then Enum.Material.Glass
		elseif isCondenser(def) then Enum.Material.Metal
		else Enum.Material.Wood
	part:SetAttribute("BlocksPlacement", true)
	part:SetAttribute("ShelfUid", uid)
	part:SetAttribute("ShelfId", def.id)

	local shelf: PlacedShelf = {
		uid = uid,
		owner = player,
		def = def,
		gridX = gridX,
		gridZ = gridZ,
		rotation = rotation,
		productId = nil,
		units = 0,
		cards = {},
		cardParts = {},
		stockBoxes = {},
		paid = paid,
		part = part,
		label = buildLabel(part, def),
	}
	part:SetAttribute("Refund", getRefund(shelf))
	positionShelf(plot, shelf)
	if def.prop and Props.hasModel(def.prop) then
		-- The part stays as the hitbox (prompts, label, customers); the prop is the look. Its label still shows.
		part.Transparency = 1
		local visual = Props.fit(def.prop, def.size, part.CFrame * CFrame.new(0, -def.size.Y / 2, 0), part)
		for _, descendant in visual:GetDescendants() do
			local color = def.propColors and descendant:IsA("BasePart") and def.propColors[descendant.Name]
			if color then
				(descendant :: BasePart).Color = color
			end
		end
		shelf.visual = visual
	end
	updateLabel(shelf)
	part.Parent = plot.shelvesFolder

	layouts[player][uid] = shelf
	return shelf
end

local function isNearPlot(player: Player, plot: Plot): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - plot.floor.Position).Magnitude <= PlacementConfig.MAX_EDIT_DISTANCE
end

local function canPlaceAt(plot: Plot, size: Vector3, gridX: number, gridZ: number, rotation: number, ignoreId: string?): boolean
	local blocked = PlacementGrid.getBlockedRects(plot.model, plot.floor.CFrame, ignoreId)
	return PlacementGrid.isFree(blocked, size, gridX, gridZ, rotation)
end

-- Shared checks for every edit request. Returns the plot and layout when the player may edit.
local function getEditablePlot(player: Player): (Plot?, { [string]: PlacedShelf }?)
	local plot = PlotService.GetPlot(player)
	local layout = layouts[player]
	if not plot or not layout then
		return nil, nil
	end
	if not isNearPlot(player, plot) then
		notify(player, "Go back to your shop to do that.", true)
		return nil, nil
	end
	return plot, layout
end

local function onPlace(player: Player, shelfId: unknown, gridX: unknown, gridZ: unknown, rotation: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(shelfId) ~= "string" or not isGridInteger(gridX) or not isGridInteger(gridZ) or not isValidRotation(rotation) then
		return
	end
	local def = Shelves.ById[shelfId]
	if not def then
		return
	end
	local plot, layout = getEditablePlot(player)
	if not plot or not layout then
		return
	end
	local gx, gz, rot = gridX :: number, gridZ :: number, rotation :: number

	if EconomyService.GetLevel(player) < def.unlockLevel then
		notify(player, `Unlocks at shop level {def.unlockLevel}.`, true)
		return
	end
	if countShelves(layout) >= PlacementConfig.MAX_SHELVES_PER_PLOT then
		notify(player, "Your shop can't fit any more shelves.", true)
		return
	end
	if not canPlaceAt(plot, def.size, gx, gz, rot, nil) then
		notify(player, "That spot is blocked.", true)
		return
	end
	if not EconomyService.TrySpend(player, def.cost) then
		notify(player, "Not enough cash.", true)
		return
	end

	createShelf(player, plot, def, gx, gz, rot, def.cost)
	notify(player, `Placed {def.name}.`, false)
end

local function onMove(player: Player, uid: unknown, gridX: unknown, gridZ: unknown, rotation: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(uid) ~= "string" or not isGridInteger(gridX) or not isGridInteger(gridZ) or not isValidRotation(rotation) then
		return
	end
	local plot, layout = getEditablePlot(player)
	if not plot or not layout then
		return
	end
	local shelf = layout[uid]
	if not shelf then
		return
	end
	local gx, gz, rot = gridX :: number, gridZ :: number, rotation :: number
	if not canPlaceAt(plot, shelf.def.size, gx, gz, rot, uid) then
		notify(player, "That spot is blocked.", true)
		return
	end

	shelf.gridX, shelf.gridZ, shelf.rotation = gx, gz, rot
	positionShelf(plot, shelf)
end

-- Only the order computer can be moved for now; the register stays put because the queue lines up on it
local function onMoveFixture(player: Player, fixtureId: unknown, gridX: unknown, gridZ: unknown, rotation: unknown)
	if not allowAction(player) then
		return
	end
	if fixtureId ~= PlotService.COMPUTER_FIXTURE_ID then
		return
	end
	if not isGridInteger(gridX) or not isGridInteger(gridZ) or not isValidRotation(rotation) then
		return
	end
	local plot = getEditablePlot(player)
	if not plot then
		return
	end
	local gx, gz, rot = gridX :: number, gridZ :: number, rotation :: number
	if not canPlaceAt(plot, plot.computer.Size, gx, gz, rot, fixtureId) then
		notify(player, "That spot is blocked.", true)
		return
	end
	PlotService.SetComputerCell(plot, gx, gz, rot)
end

local function onSell(player: Player, uid: unknown)
	if not allowAction(player) then
		return
	end
	if typeof(uid) ~= "string" then
		return
	end
	local plot, layout = getEditablePlot(player)
	if not plot or not layout then
		return
	end
	local shelf = layout[uid]
	if not shelf then
		return
	end
	if shelf.units > 0 then
		notify(player, "Sell the stock on this shelf first.", true)
		return
	end
	if countCards(shelf) > 0 then
		notify(player, "Take the cards out of this case first.", true)
		return
	end

	local refund = getRefund(shelf)
	layout[uid] = nil
	shelf.part:Destroy()
	if refund > 0 then
		EconomyService.AddCash(player, refund)
	end
	notify(player, string.format("Sold %s for $%.2f.", shelf.def.name, refund), false)
end

-- The saved cell when `size` still fits there, else the nearest free one (a shelf or the computer grew, or
-- something else now stands there). Nil when the plot has no room at all.
local function nearestFreeCell(plot: Plot, size: Vector3, startX: number, startZ: number, rotation: number, ignoreId: string?): (number?, number?)
	local w, d = PlacementGrid.getFootprint(size, rotation)
	local grid = PlacementConfig.GRID_SIZE
	local maxX, maxZ = PlotConfig.WIDTH // grid - w, PlotConfig.DEPTH // grid - d
	for _, cell in CellSearch.byDistance(startX, startZ, maxX, maxZ) do
		if canPlaceAt(plot, size, cell.x, cell.z, rotation, ignoreId) then
			return cell.x, cell.z
		end
	end
	return nil, nil
end

-- Runs after the shelves: the computer goes back to its saved spot, or (when that is taken, or a bigger
-- computer no longer fits there) to the nearest free spot, so no saved shelf is ever pushed out
local function restoreComputer(plot: Plot, saved: SavedCell?)
	local valid = typeof(saved) == "table"
		and isGridInteger(saved.gridX)
		and isGridInteger(saved.gridZ)
		and isValidRotation(saved.rotation)
	local startX = if valid then saved.gridX else PlotConfig.COMPUTER_GRID_X
	local startZ = if valid then saved.gridZ else PlotConfig.COMPUTER_GRID_Z
	local rotation = if valid then saved.rotation else 0
	local x, z = nearestFreeCell(plot, plot.computer.Size, startX, startZ, rotation, PlotService.COMPUTER_FIXTURE_ID)
	if x and z then
		PlotService.SetComputerCell(plot, x, z, rotation)
	end
end

-- Valid saved cards for this case, keyed by slot. Anything that can't go back in a slot (or every
-- card, when def is nil because the case itself couldn't be restored) is added to `leftovers` so it
-- returns to the binder instead of being lost. Each saved card ends up in exactly one of the two.
local function readSavedCards(def: ShelfDef?, saved: { SavedCard }?, leftovers: { DisplayedCard }): { [number]: DisplayedCard }
	local bySlot: { [number]: DisplayedCard } = {}
	if typeof(saved) ~= "table" then
		return bySlot
	end
	for _, entry in saved do
		if typeof(entry) ~= "table" or typeof(entry.cardId) ~= "string" or typeof(entry.foil) ~= "boolean" then
			continue
		end
		local card = Cards.ById[entry.cardId]
		if not card then
			continue
		end
		local beast: Beast? = nil
		if typeof(entry.beastId) == "string" then
			local clean = BeastRules.sanitize(entry)
			if clean then
				beast = {
					id = entry.beastId,
					cardId = clean.cardId,
					foil = clean.foil,
					level = clean.level,
					xp = clean.xp,
					stars = clean.stars,
					grade = clean.grade,
				}
			end
		end
		local level = if beast then beast.level else 1
		local stars = if beast then beast.stars else BeastRules.START_STARS
		local grade = if beast
			then beast.grade
			elseif BeastRules.isGrade(entry.grade) then entry.grade :: string
			else BeastRules.DEFAULT_GRADE
		local price = if typeof(entry.price) == "number" and entry.price == entry.price
			then CardRules.clampPrice(entry.price, card, entry.foil, level, stars, grade)
			else CardRules.getMarketValue(card, entry.foil, level, stars, grade)
		local displayed: DisplayedCard = { cardId = entry.cardId, foil = entry.foil, grade = grade, price = price, beast = beast }
		local slot = entry.slot
		if def and isCardCase(def) and isGridInteger(slot) and slot >= 1 and slot <= def.capacity and not bySlot[slot] then
			bySlot[slot] = displayed
		else
			table.insert(leftovers, displayed)
		end
	end
	return bySlot
end

local function restoreShelf(player: Player, plot: Plot, saved: SavedShelf, leftovers: { DisplayedCard })
	if typeof(saved) ~= "table" then
		return
	end
	local def = Shelves.ById[saved.shelfId]
	local valid = def ~= nil and isGridInteger(saved.gridX) and isGridInteger(saved.gridZ) and isValidRotation(saved.rotation)
	-- A shelf saved under older config (or one that grew) may not fit its spot any more: it moves to the
	-- nearest free one. The computer is placed after the shelves (ignored here), so it never pushes one out.
	local gridX, gridZ
	if valid and def then
		gridX, gridZ = nearestFreeCell(plot, def.size, saved.gridX, saved.gridZ, saved.rotation, PlotService.COMPUTER_FIXTURE_ID)
	end
	if not def or not gridX or not gridZ then
		readSavedCards(nil, saved.cards, leftovers)
		return
	end

	local paid = if typeof(saved.paid) == "number" then math.clamp(saved.paid, 0, def.cost) else 0
	local shelf = createShelf(player, plot, def, gridX, gridZ, saved.rotation, paid)
	local units = if typeof(saved.units) == "number" then math.floor(saved.units) else 0
	if typeof(saved.productId) == "string" and Products.ById[saved.productId] and units > 0 then
		PlacementService.AddStock(shelf, saved.productId, units)
	end
	for slot, displayed in readSavedCards(def, saved.cards, leftovers) do
		-- A beast ID already used in the binder gets a new one, so neither copy is overwritten
		local beast = displayed.beast
		if beast and CardService.GetBeast(player, beast.id) then
			beast.id = HttpService:GenerateGUID(false)
		end
		PlacementService.SetDisplayedCard(shelf, slot, displayed)
	end
end

-- New shops have an empty layout; returning players get their shelves, stock and displayed cards back.
-- Shelves go first (ignoring the computer), then the computer finds its spot around them. CardService loads
-- before this, so displayed cards that can't be put back are returned to the binder.
local function load(player: Player, data: PlayerData)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return -- no free plot this session; leave the saved layout untouched
	end
	layouts[player] = {}
	local leftovers: { DisplayedCard } = {}
	for _, saved in data.layout do
		restoreShelf(player, plot, saved, leftovers)
	end
	restoreComputer(plot, data.fixtures[PlotService.COMPUTER_FIXTURE_ID])
	for _, displayed in leftovers do
		CardService.GiveCard(player, displayed.cardId, displayed.foil, displayed.grade, displayed.beast)
	end
end

local function save(player: Player, data: PlayerData)
	local layout = layouts[player]
	local plot = PlotService.GetPlot(player)
	if not layout or not plot then
		return
	end

	local savedLayout: { SavedShelf } = {}
	for _, shelf in layout do
		local savedCards: { SavedCard } = {}
		for slot, displayed in shelf.cards do
			local beast = displayed.beast
			table.insert(savedCards, {
				slot = slot,
				cardId = displayed.cardId,
				foil = displayed.foil,
				price = displayed.price,
				grade = displayed.grade,
				beastId = if beast then beast.id else nil,
				level = if beast then beast.level else nil,
				xp = if beast then beast.xp else nil,
				stars = if beast then beast.stars else nil,
			})
		end
		table.insert(savedLayout, {
			shelfId = shelf.def.id,
			gridX = shelf.gridX,
			gridZ = shelf.gridZ,
			rotation = shelf.rotation,
			productId = if shelf.units > 0 then shelf.productId else nil,
			units = shelf.units,
			paid = shelf.paid,
			cards = if #savedCards > 0 then savedCards else nil,
		})
	end
	data.layout = savedLayout

	local computer = plot.computer
	data.fixtures[PlotService.COMPUTER_FIXTURE_ID] = {
		gridX = computer:GetAttribute("GridX") :: number,
		gridZ = computer:GetAttribute("GridZ") :: number,
		rotation = computer:GetAttribute("Rotation") :: number,
	}
end

local function unload(player: Player)
	local layout = layouts[player]
	if not layout then
		return
	end
	for _, shelf in layout do
		shelf.part:Destroy()
	end
	layouts[player] = nil
end

function PlacementService.GetShelf(player: Player, uid: string): PlacedShelf?
	local layout = layouts[player]
	return if layout then layout[uid] else nil
end

function PlacementService.GetShelves(player: Player): { PlacedShelf }
	local list: { PlacedShelf } = {}
	local layout = layouts[player]
	if layout then
		for _, shelf in layout do
			table.insert(list, shelf)
		end
	end
	return list
end

-- Removes up to `units` from the shelf (a customer picking them up). Returns units taken.
function PlacementService.TakeStock(shelf: PlacedShelf, units: number): number
	local taken = math.min(units, shelf.units)
	if taken <= 0 then
		return 0
	end
	shelf.units -= taken
	updateLabel(shelf)
	return taken
end

-- Puts up to maxUnits of a product on the shelf. Returns units added, or 0 and a reason.
function PlacementService.AddStock(shelf: PlacedShelf, productId: string, maxUnits: number): (number, string?)
	if isCardCase(shelf.def) then
		return 0, "This case shows single cards, not stock."
	elseif shelf.def.kind ~= "Products" then
		return 0, "This doesn't hold stock."
	end
	local accepts = shelf.def.accepts
	if accepts and not table.find(accepts, productId) then
		return 0, "This shelf can't hold that."
	end
	if shelf.units > 0 and shelf.productId ~= productId then
		return 0, "This shelf has a different product on it."
	end
	local space = shelf.def.capacity - shelf.units
	if space <= 0 then
		return 0, "This shelf is full."
	end

	local added = math.min(space, maxUnits)
	shelf.productId = productId
	shelf.units += added
	updateLabel(shelf)
	return added, nil
end

-- Card cases: put a card in a slot, or clear it with nil. Callers handle the binder side.
function PlacementService.SetDisplayedCard(shelf: PlacedShelf, slot: number, displayed: DisplayedCard?)
	shelf.cards[slot] = displayed
	renderCardSlot(shelf, slot)
	updateLabel(shelf)
end

function PlacementService.IsCardCase(shelf: PlacedShelf): boolean
	return isCardCase(shelf.def)
end

function PlacementService.IsCondenser(shelf: PlacedShelf): boolean
	return isCondenser(shelf.def)
end

function PlacementService.GetFreeSlot(shelf: PlacedShelf): number?
	for slot = 1, shelf.def.capacity do
		if not shelf.cards[slot] then
			return slot
		end
	end
	return nil
end

local function onPriceChanged(player: Player, productId: string, _price: number)
	local layout = layouts[player]
	if not layout then
		return
	end
	for _, shelf in layout do
		if shelf.productId == productId then
			updateLabel(shelf)
		end
	end
end

function PlacementService.Start()
	DataService.Register({ name = "PlacementService", load = load, save = save, unload = unload })
	PricingService.OnPriceChanged(onPriceChanged)

	Remotes.PlaceShelf.OnServerEvent:Connect(onPlace)
	Remotes.MoveShelf.OnServerEvent:Connect(onMove)
	Remotes.MoveFixture.OnServerEvent:Connect(onMoveFixture)
	Remotes.SellShelf.OnServerEvent:Connect(onSell)
end

return PlacementService
