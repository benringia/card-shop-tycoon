--!strict
-- Owns the main ScreenGui: the status corner (the party dock, buff, cash) and toast messages. Your level and XP are in
-- the party dock (PartyBarController). Star Shards show in the Bag, not here.
-- Other controllers add their panels to UIController.GetScreenGui(), and status items to GetStatusFrame().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
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
local DesktopHudConfig = require(Shared:WaitForChild("Config"):WaitForChild("DesktopHud"))
local DesktopHud = require(Shared:WaitForChild("Util"):WaitForChild("DesktopHud"))
local UiLayout = require(Shared:WaitForChild("Util"):WaitForChild("UiLayout"))
local PartyConfig = require(Shared:WaitForChild("Config"):WaitForChild("Party"))
local QuestsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Quests"))
local TeamsConfig = require(Shared:WaitForChild("Config"):WaitForChild("Teams"))
local Toasts = require(Shared:WaitForChild("Config"):WaitForChild("Toasts"))
local ToastRules = require(Shared:WaitForChild("Util"):WaitForChild("ToastRules"))
local HudMascotView = require(ClientUtil:WaitForChild("HudMascotView"))

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
-- A computer's layout (owner 2026-11-21; Config/DesktopHud LAYOUT, Util/DesktopHud). "column" (C, in use): the cash
-- in `topRow` at the top of the right column; the dock, your row and the dial where they were. "bar" (A): what you
-- have in a row at the top beside Roblox's buttons (your row in `meSpot`, the cash), what you press in one bar at the
-- bottom centre (the party dock, the weapon dial at `barSpot`, the tiles). Pish and his toasts stay bottom right
local topRow: Frame
local cashLine: Frame -- in the top row: the cash pill, and your face left of it in the column layout
local topList: UIListLayout
local meSpot: Frame
local placedListeners: { () -> () } = {} -- told after each placing (the team strip follows the top row's foot)
local barSpot: { x: number, bottom: number, scale: number }? = nil
local function desktopLayout(): string?
	return DesktopHud.layout(UserInputService.TouchEnabled, DesktopHudConfig)
end
-- Pish's seat on a computer (owner 2026-11-21: "move pish icon at the top of quests"): on the quest strip's top edge,
-- his paws behind it; his toasts sit in a row along the top, the newest over his head (ToastRules.mode "row";
-- placePerch)
local perch: Frame
local replace: () -> () = function() end -- Start's place(), for pieces that follow the quest strip
-- The What now? bubble (Util/HintBubble, in the cues' own gui): a phone's toasts hang under it while it sits where they
-- hang (ToastRules.hangBelow; owner 2026-11-28 "make sure no overlapping elements")
local hintBubble: GuiObject? = nil
-- "quests" (on the quest strip) or "corner" (the bottom right, by the weapon dial: the quests are in the Phone)
local function pishAt(): string?
	return DesktopHud.pishAt(desktopLayout(), DesktopHudConfig)
end
-- A fight's foe bar (SetToastAnchor): while it shows, the toasts hang under it (ToastRules.mode "under")
local toastAnchor: GuiObject? = nil
local shapedMode: string? = nil -- the mode the stack is shaped for (shapeToasts)
local function toastMode(): "down" | "row" | "up" | "under"
	local bar = toastAnchor
	return ToastRules.mode(UserInputService.TouchEnabled, pishAt() == "quests", bar ~= nil and bar.Parent ~= nil and bar.Visible)
end
-- No peeking Pish: a phone never has one, a guide's calm HUD hides him, and a computer's layouts dropped him (owner
-- 2026-11-21: "just remove pish"; Config/DesktopHud PISH)
local function mascotHidden(): boolean
	return UserInputService.TouchEnabled or Hud.hides("mascot") or (desktopLayout() ~= nil and pishAt() == nil)
end
-- The cash pill's size: smaller on a phone, a little smaller on a computer's layouts (Config/DesktopHud CASH_SCALE)
local function cashSize(): number
	if UserInputService.TouchEnabled then
		return HudLayout.CASH.touchScale
	end
	return if desktopLayout() then DesktopHudConfig.CASH_SCALE else 1
end
local compactListeners: { (boolean) -> () } = {}
local function isCompact(): boolean
	return UserInputService.TouchEnabled
end

local cashHeldUntil = 0 -- a sale's coins are flying in: the pill keeps its number until they land (HoldCash)
local shownCash: number? = nil

local function moneyText(cash: number): string
	return if isCompact() then CompactHud.money(cash) else string.format("$%.2f", cash)
end

local function updateCash()
	local cash = player:GetAttribute("Cash")
	-- No Cash yet = the save is still loading (can take a while in Studio): say so, so it never looks like a reset
	local loaded = typeof(cash) == "number"
	if loaded and os.clock() < cashHeldUntil then
		return
	end
	local text = if not loaded then "Loading..." else moneyText(cash)
	if cashLabel.Text ~= text and cashLabel.Text ~= "" then
		Motion.bump(cashPill)
	end
	cashLabel.Text = text
	shownCash = if loaded then cash else nil
end

function UIController.GetScreenGui(): ScreenGui
	return screenGui
end

-- The cash pill (a sale's coins fly into it: Util/CoinBurst)
function UIController.GetCashPill(): Frame
	return cashPill
end

-- Shows the cash pill `amount` lower (a sale's money still flying in) for `seconds`, then counts it up to your cash
-- over `rollSeconds` with a bump (owner 2026-11-16: "immersive animation/effects when someone buys something")
function UIController.HoldCash(seconds: number, rollSeconds: number, amount: number)
	local releaseAt = os.clock() + seconds
	local now = player:GetAttribute("Cash")
	if os.clock() >= cashHeldUntil and typeof(now) == "number" then
		shownCash = now - amount
		cashLabel.Text = moneyText(now - amount)
	end
	cashHeldUntil = math.max(cashHeldUntil, releaseAt)
	task.delay(seconds, function()
		if os.clock() + 1e-3 < cashHeldUntil then
			return -- a later sale holds it longer
		end
		local target = player:GetAttribute("Cash")
		local from = shownCash
		if typeof(target) ~= "number" or not from or target <= from then
			updateCash()
			return
		end
		Motion.bump(cashPill)
		local started = os.clock()
		local connection: RBXScriptConnection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - started) / rollSeconds, 1)
			if os.clock() < cashHeldUntil then
				connection:Disconnect() -- another sale's coins: it holds again
				return
			end
			cashLabel.Text = moneyText(from + (target - from) * (1 - (1 - t) * (1 - t)))
			if t >= 1 then
				connection:Disconnect()
				updateCash()
			end
		end)
	end)
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

-- Where your row (face, level, buffs) goes on a computer: the top row (beside the cash in the bar layout, under it
-- in the column layout: owner 2026-11-21, "move character info and level below the coin"); nil on a touch screen or
-- with the layouts off (it stays in the dock)
function UIController.GetMeSpot(): Frame?
	return if desktopLayout() then meSpot else nil
end

-- Where your face goes in the column layout: the cash's line, left of the pill (owner 2026-11-21: "put the avatar
-- beside the coin"); nil elsewhere (it stays first in your row)
function UIController.GetFaceSpot(): Frame?
	return if DesktopHud.faceBesideCash(desktopLayout()) then cashLine else nil
end

-- Where the rest of the right column starts in the column layout (the team strip, the pills under the quests): under
-- your row; `default` px down otherwise
function UIController.GetColumnStart(default: number): number
	local bottom: number? = nil
	if desktopLayout() == "column" and topRow and topRow.Visible and topRow.AbsoluteSize.Y > 0 then
		bottom = topRow.AbsolutePosition.Y + topRow.AbsoluteSize.Y
	end
	return DesktopHud.columnStart(bottom, default, DesktopHudConfig.TOP.below)
end

-- A fight's foe bar for the toasts to hang under (owner 2026-11-20, the combat HUD tidy: in their corner they landed on
-- the skill buttons), or nil when the fight is over: back to their corner
function UIController.SetToastAnchor(bar: GuiObject?)
	if toastAnchor == bar then
		return
	end
	toastAnchor = bar
	task.defer(function()
		replace() -- once the bar has its place
	end)
