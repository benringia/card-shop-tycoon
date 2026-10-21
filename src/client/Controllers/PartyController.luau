--!strict
-- Party panel: your 3 party cards. Each slot shows the card (face, grade, level, stars), the perk it gives
-- while summoned, Summon / Unsummon and Remove. One card is summoned at a time: it follows you around and
-- its perk works. Cards are added from the binder card view. The server sends PartyChanged on every change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local PartyRules = require(Shared:WaitForChild("Util"):WaitForChild("PartyRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local RestTimers = require(ClientUtil:WaitForChild("RestTimers"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))

type PartyState = {
	slots: { { slot: number, beastId: string } },
	summoned: number?,
	perk: { kind: string, value: number, text: string }?,
}

local ROW_HEIGHT = 112
local FACE_SIZE = Vector2.new(70, 100)
local BUTTON_WIDTH = 116

local PartyController = {}

local panel: Frame
local list: ScrollingFrame
local perkLabel: TextLabel
local state: PartyState? = nil
local hintLabels: { [string]: TextLabel } = {} -- beastId -> the row's bottom line (perk hint, or resting time)

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function makeRow(order: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
	row.BackgroundColor3 = UIKit.Colors.Row
	row.Parent = list
	UIKit.corner(row, 10)
	return row
end

local function addText(row: GuiObject, text: string, x: number, y: number, width: UDim, height: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = UIKit.label(row, text, font, size, color)
	label.Position = UDim2.new(0, x, 0, y)
	label.Size = UDim2.new(width.Scale, width.Offset, 0, height)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

local function buildEmptyRow(slot: number)
	local row = makeRow(slot)
	addText(row, `Slot {slot} · empty`, 14, 12, UDim.new(1, -(BUTTON_WIDTH + 30)), 22, Enum.Font.GothamBold, 17, UIKit.Colors.Text)
	addText(row, "Pick a card in your binder and press Add to party.", 14, 40, UDim.new(1, -(BUTTON_WIDTH + 30)), 40, Enum.Font.Gotham, 13, UIKit.Colors.Subtext).TextWrapped = true
	local add = UIKit.button(row, "Add card", UIKit.Colors.Accent)
	add.AnchorPoint = Vector2.new(1, 0.5)
	add.Position = UDim2.new(1, -10, 0.5, 0)
	add.Size = UDim2.fromOffset(BUTTON_WIDTH, 48)
	add.TextSize = 14
	add.Activated:Connect(function()
		panel.Visible = false
		BinderController.Open("Tap a card, then Add to party.")
	end)
end

local function buildCardRow(slot: number, beastId: string, summoned: boolean)
	local row = makeRow(slot)
	local beast = BinderController.GetBeasts()[beastId]
	local card = if beast then Cards.ById[beast.cardId] else nil
	if not beast or not card then
		addText(row, `Slot {slot}`, 14, 12, UDim.new(1, -28), 22, Enum.Font.GothamBold, 17, UIKit.Colors.Text)
		return
	end
	if summoned then
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIKit.Colors.Accent
		stroke.Thickness = 2
		stroke.Parent = row
	end

	local faceHolder = Instance.new("Frame")
	faceHolder.Position = UDim2.fromOffset(8, 6)
	faceHolder.Size = UDim2.fromOffset(FACE_SIZE.X, FACE_SIZE.Y)
	faceHolder.BackgroundTransparency = 1
	faceHolder.Parent = row
	local face = Instance.new("Frame")
	face.Size = UDim2.fromScale(1, 1)
	face.Parent = faceHolder
	UIKit.corner(face, 8)
	local faceStroke = Instance.new("UIStroke")
	faceStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	faceStroke.Parent = face
	CardFace.render(face, faceStroke, card, beast.foil, false)

	local x = FACE_SIZE.X + 18
	local textWidth = UDim.new(1, -(x + BUTTON_WIDTH + 20))
	local title = `{if summoned then "Summoned · " else ""}{card.name}{if beast.foil then " FOIL" else ""}`
	addText(row, title, x, 6, textWidth, 20, Enum.Font.GothamBold, 15, if summoned then UIKit.Colors.Accent else UIKit.Colors.Text)
	addText(row, `{BeastRules.describeGrade(beast.grade)} · {BeastRules.describeGrowth(beast.level, beast.stars)}`, x, 28, textWidth, 16, Enum.Font.Gotham, 12, UIKit.Colors.Subtext)
	local perk = PartyRules.getPerk(Party, card.element, card.rarity, beast.stars)
	local perkText = if perk then PartyRules.describe(perk) else "No perk"
	addText(row, `{card.element} perk · {perkText}`, x, 48, textWidth, 36, Enum.Font.GothamBold, 13, UIKit.Colors.Text).TextWrapped = true
	hintLabels[beastId] = addText(row, "", x, 86, textWidth, 16, Enum.Font.Gotham, 11, UIKit.Colors.Subtext)

	local summon = UIKit.button(row, if summoned then "Unsummon" else "Summon", if summoned then UIKit.Colors.Row else UIKit.Colors.Accent)
	summon.AnchorPoint = Vector2.new(1, 0)
	summon.Position = UDim2.new(1, -10, 0, 6)
	summon.Size = UDim2.fromOffset(BUTTON_WIDTH, 48)
	summon.TextSize = 14
	summon.Activated:Connect(function()
		Remotes.Summon:FireServer(if summoned then nil else slot)
	end)

	local remove = UIKit.button(row, "Remove", UIKit.Colors.Danger)
	remove.AnchorPoint = Vector2.new(1, 0)
	remove.Position = UDim2.new(1, -10, 0, 58)
	remove.Size = UDim2.fromOffset(BUTTON_WIDTH, 48)
	remove.TextSize = 14
	remove.Activated:Connect(function()
		Remotes.SetPartySlot:FireServer(slot, nil)
	end)
end

-- Bottom line of each card row: resting countdown after fainting, otherwise the perk hint
local function updateHints()
	for beastId, label in hintLabels do
		local seconds = RestTimers.GetSeconds(beastId)
		if seconds > 0 then
			local spring = if RestTimers.IsNearSpring() then " · Healing faster" else " · plaza spring heals faster"
			label.Text = `😴 Resting {RestTimers.Format(seconds)} · can't fight{spring}`
			label.TextColor3 = UIKit.Colors.Text
		else
			label.Text = "More stars make the perk stronger."
			label.TextColor3 = UIKit.Colors.Subtext
		end
	end
end

local function render()
	if not panel.Visible then
		return
	end
	clear(list)
	hintLabels = {}
	local current = state
	if not current then
		perkLabel.Text = ""
		local wait = UIKit.label(list, "Loading...", Enum.Font.GothamBold, 15, UIKit.Colors.Subtext)
		wait.Size = UDim2.new(1, 0, 0, 30)
		return
	end
	perkLabel.Text = if current.perk
		then `Active perk: {current.perk.text}`
		else "No creature summoned. Summon one to get its perk."
	local bySlot: { [number]: string } = {}
	for _, entry in current.slots do
		bySlot[entry.slot] = entry.beastId
	end
	for slot = 1, Party.PARTY_SIZE do
		local beastId = bySlot[slot]
		if beastId then
			buildCardRow(slot, beastId, current.summoned == slot)
		else
			buildEmptyRow(slot)
		end
	end
	updateHints()
end

local function toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		Remotes.RequestParty:FireServer()
		render()
	end
end

-- Opens or closes the Party panel (also from the avatar in the party bar)
function PartyController.Toggle()
	toggle()
end

function PartyController.Start()
	local screenGui = UIController.GetScreenGui()
	panel, list = UIKit.panel(screenGui, "Party", "Party")
	perkLabel = UIKit.label(panel, "", Enum.Font.GothamBold, 14, UIKit.Colors.Accent)
	perkLabel.Position = UDim2.fromOffset(16, 56)
	perkLabel.Size = UDim2.new(1, -32, 0, 22)
	perkLabel.TextTruncate = Enum.TextTruncate.AtEnd
	list.Position = UDim2.fromOffset(12, 84)
	list.Size = UDim2.new(1, -24, 1, -96)

	-- Top of the middle-left HUD stack, above the Jobs button
	local button = UIKit.button(screenGui, "Party", UIKit.Colors.Row)
	button.Name = "PartyButton"
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 12, 0.5, -140)
	button.Size = UDim2.fromOffset(96, 50)
	button.TextSize = 17
	button.Activated:Connect(toggle)

	Remotes.PartyChanged.OnClientEvent:Connect(function(payload: PartyState)
		if typeof(payload) ~= "table" or typeof(payload.slots) ~= "table" then
			return
		end
		state = payload
		render()
	end)
	local sinceHints = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceHints += dt
		if sinceHints >= 0.5 and panel.Visible then
			sinceHints = 0
			updateHints()
		end
	end)
	-- Levels and stars change perks; redraw with the new binder
	Remotes.CollectionChanged.OnClientEvent:Connect(function()
		task.defer(render)
	end)
end

return PartyController
