--!strict
-- Unboxing onto a shelf (owner 2026-11-23, pick 1; Config/Delivery UNBOX): when a carried box goes on a shelf, it opens
-- in the stocker's hands, flaps up, and a few of its products hop onto the shelf one after another (the real pack,
-- deck box, sleeve packet or booster box, Util/PackModels and friends), each landing with a pop a little higher than
-- the last while a "+n" over the shelf rolls up to what went on; then the empty box shrinks away. Client-only looks:
-- the shelf's stock is already there on the server.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Delivery = require(Config:WaitForChild("Delivery"))
local Products = require(Config:WaitForChild("Products"))
local Packs = require(Config:WaitForChild("Packs"))
local StockConfig = require(Config:WaitForChild("Stock"))
local Util = Shared:WaitForChild("Util")
local DeliveryRules = require(Util:WaitForChild("DeliveryRules"))
local PropFit = require(Util:WaitForChild("PropFit"))
local PackModels = require(Util:WaitForChild("PackModels"))
local SleevePacket = require(Util:WaitForChild("SleevePacket"))
local BoosterBoxLook = require(Util:WaitForChild("BoosterBoxLook"))
local BulkHandful = require(Util:WaitForChild("BulkHandful"))
local Town = require(Config:WaitForChild("Town"))

local UnboxFx = {}

local UNBOX = Delivery.UNBOX
local ITEM_SIZE = 1.1 -- a hopping product's longest side, studs
local BOX_COLOR = Color3.fromRGB(201, 147, 94)
local BOX_EDGE = Color3.fromRGB(150, 104, 62)

local folder: Folder? = nil

local function fxFolder(): Folder
	local current = folder
	if current and current.Parent then
		return current
	end
	local made = Instance.new("Folder")
	made.Name = "UnboxFx"
	made.Parent = workspace
	folder = made
	return made
end

local function loose(model: Instance)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
end

