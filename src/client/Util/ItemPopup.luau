--!strict
-- Boss loot picked up (the owner 2026-11-10: "picking up an item should show a notification"; Config/Victory PICKUP,
-- stacking and merging in Util/ItemPopupRules): a dark card slides in at the top right with the item's icon, "+2 Grading
-- Seal" and a line under it (a weapon material's progress, else "Added to your Bag"), a soft pop; the same item again
-- while its card shows adds to it with a little bounce; each slides away after a moment.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Victory = require(Shared:WaitForChild("Config"):WaitForChild("Victory"))
local ItemPopupRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemPopupRules"))
local Icon = require((script.Parent :: Instance):WaitForChild("Icon"))
local SoundBank = require((script.Parent :: Instance):WaitForChild("SoundBank"))

local ItemPopup = {}

local CFG = Victory.PICKUP
local BACK = Color3.fromRGB(18, 14, 26)
local EDGE = Color3.fromRGB(255, 207, 74)
local LINE = Color3.fromRGB(201, 191, 224)
local SLIDE = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MOVE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local AWAY = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type Shown = { frame: Frame, title: TextLabel, line: TextLabel, scale: UIScale }

local cards: { ItemPopupRules.Card } = {}
local shown: { [string]: Shown } = {}
local gui: ScreenGui? = nil

local function screen(): ScreenGui
	if gui and gui.Parent then
		return gui
	end
	local made = Instance.new("ScreenGui")
	made.Name = "ItemPopup"
	made.ResetOnSpawn = false
	made.DisplayOrder = 30
	made.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	made.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui = made
	return made
end

local function text(parent: Instance, value: string, size: number, color: Color3, font: Enum.Font, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = value
	label.Position = UDim2.new(0, CFG.height, 0, y)
	label.Size = UDim2.new(1, -CFG.height - 10, 0, size + 4)
	label.Parent = parent
	return label
end

local function pop()
	local sound = SoundBank.make(CFG.sound)
	sound.Volume = Victory.VOLUME * 0.7
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

local function titleOf(card: ItemPopupRules.Card): string
	local item = Items.ITEMS[card.item]
	return `+{card.count} {if item then item.name else card.item}`
end

-- The cards where they belong now: each slid to its slot (ItemPopupRules.slotY), gone ones slid off to the right
local function layout()
	local keep: { [string]: boolean } = {}
	for index, card in cards do
		keep[card.item] = true
		local entry = shown[card.item]
		if entry then
			TweenService:Create(entry.frame, MOVE, { Position = UDim2.new(1, -CFG.right, 0, ItemPopupRules.slotY(index, CFG)) }):Play()
		end
	end
	for item, entry in shown do
		if not keep[item] then
			shown[item] = nil
			TweenService:Create(entry.frame, AWAY, { Position = entry.frame.Position + UDim2.fromOffset(CFG.width + 40, 0) }):Play()
			task.delay(AWAY.Time, function()
				entry.frame:Destroy()
			end)
		end
	end
end

local function build(card: ItemPopupRules.Card, index: number, line: string): Shown
	local frame = Instance.new("Frame")
	frame.Name = card.item
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Size = UDim2.fromOffset(CFG.width, CFG.height)
	frame.Position = UDim2.new(1, CFG.width + 40, 0, ItemPopupRules.slotY(index, CFG))
	frame.BackgroundColor3 = BACK
	frame.BackgroundTransparency = 0.1
	frame.Parent = screen()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local edge = Instance.new("UIStroke")
	edge.Color = EDGE
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local item = Items.ITEMS[card.item]
	local icon = Icon.make(frame, if item then item.icon else "", UDim2.fromOffset(CFG.height - 16, CFG.height - 16))
	icon.Position = UDim2.fromOffset(8, 8)
	local title = text(frame, titleOf(card), 18, Color3.new(1, 1, 1), Enum.Font.FredokaOne, 8)
	local under = text(frame, line, 13, LINE, Enum.Font.GothamBold, 30)
	TweenService:Create(frame, SLIDE, { Position = UDim2.new(1, -CFG.right, 0, ItemPopupRules.slotY(index, CFG)) }):Play()
	return { frame = frame, title = title, line = under, scale = scale }
end

-- `count` of `item` picked up; `line`: what to say under it (a weapon material's progress), else "Added to your Bag"
function ItemPopup.show(item: string, count: number, line: string?)
	local now = os.clock()
	cards = ItemPopupRules.add(ItemPopupRules.expire(cards, now), item, count, now, CFG)
	local words = line or "Added to your Bag"
	for index, card in cards do
		if card.item ~= item then
			continue
		end
		local entry = shown[item]
		if entry then
			entry.title.Text = titleOf(card)
			entry.line.Text = words
			entry.scale.Scale = 1.12
			TweenService:Create(entry.scale, SLIDE, { Scale = 1 }):Play()
		else
			shown[item] = build(card, index, words)
		end
	end
	layout()
	pop()
	task.delay(CFG.seconds + 0.05, function()
		cards = ItemPopupRules.expire(cards, os.clock())
		layout()
	end)
end

return ItemPopup
