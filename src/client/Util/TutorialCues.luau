--!strict
-- The tutorial's cues, all without words (spec 2026-11-09-tutorial-pish-design 5, 6): glowing paw prints on the ground to
-- where to go, a bouncing paw over what to tap (a HUD button or a thing in the shop), a picture bubble over Pish, a row
-- of paws (steps done and left) and Pish's gift box in view at the top. Each returns a remover, or is set again.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))

local TutorialCues = {}

local PRINT_GAP = 3 -- studs between paw prints
local PRINT_MAX = 24
local PRINT_SIZE = 1.6 -- studs
local PAW_SIZE = 64 -- px: the bouncing paw over a button
local BOUNCE = 10 -- px (studs * 0.4 on a thing in the shop)
local BOUNCE_SPEED = 6
local ROW_PAW = 34 -- px each paw in the row
-- Pish's gift box sits in the top left corner, above the Manage tray: on phones the HUD's right column (cash, weapon
-- switch) runs from the top
local GIFT_SIZE = 56
local GIFT_LEFT = 12
local GOLD = Color3.fromRGB(255, 214, 90)

TutorialCues.GIFT_RIGHT = GIFT_LEFT + GIFT_SIZE -- px: the gift box's right edge, for the skip button beside it

local screen: ScreenGui? = nil
local row: Frame? = nil
local gift: Frame? = nil

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

-- A bouncing paw pointing down at a HUD button or a thing in the shop
function TutorialCues.pawOn(target: GuiObject | BasePart): () -> ()
	local started = os.clock()
	if typeof(target) == "Instance" and target:IsA("GuiObject") then
		local holder = Instance.new("Frame")
		holder.Name = "PawPointer"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(PAW_SIZE, PAW_SIZE)
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.ZIndex = 20
		holder.Parent = gui()
		local paw = Icon.make(holder, "Paw", UDim2.fromScale(1, 1))
		paw.Rotation = 180 -- toes down, toward the button
		tint(paw, GOLD)
		local connection = RunService.RenderStepped:Connect(function()
			local bounce = math.abs(math.sin((os.clock() - started) * BOUNCE_SPEED)) * BOUNCE
			holder.Visible = target.Parent ~= nil and target.Visible and target.AbsoluteSize.X > 0
			holder.Position = UDim2.fromOffset(target.AbsolutePosition.X + target.AbsoluteSize.X / 2, target.AbsolutePosition.Y - 4 - bounce)
		end)
		return function()
			connection:Disconnect()
			holder:Destroy()
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

-- A white picture bubble over Pish (`adornee`: his root)
function TutorialCues.bubble(adornee: BasePart, icon: string, height: number): () -> ()
	local board = Instance.new("BillboardGui")
	board.Name = "PishBubble"
	board.Size = UDim2.fromOffset(84, 84)
	board.StudsOffset = Vector3.new(0, height, 0)
	board.LightInfluence = 0
	board.Adornee = adornee
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	back.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = Color3.fromRGB(70, 60, 100)
	edge.Parent = back
	local picture = Icon.make(back, icon, UDim2.fromScale(0.68, 0.68))
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.Position = UDim2.fromScale(0.5, 0.5)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = back
	board.Parent = adornee
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	return function()
		board:Destroy()
	end
end

-- The row of paws at the top: `done` lit of `total` (hidden at total 0)
function TutorialCues.pawRow(done: number, total: number)
	local frame = row
	if not frame or not frame.Parent then
		frame = Instance.new("Frame")
		frame.Name = "PawRow"
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.new(0.5, 0, 0, 12)
		frame.AutomaticSize = Enum.AutomaticSize.X
		frame.Size = UDim2.fromOffset(0, ROW_PAW)
		frame.Parent = gui()
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = frame
		row = frame
	end
	local shown = frame :: Frame
	for _, child in shown:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	shown.Visible = total > 0
	for i = 1, total do
		local paw = Icon.make(shown, "Paw", UDim2.fromOffset(ROW_PAW, ROW_PAW))
		paw.LayoutOrder = i
		for _, image in paw:GetDescendants() do
			if image:IsA("ImageLabel") then
				image.ImageTransparency = if i <= done then 0 else 0.7
				image.ImageColor3 = if i <= done then GOLD else Color3.new(1, 1, 1)
			end
		end
	end
end

-- Pish's gift box at the top right, crossed out on the "really skip?" card's warning
function TutorialCues.giftBox(shown: boolean, crossed: boolean)
	local frame = gift
	if not frame or not frame.Parent then
		frame = Instance.new("Frame")
		frame.Name = "PishGift"
		frame.BackgroundTransparency = 1
		frame.Position = UDim2.fromOffset(GIFT_LEFT, 4)
		frame.Size = UDim2.fromOffset(GIFT_SIZE, GIFT_SIZE)
		frame.Parent = gui()
		Icon.make(frame, "Gift", UDim2.fromScale(1, 1))
		local cross = Instance.new("TextLabel")
		cross.Name = "Cross"
		cross.BackgroundTransparency = 1
		cross.Size = UDim2.fromScale(1, 1)
		cross.Text = "❌"
		cross.TextScaled = true
		cross.ZIndex = 3
		cross.Parent = frame
		gift = frame
	end
	local shownFrame = frame :: Frame
	shownFrame.Visible = shown
	local cross = shownFrame:FindFirstChild("Cross") :: TextLabel?
	if cross then
		cross.Visible = crossed
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
