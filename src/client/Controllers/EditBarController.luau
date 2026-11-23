--!strict
-- The Edit bar (owner 2026-11-23, mockup C "Action bar"; DESIGN.md 4.3 "Editing what you placed"): Edit on a thing in
-- your shop lights it up and swaps the bottom-centre tiles for its bar (Util/EditBarRules says what it offers,
-- Config/EditBar its look): the name, a status chip and a hint on the left, up to three candy tiles in the HUD's own
-- look (Util/Hud.candyTile) with a line under each, and the round close button. Not a window: the world stays in view,
-- the thumbstick stays, and walking away closes it. A resting or locked tile is grey-lilac (a padlock on a locked one)
-- and a tap says why: the locked card for a lock (BlockedController), a toast for a rest. Sell is held down: the tile
-- fills from the bottom; a quick tap says to hold. It also closes with its X, when a window opens, when the thing goes,
-- and when a tile hands over (Move, Cards, Use). BuildController (shelves, cases, machines, trophies, decor) and
-- WindowController (windows, posters) open it with their thing and its actions.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local EditBarConfig = require(Config:WaitForChild("EditBar"))
local BabyColors = require(Config:WaitForChild("BabyColors"))
local HudLayout = require(Config:WaitForChild("HudLayout"))
local SoftHud = require(Config:WaitForChild("SoftHud"))
local EditBarRules = require(Shared:WaitForChild("Util"):WaitForChild("EditBarRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BlockedController = require(Controllers:WaitForChild("BlockedController"))

-- What a tile does, by EditBarRules tile id
export type Actions = { [string]: () -> () }
export type Spec = {
	target: Instance, -- what lights up: the thing's model (or its part)
	at: BasePart, -- where it stands: walking further than Config/EditBar REACH from it closes the bar
	describe: () -> EditBarRules.Thing?, -- the thing now (nil: it's gone), asked again while the bar is up
	actions: Actions,
	icons: { [string]: string }?, -- a tile's own icon by id (a machine's Use: its picture)
}

type Slot = {
	column: Frame,
	tile: TextButton,
	sub: TextLabel,
	lock: Frame,
	mask: UIGradient,
	state: EditBarRules.Tile?,
}

local player = Players.LocalPlayer
local TILE = HudLayout.TILE_SIZE.X
local SLOTS = 3
local SUB_HEIGHT = 16
local HEIGHT = EditBarConfig.PADDING.top + TILE + 4 + SUB_HEIGHT + EditBarConfig.PADDING.bottom
local REASON = "edit" -- Hud.setBottomHidden

local EditBarController = {}

local bar: Frame
local info: Frame
local nameLabel: TextLabel
local chip: TextLabel
local hint: TextLabel
local slots: { Slot } = {}
local highlight: Highlight
local current: Spec? = nil
local shown: string? = nil -- what's drawn (its words and states), so the bar is redrawn only when that changes
local holding: { slot: Slot, began: number }? = nil
local flashToken = 0

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function lightOf(name: string): Color3
	local shades = BabyColors.COLORS[name] or BabyColors.COLORS.greyLilac
	return rgb(shades.light)
end

-- How much of the Sell tile is filled: the bottom `share` of it darkened
local function setFill(slot: Slot, share: number)
	local shade = 1 - EditBarConfig.HOLD_SHADE
	if share <= 0 then
		slot.mask.Transparency = NumberSequence.new(1)
		return
	end
	local cut = math.clamp(1 - share, 0.002, 0.996)
	slot.mask.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(cut, 1),
		NumberSequenceKeypoint.new(cut + 0.002, shade),
		NumberSequenceKeypoint.new(1, shade),
	})
end

local function iconOf(spec: Spec, tile: EditBarRules.Tile): string
	local own = spec.icons and spec.icons[tile.id]
	if own then
		return own
	end
	local icon = (EditBarConfig.ICONS :: any)[tile.id]
	return if typeof(icon) == "string" then icon else "Box"
end

local function stopHold()
	local held = holding
	holding = nil
	if held then
		setFill(held.slot, 0)
	end
end

local function close()
	local spec = current
	if not spec then
		return
	end
	current = nil
	shown = nil
	stopHold()
	highlight.Enabled = false
	highlight.Adornee = nil
	spec.at:SetAttribute("Editing", nil)
	bar.Visible = false
	Hud.setBottomHidden(REASON, false)
end

