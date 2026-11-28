--!strict
-- Welcome-back earnings on screen (owner 2026-11-17; mockup pick A, the money card): once the loading screen, the
-- prologue and the welcome flight are done and no window or purchase dialog is up, it tells the server it's ready
-- (Remotes.WelcomeBack); if the shop sold anything while you were away a gold window says how long, what sold, the cash
-- and shop XP, and whether the shelves ran empty; Collect sends coins into the cash pill. OfflineService already paid
-- it (so nothing is lost if the window never shows).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Offline = require(Config:WaitForChild("Offline"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Products = require(Config:WaitForChild("Products"))
local UIStyle = require(Config:WaitForChild("UIStyle"))
local CardArtConfig = require(Config:WaitForChild("CardArt"))
local CardArt = require(Shared:WaitForChild("Util"):WaitForChild("CardArt"))
local OfflineRules = require(Shared:WaitForChild("Util"):WaitForChild("OfflineRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local CoinBurst = require(ClientUtil:WaitForChild("CoinBurst"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local OpeningStage = require(ClientUtil:WaitForChild("OpeningStage"))
local ProductPrice = require(ClientUtil:WaitForChild("ProductPrice"))
local RobuxPrice = require(ClientUtil:WaitForChild("RobuxPrice"))
local UIController = require(Controllers:WaitForChild("UIController"))
local WeaponRevealController = require(Controllers:WaitForChild("WeaponRevealController"))

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
	nightShift: { owned: boolean, sold: number, other: number }?, -- Night Shift's line (Robux round): away past the limit
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

-- The screen is free for the card (OfflineRules.cardFree): ready, no window, no dialog, nothing on the stage (a weapon
-- reveal or a mutation choice waiting after a join used to end up under it, bug 2026-11-27)
local function free(): boolean
	return OfflineRules.cardFree({
		ready = player:GetAttribute("LoadingDone") == true
			and player:GetAttribute("SeenPrologue") == true
			and player:GetAttribute("SeenWelcome") == true,
		panelOpen = UIKit.anyPanelOpen(),
		screenClear = ScreenClear.isClear(),
		stageShown = OpeningStage.isShown(),
		revealing = WeaponRevealController.IsPlaying(),
	})
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
	local words = UIKit.label(chip, OfflineRules.soldWords(count, productId, Offline), Enum.Font.FredokaOne, 17, UIStyle.CREAM.INK)
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

-- Night Shift's line (the game pass; Robux round, spec 2026-11-28-robux-round-design; Config/Offline NIGHT_SHIFT), only
-- when away past the normal limit: with it, an indigo chip saying how long it sold; without it, a quiet row with the
-- words and the pass's live price (shown once the pass is made). False when nothing was drawn
local function nightShiftRow(list: Instance, note: { owned: boolean, sold: number, other: number }, order: number, palette: any): boolean
	local words = Offline.NIGHT_SHIFT
	local passId = Monetization.PASSES.NightShift or 0
	if not note.owned and passId == 0 then
		return false
	end
	local text = string.format(if note.owned then words.owned else words.offer, OfflineRules.hoursText(note.sold), OfflineRules.hoursText(note.other))
	local row = Instance.new("Frame")
	row.Name = "NightShift"
	row.LayoutOrder = order
	row.Size = UDim2.new(1, -16, 0, if note.owned then 34 else 48)
	row.BackgroundColor3 = if note.owned then Color3.fromRGB(40, 48, 112) else palette.row
	row.Parent = list
	UIKit.corner(row, if note.owned then 17 else 14)
	local ink = if note.owned then Color3.new(1, 1, 1) else palette.ink
	local moon = UIKit.label(row, "🌙", Enum.Font.FredokaOne, 20, ink)
	moon.Position = UDim2.fromOffset(8, 0)
	moon.Size = UDim2.new(0, 26, 1, 0)
	moon.TextXAlignment = Enum.TextXAlignment.Center
	local label = UIKit.label(row, text, Enum.Font.GothamBold, 13, ink)
	label.Position = UDim2.fromOffset(38, 0)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	if note.owned then
		local fill = Instance.new("UIGradient")
		fill.Color = ColorSequence.new(Color3.fromRGB(40, 48, 112), Color3.fromRGB(88, 70, 170))
		fill.Parent = row
		label.Size = UDim2.new(1, -46, 1, 0)
		return true
	end
	UIKit.outline(row, palette.rowEdge, 2)
	label.Size = UDim2.new(1, -(38 + 100), 1, 0)
	local buy = UIKit.button(row, "Get it", UIKit.Colors.Accent)
	buy.Name = "GetNightShift"
	buy.AnchorPoint = Vector2.new(1, 0.5)
	buy.Position = UDim2.new(1, -6, 0.5, 0)
	buy.Size = UDim2.fromOffset(90, 38)
	ProductPrice.whenKnown(passId, true, function(price: number)
		if buy.Parent then
			RobuxPrice.set(buy, "", price)
		end
	end)
	buy.Activated:Connect(function()
		ScreenClear.prompt()
		MarketplaceService:PromptGamePassPurchase(player, passId)
	end)
	return true
end

local function show(summary: Summary)
	while not free() do -- one thing at a time: after the window, the dialog or the reveal that's up
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
	local night = summary.nightShift
	if night and nightShiftRow(list, night, 5, palette) and limit then
		limit.MaxSize += Vector2.new(0, if night.owned then 44 else 58) -- room for Night Shift's line
	end
	-- the hint: storage's when racks are in play (more racks, or a Restocker to run them), else the shelves'
	local hint = if summary.needsRestocker then string.format(REPORT.needs, MOST_HOURS)
		elseif summary.restocker then string.format(REPORT.more, MOST_HOURS)
		elseif summary.empty then "Your shelves are empty. Restock them!"
		else "Stock up before you leave and it keeps selling!"
	local tip = UIKit.label(list, hint, Enum.Font.GothamBold, 14, palette.hint)
	tip.LayoutOrder = 6
	tip.Size = UDim2.new(1, -16, 0, if summary.needsRestocker then 40 else 20)
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Center
	local collect = UIKit.button(list, "Collect", UIKit.Colors.Accent)
	collect.Name = "Collect"
	collect.LayoutOrder = 7
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
