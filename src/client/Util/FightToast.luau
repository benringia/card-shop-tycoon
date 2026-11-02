--!strict
-- A normal monster fight's end, small and quick (owner 2026-11-03: no big screen for normal monsters; Config/Victory
-- TOAST, words from Util/VictoryRules.toast): a dark pill slides down at the top with an edge in its colour, "Mossling
-- defeated" with cash and XP pills (a gold line for a card or shards), "Your party fainted" in red, "Got away safely"
-- in grey. Gone after a moment; a new one replaces it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Victory = require(Shared:WaitForChild("Config"):WaitForChild("Victory"))
local VictoryRules = require(Shared:WaitForChild("Util"):WaitForChild("VictoryRules"))
local Icon = require((script.Parent :: Instance):WaitForChild("Icon"))

local FightToast = {}

local SLIDE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.25)
local BACK = Color3.fromRGB(18, 14, 26)

local current: ScreenGui? = nil
local token = 0

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function label(parent: Instance, text: string, size: number, color: Color3, order: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.FredokaOne
	item.TextSize = size
	item.TextColor3 = color
	item.Text = text
	item.AutomaticSize = Enum.AutomaticSize.XY
	item.LayoutOrder = order
	item.Parent = parent
	return item
end

local function sound(id: string)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = Victory.VOLUME * 0.7
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
end

function FightToast.show(toast: VictoryRules.Toast)
	token += 1
	local mine = token
	if current then
		current:Destroy()
	end
	local cfg = Victory.TOAST
	local edgeColor = rgb(cfg.edge[toast.kind] or cfg.edge.run)
	local gui = Instance.new("ScreenGui")
	gui.Name = "FightToast"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	current = gui

	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, -80)
	pill.AutomaticSize = Enum.AutomaticSize.XY
	pill.BackgroundColor3 = BACK
	pill.BackgroundTransparency = 0.1
	pill.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Color = edgeColor
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = pill
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 10)
	row.Parent = pill

	-- The words: the title, and under it a smaller line (gold for a drop, grey for when your party is back)
	local words = Instance.new("Frame")
	words.BackgroundTransparency = 1
	words.AutomaticSize = Enum.AutomaticSize.XY
	words.LayoutOrder = 1
	words.Parent = pill
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = words
	label(words, toast.title, 18, Color3.new(1, 1, 1), 1)
	if toast.line then
		label(words, toast.line, 13, if toast.kind == "rare" then rgb(cfg.edge.rare) else Color3.fromRGB(201, 191, 224), 2)
	end
	for index, item in toast.pills do
		local chip = Instance.new("Frame")
		chip.AutomaticSize = Enum.AutomaticSize.XY
		chip.BackgroundColor3 = Color3.new(1, 1, 1)
		chip.BackgroundTransparency = 0.92
		chip.LayoutOrder = 1 + index
		chip.Parent = pill
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = chip
		local chipPad = Instance.new("UIPadding")
		chipPad.PaddingTop, chipPad.PaddingBottom = UDim.new(0, 3), UDim.new(0, 3)
		chipPad.PaddingLeft, chipPad.PaddingRight = UDim.new(0, 6), UDim.new(0, 9)
		chipPad.Parent = chip
		local chipRow = Instance.new("UIListLayout")
		chipRow.FillDirection = Enum.FillDirection.Horizontal
		chipRow.VerticalAlignment = Enum.VerticalAlignment.Center
		chipRow.SortOrder = Enum.SortOrder.LayoutOrder
		chipRow.Padding = UDim.new(0, 4)
		chipRow.Parent = chip
		local icon = Icon.make(chip, item.icon, UDim2.fromOffset(20, 20))
		icon.LayoutOrder = 1
		label(chip, item.text, 15, Color3.new(1, 1, 1), 2)
	end

	TweenService:Create(pill, SLIDE, { Position = UDim2.new(0.5, 0, 0, cfg.top) }):Play()
	sound(if toast.kind == "rare" then Victory.SOUNDS.rare elseif toast.kind == "win" then Victory.SOUNDS.tile else "")
	task.delay(cfg.seconds, function()
		if token ~= mine then
			return
		end
		TweenService:Create(pill, FADE, { Position = UDim2.new(0.5, 0, 0, -80), BackgroundTransparency = 1 }):Play()
		TweenService:Create(edge, FADE, { Transparency = 1 }):Play()
		task.delay(FADE.Time, function()
			if token == mine and current == gui then
				gui:Destroy()
				current = nil
			end
		end)
	end)
end

return FightToast
