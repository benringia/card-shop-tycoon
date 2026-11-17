--!strict
-- Open 10 (owner 2026-11-17, "do all"; ItemRules.openMany, Levels.OPEN_MANY): a stack of Bag packs opened at once. The
-- server rolls every pack (PackService.OpenItemPacks) and sends their cards in order (Remotes.PacksOpened); this lays
-- them out face down in a grid over a dim screen and turns them over quickly, pausing on Rare and better (an Epic or a
-- Legendary flashes the screen and gets the chat shout-out). Very Rare and up light up as they turn (a halo, a turning
-- rim, a shine, their rarity's tag; CardReveal.BEST) and the rest dims once all are turned. A tap turns the rest over
-- at once. Then the totals (cards, NEW, worth), Continue and Open 10 more while the stack lasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local Items = require(Config:WaitForChild("Items"))
local Levels = require(Config:WaitForChild("Levels"))
local CardReveal = require(Config:WaitForChild("CardReveal"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local PackFx = require(Config:WaitForChild("PackFx"))
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local CardRules = require(Shared:WaitForChild("Util"):WaitForChild("CardRules"))
local ItemRules = require(Shared:WaitForChild("Util"):WaitForChild("ItemRules"))
local RevealRules = require(Shared:WaitForChild("Util"):WaitForChild("RevealRules"))
local OpeningLayout = require(Shared:WaitForChild("Util"):WaitForChild("OpeningLayout"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local AnnouncementController = require(Controllers:WaitForChild("AnnouncementController"))

local BulkOpenController = {}

type Pull = { card: any, foil: boolean, grade: string, isNew: boolean }

local PAUSE = PackOpening.BULK.pause -- seconds each rarity holds the turning over
local GRID = PackOpening.BULK.grid
local BIG = { Epic = true, Legendary = true }
local BEST = CardReveal.BEST
local HUD_REASON = "BulkOpen" -- the HUD hides under the grid, like the pack opening's stage (the quest strip plays its news after)

local player = Players.LocalPlayer
local gui: ScreenGui
local title: TextLabel
local totals: TextLabel
local grid: ScrollingFrame
local layout: UIGridLayout
local continueButton: TextButton
local moreButton: TextButton
local flash: Frame
local bagItems: { [string]: number } = {}
local showing = 0 -- bumps per batch, so an old batch's turning stops
local skipping = false
local itemId: string? = nil

local function playSound(id: string, volume: number)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	task.delay(4, sound.Destroy, sound)
end

-- The biggest cards that fit every row in the grid (the smallest, scrolling, on a small phone)
local function cellWidth(count: number): number
	local size = grid.AbsoluteSize
	return OpeningLayout.gridCell(count, size.X - grid.ScrollBarThickness - 2, size.Y - 24, GRID)
end

local function close()
	showing += 1
	gui.Enabled = false
	Hud.setHidden(HUD_REASON, false)
	player:SetAttribute("PackOpeningBusy", false)
	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- One card turned over: a quick squash, its face, its rarity's pop
local function turn(cell: Frame, pull: Pull)
	local stroke = cell:FindFirstChildOfClass("UIStroke") :: UIStroke
	local squash = cell:FindFirstChildOfClass("UIScale") :: UIScale
	TweenService:Create(squash, TweenInfo.new(0.06), { Scale = 0.85 }):Play()
	CardFace.render(cell, stroke, pull.card, pull.foil)
	TweenService:Create(squash, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if pull.card.rarity == "Common" then 1 else 1.08 }):Play()
	if pull.isNew then
		local ribbon = UIKit.label(cell, "NEW", Enum.Font.FredokaOne, 12, Color3.fromRGB(255, 205, 40))
		ribbon.AnchorPoint = Vector2.new(0.5, 0)
		ribbon.Position = UDim2.new(0.5, 0, 0, -10)
		ribbon.Size = UDim2.fromOffset(40, 16)
		ribbon.TextXAlignment = Enum.TextXAlignment.Center
		ribbon.ZIndex = 20
		UIKit.outlined(ribbon, 1.5)
	end
end

local function rounded(object: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(CardDesign.CORNER, 0)
	corner.Parent = object
end

-- A Very Rare or better lights up as it turns (owner 2026-11-17, look A): a halo of its colour behind it, its rim turning
-- round it, a shine passing over it every few seconds, and its rarity's tag under it
local function lightUp(cell: Frame, pull: Pull)
	local rarity = pull.card.rarity
	local color = CardFace.getRarityColor(rarity)
	local rims = CardDesign.RIMS[rarity] or { color, color }
	cell.ZIndex = 2 -- its halo and tag over its neighbours
	rounded(cell)
	local halo = Instance.new("ImageLabel")
	halo.Name = "Halo"
	halo.BackgroundTransparency = 1
	halo.Image = PackFx.IMAGES.aura
	halo.ImageColor3 = color
	halo.ImageTransparency = BEST.glow[1]
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.5)
	halo.Size = UDim2.fromScale(BEST.halo, BEST.halo / 1.4)
	halo.ZIndex = 0
	halo.Parent = cell
	TweenService:Create(halo, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = BEST.glow[2], Size = UDim2.fromScale(BEST.halo * 0.88, BEST.halo * 0.88 / 1.4) }):Play()
	-- the rim: the cell's own stroke (hidden under the card's drawn rim until now), its colours turning round
	local stroke = cell:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0
		stroke.Thickness = BEST.rim
		local turning = Instance.new("UIGradient")
		turning.Name = "Turning"
		turning.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rims[1]),
			ColorSequenceKeypoint.new(0.25, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, rims[2]),
			ColorSequenceKeypoint.new(0.75, color),
			ColorSequenceKeypoint.new(1, rims[1]),
		})
		turning.Parent = stroke
		TweenService:Create(turning, TweenInfo.new(BEST.spinSeconds, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
	end
	-- the shine, passing over the face now and then
	local clip = Instance.new("Frame")
	clip.Name = "ShineClip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(1, 1)
	clip.ZIndex = 8
	clip.Parent = cell
	local sweep = Instance.new("Frame")
	sweep.Name = "Shine"
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.BorderSizePixel = 0
	sweep.Position = UDim2.fromScale(-0.7, 0)
	sweep.Size = UDim2.fromScale(0.6, 1)
	sweep.ZIndex = 8
	sweep.Parent = clip
	local soft = Instance.new("UIGradient")
	soft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
	soft.Rotation = 20
	soft.Parent = sweep
	task.spawn(function()
		while sweep.Parent do
			sweep.Position = UDim2.fromScale(-0.7, 0)
			TweenService:Create(sweep, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(1.1, 0) }):Play()
			task.wait(BEST.shineEvery)
		end
	end)
	-- its rarity's tag, popping in under it
	local tag = UIKit.label(cell, string.upper(rarity), Enum.Font.FredokaOne, 10, Color3.new(1, 1, 1))
	tag.Name = "Tag"
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	tag.Position = UDim2.new(0.5, 0, 1, 4)
	tag.AutomaticSize = Enum.AutomaticSize.X
	tag.Size = UDim2.fromOffset(0, 14)
	tag.BackgroundColor3 = rims[2]
	tag.BackgroundTransparency = 0
	tag.TextXAlignment = Enum.TextXAlignment.Center
	tag.TextWrapped = false
	tag.ZIndex = 21
	UIKit.corner(tag, 7)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 5)
	padding.PaddingRight = UDim.new(0, 5)
	padding.Parent = tag
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 1.5
	edge.Parent = tag
	local pop = Instance.new("UIScale")
	pop.Scale = 0
	pop.Parent = tag
	TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- All turned: everything but the best pulls dims, so they're the first thing you see (nothing dims when there are none)
