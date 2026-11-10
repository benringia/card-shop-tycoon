--!strict
-- Owns the main ScreenGui: the status corner (party bar, buff, cash, level / XP) and toast messages. Star Shards
-- show in the Bag, not here.
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
local XpPill = require(Shared:WaitForChild("Util"):WaitForChild("XpPill"))
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
-- column, bottom up: level + XP (in line with the party bar), cash, then the buff badge; toasts pop in just
-- above it. Touch screens: see TOUCH_TOP.
local STATUS_MARGIN = 12
-- Fixed sizes, not AutomaticSize: an auto-sized frame anchored to the right edge can lay out past the screen edge
local STATUS_WIDTH = 250
local STATUS_HEIGHT = 48 + 2 * 42 + 48 + 3 * 8 -- buff badge + two pills (cash, level) + the rating chip (RatingController) + gaps
local STATUS_ROW_WIDTH = 500 -- party bar + gap + status column; spare width is empty and lets clicks through
-- Everything in the corner shrinks with the screen's height (Hud.scaleWith, HudLayout.SCALE). On touch screens
-- (landscape phones are short, the jump button takes the bottom right) it is one column down the right edge from
-- the top: buff, cash, level, then the party bar, then the toasts; it ends around the middle.
local TOUCH_TOP = 8
local TOUCH_PARTY_HEIGHT = 84 -- room for the party bar under the column

local player = Players.LocalPlayer

local UIController = {}

local screenGui: ScreenGui
local statusRow: Frame
local statusFrame: Frame
local statusLayout: UIListLayout? = nil -- the column's layout: the toasts sit right over what it shows
local toastStack: Frame -- the toasts' bubbles, over the cash pill (placeStatusRow)
local cashLabel: TextLabel
local levelLabel: TextLabel
local xpAmount: TextLabel -- the XP into the level, big ("99,800 XP")
local xpTotal: TextLabel -- the level's total, small ("/ 226,000")
local xpFill: Frame -- the thin bar's fill
local shownXp: number? = nil -- the XP into the level the pill shows now (it counts up to the real value)
local countToken = 0
local cashPill: Frame
local levelBadge: Frame

local function getNumber(name: string, default: number): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else default
end

local function updateCash()
	local cash = player:GetAttribute("Cash")
	-- No Cash yet = the save is still loading (can take a while in Studio): say so, so it never looks like a reset
	local loaded = typeof(cash) == "number"
	local text = if loaded then string.format("$%.2f", cash) else "Loading..."
	if cashLabel.Text ~= text and cashLabel.Text ~= "" then
		Motion.bump(cashPill)
	end
	cashLabel.Text = text
end

local function updateXp()
	if typeof(player:GetAttribute("XP")) ~= "number" then
		levelLabel.Text = ""
		xpAmount.Text = "Loading..."
		xpTotal.Text = ""
		xpFill.Size = UDim2.fromScale(0, 1)
		return
	end
	local xp = getNumber("XP", 0)
	local level = tostring(getNumber("Level", 1))
	local levelled = levelLabel.Text ~= level and levelLabel.Text ~= ""
	if levelled then
		Motion.bump(levelBadge)
	end
	levelLabel.Text = level
	local into, span = LevelRules.getProgress(xp)
	xpTotal.Text = XpPill.total(span)
	xpFill.Size = UDim2.fromScale(if span > 0 then math.clamp(into / span, 0, 1) else 1, 1)
	-- The number counts up from what it shows (a newer change restarts from there; a new level starts from 0)
	countToken += 1
	local token = countToken
	local from = if shownXp == nil or levelled then into else shownXp
	if from == into or span <= 0 then
		shownXp = into
		xpAmount.Text = XpPill.amount(into, span)
		return
	end
	local look = HudLayout.XP_PILL
	local started = os.clock()
	task.spawn(function()
		while token == countToken do
			local t = (os.clock() - started) / look.countSeconds
			local value = XpPill.countUp(from, into, t)
			shownXp = value
			xpAmount.Text = XpPill.amount(value, span)
			if t >= 1 then
				break
			end
			task.wait()
		end
	end)
end

function UIController.GetScreenGui(): ScreenGui
	return screenGui
end

-- Bottom-right column: items stack upwards, right-aligned. Buff 1, cash 2, level 4 (bottom).
function UIController.GetStatusFrame(): Frame
	return statusFrame
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

