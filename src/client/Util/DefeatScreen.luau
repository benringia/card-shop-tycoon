--!strict
-- The defeat screen for a lost boss fight (owner 2026-11-04, design A "Defeated card"; looks in Config/Defeat, words from
-- Util/DefeatRules): the world goes grey with a red edge and a soft sad sting plays; "DEFEATED" drops in, then a card
-- with the fight's numbers (your sword, each creature, the boss's HP left, rings dodged), a tip, and a countdown ring
-- of dots going out one by one until the server sends you to town. Tapping anywhere goes now (onSkip).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatHud = require(Shared:WaitForChild("Config"):WaitForChild("CombatHud"))
local Defeat = require(Shared:WaitForChild("Config"):WaitForChild("Defeat"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local DefeatScreen = {}

export type Row = { kind: string, label: string, value: string, cardId: string?, share: number? }
export type Show = {
	subtitle: string,
	rows: { Row },
	tip: string?,
	seconds: number, -- until town
	art: (cardId: string) -> string?, -- a creature row's portrait
	onSkip: (() -> ())?, -- tapping goes to town now (nil: no tap)
}

local DOTS = 24
local WHITE = Color3.new(1, 1, 1)

local current: { gui: ScreenGui, grey: ColorCorrectionEffect, music: Sound, ticker: RBXScriptConnection }? = nil

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function DefeatScreen.hide()
	local shown = current
	if not shown then
		return
	end
	current = nil
	shown.ticker:Disconnect()
	shown.gui:Destroy()
	TweenService:Create(shown.grey, TweenInfo.new(Defeat.GREY.fade), { Saturation = 0, Brightness = 0, TintColor = WHITE }):Play()
	Debris:AddItem(shown.grey, Defeat.GREY.fade + 0.1)
	TweenService:Create(shown.music, TweenInfo.new(Defeat.MUSIC_FADE), { Volume = 0 }):Play()
	Debris:AddItem(shown.music, Defeat.MUSIC_FADE + 0.1)
end

-- One row of the card: an icon or portrait, its label, (the boss's HP) a bar, and its number on the right
local function row(parent: Instance, entry: Row, order: number, art: (string) -> string?)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.new(1, 0, 0, 32)
	frame.Parent = parent
	local x = 0
	if entry.kind == "creature" and entry.cardId then
		local face = Instance.new("ImageLabel")
		face.BackgroundColor3 = Color3.fromRGB(42, 29, 51)
		face.Image = art(entry.cardId) or ""
		face.ScaleType = Enum.ScaleType.Crop
		face.AnchorPoint = Vector2.new(0, 0.5)
		face.Position = UDim2.new(0, 0, 0.5, 0)
		face.Size = UDim2.fromOffset(26, 26)
		face.Parent = frame
		UIKit.corner(face, 13)
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(255, 138, 58)
		edge.Thickness = 2
		edge.Parent = face
		x = 34
	elseif entry.kind == "sword" then
		local icon = UIKit.label(frame, "⚔️", Enum.Font.GothamBold, 18, WHITE)
		icon.Size = UDim2.new(0, 26, 1, 0)
		x = 32
	end
	local label = UIKit.label(frame, entry.label, Enum.Font.GothamBold, 15, WHITE)
	label.Position = UDim2.fromOffset(x, 0)
	label.Size = UDim2.new(0.55, -x, 1, 0)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if entry.kind == "hp" and entry.share then
		local track = Instance.new("Frame")
		track.BackgroundColor3 = Color3.fromRGB(42, 20, 20)
		track.BorderSizePixel = 0
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0.38, 0, 0.5, 0)
		track.Size = UDim2.new(0.36, 0, 0, 9)
		track.Parent = frame
		UIKit.corner(track, 5)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = Color3.fromRGB(255, 106, 80)
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(entry.share, 1)
		fill.Parent = track
		UIKit.corner(fill, 5)
	end
	local value = UIKit.label(frame, entry.value, Enum.Font.FredokaOne, 18, WHITE)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.Size = UDim2.new(0.3, 0, 1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
end

function DefeatScreen.show(data: Show)
	DefeatScreen.hide()
	local player = Players.LocalPlayer
	local phone = UIKit.isPhone()
	local gui = Instance.new("ScreenGui")
	gui.Name = "DefeatScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The world behind: grey and darker, a red edge
	local grey = Instance.new("ColorCorrectionEffect")
	grey.Name = "DefeatGrey"
	grey.Parent = Lighting
	local g = Defeat.GREY
	TweenService:Create(grey, TweenInfo.new(g.fade), { Saturation = g.saturation, Brightness = g.brightness, TintColor = color(g.tint) }):Play()
	local edge = Instance.new("ImageLabel")
	edge.BackgroundTransparency = 1
	edge.Image = CombatHud.HIT_FLASH.IMAGE
	edge.ImageColor3 = color(Defeat.EDGE_COLOR)
	edge.ImageTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.Parent = gui
	TweenService:Create(edge, TweenInfo.new(g.fade), { ImageTransparency = 1 - Defeat.EDGE_STRENGTH }):Play()

	-- Tap anywhere: town now
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.Parent = gui
	if data.onSkip then
		local skip = data.onSkip
		tap.Activated:Connect(function()
			skip()
			DefeatScreen.hide()
		end)
	end

	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0)
	column.Position = UDim2.fromScale(0.5, if phone then 0.06 else 0.15) -- clear of the top bar's Shop button
	column.Size = UDim2.new(0.9, 0, 0.9, 0)
	column.Parent = gui
	local width = Instance.new("UISizeConstraint")
	width.MaxSize = Vector2.new(460, math.huge)
	width.Parent = column
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, if phone then 6 else 10)
	list.Parent = column

	local title = UIKit.label(column, "DEFEATED", Enum.Font.FredokaOne, if phone then 44 else 64, color(Defeat.TITLE_COLOR))
	title.LayoutOrder = 1
	title.Size = UDim2.new(1, 0, 0, if phone then 48 else 70)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextStrokeColor3 = Color3.fromRGB(74, 0, 0)
	title.TextStrokeTransparency = 0
	local pop = Instance.new("UIScale")
	pop.Scale = 2.2
	pop.Parent = title
	TweenService:Create(pop, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local subtitle = UIKit.label(column, data.subtitle, Enum.Font.GothamBold, 15, Color3.fromRGB(241, 214, 214))
	subtitle.LayoutOrder = 2
	subtitle.Size = UDim2.new(1, 0, 0, 20)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	-- The card rises in a moment after the title
	local card = Instance.new("CanvasGroup")
	card.LayoutOrder = 3
	card.BackgroundColor3 = Color3.fromRGB(16, 10, 18)
	card.BackgroundTransparency = 0.12
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.GroupTransparency = 1
	card.Parent = column
	UIKit.corner(card, 14)
	local cardEdge = Instance.new("UIStroke")
	cardEdge.Color = color(Defeat.CARD_EDGE)
	cardEdge.Transparency = 0.5
	cardEdge.Thickness = 2
	cardEdge.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = card
	local rows = Instance.new("UIListLayout")
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	rows.Padding = UDim.new(0, 2)
	rows.Parent = card
	for index, entry in data.rows do
		row(card, entry, index, data.art)
	end
	task.delay(0.5, function()
		TweenService:Create(card, TweenInfo.new(0.45), { GroupTransparency = 0 }):Play()
	end)

	if data.tip then
		local tip = UIKit.label(column, `Tip: {data.tip}`, Enum.Font.GothamBold, 14, color(Defeat.TIP_COLOR))
		tip.LayoutOrder = 4
		tip.Size = UDim2.new(1, 0, 0, 34)
		tip.TextXAlignment = Enum.TextXAlignment.Center
	end

	-- The countdown: a ring of dots going out one by one around the seconds left, "Back to town" beside it
	local footer = Instance.new("Frame")
	footer.LayoutOrder = 5
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, 0, 0, 50)
	footer.Parent = column
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(0.5, -62, 0.5, 0)
	ring.Size = UDim2.fromOffset(44, 44)
	ring.Parent = footer
	local dots: { Frame } = {}
	for index = 1, DOTS do
		local angle = (index - 1) / DOTS * math.pi * 2 - math.pi / 2
		local dot = Instance.new("Frame")
		dot.BackgroundColor3 = Color3.fromRGB(255, 90, 74)
		dot.BorderSizePixel = 0
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.new(0.5, math.cos(angle) * 19, 0.5, math.sin(angle) * 19)
		dot.Size = UDim2.fromOffset(4, 4)
		dot.Parent = ring
		UIKit.corner(dot, 2)
		table.insert(dots, dot)
	end
	local number = UIKit.label(ring, "", Enum.Font.FredokaOne, 16, WHITE)
	number.Size = UDim2.fromScale(1, 1)
	number.TextXAlignment = Enum.TextXAlignment.Center
	local back = UIKit.label(footer, if data.onSkip then "Back to town · tap to go now" else "Back to town", Enum.Font.FredokaOne, 16, WHITE)
	back.AnchorPoint = Vector2.new(0, 0.5)
	back.Position = UDim2.new(0.5, -32, 0.5, 0)
	back.Size = UDim2.new(0.6, 0, 1, 0)
	back.TextWrapped = false

	local music = Instance.new("Sound")
	music.SoundId = Defeat.MUSIC
	music.Volume = Defeat.MUSIC_VOLUME
	music.Parent = SoundService
	music:Play()

	local started = os.clock()
	local ticker = RunService.RenderStepped:Connect(function()
		local left = data.seconds - (os.clock() - started)
		number.Text = tostring(math.max(0, math.ceil(left)))
		local share = math.clamp(left / data.seconds, 0, 1)
		for index, dot in dots do
			dot.BackgroundTransparency = if (index - 1) / DOTS < share then 0 else 0.85
		end
		if left < -1.5 then
			DefeatScreen.hide() -- the server has moved you by now
		end
	end)
	current = { gui = gui, grey = grey, music = music, ticker = ticker }
end

return DefeatScreen