local function dimRest(cells: { Frame }, pulls: { Pull })
	local any = false
	for _, pull in pulls do
		if RevealRules.standsOut(pull.card.rarity, BEST.from) then
			any = true
		end
	end
	if not any then
		return
	end
	for index, cell in cells do
		if cell.Parent and not RevealRules.standsOut(pulls[index].card.rarity, BEST.from) then
			local shade = Instance.new("Frame")
			shade.Name = "Dim"
			shade.BackgroundColor3 = Color3.new(0, 0, 0)
			shade.BackgroundTransparency = 1
			shade.BorderSizePixel = 0
			shade.Size = UDim2.fromScale(1, 1)
			shade.ZIndex = 19 -- under the NEW ribbon
			shade.Parent = cell
			rounded(shade)
			TweenService:Create(shade, TweenInfo.new(0.5), { BackgroundTransparency = BEST.dim }):Play()
		end
	end
end

-- A big pull's moment: the screen flashes its colour and the shout-out goes to chat
local function celebrate(pull: Pull)
	local color = CardFace.getRarityColor(pull.card.rarity)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.45
	TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	playSound(PackOpening.SOUNDS.dropSting, 0.5)
	if CardRules.shouldAnnounce(pull.card, pull.foil) then
		AnnouncementController.Show(player.DisplayName, pull.card, pull.foil)
		Remotes.PullRevealed:FireServer(pull.card.id, pull.foil)
	end
