--!strict
-- The phone's Store app (owner 2026-11-14: the Luck Booster for Robux and the Extra Job Slot, then "improve the design
-- of the window, make it more premium, make it feel like a WIN", option A; Config/Luck, Config/Monetization): a page
-- inside the phone (Util/Hud.phonePage). On top a green "Feeling lucky?" banner with Pish and floating clovers and the
-- luck running now; then the three boosts as colourful tiles (2x Luck 15 / 30 min, 3x Super Luck 30 min in an animated
-- rainbow), each with its win in a chip (the Legendary chance before and with it), a tag on the true best ones and a
-- shine sweeping them, and chunky gold price buttons (live prices: managed pricing gives each player theirs); then the
-- Extra Job Slot as a gold "forever" tile. A boost tap asks the server (Remotes.BuyLuck: LuckService prompts the
-- purchase; the slot: BuyUnlock); where Roblox restricts paid random items the luck tiles say they aren't sold here.
-- The win card after a purchase: StoreWinController.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Luck = require(Config:WaitForChild("Luck"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Packs = require(Config:WaitForChild("Packs"))
local HudMascot = require(Config:WaitForChild("HudMascot"))
local LuckRules = require(Shared:WaitForChild("Util"):WaitForChild("LuckRules"))
local BoughtLuck = require(Shared:WaitForChild("Util"):WaitForChild("BoughtLuck"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Hud = require(ClientUtil:WaitForChild("Hud"))
local ProductPrice = require(ClientUtil:WaitForChild("ProductPrice"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))

local StoreController = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local INK = rgb(59, 42, 82)
local SOFT = rgb(122, 106, 146)
local WHITE = Color3.new(1, 1, 1)
local GOLD_TOP, GOLD_BOTTOM, GOLD_EDGE, GOLD_INK = rgb(255, 233, 138), rgb(247, 181, 44), rgb(199, 129, 27), rgb(59, 36, 0)
local GREEN_TOP, GREEN_BOTTOM = rgb(63, 224, 138), rgb(13, 120, 70)
local CHIP_GREEN, CHIP_GREEN_INK = rgb(234, 251, 239), rgb(27, 138, 72)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 111, 168)),
	ColorSequenceKeypoint.new(0.25, rgb(255, 179, 64)),
	ColorSequenceKeypoint.new(0.5, rgb(95, 220, 140)),
	ColorSequenceKeypoint.new(0.75, rgb(79, 183, 255)),
	ColorSequenceKeypoint.new(1, rgb(167, 123, 255)),
})
local TILE_HEIGHT = 86
local BUTTON_WIDTH = 78
local BUTTON_HEIGHT = 48
local Z = 35 -- over the phone's screen
local PASS_KEY = "ExtraJobSlot"
local PACK_ID = "FirstSparkPack"

local player = Players.LocalPlayer
local content: Frame
local list: ScrollingFrame
local status: TextLabel?
local luckAllowed: boolean? = nil -- nil while Roblox's policy is being read
local drawing = false
local pricesPending = false -- a price was still being asked when the page was drawn