-- The status pills in the corner column (spec 2026-11-03-hud-creature-pals-design): cash in a green pill with a big
-- gold coin, and the level on a gold star in a white pill with the XP big and a thin bar under it (owner 2026-11-03,
-- round 3 pick B; Config/HudLayout XP_PILL), at the bottom, in line with the party bar
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
	cashLabel = addValue(cashPill, Color3.new(1, 1, 1))
	UIKit.outlined(cashLabel, 2)

	-- The level number sits on the star; the XP fills the white pill
	local levelAnchor
	levelBadge, levelAnchor = makePill(column, 4, "Level")
	levelBadge.Name = "Level"
	levelBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	levelBadge.BackgroundTransparency = 0
	local levelStroke = levelBadge:FindFirstChildOfClass("UIStroke") :: UIStroke
	levelStroke.Color = HudLayout.PILL_EDGE
	levelLabel = UIKit.label(levelAnchor:FindFirstChild("Icon") :: Frame, "", Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1))
	levelLabel.Size = UDim2.fromScale(1, 0.9)
	levelLabel.Position = UDim2.fromScale(0, 0.08)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.ZIndex = 3
	local levelEdge = Instance.new("UIStroke")
	levelEdge.Color = Color3.fromRGB(120, 70, 0)
	levelEdge.Thickness = 2
	levelEdge.Parent = levelLabel

	-- The XP into the level big, the level's total small after it, a thin bar under them (Config/HudLayout XP_PILL)
	local look = HudLayout.XP_PILL
	local xp = Instance.new("Frame")
	xp.Name = "Xp"
	xp.LayoutOrder = 2
	xp.BackgroundTransparency = 1
	xp.Size = UDim2.fromOffset(look.width, look.amountText + look.gap + look.bar + 2)
	xp.Parent = levelBadge
	local numbers = Instance.new("Frame")
	numbers.Name = "Numbers"
	numbers.BackgroundTransparency = 1
	numbers.Size = UDim2.new(1, 0, 0, look.amountText)
	numbers.Parent = xp
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Bottom
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = numbers
	xpAmount = UIKit.label(numbers, "", Enum.Font.FredokaOne, look.amountText, look.ink)
	xpAmount.Name = "Amount"
	xpAmount.LayoutOrder = 1
	xpAmount.TextWrapped = false
	xpAmount.AutomaticSize = Enum.AutomaticSize.X
	xpAmount.Size = UDim2.fromOffset(0, look.amountText)
	xpTotal = UIKit.label(numbers, "", Enum.Font.FredokaOne, look.totalText, look.soft)
	xpTotal.Name = "Total"
	xpTotal.LayoutOrder = 2
	xpTotal.TextWrapped = false
	xpTotal.AutomaticSize = Enum.AutomaticSize.X
	xpTotal.Size = UDim2.fromOffset(0, look.totalText + 1)
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.Position = UDim2.fromOffset(0, look.amountText + look.gap)
	track.Size = UDim2.new(1, 0, 0, look.bar)
	track.BackgroundColor3 = look.track
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = xp
	UIKit.corner(track, look.bar)
	xpFill = Instance.new("Frame")
	xpFill.Name = "Fill"
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Color3.new(1, 1, 1)
	xpFill.BorderSizePixel = 0
	xpFill.Parent = track
	UIKit.corner(xpFill, look.bar)
	local shine = Instance.new("UIGradient")
	shine.Color = ColorSequence.new(look.fillLeft, look.fillRight)
	shine.Parent = xpFill
end

-- The bottom-right corner (PC). On a narrow window the party bar would reach over the bottom-centre tiles (Cards,
-- Bag ...): then the corner lifts above the tile row. The toasts stay just above it. On touch screens the
-- corner is a column from the top right instead, the toasts under it.
local function placeStatusRow(rowLayout: UIListLayout)
	if UserInputService.TouchEnabled then
		statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 0, TOUCH_TOP)
		if toastStack then
			toastStack.Position = UDim2.new(1, -STATUS_MARGIN, 0, TOUCH_TOP + rowLayout.AbsoluteContentSize.Y + 6)
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
		-- Right over the column's top item (the cash pill, or the buff badge while one shows)
		local column = if statusLayout then statusLayout.AbsoluteContentSize.Y else STATUS_HEIGHT * scale
		toastStack.Position = UDim2.new(1, -STATUS_MARGIN, 1, -(bottom + column + PILL_GAP))
	end
end

function UIController.Start()
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
	local touch = UserInputService.TouchEnabled
	if touch then
		-- One column down the right edge from the top (placeStatusRow)
		statusRow.AnchorPoint = Vector2.new(1, 0)
		statusRow.Size = UDim2.fromOffset(STATUS_WIDTH, STATUS_HEIGHT + 8 + TOUCH_PARTY_HEIGHT)
		rowLayout.FillDirection = Enum.FillDirection.Vertical
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	end
	Hud.scaleWith(statusRow)
	local function place()
		placeStatusRow(rowLayout)
	end
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
	local columnLayout = Instance.new("UIListLayout")
	columnLayout.Padding = UDim.new(0, PILL_GAP)
	columnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	columnLayout.VerticalAlignment = if touch then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
	columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
	columnLayout.Parent = statusFrame
	statusLayout = columnLayout
	columnLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(place) -- the buff badge comes and goes

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
	-- Full-screen views (the binder) cover this corner with their own panels
	Hud.hideWith(statusRow)


	updateCash()
	updateXp()
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	player:GetAttributeChangedSignal("XP"):Connect(updateXp)
	player:GetAttributeChangedSignal("Level"):Connect(updateXp)
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