end

local function finish(pulls: { Pull }, cells: { Frame }, packs: number)
	dimRest(cells, pulls)
	local newCount, value = 0, 0
	for _, pull in pulls do
		newCount += if pull.isNew then 1 else 0
		value += CardRules.getMarketValue(pull.card, pull.foil, 1, BeastRules.START_STARS, pull.grade)
	end
	totals.Text = string.format("%d cards · %d NEW · worth $%.2f", #pulls, newCount, value)
	playSound(PackOpening.SOUNDS.chime, 0.4)
	local left = if itemId then ItemRules.openMany(bagItems[itemId] or 0, Levels.OPEN_MANY) else 0
	moreButton.Text = `Open {left} more`
	moreButton.Visible = left > 0
	continueButton.Visible = true
	title.Text = `{packs} packs opened!`
end

local function show(_productId: unknown, results: unknown, flags: unknown, fromItem: unknown, packs: unknown)
	if typeof(results) ~= "table" or typeof(fromItem) ~= "string" then
		return
	end
	close()
	showing += 1
	local mine = showing
	itemId = fromItem
	skipping = false
	local newFlags = if typeof(flags) == "table" then flags :: { boolean } else {}
	local pulls: { Pull } = {}
	for index, result in results :: { any } do
		local card = if typeof(result) == "table" then Cards.ById[result.cardId] else nil
		if card then
			table.insert(pulls, {
				card = card,
				foil = result.foil == true,
				grade = if BeastRules.isGrade(result.grade) then result.grade else BeastRules.DEFAULT_GRADE,
				isNew = newFlags[index] == true,
			})
		end
	end
	local count = if typeof(packs) == "number" then packs else math.ceil(#pulls / 5)
	local item = Items.ITEMS[fromItem]
	local name = if item then item.name else "pack"
	title.Text = `Opening {count} {name}{if count > 1 and string.sub(name, -1) ~= "s" then "s" else ""}...`
	totals.Text = "Tap to turn them all over"
	continueButton.Visible = false
	moreButton.Visible = false
	local width = cellWidth(#pulls)
	layout.CellSize = UDim2.fromOffset(width, math.floor(width * GRID.ratio))
	local cells: { Frame } = {}
	for index in pulls do
		local cell = Instance.new("Frame")
		cell.Name = `Card{index}`
		cell.LayoutOrder = index
		cell.BackgroundTransparency = 1
		cell.Parent = grid
		local stroke = Instance.new("UIStroke")
		stroke.Parent = cell
		local squash = Instance.new("UIScale")
		squash.Parent = cell
		CardFace.renderBack(cell, stroke)
		cells[index] = cell
	end
	gui.Enabled = true
	Hud.setHidden(HUD_REASON, true)
	player:SetAttribute("PackOpeningBusy", true)
	task.spawn(function()
		task.wait(0.4)
		for index, pull in pulls do
			if showing ~= mine then
				return
			end
			turn(cells[index], pull)
			if RevealRules.standsOut(pull.card.rarity, BEST.from) then
				lightUp(cells[index], pull)
			end
			if not skipping then
				if BIG[pull.card.rarity] then
					celebrate(pull)
				elseif pull.card.rarity ~= "Common" then
					playSound(PackOpening.SOUNDS.flip, 0.35)
				end
				task.wait(PAUSE[pull.card.rarity] or 0.05)
			elseif BIG[pull.card.rarity] then
				celebrate(pull) -- turned over in a rush, still announced and lit
			end
		end
		if showing == mine then
			finish(pulls, cells, count)
		end
	end)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "BulkOpening"
	gui.DisplayOrder = 42
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.fromRGB(20, 14, 34)
	backdrop.BackgroundTransparency = 0.12
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = gui
	backdrop.Activated:Connect(function()
		skipping = true -- a tap turns the rest over at once
	end)
	UIKit.hideTouchControlsWhileVisible(backdrop)
	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 2
	flash.Parent = gui
	title = UIKit.label(gui, "", Enum.Font.FredokaOne, 30, Color3.new(1, 1, 1))
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, PackOpening.TOP)
	title.Size = UDim2.new(1, -32, 0, 36)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.ZIndex = 5
	UIKit.outlined(title, 2)
	totals = UIKit.label(gui, "", Enum.Font.FredokaOne, 18, Color3.fromRGB(255, 214, 110))
	totals.AnchorPoint = Vector2.new(0.5, 0)
	totals.Position = UDim2.new(0.5, 0, 0, PackOpening.TOP + 40)
	totals.Size = UDim2.new(1, -32, 0, 24)
	totals.TextXAlignment = Enum.TextXAlignment.Center
	totals.ZIndex = 5
	UIKit.outlined(totals, 1.5)
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.new(0.5, 0, 0, PackOpening.TOP + 76)
	grid.Size = UDim2.new(1, -32, 1, -(PackOpening.TOP + 76 + 84))
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.ZIndex = 4
	grid.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(980, 10000)
	limit.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = grid
	layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(GRID.gap, GRID.rowGap) -- room under each for a best pull's tag
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	continueButton = UIKit.button(gui, "Continue", UIKit.Colors.Success)
	continueButton.Name = "Continue"
	continueButton.AnchorPoint = Vector2.new(1, 1)
	continueButton.Position = UDim2.new(0.5, -6, 1, -PackOpening.EDGE - 8)
	continueButton.Size = UDim2.fromOffset(200, 54)
	continueButton.ZIndex = 10
	continueButton.Visible = false
	continueButton.Activated:Connect(close)
	moreButton = UIKit.button(gui, "Open 10 more", UIKit.Colors.Accent)
	moreButton.Name = "OpenMore"
	moreButton.AnchorPoint = Vector2.new(0, 1)
	moreButton.Position = UDim2.new(0.5, 6, 1, -PackOpening.EDGE - 8)
	moreButton.Size = UDim2.fromOffset(200, 54)
	moreButton.ZIndex = 10
	moreButton.Visible = false
	moreButton.Activated:Connect(function()
		local from = itemId
		if from then
			close()
			Remotes.OpenBagPacks:FireServer(from, Levels.OPEN_MANY)
		end
	end)
end

function BulkOpenController.Start()
	build()
	Remotes.PacksOpened.OnClientEvent:Connect(show)
	Remotes.ItemsChanged.OnClientEvent:Connect(function(items: unknown)
		if typeof(items) == "table" then
			bagItems = items :: { [string]: number }
		end
	end)
	-- a fight starting closes it, like the pack opening
	Remotes.BattleStarted.OnClientEvent:Connect(function()
		if gui.Enabled then
			close()
		end
	end)
end

return BulkOpenController