-- The bar for the thing as it is now: words, chip, tiles; and its width for the tiles it has
local function render(spec: Spec, thing: EditBarRules.Thing)
	local model = EditBarRules.bar(thing)
	local parts = { model.name, model.chip.text, model.chip.tone, model.hint }
	for _, tile in model.tiles do
		table.insert(parts, `{tile.id}:{tile.state}:{tile.label}:{tile.sub}`)
	end
	local key = table.concat(parts, "|")
	if key == shown then
		return
	end
	shown = key
	local phone = UIKit.isPhone()
	nameLabel.Text = model.name
	chip.Text = model.chip.text
	chip.BackgroundColor3 = lightOf(EditBarConfig.CHIP[model.chip.tone] or "lilac")
	hint.Text = model.hint
	hint.Visible = not phone
	local infoWidth = if phone then EditBarConfig.INFO.phoneWidth else EditBarConfig.INFO.width
	info.Size = UDim2.fromOffset(infoWidth, TILE + SUB_HEIGHT)
	local count = 0
	for index, slot in slots do
		local tile = model.tiles[index]
		slot.state = tile
		slot.column.Visible = tile ~= nil
		setFill(slot, 0)
		if tile then
			count += 1
			local ready = tile.state == "ready"
			local color = if ready then EditBarConfig.COLORS[tile.id] or "sky" else EditBarConfig.COLORS.off
			Hud.paintTile(slot.tile, iconOf(spec, tile), tile.label, color, if ready then nil else EditBarConfig.DIM)
			slot.sub.Text = tile.sub
			slot.lock.Visible = tile.state == "locked"
			slot.column.Position = UDim2.fromOffset(
				EditBarConfig.PADDING.left + infoWidth + EditBarConfig.GAP + (index - 1) * (TILE + EditBarConfig.GAP),
				EditBarConfig.PADDING.top
			)
		end
	end
	local width = EditBarConfig.PADDING.left + infoWidth + count * (EditBarConfig.GAP + TILE) + EditBarConfig.PADDING.right
	bar.Size = UDim2.fromOffset(width, HEIGHT)
end

-- A quick tap on a held tile: its line says to hold for a moment
local function flashSub(slot: Slot)
	flashToken += 1
	local mine = flashToken
	local tile = slot.state
	slot.sub.Text = "Hold to sell"
	task.delay(1.4, function()
		if mine == flashToken and slot.state == tile and tile then
			slot.sub.Text = tile.sub
		end
	end)
end

local function onTile(slot: Slot)
	local spec = current
	local tile = slot.state
	if not spec or not tile then
		return
	end
	if tile.state == "locked" then
		BlockedController.Show(tile.why or "Not yet.")
		return
	elseif tile.state == "off" then
		UIController.Notify(tile.why or "Nothing to do here.", false)
		return
	end
	if tile.hold then
		flashSub(slot) -- the hold itself does it (RenderStepped); a tap only teaches
		return
	end
	local action = spec.actions[tile.id]
	close()
	if action then
		action()
	end
end

-- Every few moments while it's up: the thing still there and near, its words and states as they are now
local function check()
	local spec = current
	if not spec then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local gone = not spec.at:IsDescendantOf(workspace)
	local far = root ~= nil and root:IsA("BasePart") and (root.Position - spec.at.Position).Magnitude > EditBarConfig.REACH
	local thing = if gone or far then nil else spec.describe()
	if not thing then
		close()
		return
	end
	render(spec, thing)
end

local function buildSlot(index: number): Slot
	local column = Instance.new("Frame")
	column.Name = `Tile{index}`
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(TILE, TILE + 4 + SUB_HEIGHT)
	column.ZIndex = 2
	column.Parent = bar

	local slot: Slot
	local tile = Hud.candyTile(column, `EditTile{index}`, index, function()
		onTile(slot)
	end)
	tile.ZIndex = 2

	-- The hold's fill: a dark layer over the tile's face, shown from the bottom up by its gradient
	local body = tile:FindFirstChild("Body") :: Frame
	local face = body:FindFirstChild("Face") :: Frame
	local fill = Instance.new("Frame")
	fill.Name = "Hold"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(0, 0, 0)
	fill.BorderSizePixel = 0
	fill.Parent = face
	UIKit.corner(fill, TILE * SoftHud.TILE.corner)
	local mask = Instance.new("UIGradient")
	mask.Name = "Mask"
	mask.Rotation = 90
	mask.Transparency = NumberSequence.new(1)
	mask.Parent = fill

	local sub = UIKit.label(column, "", Enum.Font.GothamBold, EditBarConfig.SUB, UIKit.colorsFor(bar).inkSoft)
	sub.Name = "Sub"
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 0, TILE + 4)
	sub.Size = UDim2.fromOffset(TILE + EditBarConfig.GAP, SUB_HEIGHT)
	sub.TextXAlignment = Enum.TextXAlignment.Center
	sub.TextScaled = true
	sub.TextWrapped = false
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = EditBarConfig.SUB
	fit.Parent = sub

	local lock = Icon.make(column, EditBarConfig.ICONS.lock, UDim2.fromOffset(EditBarConfig.LOCK, EditBarConfig.LOCK))
	lock.Name = "Lock"
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromOffset(TILE - 6, TILE - 8)
	lock.ZIndex = 9
	Icon.layer(lock, 9)
	lock.Visible = false

	slot = { column = column, tile = tile, sub = sub, lock = lock, mask = mask, state = nil }

	-- Sell is held down: the press starts the fill, letting go or sliding off ends it (RenderStepped finishes it)
	tile.InputBegan:Connect(function(input)
		local press = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		local state = slot.state
		if press and current and state and state.hold and state.state == "ready" then
			holding = { slot = slot, began = os.clock() }
		end
	end)
	tile.MouseLeave:Connect(function()
		if holding and holding.slot == slot then
			stopHold()
		end
	end)
	return slot
