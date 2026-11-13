--!strict
-- Turts' rug shop, drawn on this client (spec 2026-11-13-turts-shop-design; TurtsService owns the rules): the owner's
-- dog on the marker workspace.TurtsNpc.Turts (NpcModels.Turts with his clips; Chikin's model stands in until his is
-- imported), his head always shaking (TurtsRules.shakeAngle on top of the clips), a sit now and then, the excited
-- spin ("celebrate") whenever the marker's Excited goes up; his rug (PropModels.TurtsRug, else a code-built one: rug,
-- cushion, lantern, crates, sign) with this player's own 3 offers on stands (SOLD ones dimmed); a timer over him; a
-- light beacon for BEACON_SECONDS after he moves; his "Shop" prompt opening the window (the offers with Buy, the
-- countdown, Robux "Restock now").
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Turts = require(Config:WaitForChild("Turts"))
local Items = require(Config:WaitForChild("Items"))
local Monetization = require(Config:WaitForChild("Monetization"))
local Rarities = require(Config:WaitForChild("Rarities"))
local TurtsRules = require(Shared:WaitForChild("Util"):WaitForChild("TurtsRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local PishVisual = require(ClientUtil:WaitForChild("PishVisual"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))
local UIController = require(Controllers:WaitForChild("UIController"))

local TurtsController = {}

local FIND_SECONDS = 30
local RUG_FORWARD = 1.6 -- studs: the rug's middle in front of him (he sits at its back)
-- the offers' stands, from his spot: an arc in front of him, low, the middle one furthest out, so he shows between them
local SLOTS = { { x = -3, z = -2.6 }, { x = 0, z = -4.6 }, { x = 3, z = -2.6 } }
local STAND_HEIGHT = 0.7
local WOOD = Color3.fromRGB(150, 100, 60)
local RUG_COLORS = { Color3.fromRGB(200, 72, 56), Color3.fromRGB(242, 176, 66) }
local SOLD_FADE = 0.6

type Slot = { stand: Part, gui: BillboardGui, icon: Frame, price: TextLabel, sold: TextLabel }

local marker: BasePart
local visual: PishVisual.Visual? = nil
local head: Bone? = nil
local rug: Model
local slots: { Slot } = {}
local timerLabel: TextLabel
local stock = { index = 0, offers = {} :: { string }, bought = {} :: { string }, endsAt = 0 }
-- The shake last put on his head and the transform it left, so it's swapped each frame, never piled up (nothing else
-- rewrites his head every frame: a shake multiplied on top grew to 50-88 degrees in Studio)
local shakeOn = CFrame.identity
local shakeLeft: CFrame? = nil
local panel: Frame? = nil
local cards: Frame? = nil
local countdown: TextLabel? = nil

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local made = Instance.new("Part")
	made.Name = name
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
	made.CastShadow = false
	made.Size = size
	made.Color = color
	made.Material = material or Enum.Material.SmoothPlastic
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	return made
end

-- The lantern's glow and the sign's word, on the imported rug (Frame, Glow, Sign) or the stand-in
local function dress(model: Model)
	local glass = model:FindFirstChild("Glow", true)
	if glass and glass:IsA("BasePart") then
		glass.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 196, 110)
		light.Range = 9
		light.Brightness = 0.8
		light.Parent = glass
	end
	local board = model:FindFirstChild("Sign", true)
	if board and board:IsA("BasePart") then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0.3
		gui.Parent = board
		local word = UIKit.label(gui, "TURTS", Enum.Font.FredokaOne, 44, Color3.fromRGB(255, 248, 236))
		word.Size = UDim2.fromScale(1, 1)
		word.TextXAlignment = Enum.TextXAlignment.Center
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
end