-- The Legendary chance of the First Spark pack's last card with a boost (0: none), for the tiles' chips
local function legendaryChance(boost: number): number
	local slots = Packs.ById[PACK_ID].slots
	local hit = slots[#slots]
	local chances = LuckRules.chances(if boost > 0 then LuckRules.boost(hit, Packs.RANK, Luck.FROM_RARITY, boost) else hit)
	return chances.Legendary or 0
end

local function label(parent: Instance, text: string, font: Enum.Font, size: number, color: Color3): TextLabel
	local made = UIKit.label(parent, text, font, size, color)
	made.ZIndex = Z + 2
	return made
end

local function corner(parent: GuiObject, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

local function gradient(parent: GuiObject, colors: ColorSequence, rotation: number): UIGradient
	local made = Instance.new("UIGradient")
	made.Color = colors
	made.Rotation = rotation
	made.Parent = parent
	return made
end

local function stroke(parent: GuiObject, color: Color3, thickness: number)
	local made = Instance.new("UIStroke")
	made.Color = color
	made.Thickness = thickness
	made.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	made.Parent = parent
end

-- A soft band of light sweeping across, over and over (the best tiles, the banner)
local function shine(parent: GuiObject, delay: number)
	parent.ClipsDescendants = true
	local band = Instance.new("Frame")
	band.Name = "Shine"
	band.BackgroundColor3 = WHITE
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(0.45, 1)
	band.Position = UDim2.fromScale(-0.5, 0)
	band.ZIndex = Z + 1
	band.Parent = parent
	local fade = Instance.new("UIGradient")
	fade.Rotation = 20
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
	TweenService:Create(band, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, delay), {
		Position = UDim2.fromScale(1.1, 0),
	}):Play()
end

-- A small rounded tag: the odds chip, the badges, the live pill
local function chip(parent: Instance, text: string, back: Color3, ink: Color3, size: number): TextLabel
	local made = label(parent, text, Enum.Font.GothamBold, size, ink)
	made.AutomaticSize = Enum.AutomaticSize.X
	made.Size = UDim2.fromOffset(0, size + 7)
	made.BackgroundColor3 = back
	made.BackgroundTransparency = 0
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = made
	corner(made, 8)
	return made
end

-- A chunky gold price button (a darker lip under it), or a quiet one when it can't be bought now
local function buyButton(parent: Instance, text: string, enabled: boolean, onTap: (() -> ())?): TextButton
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(1, 0)
	lip.Position = UDim2.new(1, -8, 0, 13)
	lip.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
	lip.BackgroundColor3 = if enabled then GOLD_EDGE else rgb(170, 160, 185)
	lip.ZIndex = Z + 2
	lip.Parent = parent
	corner(lip, 14)
	local button = Instance.new("TextButton")
	button.Name = "Buy"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -8, 0, 10)
	button.Size = UDim2.fromOffset(BUTTON_WIDTH, BUTTON_HEIGHT)
	button.BackgroundColor3 = WHITE
	button.AutoButtonColor = enabled
	button.Font = Enum.Font.FredokaOne
	button.Text = text
	button.TextColor3 = if enabled then GOLD_INK else rgb(110, 100, 125)
	button.TextScaled = true
	button.ZIndex = Z + 3
	button.Parent = parent
	corner(button, 14)
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 18
	fit.Parent = button
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	gradient(button, if enabled then ColorSequence.new(GOLD_TOP, GOLD_BOTTOM) else ColorSequence.new(rgb(236, 232, 242), rgb(212, 206, 222)), 90)
	button.Activated:Connect(function()
		if enabled and onTap then
			onTap()
		end
	end)
	return button
end

type TileLook = { back: ColorSequence?, outline: Color3?, iconBack: ColorSequence, light: boolean, rainbow: boolean?, chipBack: Color3, chipInk: Color3 }

-- One thing to buy: a coloured icon, its name and length, its win in a chip, a tag, a price button
local function tile(order: number, look: TileLook, icon: string, name: string, sub: string, win: string, badge: string?, button: string?, enabled: boolean, onTap: (() -> ())?)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, TILE_HEIGHT)
	frame.BackgroundColor3 = WHITE
	frame.ZIndex = Z
	frame.Parent = list
	corner(frame, 16)
	if look.back then
		local fill = gradient(frame, look.back, 0)
		if look.rainbow then
			fill.Offset = Vector2.new(-0.5, 0)
			TweenService:Create(fill, TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.5, 0) }):Play()
		end
	end
	if look.outline then
		stroke(frame, look.outline, 2.5)
	end
	local ink = if look.light then WHITE else INK
	local box = Instance.new("Frame")
	box.Position = UDim2.fromOffset(10, 10)
	box.Size = UDim2.fromOffset(40, 40)
	box.BackgroundColor3 = WHITE
	box.ZIndex = Z + 2
	box.Parent = frame
	corner(box, 12)
	gradient(box, look.iconBack, 90)
	local glyph = label(box, icon, Enum.Font.FredokaOne, 24, INK)
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	glyph.ZIndex = Z + 3
	local textWidth = -(58 + BUTTON_WIDTH + 14)
	local title = label(frame, name, Enum.Font.FredokaOne, 17, ink)
	title.Position = UDim2.fromOffset(58, 9)
	title.Size = UDim2.new(1, textWidth, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	local most = Instance.new("UITextSizeConstraint")
	most.MaxTextSize = 17
	most.Parent = title
	if look.light then
		title.TextStrokeTransparency = 0.6
	end
	local length = label(frame, sub, Enum.Font.GothamBold, 11, ink)
	length.Position = UDim2.fromOffset(58, 32)
	length.Size = UDim2.new(1, textWidth, 0, 16)
	length.TextXAlignment = Enum.TextXAlignment.Left
	length.TextTransparency = 0.15
	length.TextWrapped = true
	local winChip = chip(frame, win, look.chipBack, look.chipInk, 12)
	winChip.Position = UDim2.fromOffset(10, 60)
	if badge then
		local tag = chip(frame, badge, rgb(255, 92, 138), WHITE, 10)
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -10, 0, 64)
		tag.ZIndex = Z + 4
	end
	if button then
		buyButton(frame, button, enabled, onTap)
	end
	if badge or look.rainbow then
		shine(frame, 1.6 + order * 0.3)
	end
