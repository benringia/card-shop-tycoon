--!strict
-- The packenship.co delivery van (owner 2026-11-23, mockup A; Config/Delivery VAN): a small white van with a lilac
-- skirt, a mint band with the supplier's name, sky-blue windows, a sliding door on its right side (the side that faces
-- the pad) and four wheels. The Blender model (PropModels.DeliveryVan, owner 2026-11-23: "make the van in blender";
-- tools/blender/build_delivery_van.py, docs/props.md "The delivery van": parts Frame, Door, WheelFL/FR/RL/RR,
-- BandLeft/BandRight, Headlights/Taillights) once it's saved as assets/props/DeliveryVan.rbxm, else built from parts
-- here. It faces -Z (its front), its right is +X, its pivot sits on the street under its middle. Client-only, and only
-- the orderer's: DeliveryController moves it on its own (BulkMoveTo every frame), turns its wheels, slides its door and
-- fades it in and out at the street's ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Delivery = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Delivery"))

local DeliveryVan = {}

export type Built = {
	model: Model,
	body: BasePart, -- the part its sounds play from
	parts: { BasePart }, -- every part but the wheels and the door, with their offsets from the pivot
	offsets: { CFrame },
	looks: { { part: BasePart, base: number } }, -- every part's own transparency, for the fade
	wheels: { { part: BasePart, offset: CFrame } },
	door: { part: BasePart, closed: CFrame, open: CFrame },
	labels: { TextLabel },
}

local VAN = Delivery.VAN
local CAB_LENGTH = 3.6 -- the code-built van's cab is the front (-Z) part, the cargo box behind it
local DOOR_LENGTH = 2.2 -- its sliding door, just behind the cab on the right
local DOOR_GAP = 0.15
local DOOR_SLIDE_OUT = 0.16 -- an open door stands this far off the side, clear of the name band it slides over
local LABEL_PIXELS = 90 -- the name's canvas, pixels a stud (it keeps the band's shape)
-- the Blender model's parts the van can't do without
local MODEL_PARTS = { "Frame", "Door", "BandLeft", "BandRight", "WheelFL", "WheelFR", "WheelRL", "WheelRR" }

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function loose(made: BasePart)
	made.Anchored = true
	made.CanCollide = false
	made.CanQuery = false
	made.CanTouch = false
end

local warned = false

-- The Blender model when it's saved with every part the van moves, else nil (the code-built van stands in)
local function template(): Model?
	local props = ReplicatedStorage:FindFirstChild("PropModels")
	local found = if props then props:FindFirstChild("DeliveryVan") else nil
	if not found or not found:IsA("Model") then
		return nil
	end
	for _, name in MODEL_PARTS do
		local piece = found:FindFirstChild(name)
		if not piece or not piece:IsA("BasePart") then
			if not warned then
				warned = true
				warn(`[DeliveryVan] PropModels.DeliveryVan has no {name} part: the code-built van stands in`)
			end
			return nil
		end
	end
	return found
end

-- One of the code-built van's parts at `offset` from its pivot
local function part(model: Model, name: string, size: Vector3, offset: CFrame, color: { number }, material: Enum.Material?): Part
	local made = Instance.new("Part")
	made.Name = name
	loose(made)
	made.Size = size
	made.CFrame = offset
	made.Color = rgb(color)
	made.Material = material or Enum.Material.SmoothPlastic
	made.TopSurface = Enum.SurfaceType.Smooth
	made.BottomSurface = Enum.SurfaceType.Smooth
	made.Parent = model
	return made
end

-- The supplier's name on a side band, facing `face`
local function label(band: BasePart, face: Enum.NormalId): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = LABEL_PIXELS
	gui.LightInfluence = 0.3
	gui.Parent = band
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = VAN.name
	text.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = text
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(24, 140, 100)
	edge.Thickness = 2
	edge.Parent = text
	return text
end

-- A lamp lit up: its own colour, glowing (the palette texture off, so the colour shows)
local function glow(lamp: BasePart, color: { number })
	if lamp:IsA("MeshPart") then
		pcall(function()
			lamp.TextureID = ""
		end)
	end
	for _, child in lamp:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	lamp.Material = Enum.Material.Neon
	lamp.Color = rgb(color)
end

local function looksOf(model: Model): { { part: BasePart, base: number } }
	local looks = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(looks, { part = descendant, base = descendant.Transparency })
		end
	end
	return looks
end

-- How far an open door slides back: its length along the van
local function slideOf(door: BasePart, closed: CFrame): number
	local size = door.Size
	local along = math.abs(closed.RightVector.Z) * size.X + math.abs(closed.UpVector.Z) * size.Y + math.abs(closed.LookVector.Z) * size.Z
	return along + 0.1
end

