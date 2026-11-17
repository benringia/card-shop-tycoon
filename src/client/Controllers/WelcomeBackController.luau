--!strict
-- Welcome-back earnings on screen (owner 2026-11-17; mockup pick A, the money card): once the loading screen, the
-- prologue and the welcome flight are done and no window or purchase dialog is up, it tells the server it's ready
-- (Remotes.WelcomeBack); if the shop sold anything while you were away a gold window says how long, what sold, the cash
-- and shop XP, and whether the shelves ran empty; Collect sends coins into the cash pill. OfflineService already paid
-- it (so nothing is lost if the window never shows).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Offline = require(Config:WaitForChild("Offline"))
local Products = require(Config:WaitForChild("Products"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local UIController = require(Controllers:WaitForChild("UIController"))

local WelcomeBackController = {}

type Summary = { minutes: number, units: number, cash: number, xp: number, sold: { [string]: number }, empty: boolean }

local player = Players.LocalPlayer
local READY_CHECK = 0.5 -- seconds between checks that the screen is free
local GIVE_UP = 180 -- seconds: ask anyway (the server paid it already; this only shows it)

local function awayText(minutes: number): string
	local hours, rest = minutes // 60, minutes % 60
	if hours <= 0 then
		return `{rest}m`
	end
	return if rest > 0 then `{hours}h {rest}m` else `{hours}h`
end

local function free(): boolean
	return player:GetAttribute("LoadingDone") == true
		and player:GetAttribute("SeenPrologue") == true
		and player:GetAttribute("SeenWelcome") == true
		and not UIKit.anyPanelOpen()
		and ScreenClear.isClear()
end

-- One "18 packs" chip: the product's picture and its count
local function soldChip(parent: Instance, productId: string, count: number, order: number)
	local product = Products.ById[productId]
	local chip = Instance.new("Frame")
	chip.LayoutOrder = order
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 40)
	chip.BackgroundColor3 = UIStyle.CREAM.ROW
	chip.Parent = parent
	UIKit.corner(chip, 10)
	UIKit.outline(chip, UIStyle.CREAM.ROW_EDGE, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = chip
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 6)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = chip
	local picture = Icon.make(chip, if product then product.icon else "Box", UDim2.fromOffset(30, 30))
	picture.LayoutOrder = 1
	local words = UIKit.label(chip, `{count} {Offline.PLURALS[productId] or "items"}`, Enum.Font.FredokaOne, 17, UIStyle.CREAM.INK)
	words.LayoutOrder = 2
	words.AutomaticSize = Enum.AutomaticSize.X
	words.Size = UDim2.fromOffset(0, 30)
	words.TextWrapped = false
end

local function show(summary: Summary)
	while UIKit.anyPanelOpen() do -- one window at a time: after the one that's up
		task.wait(READY_CHECK)
	end
	local screen = UIController.GetScreenGui()
	local panel, list = UIKit.panel(screen, "WelcomeBack", "Welcome back!", "Quests")
	Icon.header(panel, "Cash", UIKit.HEADER_HEIGHT)
	local limit = panel:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(460, 340)
	end
	local palette = UIKit.colorsFor(panel)
	local layout = list:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Padding = UDim.new(0, 10)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	end
	local away = UIKit.label(list, `While you were away ({awayText(summary.minutes)}) your shop sold:`, Enum.Font.GothamBold, 15, palette.inkSoft)
	away.LayoutOrder = 1
	away.Size = UDim2.new(1, -16, 0, 22)
	away.TextXAlignment = Enum.TextXAlignment.Center
	local chips = Instance.new("Frame")
	chips.LayoutOrder = 2
	chips.BackgroundTransparency = 1
	chips.AutomaticSize = Enum.AutomaticSize.Y
	chips.Size = UDim2.new(1, -16, 0, 0)
	chips.Parent = list
	local flow = Instance.new("UIListLayout")
	flow.FillDirection = Enum.FillDirection.Horizontal
	flow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	flow.Wraps = true
	flow.Padding = UDim.new(0, 8)
	flow.SortOrder = Enum.SortOrder.LayoutOrder
	flow.Parent = chips
	local order = 0
	for _, product in Products.List do
		local count = summary.sold[product.id]
		if count and count > 0 then
			order += 1
			soldChip(chips, product.id, count, order)
		end
	end
	local earned = UIKit.label(list, string.format("+$%.2f  ·  +%d shop XP", summary.cash, summary.xp), Enum.Font.FredokaOne, 26, UIStyle.CREAM.GOOD)
	earned.LayoutOrder = 3
	earned.Size = UDim2.new(1, -16, 0, 34)
	earned.TextXAlignment = Enum.TextXAlignment.Center
	local tip = UIKit.label(list, if summary.empty then "Your shelves are empty. Restock them!" else "Stock up before you leave and it keeps selling!", Enum.Font.GothamBold, 14, palette.hint)
	tip.LayoutOrder = 4
	tip.Size = UDim2.new(1, -16, 0, 20)
	tip.TextXAlignment = Enum.TextXAlignment.Center
	local collect = UIKit.button(list, "Collect", UIKit.Colors.Accent)
	collect.Name = "Collect"
	collect.LayoutOrder = 5
	collect.Size = UDim2.fromOffset(180, 52)
	collect.Activated:Connect(function()
		CoinBurst.fly(screen, collect.AbsolutePosition + collect.AbsoluteSize / 2, UIController.GetCashPill(), 8)
		panel.Visible = false
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then
			task.delay(1, panel.Destroy, panel)
		end
	end)
	panel.Visible = true
end

function WelcomeBackController.Start()
	Remotes.WelcomeBack.OnClientEvent:Connect(function(summary: unknown)
		if typeof(summary) == "table" and typeof((summary :: any).cash) == "number" then
			task.spawn(show, summary :: Summary)
		end
	end)
	-- Ready once the screen is free (or after a long wait anyway): the server sends what sold, if anything did
	task.spawn(function()
		local waited = 0
		while not free() and waited < GIVE_UP do
			task.wait(READY_CHECK)
			waited += READY_CHECK
		end
		Remotes.WelcomeBack:FireServer()
	end)
end

return WelcomeBackController