end

-- "R$ 29" once the price is in, "..." meanwhile (the page draws again when it comes), "Coming soon" for a product not
-- made yet
local function priceText(id: number, price: number?): string
	if id == 0 then
		return "Coming soon"
	end
	if not price then
		pricesPending = true
		return "..."
	end
	return `R$ {price}`
end

-- The luck running now and its time (LuckService's attributes), or a nudge when none runs
local function statusText(): string
	local strength = player:GetAttribute("BoughtLuck")
	local info = if typeof(strength) == "string" then Luck.STRENGTHS[strength] else nil
	if not info then
		return "Pick a boost below!"
	end
	local untilTime = player:GetAttribute("BoughtLuckUntil")
	local time = LuckRules.badgeText(if typeof(untilTime) == "number" then untilTime else nil, workspace:GetServerTimeNow(), "") or ""
	local waiting = player:GetAttribute("BoughtLuckWaiting")
	local more = if typeof(waiting) == "number" and waiting >= 60 then ` (+{math.floor(waiting / 60)} min)` else ""
	return `{info.icon} {info.name} on · {(string.gsub(time, "^%s+", ""))}{more}`
end

-- The green banner: Pish peeking, clovers floating, "Feeling lucky?", what's running
local function banner()
	local frame = Instance.new("Frame")
	frame.LayoutOrder = 1
	frame.Size = UDim2.new(1, -8, 0, 98)
	frame.BackgroundColor3 = WHITE
	frame.ZIndex = Z
	frame.Parent = list
	corner(frame, 18)
	gradient(frame, ColorSequence.new(GREEN_TOP, GREEN_BOTTOM), 60)
	stroke(frame, rgb(190, 255, 215), 2)
	for index, spot in { { 0.88, 0.14, 20 }, { 0.72, 0.6, 14 }, { 0.95, 0.66, 12 } } do
		local clover = Instance.new("ImageLabel")
		clover.BackgroundTransparency = 1
		clover.Image = Luck.AURA.CLOVER
		clover.ImageColor3 = rgb(200, 255, 215)
		clover.ImageTransparency = 0.35
		clover.AnchorPoint = Vector2.new(0.5, 0.5)
		clover.Position = UDim2.fromScale(spot[1], spot[2])
		clover.Size = UDim2.fromOffset(spot[3], spot[3])
		clover.ZIndex = Z + 1
		clover.Parent = frame
		TweenService:Create(clover, TweenInfo.new(1.5 + index * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = UDim2.fromScale(spot[1], spot[2] - 0.08),
			Rotation = 25,
		}):Play()
	end
	local pish = Instance.new("ImageLabel")
	pish.BackgroundTransparency = 1
	pish.Image = HudMascot.images.peek
	pish.AnchorPoint = Vector2.new(0, 1)
	pish.Position = UDim2.new(0, 2, 1, 6)
	pish.Size = UDim2.fromOffset(82, 82)
	pish.ScaleType = Enum.ScaleType.Fit
	pish.ZIndex = Z + 2
	pish.Parent = frame
	local title = label(frame, "Feeling lucky?", Enum.Font.FredokaOne, 19, WHITE)
	title.Position = UDim2.fromOffset(88, 8)
	title.Size = UDim2.new(1, -94, 0, 24)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextStrokeTransparency = 0.55
	local line = label(frame, "Luck makes the last card in every pack better!", Enum.Font.GothamBold, 11, WHITE)
	line.Position = UDim2.fromOffset(88, 32)
	line.Size = UDim2.new(1, -94, 0, 28)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextWrapped = true
	local live = chip(frame, statusText(), rgb(10, 80, 45), WHITE, 11)
	live.BackgroundTransparency = 0.35
	live.Position = UDim2.fromOffset(88, 66)
	status = live
	shine(frame, 2.4)
end

local function heading(order: number, text: string)
	local line = label(list, text, Enum.Font.FredokaOne, 16, INK)
	line.LayoutOrder = order
	line.Size = UDim2.new(1, -12, 0, 22)
	line.TextXAlignment = Enum.TextXAlignment.Left
end

local LUCK_LOOKS: { [string]: TileLook } = {
	x2 = { iconBack = ColorSequence.new(rgb(191, 247, 207), rgb(111, 227, 154)), light = false, chipBack = CHIP_GREEN, chipInk = CHIP_GREEN_INK },
	x2best = { outline = rgb(54, 197, 111), iconBack = ColorSequence.new(rgb(143, 240, 176), rgb(35, 178, 90)), light = false, chipBack = CHIP_GREEN, chipInk = CHIP_GREEN_INK },
	x3 = { back = RAINBOW, rainbow = true, iconBack = ColorSequence.new(rgb(255, 255, 255), rgb(235, 225, 255)), light = true, chipBack = WHITE, chipInk = rgb(124, 63, 208) },
}
local SLOT_LOOK: TileLook = {
	back = ColorSequence.new(rgb(255, 247, 218), rgb(255, 233, 168)),
	outline = rgb(245, 194, 66),
	iconBack = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM),
	light = false,
	chipBack = WHITE,
	chipInk = rgb(176, 112, 15),
}

