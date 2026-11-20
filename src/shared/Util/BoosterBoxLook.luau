--!strict
-- A sealed booster box (owner 2026-11-20: "improve booster box design on shelf and cashier"; it was a plain yellow
-- shipping case with a hand hole: Util/BrandBox). Printed like a real one: the set's art across every side inside a
-- gold rim, the set's name in gold on a dark band along the top and "BOOSTER BOX" on a band in the product's colour
-- along the bottom, the card back's seal on the ends, and a little shine like shrink wrap. All SurfaceGuis on the part
-- itself, so the look goes wherever the part does: on shelves (PlacementService) and the register's counter
-- (RegisterService). Numbers in Config/Stock BOOSTER_BOX; its words from Util/PropFit.boosterWords.
local Shared = (script.Parent :: Instance).Parent :: Instance
local Config = Shared:WaitForChild("Config")
local CardDesign = require(Config:WaitForChild("CardDesign"))
local Products = require(Config:WaitForChild("Products"))
local ShopDetail = require(Config:WaitForChild("ShopDetail"))
local Stock = require(Config:WaitForChild("Stock"))
local UIIcons = require(Config:WaitForChild("UIIcons"))
local PropFit = require(script.Parent:WaitForChild("PropFit"))

local BoosterBoxLook = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function band(parent: GuiObject, top: boolean, height: number, color: Color3, transparency: number): Frame
	local strip = Instance.new("Frame")
	strip.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	strip.Position = UDim2.fromScale(0, if top then 0 else 1)
	strip.Size = UDim2.fromScale(1, height)
	strip.BackgroundColor3 = color
	strip.BackgroundTransparency = transparency
	strip.BorderSizePixel = 0
	strip.Parent = parent
	return strip
end

local function words(parent: GuiObject, text: string, color: Color3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.88, 0.74)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
end

-- Draws the box on `box`. pixelsPerStud: sharper for a small box.
function BoosterBoxLook.draw(box: BasePart, product: Products.Product, pixelsPerStud: number?)
	local look = Stock.BOOSTER_BOX
	local gold = look.RIM
	local art = product.art or (UIIcons :: any)[product.icon]
	local title, kind = PropFit.boosterWords(product.name)
	box.Color = look.DARK
	box.Material = Enum.Material.SmoothPlastic
	box.Reflectance = look.SHINE
	local function side(normal: Enum.NormalId): Frame
		local gui = Instance.new("SurfaceGui")
		gui.Face = normal
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = pixelsPerStud or Stock.CASE.PIXELS_PER_STUD
		gui.MaxDistance = ShopDetail.SCREEN_DISTANCE
		gui.Parent = box
		local face = Instance.new("Frame")
		face.Size = UDim2.fromScale(1, 1)
		face.BackgroundColor3 = look.DARK
		face.BorderSizePixel = 0
		face.Parent = gui
		return face
	end
	local function rim(face: Frame)
		local edge = Instance.new("Frame")
		edge.BackgroundTransparency = 1
		edge.Size = UDim2.fromScale(1, 1)
		edge.Parent = face
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = gold
		stroke.Thickness = look.RIM_PIXELS
		stroke.Parent = edge
		-- the stroke draws outside its frame: pull the frame in so the rim stays on the face
		edge.Position = UDim2.fromOffset(look.RIM_PIXELS, look.RIM_PIXELS)
		edge.Size = UDim2.new(1, -2 * look.RIM_PIXELS, 1, -2 * look.RIM_PIXELS)
	end
	-- the printed sides: the art across the whole face, the set's name over it, what it is under it
	for _, normal in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top } do
		local face = side(normal)
		local lid = normal == Enum.NormalId.Top
		local ends = normal == Enum.NormalId.Front or normal == Enum.NormalId.Back
		if art then
			local picture = Instance.new("ImageLabel")
			picture.Size = UDim2.fromScale(1, 1)
			picture.BackgroundColor3 = look.DARK
			picture.BorderSizePixel = 0
			picture.Image = art
			picture.ScaleType = Enum.ScaleType.Crop
			picture.Parent = face
		end
		words(band(face, true, if lid then look.LID_BAND else look.TITLE_BAND, look.DARK, look.BAND_SEE_THROUGH), title, gold)
		if kind ~= "" then
			words(band(face, false, if lid then look.LID_BAND * 0.8 else look.KIND_BAND, rgb(product.color), 0), kind, look.DARK)
		end
		if ends then
			-- the seal: the card back's medallion in a gold ring, in the middle of the art
			local seal = Instance.new("ImageLabel")
			seal.AnchorPoint = Vector2.new(0.5, 0.5)
			seal.Position = UDim2.fromScale(0.5, 0.5 + (look.TITLE_BAND - look.KIND_BAND) / 2)
			seal.Size = UDim2.fromScale(look.SEAL, look.SEAL)
			seal.SizeConstraint = Enum.SizeConstraint.RelativeYY
			seal.BackgroundColor3 = look.DARK
			seal.Image = CardDesign.BACK.IMAGE
			seal.ScaleType = Enum.ScaleType.Crop
			seal.Parent = face
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = seal
			local ring = Instance.new("UIStroke")
			ring.Color = gold
			ring.Thickness = look.RIM_PIXELS
			ring.Parent = seal
		end
		rim(face)
	end
end

return BoosterBoxLook
