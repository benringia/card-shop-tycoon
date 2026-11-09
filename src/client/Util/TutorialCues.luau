--!strict
-- The tutorial's cues (spec 2026-11-09-tutorial-pish-design 5, 6, 14): glowing paw prints on the ground to where to go,
-- a bouncing paw (and a gold ring) over what to tap (a HUD button, a button in a window or a thing in the shop), and
-- the labelled tour bar at the top: the step of the tour, the paw row, his gift at the end and the skip button
-- (Pish's words: Util/TutorialTalk). Each returns a remover, or is set again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PishTalk = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("PishTalk"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local TutorialCues = {}

local PRINT_GAP = 3 -- studs between paw prints
local PRINT_MAX = 24
local PRINT_SIZE = 1.6 -- studs
local PAW_SIZE = 64 -- px: the bouncing paw over a button (smaller over a small one, down to PAW_MIN)
local PAW_MIN = 40
local RING_PAD = 5 -- px the gold ring stands off the button
local RING_THICKNESS = 4
local RING_CORNER = 14
local BOUNCE = 10 -- px (studs * 0.4 on a thing in the shop)
local BOUNCE_SPEED = 6
local GOLD = Color3.fromRGB(255, 214, 90)
-- The tour bar at the top (owner's pick A, 2026-11-10): "Pish's Tour · 3 of 8", the paw row, "Gift at the end!" and
-- the skip button (TutorialController puts it in). On a narrow screen it's shorter and sits in the top left corner,
-- above the Manage tray: on phones the HUD's right column (cash, weapon switch) runs from the top
local BAR_HEIGHT = 56
local BAR_COMPACT = 900 -- px: narrower screens leave out the paw row
local BAR_EDGE = 12 -- px from the screen's left edge when compact
local ROW_PAW = 22 -- px each paw in the row
local PILL_HEIGHT = 40
local PILL_ICON = 26
local PILL_FILL = Color3.fromRGB(255, 246, 224)
local PILL_EDGE = Color3.fromRGB(255, 215, 122)

local screen: ScreenGui? = nil
local bar: Frame? = nil

-- Gold paws: white ones vanished against the shop's white walls and light floors
local function tint(icon: Instance, color: Color3)
	for _, image in icon:GetDescendants() do
		if image:IsA("ImageLabel") then
			image.ImageColor3 = color
		end
	end
end

-- The cues' own screen, over the HUD
local function gui(): ScreenGui
	local made = screen
	if made and made.Parent then
		return made
	end
	local new = Instance.new("ScreenGui")
	new.Name = "TutorialCues"
	new.ResetOnSpawn = false
	new.IgnoreGuiInset = false -- the same space as the HUD, so a paw lines up with its button
	new.DisplayOrder = 30
	new.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	new.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screen = new
	return new
end

-- Glowing paw prints along the ground from `from` to `to`, lighting up one after another
function TutorialCues.trail(from: Vector3, to: Vector3): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "PawTrail"
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local count = math.clamp(math.floor(flat.Magnitude / PRINT_GAP), 1, PRINT_MAX)
	local prints = {}
	for i = 1, count do
		local at = from + flat * (i / (count + 1))
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Position = Vector3.new(at.X, to.Y + 0.15, at.Z)
		anchor.Parent = folder
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromScale(PRINT_SIZE, PRINT_SIZE)
		board.LightInfluence = 0
		board.Adornee = anchor
		board.Parent = anchor
		local paw = Icon.make(board, "Paw", UDim2.fromScale(1, 1))
		tint(paw, GOLD)
		table.insert(prints, paw)
	end
	folder.Parent = workspace
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local wave = (os.clock() - started) * 6
		for i, paw in prints do
			local glow = 0.5 + 0.5 * math.sin(wave - i * 0.7)
			for _, image in paw:GetDescendants() do
				if image:IsA("ImageLabel") then
					image.ImageTransparency = 0.6 - glow * 0.6
				elseif image:IsA("TextLabel") then
					image.TextTransparency = 0.6 - glow * 0.6
				end
			end
		end
	end)
	return function()
		connection:Disconnect()
		folder:Destroy()
	end
end

-- A bouncing paw pointing down at a HUD button, a button in a window or a thing in the shop; a button also gets a
-- pulsing gold ring round it (in a window full of items the paw alone could pass for one of them)
function TutorialCues.pawOn(target: GuiObject | BasePart): () -> ()
	local started = os.clock()
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		local holder = Instance.new("Frame")
		holder.Name = "PawPointer"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.ZIndex = 20
		holder.Parent = gui()
		local paw = Icon.make(holder, "Paw", UDim2.fromScale(1, 1))
		paw.Rotation = 180 -- toes down, toward the button
		tint(paw, GOLD)
		local ring = Instance.new("Frame")
		ring.Name = "PawRing"
		ring.BackgroundTransparency = 1
		ring.ZIndex = 19
		ring.Parent = gui()
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, RING_CORNER)
		corner.Parent = ring
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = RING_THICKNESS
		stroke.Parent = ring
		local connection = RunService.RenderStepped:Connect(function()
			local beat = math.abs(math.sin((os.clock() - started) * BOUNCE_SPEED))
			local at, size = target.AbsolutePosition, target.AbsoluteSize
			local shown = target.Parent ~= nil and target.Visible and size.X > 0
			local pawSize = math.clamp(size.Y * 0.9, PAW_MIN, PAW_SIZE)
			holder.Visible = shown
			holder.Size = UDim2.fromOffset(pawSize, pawSize)
			holder.Position = UDim2.fromOffset(at.X + size.X / 2, at.Y - 4 - beat * BOUNCE)
			ring.Visible = shown
			ring.Position = UDim2.fromOffset(at.X - RING_PAD, at.Y - RING_PAD)
			ring.Size = UDim2.fromOffset(size.X + RING_PAD * 2, size.Y + RING_PAD * 2)
			stroke.Transparency = 0.15 + beat * 0.45
		end)
		return function()
			connection:Disconnect()
			holder:Destroy()
			ring:Destroy()
		end
	end
	local part = target :: BasePart
	-- Depth-tested like the trail's prints: always-on-top boards made here never drew in Studio play (2026-11-10)
	local board = Instance.new("BillboardGui")
	board.Name = "PawPointer"
	board.Size = UDim2.fromOffset(PAW_SIZE, PAW_SIZE)
	board.LightInfluence = 0
	board.Adornee = part
	board.Parent = part
	local paw = Icon.make(board, "Paw", UDim2.fromScale(1, 1))
	paw.Rotation = 180
	tint(paw, GOLD)
	local top = part.Size.Y / 2 + 2.5
	local connection = RunService.RenderStepped:Connect(function()
		local bounce = math.abs(math.sin((os.clock() - started) * BOUNCE_SPEED)) * BOUNCE * 0.04
		board.StudsOffset = Vector3.new(0, top + bounce, 0)
	end)
	return function()
		connection:Disconnect()
		board:Destroy()
	end
