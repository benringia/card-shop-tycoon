--!strict
-- The Bag's XP Tonic picker (owner 2026-11-17: "xp tonics should have a "Use button" then lets the player choose which
-- pet in the party"): the tonic's Use button turns the Bag's detail panel into your party cards (portrait, name, level
-- and its bar to the next one); tapping one sends a tonic to it (remote UseXpTonic: PartyService checks the card is in
-- your party and below max level, takes the tonic and says what it did). It stays open so a few can go on in a row; a
-- card at max level shows greyed with MAX. BinderController draws the Bag and asks this module to draw the list; this
-- module keeps the party's slots (PartyChanged) and whether the list is open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Beasts = require(Config:WaitForChild("Beasts"))
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local Party = require(Config:WaitForChild("Party"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local CardFace = require((script.Parent :: Instance):WaitForChild("CardFace"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local TonicPicker = {}

local ROW_HEIGHT = 80 -- px before the Bag's own shrink: still about 48 px tall on the smallest phone
local ROW_GAP = 8
local ROWS_TOP = 62
local SEND_GAP = Party.ACTION_COOLDOWN + 0.05 -- quick taps queue up instead of meeting the server's rate limit
local PRESS = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local slots: { [number]: string } = {}
local open = false
local nextSendAt = 0

function TonicPicker.setParty(party: { [number]: string })
	slots = party
end

function TonicPicker.isOpen(): boolean
	return open
end

function TonicPicker.setOpen(value: boolean)
	open = value
end

-- One tonic on that card: sent now, or just after the last one when tapped quickly
local function send(beastId: string)
	local now = os.clock()
	local wait = math.max(0, nextSendAt - now)
	nextSendAt = now + wait + SEND_GAP
	task.delay(wait, function()
		Remotes.UseXpTonic:FireServer(beastId)
	end)
end

local function line(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3, x: number, y: number, rightGap: number): TextLabel
	local label = UIKit.label(parent, text, font, size, color)
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.new(1, -(x + rightGap), 0, size + 4)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 34
	return label
end

-- One party card's row: its portrait in its element's colour, name, level and bar, and what a tap gives
local function row(detail: Frame, target: ItemRules.TonicTarget, y: number, palette: UIKit.Palette)
	local card = Cards.ById[target.cardId]
	local button = Instance.new("TextButton")
	button.Name = `Slot{target.slot}`
	button.Text = ""
	button.AutoButtonColor = false
	button.Active = not target.maxed
	button.Position = UDim2.fromOffset(12, y)
	button.Size = UDim2.new(1, -24, 0, ROW_HEIGHT)
	button.BackgroundColor3 = palette.slotEmpty
	button.ZIndex = 33
	button.Parent = detail
	UIKit.corner(button, 12)
	UIKit.outline(button, palette.rowEdge, 2)
	local scale = Instance.new("UIScale")
	scale.Parent = button

	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.BackgroundColor3 = palette.row
	portrait.Image = if card then CardFace.artImage(card) else ""
	portrait.ScaleType = Enum.ScaleType.Crop
	portrait.AnchorPoint = Vector2.new(0, 0.5)
	portrait.Position = UDim2.new(0, 10, 0.5, 0)
	portrait.Size = UDim2.fromOffset(56, 56)
	portrait.ZIndex = 34
	portrait.Parent = button
	UIKit.corner(portrait, 12)
	UIKit.outline(portrait, if card then Cards.ELEMENTS[card.element] else palette.rowEdge, 3)

	local left, chipRoom = 76, 84
	line(button, if card then card.name else "Creature", Enum.Font.FredokaOne, 16, palette.ink, left, 12, chipRoom)
	line(button, `Lv {target.level}`, Enum.Font.FredokaOne, 14, palette.hint, left, 34, chipRoom)
	local track, fill = UIKit.bar(button, if target.maxed then 1 else BeastRules.levelProgress(target.level, target.xp), UIStyle.BABY.sky.fill)
	track.Position = UDim2.fromOffset(left, 58)
	track.Size = UDim2.new(1, -(left + chipRoom), 0, 8)
	track.ZIndex = 34
	fill.ZIndex = 35

	local chip = UIKit.pill(button, if target.maxed then "MAX" else `+{Items.ITEMS.xpTonic.xp} XP`, if target.maxed then UIStyle.BABY.greyLilac.fill else UIStyle.BABY.mint.fill)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -10, 0.5, 0)
	chip.Size = UDim2.fromOffset(0, 28)
	chip.ZIndex = 35
	if target.maxed then
		button.BackgroundTransparency = 0.4
		portrait.ImageTransparency = 0.4
		return
	end
	button.Activated:Connect(function()
		scale.Scale = 0.94
		TweenService:Create(scale, PRESS, { Scale = 1 }):Play()
		send(target.beastId)
	end)
end

-- Draws the list into `detail` (the Bag's detail panel, already emptied): `palette` its colours, `beasts` the binder's
-- levelled cards, `count` the tonics held, `back` closes the list
function TonicPicker.render(detail: Frame, palette: UIKit.Palette, beasts: { [string]: any }, count: number, back: () -> ())
	local title = line(detail, "Use XP Tonic on...", Enum.Font.FredokaOne, 20, palette.ink, 16, 12, 16)
	title.TextXAlignment = Enum.TextXAlignment.Center
	local hint = line(detail, `+{Items.ITEMS.xpTonic.xp} XP each · You have {count}`, Enum.Font.FredokaOne, 14, palette.hint, 16, 38, 16)
	hint.TextXAlignment = Enum.TextXAlignment.Center

	local targets = ItemRules.tonicTargets(slots, beasts, Party.PARTY_SIZE, Beasts.MAX_LEVEL)
	if #targets == 0 then
		local empty = UIKit.label(detail, "Your party is empty. Add a creature from your binder, then come back.", Enum.Font.FredokaOne, 16, palette.inkSoft)
		empty.Position = UDim2.fromOffset(20, ROWS_TOP + 10)
		empty.Size = UDim2.new(1, -40, 0, 80)
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.ZIndex = 34
	end
	for index, target in targets do
		row(detail, target, ROWS_TOP + (index - 1) * (ROW_HEIGHT + ROW_GAP), palette)
	end

	local backButton = UIKit.button(detail, "Back", UIKit.Colors.Secondary)
	backButton.Name = "Back"
	backButton.AnchorPoint = Vector2.new(0.5, 1)
	backButton.Position = UDim2.new(0.5, 0, 1, -12)
	backButton.Size = UDim2.fromOffset(140, 48)
	backButton.ZIndex = 34
	backButton.Activated:Connect(back)
end

return TonicPicker