-- One of the product as it sits on a shelf, fitted to ITEM_SIZE: a pack, a deck box, a sleeve packet, a sealed booster
-- box or a handful of cards (the register counter's looks, PropFit.counterLook); anything else a block in its colour
local function item(productId: string): Model
	local product = Products.ById[productId]
	local look = if product then PropFit.counterLook(product.stockLook, Packs.ById[product.id] ~= nil) else "block"
	local model: Model
	if look == "pack" then
		model = PackModels.pack(productId, "Low")
	elseif look == "deck" then
		model = PackModels.deckBox(productId)
	elseif look == "sleeves" and product then
		model = SleevePacket.build(SleevePacket.color(1), Color3.fromRGB(product.color[1], product.color[2], product.color[3]))
	elseif look == "booster" and product then
		model = Instance.new("Model")
		local box = Town.SHELF_STOCK.BOOSTERS
		local booster = Instance.new("Part")
		booster.Size = Vector3.new(box.WIDTH, box.HEIGHT, box.DEPTH)
		booster.Parent = model
		BoosterBoxLook.draw(booster, product, box.PIXELS_PER_STUD)
	elseif look == "bulk" then
		model = BulkHandful.build(nil, 1)
	else
		model = Instance.new("Model")
		local block = Instance.new("Part")
		block.Size = Vector3.new(1, 1, 1)
		block.Color = if product then Color3.fromRGB(product.color[1], product.color[2], product.color[3]) else BOX_COLOR
		block.Material = Enum.Material.SmoothPlastic
		block.Parent = model
	end
	loose(model)
	model:PivotTo(CFrame.new())
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		model:ScaleTo(model:GetScale() * ITEM_SIZE / longest)
	end
	return model
end

-- The open box in the stocker's hands: a cardboard body and two flaps that swing open
local function openBox(at: CFrame): (Model, { BasePart })
	local model = Instance.new("Model")
	model.Name = "OpenBox"
	local size = StockConfig.BOX_SIZE
	local body = Instance.new("Part")
	body.Size = size
	body.CFrame = at
	body.Color = BOX_COLOR
	body.Material = Enum.Material.Cardboard
	body.Parent = model
	local flaps: { BasePart } = {}
	for _, side in { -1, 1 } do
		local flap = Instance.new("Part")
		flap.Size = Vector3.new(size.X / 2, 0.08, size.Z)
		-- hinged on the top edge: closed it lies flat over its half of the top
		flap.CFrame = at * CFrame.new(side * size.X / 4, size.Y / 2 + 0.04, 0)
		flap.Color = BOX_EDGE
		flap.Material = Enum.Material.Cardboard
		flap:SetAttribute("Side", side)
		flap.Parent = model
		table.insert(flaps, flap)
	end
	loose(model)
	model.Parent = fxFolder()
	return model, flaps
end

-- Where the products land: the shelf's display boxes (PlacementService's StockBox parts), else across its top half
local function targets(shelf: BasePart, count: number): { Vector3 }
	local spots: { Vector3 } = {}
	for _, child in shelf:GetChildren() do
		if child:IsA("BasePart") and child.Name == "StockBox" then
			table.insert(spots, child.Position + Vector3.new(0, child.Size.Y * 0.3, 0))
		end
	end
	local list = {}
	for index = 1, count do
		if #spots > 0 then
			list[index] = spots[(index - 1) % #spots + 1]
		else
			local x = (index / (count + 1) - 0.5) * shelf.Size.X * 0.7
			list[index] = (shelf.CFrame * CFrame.new(x, shelf.Size.Y * 0.2, 0)).Position
		end
	end
	return list
end

-- The "+n" over the shelf, rolling up as the products land
local function counter(shelf: BasePart): (BillboardGui, TextLabel)
	local gui = Instance.new("BillboardGui")
	gui.Name = "UnboxCount"
	gui.Adornee = shelf
	gui.Size = UDim2.fromOffset(140, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, shelf.Size.Y / 2 + 1.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = UNBOX.reach
	gui.Parent = fxFolder()
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.Text = ""
	text.TextColor3 = Color3.fromRGB(63, 214, 160)
	text.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 3
	edge.Parent = text
	return gui, text
end

local function playSound(at: Vector3, sound: { id: string, volume: number }, pitch: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Position = at
	holder.Parent = fxFolder()
	local made = Instance.new("Sound")
	made.SoundId = sound.id
	made.Volume = sound.volume
	made.PlaybackSpeed = pitch or 1
	made.RollOffMaxDistance = UNBOX.reach
	made.Parent = holder
	made:Play()
	Debris:AddItem(holder, 3)
end

-- Flies a product from `from` to `to` on an arc over `seconds`, then calls `landed`
local function fly(model: Model, from: Vector3, to: Vector3, seconds: number, landed: () -> ())
	local start = os.clock()
	local spin = (math.random() - 0.5) * math.pi
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local share = (os.clock() - start) / seconds
		if share >= 1 or not model.Parent then
			connection:Disconnect()
			model:Destroy()
			landed()
			return
		end
		local point = DeliveryRules.hopPoint({ x = from.X, y = from.Y, z = from.Z }, { x = to.X, y = to.Y, z = to.Z }, share, UNBOX.peak)
		model:PivotTo(CFrame.new(point.x, point.y, point.z) * CFrame.Angles(0, spin * share, 0))
	end)
end

-- Plays the unboxing: the box in front of `root` (the stocker's) opens and `added` units go onto `shelf` as a few
-- hopping `productId`s
function UnboxFx.play(shelf: BasePart, root: BasePart, productId: string, added: number)
	local shares = DeliveryRules.shares(added, UNBOX.items)
	if #shares == 0 then
		return
	end
	local at = root.CFrame * StockConfig.CARRY_OFFSET
	local box, flaps = openBox(at)
	playSound(at.Position, Delivery.SOUNDS.flap)
	for _, flap in flaps do
		local side = flap:GetAttribute("Side") :: number
		local size = StockConfig.BOX_SIZE
		-- swung open about its outer edge: up and out, past upright
		local hinge = at * CFrame.new(side * size.X / 2, size.Y / 2, 0)
		local openFrame = hinge * CFrame.Angles(0, 0, side * math.rad(-120)) * CFrame.new(-side * size.X / 4, 0.04, 0)
		TweenService:Create(flap, TweenInfo.new(UNBOX.open, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = openFrame }):Play()
	end

	local template = item(productId)
	local landing = targets(shelf, #shares)
	local gui, text = counter(shelf)
	local shown = 0
	local from = (at * CFrame.new(0, StockConfig.BOX_SIZE.Y / 2 + 0.4, 0)).Position
	for index, share in shares do
		task.delay(UNBOX.open + (index - 1) * UNBOX.gap, function()
			local copy = template:Clone()
			copy.Parent = fxFolder()
			fly(copy, from, landing[index], UNBOX.flight, function()
				shown += share
				text.Text = `+{shown}`
				playSound(landing[index], Delivery.SOUNDS.pop, 1 + (index - 1) * UNBOX.pitchStep)
			end)
		end)
	end
	template:Destroy()

	-- after the last lands: the box shrinks away, the count floats up and fades
	local finish = UNBOX.open + (#shares - 1) * UNBOX.gap + UNBOX.flight
	task.delay(finish + 0.1, function()
		for _, piece in box:GetChildren() do
			if piece:IsA("BasePart") then
				TweenService:Create(piece, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = piece.Size * 0.05, Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(box, 0.4)
	end)
	task.delay(finish + 0.6, function()
		TweenService:Create(gui, TweenInfo.new(0.6), { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 1.2, 0) }):Play()
		TweenService:Create(text, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		local edge = text:FindFirstChildOfClass("UIStroke")
		if edge then
			TweenService:Create(edge, TweenInfo.new(0.6), { Transparency = 1 }):Play()
		end
		Debris:AddItem(gui, 0.7)
	end)
end

return UnboxFx
