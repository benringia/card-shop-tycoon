--!strict
-- Builds and runs the loading screen: the binder (owner 2026-11-13, spec 2026-11-13-loading-screen-binder-design;
-- Config/LoadingScreen). A binder open over the world's painting, nine pockets on its left page that fill with cards of
-- Pish, Chikin and Turts as loading goes, the place's name, the count, the step, a slow-save note and a tip on the
-- right page, under a pink "ONE MORE PACK" ribbon. Lives in ReplicatedFirst so it shows from the first frame; the
-- join screen, the copy TeleportService carries and the Wild portal's screen (WildLoadingController) all build it
-- here. Works on the gui's instances by name, so any copy is driven the same way. From its first frame Pish trots under
-- the step and the step's dots count up (owner 2026-11-14: it looked static until the first card flew in).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LoadingGui = {}

local BOOK_ASPECT = 1.68 -- the open binder's width over its height
local PAGE_ASPECT = 0.76 -- the left page: three pockets of card shape across, three down

local function color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function corner(parent: Instance, scale: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(scale, 0)
	round.Parent = parent
end

local function frame(parent: Instance, name: string, rgb: { number }?): Frame
	local made = Instance.new("Frame")
	made.Name = name
	made.BorderSizePixel = 0
	if rgb then
		made.BackgroundColor3 = color(rgb)
	else
		made.BackgroundTransparency = 1
	end
	made.Parent = parent
	return made
end

-- A label whose text fills its box (the box sized in its parent's scale, so the words grow with the binder on any
-- screen; the screen's size isn't known yet this early)
local function label(parent: Instance, name: string, font: Enum.Font, height: number, rgb: { number }): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Font = font
	text.TextScaled = true
	text.TextColor3 = color(rgb)
	text.Text = ""
	text.Size = UDim2.fromScale(1, height)
	text.Parent = parent
	return text
end

-- The ribbon across the binder's top edge: two darker tails behind a pink band with the game's name
local function ribbon(book: Frame, look: any)
	local colors = look.RIBBON
	for index, side in { -1, 1 } do
		local tail = frame(book, `RibbonTail{index}`, colors.drop)
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.fromScale(0.5 + side * 0.33, 0.035)
		tail.Size = UDim2.fromScale(0.09, 0.13)
		tail.Rotation = side * 8
		tail.ZIndex = 8
		corner(tail, 0.15)
	end
	local band = frame(book, "Ribbon", { 255, 255, 255 })
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0)
	band.Size = UDim2.fromScale(0.62, 0.17)
	band.ZIndex = 9
	corner(band, 0.12)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(color(colors.top), color(colors.bottom))
	shade.Parent = band
	for _, part in { { "RibbonDrop", colors.drop, 0.56 }, { "RibbonText", { 255, 255, 255 }, 0.5 } } do
		local text = label(band, part[1] :: string, Enum.Font.Bangers, 0.78, part[2] :: { number })
		text.AnchorPoint = Vector2.new(0.5, 0.5)
		text.Position = UDim2.fromScale(0.5, part[3] :: number)
		text.Size = UDim2.fromScale(0.9, 0.78)
		text.Text = look.TITLE
		text.ZIndex = 10
	end
end

-- The left page: nine pockets, each with its card waiting up and to the right, nearly invisible (still drawn, so
-- its picture loads before it's needed)
local function page(book: Frame, look: any)
	local leaf = frame(book, "Page", look.BOOK.page)
	leaf.AnchorPoint = Vector2.new(0, 0.5)
	leaf.Position = UDim2.fromScale(0.05, 0.5)
	leaf.Size = UDim2.fromScale(0.42, 0.88)
	corner(leaf, 0.03)
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = PAGE_ASPECT
	shape.Parent = leaf
	local padding = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(padding :: any)[side] = UDim.new(0.03, 0)
	end
	padding.Parent = leaf
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.3, 0.3)
	grid.CellPadding = UDim2.fromScale(0.05, 0.05)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = leaf
	for index, card in look.DOG_CARDS do
		local pocket = frame(leaf, `Pocket{index}`, look.BOOK.pocket)
		pocket.LayoutOrder = index
		corner(pocket, 0.06)
		local edge = Instance.new("UIStroke")
		edge.Color = color(look.BOOK.pocketEdge)
		edge.Thickness = 1
		edge.Parent = pocket
		local rim = frame(pocket, "Card", look.RIMS[card.rarity] or look.ACCENT)
		rim.AnchorPoint = Vector2.new(0.5, 0.5)
		rim.Position = UDim2.fromScale(1.9, -0.4)
		rim.Size = UDim2.new(1.1, -4, 1.1, -4)
		rim.Rotation = 18
		rim.BackgroundTransparency = 1
		rim.ZIndex = 3
		corner(rim, 0.08)
		local art = Instance.new("ImageLabel")
		art.Name = "Art"
		art.BackgroundTransparency = 1
		art.Image = card.image
		art.ScaleType = Enum.ScaleType.Crop
		art.ImageTransparency = 0.99
		art.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Position = UDim2.fromScale(0.5, 0.5)
		art.Size = UDim2.new(1, -4, 1, -4)
		art.ZIndex = 4
		art.Parent = rim
		corner(art, 0.06)
	end
	-- the rings down the spine
	for index, y in { 0.2, 0.5, 0.8 } do
		local ring = frame(book, `Ring{index}`, look.BOOK.ring)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.478, y)
		ring.Size = UDim2.fromScale(0.022, 0.085)
		ring.ZIndex = 5
		corner(ring, 0.5)
	end
