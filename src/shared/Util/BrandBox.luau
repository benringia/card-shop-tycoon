--!strict
-- A branded case drawn on a box part (Config/Stock CASE; the user's pick, 2026-10-30): printed in the product's colour,
-- every side with darker bands top and bottom; the front and back show the product's art in a gold frame (its pack
-- art, else Products `art`, else its UI icon), its name and, when given, a dark pill with a count; the ends have hand
-- holes; the lid has the name. All SurfaceGuis on the part itself, so the look goes wherever the part does. Delivery
-- boxes (StockService) and sealed booster boxes on shelves (PlacementService) use it.
local Config = (script.Parent :: Instance).Parent:WaitForChild("Config")
local Packs = require(Config:WaitForChild("Packs"))
local Products = require(Config:WaitForChild("Products"))
local ShopDetail = require(Config:WaitForChild("ShopDetail"))
local Stock = require(Config:WaitForChild("Stock"))
local UIIcons = require(Config:WaitForChild("UIIcons"))

local BrandBox = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function text(parent: GuiObject, words: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = words
	label.Parent = parent
	return label
end

-- Draws the case on `box`. count: the pill's words ("x24"), none when nil. pixelsPerStud: sharper for small boxes.
function BrandBox.draw(box: BasePart, product: Products.Product, count: string?, pixelsPerStud: number?)
	local look = Stock.CASE
	local color = rgb(product.color)
	local band = color:Lerp(Color3.new(0, 0, 0), look.DARKEN)
	local pack = Packs.ById[product.id]
	local printed = if pack and pack.art then pack.art else product.art
	local art = printed or (UIIcons :: any)[product.icon]
	box.Color = color
	box.Material = Enum.Material.SmoothPlastic
	local function side(normal: Enum.NormalId): Frame
		local gui = Instance.new("SurfaceGui")
		gui.Face = normal
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud or look.PIXELS_PER_STUD
		gui.MaxDistance = ShopDetail.SCREEN_DISTANCE
		gui.Parent = box
		local face = Instance.new("Frame")
		face.Size = UDim2.fromScale(1, 1)
		face.BackgroundColor3 = color
		face.BorderSizePixel = 0
		face.Parent = gui
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215))
		shade.Parent = face
		if normal ~= Enum.NormalId.Top then
			for _, top in { true, false } do
				local strip = Instance.new("Frame")
				strip.AnchorPoint = Vector2.new(0, if top then 0 else 1)
				strip.Position = UDim2.fromScale(0, if top then 0 else 1)
				strip.Size = UDim2.fromScale(1, look.BAND)
				strip.BackgroundColor3 = band
				strip.BorderSizePixel = 0
				strip.Parent = face
			end
		end
		return face
	end
	for _, normal in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local face = side(normal)
		if art then
			local picture = Instance.new("ImageLabel")
			picture.Position = UDim2.fromScale(look.ART[1], look.ART[2])
			picture.Size = UDim2.fromScale(look.ART[3], look.ART[4])
			picture.BackgroundColor3 = band
			picture.Image = art
			picture.ScaleType = if printed then Enum.ScaleType.Crop else Enum.ScaleType.Fit
			picture.Parent = face
			local frame = Instance.new("UIStroke")
			frame.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			frame.Color = rgb(look.FRAME)
			frame.Thickness = 4
			frame.Parent = picture
		end
		local right = look.ART[1] + look.ART[3] + 0.04
		local nameHeight = if count then 0.44 else 0.66
		local name = text(face, string.upper(product.name), Color3.new(1, 1, 1), UDim2.fromScale(right, 0.15), UDim2.fromScale(0.96 - right, nameHeight))
		name.TextStrokeTransparency = 0.35
		if count then
			local pill = Instance.new("Frame")
			pill.Position = UDim2.fromScale(right + 0.04, 0.63)
			pill.Size = UDim2.fromScale(0.88 - right, 0.2)
			pill.BackgroundColor3 = rgb(look.PILL)
			pill.Parent = face
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = pill
			text(pill, count, rgb(look.FRAME), UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.8, 0.76))
		end
	end
	for _, normal in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local hole = Instance.new("Frame")
		hole.AnchorPoint = Vector2.new(0.5, 0.5)
		hole.Position = UDim2.fromScale(0.5, 0.3)
		hole.Size = UDim2.fromScale(0.34, 0.13)
		hole.BackgroundColor3 = rgb(look.HANDLE)
		hole.Parent = side(normal)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = hole
	end
	local lid = side(Enum.NormalId.Top)
	text(lid, string.upper(product.name), Color3.new(1, 1, 1), UDim2.fromScale(0.1, 0.3), UDim2.fromScale(0.8, 0.4)).TextStrokeTransparency = 0.35
end

return BrandBox