end

-- Told after the HUD's pieces are placed (the top row moved or resized)
function UIController.OnPlaced(listener: () -> ())
	table.insert(placedListeners, listener)
end

-- The weapon dial's place in a computer's bottom bar: its left edge, its foot's distance from the screen's bottom and
-- its scale; nil when it isn't in the bar (a touch screen, a window too narrow: WeaponSwitchController places it)
function UIController.GetBarSpot(): { x: number, bottom: number, scale: number }?
	return barSpot
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
	-- "down": a touch screen's stack hangs under the column, tails on top; "up" (over the cash) and "row" (a
	-- computer's, along the top with the newest over Pish): tails underneath
	local mode = toastMode()
	local touch = mode == "down"
	local edge = Toasts.EDGE_THICKNESS
	local tailRoom = math.ceil(Toasts.TAIL * 0.75) + edge
	-- A canvas group, so the whole bubble fades as one; padded so the tail and shadow fit inside it
	local root = Instance.new("CanvasGroup")
	root.Name = "Toast"
	-- newest nearest the cash (or Pish: last in the row, its right end; under a fight's foe bar: first under it)
	root.LayoutOrder = if touch or mode == "under" then -id else id
	root.Size = UDim2.new()
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.BackgroundTransparency = 1
	root.GroupTransparency = 1
	local room = Instance.new("UIPadding")
	room.PaddingTop = UDim.new(0, if touch then tailRoom else edge)
	room.PaddingBottom = UDim.new(0, if touch or mode == "under" then edge + Toasts.SHADOW_OFFSET else tailRoom + Toasts.SHADOW_OFFSET)
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
	-- a plain bubble when nobody says it (a computer with no Pish on its HUD)
	local tailed = ToastRules.tail(mode, not mascotHidden())
	tail.Visible = tailed
	local join = Instance.new("Frame")
	join.Name = "TailJoin"
	join.AnchorPoint = Vector2.new(0.5, 0.5)
	join.Position = UDim2.new(1, -Toasts.TAIL_RIGHT, tailY, 0)
	join.Size = UDim2.fromOffset(Toasts.TAIL * 1.2, edge * 2 + 2)
	join.BackgroundColor3 = Color3.new(1, 1, 1)
	join.BorderSizePixel = 0
	join.ZIndex = 6
	join.Visible = tailed
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

-- In a fight: the stack's top centre just under the foe's bar and whatever hangs from it (its states, its adds).
-- False when no fight's bar is up
local function placeUnder(): boolean
	local bar = toastAnchor
	if not toastStack or not bar or toastMode() ~= "under" then
		return false
	end
	local origin = screenGui.AbsolutePosition
	local hang = 0
	for _, child in bar:GetChildren() do
		if child:IsA("GuiObject") and child.Visible and child.AbsoluteSize.Y > 0 then
			hang = math.max(hang, child.AbsolutePosition.Y + child.AbsoluteSize.Y - origin.Y)
		end
	end
	local at, size = bar.AbsolutePosition - origin, bar.AbsoluteSize
	local spot = ToastRules.under({ x = at.X, y = at.Y, w = size.X, h = size.Y }, hang, Toasts.UNDER_GAP)
	toastStack.Position = UDim2.fromOffset(spot.x, spot.y)
	return true
end

local function pushToast(message: string, kind: string, duration: number?, icon: string?): number
	if toastMode() ~= shapedMode then
		replace() -- a fight's bar came or went since the stack was shaped
	end
	placeUnder()
	local look = Toasts.KINDS[kind]
	local seconds = ToastRules.seconds(Toasts, kind, duration)
	local entries: { ToastRules.Entry } = {}
	for _, bubble in bubbles do
		table.insert(entries, { id = bubble.id, message = bubble.message })
	end
	local max = ToastRules.max(toastMode(), Toasts)
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

	cashPill = makePill(if desktopLayout() then cashLine else column, 2, "Coin") -- a computer: in the top row
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
	cashScale.Scale = cashSize()
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
		seat.Parent = if desktopLayout() then perch else column -- a computer: on the quest strip
		-- its own size, not AutomaticSize (that grew to his sticker's hidden foot under the seat); none with no Pish
		perch.Size = if pishAt() == nil then UDim2.new() else seat.Size
		cashPill.ZIndex = 2
		pishSeat = seat
		HudMascotView.mount(seat, seat.Size.Y.Offset + PILL_GAP)
	end
end

-- The toasts' stack for this screen (ToastRules.mode): a column hanging down ("down", a touch screen), a column rising
-- ("up", over the cash), or a row along the top, its right end at Pish ("row", a computer with him on the quests)
local function shapeToasts()
	local mode = toastMode()
	shapedMode = mode
	local row = mode == "row"
	local under = mode == "under" -- a fight: hanging from the foe's bar, centred on it
	toastStack.AnchorPoint = if under then Vector2.new(0.5, 0) elseif mode == "down" then Vector2.new(1, 0) else Vector2.new(1, 1)
	toastStack.Size = if row then UDim2.fromOffset((Toasts.WIDTH + 40) * Toasts.MAX_TOUCH, 160) else UDim2.fromOffset(Toasts.WIDTH + 40, 420)
	local toastLayout = toastStack:FindFirstChildOfClass("UIListLayout")
	if toastLayout then
		toastLayout.FillDirection = if row then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		toastLayout.VerticalAlignment = if mode == "down" or under then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom
		toastLayout.HorizontalAlignment = if under then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Right
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
		shapeToasts()
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
	-- a computer's layout: the side column hangs under Roblox's buttons (owner 2026-11-21: "make phone and daily
	-- gift move up below roblox"), far above the dock
	local sideTop = DesktopHud.sideTop(desktopLayout(), DesktopHudConfig)
	if sideTop then
		Hud.liftSide(0, sideTop)
		return
	end
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
			cashScale.Scale = cashSize()
		end
		fitCoin(compact)
		if cashPill then
			cashPill.Parent = if desktopLayout() then cashLine else statusFrame -- a computer: in the top row
		end
		if pishSeat then
			pishSeat.Visible = not compact
			pishSeat.Parent = if desktopLayout() then perch else statusFrame
		end
		HudMascotView.setHidden(mascotHidden())
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
			-- left of the column, under the top bar strip: clear of the dock and the jump button; under the What now?
			-- bubble while it sits there
			local beside = STATUS_MARGIN + rowLayout.AbsoluteContentSize.X + 8
			local right = screenGui.AbsoluteSize.X - beside
			local bubble = hintBubble
			local keep = if bubble and bubble.Parent and bubble.Visible
				then { x = bubble.AbsolutePosition.X, y = bubble.AbsolutePosition.Y, w = bubble.AbsoluteSize.X, h = bubble.AbsoluteSize.Y }
				else nil
			local scale = toastStack.AbsoluteSize.X / (Toasts.WIDTH + 40) -- its UIScale (shapeToasts sizes it on a phone)
			local stack = { left = right - toastStack.AbsoluteSize.X, right = right }
			local hang = ToastRules.hangBelow(top + height + 8, stack, keep, Toasts.TOUCH_REACH * scale, Toasts.GAP * scale)
			toastStack.Position = UDim2.new(1, -beside, 0, hang)
		end
		return
	end
	local bottom = STATUS_MARGIN
	local width = screenGui.AbsoluteSize.X
	local tiles = screenGui:FindFirstChild("HudBottom")
	local tilesRight = width / 2 + (if tiles and tiles:IsA("GuiObject") then tiles.AbsoluteSize.X / 2 else 0)
	local rowLeft = width - STATUS_MARGIN - rowLayout.AbsoluteContentSize.X
	local scale = Hud.scaleFor()
	if desktopLayout() then
		-- nothing is left in this corner on a computer: the cash is at the top (placeDesktop), Pish on the quests with
		-- his toasts beside him (placePerch)
		statusRow.Position = UDim2.new(1, -STATUS_MARGIN, 1, -STATUS_MARGIN)
		return
	end
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

-- A computer's layout (Config/DesktopHud), after the corners are placed. The column layout: only the cash moves, to
-- the top right. The bar layout's top row and bottom bar: the top row beside Roblox's
-- buttons (GuiService.TopbarInset: the top bar's free room), or under the bar at the left when it doesn't fit; the
-- dock, the weapon dial and the tiles as one centred bar, or the corners as they were when the window is too narrow
local function placeDesktop()
	barSpot = nil
	local layout = desktopLayout()
	if not layout then
		Hud.placeBottom(nil)
		return
	end
	local view = screenGui.AbsoluteSize
	local scale = Hud.scaleFor() * Hud.growFor()
	local top = DesktopHudConfig.TOP
	local inset = GuiService:GetGuiInset().Y
	local free = GuiService.TopbarInset
	-- the column layout stacks the cash over your row (right-aligned); the bar layout sets them side by side
	local stacked = DesktopHud.meUnderCash(layout)
	topList.FillDirection = if stacked then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal
	topList.HorizontalAlignment = if stacked then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	topList.Padding = UDim.new(0, if stacked then top.stack else top.gap)
	meSpot.LayoutOrder = if stacked then 3 else 1 -- the cash is 2
	-- level with Roblox's own pills, the coin clear of the screen's top (owner 2026-11-21): the cash pill's own height
	local lineHeight = if cashLine.AbsoluteSize.Y > 0 then cashLine.AbsoluteSize.Y else topRow.AbsoluteSize.Y
	local level = DesktopHud.cashTop(top.level, lineHeight, ICON_SIZE * scale * cashSize(), top.clear)
	if layout == "column" then
		-- C: the cash on top of the right column, in the top bar's strip (the team strip and the quests start under
		-- it); the dock bottom left (placeDock), the tiles centred, the dial by Pish (WeaponSwitchController)
		topRow.AnchorPoint = Vector2.new(1, 0)
		topRow.Position = UDim2.fromOffset(DesktopHud.topRight(free.Max.X, view.X, DesktopHudConfig), level - inset)
		Hud.placeBottom(nil)
		return
	end
	topRow.AnchorPoint = Vector2.new(0, 0)
	local freeRight = free.Max.X
	local quests = screenGui:FindFirstChild("QuestTracker", true)
	if quests and quests:IsA("GuiObject") and quests.Visible and quests.AbsoluteSize.X > 0 then
		freeRight = math.min(freeRight, quests.AbsolutePosition.X - top.gap) -- a grown row hangs under the top bar
	end
	local row = DesktopHud.topRow(free.Min.X, freeRight, topRow.AbsoluteSize.X, DesktopHudConfig)
	topRow.Position = UDim2.fromOffset(row.x, if row.inBar then level - inset else top.under)

	local look = HudLayout.WEAPON_SWITCH
	local dialScale = math.max(scale, 48 / look.hit)
	local dial = screenGui:FindFirstChild("WeaponSwitch")
	local fighting = screenGui:FindFirstChild("CombatHud") ~= nil
	local dialWanted = dial ~= nil and dial:GetAttribute("Wanted") == true and not fighting
	local quick = PartyConfig.BAR.DOCK.quick
	local dockWidth = if dockHolder.AbsoluteSize.X > 4 then dockHolder.AbsoluteSize.X + (quick.gap + quick.size) * scale else 0
	local dialWidth = UiLayout.switchBox(look) -- the weapon row (owner 2026-11-27 pick B)
	local tiles = screenGui:FindFirstChild("HudBottom")
	local tilesWidth = if tiles and tiles:IsA("GuiObject") then tiles.AbsoluteSize.X else 0
	local side = screenGui:FindFirstChild("HudSide")
	local clear = DesktopHudConfig.CLEAR * scale
	local clearLeft = (if side and side:IsA("GuiObject") then side.AbsolutePosition.X - screenGui.AbsolutePosition.X + side.AbsoluteSize.X else 0) + clear
	local clearRight = STATUS_MARGIN + clear
	local spots = DesktopHud.bar(view.X, {
		{ id = "party", w = dockWidth },
		{ id = "weapon", w = if dialWanted then dialWidth * dialScale else 0 },
		{ id = "tiles", w = tilesWidth },
	}, DesktopHudConfig.GAP * scale, clearLeft, clearRight)
	if not spots then
		Hud.placeBottom(nil) -- too narrow: the dock bottom left (placeDock), the dial by the corner
		return
	end
	if spots.party then
		dockHolder.Position = UDim2.new(0, spots.party, 1, -HudLayout.BOTTOM_MARGIN)
	end
	Hud.placeBottom(spots.tiles)
	if spots.weapon then
		barSpot = { x = spots.weapon, bottom = HudLayout.BOTTOM_MARGIN, scale = dialScale }
	end
end

-- Pish on a computer: on the quest strip's top edge near its left end, or where the strip would be while it isn't
-- showing; his toasts sit in a row along the top, the newest one's tail over his head (ToastRules.stackCorner)
local followed: Instance? = nil
local function placePerch()
	if not desktopLayout() or not perch then
		return
	end
	local scale = Hud.scaleFor() * Hud.growFor()
	local view = screenGui.AbsoluteSize
	local at = pishAt()
	if at == nil then
		-- no Pish on a computer's HUD (owner 2026-11-21): his seat takes no room (the weapon dial has the corner), and
		-- the toasts are plain bubbles in the lower right, over the dial while there's one to switch to
		perch.Size = UDim2.new()
		if toastStack then
			local look = HudLayout.WEAPON_SWITCH
			local dial = screenGui:FindFirstChild("WeaponSwitch")
			local wanted = dial ~= nil and dial:GetAttribute("Wanted") == true
			local _, rowHeight = UiLayout.switchBox(look) -- the weapon row (owner 2026-11-27 pick B)
			local dialHeight = if wanted then rowHeight * math.max(Hud.scaleFor(), 48 / look.hit) else 0
			local corner = DesktopHud.toastCorner({ w = view.X, h = view.Y }, dialHeight, DesktopHudConfig)
			toastStack.Position = UDim2.fromOffset(corner.x, corner.y)
		end
		return
	end
	if at == "corner" then
		-- no quest strip to sit on (the quests are in the Phone): he peeks over the screen's bottom edge in the
		-- bottom-right corner, his sticker's hidden foot just off the screen; the weapon dial sits beside him
		-- (WeaponSwitchController) and his toasts rise over him (ToastRules.mode "up")
		perch.Position = UDim2.fromOffset(view.X - STATUS_MARGIN - perch.AbsoluteSize.X, view.Y - (PILL_GAP + HudMascotConfig.perch.overlap) * scale)
		if toastStack then
			local head = HudMascotView.head()
			local corner = if head
				then ToastRules.stackCorner({ x = head.X, y = head.Y }, Toasts.TAIL_RIGHT, Toasts.TAIL, scale)
				else { x = view.X - STATUS_MARGIN, y = perch.AbsolutePosition.Y - PILL_GAP }
			toastStack.Position = UDim2.fromOffset(corner.x, corner.y)
		end
		return
	end
	local left = view.X - DesktopHudConfig.TOP.right - QuestsConfig.STRIP.width * scale
	local top = TeamsConfig.STRIP.top
	local quests = screenGui:FindFirstChild("QuestTracker", true)
	if quests and quests:IsA("GuiObject") then
		if followed ~= quests then
			followed = quests
			for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
				quests:GetPropertyChangedSignal(property):Connect(function()
					replace()
				end)
			end
		end
		if quests.Visible and quests.AbsoluteSize.X > 0 then
			left, top = quests.AbsolutePosition.X, quests.AbsolutePosition.Y
		end
	end
	-- peeking from behind the quest box: his sticker's hidden foot (HudMascotConfig.perch.overlap under his seat's
	-- line, PILL_GAP under the seat) and PERCH.sink px more sit behind the strip's top edge, which draws over him
	perch.Position = UDim2.fromOffset(left + DesktopHudConfig.PERCH.inset * scale, top + (DesktopHudConfig.PERCH.sink - PILL_GAP) * scale)
	if toastStack then
		local head = HudMascotView.head()
		local corner = if head
			then ToastRules.stackCorner({ x = head.X, y = head.Y }, Toasts.TAIL_RIGHT, Toasts.TAIL, scale)
			else { x = perch.AbsolutePosition.X + perch.AbsoluteSize.X, y = top - perch.AbsoluteSize.Y } -- he's hidden: where he would speak from
		toastStack.Position = UDim2.fromOffset(corner.x, corner.y)
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
	Hud.scaleWith(statusRow, if touch then HudLayout.SCALE.TOUCH_MIN else nil, true) -- bigger on a desktop (Config/HudGrow)
	-- The PC's party dock holder (bottom left; PartyBarController puts the dock in it off a phone)
	dockHolder = Instance.new("Frame")
	dockHolder.Name = "PartyDock"
	dockHolder.AnchorPoint = Vector2.new(0, 1)
	dockHolder.Size = UDim2.new()
	dockHolder.AutomaticSize = Enum.AutomaticSize.XY
	dockHolder.BackgroundTransparency = 1
	dockHolder.Parent = screenGui
	Hud.scaleWith(dockHolder, nil, true) -- bigger on a desktop (owner 2026-11-21: "also make this bigger on desktop")
	Hud.hideWith(dockHolder) -- full-screen views (the binder) cover it
	Hud.calmPiece(dockHolder, "party") -- its name: manning the register keeps it (Hud.keepOnly), the shop bar in view
	-- A computer's top row (Config/DesktopHud): your row (PartyBarController puts it in MeSpot) and the cash
	topRow = Instance.new("Frame")
	topRow.Name = "TopRow"
	topRow.BackgroundTransparency = 1
	topRow.Size = UDim2.new()
	topRow.AutomaticSize = Enum.AutomaticSize.XY
	topRow.Parent = screenGui
	topList = Instance.new("UIListLayout")
	topList.FillDirection = Enum.FillDirection.Horizontal
	topList.VerticalAlignment = Enum.VerticalAlignment.Center
	topList.Padding = UDim.new(0, DesktopHudConfig.TOP.gap)
	topList.SortOrder = Enum.SortOrder.LayoutOrder
	topList.Parent = topRow
	cashLine = Instance.new("Frame")
	cashLine.Name = "CashLine"
	cashLine.LayoutOrder = 2
	cashLine.BackgroundTransparency = 1
	cashLine.Size = UDim2.new()
	cashLine.AutomaticSize = Enum.AutomaticSize.XY
	cashLine.Parent = topRow
	local lineList = Instance.new("UIListLayout")
	lineList.FillDirection = Enum.FillDirection.Horizontal
	lineList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	lineList.VerticalAlignment = Enum.VerticalAlignment.Center
	lineList.Padding = UDim.new(0, DesktopHudConfig.FACE.gap)
	lineList.SortOrder = Enum.SortOrder.LayoutOrder
	lineList.Parent = cashLine
	cashLine:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		replace()
	end)
	Hud.scaleWith(topRow, nil, true)
	Hud.hideWith(topRow) -- full-screen views cover it; a fight hides it by name (BattleController HUD_NAMES)
	Hud.keepName(topRow, "cash") -- manning the register keeps your money in view
	meSpot = Instance.new("Frame")
	meSpot.Name = "MeSpot"
	meSpot.LayoutOrder = 1
	meSpot.BackgroundTransparency = 1
	meSpot.Size = UDim2.new()
	meSpot.AutomaticSize = Enum.AutomaticSize.XY
	meSpot.Parent = topRow
	Hud.calmPiece(meSpot, "party") -- hidden with the dock through a guide's calm HUD, as when it sat in it
	-- Pish's perch on the quest strip (placePerch); made before the quests' own gui, so the strip draws over his paws
	perch = Instance.new("Frame")
	perch.Name = "PishPerch"
	perch.AnchorPoint = Vector2.new(0, 1)
	perch.BackgroundTransparency = 1
	perch.Size = UDim2.new()
	perch.Parent = screenGui
	Hud.scaleWith(perch, nil, true)
	Hud.hideWith(perch)
	local placing = false
	local function place()
		if placing then
			return -- placing moves pieces whose size signals call this again
		end
		placing = true
		if toastStack and toastMode() ~= shapedMode then
			shapeToasts() -- a fight's bar came or went
		end
		placeStatusRow(rowLayout)
		placeDock()
		placeDesktop()
		placePerch()
		placeUnder() -- in a fight the toasts hang under the foe's bar, wherever the corners put them
		placing = false
		for _, listener in placedListeners do
			task.spawn(listener)
		end
	end
	replace = place
	screenGui.DescendantAdded:Connect(function(added)
		if added.Name == "QuestTracker" then
			task.defer(place) -- the quest strip arrived: Pish goes onto it
		end
	end)
	-- the What now? bubble, made on its first tip in the cues' gui: a phone's toasts follow it (placeStatusRow)
	local function followBubble(child: Instance)
		if child.Name ~= "HintBubble" or not child:IsA("GuiObject") or hintBubble == child then
			return
		end
		hintBubble = child
		for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
			child:GetPropertyChangedSignal(property):Connect(place)
		end
		task.defer(place)
	end
	local function followCues(child: Instance)
		if child.Name ~= "TutorialCues" then
			return
		end
		child.ChildAdded:Connect(followBubble)
		for _, inside in child:GetChildren() do
			followBubble(inside)
		end
	end
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui.ChildAdded:Connect(followCues)
	for _, child in playerGui:GetChildren() do
		followCues(child)
	end
	topRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(place)
	-- the weapon dial joins or leaves the bar (WeaponSwitchController sets Wanted on its layer), a fight comes or goes
	screenGui.ChildAdded:Connect(function(child)
		if child.Name == "WeaponSwitch" then
			child:GetAttributeChangedSignal("Wanted"):Connect(place)
		end
		if child.Name == "WeaponSwitch" or child.Name == "CombatHud" then
			place()
		end
	end)
	screenGui.ChildRemoved:Connect(function(child)
		if child.Name == "CombatHud" then
			place()
		end
	end)
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
	toastStack.BackgroundTransparency = 1
	toastStack.ZIndex = 10
	-- not a window: a fight's start closes the open windows (BattleController setHudHidden) but leaves this up (it hid
	-- every toast for the rest of the session after the first fight until 2026-11-19)
	toastStack:SetAttribute("KeepInFights", true)
	toastStack.Parent = screenGui
	Hud.scaleWith(toastStack, nil, true)
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.Padding = UDim.new(0, Toasts.GAP)
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.Parent = toastStack
	shapeToasts()
	place()
	-- Pish over the cash hides while a tour asks for the calm HUD (Util/Hud's "mascot" piece) and on a phone
	Hud.onCalm(function()
		HudMascotView.setHidden(mascotHidden())
		place()
	end)
	HudMascotView.setHidden(mascotHidden())
	-- Full-screen views (the binder) cover this corner with their own panels
	Hud.hideWith(statusRow)
	Hud.keepName(statusRow, "cash") -- manning the register keeps your money in view (owner 2026-11-16)


	updateCash()
	player:GetAttributeChangedSignal("Cash"):Connect(updateCash)
	require(ClientUtil:WaitForChild("CoinSound")).start() -- a coin sound whenever the cash goes up (owner 2026-11-19)
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
end

return UIController
