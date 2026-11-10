--!strict
-- Pish's talk card (spec 2026-11-09-tutorial-pish-design 14, the owner's pick A): at the bottom centre, just above the
-- HUD tiles, a cotton candy card with Pish's face (his model in a little window), his name, one short line in big
-- text, the picture of the thing to use, and a big Next while he has more to say. A new line types itself in; a tap on
-- the card (or Next) shows the rest, then moves on. Lines come from Config/PishTalk through Util/TalkRules.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PishTalk = require(Shared:WaitForChild("Config"):WaitForChild("PishTalk"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local TutorialTalk = {}

local WIDTH = 560 -- px at most; a share of a narrow screen
local SCREEN_SHARE = 0.64
local MIN_WIDTH = 260 -- px: it never gets narrower than this to clear the Skip button
local HEIGHT = 112
local FACE = 84
local PICTURE = 52
local NEXT_WIDTH = 108
local GAP = 34 -- px above the HUD tiles (their icons pop up out of the row)
local TOP = 66 -- px from the top when the card goes up there
local BAR_GAP = 12 -- px above the placement bar while the player places something
local PAW_ROOM = 82 -- px over the button Pish points at for his bouncing paw (Util/TutorialCues: 64 + lift + bounce)
local EDGE = 8 -- px kept clear of the screen's edges and the HUD's side columns
local TYPE_SPEED = 45 -- letters a second
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local card: Frame? = nil
local line: TextLabel? = nil
local nextButton: TextButton? = nil
local picture: Frame? = nil
local scale: UIScale? = nil
local typedAt = 0
local avoid: GuiObject? = nil -- what Pish points at in a window: the card moves to the top rather than cover it
local tiles: GuiObject? = nil
local shownText = ""
local shownIcon: string? = nil
local onNext: (() -> ())? = nil
local speakerName = "Pish" -- whose card it is (TutorialTalk.speaker): his face and name
local nameLabel: TextLabel? = nil
local forceTop = false -- in a fight the card sits at the top, clear of the combat buttons (TutorialTalk.atTop)

-- The speaker's head in a little window, Pish's or Chikin's (the paw while his model isn't in the game)
local function face(parent: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Face"
	holder.Size = UDim2.fromOffset(FACE, FACE)
	holder.Position = UDim2.new(0, 12, 0.5, 0)
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.BackgroundColor3 = Color3.fromRGB(255, 246, 224)
	holder.Parent = parent
	UIKit.corner(holder, FACE / 2)
	UIKit.outline(holder, Color3.fromRGB(255, 215, 122), 3)
	local models = ReplicatedStorage:FindFirstChild("NpcModels")
	local model = models and models:FindFirstChild(speakerName)
	if not model or not model:IsA("Model") then
		local paw = Icon.make(holder, "Paw", UDim2.fromScale(0.7, 0.7))
		paw.AnchorPoint = Vector2.new(0.5, 0.5)
		paw.Position = UDim2.fromScale(0.5, 0.5)
		return
	end
	local view = Instance.new("ViewportFrame")
	view.Size = UDim2.fromScale(1, 1)
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 200)
	view.LightColor = Color3.fromRGB(255, 255, 255)
	view.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = view
	local copy = model:Clone()
	copy:PivotTo(CFrame.new())
	copy.Parent = view
	local box, size = copy:GetBoundingBox()
	local head = box.Position + Vector3.new(0, size.Y * 0.28, -size.Z * 0.2)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(head + Vector3.new(0, size.Y * 0.05, -size.Y * 1.9), head)
	camera.Parent = view
	view.CurrentCamera = camera
end

local function build(): Frame
	local made = Instance.new("Frame")
	made.Name = "PishTalk"
	made.AnchorPoint = Vector2.new(0.5, 1)
	made.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	made.ZIndex = 25
	made.Parent = TutorialCues.screen()
	UIKit.creamWindow(made)
	scale = Instance.new("UIScale")
	scale.Parent = made
	face(made)
	local colors = UIKit.colorsFor(made)

	local name = UIKit.label(made, speakerName, Enum.Font.FredokaOne, 18, Color3.fromRGB(224, 138, 44))
	name.Name = "Speaker"
	nameLabel = name
	name.Position = UDim2.fromOffset(12 + FACE + 12, 10)
	name.Size = UDim2.new(1, -(12 + FACE + 12 + NEXT_WIDTH + PICTURE + 30), 0, 22)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local text = UIKit.label(made, "", Enum.Font.FredokaOne, 24, colors.ink)
	text.Name = "Line"
	text.Position = UDim2.fromOffset(12 + FACE + 12, 32)
	text.Size = UDim2.new(1, -(12 + FACE + 12 + NEXT_WIDTH + PICTURE + 30), 1, -40)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 24
	limit.MinTextSize = 14
	limit.Parent = text
	line = text

	local thing = Instance.new("Frame")
	thing.Name = "Picture"
	thing.BackgroundTransparency = 1
	thing.AnchorPoint = Vector2.new(1, 0.5)
	thing.Position = UDim2.new(1, -(NEXT_WIDTH + 22), 0.5, 0)
	thing.Size = UDim2.fromOffset(PICTURE, PICTURE)
	thing.Parent = made
	picture = thing

	local button = UIKit.button(made, PishTalk.NEXT, UIKit.Colors.Accent)
	button.Name = "Next"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	button.Size = UDim2.fromOffset(NEXT_WIDTH, 56)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 22
	button.Activated:Connect(function()
		TutorialTalk.advance()
	end)
	nextButton = button

	-- A tap anywhere on the card moves on too
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 0
	tap.Parent = made
	tap.Activated:Connect(function()
		TutorialTalk.advance()
	end)

	-- Just above the HUD's bottom tiles, as wide as fits; at the top instead when it would cover what Pish points at
	RunService.RenderStepped:Connect(function()
		if not made.Visible then
			return
		end
		local screenSize = TutorialCues.screen().AbsoluteSize
		if not tiles or not tiles.Parent then
			local main = made:FindFirstAncestorWhichIsA("PlayerGui")
			local gui = main and main:FindFirstChild("MainGui")
			local found = gui and gui:FindFirstChild("HudBottom", true)
			tiles = if found and found:IsA("GuiObject") then found else nil
		end
		local row = tiles
		local bottom = if row then row.AbsolutePosition.Y - GAP else screenSize.Y - GAP
		-- Clear of the HUD's side columns beside it (on a phone the cash, weapon switch and party run down the right)
		local leftEdge, rightEdge = EDGE, screenSize.X - EDGE
		local main = made:FindFirstAncestorWhichIsA("PlayerGui")
		local gui = main and main:FindFirstChild("MainGui")
		-- Above the Rotate / Place / Cancel bar while the player places something (phones need those buttons)
		local placing = gui and gui:FindFirstChild("PlacementBar", true)
		if placing and placing:IsA("GuiObject") and placing.Visible then
			bottom = math.min(bottom, placing.AbsolutePosition.Y - BAR_GAP)
		end
		local height = HEIGHT * math.min(WIDTH, screenSize.X * SCREEN_SHARE) / WIDTH
		for _, columnName in { "StatusRow", "HudSide" } do
			local column = gui and gui:FindFirstChild(columnName)
			if column and column:IsA("GuiObject") and column.Visible then
				local top, low = column.AbsolutePosition.Y, column.AbsolutePosition.Y + column.AbsoluteSize.Y
				if low > bottom - height and top < bottom then
					if columnName == "StatusRow" then
						rightEdge = math.min(rightEdge, column.AbsolutePosition.X - EDGE)
					else
						leftEdge = math.max(leftEdge, column.AbsolutePosition.X + column.AbsoluteSize.X + EDGE)
					end
				end
			end
		end
		local width = math.min(WIDTH, screenSize.X * SCREEN_SHARE)
		local centre = screenSize.X / 2
		if centre + width / 2 > rightEdge or centre - width / 2 < leftEdge then
			width = math.min(width, rightEdge - leftEdge)
			centre = math.clamp(centre, leftEdge + width / 2, rightEdge - width / 2)
		end
		local fit = width / WIDTH
		if scale then
			scale.Scale = scale:GetAttribute("Popping") and scale.Scale or fit
		end
		height = HEIGHT * fit
		local target = avoid
		local covered = false
		if target and target.Parent then
			local top, low = target.AbsolutePosition.Y, target.AbsolutePosition.Y + target.AbsoluteSize.Y
			local left, right = target.AbsolutePosition.X, target.AbsolutePosition.X + target.AbsoluteSize.X
			local cardLeft, cardRight = centre - width / 2, centre + width / 2
			local across = right > cardLeft and left < cardRight
			if across and top >= bottom and top - PAW_ROOM < bottom then
				-- A HUD tile under the card: up enough to show the paw bouncing on it
				bottom = top - PAW_ROOM
			end
			covered = across and low > bottom - height and top - PAW_ROOM < bottom
		end
		covered = covered or forceTop
		-- Clear of the Skip button at the top right (on a short phone screen a raised card reaches it): narrower, to its
		-- left
		local cardTop = if covered then TOP else bottom - height
		local skip = TutorialCues.screen():FindFirstChild("TutorialSkip")
		if skip and skip:IsA("GuiObject") and skip.Visible then
			local skipLow = skip.AbsolutePosition.Y + skip.AbsoluteSize.Y
			local skipLeft = skip.AbsolutePosition.X - EDGE
			if cardTop < skipLow and centre + width / 2 > skipLeft then
				local cardLeft = centre - width / 2
				width = math.max(MIN_WIDTH, skipLeft - math.max(leftEdge, cardLeft))
				centre = math.max(leftEdge, cardLeft) + width / 2
				fit = width / WIDTH
				if scale and not scale:GetAttribute("Popping") then
					scale.Scale = fit
				end
			end
		end
		made.AnchorPoint = Vector2.new(0.5, if covered then 0 else 1)
		made.Position = UDim2.fromOffset(centre, if covered then TOP else bottom)
		if line and shownText ~= "" then
			local letters = math.floor((os.clock() - typedAt) * TYPE_SPEED)
			line.MaxVisibleGraphemes = if letters >= utf8.len(shownText) :: number then -1 else letters
		end
	end)
	card = made
	return made
end

local function fit(): number
	local screenSize = TutorialCues.screen().AbsoluteSize
	return math.min(WIDTH, screenSize.X * SCREEN_SHARE) / WIDTH
end

-- Show a line: `next` is the button's label (nil: no button, the line stays), `icon` the picture of the thing to use
-- (Config/UIIcons name), `advance` what Next does
function TutorialTalk.say(text: string, icon: string?, next: string?, advance: (() -> ())?)
	local shown = card or build()
	local isNew = text ~= shownText or not shown.Visible
	shown.Visible = true
	onNext = advance
	if nextButton then
		nextButton.Visible = next ~= nil
		nextButton.Text = next or ""
	end
	if picture and icon ~= shownIcon then
		shownIcon = icon
		for _, child in picture:GetChildren() do
			child:Destroy()
		end
		if icon then
			Icon.make(picture, icon, UDim2.fromScale(1, 1))
		end
	end
	if not isNew or not line then
		return
	end
	shownText = text
	line.Text = text
	typedAt = os.clock()
	line.MaxVisibleGraphemes = 0
	if scale then
		local target = fit()
		scale:SetAttribute("Popping", true)
		scale.Scale = target * 0.92
		local tween = TweenService:Create(scale, POP, { Scale = target })
		tween.Completed:Once(function()
			scale:SetAttribute("Popping", nil)
		end)
		tween:Play()
	end
end

-- Next (or a tap on the card): the rest of a line still typing, else on to the next one
function TutorialTalk.advance()
	if not line or shownText == "" then
		return
	end
	local typed = line.MaxVisibleGraphemes
	if typed ~= -1 and typed < (utf8.len(shownText) :: number) then
		typedAt = -math.huge -- show it all now
		return
	end
	local callback = onNext
	if callback and nextButton and nextButton.Visible then
		callback()
	end
end

-- Whose card it is: "Pish" (the default) or "Chikin": his face and name
function TutorialTalk.speaker(name: string)
	if name == speakerName then
		return
	end
	speakerName = name
	local shown = card
	if shown then
		local old = shown:FindFirstChild("Face")
		if old then
			old:Destroy()
		end
		face(shown)
	end
	if nameLabel then
		nameLabel.Text = name
	end
end

-- In a fight: the card at the top, clear of the combat buttons
function TutorialTalk.atTop(on: boolean)
	forceTop = on
end

-- What Pish points at in a window now (nil: nothing to keep clear)
function TutorialTalk.keepClear(target: GuiObject?)
	avoid = target
end

function TutorialTalk.hide()
	if card then
		card.Visible = false
	end
	shownText = ""
	onNext = nil
end

return TutorialTalk