-- The Blender model, every part placed by its offset from the model's pivot (the bottom centre, tools/props/split_pack)
local function fromModel(source: Model, parent: Instance): Built
	local model = source:Clone()
	model.Name = "DeliveryVan"
	local pivot = model:GetPivot()
	local door = model:FindFirstChild("Door") :: BasePart
	local list: { BasePart } = {}
	local offsets: { CFrame } = {}
	local wheels = {}
	for _, descendant in model:GetDescendants() do
		if not descendant:IsA("BasePart") then
			continue
		end
		loose(descendant)
		local offset = pivot:ToObjectSpace(descendant.CFrame)
		if string.sub(descendant.Name, 1, 5) == "Wheel" then
			table.insert(wheels, { part = descendant, offset = offset })
		elseif descendant ~= door then
			table.insert(list, descendant)
			table.insert(offsets, offset)
		end
	end
	for name, color in { Headlights = VAN.light, Taillights = VAN.tail } do
		local lamp = model:FindFirstChild(name)
		if lamp and lamp:IsA("BasePart") then
			glow(lamp, color)
		end
	end
	local labels = {
		label(model:FindFirstChild("BandLeft") :: BasePart, Enum.NormalId.Left),
		label(model:FindFirstChild("BandRight") :: BasePart, Enum.NormalId.Right),
	}
	local closed = pivot:ToObjectSpace(door.CFrame)
	-- slid in the van's own frame: out from its right side, back toward its rear (+Z)
	local open = CFrame.new(DOOR_SLIDE_OUT, 0, slideOf(door, closed)) * closed
	local looks = looksOf(model)
	model.Parent = parent
	return {
		model = model,
		body = model:FindFirstChild("Frame") :: BasePart,
		parts = list,
		offsets = offsets,
		looks = looks,
		wheels = wheels,
		door = { part = door, closed = closed, open = open },
		labels = labels,
	}
end

-- The stand-in built from parts
local function codeBuilt(parent: Instance): Built
	local model = Instance.new("Model")
	model.Name = "DeliveryVan"
	local length, width = VAN.length, VAN.width
	local half = length / 2
	local cabLength = CAB_LENGTH
	local cargoStart = -half + cabLength
	local wheelY = VAN.wheel / 2

	local list: { BasePart } = {}
	local function add(made: BasePart)
		table.insert(list, made)
	end
	-- the lilac skirt, the white cab and cargo box, the step between them
	add(part(model, "Skirt", Vector3.new(width - 0.1, 1, length - 0.4), CFrame.new(0, wheelY + 0.25, 0.1), VAN.skirt))
	local cargo = part(model, "Cargo", Vector3.new(width, 3.6, half - cargoStart), CFrame.new(0, wheelY + 2.45, (cargoStart + half) / 2), VAN.body)
	add(cargo)
	add(part(model, "Cab", Vector3.new(width, 2.6, cabLength - 0.2), CFrame.new(0, wheelY + 1.95, -half + 0.1 + (cabLength - 0.2) / 2), VAN.body))
	local wedge = Instance.new("WedgePart")
	wedge.Name = "Step"
	loose(wedge)
	wedge.Size = Vector3.new(width, 1, 1.6)
	wedge.CFrame = CFrame.new(0, wheelY + 3.75, cargoStart - 0.8)
	wedge.Color = rgb(VAN.body)
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.Parent = model
	add(wedge)
	-- glass: the windscreen across the cab's front, a window each side of the cab
	local glass = part(model, "Windscreen", Vector3.new(width - 0.8, 1.5, 0.12), CFrame.new(0, wheelY + 2.55, -half + 0.04), VAN.glass, Enum.Material.Glass)
	glass.Transparency = 0.15
	add(glass)
	for _, side in { -1, 1 } do
		local window = part(model, "CabWindow", Vector3.new(0.12, 1.2, 1.8), CFrame.new(side * (width / 2 + 0.02), wheelY + 2.6, -half + 1.9), VAN.glass, Enum.Material.Glass)
		window.Transparency = 0.15
		add(window)
	end
	-- lights and bumpers
	for _, side in { -1, 1 } do
		add(part(model, "Headlight", Vector3.new(1, 0.6, 0.1), CFrame.new(side * 1.8, wheelY + 1.3, -half - 0.02), VAN.light, Enum.Material.Neon))
		add(part(model, "Taillight", Vector3.new(0.6, 1, 0.1), CFrame.new(side * (width / 2 - 0.4), wheelY + 1.6, half + 0.02), VAN.tail, Enum.Material.Neon))
	end
	add(part(model, "FrontBumper", Vector3.new(width + 0.1, 0.5, 0.4), CFrame.new(0, wheelY, -half - 0.05), VAN.tyre))
	add(part(model, "RearBumper", Vector3.new(width + 0.1, 0.5, 0.4), CFrame.new(0, wheelY, half + 0.05), VAN.tyre))
	-- the mint band with the name: the whole left side; on the right, behind the sliding door
	local labels: { TextLabel } = {}
	local leftBand = part(model, "BandLeft", Vector3.new(0.1, 1.3, half - cargoStart - 0.6), CFrame.new(-width / 2 - 0.05, wheelY + 2.7, (cargoStart + half) / 2), VAN.stripe)
	add(leftBand)
	table.insert(labels, label(leftBand, Enum.NormalId.Left))
	local doorLength = DOOR_LENGTH
	local doorFront = cargoStart + DOOR_GAP
	local rightStart = doorFront + doorLength + 0.25
	local rightBand = part(model, "BandRight", Vector3.new(0.1, 1.3, half - rightStart - 0.3), CFrame.new(width / 2 + 0.05, wheelY + 2.7, (rightStart + half - 0.3) / 2), VAN.stripe)
	add(rightBand)
	table.insert(labels, label(rightBand, Enum.NormalId.Right))

	-- the sliding door: closed in its frame, open slid back along the side (outside the body)
	local closed = CFrame.new(width / 2 + 0.06, wheelY + 2.15, doorFront + doorLength / 2)
	local door = part(model, "Door", Vector3.new(0.12, 3.1, doorLength), closed, VAN.door)
	local open = CFrame.new(DOOR_SLIDE_OUT, 0, doorLength + 0.1) * closed

	-- wheels: tyres with a hub, turning about their axle (the X axis)
	local wheels = {}
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local at = CFrame.new(x * (width / 2 - 0.35), wheelY, z * (half - 1.9))
			local tyre = part(model, "Tyre", Vector3.new(0.8, VAN.wheel, VAN.wheel), at, VAN.tyre)
			tyre.Shape = Enum.PartType.Cylinder
			table.insert(wheels, { part = tyre :: BasePart, offset = at })
			local hub = part(model, "Hub", Vector3.new(0.84, VAN.wheel * 0.5, VAN.wheel * 0.5), at, VAN.hub, Enum.Material.Metal)
			hub.Shape = Enum.PartType.Cylinder
			table.insert(wheels, { part = hub :: BasePart, offset = at })
		end
	end

	local offsets = {}
	for index, made in list do
		offsets[index] = made.CFrame
	end
	local looks = looksOf(model)
	model.Parent = parent
	return {
		model = model,
		body = cargo,
		parts = list,
		offsets = offsets,
		looks = looks,
		wheels = wheels,
		door = { part = door, closed = closed, open = open },
		labels = labels,
	}
