--!strict
-- Pack opening: the "Rip a pack" button (while carrying a box of packs) and the opening screen.
-- Tap the pack to tear it, then tap each face-down card to flip it. The hit slot flips last with a
-- rarity-coloured build-up. The server already rolled the cards; this only plays the reveal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Packs = require(Config:WaitForChild("Packs"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

type Card = typeof(Cards.List[1])
type Pack = typeof(Packs.ById[""])
type PullResult = { cardId: string, foil: boolean }

type CardView = {
	card: Card,
	foil: boolean,
	button: TextButton,
	inner: Frame,
	stroke: UIStroke,
	flipped: boolean,
}

local RIP_WAIT_SECONDS = 3 -- re-enable the button if the server never answers
local RIP_KEY = Enum.KeyCode.T -- rips a pack, then advances the opening screen (tear → flip → done)

local player = Players.LocalPlayer

local PackOpeningController = {}

local ripButton: TextButton
local gui: ScreenGui
local boxLabel: TextLabel
local packButton: TextButton
local cardRow: Frame
local statusLabel: TextLabel
local doneButton: TextButton
local oddsPanel: TextLabel
local flash: Frame

local isOpening = false
local waitingForServer = false
local tearing = false
local busy = false -- a flip is animating
local pendingResults: { PullResult }? = nil
local views: { CardView } = {}
local flippedCount = 0

local function tween(instance: Instance, seconds: number, goals: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(instance, info, goals)
	t:Play()
	return t
end

local function playSound(soundId: string)
	if soundId == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	task.delay(5, function()
		sound:Destroy()
	end)
end

local function getCardValue(view: CardView): number
	return CardRules.getMarketValue(view.card, view.foil)
end

local function buildOddsText(pack: Pack): string
	local lines = { `{pack.name} pack odds` }
	for index, slot in pack.slots do
		local total = 0
		for _, option in slot do
			total += option.weight
		end
		local parts = {}
		for _, option in slot do
			table.insert(parts, string.format("%s %g%%", option.rarity, option.weight / total * 100))
		end
		table.insert(lines, `Card {index}: {table.concat(parts, " / ")}`)
	end
	table.insert(lines, string.format("Any card can be Foil (%gx value): %g%%", Rarities.FOIL_MULTIPLIER, Rarities.FOIL_CHANCE * 100))
	return table.concat(lines, "\n")
end

local function getPacksLeft(): number
	local units = player:GetAttribute("CarryUnits")
	return if typeof(units) == "number" then units else 0
end

-- Ripping is offered while carrying a box whose product is a pack
local function refreshRipButton()
	local productId = player:GetAttribute("CarryProductId")
	local carryingPacks = typeof(productId) == "string" and Packs.ById[productId] ~= nil
	local left = getPacksLeft()
	ripButton.Visible = carryingPacks and not isOpening
	ripButton.Text = `Rip a pack (T)\n{left} left`
	boxLabel.Text = if carryingPacks then `{left} packs left in box` else "Box empty"
end

local function onRip()
	if waitingForServer or isOpening then
		return
	end
	waitingForServer = true
	Remotes.RipPack:FireServer()
	task.delay(RIP_WAIT_SECONDS, function()
		waitingForServer = false
	end)
end

local function flipCard(view: CardView)
	playSound(PackOpening.FLIP_SOUND_ID)
	tween(view.inner, PackOpening.FLIP_SECONDS, { Size = UDim2.fromScale(0, 1) }).Completed:Wait()
	CardFace.render(view.inner, view.stroke, view.card, view.foil)
	tween(view.inner, PackOpening.FLIP_SECONDS, { Size = UDim2.fromScale(1, 1) }).Completed:Wait()
end

-- The hit slot glows in its rarity colour and pulses before it flips
local function buildUp(view: CardView)
	view.stroke.Color = CardFace.getRarityColor(view.card.rarity)
	local pulses = 3
	local pulseSeconds = PackOpening.HIT_BUILDUP_SECONDS / (pulses * 2)
	for _ = 1, pulses do
		tween(view.stroke, pulseSeconds, { Thickness = 8 }).Completed:Wait()
		tween(view.stroke, pulseSeconds, { Thickness = 3 }).Completed:Wait()
	end
	playSound(PackOpening.HIT_SOUND_IDS[view.card.rarity] or "")
end

local function flashScreen()
	flash.BackgroundTransparency = 0
	flash.Visible = true
	tween(flash, PackOpening.FLASH_SECONDS, { BackgroundTransparency = 1 }).Completed:Wait()
	flash.Visible = false
end

local function finish()
	local total = 0
	for _, view in views do
		total += getCardValue(view)
	end
	statusLabel.Text = string.format("Pack value: $%.2f", total)
	doneButton.Visible = true
end

local function onCardTapped(view: CardView)
	if busy or view.flipped then
		return
	end
	local isHit = view == views[#views]
	if isHit and flippedCount < #views - 1 then
		statusLabel.Text = "Flip the others first!"
		return
	end

	busy = true
	if isHit then
		buildUp(view)
	end
	flipCard(view)
	view.flipped = true
	flippedCount += 1
	if view.card.rarity == "Legendary" then
		task.spawn(flashScreen)
	end
	busy = false

	if flippedCount == #views then
		finish()
	elseif not isHit then
		statusLabel.Text = if flippedCount == #views - 1 then "Now the big one..." else "Tap the cards to flip them"
	end
end

local function makeCardView(card: Card, foil: boolean, order: number): CardView
	local button = Instance.new("TextButton")
	button.Name = "Card" .. order
	button.LayoutOrder = order
	button.Size = UDim2.fromScale(0.18, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = cardRow

	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 0.7
	aspect.Parent = button

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = button
	UIKit.corner(inner, 10)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = inner

	CardFace.renderBack(inner, stroke)

	local view: CardView = {
		card = card,
		foil = foil,
		button = button,
		inner = inner,
		stroke = stroke,
		flipped = false,
	}
	button.Activated:Connect(function()
		onCardTapped(view)
	end)
	return view
end

local function clearCards()
	for _, view in views do
		view.button:Destroy()
	end
	table.clear(views)
	flippedCount = 0
end

local function dealCards(results: { PullResult })
	-- No flipping until every card is down, so the last card is really the hit slot
	busy = true
	cardRow.Visible = true
	statusLabel.Text = "Tap the cards to flip them"
	for index, result in results do
		local card = Cards.ById[result.cardId]
		if card then
			table.insert(views, makeCardView(card, result.foil == true, index))
			task.wait(PackOpening.DEAL_DELAY)
		end
	end
	busy = false
end

local function tearPack()
	local results = pendingResults
	if tearing or not results then
		return
	end
	tearing = true
	pendingResults = nil
	playSound(PackOpening.TEAR_SOUND_ID)

	local shake = PackOpening.TEAR_SECONDS / 4
	tween(packButton, shake, { Rotation = 6 }).Completed:Wait()
	tween(packButton, shake, { Rotation = -6 }).Completed:Wait()
	tween(packButton, shake * 2, {
		Rotation = 0,
		Size = UDim2.fromScale(0.4, 0.75),
		BackgroundTransparency = 1,
		TextTransparency = 1,
	}).Completed:Wait()

	packButton.Visible = false
	packButton.Size = UDim2.fromScale(0.22, 0.55)
	packButton.BackgroundTransparency = 0
	packButton.TextTransparency = 0
	tearing = false
	dealCards(results)
end

local function close()
	gui.Enabled = false
	oddsPanel.Visible = false
	clearCards()
	isOpening = false
	refreshRipButton()
end

local function onPackOpened(productId: string, results: { PullResult })
	waitingForServer = false
	local pack = Packs.ById[productId]
	if not pack or typeof(results) ~= "table" then
		return
	end

	clearCards()
	isOpening = true
	refreshRipButton()
	pendingResults = results

	packButton.BackgroundColor3 = pack.color
	packButton.Text = `{string.upper(pack.name)}\n\nTap to open!`
	packButton.Visible = true
	cardRow.Visible = false
	doneButton.Visible = false
	statusLabel.Text = ""
	oddsPanel.Text = buildOddsText(pack)
	gui.Enabled = true
end

local function buildScreen()
	gui = Instance.new("ScreenGui")
	gui.Name = "PackOpening"
	gui.DisplayOrder = 10 -- above the main HUD
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.25
	backdrop.Active = true -- swallow taps so the world behind isn't clicked
	backdrop.Parent = gui

	packButton = UIKit.button(gui, "", Color3.new(1, 1, 1))
	packButton.Name = "Pack"
	packButton.AnchorPoint = Vector2.new(0.5, 0.5)
	packButton.Position = UDim2.fromScale(0.5, 0.48)
	packButton.Size = UDim2.fromScale(0.22, 0.55)
	packButton.Font = Enum.Font.FredokaOne
	packButton.TextScaled = true
	packButton.Activated:Connect(tearPack)
	local packAspect = Instance.new("UIAspectRatioConstraint")
	packAspect.AspectRatio = 0.65
	packAspect.Parent = packButton

	cardRow = Instance.new("Frame")
	cardRow.Name = "Cards"
	cardRow.AnchorPoint = Vector2.new(0.5, 0.5)
	cardRow.Position = UDim2.fromScale(0.5, 0.47)
	cardRow.Size = UDim2.fromScale(0.96, 0.5)
	cardRow.BackgroundTransparency = 1
	cardRow.Visible = false
	cardRow.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.012, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = cardRow

	statusLabel = UIKit.label(gui, "", Enum.Font.GothamBold, 22, UIKit.Colors.Text)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.Position = UDim2.new(0.5, 0, 0.73, 0)
	statusLabel.Size = UDim2.new(0.9, 0, 0, 32)

	doneButton = UIKit.button(gui, "Done", UIKit.Colors.Accent)
	doneButton.Name = "Done"
	doneButton.AnchorPoint = Vector2.new(0.5, 0)
	doneButton.Position = UDim2.new(0.5, 0, 0.73, 36)
	doneButton.Size = UDim2.fromOffset(160, 56)
	doneButton.Visible = false
	doneButton.Activated:Connect(close)

	local oddsButton = UIKit.button(gui, "Odds", UIKit.Colors.Row)
	oddsButton.Name = "OddsButton"
	oddsButton.AnchorPoint = Vector2.new(1, 0)
	oddsButton.Position = UDim2.new(1, -16, 0, 60)
	oddsButton.Size = UDim2.fromOffset(88, 48)

	oddsPanel = UIKit.label(gui, "", Enum.Font.Gotham, 16, UIKit.Colors.Text)
	oddsPanel.Name = "Odds"
	oddsPanel.AnchorPoint = Vector2.new(1, 0)
	oddsPanel.Position = UDim2.new(1, -16, 0, 116)
	oddsPanel.Size = UDim2.fromOffset(330, 190)
	oddsPanel.BackgroundTransparency = 0.05
	oddsPanel.BackgroundColor3 = UIKit.Colors.Panel
	oddsPanel.TextYAlignment = Enum.TextYAlignment.Top
	oddsPanel.ZIndex = 5
	oddsPanel.Visible = false
	UIKit.corner(oddsPanel, 10)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = oddsPanel
	oddsButton.Activated:Connect(function()
		oddsPanel.Visible = not oddsPanel.Visible
	end)

	boxLabel = UIKit.label(gui, "", Enum.Font.GothamBold, 18, UIKit.Colors.Text)
	boxLabel.Name = "PacksLeft"
	boxLabel.Position = UDim2.fromOffset(16, 64)
	boxLabel.Size = UDim2.fromOffset(260, 40)

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.ZIndex = 20
	flash.Visible = false
	flash.Parent = gui
end

-- T on the opening screen: tear the pack, else flip the next card, else close
local function advance()
	if pendingResults then
		tearPack()
	elseif doneButton.Visible then
		close()
	else
		for _, view in views do
			if not view.flipped then
				onCardTapped(view)
				return
			end
		end
	end
end

local function onInputBegan(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= RIP_KEY then
		return
	end
	if gui.Enabled then
		task.spawn(advance)
	elseif ripButton.Visible then
		onRip()
	end
end

function PackOpeningController.Start()
	ripButton = UIKit.button(UIController.GetScreenGui(), "", UIKit.Colors.Accent)
	ripButton.Name = "RipButton"
	-- Next to the Drop button on the middle-left
	ripButton.AnchorPoint = Vector2.new(0, 0.5)
	ripButton.Position = UDim2.new(0, 116, 0.5, 132)
	ripButton.Size = UDim2.fromOffset(130, 56)
	ripButton.TextSize = 16
	ripButton.Visible = false
	ripButton.Activated:Connect(onRip)

	buildScreen()
	refreshRipButton()

	player:GetAttributeChangedSignal("CarryProductId"):Connect(refreshRipButton)
	player:GetAttributeChangedSignal("CarryUnits"):Connect(refreshRipButton)
	UserInputService.InputBegan:Connect(onInputBegan)
	Remotes.PackOpened.OnClientEvent:Connect(onPackOpened)
end

return PackOpeningController