-- His rug and things (PropModels.TurtsRug when it's imported: Frame, Glow, Sign, origin where he sits, built by
-- tools/blender/build_turts_rug.py), laid out round the origin facing -Z (his customers)
local function buildRug(): Model
	local props = ReplicatedStorage:FindFirstChild("PropModels")
	local template = if props then props:FindFirstChild("TurtsRug") else nil
	if template and template:IsA("Model") then
		local model = template:Clone()
		dress(model)
		return model
	end
	local model = Instance.new("Model")
	model.Name = "TurtsRug"
	local r = Turts.RUG_RADIUS
	for ring, color in RUG_COLORS do
		local disc = part("Rug", Vector3.new(0.08 + ring * 0.01, r * 2 * (1.12 - ring * 0.18), r * 2 * (1.12 - ring * 0.18)), color, Enum.Material.Fabric)
		disc.Shape = Enum.PartType.Cylinder
		disc.CFrame = CFrame.new(0, 0.05 + ring * 0.01, -RUG_FORWARD) * CFrame.Angles(0, 0, math.rad(90))
		disc.Parent = model
	end
	local cushion = part("Cushion", Vector3.new(2.6, 0.18, 2.4), Color3.fromRGB(120, 86, 170), Enum.Material.Fabric)
	cushion.CFrame = CFrame.new(0, 0.15, 0.2)
	cushion.Parent = model
	for index, x in { -2.9, 2.9 } do
		local crate = part("Crate", Vector3.new(1.4, 1.2, 1.4), WOOD, Enum.Material.WoodPlanks)
		crate.CFrame = CFrame.new(x, 0.65, 0.6) * CFrame.Angles(0, math.rad(index * 12), 0)
		crate.Parent = model
	end
	local lantern = part("Glow", Vector3.new(0.5, 0.7, 0.5), Color3.fromRGB(255, 196, 110))
	lantern.CFrame = CFrame.new(-2.9, 1.65, 0.6)
	lantern.Parent = model
	local sign = part("Sign", Vector3.new(2.2, 1.2, 0.15), Color3.fromRGB(44, 52, 56), Enum.Material.Slate)
	sign.CFrame = CFrame.new(2.9, 1.9, 0.6) * CFrame.Angles(math.rad(-12), 0, 0)
	sign.Parent = model
	dress(model)
	model.WorldPivot = CFrame.new() -- laid out round the origin: PivotTo puts the origin on his spot
	return model
end

-- One offer's stand on the rug: a little post with the offer's icon, price and SOLD over it
local function buildSlot(parent: Instance): Slot
	local stand = part("Stand", Vector3.new(STAND_HEIGHT, 0.9, 0.9), WOOD, Enum.Material.Wood) -- a cylinder's length is X
	stand.Shape = Enum.PartType.Cylinder
	stand.Parent = parent
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(84, 92)
	gui.StudsOffset = Vector3.new(0, 1.3, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false
	gui.Adornee = stand
	gui.Parent = stand
	local icon = Icon.make(gui, "BoosterPack", UDim2.fromOffset(56, 56))
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 0)
	local price = UIKit.label(gui, "", Enum.Font.FredokaOne, 20, Color3.fromRGB(255, 214, 110))
	price.Position = UDim2.fromOffset(0, 58)
	price.Size = UDim2.new(1, 0, 0, 24)
	price.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.outlined(price, 2)
	local sold = UIKit.label(gui, "SOLD", Enum.Font.FredokaOne, 22, Color3.fromRGB(255, 255, 255))
	sold.Position = UDim2.fromOffset(0, 22)
	sold.Size = UDim2.new(1, 0, 0, 26)
	sold.TextXAlignment = Enum.TextXAlignment.Center
	sold.Rotation = -12
	UIKit.outlined(sold, 2)
	sold.Visible = false
	return { stand = stand, gui = gui, icon = icon, price = price, sold = sold }
end

-- A soft round glow behind an offer's icon in its tier's colour (his packs: Very Rare, Epic, Legendary)
local function glowBehind(icon: Frame, offer: any)
	local old = icon:FindFirstChild("TierGlow")
	if old then
		old:Destroy()
	end
	local tier = if offer and offer.glow then (Rarities.Tiers :: any)[offer.glow] else nil
	if not tier then
		return
	end
	local glow = Instance.new("Frame")
	glow.Name = "TierGlow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.1, 1.1)
	glow.BackgroundColor3 = tier.color
	glow.BackgroundTransparency = 0.35
	glow.ZIndex = icon.ZIndex - 1
	glow.Parent = icon
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = glow
end

local function itemOf(offerId: string): any
	local offer = Turts.OFFERS[offerId]
	return if offer then (Items.ITEMS :: any)[offer.item] else nil
end

local function bought(offerId: string): boolean
	return table.find(stock.bought, offerId) ~= nil
end