local function draw()
	pricesPending = false
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	banner()

	heading(2, "🍀 Luck boosts")
	local plain = legendaryChance(0)
	for index, key in Luck.STORE do
		local product = Luck.PRODUCTS[key]
		local strength = Luck.STRENGTHS[product.strength]
		local look = if product.strength == "x3" then LUCK_LOOKS.x3 elseif product.badge then LUCK_LOOKS.x2best else LUCK_LOOKS.x2
		local minutes = `{math.floor(product.seconds / 60)} minutes`
		local win = BoughtLuck.oddsText(plain, legendaryChance(strength.boost))
		if luckAllowed == false then
			tile(2 + index, look, strength.icon, strength.name, minutes, "Not sold where you live", nil, nil, false, nil)
		else
			local id = Monetization.PRODUCTS[key] or 0
			local price = ProductPrice.of(id)
			tile(2 + index, look, strength.icon, strength.name, minutes, win, product.badge, priceText(id, price), id ~= 0 and price ~= nil and luckAllowed == true, function()
				ScreenClear.prompt()
				Remotes.BuyLuck:FireServer(key)
			end)
		end
	end
	local note = label(list, "The time only runs while you play. All the odds are in the Rarity guide.", Enum.Font.GothamBold, 10, SOFT)
	note.LayoutOrder = 10
	note.Size = UDim2.new(1, -12, 0, 26)
	note.TextWrapped = true

	heading(20, "⭐ Forever")
	-- Sold as a one-time developer product (Monetization UNLOCKS; the server opens it only while you don't own it),
	-- else as the game pass
	local productId = Monetization.PRODUCTS[PASS_KEY] or 0
	local passId = Monetization.PASSES[PASS_KEY] or 0
	local sub = "A second worker"
	if player:GetAttribute(`Has{PASS_KEY}`) == true then
		tile(21, SLOT_LOOK, "💼", "Extra Job Slot", sub, "+1 worker, yours forever", nil, "Owned", false, nil)
	elseif productId ~= 0 then
		local price = ProductPrice.of(productId)
		tile(21, SLOT_LOOK, "💼", "Extra Job Slot", sub, "+1 worker, forever", "FOREVER", priceText(productId, price), price ~= nil, function()
			ScreenClear.prompt()
			Remotes.BuyUnlock:FireServer(PASS_KEY)
		end)
	else
		local price = ProductPrice.ofPass(passId)
		tile(21, SLOT_LOOK, "💼", "Extra Job Slot", sub, "+1 worker, forever", "FOREVER", priceText(passId, price), passId ~= 0 and price ~= nil, function()
			ScreenClear.prompt()
			MarketplaceService:PromptGamePassPurchase(player, passId)
		end)
	end
end

-- The page showing: its own frame and the phone round it (the phone closes without hiding the page)
local function isOpen(): boolean
	local phone = content and content.Parent
	return content ~= nil and content.Visible and phone ~= nil and phone:IsA("GuiObject") and phone.Visible
end

-- Draws now, and again each second until every price is in (ten tries); keeps the running time ticking while open
local function open()
	draw()
	Hud.showPhonePage("Store")
	if drawing then
		return
	end
	drawing = true
	task.spawn(function()
		local tries = 0
		while isOpen() do
			task.wait(1)
			local live = status
			if pricesPending and tries < 10 then -- a price that never comes stays "..."
				tries += 1
				draw()
			elseif live and live.Parent then
				live.Text = statusText()
			end
		end
		drawing = false
	end)
end

local function build()
	content = Hud.phonePage("Store", "Store")
	list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 34)
	list.Size = UDim2.new(1, 0, 1, -34)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ZIndex = Z - 1
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = list
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = list
end

function StoreController.Start()
	build()
	Hud.fanButton({ id = "Store", icon = "🛒", label = "Store", order = 6, stay = true, onClick = open })
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		luckAllowed = ok and typeof(info) == "table" and info.ArePaidRandomItemsRestricted ~= true
		if isOpen() then
			draw()
		end
	end)
	for _, name in { "BoughtLuck", "BoughtLuckUntil", `Has{PASS_KEY}` } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if isOpen() then
				draw()
			end
		end)
	end
end

return StoreController
