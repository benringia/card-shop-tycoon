--!strict
-- Daily, weekly and monthly gifts (spec 2026-11-15-daily-gifts-design, Config/Gifts, Util/GiftRules; main game): the
-- Gift tile on the HUD's side (Pish's present, the play time left counting down, a red "!" once something's ready;
-- shown once the first visit is done), the Daily Gifts window (layout A, owner 2026-11-15: the 7 days in a row, today's
-- glowing, the big gift on day 7, then the Weekly and Monthly Chests' bars) and the win moments (Util/GiftWin) as the
-- server hands gifts out. A chest a daily gift earned is claimed right after its win moment; a pack picked with OPEN IT
-- NOW! opens once the last one is closed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Gifts = require(Config:WaitForChild("Gifts"))
local Items = require(Config:WaitForChild("Items"))
local Luck = require(Config:WaitForChild("Luck"))
local GiftRules = require(Shared:WaitForChild("Util"):WaitForChild("GiftRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local GiftMotion = require(ClientUtil:WaitForChild("GiftMotion"))
local GiftWin = require(ClientUtil:WaitForChild("GiftWin"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local GiftController = {}

local GOLD = Color3.fromRGB(255, 200, 50)
local PURPLE = Color3.fromRGB(150, 100, 255)
local AMBER = Color3.fromRGB(255, 160, 30)
local TILE_HEIGHT = 158
local MOTION = Gifts.MOTION

type Win = { kind: string, index: number, lines: { GiftRules.Line }, earned: GiftRules.Earned }

local view: GiftRules.View? = nil
local counting = false
local leftAt = 0 -- os.clock when view.secondsLeft was true
local tile: TextButton? = nil
local badge: TextLabel? = nil
local panel: Frame? = nil
local content: Frame? = nil
local status: TextLabel? = nil
local queue: { Win } = {}
local playing = false
local toOpen: string? = nil

local function clock(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", left // 60, left % 60)
end

-- Time until the next UTC day, when the next daily gift starts counting: "5h 12m", "42m"
local function nextGiftIn(): string
	local left = 86400 - (workspace:GetServerTimeNow() % 86400)
	local hours, minutes = math.floor(left / 3600), math.max(math.ceil((left % 3600) / 60), 1)
	if minutes == 60 then
		hours, minutes = hours + 1, 0
	end
	return if hours > 0 then `{hours}h {minutes}m` else `{minutes}m`
end

-- Play time left now (the server's number counted down here while play time counts)
local function secondsLeft(): number
	if not view then
		return 0
	end
	if not counting then
		return view.secondsLeft
	end
	return math.max(view.secondsLeft - (os.clock() - leftAt), 0)
end

-- The server says when it's ready (its count, every Gifts.TICK); the countdown here only shows the time
local function readyNow(): boolean
	return view ~= nil and view.ready
end

local function anythingReady(): boolean
	return view ~= nil and (readyNow() or view.weekEarned or view.monthEarned)
end

local function refreshTile()
	local button = tile
	if not button or not view then
		return
	end
	button.Visible = counting or anythingReady()
	local text = if anythingReady() then Gifts.TILE.ready elseif view.claimedToday then nextGiftIn() else clock(secondsLeft())
	Hud.setLabel("Gift", text)
	if badge then
		badge.Visible = anythingReady()
	end
end

local function claim(kind: string)
	Remotes.GiftClaim:FireServer(kind)
end

-- One day's tile: done ones ticked, today's glowing (CLAIM! or its time), day 7 golden
local function dayTile(row: Frame, index: number, today: GiftRules.View, entrance: boolean)
	local palette = UIKit.colorsFor(row)
	local reward = Gifts.DAILY[index]
	local lines = GiftRules.lines(reward, Items, Luck)
	local big = index == #Gifts.DAILY
	local done = index < today.day or (index == today.day and today.claimedToday)
	local isToday = index == today.day and not today.claimedToday
	local box = Instance.new("Frame")
	box.Name = `Day{index}`
	box.LayoutOrder = index
	box.Size = UDim2.new(if big then 0.19 else 0.118, 0, 0, TILE_HEIGHT)
	box.BackgroundColor3 = if big then Color3.fromRGB(255, 226, 130) else palette.row
	box.Parent = row
	UIKit.corner(box, 14)
	UIKit.outline(box, if isToday or big then GOLD else palette.rowEdge, if isToday then 4 else 3)
	if big then
		local shine = Instance.new("UIGradient")
		shine.Rotation = 90
		shine.Color = ColorSequence.new(Color3.fromRGB(255, 246, 205), Color3.fromRGB(255, 205, 90))
		shine.Parent = box
	end
	if isToday then
		UIKit.glow(box, GOLD, 14, 0, 0.15)
	end
	local name = UIKit.label(box, if big then "Day 7 BIG GIFT" else `Day {index}`, Enum.Font.FredokaOne, 14, palette.hint)
	name.Position = UDim2.fromOffset(4, 4)
	name.Size = UDim2.new(1, -8, 0, 18)
	name.TextXAlignment = Enum.TextXAlignment.Center
	local picture = Icon.make(box, lines[#lines > 1 and lines[1].icon == "Cash" and 2 or 1].icon, UDim2.fromOffset(56, 56))
	picture.AnchorPoint = Vector2.new(0.5, 0)
	picture.Position = UDim2.new(0.5, 0, 0, 24)
	local words = {}
	for _, line in lines do
		table.insert(words, line.text)
	end
	local about = UIKit.label(box, table.concat(words, " + "), Enum.Font.FredokaOne, 13, palette.ink)
	about.Position = UDim2.fromOffset(4, 82)
	about.Size = UDim2.new(1, -8, 0, 38)
	about.TextWrapped = true
	about.TextXAlignment = Enum.TextXAlignment.Center
	about.TextYAlignment = Enum.TextYAlignment.Top
	if done then
		for _, item in box:GetDescendants() do
			if item:IsA("TextLabel") then
				item.TextTransparency = 0.5
			elseif item:IsA("ImageLabel") and item.Name == "Glyph" then
				item.ImageTransparency = 0.5
			end
		end
		local tick = Icon.make(box, "Check", UDim2.fromOffset(50, 50))
		tick.Name = "Done"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, 0, 0, 52)
		tick.ZIndex = box.ZIndex + 3
		local glyph = tick:FindFirstChild("Glyph")
		if glyph and glyph:IsA("GuiObject") then
			glyph.ZIndex = tick.ZIndex
		end
		if entrance then
			GiftMotion.popIn(tick, index * MOTION.pop.every + 0.25)
		end
	elseif isToday then
		local ready = readyNow()
		local action = UIKit.button(box, if ready then "CLAIM!" else clock(secondsLeft()), if ready then UIKit.Colors.Success else UIKit.Colors.Secondary)
		action.Name = "Claim"
		action.AnchorPoint = Vector2.new(0.5, 1)
		action.Position = UDim2.new(0.5, 0, 1, -6)
		action.Size = UDim2.new(1, -8, 0, 48)
		action.Activated:Connect(function()
			if readyNow() then
				claim("daily")
			end
		end)
		-- something's inside: it bobs while it waits, rattles once it's ready; sparkles twinkle round it
		if ready then
			GiftMotion.rattle(picture, MOTION.rattle.every)
		else
			GiftMotion.bob(picture, MOTION.bobPx)
		end
		GiftMotion.sparkles(box, picture, MOTION.sparkle.today)
	end
	if big then
		GiftMotion.shine(box, 14, MOTION.shine.every)
		GiftMotion.rock(picture, MOTION.rockAngle)
		if not isToday then
			GiftMotion.sparkles(box, picture, MOTION.sparkle.big) -- today's already twinkle
		end
	end
	local function breathe()
		if isToday then
			GiftMotion.breathe(box, 1.05)
		end
	end
	if entrance then
		GiftMotion.popIn(box, index * MOTION.pop.every, breathe)
	else
		breathe()
	end
end

-- A chest's row: its picture, name, days, the bar, what's inside, and OPEN! once earned
local function chestRow(parent: Frame, order: number, kind: string, title: string, days: number, target: number, earned: boolean, fill: Color3, reward: GiftRules.Reward, note: string, entrance: boolean)
	local palette = UIKit.colorsFor(parent)
	local lines = GiftRules.lines(reward, Items, Luck)
	local row = Instance.new("Frame")
	row.Name = title
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, 86)
	row.BackgroundColor3 = palette.row
	row.Parent = parent
	UIKit.corner(row, 16)
	UIKit.outline(row, if earned then GOLD else palette.rowEdge, 3)
	local picture = Icon.make(row, lines[#lines > 1 and lines[1].icon == "Cash" and 2 or 1].icon, UDim2.fromOffset(64, 64))
	picture.Position = UDim2.fromOffset(12, 14)
	local right = if earned then 140 elseif days >= target then 64 else 16
	local name = UIKit.label(row, title, Enum.Font.FredokaOne, 20, palette.ink)
	name.Position = UDim2.fromOffset(88, 8)
	name.Size = UDim2.new(1, -(88 + right + 110), 0, 26)
	local count = UIKit.label(row, `{math.min(days, target)} / {target} days`, Enum.Font.FredokaOne, 18, palette.ink)
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -right, 0, 8)
	count.Size = UDim2.fromOffset(110, 26)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local share = if earned then 1 else days / math.max(target, 1)
	local track, inner = UIKit.bar(row, share, fill)
	track.Position = UDim2.fromOffset(88, 38)
	track.Size = UDim2.new(1, -(88 + right), 0, 16)
	if entrance then
		GiftMotion.fill(inner, share, 0.35 + order * 0.15)
	end
	if share > 0 then
		GiftMotion.shine(inner, 999, MOTION.shine.every + order * 0.4)
	end
	local words = {}
	for _, line in lines do
		table.insert(words, line.text)
	end
	local inside = UIKit.label(row, `Inside: {table.concat(words, " · ")} · {note}`, Enum.Font.GothamBold, 13, palette.inkSoft)
	inside.Position = UDim2.fromOffset(88, 60)
	inside.Size = UDim2.new(1, -(88 + right), 0, 26)
	inside.TextWrapped = true
	if earned then
		local open = UIKit.button(row, "OPEN!", UIKit.Colors.Success)
		open.Name = "Open"
		open.AnchorPoint = Vector2.new(1, 0.5)
		open.Position = UDim2.new(1, -12, 0.5, 0)
		open.Size = UDim2.fromOffset(116, 52)
		open.Activated:Connect(function()
			claim(kind)
		end)
		GiftMotion.rattle(picture, MOTION.rattle.every)
		GiftMotion.sparkles(row, picture, MOTION.sparkle.chest)
		GiftMotion.breathe(open, 1.06)
	elseif days >= target then
		-- already opened this week or month: a tick where its OPEN! was
		local tick = Icon.make(row, "Check", UDim2.fromOffset(40, 40))
		tick.Name = "Opened"
		tick.AnchorPoint = Vector2.new(1, 0.5)
		tick.Position = UDim2.new(1, -14, 0.5, 0)
	end
	if entrance then
		GiftMotion.popIn(row, 0.45 + order * 0.08)
	end
end

local function statusText(): string
	if not view then
		return ""
	end
	if not counting and not view.claimedToday then
		return "Finish your first visit with Pish to start getting gifts."
	end
	if view.claimedToday then
		return `You opened today's gift! The next one comes in {nextGiftIn()}.`
	end
	if readyNow() then
		return "Your gift is ready! Tap CLAIM!"
	end
	return `Play {clock(secondsLeft())} more for today's gift.`
end

-- `entrance`: the window just opened (its tiles pop in, its bars fill up)
local function fillWindow(entrance: boolean)
	local holder = content
	local today = view
	if not holder or not today then
		return
	end
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if status then
		status.Text = statusText()
	end
	local days = Instance.new("Frame")
	days.Name = "Days"
	days.LayoutOrder = 1
	days.BackgroundTransparency = 1
	days.Size = UDim2.new(1, 0, 0, TILE_HEIGHT + 12)
	days.Parent = holder
	local dayLayout = Instance.new("UIListLayout")
	dayLayout.FillDirection = Enum.FillDirection.Horizontal
	dayLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dayLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dayLayout.Padding = UDim.new(0.01, 0)
	dayLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dayLayout.Parent = days
	for index = 1, #Gifts.DAILY do
		dayTile(days, index, today, entrance)
	end
	chestRow(holder, 2, "weekly", "Weekly Chest", today.weekDays, today.weekTarget, today.weekEarned, PURPLE, Gifts.WEEKLY.reward, "new week Monday", entrance)
	chestRow(holder, 3, "monthly", "Monthly Chest", today.monthDays, today.monthTarget, today.monthEarned, AMBER, Gifts.MONTHLY.reward, "new month on the 1st", entrance)
end

local function buildWindow()
	local made, list = UIKit.panel(UIController.GetScreenGui(), "Gifts", "Daily Gifts", "Bag")
	panel = made
	made.Size = UDim2.fromScale(0.96, 0.94)
	local limit = made:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(820, 500)
	end
	Icon.header(made, Gifts.TILE.icon, UIKit.HEADER_HEIGHT)
	local palette = UIKit.colorsFor(made)
	local line = UIKit.label(list, "", Enum.Font.GothamBold, 15, palette.inkSoft)
	line.LayoutOrder = 0
	line.Size = UDim2.new(1, 0, 0, 22)
	line.TextXAlignment = Enum.TextXAlignment.Center
	status = line
	local holder = Instance.new("Frame")
	holder.Name = "Content"
	holder.LayoutOrder = 1
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.Parent = list
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 6)
	inset.PaddingRight = UDim.new(0, 6)
	inset.PaddingTop = UDim.new(0, 6)
	inset.PaddingBottom = UDim.new(0, 6)
	inset.Parent = holder
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	content = holder
end

local function toggle()
	if not panel then
		buildWindow()
	end
	local window = panel :: Frame
	if window.Visible then
		UIKit.closePanel(window)
		return
	end
	Remotes.GiftState:FireServer() -- fresh numbers as it opens
	window.Visible = true
	fillWindow(true)
end

-- The win moments, one at a time; the chests a daily gift earned are claimed after it, one per win moment (the
-- server takes one claim a second), and a pack picked opens at the end
local function runQueue()
	if playing then
		return
	end
	playing = true
	local chests: { string } = {}
	while #queue > 0 do
		local win = table.remove(queue, 1) :: Win
		if panel and panel.Visible then
			UIKit.closePanel(panel)
		end
		local pack = GiftWin.play(win.kind, win.index, win.lines)
		if pack and not toOpen then
			toOpen = pack
		end
		if win.earned.week then
			table.insert(chests, "weekly")
		end
		if win.earned.month then
			table.insert(chests, "monthly")
		end
		if #queue == 0 and #chests > 0 then
			claim(table.remove(chests, 1) :: string)
			local waited = 0
			while #queue == 0 and waited < 3 do
				waited += task.wait(0.1)
			end
		end
	end
	playing = false
	local pack = toOpen
	toOpen = nil
	if pack then
		Remotes.OpenBagPack:FireServer(pack)
	end
end

-- The HUD tile's present gives a little rattle (something's ready inside)
local function wiggleTile()
	local body = tile and tile:FindFirstChild("Body")
	if not body then
		return
	end
	task.spawn(function()
		for _, side in MOTION.rattle.angles do
			for _, name in { "Icon", "IconShadow" } do
				local picture = body:FindFirstChild(name)
				if picture and picture:IsA("GuiObject") then
					TweenService:Create(picture, TweenInfo.new(0.06, Enum.EasingStyle.Sine), { Rotation = side }):Play()
				end
			end
			task.wait(0.06)
		end
	end)
end

local function makeTile()
	local made = Hud.tile({
		id = "Gift",
		icon = Gifts.TILE.icon,
		label = Gifts.TILE.label,
		group = "Side",
		order = Gifts.TILE.order,
		phoneBottom = Gifts.TILE.phoneBottom,
		onClick = toggle,
	})
	made.Visible = false
	tile = made
	local mark = Instance.new("TextLabel")
	mark.Name = "Ready"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.new(1, -6, 0, 6)
	mark.Size = UDim2.fromOffset(26, 26)
	mark.BackgroundColor3 = Color3.fromRGB(255, 59, 92)
	mark.Font = Enum.Font.FredokaOne
	mark.Text = "!"
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.TextSize = 18
	mark.ZIndex = 20
	mark.Visible = false
	mark.Parent = made
	UIKit.corner(mark, 13)
	UIKit.outline(mark, Color3.new(1, 1, 1), 2)
	local pulse = Instance.new("UIScale")
	pulse.Parent = mark
	TweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.25 }):Play()
	badge = mark
end

function GiftController.Start()
	makeTile()
	Remotes.GiftState.OnClientEvent:Connect(function(next: any, isCounting: any)
		if typeof(next) ~= "table" then
			return
		end
		local wasReady = anythingReady()
		view = next :: GiftRules.View
		counting = isCounting == true
		leftAt = os.clock()
		refreshTile()
		if panel and panel.Visible then
			fillWindow(false)
		end
		if anythingReady() and not wasReady and not playing then
			UIController.Notify("Your gift is ready! Tap Gift to open it.", false)
		end
	end)
	Remotes.GiftClaim.OnClientEvent:Connect(function(kind: any, index: any, lines: any, earned: any)
		if typeof(kind) ~= "string" or typeof(lines) ~= "table" then
			return
		end
		table.insert(queue, {
			kind = kind,
			index = if typeof(index) == "number" then index else 1,
			lines = lines,
			earned = if typeof(earned) == "table" then earned else { week = false, month = false },
		})
		task.spawn(runQueue)
	end)
	-- the tile's and the window's countdown, every second; the moment it hits zero it shows ready
	task.spawn(function()
		local wasReady = false
		local sinceWiggle = 0
		while true do
			task.wait(1)
			if not view then
				continue
			end
			refreshTile()
			sinceWiggle += 1
			if anythingReady() and sinceWiggle >= MOTION.tileWiggle then
				sinceWiggle = 0
				wiggleTile()
			end
			local ready = readyNow()
			if panel and panel.Visible then
				if ready ~= wasReady then
					fillWindow(false)
				else
					local claimButton = panel:FindFirstChild("Claim", true)
					if claimButton and claimButton:IsA("TextButton") and not ready then
						claimButton.Text = clock(secondsLeft())
					end
					if status then
						status.Text = statusText()
					end
				end
			end
			wasReady = ready
		end
	end)
	Remotes.GiftState:FireServer()
end

return GiftController
