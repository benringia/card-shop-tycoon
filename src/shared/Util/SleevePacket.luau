--!strict
-- One retail packet of card sleeves (Town.SHELF_STOCK.SLEEVES): a white backing card with a header tab and hang hole,
-- the sleeves behind a clear window printed with them fanned out, a strip in the product's colour. Built standing, its bottom centre at the model's
-- pivot and its front toward -Z, like the pack models. Sleeves stock on shelves (PlacementService) and a packet lying on
-- the register's counter (RegisterService; owner 2026-11-17: "card sleeves doesnt have a model on the counter") use it.
local Config = (script.Parent :: Instance).Parent:WaitForChild("Config")
local Town = require(Config:WaitForChild("Town"))
local UIIcons = require(Config:WaitForChild("UIIcons"))

local SleevePacket = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

function SleevePacket.build(sleeveColor: Color3, brandColor: Color3): Model
	local look = Town.SHELF_STOCK.SLEEVES
	local card = rgb(look.CARD)
	local width, height, thickness = look.WIDTH, look.HEIGHT, look.THICKNESS
	local model = Instance.new("Model")
	model.Name = "SleevePacket"
	local function piece(name: string, size: Vector3, at: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.SmoothPlastic
		part.Size = size
		part.CFrame = at
		part.Color = color
		part.Parent = model
		return part
	end
	piece("Backing", Vector3.new(width, height, thickness * 0.4), CFrame.new(0, height / 2, thickness * 0.3), card)
	piece("Sleeves", Vector3.new(width - 0.1, height * 0.6, thickness * 0.4), CFrame.new(0, height * 0.52, -thickness * 0.05), sleeveColor)
	local window = piece("Window", Vector3.new(width - 0.06, height * 0.66, thickness * 0.2), CFrame.new(0, height * 0.52, -thickness * 0.35), Color3.new(1, 1, 1))
	window.Material = Enum.Material.Glass
	window.Transparency = look.WINDOW_TRANSPARENCY
	-- the sleeves fanned out on the window (the menus' Sleeves picture), so it reads as card sleeves at a glance (a
	-- plain coloured panel lying on the counter passed for a block)
	local picture = Instance.new("Decal")
	picture.Name = "Print"
	picture.Face = Enum.NormalId.Front
	picture.Texture = UIIcons.Sleeves
	picture.Parent = window
	piece("Brand", Vector3.new(width, height * 0.14, thickness * 0.5), CFrame.new(0, height * 0.07, -thickness * 0.05), brandColor)
	piece("Tab", Vector3.new(width * 0.5, look.TAB, thickness * 0.4), CFrame.new(0, height + look.TAB / 2, thickness * 0.3), card)
	piece("Hole", Vector3.new(0.12, 0.05, thickness * 0.45), CFrame.new(0, height + look.TAB * 0.55, thickness * 0.3), Color3.fromRGB(30, 32, 38))
	model.WorldPivot = CFrame.new()
	return model
end

-- The colours a shelf of sleeves cycles through (each stock slot the next one), and a packet's pick by number
function SleevePacket.color(index: number): Color3
	local colors = Town.SHELF_STOCK.SLEEVES.COLORS
	return rgb(colors[(index - 1) % #colors + 1])
end

return SleevePacket