end

function DeliveryVan.build(parent: Instance): Built
	local source = template()
	if source then
		return fromModel(source, parent)
	end
	return codeBuilt(parent)
end

-- Puts the van at `cframe` (its pivot on the street, facing where it drives) with its wheels turned `turn` radians
-- and its door `doorShare` open (0 shut, 1 open)
function DeliveryVan.place(van: Built, cframe: CFrame, turn: number, doorShare: number)
	local parts: { BasePart } = table.clone(van.parts)
	local frames: { CFrame } = {}
	for index, offset in van.offsets do
		frames[index] = cframe * offset
	end
	for _, wheel in van.wheels do
		table.insert(parts, wheel.part)
		-- turned about the van's own X axis through the wheel's middle (its axle): the wheel rolls
		table.insert(frames, cframe * CFrame.new(wheel.offset.Position) * CFrame.Angles(-turn, 0, 0) * wheel.offset.Rotation)
	end
	table.insert(parts, van.door.part)
	table.insert(frames, cframe * van.door.closed:Lerp(van.door.open, math.clamp(doorShare, 0, 1)))
	workspace:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Where a box leaves the van standing at `stop`: just outside its sliding door, at the door's height
function DeliveryVan.doorPoint(stop: CFrame): Vector3
	local doorMiddle = -VAN.length / 2 + CAB_LENGTH + DOOR_GAP + DOOR_LENGTH / 2
	local source = template()
	if source then
		local door = source:FindFirstChild("Door") :: BasePart
		doorMiddle = source:GetPivot():PointToObjectSpace(door.Position).Z
	end
	return (stop * CFrame.new(VAN.width / 2 + 0.6, VAN.doorHeight, doorMiddle)).Position
end

-- How solid the van is: 1 itself, 0 gone (at the street's ends)
function DeliveryVan.fade(van: Built, alpha: number)
	local a = math.clamp(alpha, 0, 1)
	for _, look in van.looks do
		look.part.Transparency = look.base + (1 - look.base) * (1 - a)
	end
	for _, text in van.labels do
		text.TextTransparency = 1 - a
		local edge = text:FindFirstChildOfClass("UIStroke")
		if edge then
			edge.Transparency = 1 - a
		end
	end
end

return DeliveryVan
