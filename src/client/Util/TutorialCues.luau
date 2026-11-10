--!strict
-- The tutorial's cues (spec 2026-11-09-tutorial-pish-design 5, 6, 14): glowing paw prints on the ground to where to go,
-- a bouncing paw (and a gold ring) over what to tap (a HUD button, a button in a window or a thing in the shop), the
-- small Skip at the top right and the tour card it opens (the step of the tour, the paw row, his gift, Keep going or
-- Skip tour) (Pish's words: Util/TutorialTalk). Each returns a remover, or is set again.
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
local PRINT_PX = 46 -- px: a paw print up close (PRINT_NEAR studs away), smaller further off down to PRINT_MIN
local PRINT_NEAR = 12
local PRINT_MIN = 16
local PAW_SIZE = 64 -- px: the bouncing paw over a button (smaller over a small one, down to PAW_MIN)
local PAW_MIN = 40
local RING_PAD = 5 -- px the gold ring stands off the button
local RING_THICKNESS = 4
local RING_CORNER = 14
local BOUNCE = 10 -- px (studs * 0.4 on a thing in the shop)
local BOUNCE_SPEED = 6
local GOLD = Color3.fromRGB(255, 214, 90)
-- The small Skip at the top right (round 3, owner's pick A) and the tour card it opens: the step of the tour, the paw
-- row, his gift at the end, Keep going and Skip tour. On a phone the HUD's right column (cash, weapon switch) runs
-- from the top, so Skip sits just left of it
local SKIP_SIZE = Vector2.new(84, 48) -- px (tap targets 48 px or more)
local SKIP_EDGE = 10 -- px from the screen's right edge, or from the HUD's right column beside it
local ROW_PAW = 26 -- px each paw on the tour card
local CARD_SIZE = Vector2.new(360, 250)
local CARD_GREY = Color3.fromRGB(190, 195, 205)
local DIM_COLOR = Color3.fromRGB(20, 10, 40) -- the spotlight's dimming
local DIM_TRANSPARENCY = 0.45
local SPOT_PAD = 8 -- px of light round the button

local screen: ScreenGui? = nil
local skip: TextButton? = nil
local onSkipTap: (() -> ())? = nil
local spotTarget: GuiObject? = nil
local spotFrames: { Frame }? = nil
local card: Frame? = nil
local askCard: Frame? = nil -- the "tour again?" card (TutorialCues.askReplay)
local ASK_SIZE = Vector2.new(330, 150)

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

-- Where a point in the world shows on the cues' screen (it shares the HUD's inset), and how far it is; nil behind
-- the camera
local function onScreen(at: Vector3): (Vector2?, number)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, 0
	end
	local point, visible = camera:WorldToScreenPoint(at)
	if point.Z <= 0 then
		return nil, 0
	end
	return if visible then Vector2.new(point.X, point.Y) else nil, point.Z
end

-- Glowing paw prints along the ground from `from` to `to`, lighting up one after another. Drawn on the screen over
-- the world (owner 2026-11-10: "paw prints are not visible when the door is closed"), smaller further away
function TutorialCues.trail(from: Vector3, to: Vector3): () -> ()
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local count = math.clamp(math.floor(flat.Magnitude / PRINT_GAP), 1, PRINT_MAX)
	local holder = Instance.new("Frame")
	holder.Name = "PawTrail"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 5
	holder.Parent = gui()
	local prints: { { at: Vector3, paw: Frame } } = {}
	local facing = math.deg(math.atan2(flat.X, -flat.Z))
	for i = 1, count do
		local at = from + flat * (i / (count + 1))
		local paw = Icon.make(holder, "Paw", UDim2.fromOffset(PRINT_PX, PRINT_PX))
		paw.AnchorPoint = Vector2.new(0.5, 0.5)
		paw.Rotation = facing
		tint(paw, GOLD)
		table.insert(prints, { at = Vector3.new(at.X, to.Y + 0.15, at.Z), paw = paw })
	end
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local wave = (os.clock() - started) * 6
		for i, entry in prints do
			local point, depth = onScreen(entry.at)
			entry.paw.Visible = point ~= nil
			if point then
				local size = math.clamp(PRINT_PX * PRINT_NEAR / depth, PRINT_MIN, PRINT_PX)
				entry.paw.Position = UDim2.fromOffset(point.X, point.Y)
				entry.paw.Size = UDim2.fromOffset(size, size)
				local glow = 0.5 + 0.5 * math.sin(wave - i * 0.7)
				for _, image in entry.paw:GetDescendants() do
					if image:IsA("ImageLabel") then
						image.ImageTransparency = 0.55 - glow * 0.5
					end
				end
			end
		end
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
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
	-- On the screen over the world, like the trail: walls and closed doors don't hide it
	local holder = Instance.new("Frame")
	holder.Name = "PawPointer"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Size = UDim2.fromOffset(PAW_SIZE, PAW_SIZE)
	holder.ZIndex = 20
	holder.Parent = gui()
	local paw = Icon.make(holder, "Paw", UDim2.fromScale(1, 1))
	paw.Rotation = 180
	tint(paw, GOLD)
	local connection = RunService.RenderStepped:Connect(function()
		local point = onScreen(part.Position + Vector3.new(0, part.Size.Y / 2 + 0.5, 0))
		holder.Visible = point ~= nil and part.Parent ~= nil
		if point then
			local beat = math.abs(math.sin((os.clock() - started) * BOUNCE_SPEED))
			holder.Position = UDim2.fromOffset(point.X, point.Y - beat * BOUNCE)
		end
	end)
	return function()
		connection:Disconnect()
		holder:Destroy()
	end
end


-- The small Skip at the top right (a tap opens the tour card: TutorialController); shown or hidden
function TutorialCues.skipButton(shown: boolean, onTap: () -> ())
	local button = skip
	if not button or not button.Parent then
		local made = Instance.new("TextButton")
		made.Name = "TutorialSkip"
		made.Text = ""
		made.AnchorPoint = Vector2.new(1, 0)
		made.Size = UDim2.fromOffset(SKIP_SIZE.X, SKIP_SIZE.Y)
		made.BackgroundColor3 = Color3.new(1, 1, 1)
		made.AutoButtonColor = false
		made.ZIndex = 30
		made.Parent = gui()
		UIKit.corner(made, 14)
		UIKit.outline(made, Color3.fromRGB(255, 211, 234), 3)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, 4)
		list.Parent = made
		local arrow = Icon.make(made, "Next", UDim2.fromOffset(22, 22))
		arrow.LayoutOrder = 1
		local words = UIKit.label(made, PishTalk.LABELS.skip, Enum.Font.FredokaOne, 19, Color3.fromRGB(90, 70, 110))
		words.LayoutOrder = 2
		words.AutomaticSize = Enum.AutomaticSize.X
		words.Size = UDim2.fromOffset(0, SKIP_SIZE.Y)
		made.Activated:Connect(function()
			local tap = onSkipTap
			if tap then
				tap()
			end
		end)
		-- Top right, or just left of the HUD's right column when it reaches the top (phones)
		RunService.RenderStepped:Connect(function()
			if not made.Visible then
				return
			end
			local screenSize = gui().AbsoluteSize
			local right = screenSize.X - SKIP_EDGE
			local main = Players.LocalPlayer:FindFirstChild("PlayerGui")
			local hud = main and main:FindFirstChild("MainGui")
			local column = hud and hud:FindFirstChild("StatusRow")
			if column and column:IsA("GuiObject") and column.Visible and column.AbsolutePosition.Y < SKIP_SIZE.Y + 8 then
				right = math.min(right, column.AbsolutePosition.X - SKIP_EDGE)
			end
			made.Position = UDim2.fromOffset(right, 4)
		end)
		skip = made
		button = made
	end
	onSkipTap = onTap
	;(button :: TextButton).Visible = shown
