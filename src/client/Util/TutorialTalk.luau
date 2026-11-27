--!strict
-- Pish's talk card (spec 2026-11-09-tutorial-pish-design 14, the owner's pick A): at the top centre (the owner
-- 2026-11-11: "so that pish model can be seen"; down above the HUD tiles when the top would cover what he points at,
-- and never on it: Util/TalkRules.cardPlace, spec 2026-11-25-pish-first-steps-design), a cotton candy card with Pish's face (his model in a little window), his name, one short line in big
-- text, the picture of the thing to use, and a big Next while he has more to say. A new line types itself in; a tap on
-- the card (or Next) shows the rest, then moves on. Lines come from Config/PishTalk through Util/TalkRules.
-- Easy to notice and never waiting on a press (owner 2026-11-20: "tutorial is hard to notice ... people hardly press
-- next"; Config/PishTalk CARD, AUTO_NEXT, NEXT_RING): bigger on a computer, a new line pops in with a gold flash and a
-- soft chime, the button wears the tutorial's gold ring once the line is typed, and a plain Next presses itself
-- after time to read it (a bar fills on it).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PishTalk = require(Shared:WaitForChild("Config"):WaitForChild("PishTalk"))
local TalkRules = require(Shared:WaitForChild("Util"):WaitForChild("TalkRules"))
local HudGrow = require(Shared:WaitForChild("Util"):WaitForChild("HudGrow"))
local HudGrowConfig = require(Shared:WaitForChild("Config"):WaitForChild("HudGrow"))

local ClientUtil = script.Parent :: Instance
local Icon = require(ClientUtil:WaitForChild("Icon"))
local TutorialCues = require(ClientUtil:WaitForChild("TutorialCues"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

local TutorialTalk = {}

-- Smaller since 2026-11-11 (the owner: "the screen is really crowded ... a smaller fontsize and a smaller talk card";
-- was 560 x 112, text 24, name 18, face 84): Next keeps a finger-sized 48 px height
local WIDTH = 420 -- px at most; a share of a narrow screen
local SCREEN_SHARE = 0.64
local HEIGHT = 76
local FACE = 56
local PICTURE = 34
local NEXT_WIDTH = 84
local NEXT_HEIGHT = 48
local INSET = 10 -- px round the face and between it and the words
local NAME_SIZE = 14
local LINE_SIZE = 18 -- the line's biggest text (it shrinks to fit, never under LINE_MIN)
local LINE_MIN = 12
local GAP = 34 -- px above the HUD tiles (their icons pop up out of the row)
local TOP = 8 -- px under Roblox's top bar: where the card sits (the owner 2026-11-11: "move the dialogue higher up")
local FIGHT_TOP = 66 -- px in a fight: under the boss's HP bar
local BAR_GAP = 12 -- px above the placement bar while the player places something
local POINTER_ROOM = 82 -- px over the button Pish points at for his bouncing arrow (Util/TutorialCues: 64 + lift + bounce)
local EDGE = 8 -- px kept clear of the screen's edges and the HUD's side columns
local SIDE_FIT = 0.82 -- at the register the card stands at the left side, a little smaller (TalkRules.cardPlace)
local TYPE_SPEED = 45 -- letters a second
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local card: Frame? = nil
local line: TextLabel? = nil
local nextButton: TextButton? = nil
local picture: Frame? = nil
local scale: UIScale? = nil
local typedAt = 0
local avoid: GuiObject? = nil -- what Pish points at: the card moves down above the HUD rather than cover it
local tiles: GuiObject? = nil
local shownText = ""
local shownIcon: string? = nil
local onNext: (() -> ())? = nil
local tapAdvances = true -- a tap on the card does what the button does (not for "Got it!", which sends Pish away)
local GOT_IT_GUARD = 0.5 -- seconds a fresh "Got it!" ignores presses: it takes Next's place, and a quick double tap on
-- Next must not send Pish away
local buttonSince = 0 -- when the button last changed what it does
local speakerName = "Pish" -- whose card it is (TutorialTalk.speaker): his face and name
local nameLabel: TextLabel? = nil
local forceTop = false -- in a fight the card sits at the top, clear of the combat buttons (TutorialTalk.atTop)
local glowStroke: UIStroke? = nil -- the gold edge a new line flashes
local glowAt = -math.huge -- os.clock() of the last new line
local ringStroke: UIStroke? = nil -- the gold ring round the button once the line is typed
local nextBar: Frame? = nil -- the bar filling on a Next that presses itself
local readFor = 0 -- seconds the typed line has been up (while the card shows)
local chime: Sound? = nil
local COVER_CHECK = 0.2 -- seconds between looks for something over the card
local coverCheck = 0
local covered = false -- a button or window of a screen above the tutorial's lies over the card (isCovered)
local lineLimit: UITextSizeConstraint? = nil -- the line's text size limits (in screen px: they don't follow the UIScale)
local avoidPointer: GuiObject? = nil -- the button his arrow bounces on (`avoid` is what the ring goes round: a whole tile)

-- A button's box on screen; nil when there's none (or it's gone)
local function boxOf(gui: GuiObject?): TalkRules.Box?
	if not gui or not gui.Parent then
		return nil
	end
	return { x = gui.AbsolutePosition.X, y = gui.AbsolutePosition.Y, w = gui.AbsoluteSize.X, h = gui.AbsoluteSize.Y }
end

-- The card's widest, in px: as designed on a phone, bigger on a computer (TalkRules.cardGrow)
local function widest(screenSize: Vector2): number
	local touch = UserInputService.TouchEnabled
	return WIDTH * TalkRules.cardGrow(touch, HudGrow.scale(screenSize.Y, touch, HudGrowConfig), PishTalk.CARD)
end

-- A see-through frame `pad` px round `parent` with a gold line on it (the card's flash, the button's ring)
local function goldEdge(parent: GuiObject, name: string, pad: number, thickness: number, color: { number }, radius: number): UIStroke
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(-pad, -pad)
	frame.Size = UDim2.new(1, pad * 2, 1, pad * 2)
	frame.ZIndex = parent.ZIndex
	frame.Parent = parent
	UIKit.corner(frame, radius + pad)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.fromRGB(color[1], color[2], color[3])
	stroke.Thickness = thickness
	stroke.Transparency = 1
	stroke.Parent = frame
	return stroke
end

-- Whether something that takes clicks lies over the card's button (else its middle) in a screen drawn above the
-- tutorial's: a level-up card's tap-to-close veil, a win screen (owner 2026-11-20: "sometimes the NEXT is not
-- clickable": the press went to what was on top). The card then waits out of the way (TutorialCues.quiet).
local function isCovered(shown: Frame): boolean
	local own = TutorialCues.screen()
	local playerGui = own.Parent
	if not playerGui or not playerGui:IsA("BasePlayerGui") then
		return false
	end
	local button = nextButton
	local piece: GuiObject = if button and button.Visible then button else shown
	local at = piece.AbsolutePosition + piece.AbsoluteSize / 2
	for _, object in playerGui:GetGuiObjectsAtPosition(at.X, at.Y) do
		local layer = object:FindFirstAncestorWhichIsA("ScreenGui")
		if layer and layer ~= own and layer.DisplayOrder > own.DisplayOrder and (object:IsA("GuiButton") or object.Active) then
			return true
		end
	end
	return false
end

local function cornerOf(piece: GuiObject): number
	local corner = piece:FindFirstChildOfClass("UICorner")
	return if corner then corner.CornerRadius.Offset else 12
end

-- The speaker's head in a little window, Pish's or Chikin's (the paw while his model isn't in the game)
local function face(parent: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Face"
	holder.Size = UDim2.fromOffset(FACE, FACE)
	holder.Position = UDim2.new(0, INSET, 0.5, 0)
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

	local words = INSET + FACE + INSET -- where the name and the line start
	local room = words + NEXT_WIDTH + PICTURE + 26 -- the width the face, picture and Next take
	local name = UIKit.label(made, speakerName, Enum.Font.FredokaOne, NAME_SIZE, Color3.fromRGB(224, 138, 44))
	name.Name = "Speaker"
	nameLabel = name
	name.Position = UDim2.fromOffset(words, 7)
	name.Size = UDim2.new(1, -room, 0, 16)
	name.TextXAlignment = Enum.TextXAlignment.Left

	local text = UIKit.label(made, "", Enum.Font.FredokaOne, LINE_SIZE, colors.ink)
	text.Name = "Line"
	text.Position = UDim2.fromOffset(words, 24)
	text.Size = UDim2.new(1, -room, 1, -30)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.TextWrapped = true
	text.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = LINE_SIZE
	limit.MinTextSize = LINE_MIN
	limit.Parent = text
	lineLimit = limit
	line = text

	local thing = Instance.new("Frame")
	thing.Name = "Picture"
	thing.BackgroundTransparency = 1
	thing.AnchorPoint = Vector2.new(1, 0.5)
	thing.Position = UDim2.new(1, -(NEXT_WIDTH + 18), 0.5, 0)
	thing.Size = UDim2.fromOffset(PICTURE, PICTURE)
	thing.Parent = made
	picture = thing

	local button = UIKit.button(made, PishTalk.NEXT, UIKit.Colors.Accent)
	button.Name = "Next"
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -INSET, 0.5, 0)
	button.Size = UDim2.fromOffset(NEXT_WIDTH, NEXT_HEIGHT)
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 18
	button.Activated:Connect(function()
		local callback = onNext
		if not tapAdvances and callback then
			if os.clock() - buttonSince >= GOT_IT_GUARD then
				callback() -- "Got it!": at once, even mid-line (not a double tap's second half)
			end
			return
		end
		TutorialTalk.advance()
	end)
	nextButton = button
	local ring = PishTalk.NEXT_RING
	ringStroke = goldEdge(button, "Ring", ring.pad, ring.thickness, ring.color, cornerOf(button))
	local barLook = PishTalk.NEXT_BAR
	local bar = Instance.new("Frame")
	bar.Name = "Timer"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, barLook.inset, 1, -barLook.inset + 2)
	bar.Size = UDim2.fromOffset(0, barLook.height)
	bar.BackgroundColor3 = button.TextColor3
	bar.BackgroundTransparency = barLook.transparency
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = button
	UIKit.corner(bar, barLook.height / 2)
	nextBar = bar
	local glow = PishTalk.CARD.GLOW
	glowStroke = goldEdge(made, "Glow", glow.pad, glow.thickness, glow.color, cornerOf(made))
	local sound = Instance.new("Sound")
	sound.Name = "NewLine"
	sound.SoundId = PishTalk.CARD.SOUND.id
	sound.Volume = PishTalk.CARD.SOUND.volume
	sound.PlaybackSpeed = PishTalk.CARD.SOUND.pitch
	sound.Parent = made
	chime = sound

	-- A tap anywhere on the card moves on too
	local tap = Instance.new("TextButton")
	tap.Name = "Tap"
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 0
	tap.Parent = made
	tap.Activated:Connect(function()
		if tapAdvances then
			TutorialTalk.advance()
		end
	end)

	-- At the top centre, as wide as fits; just above the HUD's bottom tiles instead when it would cover what Pish points at
	RunService.RenderStepped:Connect(function(dt)
		if not made.Visible then
			if covered then
				covered = false
				TutorialCues.quiet("covered", false)
			end
			return
		end
		coverCheck += dt
		if coverCheck >= COVER_CHECK then
			coverCheck = 0
			local now = isCovered(made)
			if now ~= covered then
				covered = now
				TutorialCues.quiet("covered", now)
			end
		end
		if covered then
			return -- waiting under what has the screen: no typing, no timer
		end
		local screenSize = TutorialCues.screen().AbsoluteSize
		local grown = widest(screenSize)
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
		local height = HEIGHT * math.min(grown, screenSize.X * SCREEN_SHARE) / WIDTH
		for _, columnName in { "StatusRow", "HudSide", "PartyDock" } do
			local column = gui and gui:FindFirstChild(columnName)
			-- a computer's party dock sits in the bottom bar's middle (Config/DesktopHud): not a column at the left edge
			local inBar = columnName == "PartyDock" and column ~= nil and column:IsA("GuiObject") and column.AbsolutePosition.X > screenSize.X * 0.2
			if column and column:IsA("GuiObject") and column.Visible and not inBar then
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
		local width = math.min(grown, screenSize.X * SCREEN_SHARE)
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
		local target, pointer = boxOf(avoid), boxOf(avoidPointer or avoid)
		if not target then
			-- nothing on the screen to point at: the arrow over a thing in the world, or waiting at the screen's edge
			-- (seen 2026-11-27: Chikin's card covered the Wild's paw on the walk there)
			target = TutorialCues.worldPointerBox()
		end
		local cardLeft = centre - width / 2
		if pointer and pointer.x + pointer.w > cardLeft and pointer.x < cardLeft + width and pointer.y >= bottom and pointer.y - POINTER_ROOM < bottom then
			-- A HUD tile under the card when it's down: up enough to show the arrow bouncing on it
			bottom = pointer.y - POINTER_ROOM
		end
		local top = if forceTop then FIGHT_TOP else TOP
		local manning = Players.LocalPlayer:GetAttribute("ManningRegister") == true
		-- The card's two spots with Skip's tap area docked to each (spec 2026-11-25-pish-first-steps-design 1)
		local topCard: TalkRules.Box = { x = cardLeft, y = top, w = width, h = height }
		local lowCard: TalkRules.Box = { x = cardLeft, y = bottom - height, w = width, h = height }
		local topSkip, lowSkip = TutorialCues.skipBox(topCard, true), TutorialCues.skipBox(lowCard, false)
		local spots: { TalkRules.Spot } = {
			{ name = "top", boxes = if topSkip then { topCard, topSkip } else { topCard } },
			{ name = "bottom", boxes = if lowSkip then { lowCard, lowSkip } else { lowCard } },
		}
		local where = TalkRules.cardPlace(spots, target, if pointer then TalkRules.pointerBox(pointer, POINTER_ROOM) else nil, forceTop, manning)
		if where == "side" then
			-- at the register: left of its screen and drawer, half way down (under the Leave pill)
			made.AnchorPoint = Vector2.new(0, 0.5)
			made.Position = UDim2.fromOffset(EDGE + 4, screenSize.Y * 0.47)
			if scale and not scale:GetAttribute("Popping") then
				scale.Scale = math.min(fit, SIDE_FIT)
			end
		else
			made.AnchorPoint = Vector2.new(0.5, if where == "top" then 0 else 1)
			made.Position = UDim2.fromOffset(centre, if where == "top" then top else bottom)
		end
		local typed = false
		local total = 0
		if line and shownText ~= "" then
			local letters = math.floor((os.clock() - typedAt) * TYPE_SPEED)
			total = utf8.len(shownText) :: number
			typed = letters >= total
			line.MaxVisibleGraphemes = if typed then -1 else letters
		end
		if glowStroke then
			glowStroke.Transparency = TalkRules.glow(os.clock() - glowAt, PishTalk.CARD.GLOW)
		end
		-- a bigger card (a computer's) has bigger words: a scaled text's size limits are in screen px
		if lineLimit and scale then
			local grownText = math.max(1, scale.Scale)
			lineLimit.MaxTextSize = math.round(LINE_SIZE * grownText)
			lineLimit.MinTextSize = math.round(LINE_MIN * grownText)
		end
		-- Once the line is typed: the gold ring round the button, and a plain Next fills up and presses itself
		local button = nextButton
		local waiting = typed and button ~= nil and button.Visible
		if ringStroke then
			local ring = PishTalk.NEXT_RING
			local beat = (math.sin(os.clock() * 2 * math.pi / ring.beat) + 1) / 2
			ringStroke.Transparency = if waiting then ring.pulse[1] + beat * (ring.pulse[2] - ring.pulse[1]) else 1
		end
		local auto = waiting and button ~= nil and onNext ~= nil and TalkRules.pressesItself(button.Text, PishTalk.NEXT, not tapAdvances)
		if nextBar then
			nextBar.Visible = auto
		end
		if not auto or not button then
			readFor = 0
			return
		end
		readFor += dt
		local need = TalkRules.readSeconds(total, PishTalk.AUTO_NEXT)
		if nextBar then
			local share = math.min(1, readFor / need)
			nextBar.Size = UDim2.new(share, -PishTalk.NEXT_BAR.inset * 2 * share, 0, PishTalk.NEXT_BAR.height)
		end
		if readFor >= need then
			readFor = 0
			local callback = onNext
			if callback then
				callback()
			end
		end
	end)
	card = made
	return made
end

local function fit(): number
	local screenSize = TutorialCues.screen().AbsoluteSize
	return math.min(widest(screenSize), screenSize.X * SCREEN_SHARE) / WIDTH
end

-- Show a line: `next` is the button's label (nil: no button, the line stays), `icon` the picture of the thing to use
-- (Config/UIIcons name), `advance` what Next does; `buttonOnly`: only the button does it, not a tap on the card (a
-- "Got it!" that sends Pish away, owner 2026-11-18)
function TutorialTalk.say(text: string, icon: string?, next: string?, advance: (() -> ())?, buttonOnly: boolean?)
	local shown = card or build()
	local isNew = text ~= shownText or not shown.Visible
	shown.Visible = true
	onNext = advance
	tapAdvances = buttonOnly ~= true
	if nextButton then
		if nextButton.Text ~= (next or "") or not nextButton.Visible then
			buttonSince = os.clock()
		end
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
	readFor = 0
	glowAt = os.clock()
	if chime then
		chime:Play()
	end
	if scale then
		local target = fit()
		scale:SetAttribute("Popping", true)
		scale.Scale = target * PishTalk.CARD.POP
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

-- What Pish points at now, kept clear of the card (nil: nothing; then the arrow over a thing in the world): `target`
-- what his ring goes round, `pointer` the button his arrow bounces on (the same one unless the ring takes a whole
-- tile: the rack's Buy)
function TutorialTalk.keepClear(target: GuiObject?, pointer: GuiObject?)
	avoid = target
	avoidPointer = pointer
end

function TutorialTalk.hide()
	if card then
		card.Visible = false
	end
	shownText = ""
	onNext = nil
	tapAdvances = true
end

return TutorialTalk