end

-- Pish trotting on the spot over a road (Config/LoadingScreen TROT), under the step: the road's dashes (one more than
-- fit, so one is always coming in as they run back), then him standing on them
local function trot(column: Frame, look: any)
	local track = frame(column, "Trot")
	track.Size = UDim2.fromScale(1, 0.26)
	track.LayoutOrder = 4
	local cfg = look.TROT
	if not cfg then
		track.Visible = false
		return
	end
	local road = frame(track, "Road")
	road.AnchorPoint = Vector2.new(0.5, 0.5)
	road.Position = UDim2.fromScale(0.5, cfg.FEET)
	road.Size = UDim2.fromScale(0.62, 0.06)
	road.ClipsDescendants = true
	for index = 1, cfg.DASHES + 1 do
		local dash = frame(road, `Dash{index}`, look.ACCENT)
		dash.BackgroundTransparency = 0.35
		dash.AnchorPoint = Vector2.new(0, 0.5)
		dash.Position = UDim2.fromScale((index - 1) / cfg.DASHES, 0.5)
		dash.Size = UDim2.fromScale(0.55 / cfg.DASHES, 1)
		corner(dash, 0.5)
	end
	local pish = Instance.new("ImageLabel")
	pish.Name = "Pish"
	pish.BackgroundTransparency = 1
	pish.Image = cfg.IMAGE
	pish.ImageRectSize = Vector2.new(cfg.FRAME_SIZE, cfg.FRAME_SIZE)
	pish.AnchorPoint = Vector2.new(0.5, 0)
	pish.Position = UDim2.fromScale(0.5, 0)
	pish.Size = UDim2.fromScale(1, 1)
	pish.ZIndex = 2
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = pish
	pish.Parent = track
end

-- The right page: the place's name, the count, the step, Pish trotting, the slow-save note, a tip in a cream bubble
local function rightPage(book: Frame, look: any, firstStep: string)
	local column = frame(book, "Info")
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.fromScale(0.53, 0.53)
	column.Size = UDim2.fromScale(0.42, 0.8)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.025, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = column
	local place = label(column, "Place", Enum.Font.Bangers, 0.1, look.ACCENT)
	place.Text = look.PLACE
	place.Visible = look.PLACE ~= ""
	place.LayoutOrder = 1
	-- "N / 9": the number big in the place's colour over a darker drop, " / 9" smaller beside it
	local count = frame(column, "CountBox")
	count.Size = UDim2.fromScale(1, 0.24)
	count.LayoutOrder = 2
	for _, part in { { "CountDrop", look.ACCENT_DROP, 0.05 }, { "Count", look.ACCENT, 0 } } do
		local number = label(count, part[1] :: string, Enum.Font.Bangers, 1, part[2] :: { number })
		number.AnchorPoint = Vector2.new(1, 0)
		number.Position = UDim2.fromScale(0.55, part[3] :: number)
		number.Size = UDim2.fromScale(0.5, 1)
		number.TextXAlignment = Enum.TextXAlignment.Right
		number.Text = "0"
		number.ZIndex = if part[1] == "Count" then 7 else 6
	end
	local slash = label(count, "Slash", Enum.Font.Bangers, 0.5, look.BOOK.muted)
	slash.Position = UDim2.fromScale(0.57, 0.42)
	slash.Size = UDim2.fromScale(0.4, 0.5)
	slash.TextXAlignment = Enum.TextXAlignment.Left
	slash.Text = `/ {look.POCKETS}`
	slash.ZIndex = 7
	local step = label(column, "Step", Enum.Font.GothamBold, 0.075, { 255, 255, 255 })
	step.RichText = true -- its dots count up (LoadingRules.dotted)
	step.Text = firstStep
	step.LayoutOrder = 3
	trot(column, look)
	local note = label(column, "Note", Enum.Font.GothamBold, 0.06, look.ACCENT)
	note.LayoutOrder = 5
	note.Visible = false
	local bubble = frame(column, "TipBox", look.TIP_COLORS.back)
	bubble.Size = UDim2.fromScale(0.94, 0.17)
	bubble.LayoutOrder = 6
	corner(bubble, 0.3)
	local tip = label(bubble, "Tip", Enum.Font.GothamBold, 0.7, look.TIP_COLORS.text)
	tip.AnchorPoint = Vector2.new(0.5, 0.5)
	tip.Position = UDim2.fromScale(0.5, 0.5)
	tip.Size = UDim2.fromScale(0.9, 0.7)
	tip.Text = look.TIPS[1] or ""
	local wrap = Instance.new("UITextSizeConstraint")
	wrap.MaxTextSize = 40
	wrap.Parent = tip