end

-- The tour card (Skip tapped): "Pish's Tour · 3 of 8", the paw row, his gift and what you'd miss, a big green Keep
-- going and a small grey Skip tour
function TutorialCues.tourCard(done: number, total: number, onKeep: () -> (), onSkip: () -> ())
	if card and card.Parent then
		return
	end
	local labels = PishTalk.LABELS
	local made = Instance.new("Frame")
	made.Name = "TourCard"
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	made.ZIndex = 40
	made.Parent = gui()
	UIKit.creamWindow(made)
	local ink = UIKit.colorsFor(made).ink
	local title = UIKit.label(made, string.format(labels.tour, math.min(done + 1, total), total), Enum.Font.FredokaOne, 24, ink)
	title.Position = UDim2.fromOffset(0, 12)
	title.Size = UDim2.new(1, 0, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local paws = Instance.new("Frame")
	paws.BackgroundTransparency = 1
	paws.AnchorPoint = Vector2.new(0.5, 0)
	paws.Position = UDim2.new(0.5, 0, 0, 48)
	paws.AutomaticSize = Enum.AutomaticSize.X
	paws.Size = UDim2.fromOffset(0, ROW_PAW)
	paws.Parent = made
	local pawList = Instance.new("UIListLayout")
	pawList.FillDirection = Enum.FillDirection.Horizontal
	pawList.Padding = UDim.new(0, 4)
	pawList.SortOrder = Enum.SortOrder.LayoutOrder
	pawList.Parent = paws
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
	local gift = Icon.make(made, "PishGift", UDim2.fromOffset(72, 72))
	gift.AnchorPoint = Vector2.new(0.5, 0)
	gift.Position = UDim2.new(0.5, 0, 0, 82)
	local line = UIKit.label(made, labels.tourGift, Enum.Font.FredokaOne, 19, ink)
	line.Position = UDim2.fromOffset(0, 156)
	line.Size = UDim2.new(1, 0, 0, 24)
	line.TextXAlignment = Enum.TextXAlignment.Center
	local keep = UIKit.button(made, labels.keepGoing, UIKit.Colors.Success)
	keep.Name = "Keep"
	keep.AnchorPoint = Vector2.new(0, 1)
	keep.Position = UDim2.new(0, 16, 1, -14)
	keep.Size = UDim2.fromOffset(190, 52)
	keep.Font = Enum.Font.FredokaOne
	keep.TextSize = 22
	local skipTour = UIKit.button(made, labels.skipYes, CARD_GREY)
	skipTour.Name = "ReallySkip"
	skipTour.AnchorPoint = Vector2.new(1, 1)
	skipTour.Position = UDim2.new(1, -16, 1, -16)
	skipTour.Size = UDim2.fromOffset(122, 48)
	skipTour.Font = Enum.Font.FredokaOne
	skipTour.TextSize = 18
	local function close()
		made:Destroy()
		card = nil
	end
	keep.Activated:Connect(function()
		close()
		onKeep()
	end)
	skipTour.Activated:Connect(function()
		close()
		onSkip()
	end)
	card = made
end

-- Tapping the peeking Pish (round 5: he's the Pish button): "Want my shop tour again?" with a big green Yes and a
-- small grey Not now, so a stray tap never restarts it
function TutorialCues.askReplay(onYes: () -> ())
	if askCard and askCard.Parent then
		return
	end
	local labels = PishTalk.LABELS
	local made = Instance.new("Frame")
	made.Name = "AskReplay"
	made.AnchorPoint = Vector2.new(0.5, 0.5)
	made.Position = UDim2.fromScale(0.5, 0.5)
	made.Size = UDim2.fromOffset(ASK_SIZE.X, ASK_SIZE.Y)
	made.ZIndex = 40
	made.Parent = gui()
	UIKit.creamWindow(made)
	local ink = UIKit.colorsFor(made).ink
	local face = Icon.make(made, "Paw", UDim2.fromOffset(34, 34))
	face.Position = UDim2.fromOffset(16, 16)
	local line = UIKit.label(made, labels.replayAsk, Enum.Font.FredokaOne, 22, ink)
	line.Position = UDim2.fromOffset(58, 16)
	line.Size = UDim2.new(1, -74, 0, 34)
	local yes = UIKit.button(made, labels.replayYes, UIKit.Colors.Success)
	yes.Name = "Yes"
	yes.AnchorPoint = Vector2.new(0, 1)
	yes.Position = UDim2.new(0, 16, 1, -16)
	yes.Size = UDim2.fromOffset(170, 52)
	yes.Font = Enum.Font.FredokaOne
	yes.TextSize = 22
	local no = UIKit.button(made, labels.replayNo, CARD_GREY)
	no.Name = "No"
	no.AnchorPoint = Vector2.new(1, 1)
	no.Position = UDim2.new(1, -16, 1, -18)
	no.Size = UDim2.fromOffset(112, 48)
	no.Font = Enum.Font.FredokaOne
	no.TextSize = 18
	local function close()
		made:Destroy()
		askCard = nil
	end
	yes.Activated:Connect(function()
		close()
		onYes()
	end)
	no.Activated:Connect(close)
	askCard = made
end

function TutorialCues.isTourCardOpen(): boolean
	return card ~= nil and card.Parent ~= nil
end

-- The tour card away (the first visit ended under it)
function TutorialCues.closeTourCard()
	if card then
		card:Destroy()
		card = nil
	end
end

-- The spotlight (round 3, pick A): everything dims but the button Pish points at (his card, the paw and Skip stay
-- above it); nil takes it away. Four dim frames round the button, following it
function TutorialCues.spotlight(target: GuiObject?)
	spotTarget = target
	if spotFrames or not target then
		return
	end
	local frames = {}
	for i = 1, 4 do
		local dim = Instance.new("Frame")
		dim.Name = "Dim" .. i
		dim.BackgroundColor3 = DIM_COLOR
		dim.BackgroundTransparency = DIM_TRANSPARENCY
		dim.BorderSizePixel = 0
		dim.ZIndex = 15
		dim.Active = false
		dim.Visible = false
		dim.Parent = gui()
		table.insert(frames, dim)
	end
	spotFrames = frames
	RunService.RenderStepped:Connect(function()
		local current = spotTarget
		local shown = current ~= nil and current.Parent ~= nil and current.Visible and current.AbsoluteSize.X > 0
		for _, dim in frames do
			dim.Visible = shown
		end
		if not shown or not current then
			return
		end
		local screenSize = gui().AbsoluteSize
		-- Whole pixels, so the four frames meet without a bright seam between them
		local left = math.floor(current.AbsolutePosition.X - SPOT_PAD)
		local top = math.floor(current.AbsolutePosition.Y - SPOT_PAD)
		local right = math.ceil(current.AbsolutePosition.X + current.AbsoluteSize.X + SPOT_PAD)
		local bottom = math.ceil(current.AbsolutePosition.Y + current.AbsoluteSize.Y + SPOT_PAD)
		frames[1].Position, frames[1].Size = UDim2.fromOffset(0, -60), UDim2.fromOffset(screenSize.X, math.max(0, top + 60))
		frames[2].Position, frames[2].Size = UDim2.fromOffset(0, bottom), UDim2.fromOffset(screenSize.X, math.max(0, screenSize.Y - bottom))
		frames[3].Position, frames[3].Size = UDim2.fromOffset(0, top), UDim2.fromOffset(math.max(0, left), bottom - top)
		frames[4].Position, frames[4].Size = UDim2.fromOffset(right, top), UDim2.fromOffset(math.max(0, screenSize.X - right), bottom - top)
	end)
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
