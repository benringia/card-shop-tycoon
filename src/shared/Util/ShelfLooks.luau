--!strict
-- Draws the code-built product shelves (Town.SLOTS marked built: Shelf, WallShelf, HookRack, DisplayRack) from the
-- parts Util/ShelfLayout places for the shelf's size and stock levels: charcoal posts, base and header sign, light
-- grey plates with dark price rails, an oak slat back (a pegboard with chrome hooks on the Accessory Hook). Look:
-- Town.SHELF_LOOK. No lights. Used by Props for the shelves and their placement ghosts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Town = require(Config:WaitForChild("Town"))
local Shelves = require(Config:WaitForChild("Shelves"))
local Util = Shared:WaitForChild("Util")
local ShelfStock = require(Util:WaitForChild("ShelfStock"))
local ShelfLayout = require(Util:WaitForChild("ShelfLayout"))

local ShelfLooks = {}

local KINDS: { [string]: ShelfLayout.Kind } = { Shelf = "Rack", WallShelf = "Rack", HookRack = "Pegboard", DisplayRack = "DoubleRack" }
local SLAT = 0.45 -- height of one back slat
local GROOVE = 0.06 -- the dark gap between slats

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- The stock layout of the shelf this slot draws (its Config/Shelves stock override on top of SHELF_STOCK)
local function stockFor(slot: string): ShelfStock.StockConfig
	for _, def in Shelves.List do
		if def.prop == slot then
			return ShelfStock.configFor(Town.SHELF_STOCK, def.stock)
		end
	end
	return Town.SHELF_STOCK
end

local function addPart(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Horizontal oak slats with dark grooves between them, filling the back panel's box
local function addSlats(model: Model, size: Vector3, cframe: CFrame)
	local look = Town.SHELF_LOOK
	addPart(model, "BackCore", Vector3.new(size.X, size.Y, size.Z * 0.5), cframe, rgb(look.SLAT_GAP), Enum.Material.Wood)
	local count = math.max(1, math.floor(size.Y / SLAT))
	local pitch = size.Y / count
	for index = 1, count do
		local y = -size.Y / 2 + (index - 0.5) * pitch
		addPart(model, "Slat", Vector3.new(size.X, pitch - GROOVE, size.Z), cframe * CFrame.new(0, y, 0), rgb(look.BACK_COLOR), Enum.Material.Wood)
	end
end

local function addHeaderText(header: Part, text: string, bothFaces: boolean)
	for _, face in if bothFaces then { Enum.NormalId.Front, Enum.NormalId.Back } else { Enum.NormalId.Front } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(header.Size.X * 50, header.Size.Y * 50)
		gui.LightInfluence = 0.3
		gui.Parent = header
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 0.7)
		label.Position = UDim2.fromScale(0, 0.15)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = rgb(Town.SHELF_LOOK.HEADER_TEXT)
		label.Text = text
		label.Parent = gui
	end
end

function ShelfLooks.isShelf(slot: string): boolean
	return KINDS[slot] ~= nil
end

-- Adds the shelf's parts to model, bottom centre at the origin, front facing -Z
function ShelfLooks.draw(model: Model, slot: string, size: Vector3)
	local kind = KINDS[slot]
	local look = Town.SHELF_LOOK
	local frame = rgb(look.FRAME)
	local boxes = ShelfLayout.build(kind, { x = size.X, y = size.Y, z = size.Z }, stockFor(slot), look)
	for _, box in boxes do
		local boxSize = Vector3.new(box.sx, box.sy, box.sz)
		local cframe = CFrame.new(box.x, box.y, box.z)
		if box.role == "back" then
			if kind == "Pegboard" then
				addPart(model, "Pegboard", boxSize, cframe, rgb(look.PEGBOARD), Enum.Material.Fabric)
			else
				addSlats(model, boxSize, cframe)
			end
		elseif box.role == "plate" then
			local wire = kind == "Pegboard"
			addPart(model, "Plate", boxSize, cframe, rgb(if wire then look.CHROME else look.PLATE_COLOR), if wire then Enum.Material.Metal else Enum.Material.SmoothPlastic)
		elseif box.role == "rail" then
			addPart(model, "Rail", boxSize, cframe, rgb(look.RAIL_COLOR), Enum.Material.SmoothPlastic)
		elseif box.role == "hook" then
			addPart(model, "Hook", boxSize, cframe, rgb(look.CHROME), Enum.Material.Metal)
		elseif box.role == "header" then
			local header = addPart(model, "Header", boxSize, cframe, frame, Enum.Material.SmoothPlastic)
			addHeaderText(header, look.HEADERS[slot] or "", kind == "DoubleRack")
		else
			addPart(model, if box.role == "base" then "Base" else "Post", boxSize, cframe, frame, Enum.Material.Metal)
		end
	end
end

return ShelfLooks