-- The rug and the stands at his spot; the stands show this player's offers
local function layOut()
	local base = marker.CFrame
	rug:PivotTo(base)
	for index, slot in slots do
		local spot = SLOTS[index]
		slot.stand.CFrame = base * CFrame.new(spot.x, STAND_HEIGHT / 2, spot.z) * CFrame.Angles(0, 0, math.rad(90))
		local offerId = stock.offers[index]
		local offer = if offerId then Turts.OFFERS[offerId] else nil
		slot.gui.Enabled = offer ~= nil
		if offer and offerId then
			local item = itemOf(offerId)
			Icon.set(slot.icon, if item and item.icon then item.icon else "BoosterPack")
			glowBehind(slot.icon, offer)
			slot.price.Text = `${offer.price}`
			local gone = bought(offerId)
			slot.sold.Visible = gone
			slot.icon.Visible = true
			for _, child in slot.icon:GetDescendants() do
				if child:IsA("ImageLabel") then
					child.ImageTransparency = if gone then SOLD_FADE else 0
				end
			end
		end
	end
end

local function clock(seconds: number): string
	local left = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", left // 60, left % 60)
end

-- The window's offer cards (rebuilt when the stock changes)
local function fillWindow()
	if not cards or not panel then
		return
	end
	for _, child in cards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local palette = UIKit.colorsFor(panel)
	for index, offerId in stock.offers do
		local offer = Turts.OFFERS[offerId]
		local item = itemOf(offerId)
		if not offer then
			continue
		end
		local row = Instance.new("Frame")
		row.Name = `Offer{index}`
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, 88)
		row.BackgroundColor3 = palette.row
		row.Parent = cards
		UIKit.corner(row, 14)
		UIKit.outline(row, palette.rowEdge, 2)
		local icon = Icon.make(row, if item and item.icon then item.icon else "BoosterPack", UDim2.fromOffset(60, 60))
		icon.Position = UDim2.fromOffset(12, 14)
		icon.ZIndex = row.ZIndex + 2
		glowBehind(icon, offer)
		local name = UIKit.label(row, offer.name, Enum.Font.FredokaOne, 19, palette.ink)
		name.Position = UDim2.fromOffset(84, 10)
		name.Size = UDim2.new(1, -210, 0, 26)
		local about = UIKit.label(row, if item then item.description else "", Enum.Font.GothamBold, 13, palette.inkSoft)
		about.Position = UDim2.fromOffset(84, 38)
		about.Size = UDim2.new(1, -210, 0, 40)
		about.TextWrapped = true
		about.TextYAlignment = Enum.TextYAlignment.Top
		if bought(offerId) then
			local tag = UIKit.pill(row, "SOLD", UIKit.Colors.Success)
			tag.AnchorPoint = Vector2.new(1, 0.5)
			tag.Position = UDim2.new(1, -14, 0.5, 0)
		else
			local buy = UIKit.button(row, `${offer.price}`, UIKit.Colors.Accent)
			buy.AnchorPoint = Vector2.new(1, 0.5)
			buy.Position = UDim2.new(1, -12, 0.5, 0)
			buy.Size = UDim2.fromOffset(112, 48)
			buy.Activated:Connect(function()
				Remotes.TurtsBuy:FireServer(offerId, stock.index)
			end)
		end
	end
end

local function buildWindow()
	local list: ScrollingFrame
	local made: Frame
	made, list = UIKit.panel(UIController.GetScreenGui(), "TurtsShop", "Turts' Shop")
	panel = made
	local palette = UIKit.colorsFor(made)
	local line = UIKit.label(list, "", Enum.Font.GothamBold, 15, palette.inkSoft)
	line.LayoutOrder = 0
	line.Size = UDim2.new(1, 0, 0, 22)
	line.TextXAlignment = Enum.TextXAlignment.Center
	countdown = line
	local holder = Instance.new("Frame")
	holder.Name = "Offers"
	holder.LayoutOrder = 1
	holder.BackgroundTransparency = 1
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.Parent = list
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	cards = holder
	local productId = (Monetization.PRODUCTS :: any)[Turts.PRODUCT] :: number
	local soon = productId == 0
	local restock = UIKit.button(list, if soon then "Restock now · Coming soon" else "Restock now", UIKit.Colors.Secondary)
	if not soon then
		-- its Robux price on the button, from Roblox (the price is set on Creator Hub)
		task.spawn(function()
			local ok, info = pcall(function()
				return game:GetService("MarketplaceService"):GetProductInfo(productId, Enum.InfoType.Product)
			end)
			if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
				restock.Text = `Restock now · R$ {info.PriceInRobux}`
			end
		end)
	end
	restock.LayoutOrder = 2
	restock.Size = UDim2.new(1, 0, 0, 52)
	restock.Activated:Connect(function()
		if not soon then
			Remotes.TurtsRestockNow:FireServer()
		end
	end)
	fillWindow()
end

