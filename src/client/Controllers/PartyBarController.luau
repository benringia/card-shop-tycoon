--!strict
-- Quick party bar in the bottom-right corner, left of the cash: your avatar, then your 3 party slots. Tap a party card to
-- summon it (tap the summoned one again to unsummon); tap an empty slot to pick a card in the binder; tap your
-- avatar to open the Party panel. Cards resting after a fight show "😴 2:41".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Party = require(Config:WaitForChild("Party"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local RestTimers = require(ClientUtil:WaitForChild("RestTimers"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))
local BinderController = require(Controllers:WaitForChild("BinderController"))
local PartyController = require(Controllers:WaitForChild("PartyController"))

type SlotButton = { button: TextButton, stroke: UIStroke, scale: UIScale, rest: TextLabel }

local PORTRAIT_SIZE = 48
local SUMMONED_STROKE = 3
local IDLE_STROKE = 1.5
local EMPTY_COLOR = Color3.fromRGB(25, 25, 35)

local player = Players.LocalPlayer

local PartyBarController = {}

local slotButtons: { SlotButton } = {}
local slots: { [number]: string } = {} -- party slot -> beastId
local summoned: number? = nil

local function makeCircle(parent: Instance, order: number): (TextButton, UIStroke)
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(PORTRAIT_SIZE, PORTRAIT_SIZE)
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 22
	button.TextColor3 = UIKit.Colors.Text
	button.TextStrokeTransparency = 0.5
	button.Parent = parent
	UIKit.corner(button, PORTRAIT_SIZE / 2)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = IDLE_STROKE
	stroke.Parent = button
	return button, stroke
end

local function render()
	local beasts = BinderController.GetBeasts()
	for slot, entry in slotButtons do
		local beast = beasts[slots[slot] or ""]
		local card = if beast then Cards.ById[beast.cardId] else nil
		local isSummoned = card ~= nil and summoned == slot
		if card then
			-- Placeholder portrait like the card art: the name's initial on the element colour
			entry.button.Text = string.sub(card.name, 1, 1)
			entry.button.BackgroundColor3 = Cards.ELEMENTS[card.element] or UIKit.Colors.Row
			entry.button.BackgroundTransparency = if isSummoned then 0 else 0.35
		else
			entry.button.Text = "+"
			entry.button.BackgroundColor3 = EMPTY_COLOR
			entry.button.BackgroundTransparency = 0.3
		end
		entry.stroke.Color = if isSummoned then UIKit.Colors.Accent else Color3.new(1, 1, 1)
		entry.stroke.Thickness = if isSummoned then SUMMONED_STROKE else IDLE_STROKE
		entry.stroke.Transparency = if isSummoned then 0 else 0.6
		entry.scale.Scale = if isSummoned then 1.08 else 1
	end
end

function PartyBarController.Start()
	local bar = Instance.new("Frame")
	bar.Name = "PartyBar"
	bar.LayoutOrder = 0 -- left of the buff / cash / XP column
	bar.Size = UDim2.new()
	bar.AutomaticSize = Enum.AutomaticSize.XY
	bar.BackgroundTransparency = 1
	bar.Parent = UIController.GetStatusRow()
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	-- Your avatar: opens the Party panel
	local avatar, avatarStroke = makeCircle(bar, 0)
	avatar.Name = "Avatar"
	avatar.Text = ""
	avatar.BackgroundColor3 = EMPTY_COLOR
	avatarStroke.Color = UIKit.Colors.Accent
	local headshot = Instance.new("ImageLabel")
	headshot.Size = UDim2.fromScale(1, 1)
	headshot.BackgroundTransparency = 1
	headshot.Parent = avatar
	UIKit.corner(headshot, PORTRAIT_SIZE / 2)
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
		local button, stroke = makeCircle(bar, slot)
		button.Name = `Slot{slot}`
		local scale = Instance.new("UIScale")
		scale.Parent = button
		local rest = UIKit.label(button, "", Enum.Font.GothamBold, 11, UIKit.Colors.Text)
		rest.AnchorPoint = Vector2.new(0.5, 1)
		rest.Position = UDim2.new(0.5, 0, 1, 6)
		rest.Size = UDim2.fromOffset(PORTRAIT_SIZE + 10, 16)
		rest.TextXAlignment = Enum.TextXAlignment.Center
		rest.BackgroundColor3 = EMPTY_COLOR
		rest.BackgroundTransparency = 0.15
		rest.Visible = false
		UIKit.corner(rest, 6)
		slotButtons[slot] = { button = button, stroke = stroke, scale = scale, rest = rest }
		button.Activated:Connect(function()
			if not slots[slot] then
				BinderController.Open("Tap a card, then Add to party.")
			elseif summoned == slot then
				Remotes.Summon:FireServer(nil)
			else
				Remotes.Summon:FireServer(slot)
			end
		end)
	end
	render()

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
		for slot, entry in slotButtons do
			local seconds = if slots[slot] then RestTimers.GetSeconds(slots[slot]) else 0
			entry.rest.Visible = seconds > 0
			if seconds > 0 then
				entry.rest.Text = `😴 {RestTimers.Format(seconds)}`
			end
		end
	end)
end

return PartyBarController
