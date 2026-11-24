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
local CardArtConfig = require(Config:WaitForChild("CardArt"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local UIController = require(Controllers:WaitForChild("UIController"))

local WelcomeBackController = {}

-- restocker / boxes / base / extra / needsRestocker: away selling with storage racks (OfflineService; spec
-- 2026-11-24-shop-variety-design)
type Summary = {
	minutes: number,
	units: number,
	cash: number,
	xp: number,
	sold: { [string]: number },
	empty: boolean,
	restocker: { name: string, cardId: string }?,
	boxes: number?,
	base: number?,
	extra: number?,
	needsRestocker: boolean?,
}

local REPORT = Offline.REPORT
local MOST_HOURS = (Offline.MAX_MINUTES + Offline.MAX_EXTRA_MINUTES) // 60

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

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The Restocker's report (mockup pick 2): its card's picture, what it carried out of the racks, and a bar of the time
-- selling (blue: from the shelves, green: from storage) with both times under it
local function restockerReport(parent: Instance, summary: Summary, order: number)
	local restocker = summary.restocker :: { name: string, cardId: string }
	local base, extra, boxes = summary.base or summary.minutes, summary.extra or 0, summary.boxes or 0
	local panel = Instance.new("Frame")
	panel.Name = "Restocker"
	panel.LayoutOrder = order
	panel.Size = UDim2.new(1, -16, 0, REPORT.height)
	panel.BackgroundColor3 = UIStyle.CREAM.ROW
	panel.Parent = parent
	UIKit.corner(panel, 16)
	UIKit.outline(panel, UIStyle.CREAM.ROW_EDGE, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = panel

	local size = REPORT.portrait
	local portrait = Instance.new("ImageLabel")
	portrait.Name = "Portrait"
	portrait.Size = UDim2.fromOffset(size, size)
	portrait.BackgroundColor3 = UIStyle.CREAM.ROW_EDGE
	portrait.Image = CardArt.pick(restocker.name, size, CardArtConfig) or ""
	portrait.ScaleType = Enum.ScaleType.Crop
	portrait.Parent = panel
	UIKit.corner(portrait, size)
	UIKit.outline(portrait, rgb(REPORT.ring), 3)

	local title = UIKit.label(panel, string.format(REPORT.title, restocker.name), Enum.Font.FredokaOne, 16, UIStyle.CREAM.INK)
	title.Position = UDim2.fromOffset(size + 12, 6)
	title.Size = UDim2.new(1, -(size + 12), 0, 20)
	title.TextWrapped = false
	local boxLine = UIKit.label(panel, if boxes == 1 then REPORT.box else string.format(REPORT.boxes, boxes), Enum.Font.GothamBold, 13, UIStyle.CREAM.INK_SOFT)
	boxLine.Position = UDim2.fromOffset(size + 12, 28)
	boxLine.Size = UDim2.new(1, -(size + 12), 0, 16)

	-- the bar: shelves' share, then storage's
	local total = math.max(1, base + extra)
	local track = Instance.new("Frame")
	track.Name = "Time"
	track.Position = UDim2.fromOffset(0, size + 6)
	track.Size = UDim2.new(1, 0, 0, REPORT.bar)
	track.BackgroundColor3 = rgb(REPORT.track)
	track.ClipsDescendants = true
	track.Parent = panel
	UIKit.corner(track, REPORT.bar)
	local shelves = Instance.new("Frame")
	shelves.Size = UDim2.fromScale(base / total, 1)
	shelves.BackgroundColor3 = rgb(REPORT.shelvesColor)
	shelves.BorderSizePixel = 0
	shelves.Parent = track
	local storage = Instance.new("Frame")
	storage.Position = UDim2.fromScale(base / total, 0)
	storage.Size = UDim2.fromScale(extra / total, 1)
	storage.BackgroundColor3 = rgb(REPORT.storageColor)
	storage.BorderSizePixel = 0
	storage.Parent = track
	local legendY = size + 6 + REPORT.bar + 3
	local fromShelves = UIKit.label(panel, string.format(REPORT.shelves, awayText(base)), Enum.Font.GothamBold, 12, rgb(REPORT.shelvesInk))
	fromShelves.Position = UDim2.fromOffset(0, legendY)
	fromShelves.Size = UDim2.new(0.5, 0, 0, 14)
	local fromStorage = UIKit.label(panel, string.format(REPORT.storage, awayText(extra)), Enum.Font.GothamBold, 12, rgb(REPORT.storageInk))
	fromStorage.AnchorPoint = Vector2.new(1, 0)
	fromStorage.Position = UDim2.new(1, 0, 0, legendY)
	fromStorage.Size = UDim2.new(0.5, 0, 0, 14)
	fromStorage.TextXAlignment = Enum.TextXAlignment.Right
	fromStorage.Visible = extra > 0
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
		-- taller with the Restocker's report, a little with the two-line racks hint
		limit.MaxSize = Vector2.new(460, if summary.restocker then 340 + REPORT.height + 22 elseif summary.needsRestocker then 362 else 340)
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
	if summary.restocker then
		restockerReport(list, summary, 4)
	end
	-- the hint: storage's when racks are in play (more racks, or a Restocker to run them), else the shelves'
	local hint = if summary.needsRestocker then string.format(REPORT.needs, MOST_HOURS)
		elseif summary.restocker then string.format(REPORT.more, MOST_HOURS)
		elseif summary.empty then "Your shelves are empty. Restock them!"
		else "Stock up before you leave and it keeps selling!"
	local tip = UIKit.label(list, hint, Enum.Font.GothamBold, 14, palette.hint)
	tip.LayoutOrder = 5
	tip.Size = UDim2.new(1, -16, 0, if summary.needsRestocker then 40 else 20)
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Center
	local collect = UIKit.button(list, "Collect", UIKit.Colors.Accent)
	collect.Name = "Collect"
	collect.LayoutOrder = 6
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
