--!strict
-- The pack opening's screen layer over the 3D stage (UI project 3 spec 4.1 / 4.6): a full-screen tap layer (taps,
-- swipes), the hint capsule, the packs-left and pity pills, the Odds button and panel, and the results pills
-- (Your cards · NEW xN · the pack's value · Rarity guide) with a green Continue, popping in after the lineup lands.
-- UIKit look; numbers: Config/PackOpening (TOP, EDGE, PILL_HEIGHT, RESULTS).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local PackOpening = require(Config:WaitForChild("PackOpening"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))

export type Handlers = {
	press: (position: Vector2) -> (), -- a finger or the mouse went down on the stage
	continue: () -> (),
	rarityGuide: () -> (),
}

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local NEW_COLOR = Color3.fromRGB(255, 205, 40)

local OpeningResults = {}

local gui: ScreenGui
local hintPill: Frame
local hintLabel: TextLabel
local boxLabel: TextLabel
local pityLabel: TextLabel
local oddsButton: TextButton
local oddsPanel: TextLabel
local resultsBar: Frame
local newLabel: TextLabel
local valueLabel: TextLabel
local continueButton: TextButton
local continueScale: UIScale

local function pillLabel(name: string, color: Color3, y: number, height: number): TextLabel
	local label = UIKit.label(gui, "", Enum.Font.FredokaOne, 18, color)
	label.Name = name
	label.Position = UDim2.fromOffset(PackOpening.EDGE, y)
	label.Size = UDim2.fromOffset(0, height)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextWrapped = false
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.BackgroundColor3 = UIKit.Colors.Row
	label.BackgroundTransparency = 0.1
	label.ZIndex = 5
	UIKit.corner(label, height / 2)
	UIKit.outline(label, UIKit.Colors.Outline, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = label
	return label
end

-- A rounded pill in the results bar: an icon (Config/UIIcons) and its text; each is a button so the bar stays tappable
local function addPill(name: string, icon: string, text: string, fill: Color3, textColor: Color3, order: number): (TextButton, TextLabel)
	local pill = Instance.new("TextButton")
	pill.Name = name
	pill.Text = ""
	pill.AutoButtonColor = false
	pill.LayoutOrder = order
	pill.Size = UDim2.fromOffset(0, PackOpening.PILL_HEIGHT)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = fill
	pill.Parent = resultsBar
	UIKit.corner(pill, PackOpening.PILL_HEIGHT / 2)
	UIKit.outline(pill, if UIKit.isLight(fill) then UIKit.Colors.Outline else fill:Lerp(BLACK, 0.25), 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 18)
	pad.Parent = pill
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = pill
	local glyph = Icon.make(pill, icon, UDim2.fromOffset(28, 28))
	glyph.LayoutOrder = 1
	local label = UIKit.label(pill, text, Enum.Font.FredokaOne, 21, textColor)
	label.LayoutOrder = 2
	label.Size = UDim2.fromScale(0, 1)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextXAlignment = Enum.TextXAlignment.Center
	local scale = Instance.new("UIScale")
	scale.Name = "Pop"
	scale.Scale = 0
	scale.Parent = pill
	return pill, label
end

function OpeningResults.build(handlers: Handlers)
	gui = Instance.new("ScreenGui")
	gui.Name = "PackOpening"
	gui.DisplayOrder = 42 -- over the stage's cinema bars and banner
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Taps and swipes anywhere on the stage (the buttons take their own)
	local tapLayer = Instance.new("TextButton")
	tapLayer.Name = "Stage"
	tapLayer.Text = ""
	tapLayer.AutoButtonColor = false
	tapLayer.BackgroundTransparency = 1
	tapLayer.Size = UDim2.fromScale(1, 1)
	tapLayer.Parent = gui
	tapLayer.InputBegan:Connect(function(input)
		local press = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if press then
			handlers.press(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)
	UIKit.hideTouchControlsWhileVisible(tapLayer)

	hintPill = Instance.new("Frame")
	hintPill.Name = "Hint"
	hintPill.AnchorPoint = Vector2.new(0.5, 0)
	hintPill.Size = UDim2.fromOffset(0, PackOpening.PILL_HEIGHT)
	hintPill.AutomaticSize = Enum.AutomaticSize.X
	hintPill.BackgroundColor3 = UIKit.Colors.Panel
	hintPill.BackgroundTransparency = 0.2
	hintPill.ZIndex = 5
	hintPill.Parent = gui
	UIKit.corner(hintPill, PackOpening.PILL_HEIGHT / 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = hintPill
	hintLabel = UIKit.label(hintPill, "", Enum.Font.FredokaOne, 20, WHITE)
	hintLabel.Size = UDim2.fromScale(0, 1)
	hintLabel.AutomaticSize = Enum.AutomaticSize.X
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.ZIndex = 6

	boxLabel = pillLabel("PacksLeft", UIKit.Colors.Text, PackOpening.TOP, PackOpening.PILL_HEIGHT)
	pityLabel = pillLabel("Pity", Color3.fromRGB(255, 214, 110), PackOpening.TOP + PackOpening.PILL_HEIGHT + 8, PackOpening.PILL_HEIGHT - 8)

	oddsButton = UIKit.button(gui, "Odds", UIKit.Colors.Row)
	oddsButton.Name = "OddsButton"
	oddsButton.AnchorPoint = Vector2.new(1, 0)
	oddsButton.Position = UDim2.new(1, -16, 0, PackOpening.TOP)
	oddsButton.Size = UDim2.fromOffset(124, PackOpening.PILL_HEIGHT)
	oddsButton.Font = Enum.Font.FredokaOne
	oddsButton.ZIndex = 10
	local oddsPad = oddsButton:FindFirstChildOfClass("UIPadding")
	if oddsPad then
		oddsPad.PaddingLeft = UDim.new(0, 30)
	end
	local oddsIcon = Icon.make(oddsButton, "Odds", UDim2.fromOffset(26, 26))
	oddsIcon.AnchorPoint = Vector2.new(0, 0.5)
	oddsIcon.Position = UDim2.new(0, -18, 0.5, 0)
	oddsIcon.ZIndex = 11
	oddsPanel = UIKit.label(gui, "", Enum.Font.Gotham, 16, UIKit.Colors.Text)
	oddsPanel.Name = "Odds"
	oddsPanel.AnchorPoint = Vector2.new(1, 0)
	oddsPanel.Position = UDim2.new(1, -16, 0, PackOpening.TOP + 56)
	oddsPanel.Size = UDim2.fromOffset(330, 230)
	oddsPanel.BackgroundTransparency = 0.05
	oddsPanel.BackgroundColor3 = UIKit.Colors.Panel
	oddsPanel.TextYAlignment = Enum.TextYAlignment.Top
	oddsPanel.ZIndex = 11
	oddsPanel.Visible = false
	UIKit.corner(oddsPanel, 10)
	local oddsPadding = Instance.new("UIPadding")
	oddsPadding.PaddingLeft = UDim.new(0, 12)
	oddsPadding.PaddingRight = UDim.new(0, 12)
	oddsPadding.PaddingTop = UDim.new(0, 10)
	oddsPadding.Parent = oddsPanel
	oddsButton.Activated:Connect(function()
		oddsPanel.Visible = not oddsPanel.Visible
	end)

	resultsBar = Instance.new("Frame")
	resultsBar.Name = "ResultsBar"
	resultsBar.AnchorPoint = Vector2.new(0.5, 0)
	resultsBar.Position = UDim2.new(0.5, 0, 0, PackOpening.TOP)
	resultsBar.Size = UDim2.new(1, -32, 0, PackOpening.PILL_HEIGHT)
	resultsBar.BackgroundTransparency = 1
	resultsBar.Visible = false
	resultsBar.ZIndex = 8
	resultsBar.Parent = gui
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 10)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = resultsBar
	addPill("YourCards", "Cards", "Your cards", UIKit.Colors.Row, UIKit.Colors.Text, 1)
	local _, newText = addPill("NewCount", "Star", "NEW x0", NEW_COLOR, UIKit.Colors.Ink, 2)
	newLabel = newText
	local _, value = addPill("Value", "Cash", "$0.00", UIKit.Colors.Row, Color3.fromRGB(110, 225, 140), 3)
	valueLabel = value
	local guide = addPill("RarityGuide", "Info", "Rarity guide", UIKit.Colors.Row, UIKit.Colors.Accent, 4)
	guide.AutoButtonColor = true
	guide.Activated:Connect(handlers.rarityGuide)

	continueButton = UIKit.button(gui, "Continue", UIKit.Colors.Success)
	continueButton.Name = "Continue"
	continueButton.AnchorPoint = Vector2.new(0.5, 1)
	continueButton.Position = UDim2.new(0.5, 0, 1, -PackOpening.EDGE - 8)
	continueButton.Size = UDim2.fromOffset(240, 54)
	continueButton.TextSize = 24
	continueButton.Font = Enum.Font.FredokaOne
	continueButton.ZIndex = 10
	continueButton.Visible = false
	continueScale = Instance.new("UIScale")
	continueScale.Parent = continueButton
	continueButton.Activated:Connect(handlers.continue)
end

-- The screen over a fresh opening: the hint, the box count, pity and odds
function OpeningResults.show(oddsText: string)
	oddsPanel.Text = oddsText
	oddsPanel.Visible = false
	oddsButton.Visible = true
	boxLabel.Visible = true
	pityLabel.Visible = pityLabel.Text ~= ""
	resultsBar.Visible = false
	continueButton.Visible = false
	gui.Enabled = true
end

function OpeningResults.hide()
	gui.Enabled = false
	oddsPanel.Visible = false
end

-- The hint capsule: at the top over the pack, at the bottom while cards are revealed (nil hides it)
function OpeningResults.hint(text: string?, bottom: boolean?)
	hintPill.Visible = text ~= nil
	hintLabel.Text = text or ""
	hintPill.AnchorPoint = Vector2.new(0.5, if bottom then 1 else 0)
	hintPill.Position = if bottom then UDim2.new(0.5, 0, 1, -PackOpening.EDGE) else UDim2.new(0.5, 0, 0, PackOpening.TOP)
end

function OpeningResults.box(text: string)
	boxLabel.Text = text
end

function OpeningResults.pity(text: string)
	pityLabel.Text = text
	pityLabel.Visible = gui.Enabled and text ~= "" and boxLabel.Visible
end

-- After the lineup lands: the corner pills go, the results pills pop in one after another, then Continue
function OpeningResults.results(newCount: number, value: number)
	boxLabel.Visible = false
	pityLabel.Visible = false
	oddsButton.Visible = false
	oddsPanel.Visible = false
	OpeningResults.hint(nil)
	newLabel.Text = `NEW x{newCount}`
	valueLabel.Text = string.format("$%.2f", value)
	resultsBar.Visible = true
	local seconds = PackOpening.RESULTS.PILL_SECONDS
	for index, pill in resultsBar:GetChildren() do
		local pop = pill:FindFirstChild("Pop")
		if pop and pop:IsA("UIScale") then
			pop.Scale = 0
			local info = TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, (index - 1) * 0.05)
			TweenService:Create(pop, info, { Scale = 1 }):Play()
		end
	end
	continueButton.Visible = true
	continueScale.Scale = 0
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, PackOpening.RESULTS.CONTINUE_DELAY)
	TweenService:Create(continueScale, info, { Scale = 1 }):Play()
end

function OpeningResults.gui(): ScreenGui
	return gui
end

return OpeningResults
