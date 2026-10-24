--!strict
-- Quick party bar in the bottom-right corner, left of the cash: a dark tray with your avatar ("PARTY", opens the
-- Party panel), then your 3 party slots as small cards. A filled slot shows the card's art in its rarity rim with
-- its level; the summoned one lifts and glows with an OUT tag; an empty one is a dashed "+" (picks a card in the
-- binder). Tap a slot, or press 1 / 2 / 3, to summon it (again to unsummon). Cards resting after a fight dim and show
-- "💤 2:41". Numbers: Config/Party BAR.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Party = require(Config:WaitForChild("Party"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local RestTimers = require(ClientUtil:WaitForChild("RestTimers"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))

type SlotView = {
	button: TextButton,
	lift: UIScale,
	rim: UIStroke,
	rimShade: UIGradient,
	art: ImageLabel,
	element: Frame,
	level: TextLabel,
	empty: Frame,
	outTag: TextLabel,
	glow: ImageLabel,
	rest: TextLabel,
	shade: Frame,
}

local BAR = Party.BAR
local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end
local SLOT_SIZE = UDim2.fromOffset(BAR.SLOT[1], BAR.SLOT[2])
local EMPTY = rgb(BAR.EMPTY)
local EMPTY_EDGE = rgb(BAR.EMPTY_EDGE)
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(20, 28, 60)
local SUMMON_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
local SUMMON_ACTION = "PartySummon"

local player = Players.LocalPlayer

local PartyBarController = {}

local slotViews: { SlotView } = {}
local slots: { [number]: string } = {} -- party slot -> beastId
local summoned: number? = nil

-- Tap or key: an empty slot asks for a card, a party card summons, the summoned one goes back
local function useSlot(slot: number)
	if not slots[slot] then
		BinderController.Open("Tap a card, then Add to party.")
	elseif summoned == slot then
		Remotes.Summon:FireServer(nil)
	else
		Remotes.Summon:FireServer(slot)
	end
end

local function keyChip(parent: GuiObject, key: string)
	local chip = UIKit.label(parent, key, Enum.Font.FredokaOne, 12, WHITE)
	chip.Name = "Key"
	-- Bottom-left corner, clear of the OUT tag on top and the level chip in the middle
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.new(0, 1, 1, -1)
	chip.Size = UDim2.fromOffset(17, 17)
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.BackgroundColor3 = INK
	chip.BackgroundTransparency = 0
	chip.ZIndex = 8
	UIKit.corner(chip, 5)
	UIKit.outline(chip, WHITE, 1.5)
end

local function makeSlot(parent: Instance, slot: number): SlotView
	local button = Instance.new("TextButton")
	button.Name = `Slot{slot}`
	button.LayoutOrder = slot
	button.Text = ""
	button.Size = SLOT_SIZE
	button.BackgroundColor3 = EMPTY
	button.AutoButtonColor = false
	button.ClipsDescendants = false
	button.Parent = parent
	UIKit.corner(button, 8)
	local lift = Instance.new("UIScale")
	lift.Parent = button

	-- The summoned glow behind the card
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(2.2, 1.9)
	glow.Image = CardDesign.IMAGES.GLOW
	glow.ImageColor3 = UIKit.Colors.Accent
	glow.ImageTransparency = 0.25
	glow.ZIndex = 0
	glow.Visible = false
	glow.Parent = button

	-- The card: its element scene with the element icon on it
	local art = Instance.new("ImageLabel")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.ScaleType = Enum.ScaleType.Crop
	art.ZIndex = 2
	art.Parent = button
	UIKit.corner(art, 8)
	local element = Icon.make(button, "Ember", UDim2.fromScale(0.62, 0.62))
	element.AnchorPoint = Vector2.new(0.5, 0.5)
	element.Position = UDim2.fromScale(0.5, 0.46)
	element.SizeConstraint = Enum.SizeConstraint.RelativeXX
	element.ZIndex = 3

	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = WHITE
	rim.Thickness = BAR.RIM
	rim.Parent = button
	local rimShade = Instance.new("UIGradient")
	rimShade.Rotation = 90
	rimShade.Parent = rim

	local level = UIKit.label(button, "", Enum.Font.FredokaOne, 10, WHITE)
	level.Name = "Level"
	level.AnchorPoint = Vector2.new(1, 1)
	level.Position = UDim2.new(1, -2, 1, -2)
	level.Size = UDim2.fromOffset(0, 14)
	level.AutomaticSize = Enum.AutomaticSize.X
	level.TextWrapped = false
	level.TextXAlignment = Enum.TextXAlignment.Center
	level.BackgroundColor3 = INK
	level.BackgroundTransparency = 0.15
	level.ZIndex = 5
	UIKit.corner(level, 8)
	local levelPad = Instance.new("UIPadding")
	levelPad.PaddingLeft = UDim.new(0, 4)
	levelPad.PaddingRight = UDim.new(0, 4)
	levelPad.Parent = level

	-- Empty: a dashed outline (short white bars round the edge) and a "+"
	local empty = Instance.new("Frame")
	empty.Name = "Empty"
	empty.BackgroundTransparency = 1
	empty.Size = UDim2.fromScale(1, 1)
	empty.ZIndex = 2
	empty.Parent = button
	for index = 0, 5 do
		for _, side in { "Left", "Right" } do
			local dash = Instance.new("Frame")
			dash.BorderSizePixel = 0
			dash.BackgroundColor3 = WHITE
			dash.BackgroundTransparency = 0.45
			dash.AnchorPoint = Vector2.new(0.5, 0)
			dash.Position = UDim2.new(if side == "Left" then 0 else 1, 0, (index + 0.2) / 6, 0)
			dash.Size = UDim2.new(0, 2, 1 / 12, 0)
			dash.ZIndex = 2
			dash.Parent = empty
		end
	end
	for index = 0, 3 do
		for _, side in { "Top", "Bottom" } do
			local dash = Instance.new("Frame")
			dash.BorderSizePixel = 0
			dash.BackgroundColor3 = WHITE
			dash.BackgroundTransparency = 0.45
			dash.AnchorPoint = Vector2.new(0, 0.5)
			dash.Position = UDim2.new((index + 0.2) / 4, 0, if side == "Top" then 0 else 1, 0)
			dash.Size = UDim2.new(1 / 8, 0, 0, 2)
			dash.ZIndex = 2
			dash.Parent = empty
		end
	end
	local plus = UIKit.label(empty, "+", Enum.Font.FredokaOne, 26, Color3.fromRGB(190, 200, 230))
	plus.Size = UDim2.fromScale(1, 1)
	plus.TextXAlignment = Enum.TextXAlignment.Center
	plus.ZIndex = 3

	local outTag = UIKit.label(button, "OUT", Enum.Font.FredokaOne, 11, UIKit.Colors.Ink)
	outTag.Name = "Out"
	outTag.AnchorPoint = Vector2.new(0.5, 0.5)
	outTag.Position = UDim2.new(0.5, 0, 0, 0)
	outTag.Size = UDim2.fromOffset(32, 15)
	outTag.TextXAlignment = Enum.TextXAlignment.Center
	outTag.BackgroundColor3 = UIKit.Colors.Accent
	outTag.BackgroundTransparency = 0
	outTag.ZIndex = 7
	outTag.Visible = false
	UIKit.corner(outTag, 8)

	-- Resting: the card dims and the countdown sits over it
	local shade = Instance.new("Frame")
	shade.Name = "Resting"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.ZIndex = 6
	shade.Visible = false
	shade.Parent = button
	UIKit.corner(shade, 8)
	local rest = UIKit.label(shade, "", Enum.Font.FredokaOne, 12, WHITE)
	rest.Size = UDim2.fromScale(1, 1)
	rest.TextXAlignment = Enum.TextXAlignment.Center
	rest.ZIndex = 7

	keyChip(button, tostring(slot))
	button.Activated:Connect(function()
		useSlot(slot)
	end)
	return {
		button = button,
		lift = lift,
		rim = rim,
		rimShade = rimShade,
		art = art,
		element = element,
		level = level,
		empty = empty,
		outTag = outTag,
		glow = glow,
		rest = rest,
		shade = shade,
	}
end

local function render()
	local beasts = BinderController.GetBeasts()
	for slot, view in slotViews do
		local beast = beasts[slots[slot] or ""]
		local card = if beast then Cards.ById[beast.cardId] else nil
		local isSummoned = card ~= nil and summoned == slot
		view.empty.Visible = card == nil
		view.art.Visible = card ~= nil
		view.element.Visible = card ~= nil
		view.level.Visible = card ~= nil
		view.outTag.Visible = isSummoned
		view.glow.Visible = isSummoned
		if card and beast then
			local own = CardDesign.ART_IMAGES[card.name]
			view.art.Image = own or CardDesign.SCENES[card.element] or ""
			Icon.set(view.element, card.element)
			view.element.Visible = own == nil -- a card's own picture already shows its creature
			view.level.Text = `Lv {beast.level}`
			local colors = CardDesign.RIMS[card.rarity] or CardDesign.RIMS.Common
			view.rimShade.Color = ColorSequence.new(colors[1], colors[2])
			view.button.BackgroundColor3 = Cards.ELEMENTS[card.element] or EMPTY
		else
			view.rimShade.Color = ColorSequence.new(EMPTY_EDGE)
			view.button.BackgroundColor3 = EMPTY
		end
		view.rim.Thickness = if isSummoned then BAR.RIM + 1 else BAR.RIM
		if isSummoned then
			view.rimShade.Color = ColorSequence.new(UIKit.Colors.Accent:Lerp(WHITE, 0.4), UIKit.Colors.Accent)
		end
		view.rim.Transparency = if card then 0 else 1
		TweenService:Create(view.lift, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = if isSummoned then BAR.LIFT else 1 }):Play()
	end
end

function PartyBarController.Start()
	-- The tray: a dark rounded bar like the money pills beside it
	local bar = Instance.new("Frame")
	bar.Name = "PartyBar"
	bar.LayoutOrder = 0 -- left of the buff / cash / XP column
	bar.Size = UDim2.new()
	bar.AutomaticSize = Enum.AutomaticSize.XY
	bar.BackgroundColor3 = rgb(BAR.TRAY)
	bar.BackgroundTransparency = BAR.TRAY_TRANSPARENCY
	bar.Parent = UIController.GetStatusRow()
	UIKit.corner(bar, 16)
	UIKit.outline(bar, UIKit.Colors.Outline, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = bar
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, BAR.GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	-- Your avatar with a PARTY tag: opens the Party panel
	local avatar = Instance.new("TextButton")
	avatar.Name = "Avatar"
	avatar.LayoutOrder = 0
	avatar.Text = ""
	avatar.Size = UDim2.fromOffset(BAR.AVATAR, BAR.AVATAR)
	avatar.BackgroundColor3 = EMPTY
	avatar.Parent = bar
	UIKit.corner(avatar, BAR.AVATAR / 2)
	UIKit.outline(avatar, UIKit.Colors.Accent, 3)
	local headshot = Instance.new("ImageLabel")
	headshot.Size = UDim2.fromScale(1, 1)
	headshot.BackgroundTransparency = 1
	headshot.Parent = avatar
	UIKit.corner(headshot, BAR.AVATAR / 2)
	local tag = UIKit.label(avatar, "PARTY", Enum.Font.FredokaOne, 10, UIKit.Colors.Ink)
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = UDim2.new(0.5, 0, 1, 0)
	tag.Size = UDim2.fromOffset(44, 16)
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.BackgroundColor3 = UIKit.Colors.Accent
	tag.BackgroundTransparency = 0
	tag.ZIndex = 3
	UIKit.corner(tag, 8)
	task.spawn(function()
		local ok, image = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			headshot.Image = image
		end
	end)
	avatar.Activated:Connect(PartyController.Toggle)

	for slot = 1, Party.PARTY_SIZE do
		slotViews[slot] = makeSlot(bar, slot)
	end
	render()

	-- 1 / 2 / 3 summon (bound above Roblox's own hotbar keys; never while typing)
	ContextActionService:BindActionAtPriority(SUMMON_ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local slot = table.find(SUMMON_KEYS, input.KeyCode)
		if not slot or not bar.Visible or not (bar.Parent :: GuiObject).Visible then
			return Enum.ContextActionResult.Pass
		end
		useSlot(slot)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, table.unpack(SUMMON_KEYS))

	Remotes.PartyChanged.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.slots) ~= "table" then
			return
		end
		slots = {}
		for _, entry in payload.slots do
			if typeof(entry) == "table" and typeof(entry.slot) == "number" and typeof(entry.beastId) == "string" then
				slots[entry.slot] = entry.beastId
			end
		end
		summoned = if typeof(payload.summoned) == "number" then payload.summoned else nil
		render()
	end)
	-- Party cards arrive with the binder; redraw when it changes
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)

	-- Resting countdowns
	local sinceRest = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceRest += dt
		if sinceRest < 0.5 then
			return
		end
		sinceRest = 0
		for slot, view in slotViews do
			local seconds = if slots[slot] then RestTimers.GetSeconds(slots[slot]) else 0
			view.shade.Visible = seconds > 0
			if seconds > 0 then
				view.rest.Text = `💤\n{RestTimers.Format(seconds)}`
			end
		end
	end)
end

return PartyBarController