end

-- A fresh screen at its first step, in a place's look (Util/LoadingRules.look)
function LoadingGui.build(look: any, firstStep: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("Pockets", look.POCKETS)
	gui:SetAttribute("Filled", 0)
	gui:SetAttribute("FlySeconds", look.FLY_SECONDS)
	gui:SetAttribute("FlyStagger", look.FLY_STAGGER)
	gui:SetAttribute("Accent", color(look.ACCENT))
	gui:SetAttribute("StepText", firstStep)

	local back = frame(gui, "Back", { 255, 255, 255 })
	back.Size = UDim2.fromScale(1, 1)
	back.Active = true -- taps and clicks stop here while loading
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(color(look.BACKGROUND.top), color(look.BACKGROUND.bottom))
	shade.Parent = back

	-- the world's painting, a dark layer over it so the binder reads
	local backdrop = Instance.new("ImageLabel")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundTransparency = 1
	backdrop.Image = look.BACKDROP or ""
	backdrop.ScaleType = Enum.ScaleType.Crop
	local rect = look.BACKDROP_RECT
	if rect and rect[3] > 0 then
		backdrop.ImageRectOffset = Vector2.new(rect[1], rect[2])
		backdrop.ImageRectSize = Vector2.new(rect[3], rect[4])
	end
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = back
	local dim = frame(back, "Dim", look.BACKGROUND.bottom)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundTransparency = look.DIM_TRANSPARENCY

	local book = frame(back, "Book", look.BOOK.case)
	book.AnchorPoint = Vector2.new(0.5, 0.5)
	book.Position = UDim2.fromScale(0.5, 0.55)
	book.Size = UDim2.fromScale(0.7, 0.74)
	corner(book, 0.04)
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = BOOK_ASPECT
	shape.Parent = book
	-- the stitching just inside the edge, in the place's colour
	local stitch = frame(book, "Stitch")
	stitch.AnchorPoint = Vector2.new(0.5, 0.5)
	stitch.Position = UDim2.fromScale(0.5, 0.5)
	stitch.Size = UDim2.fromScale(0.97, 0.95)
	corner(stitch, 0.03)
	local thread = Instance.new("UIStroke")
	thread.Name = "Thread"
	thread.Color = color(look.ACCENT)
	thread.Thickness = 1.5
	thread.Transparency = 0.35
	thread.Parent = stitch

	page(book, look)
	rightPage(book, look, firstStep)
	ribbon(book, look)
	return gui
end

-- Pish's trot, the road and the step's dots, every frame until the screen is gone (through its fade too).
-- Util/LoadingRules is in ReplicatedStorage, there by the time a screen animates (Show waits for it)
local function moveAlong(gui: ScreenGui, look: any)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local util = shared and shared:FindFirstChild("Util")
	local rulesModule = util and util:FindFirstChild("LoadingRules")
	if not rulesModule or not rulesModule:IsA("ModuleScript") then
		return
	end
	local rules = require(rulesModule) :: any
	local cfg = look.TROT
	local pish = gui:FindFirstChild("Pish", true)
	local road = gui:FindFirstChild("Road", true)
	local step = gui:FindFirstChild("Step", true)
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not gui.Parent then
			connection:Disconnect()
			return
		end
		local seconds = os.clock() - started
		if cfg and pish and pish:IsA("ImageLabel") then
			local x, y = rules.trotRect(rules.trotFrame(seconds, cfg), cfg)
			pish.ImageRectOffset = Vector2.new(x, y)
		end
		if cfg and road then
			local shift = rules.roadShift(seconds, cfg)
			for index = 1, cfg.DASHES + 1 do
				local dash = road:FindFirstChild(`Dash{index}`)
				if dash and dash:IsA("Frame") then
					dash.Position = UDim2.fromScale((index - 1 - shift) / cfg.DASHES, 0.5)
				end
			end
		end
		local words = gui:GetAttribute("StepText")
		if step and step:IsA("TextLabel") and typeof(words) == "string" then
			local text = rules.dotted(words, seconds, look.DOTS_SECONDS or 0.35)
			if step.Text ~= text then
				step.Text = text
			end
		end
	end)