local function openWindow()
	if not panel then
		buildWindow()
	end
	Remotes.TurtsStock:FireServer() -- fresh numbers as it opens
	fillWindow()
	if panel then
		panel.Visible = true
	end
end

-- A soft column of light over his rug after he moves, fading out
local function beacon()
	local column = part("TurtsBeacon", Vector3.new(30, 1.6, 1.6), Color3.fromRGB(255, 226, 150), Enum.Material.Neon)
	column.Shape = Enum.PartType.Cylinder
	column.Transparency = 0.7
	column.CFrame = marker.CFrame * CFrame.new(0, 18, 1) * CFrame.Angles(0, 0, math.rad(90)) -- behind him, rising over his head
	column.Parent = workspace
	local fade = TweenService:Create(column, TweenInfo.new(Turts.BEACON_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
	fade.Completed:Once(function()
		column:Destroy()
	end)
	fade:Play()
end

local function makeVisual()
	visual = PishVisual.new(marker, "Turts") or PishVisual.new(marker, "Chikin")
	head = nil
	if visual then
		local bone = visual.body.model:FindFirstChild("Head_0", true)
		head = if bone and bone:IsA("Bone") then bone else nil
	end
end

local function overhead(): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "TurtsTag"
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.MaxDistance = 90
	gui.Adornee = marker
	gui.Parent = marker
	local name = UIKit.label(gui, "Turts' Shop", Enum.Font.FredokaOne, 22, Color3.fromRGB(255, 255, 255))
	name.Size = UDim2.new(1, 0, 0, 28)
	name.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.outlined(name, 2)
	local time = UIKit.label(gui, "", Enum.Font.GothamBold, 15, Color3.fromRGB(255, 214, 110))
	time.Position = UDim2.fromOffset(0, 28)
	time.Size = UDim2.new(1, 0, 0, 22)
	time.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.outlined(time, 2)
	return time
end

local function addPrompt()
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Turts"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Turts.PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = marker
	prompt.Triggered:Connect(openWindow)
end

function TurtsController.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("TurtsNpc", FIND_SECONDS)
		local found = if folder then folder:WaitForChild("Turts", FIND_SECONDS) else nil
		if not found or not found:IsA("BasePart") then
			return -- not the main game, or his service isn't running
		end
		marker = found
		rug = buildRug()
		rug.Parent = workspace
		for _ = 1, #SLOTS do
			table.insert(slots, buildSlot(rug))
		end
		timerLabel = overhead()
		addPrompt()
		makeVisual()
		layOut()

		Remotes.TurtsStock.OnClientEvent:Connect(function(index: number, offers: { string }, boughtIds: { string }, endsAt: number)
			stock = { index = index, offers = offers, bought = boughtIds, endsAt = endsAt }
			layOut()
			fillWindow()
		end)
		Remotes.TurtsStock:FireServer()
		marker:GetPropertyChangedSignal("CFrame"):Connect(layOut)
		marker:GetAttributeChangedSignal("MovedAt"):Connect(beacon)
		marker:GetAttributeChangedSignal("Excited"):Connect(function()
			if visual then
				PishVisual.play(visual, "celebrate")
			end
		end)

		-- a sit now and then
		task.spawn(function()
			local rng = Random.new()
			while true do
				task.wait(rng:NextNumber(Turts.SIT_EVERY[1], Turts.SIT_EVERY[2]))
				if visual then
					PishVisual.play(visual, "sit")
				end
			end
		end)
		-- the timer over him and in the window
		task.spawn(function()
			while true do
				local left = TurtsRules.secondsLeft(os.time(), Turts.RESTOCK_SECONDS)
				timerLabel.Text = `Restock in {clock(left)}`
				if countdown then
					countdown.Text = `New offers in {clock(left)}`
				end
				task.wait(1)
			end
		end)
		RunService.RenderStepped:Connect(function(dt)
			if not visual then
				return
			end
			PishVisual.step(visual, dt)
			local bone = head
			if bone then
				-- his head always shakes (owner: "main animation will be the head shake"), on top of the clips: the last
				-- frame's shake taken off first, unless something else has set the head since
				local base = if shakeLeft and bone.Transform == shakeLeft then shakeLeft * shakeOn:Inverse() else bone.Transform
				shakeOn = CFrame.Angles(0, math.rad(TurtsRules.shakeAngle(os.clock(), Turts.SHAKE)), 0)
				bone.Transform = base * shakeOn
				shakeLeft = bone.Transform
			end
		end)
	end)
end

return TurtsController
