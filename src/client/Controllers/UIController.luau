--!strict
-- Owns the main ScreenGui: the status corner (the party dock, buff, cash) and toast messages. Your level and XP are in
-- the party dock (PartyBarController). Star Shards show in the Bag, not here.
-- Other controllers add their panels to UIController.GetScreenGui(), and status items to GetStatusFrame().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local LevelRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelRules"))
local LevelUpRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelUpRules"))
local Levels = require(Shared:WaitForChild("Config"):WaitForChild("Levels"))
local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Motion = require(ClientUtil:WaitForChild("Motion"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local HudLayout = require(Shared:WaitForChild("Config"):WaitForChild("HudLayout"))
local CompactHud = require(Shared:WaitForChild("Util"):WaitForChild("CompactHud"))
local HudMascotConfig = require(Shared:WaitForChild("Config"):WaitForChild("HudMascot"))
local GuiService = game:GetService("GuiService")
local SquishRules = require(Shared:WaitForChild("Util"):WaitForChild("SquishRules"))
local SoftHud = require(Shared:WaitForChild("Config"):WaitForChild("SoftHud"))
local Toasts = require(Shared:WaitForChild("Config"):WaitForChild("Toasts"))
local ToastRules = require(Shared:WaitForChild("Util"):WaitForChild("ToastRules"))
local HudMascotView = require(ClientUtil:WaitForChild("HudMascotView"))

local LEVEL_UP_TOAST_SECONDS = 5
local PILL_COLOR = Color3.fromRGB(22, 26, 38)
local PILL_HEIGHT = 42
local PILL_GAP = 8
local ICON_SIZE = HudLayout.STATUS_ICON -- the coin and the star poke out past the pill's top and bottom
-- Status sits in the bottom-right corner (the top corners hold Roblox's menu, chat and the player list). The
-- column, bottom up: cash (in line with the party dock's foot), the rating chip, then the buff badge; toasts pop in
-- just above it. Touch screens: see TOUCH_TOP.
local STATUS_MARGIN = 12
-- Fixed sizes, not AutomaticSize: an auto-sized frame anchored to the right edge can lay out past the screen edge
local STATUS_WIDTH = 250
local STATUS_HEIGHT = 170 -- the party dock's height (the column beside it: buff badge, rating chip, cash, gaps)
local STATUS_ROW_WIDTH = 500 -- party dock + gap + status column; spare width is empty and lets clicks through
-- Everything in the corner shrinks with the screen's height (Hud.scaleWith, HudLayout.SCALE). On touch screens
-- (landscape phones are short, the jump button takes the bottom right) it is one column down the right edge from
-- the very top: buff, cash, then the party dock; the toasts pop in left of it.
local TOUCH_TOP = 8
local TOUCH_PARTY_HEIGHT = 170 -- room for the party dock under the column

local player = Players.LocalPlayer

local UIController = {}

local screenGui: ScreenGui
local statusRow: Frame
local statusFrame: Frame
local statusLayout: UIListLayout? = nil -- the column's layout: the toasts sit right over what it shows
local toastStack: Frame -- the toasts' bubbles, over the cash pill (placeStatusRow)
local dockHolder: Frame -- the party dock on a PC: bottom left (owner 2026-11-13: "on desktop can we move character
-- info and party on the bottom left. align them"); on a phone the dock sits in the status row
local cashLabel: TextLabel
local cashPill: Frame
local cashScale: UIScale -- the cash pill smaller on a touch screen (HudLayout.CASH.touchScale)
local pishSeat: Frame? = nil -- Pish over the cash pill on a computer (HudMascotView)
local compactListeners: { (boolean) -> () } = {}
local function isCompact(): boolean
	return UserInputService.TouchEnabled
end

local function updateCash()
	local cash = player:GetAttribute("Cash")
	-- No Cash yet = the save is still loading (can take a while in Studio): say so, so it never looks like a reset
	local loaded = typeof(cash) == "number"
	local text = if not loaded then "Loading..." elseif isCompact() then CompactHud.money(cash) else string.format("$%.2f", cash)
	if cashLabel.Text ~= text and cashLabel.Text ~= "" then
		Motion.bump(cashPill)
	end
	cashLabel.Text = text
end

function UIController.GetScreenGui(): ScreenGui
	return screenGui
end

-- Bottom-right column: items stack upwards, right-aligned. Buff 1, cash 2 (bottom).
function UIController.GetStatusFrame(): Frame
	return statusFrame
end

-- Whether the phone's slim HUD is on (touch screens), and told when it changes (Studio's device
-- simulator switches mid-play); `listener` is called at once with today's answer too
function UIController.IsCompact(): boolean
	return isCompact()
end

function UIController.OnCompact(listener: (boolean) -> ())
	table.insert(compactListeners, listener)
	task.spawn(listener, isCompact())
end

-- The PC's bottom-left holder for the party dock (PartyBarController)
function UIController.GetDockHolder(): Frame
	return dockHolder
end

-- The whole bottom-right corner, laid out left to right; the status column (GetStatusFrame) is LayoutOrder 10
function UIController.GetStatusRow(): Frame
	return statusRow
end


-- Toasts (owner's pick A, 2026-11-06; Config/Toasts, Util/ToastRules): the HUD mascot's speech bubbles stacked just above
-- the cash pill, newest nearest the coin, messages and sales alike, at most MAX (MAX_TOUCH on touch screens). Each
-- pops up with a squash-and-bounce, stays its seconds and leaves shrinking and fading; the same message again bumps
-- the newest bubble instead of stacking a copy. The HUD's peeking Pish hops as a burst arrives.
type Bubble = { id: number, message: string, root: CanvasGroup, scale: UIScale, closing: boolean, closeAt: number }
local bubbles: { Bubble } = {} -- up now, oldest first
local nextToastId = 0
local lastHop: number? = nil

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function closeBubble(bubble: Bubble)
	if bubble.closing then
		return
	end
	bubble.closing = true
	local index = table.find(bubbles, bubble)
	if index then
		table.remove(bubbles, index)
	end
	local out = TweenInfo.new(Toasts.OUT.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(bubble.root, out, { GroupTransparency = 1 }):Play()
	local shrink = TweenService:Create(bubble.scale, out, { Scale = Toasts.OUT.scale })
	shrink.Completed:Once(function()
		bubble.root:Destroy()
	end)
	shrink:Play()
end

-- Closes `bubble` in `seconds`, unless it's bumped again (a later close) or closed before
local function closeLater(bubble: Bubble, seconds: number)
	local at = os.clock() + seconds
	bubble.closeAt = at
	task.delay(seconds, function()
		if bubble.closeAt == at then
			closeBubble(bubble)
		end
	end)
end

-- A bubble: its soft shadow, the tail (pointing down at the cash; up on touch screens, where the stack hangs under the
-- column), and the white body with the icon chip in its kind's colour and the words in its kind's ink
local function buildBubble(id: number, message: string, kind: string, icon: string): Bubble
	local look = Toasts.KINDS[kind]
	local touch = UserInputService.TouchEnabled
	local edge = Toasts.EDGE_THICKNESS
	local tailRoom = math.ceil(Toasts.TAIL * 0.75) + edge
	-- A canvas group, so the whole bubble fades as one; padded so the tail and shadow fit inside it
	local root = Instance.new("CanvasGroup")
	root.Name = "Toast"
	root.LayoutOrder = if touch then -id else id -- newest nearest the cash
	root.Size = UDim2.new()
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	local room = Instance.new("UIPadding")
	room.PaddingTop = UDim.new(0, if touch then tailRoom else edge)
	room.PaddingBottom = UDim.new(0, if touch then edge + Toasts.SHADOW_OFFSET else tailRoom + Toasts.SHADOW_OFFSET)
	room.PaddingLeft = UDim.new(0, edge)
	room.PaddingRight = UDim.new(0, edge)
	room.Parent = root
	local scale = Instance.new("UIScale")
	scale.Scale = Toasts.POP.from
	scale.Parent = root

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new()
	body.AutomaticSize = Enum.AutomaticSize.XY
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.ZIndex = 3
	body.Parent = root
	UIKit.corner(body, Toasts.CORNER)
	UIKit.outline(body, rgb(Toasts.EDGE), edge)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Toasts.PAD * 0.8)
	padding.PaddingBottom = UDim.new(0, Toasts.PAD * 0.8)
	padding.PaddingLeft = UDim.new(0, Toasts.PAD * 0.8)
	padding.PaddingRight = UDim.new(0, Toasts.PAD + 2)
	padding.Parent = body
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, Toasts.PAD * 0.8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = body

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.LayoutOrder = 1
	chip.Size = UDim2.fromOffset(Toasts.CHIP, Toasts.CHIP)
	chip.BackgroundColor3 = rgb(look.chip)
	chip.ZIndex = 4
	chip.Parent = body
	UIKit.corner(chip, Toasts.CHIP / 3)
	local glyph = Icon.make(chip, icon, UDim2.fromOffset(Toasts.ICON, Toasts.ICON))
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.ZIndex = 5
	for _, child in glyph:GetChildren() do
		if child:IsA("GuiObject") then
			child.ZIndex = 5
		end
	end

	local label = UIKit.label(body, message, Enum.Font.GothamBold, Toasts.TEXT, rgb(look.ink))
	label.Name = "Words"
	label.LayoutOrder = 2
	label.Size = UDim2.new()
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 4
	local wrap = Instance.new("UISizeConstraint")
	wrap.MaxSize = Vector2.new(Toasts.WIDTH - Toasts.CHIP - Toasts.CLOSE - Toasts.PAD * 4, math.huge)
	wrap.Parent = label

	-- The close button at the right end: an "x" in a lilac circle (the whole bubble closes it on a click or tap, below)
	local close = Instance.new("Frame")
	close.Name = "Close"
	close.LayoutOrder = 3
	close.Size = UDim2.fromOffset(Toasts.CLOSE, Toasts.CLOSE)
	close.BackgroundColor3 = rgb(Toasts.CLOSE_FILL)
	close.ZIndex = 4
	close.Parent = body
	UIKit.corner(close, Toasts.CLOSE / 2)
	local cross = UIKit.label(close, "x", Enum.Font.FredokaOne, Toasts.CLOSE * 0.7, rgb(Toasts.KINDS.news.ink))
	cross.Size = UDim2.fromScale(1, 1)
	cross.TextXAlignment = Enum.TextXAlignment.Center
	cross.TextYAlignment = Enum.TextYAlignment.Center
	cross.ZIndex = 5

	-- The shadow under the body, the same shape a little lower
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Position = UDim2.fromOffset(0, Toasts.SHADOW_OFFSET)
	shadow.BackgroundColor3 = rgb(Toasts.SHADOW)
	shadow.BackgroundTransparency = Toasts.SHADOW_TRANSPARENCY
	shadow.ZIndex = 1
	shadow.Parent = root
	UIKit.corner(shadow, Toasts.CORNER)
	-- The tail: a white square turned 45 degrees, half of it out past the body's edge; a white strip over the body's
	-- edge line where they meet, so the tail runs into the bubble
	local tailY = if touch then 0 else 1
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(1, -Toasts.TAIL_RIGHT, tailY, 0)
	tail.Size = UDim2.fromOffset(Toasts.TAIL, Toasts.TAIL)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.new(1, 1, 1)
	tail.ZIndex = 2
	tail.Parent = root
	UIKit.corner(tail, 3)
	UIKit.outline(tail, rgb(Toasts.EDGE), edge)
	local join = Instance.new("Frame")
	join.Name = "TailJoin"
	join.AnchorPoint = Vector2.new(0.5, 0.5)
	join.Position = UDim2.new(1, -Toasts.TAIL_RIGHT, tailY, 0)
	join.Size = UDim2.fromOffset(Toasts.TAIL * 1.2, edge * 2 + 2)
	join.BackgroundColor3 = Color3.new(1, 1, 1)
	join.BorderSizePixel = 0
	join.ZIndex = 6
	join.Parent = root

	-- The whole bubble is the close button (finger-sized on phones); the "x" darkens while the pointer is over it
	local hit = Instance.new("TextButton")
	hit.Name = "CloseHit"
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 8
	hit.Parent = root
	hit.MouseEnter:Connect(function()
		close.BackgroundColor3 = rgb(Toasts.CLOSE_HOVER)
	end)
	hit.MouseLeave:Connect(function()
		close.BackgroundColor3 = rgb(Toasts.CLOSE_FILL)
	end)

	root.Parent = toastStack
	local bubble: Bubble = { id = id, message = message, root = root, scale = scale, closing = false, closeAt = 0 }
	hit.Activated:Connect(function()
		closeBubble(bubble)
	end)
	return bubble
end

-- Pops up from small: overshoots, squashes, settles (Toasts.POP)
local function popIn(bubble: Bubble)
	local pop = Toasts.POP
	TweenService:Create(bubble.root, TweenInfo.new(pop.seconds * 0.3), { GroupTransparency = 0 }):Play()
	local grow = TweenService:Create(bubble.scale, TweenInfo.new(pop.seconds * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = pop.over })
	grow.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or bubble.closing then
			return
		end
		local squash = TweenService:Create(bubble.scale, TweenInfo.new(pop.seconds * 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Scale = pop.squash })
		squash.Completed:Once(function(done)
			if done == Enum.PlaybackState.Completed and not bubble.closing then
				TweenService:Create(bubble.scale, TweenInfo.new(pop.seconds * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		end)
		squash:Play()
	end)
	grow:Play()
end

local function pushToast(message: string, kind: string, duration: number?, icon: string?): number
	local look = Toasts.KINDS[kind]
	local seconds = ToastRules.seconds(Toasts, kind, duration)
	local entries: { ToastRules.Entry } = {}
	for _, bubble in bubbles do
		table.insert(entries, { id = bubble.id, message = bubble.message })
	end
	local max = if UserInputService.TouchEnabled then Toasts.MAX_TOUCH else Toasts.MAX
	local bumpId, drop = ToastRules.place(entries, message, max)
	if bumpId then
		for _, bubble in bubbles do
			if bubble.id == bumpId then
				bubble.scale.Scale = Toasts.BUMP.scale
				TweenService:Create(bubble.scale, TweenInfo.new(Toasts.BUMP.seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				closeLater(bubble, seconds)
				return bubble.id
			end
		end
	end
	for _, id in drop do
		for _, bubble in table.clone(bubbles) do
			if bubble.id == id then
				closeBubble(bubble)
			end
		end
	end
	-- A message's own emoji goes in the chip; else the given icon, else its kind's
	local emoji, words = ToastRules.leadingEmoji(message)
	nextToastId += 1
	local bubble = buildBubble(nextToastId, words, kind, emoji or icon or look.icon)
	bubble.message = message
	table.insert(bubbles, bubble)
	popIn(bubble)
	closeLater(bubble, seconds)
	local now = os.clock()
	if ToastRules.hopNow(lastHop, now, Toasts.HOP_GAP) then
		lastHop = now
		HudMascotView.hop()
	end
	return bubble.id
end

-- A toast over the cash pill: news (or red-ink errors) with an icon (Config/UIIcons name or emoji; the kind's own
-- otherwise). Returns a token for UIController.Dismiss.
function UIController.Notify(message: string, isError: boolean?, duration: number?, icon: string?): number
	return pushToast(message, ToastRules.kind(isError == true, false), duration, icon)
end

-- A money toast (sales and other money coming in): the same stack, in green ink with the coin
function UIController.NotifySide(message: string)
	pushToast(message, "money", nil, nil)
end

-- Takes a toast down early (e.g. a hint once it's been followed)
function UIController.Dismiss(token: number)
	for _, bubble in table.clone(bubbles) do
		if bubble.id == token then
			closeBubble(bubble)
		end
	end
end

-- Several level-ups can arrive at once; show them one after another instead of overwriting
local levelUpQueue: { number } = {}
local showingLevelUps = false

local function showLevelUps()
	showingLevelUps = true
	while #levelUpQueue > 0 do
		local level = table.remove(levelUpQueue, 1) :: number
		local unlocks = LevelRules.getUnlocks(level)
		-- "Level 7! +$70 · Unlocked: Deck Box" (the reward is paid on the server, Util/LevelUpRules)
		local message = `Level {level}! {LevelUpRules.rewardText(Levels, level)}`
		if #unlocks > 0 then
			message ..= ` · Unlocked: {table.concat(unlocks, ", ")}`
		end
		UIController.Notify(message, false, LEVEL_UP_TOAST_SECONDS)
		task.wait(LEVEL_UP_TOAST_SECONDS)
	end
	showingLevelUps = false
end

local function queueLevelUp(level: number)
	table.insert(levelUpQueue, level)
	if not showingLevelUps then
		task.spawn(showLevelUps)
	end
end

-- A dark rounded pill whose icon (Config/UIIcons) sits over its left end, a little bigger than the pill.
-- Its contents go in a row after the icon's space; returns the pill and that row.
local function makePill(parent: Instance, order: number, icon: string): (Frame, Frame)
	local pill = Instance.new("Frame")
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = PILL_COLOR
	pill.BackgroundTransparency = 0.1
	pill.Parent = parent
	UIKit.corner(pill, PILL_HEIGHT / 2)
	UIKit.outline(pill, UIKit.Colors.Outline, 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, ICON_SIZE - 4)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = pill
	-- The icon lives in a zero-size anchor so the row ignores it, then sits over the pill's left end
	local anchor = Instance.new("Frame")
	anchor.Name = "IconAnchor"
	anchor.LayoutOrder = 0
	anchor.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	anchor.BackgroundTransparency = 1
	anchor.Parent = pill
	local holder = Icon.make(anchor, icon, UDim2.fromOffset(ICON_SIZE, ICON_SIZE))
	holder.AnchorPoint = Vector2.new(0, 0.5)
	holder.Position = UDim2.new(0, -(ICON_SIZE + 2), 0.5, 0)
	return pill, anchor
end

local function addValue(pill: Frame, color: Color3): TextLabel
	local value = UIKit.label(pill, "", Enum.Font.FredokaOne, 22, color)
	value.LayoutOrder = 2
	value.Size = UDim2.fromOffset(0, PILL_HEIGHT)
	value.AutomaticSize = Enum.AutomaticSize.X
	value.TextWrapped = false
	return value
end

-- The cash pill in the corner column (spec 2026-11-03-hud-creature-pals-design): cash in a green pill with a big gold
-- coin. The level and XP moved into the party dock (owner 2026-11-13: "the exp/level looks broken")
-- The coin: bigger than the pill and poking out of it on a computer, inside it on a phone (HudLayout.CASH.touchCoin)
local function fitCoin(compact: boolean)
	local anchor = cashPill and cashPill:FindFirstChild("IconAnchor")
	local coin = if anchor then anchor:FindFirstChildWhichIsA("GuiObject") else nil
	local padding = if cashPill then cashPill:FindFirstChildOfClass("UIPadding") else nil
	if not coin or not padding then
		return
	end
	local size = if compact then HudLayout.CASH.touchCoin else ICON_SIZE
	local inset = if compact then (PILL_HEIGHT - size) / 2 else -2
	coin.Size = UDim2.fromOffset(size, size)
	coin.Position = UDim2.new(0, -(size + inset), 0.5, 0)
	padding.PaddingLeft = UDim.new(0, if compact then size + inset * 2 else ICON_SIZE - 4)
end

local function buildStatusPills()
	local column = statusFrame

	cashPill = makePill(column, 2, "Coin")
	cashPill.Name = "Cash"
	cashPill.BackgroundColor3 = Color3.new(1, 1, 1)
	cashPill.BackgroundTransparency = 0
	local edge = cashPill:FindFirstChildOfClass("UIStroke") :: UIStroke
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = HudLayout.OUTLINE
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(HudLayout.CASH.top, HudLayout.CASH.bottom)
	shade.Parent = cashPill
	cashScale = Instance.new("UIScale")
	cashScale.Scale = if isCompact() then HudLayout.CASH.touchScale else 1
	cashScale.Parent = cashPill
	fitCoin(isCompact())
	cashLabel = addValue(cashPill, Color3.new(1, 1, 1))
	UIKit.outlined(cashLabel, 2)

	-- Pish's seat over the cash pill on a computer (owner 2026-11-13 pick P1: "over the cash, saying the toasts"): his
	-- head over the pill's top edge, his paws behind it (the pill draws over him); a phone has no room, so no Pish there
	local mascot = HudMascotConfig
	if mascot.images.peek ~= "" then
		local width, height = mascot.size.peek[1], mascot.size.peek[2]
		local seat = Instance.new("Frame")
		seat.Name = "PishSeat"
		seat.LayoutOrder = 1 -- over the cash (2)
		seat.BackgroundTransparency = 1
		seat.Size = UDim2.fromOffset(width + mascot.perch.x * 2, math.max(0, height - mascot.perch.overlap - PILL_GAP))
		seat.Visible = not isCompact()
		seat.ZIndex = 1
		seat.Parent = column
		cashPill.ZIndex = 2
		pishSeat = seat
		HudMascotView.mount(seat, seat.Size.Y.Offset + PILL_GAP)
	end
end

-- The bottom-right corner (PC). On a narrow window the party bar would reach over the bottom-centre tiles (Cards,
-- Bag ...): then the corner lifts above the tile row. The toasts stay just above it. On touch screens the
-- corner is a column from the top right instead, the toasts under it.
local appliedTouch: boolean? = nil
local columnLayout: UIListLayout? = nil

-- The corner's arrangement for touch or not (a column from the top right on touch screens, a row in the bottom right
-- otherwise), done again if it changes while playing (Studio's device simulator, owner 2026-11-13: the party bar landed
-- at the top centre after switching to a phone)
local function arrange(rowLayout: UIListLayout)
	local touch = UserInputService.TouchEnabled
	if touch == appliedTouch then
		return
	end
	appliedTouch = touch
	statusRow.AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1)
	statusRow.Size = if touch then UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT + 8 + TOUCH_PARTY_HEIGHT) else UDim2.fromOffset(STATUS_ROW_WIDTH, STATUS_HEIGHT)
	rowLayout.FillDirection = if touch then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	if statusFrame then
		statusFrame.LayoutOrder = if touch then -1 else 10
		statusFrame.Size = if touch then UDim2.fromOffset(STATUS_WIDTH, 0) else UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT)
		statusFrame.AutomaticSize = if touch then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	end
	if columnLayout then
		columnLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	end
	if toastStack then
		toastStack.AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1)
		local toastLayout = toastStack:FindFirstChildOfClass("UIListLayout")
		if toastLayout then
			toastLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
		end
	end
end

-- The PC's party dock in the bottom-left corner: lifted above the bottom tiles' row when the window is too narrow for
-- both, and the side column (the Phone, Cards) lifted clear of it on a short window
local function placeDock()
	if not dockHolder then
		return
	end
	if UserInputService.TouchEnabled then
		Hud.liftSide(0)
		return
	end
	local width = screenGui.AbsoluteSize.X
	local tiles = screenGui:FindFirstChild("HudBottom")
	local tilesLeft = width / 2 - (if tiles and tiles:IsA("GuiObject") then tiles.AbsoluteSize.X / 2 else 0)
	local bottom = STATUS_MARGIN
	if HudLayout.SIDE_X + dockHolder.AbsoluteSize.X + STATUS_MARGIN > tilesLeft then
		bottom = math.max(bottom, SquishRules.rowTop(SoftHud.TILE, SoftHud.SQUISH, HudLayout.BOTTOM_MARGIN, Hud.scaleFor()) + PILL_GAP)
	end
	dockHolder.Position = UDim2.new(0, HudLayout.SIDE_X, 1, -bottom)
	local sideFrame = screenGui:FindFirstChild("HudSide")
	if sideFrame and sideFrame:IsA("GuiObject") then
		local dockTop = screenGui.AbsoluteSize.Y - bottom - dockHolder.AbsoluteSize.Y
		local sideBottom = screenGui.AbsoluteSize.Y / 2 + sideFrame.AbsoluteSize.Y / 2
		Hud.liftSide(math.max(0, sideBottom - dockTop + PILL_GAP))
	end
end

local function placeStatusRow(rowLayout: UIListLayout)
	local wasCompact = appliedTouch
	arrange(rowLayout)
	if wasCompact ~= appliedTouch then
		-- the slim phone HUD on or off: the cash's words, and whoever listens
		local compact = appliedTouch == true
		if cashScale then
			cashScale.Scale = if compact then HudLayout.CASH.touchScale else 1
		end
		fitCoin(compact)
		if pishSeat then
			pishSeat.Visible = not compact
		end
		HudMascotView.setHidden(compact or Hud.hides("mascot"))
		if cashLabel then
			updateCash()
		end
		Hud.setCompact(compact) -- Bag, Bosses, Admin into the Phone, Cards under it
		for _, listener in compactListeners do
			task.spawn(listener, compact)
		end
	end
	if UserInputService.TouchEnabled then
		-- at the very top (owner 2026-11-13: "leveled with the roblox icons on the other side"): your row (the party dock
		-- moves it here on a phone) centred on Roblox's top bar strip, the cash pill and the dock under it
		local inset = GuiService:GetGuiInset().Y
		local first = statusRow:FindFirstChild("MeRow")
		local height = if first and first:IsA("GuiObject") then first.AbsoluteSize.Y else 0
		local top = math.max(TOUCH_TOP / 4, (inset - height) / 2) - inset
		statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 0, top)
		if toastStack then
			-- left of the column, under the top bar strip: clear of the dock and the jump button
			local beside = STATUS_MARGIN + rowLayout.AbsoluteContentSize.X + 8
			toastStack.Position = UDim2.new(1, -beside, 0, top + height + 8)
		end
		return
	end
	local bottom = STATUS_MARGIN
	local width = screenGui.AbsoluteSize.X
	local tiles = screenGui:FindFirstChild("HudBottom")
	local tilesRight = width / 2 + (if tiles and tiles:IsA("GuiObject") then tiles.AbsoluteSize.X / 2 else 0)
	local rowLeft = width - STATUS_MARGIN - rowLayout.AbsoluteContentSize.X
	local scale = Hud.scaleFor()
	if rowLeft < tilesRight + STATUS_MARGIN then
		-- Clear of the tiles' popped-out icons, hovered too (SquishRules.rowTop)
		bottom = math.max(bottom, SquishRules.rowTop(SoftHud.TILE, SoftHud.SQUISH, HudLayout.BOTTOM_MARGIN, scale) + PILL_GAP)
	end
	statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 1, -bottom)
	if toastStack then
		-- Out of Pish over the cash pill, as if he says it (owner 2026-11-12; back there 2026-11-13 pick P1); while he's
		-- hidden, right over the column's top item
		local head = HudMascotView.head()
		if head then
			local corner = ToastRules.stackCorner({ x = head.X, y = head.Y }, Toasts.TAIL_RIGHT, Toasts.TAIL, scale)
			toastStack.Position = UDim2.fromOffset(corner.x, corner.y)
			return
		end
		local column = if statusLayout then statusLayout.AbsoluteContentSize.Y else STATUS_HEIGHT * scale
		toastStack.Position = UDim2.new(1, -STATUS_MARGIN, 1, -(bottom + column + PILL_GAP))
	end
end

function UIController.Start()
	-- Roblox's player list goes: the plaza leaderboard ranks players (owner 2026-11-13, Config/Leaderboard)
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MainGui"
	screenGui.ResetOnSpawn = false
	-- Children always draw above their parent; ZIndex only orders panels against each other.
	-- (The code default is Global, where a raised panel would cover its own contents.)
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")
	Hud.mount(screenGui)

	-- A row (party bar, then the column of buff, cash and XP) so the corner stays short on landscape phones
	statusRow = Instance.new("Frame")
	statusRow.Name = "StatusRow"
	statusRow.AnchorPoint = Vector2.new(1, 1)
	statusRow.Size = UDim2.fromOffset(STATUS_ROW_WIDTH, STATUS_HEIGHT)
	statusRow.BackgroundTransparency = 1
	statusRow.Parent = screenGui
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = statusRow
	local touch = UserInputService.TouchEnabled -- touch screens: one column down the right edge from the top (arrange)
	Hud.scaleWith(statusRow, if touch then HudLayout.SCALE.TOUCH_MIN else nil)
	-- The PC's party dock holder (bottom left; PartyBarController puts the dock in it off a phone)
	dockHolder = Instance.new("Frame")
	dockHolder.Name = "PartyDock"
	dockHolder.AnchorPoint = Vector2.new(0, 1)
	dockHolder.Size = UDim2.new()
	dockHolder.AutomaticSize = Enum.AutomaticSize.XY
	dockHolder.BackgroundTransparency = 1
	dockHolder.Parent = screenGui
	Hud.scaleWith(dockHolder)
	Hud.hideWith(dockHolder) -- full-screen views (the binder) cover it
	local function place()
		placeStatusRow(rowLayout)
		placeDock()
	end
	dockHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(place)
	local tiles = screenGui:FindFirstChild("HudBottom")
	if tiles and tiles:IsA("GuiObject") then
		tiles:GetPropertyChangedSignal("AbsoluteSize"):Connect(place) -- context tiles (Drop, Rip) widen the row
	end

	statusFrame = Instance.new("Frame")
	statusFrame.Name = "Status"
	statusFrame.LayoutOrder = if touch then -1 else 10 -- above the party bar on touch screens, right of it on PC
	statusFrame.Size = if touch then UDim2.fromOffset(STATUS_WIDTH, 0) else UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT)
	statusFrame.AutomaticSize = if touch then Enum.AutomaticSize.Y else Enum.AutomaticSize.None
	statusFrame.BackgroundTransparency = 1
	statusFrame.Parent = statusRow
	local column = Instance.new("UIListLayout")
	column.Padding = UDim.new(0, PILL_GAP)
	column.HorizontalAlignment = Enum.HorizontalAlignment.Right
	column.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	column.SortOrder = Enum.SortOrder.LayoutOrder
	column.Parent = statusFrame
	statusLayout = column
	columnLayout = column
	column:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(place) -- the buff badge comes and goes

	buildStatusPills()

	-- The toasts' stack, placed with the corner (placeStatusRow). Not hidden with the corner: toasts stay up over the
	-- binder and the pack opening
	toastStack = Instance.new("Frame")
	toastStack.Name = "Toasts"
	toastStack.AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(1, 1)
	toastStack.Size = UDim2.fromOffset(Toasts.WIDTH + 40, 420)
	toastStack.BackgroundTransparency = 1
	toastStack.ZIndex = 10
	toastStack.Parent = screenGui
	Hud.scaleWith(toastStack)
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, Toasts.GAP)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Parent = toastStack
	place()
	-- Pish over the cash hides while a tour asks for the calm HUD (Util/Hud's "mascot" piece) and on a phone
	Hud.onCalm(function()
		HudMascotView.setHidden(isCompact() or Hud.hides("mascot"))
		place()
	end)
	HudMascotView.setHidden(isCompact() or Hud.hides("mascot"))
	-- Full-screen views (the binder) cover this corner with their own panels
	Hud.hideWith(statusRow)


	updateCash()
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	Remotes.Notify.OnClientEvent:Connect(function(message: string, isError: boolean?, style: string?)
		if typeof(message) ~= "string" then
			return
		end
		if style == "side" then
			UIController.NotifySide(message)
		else
			UIController.Notify(message, isError == true)
		end
	end)
	Remotes.LevelUp.OnClientEvent:Connect(queueLevelUp)
end

return UIController