end

-- Cycles the tips and starts Pish trotting; returns a stop (for the tips)
function LoadingGui.animate(gui: ScreenGui, look: any): () -> ()
	local running = true
	moveAlong(gui, look)
	local tip = gui:FindFirstChild("Tip", true)
	task.spawn(function()
		local tips = look.TIPS
		if #tips == 0 then
			return
		end
		local index = math.random(1, #tips)
		while running and tip and tip.Parent do
			(tip :: TextLabel).Text = tips[index]
			index = index % #tips + 1
			task.wait(look.TIP_SECONDS)
		end
	end)
	return function()
		running = false
	end
end

-- One card sliding into its pocket
local function flyIn(card: Frame, seconds: number)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(card, info, {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -4, 1, -4),
		Rotation = 0,
		BackgroundTransparency = 0,
	}):Play()
	local art = card:FindFirstChild("Art")
	if art and art:IsA("ImageLabel") then
		TweenService:Create(art, TweenInfo.new(seconds * 0.5), { ImageTransparency = 0 }):Play()
	end
end

-- The step's words, how many pockets hold a card (more fly in, FLY_STAGGER apart) and the slow-save note ("" for none).
-- All pockets full: the step shows in the place's colour (it's "Ready!")
function LoadingGui.set(gui: ScreenGui, stepText: string, pockets: number, note: string)
	local total = gui:GetAttribute("Pockets") :: number? or 9
	local filled = gui:GetAttribute("Filled") :: number? or 0
	local seconds = gui:GetAttribute("FlySeconds") :: number? or 0.45
	local stagger = gui:GetAttribute("FlyStagger") :: number? or 0.12
	local target = math.clamp(math.floor(pockets), 0, total)
	if target > filled then
		gui:SetAttribute("Filled", target)
		local lands = os.clock() + (target - filled - 1) * stagger + seconds
		gui:SetAttribute("LandsAt", math.max(gui:GetAttribute("LandsAt") :: number? or 0, lands))
		for index = filled + 1, target do
			local pocket = gui:FindFirstChild(`Pocket{index}`, true)
			local card = pocket and pocket:FindFirstChild("Card")
			if card and card:IsA("Frame") then
				task.delay((index - filled - 1) * stagger, flyIn, card, seconds)
			end
		end
		for _, name in { "Count", "CountDrop" } do
			local count = gui:FindFirstChild(name, true)
			if count and count:IsA("TextLabel") then
				count.Text = tostring(target)
			end
		end
	end
	gui:SetAttribute("StepText", stepText)
	local step = gui:FindFirstChild("Step", true)
	if step and step:IsA("TextLabel") then
		step.Text = stepText
		if target >= total then
			step.TextColor3 = gui:GetAttribute("Accent") :: Color3? or step.TextColor3
		end
	end
	local noteLabel = gui:FindFirstChild("Note", true)
	if noteLabel and noteLabel:IsA("TextLabel") then
		noteLabel.Text = note
		noteLabel.Visible = note ~= ""
	end
end

-- Seconds until the last card sent flying has landed (0 once they all have)
function LoadingGui.settleSeconds(gui: ScreenGui): number
	return math.max(0, (gui:GetAttribute("LandsAt") :: number? or 0) - os.clock())
end

-- Fades everything out, then removes the screen
function LoadingGui.fadeOut(gui: ScreenGui, seconds: number)
	local info = TweenInfo.new(seconds)
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") then
			TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif item:IsA("ImageLabel") then
			TweenService:Create(item, info, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(seconds, function()
		gui:Destroy()
	end)
end

return LoadingGui
