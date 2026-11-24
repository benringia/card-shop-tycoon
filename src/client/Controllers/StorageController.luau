--!strict
-- Storage racks on the owner's screen (spec docs/superpowers/specs/2026-11-24-storage-racks-design.md; owner 2026-11-24:
-- "redesign the window not just a plain list", pick C "Stock clipboard"):
--   Open(rack): the rack's stock clipboard, a UIKit.panel with no face, band or title (the window rules stay: one at a
--   time, the close X, the thumbstick hidden) and the clipboard drawn in it at its layout's size (Config/Storage
--   CLIPBOARD: a computer's mockup C, a phone's on its side with two columns), scaled to fit like the order computer
--   (OrderRules.fit). One line per kind of box (StorageRules.lines) with a TAKE stamp; the whole line is the button, so a
--   phone's stays a 48 px tap. TAKE asks for that kind's half-used box first (Remotes.TakeStoredBox) and closes the
--   sheet. While open it follows the rack's attributes (PlacementService: Stored, StoredCount, LastWorker).
--   Remotes.RackBoxHop: a box hopping between someone's arms and its spot on a rack, for everyone near.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SharedUtil = Shared:WaitForChild("Util")
local Shelves = require(Config:WaitForChild("Shelves"))
local Products = require(Config:WaitForChild("Products"))
local Storage = require(Config:WaitForChild("Storage"))
local StockConfig = require(Config:WaitForChild("Stock"))
local CarryPose = require(Config:WaitForChild("CarryPose"))
local HudGrowConfig = require(Config:WaitForChild("HudGrow"))
local StorageRules = require(SharedUtil:WaitForChild("StorageRules"))
local OrderRules = require(SharedUtil:WaitForChild("OrderRules"))
local HudGrow = require(SharedUtil:WaitForChild("HudGrow"))
local Props = require(SharedUtil:WaitForChild("Props"))
local DeliveryLooks = require(SharedUtil:WaitForChild("DeliveryLooks"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local UIController = require(Controllers:WaitForChild("UIController"))

local StorageController = {}

type Layout = { size: { number }, columns: number, lineHeight: number, linesTop: number, titleY: number, subY: number }
type Sheet = { root: Frame, scale: UIScale, lines: Frame, subtitle: TextLabel, layout: Layout, lineWidth: number }

local LOOK = Storage.CLIPBOARD
local WORDS = Storage.WORDS
local HOP = Storage.HOP

local player = Players.LocalPlayer
local panel: Frame? = nil
local sheet: Sheet? = nil
local built: string? = nil -- "desk" or "phone"
local current: BasePart? = nil
local watching: { RBXScriptConnection } = {}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function box(parent: Instance, name: string, position: Vector2, size: Vector2, color: { number }?, corner: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(position.X, position.Y)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = if color then rgb(color) else Color3.new(1, 1, 1)
	frame.BackgroundTransparency = if color then 0 else 1
	frame.Parent = parent
	if corner then
		UIKit.corner(frame, corner)
	end
	return frame
end

local function write(parent: Instance, name: string, value: string, font: Enum.Font, size: number, color: { number }, position: Vector2, area: Vector2, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = rgb(color)
	label.Text = value
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Position = UDim2.fromOffset(position.X, position.Y)
	label.Size = UDim2.fromOffset(area.X, area.Y)
	label.Parent = parent
	return label
end

local function gradient(parent: GuiObject, top: { number }, bottom: { number })
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new(rgb(top), rgb(bottom))
	fill.Parent = parent
end

-- The board, its clip, the ruled paper and its writing, at the layout's size (the panel scales it: fit)
local function buildSheet(host: Frame, layout: Layout): Sheet
	local size = Vector2.new(layout.size[1], layout.size[2])
	local root = box(host, "Clipboard", Vector2.zero, size, nil, nil)
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local boardHeight = size.Y - LOOK.board.dropY
	box(root, "Drop", Vector2.new(0, LOOK.board.dropY), Vector2.new(size.X, boardHeight), LOOK.board.drop, LOOK.board.corner)
	local board = box(root, "Board", Vector2.zero, Vector2.new(size.X, boardHeight), { 255, 255, 255 }, LOOK.board.corner)
	gradient(board, LOOK.board.top, LOOK.board.bottom)

	local paperSize = Vector2.new(size.X - LOOK.paper.left - LOOK.paper.right, boardHeight - LOOK.paper.top - LOOK.paper.bottom)
	local paper = box(board, "Paper", Vector2.new(LOOK.paper.left, LOOK.paper.top), paperSize, LOOK.paper.color, LOOK.paper.corner)
	paper.ClipsDescendants = true
	-- a ruled line at every line's foot, carried up the whole paper
	local y = (layout.linesTop - 1) % layout.lineHeight
	while y < paperSize.Y do
		box(paper, "Rule", Vector2.new(0, y), Vector2.new(paperSize.X, LOOK.rules.thickness), LOOK.rules.color, nil)
		y += layout.lineHeight
	end
	box(paper, "Margin", Vector2.new(LOOK.margin.x, 0), Vector2.new(LOOK.margin.width, paperSize.Y), LOOK.margin.color, nil)

	local clip = box(root, "Clip", Vector2.new((size.X - LOOK.clip.width) / 2, LOOK.clip.y), Vector2.new(LOOK.clip.width, LOOK.clip.height), { 255, 255, 255 }, 12)
	gradient(clip, LOOK.clip.top, LOOK.clip.bottom)
	box(clip, "Hole", Vector2.new((LOOK.clip.width - 46) / 2, 9), Vector2.new(46, 14), LOOK.clip.hole, 7)

	local width = paperSize.X - LOOK.inner.left - LOOK.inner.right
	write(paper, "Title", WORDS.title, Enum.Font.FredokaOne, LOOK.titleSize, LOOK.ink, Vector2.new(LOOK.inner.left, layout.titleY), Vector2.new(width, 28))
	local subtitle = write(paper, "Subtitle", "", Enum.Font.GothamBold, LOOK.subSize, LOOK.inkSoft, Vector2.new(LOOK.inner.left, layout.subY), Vector2.new(width, 16))
	local lineCount = math.floor((paperSize.Y - layout.linesTop - LOOK.inner.bottom - 16) / layout.lineHeight)
	local lines = box(paper, "Lines", Vector2.new(LOOK.inner.left, layout.linesTop), Vector2.new(width, lineCount * layout.lineHeight), nil, nil)
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(12, 0)
	grid.CellSize = UDim2.new(1 / layout.columns, if layout.columns > 1 then -6 else 0, 0, layout.lineHeight)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = lines
	write(paper, "Footer", WORDS.footer, Enum.Font.GothamBold, LOOK.smallSize, LOOK.inkSoft, Vector2.new(LOOK.inner.left, paperSize.Y - LOOK.inner.bottom - 16), Vector2.new(width, 16), Enum.TextXAlignment.Right)
	local lineWidth = if layout.columns > 1 then (width - 12 * (layout.columns - 1)) / layout.columns else width
	return { root = root, scale = scale, lines = lines, subtitle = subtitle, layout = layout, lineWidth = lineWidth }
end

-- The sheet as big as fits: under Roblox's top bar, above the bottom tiles while they show, growing on a big screen
-- like the HUD (the window's own growth is off: SizesItself)
local function fit()
	local host, made = panel, sheet
	if not host or not made then
		return
	end
	local gui = host.Parent
	local area = if gui and gui:IsA("GuiBase2d") then gui.AbsoluteSize else Vector2.new(1280, 720)
	local tiles = Hud.bottomTop()
	local floor = if gui and gui:IsA("GuiBase2d") and tiles then tiles - gui.AbsolutePosition.Y else nil
	local grow = if HudGrowConfig.WINDOWS then HudGrow.scale(area.Y, UserInputService.TouchEnabled, HudGrowConfig) else 1
	local size = made.layout.size
	local scale, middle = OrderRules.fit({ w = area.X, h = area.Y }, { w = size[1], h = size[2] }, floor, LOOK.fit, grow)
	made.scale.Scale = scale
	host.Size = UDim2.fromOffset(math.floor(size[1] * scale), math.floor(size[2] * scale))
	host.Position = UDim2.new(0.5, 0, 0, middle)
end

local function stopWatching()
	for _, connection in watching do
		connection:Disconnect()
	end
	table.clear(watching)
	current = nil
end

local function take(productId: string, pop: UIScale)
	local rack = current
	local uid = if rack then rack:GetAttribute("ShelfUid") else nil
	if typeof(uid) ~= "string" then
		return
	end
	pop.Scale = 1.15
	TweenService:Create(pop, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Remotes.TakeStoredBox:FireServer(uid, productId) -- StockService: into your arms, or the locked card says why not
	if panel then
		UIKit.closePanel(panel)
	end
end

-- One line of the sheet: the kind's picture as a taped sticker, its name, a tally mark a box and what's inside, and the
-- TAKE stamp; the whole line takes a box
local function drawLine(made: Sheet, order: number, entry: StorageRules.Line)
	local layout = made.layout
	local row = Instance.new("TextButton")
	row.Name = entry.productId
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.AutoButtonColor = false
	row.Text = ""
	row.Parent = made.lines
	local sticker = LOOK.sticker
	local stick = box(row, "Sticker", Vector2.new(0, (layout.lineHeight - sticker.size) / 2), Vector2.new(sticker.size, sticker.size), { 255, 255, 255 }, 6)
	stick.Rotation = sticker.tilt
	local product = Products.ById[entry.productId]
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(sticker.image, sticker.image)
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = DeliveryLooks.picture(entry.productId, if product then product.icon else nil) or ""
	image.Parent = stick
	local tape = box(stick, "Tape", Vector2.new(9, -5), Vector2.new(18, 8), sticker.tape, nil)
	tape.Rotation = 6
	tape.BackgroundTransparency = 0.15

	local stamp = LOOK.stamp
	local textLeft = sticker.size + 12
	local textWidth = made.lineWidth - textLeft - stamp.width - 10
	local textTop = (layout.lineHeight - 36) / 2
	write(row, "Name", entry.name, Enum.Font.FredokaOne, LOOK.nameSize, LOOK.ink, Vector2.new(textLeft, textTop + 2), Vector2.new(textWidth, 18))
	write(row, "Count", `{entry.tally} · {entry.words}`, Enum.Font.GothamBold, LOOK.smallSize, LOOK.inkSoft, Vector2.new(textLeft, textTop + 20), Vector2.new(textWidth, 16))

	local mark = Instance.new("TextLabel")
	mark.Name = "Stamp"
	mark.AnchorPoint = Vector2.new(1, 0.5)
	mark.Position = UDim2.new(1, -4, 0.5, 0)
	mark.Size = UDim2.fromOffset(stamp.width, stamp.height)
	mark.Rotation = stamp.tilt
	mark.BackgroundColor3 = rgb(stamp.fill)
	mark.BackgroundTransparency = stamp.fillTransparency
	mark.Font = Enum.Font.FredokaOne
	mark.TextSize = stamp.textSize
	mark.TextColor3 = rgb(stamp.color)
	mark.Text = WORDS.take
	mark.Parent = row
	UIKit.corner(mark, 8)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rgb(stamp.color)
	stroke.Thickness = stamp.stroke
	stroke.Parent = mark
	local pop = Instance.new("UIScale")
	pop.Parent = mark
	row.Activated:Connect(function()
		take(entry.productId, pop)
	end)
end

-- The sheet as the rack is now: its subtitle and a line per kind (or "Nothing stored yet.")
local function render()
	local rack, made = current, sheet
	if not rack or not made then
		return
	end
	local def = Shelves.ById[rack.Name]
	local capacity = if def then def.capacity else #Storage.SPOTS.x * #Storage.SPOTS.decks
	local stored = StorageRules.decode(rack:GetAttribute("Stored"), capacity)
	local worker = rack:GetAttribute("LastWorker")
	made.subtitle.Text = StorageRules.subtitle(StorageRules.count(stored), capacity, if typeof(worker) == "string" then worker else nil, WORDS)
	for _, child in made.lines:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local entries = StorageRules.lines(stored, Storage.NAMES, Storage.UNITS)
	if #entries == 0 then
		local empty = write(made.lines, "Nothing", WORDS.nothing, Enum.Font.GothamBold, LOOK.nameSize, LOOK.inkSoft, Vector2.zero, Vector2.new(made.lineWidth, made.layout.lineHeight))
		empty.LayoutOrder = 1
		return
	end
	for order, entry in entries do
		drawLine(made, order, entry)
	end
end

-- The sheet for this screen (a computer's or a phone's), built again when the screen changed kind
local function ensureBuilt()
	local host = panel
	if not host then
		return
	end
	local want = if UIKit.isShort() then "phone" else "desk"
	if not sheet or built ~= want then
		if sheet then
			sheet.root:Destroy()
		end
		built = want
		sheet = buildSheet(host, if want == "phone" then LOOK.phone else LOOK.desk)
	end
	fit()
	render()
end

local function makePanel(): Frame
	local made, list = UIKit.panel(UIController.GetScreenGui(), "StorageRack", WORDS.title)
	list:Destroy()
	-- the clipboard is the window: no cream face, band or title of its own (the X stays on its corner)
	made.BackgroundTransparency = 1
	for _, name in { "Header", "Title", "Glow" } do
		local child = made:FindFirstChild(name)
		if child and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	local limit = made:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit:Destroy()
	end
	made:SetAttribute("SizesItself", true)
	made:GetPropertyChangedSignal("Visible"):Connect(function()
		if not made.Visible then
			stopWatching()
		end
	end)
	return made
end

-- The rack's stock clipboard (its E prompt with empty hands, or Open on its Edit bar)
function StorageController.Open(rack: BasePart)
	if not panel then
		panel = makePanel()
	end
	stopWatching()
	current = rack
	for _, name in { "Stored", "StoredCount", "LastWorker" } do
		table.insert(watching, rack:GetAttributeChangedSignal(name):Connect(render))
	end
	table.insert(watching, rack.Destroying:Connect(function()
		if panel then
			UIKit.closePanel(panel) -- sold
		end
	end))
	ensureBuilt()
	if panel then
		panel.Visible = true
	end
end

-- The hop ------------------------------------------------------------------------------------------------------------

local function spotCFrame(rack: BasePart, slot: number): CFrame?
	local def = Shelves.ById[rack.Name]
	if not def then
		return nil
	end
	local x, y = StorageRules.spot(slot, Storage.SPOTS, def.size.Y)
	return rack.CFrame * CFrame.new(x, y, 0)
end

-- In front of a carrier's chest, where a box is held (Config/CarryPose)
local function armsCFrame(carrier: Instance?): CFrame?
	if not carrier or not carrier:IsA("Model") then
		return nil
	end
	local torso = carrier:FindFirstChild("UpperTorso") or carrier:FindFirstChild("HumanoidRootPart")
	if not torso or not torso:IsA("BasePart") then
		return nil
	end
	return torso.CFrame * CFrame.new(0, -CarryPose.BOX.down, -CarryPose.BOX.forward)
end

-- The real box at the hop's end: on the rack's spot, or in the carrier's arms (the owner's weld or a worker's)
local function realBox(rack: BasePart, slot: number, toRack: boolean, carrier: Instance?): Instance?
	if toRack then
		for _, child in rack:GetChildren() do
			if child.Name == "StockBox" and child:GetAttribute("Slot") == slot then
				return child
			end
		end
		return nil
	end
	local shelves = rack.Parent
	local plot = if shelves then shelves.Parent else nil
	if not plot or not carrier then
		return nil
	end
	for _, child in plot:GetChildren() do
		if child.Name == "StockBox" then
			for _, joint in child:GetChildren() do
				local held = (joint:IsA("Weld") and joint.Part0) or (joint:IsA("WeldConstraint") and joint.Part1)
				if held and held:IsDescendantOf(carrier) then
					return child
				end
			end
		end
	end
	return nil
end

local function setHidden(thing: Instance?, hidden: boolean)
	if not thing then
		return
	end
	local items = thing:GetDescendants()
	table.insert(items, thing)
	for _, item in items do
		if item:IsA("BasePart") or item:IsA("Decal") then
			item.LocalTransparencyModifier = if hidden then 1 else 0
		elseif item:IsA("SurfaceGui") then
			item.Enabled = not hidden
		end
	end
end

-- A box to fly: the delivery box's model with its stickers, as on the pad (Util/Props, Util/DeliveryLooks)
local function flyingBox(productId: string): Part?
	local product = Products.ById[productId]
	if not product then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = "HopBox"
	part.Size = StockConfig.BOX_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	local model = Props.weldFit(product.boxProp, part)
	if model then
		DeliveryLooks.finishBox(model, product.id, product.icon)
	else
		part.Transparency = 0
		part.Color = StockConfig.BOX_COLOR
		part.Material = Enum.Material.Cardboard
	end
	return part
end

local function onHop(rack: unknown, slot: unknown, productId: unknown, toRack: unknown, carrier: unknown)
	if typeof(rack) ~= "Instance" or not rack:IsA("BasePart") or typeof(slot) ~= "number" or typeof(productId) ~= "string" then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - rack.Position).Magnitude > HOP.range then
		return
	end
	local who = if typeof(carrier) == "Instance" then carrier else nil
	local storing = toRack == true
	local spot = spotCFrame(rack, slot)
	local arms = armsCFrame(who)
	local copy = flyingBox(productId)
	if not spot or not arms or not copy then
		return
	end
	local real = realBox(rack, slot, storing, who)
	local from = if storing then arms else spot
	copy.CFrame = from
	copy.Parent = workspace
	setHidden(real, true)
	local start = os.clock()
	local connection: RBXScriptConnection? = nil
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / HOP.seconds, 0, 1)
		local to = if storing then spot else (armsCFrame(who) or arms) -- into arms that may be walking
		local eased = 1 - (1 - t) * (1 - t)
		copy.CFrame = from:Lerp(to, eased) + Vector3.new(0, 4 * HOP.height * t * (1 - t), 0)
		if t >= 1 then
			if connection then
				connection:Disconnect()
			end
			copy:Destroy()
			setHidden(real, false)
		end
	end)
end

function StorageController.Start()
	if workspace:GetAttribute("PlaceKind") ~= "Main" then
		return -- shops are in the main game
	end
	Remotes.RackBoxHop.OnClientEvent:Connect(onHop)
	-- a window resized (or a phone turned): the sheet fits again, a phone's layout if it's short now
	UIController.GetScreenGui():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(function()
			if panel and panel.Visible then
				ensureBuilt()
			end
		end)
	end)
	player.CharacterRemoving:Connect(function()
		if panel then
			UIKit.closePanel(panel)
		end
	end)
end

return StorageController