end

-- A label pill on the tour bar: a picture and its words
local function pill(parent: Frame, order: number, icon: string): TextLabel
	local holder = Instance.new("Frame")
	holder.Name = "Pill" .. order
	holder.LayoutOrder = order
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	holder.BackgroundColor3 = PILL_FILL
	holder.Parent = parent
	UIKit.corner(holder, 14)
	UIKit.outline(holder, PILL_EDGE, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = holder
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	local picture = Icon.make(holder, icon, UDim2.fromOffset(PILL_ICON, PILL_ICON))
	picture.LayoutOrder = 1
	local words = UIKit.label(holder, "", Enum.Font.FredokaOne, 18, UIKit.colorsFor(parent).ink)
	words.Name = "Words"
	words.LayoutOrder = 2
	words.AutomaticSize = Enum.AutomaticSize.X
	words.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	return words
end

local function buildBar(): Frame
	local made = Instance.new("Frame")
	made.Name = "TourBar"
	made.AutomaticSize = Enum.AutomaticSize.X
	made.Size = UDim2.fromOffset(0, BAR_HEIGHT)
	made.ZIndex = 20
	made.Parent = gui()
	-- The cotton candy colours without creamWindow's face and glow frames: a row that sizes itself would count them
	made:SetAttribute("Theme", "cream")
	made.BackgroundColor3 = UIKit.colorsFor(made).panel
	UIKit.corner(made, 16)
	UIKit.outline(made, Color3.fromRGB(255, 211, 234), 3)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = made
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = made
	pill(made, 1, "Paw")
	local paws = Instance.new("Frame")
	paws.Name = "PawRow"
	paws.LayoutOrder = 2
	paws.BackgroundTransparency = 1
	paws.AutomaticSize = Enum.AutomaticSize.X
	paws.Size = UDim2.fromOffset(0, ROW_PAW)
	paws.Parent = made
	local pawList = Instance.new("UIListLayout")
	pawList.FillDirection = Enum.FillDirection.Horizontal
	pawList.Padding = UDim.new(0, 3)
	pawList.SortOrder = Enum.SortOrder.LayoutOrder
	pawList.Parent = paws
	pill(made, 3, "Gift")
	bar = made
	return made
end

-- The tour bar showing step `done + 1` of `total` (hidden at total 0); the skip button goes in it (LayoutOrder 4)
function TutorialCues.topBar(done: number, total: number): Frame
	local shown = if bar and bar.Parent then bar else buildBar()
	shown.Visible = total > 0
	local compact = gui().AbsoluteSize.X < BAR_COMPACT
	shown.AnchorPoint = Vector2.new(if compact then 0 else 0.5, 0)
	shown.Position = if compact then UDim2.fromOffset(BAR_EDGE, 4) else UDim2.new(0.5, 0, 0, 4)
	local labels = PishTalk.LABELS
	local tour = shown:FindFirstChild("Pill1")
	local tourWords = tour and tour:FindFirstChild("Words")
	if tourWords and tourWords:IsA("TextLabel") then
		tourWords.Text = string.format(if compact then labels.tourShort else labels.tour, math.min(done + 1, total), total)
	end
	local gift = shown:FindFirstChild("Pill3")
	local giftWords = gift and gift:FindFirstChild("Words")
	if giftWords and giftWords:IsA("TextLabel") then
		giftWords.Text = if compact then labels.giftShort else labels.gift
	end
	local paws = shown:FindFirstChild("PawRow") :: Frame
	paws.Visible = not compact
	for _, child in paws:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i = 1, total do
		local paw = Icon.make(paws, "Paw", UDim2.fromOffset(ROW_PAW, ROW_PAW))
		paw.LayoutOrder = i
		for _, image in paw:GetDescendants() do
			if image:IsA("ImageLabel") then
				image.ImageTransparency = if i <= done then 0 else 0.6
				image.ImageColor3 = if i <= done then GOLD else Color3.fromRGB(200, 190, 210)
			end
		end
	end
	return shown
end

function TutorialCues.hideBar()
	if bar then
		bar.Visible = false
	end
end

-- A burst of sparkles at a point (a step done)
function TutorialCues.sparkle(at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = at
	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	burst.LightEmission = 1
	burst.Size = NumberSequence.new(0.5, 0)
	burst.Lifetime = NumberRange.new(0.5, 0.9)
	burst.Speed = NumberRange.new(6, 12)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = anchor
	anchor.Parent = workspace
	burst:Emit(30)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

-- The cues' screen, for the controller's own pieces (the skip button and card)
function TutorialCues.screen(): ScreenGui
	return gui()
end

return TutorialCues