end

local function build()
	bar = Instance.new("Frame")
	bar.Name = "EditBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -HudLayout.BOTTOM_MARGIN)
	bar.Size = UDim2.fromOffset(EditBarConfig.INFO.width, HEIGHT)
	bar.ZIndex = 2
	bar.Visible = false
	bar.Parent = UIController.GetScreenGui()
	UIKit.creamWindow(bar)
	Hud.scaleWith(bar, nil, true) -- as big as the HUD round it, on every screen
	local palette = UIKit.colorsFor(bar)

	info = Instance.new("Frame")
	info.Name = "Info"
	info.BackgroundTransparency = 1
	info.AnchorPoint = Vector2.new(0, 0.5)
	info.Position = UDim2.new(0, EditBarConfig.PADDING.left, 0.5, 4)
	info.ZIndex = 2
	info.Parent = bar
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = info

	nameLabel = UIKit.label(info, "", Enum.Font.FredokaOne, EditBarConfig.INFO.name, palette.ink)
	nameLabel.Name = "Name"
	nameLabel.LayoutOrder = 1
	nameLabel.Size = UDim2.new(1, 0, 0, EditBarConfig.INFO.name + 4)
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	chip = UIKit.pill(info, "", lightOf("lilac"), palette.ink)
	chip.Name = "Chip"
	chip.LayoutOrder = 2
	chip.TextSize = EditBarConfig.INFO.chip

	hint = UIKit.label(info, "", Enum.Font.GothamBold, EditBarConfig.INFO.hint, palette.inkSoft)
	hint.Name = "Hint"
	hint.LayoutOrder = 3
	hint.Size = UDim2.new(1, 0, 0, EditBarConfig.INFO.hint * 2 + 6)
	hint.TextWrapped = true
	hint.TextYAlignment = Enum.TextYAlignment.Top

	for index = 1, SLOTS do
		slots[index] = buildSlot(index)
	end

	local closeButton = UIKit.closeButton(bar)
	closeButton.Activated:Connect(close)

	highlight = Instance.new("Highlight")
	highlight.Name = "EditBarGlow"
	highlight.FillColor = rgb(EditBarConfig.HIGHLIGHT.color)
	highlight.FillTransparency = EditBarConfig.HIGHLIGHT.fill
	highlight.OutlineColor = rgb(EditBarConfig.HIGHLIGHT.color)
	highlight.OutlineTransparency = EditBarConfig.HIGHLIGHT.outline
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = UIController.GetScreenGui()
end

-- Opens the bar for a thing (closing the one up): it lights up, the bottom tiles make way, the bar slides up
function EditBarController.Open(spec: Spec)
	close()
	local thing = spec.describe()
	if not thing then
		return
	end
	current = spec
	highlight.Adornee = spec.target
	highlight.Enabled = true
	spec.at:SetAttribute("Editing", true) -- this client's: the shelf hover leaves it alone (ShelfInfoController)
	render(spec, thing)
	Hud.setBottomHidden(REASON, true)
	bar.Position = UDim2.new(0.5, 0, 1, HEIGHT)
	bar.Visible = true
	TweenService:Create(bar, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -HudLayout.BOTTOM_MARGIN),
	}):Play()
end

function EditBarController.Close()
	close()
end

-- Whether a bar is up (a guide waits while you're editing: Util/PlayerBusy)
function EditBarController.IsOpen(): boolean
	return current ~= nil
end

function EditBarController.Start()
	build()
	-- a window opening takes over (the Shop, a case's cards, a machine's window)
	UIKit.onPanelsChanged(function(open: boolean)
		if open then
			close()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local release = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if release and holding then
			stopHold()
		end
	end)
	local since = 0
	RunService.RenderStepped:Connect(function(dt)
		local held = holding
		local spec = current
		if held and spec then
			local share = (os.clock() - held.began) / EditBarConfig.HOLD_SECONDS
			if share >= 1 then
				local action = spec.actions[held.slot.state and held.slot.state.id or ""]
				close()
				if action then
					action()
				end
			else
				setFill(held.slot, share)
			end
		end
		since += dt
		if since >= EditBarConfig.CHECK_SECONDS then
			since = 0
			check()
		end
	end)
end

return EditBarController
