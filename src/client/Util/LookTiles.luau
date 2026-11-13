--!strict
-- Shop decor's look tiles (spec 2026-11-14-shop-decor-design): the first six tiles of the Shop menu's Decor tab, one per
-- shop look (Config/Decor LOOKS), the size of the Build tiles beside them. Each shows a swatch of the look (its wall
-- and wallpaper above the band, trim and floor), its name and a button: "Using" on the look in use, "Use" on one
-- you own, its price (green, pink when you're short) or the level it unlocks at. Pressing asks the server
-- (Remotes.ShopLook); DecorService says no through the Blocked card. Reads the attributes ShopLook, ShopLooksOwned,
-- Level and Cash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Decor = require(Shared:WaitForChild("Config"):WaitForChild("Decor"))
local DecorRules = require(Shared:WaitForChild("Util"):WaitForChild("DecorRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local LookTiles = {}

local PICTURE = 110 -- the swatch's height, like the Build tiles' 3D pictures
local WALLPAPER_TILE = 44 -- pixels a wallpaper repeat on the swatch

type Tile = { look: DecorRules.Look, frame: Frame, button: TextButton }

local player = Players.LocalPlayer

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function attribute(name: string): any
	return player:GetAttribute(name)
end

-- The player's decor as the server last told it
local function state(): DecorRules.State
	local look = attribute("ShopLook")
	local owned = attribute("ShopLooksOwned")
	local list = {}
	if typeof(owned) == "string" then
		for id in string.gmatch(owned, "[^,]+") do
			table.insert(list, id)
		end
	end
	return { look = if typeof(look) == "string" then look else Decor.DEFAULT_LOOK, owned = list }
end

local function swatch(parent: GuiObject, look: DecorRules.Look, background: Color3)
	local frame = Instance.new("Frame")
	frame.Name = "Swatch"
	frame.Position = UDim2.fromOffset(8, 8)
	frame.Size = UDim2.new(1, -16, 0, PICTURE)
	frame.BackgroundColor3 = background
	frame.ClipsDescendants = true
	frame.Parent = parent
	UIKit.corner(frame, 10)
	local wall = Instance.new("Frame")
	wall.Name = "Wall"
	wall.Size = UDim2.fromScale(1, 0.62)
	wall.BackgroundColor3 = rgb(look.wall)
	wall.BorderSizePixel = 0
	wall.Parent = frame
	if look.wallpaper ~= "" then
		local paper = Instance.new("ImageLabel")
		paper.Name = "Wallpaper"
		paper.Size = UDim2.fromScale(1, 1)
		paper.BackgroundTransparency = 1
		paper.Image = look.wallpaper
		paper.ScaleType = Enum.ScaleType.Tile
		paper.TileSize = UDim2.fromOffset(WALLPAPER_TILE, WALLPAPER_TILE)
		paper.Parent = wall
	end
	for _, strip in { { "Band", 0.62, 0.12, look.band }, { "Trim", 0.6, 0.03, look.trim }, { "Floor", 0.74, 0.26, look.floor } } do
		local piece = Instance.new("Frame")
		piece.Name = strip[1] :: string
		piece.Position = UDim2.fromScale(0, strip[2] :: number)
		piece.Size = UDim2.fromScale(1, strip[3] :: number)
		piece.BackgroundColor3 = rgb(strip[4] :: { number })
		piece.BorderSizePixel = 0
		piece.Parent = frame
	end
end

local function refresh(tiles: { Tile })
	local current = state()
	local level = attribute("Level")
	local cash = attribute("Cash")
	level = if typeof(level) == "number" then level else 1
	cash = if typeof(cash) == "number" then cash else 0
	for _, tile in tiles do
		local look, button = tile.look, tile.button
		local using = current.look == look.id
		local owned = DecorRules.owns(Decor, current, look.id)
		local locked = not owned and level < look.level
		button.Text = if using then "Using"
			elseif owned then "Use"
			elseif locked then `🔒 Lv {look.level}`
			else string.format("$%d", look.price)
		-- Soft buttons (UIKit): butter on the look in use, sky to switch, mint to buy, pink when short, grey while locked
		button.BackgroundColor3 = if using then UIKit.Colors.Accent
			elseif owned then UIKit.Colors.Secondary
			elseif locked then UIKit.Colors.Locked
			elseif cash < look.price then UIKit.Colors.Danger
			else UIKit.Colors.Success
		button.AutoButtonColor = not using
	end
end

-- The six look tiles in `list` (LayoutOrder 1-6, so they come before the Build tiles), kept up to date
function LookTiles.build(list: ScrollingFrame, palette: any): { GuiObject }
	local tiles: { Tile } = {}
	local frames: { GuiObject } = {}
	for index, look in Decor.LOOKS do
		local frame = Instance.new("Frame")
		frame.Name = "Look" .. look.id
		frame.LayoutOrder = index
		frame.BackgroundColor3 = palette.row
		frame.Parent = list
		UIKit.corner(frame, 14)
		UIKit.outline(frame)
		swatch(frame, look, palette.slotEmpty)
		local name = UIKit.label(frame, look.name, Enum.Font.FredokaOne, 17, UIKit.Colors.Text)
		name.Position = UDim2.fromOffset(10, PICTURE + 12)
		name.Size = UDim2.new(1, -20, 0, 22)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextWrapped = false
		local detail = UIKit.label(frame, "Shop look", Enum.Font.GothamBold, 13, UIKit.Colors.Subtext)
		detail.Position = UDim2.fromOffset(10, PICTURE + 34)
		detail.Size = UDim2.new(1, -20, 0, 18)
		local button = UIKit.button(frame, "", UIKit.Colors.Success)
		button.AnchorPoint = Vector2.new(0.5, 1)
		button.Position = UDim2.new(0.5, 0, 1, -8)
		button.Size = UDim2.new(1, -16, 0, 48)
		button.Font = Enum.Font.FredokaOne
		button.TextSize = 20
		button.Activated:Connect(function()
			local current = state()
			if current.look == look.id then
				return -- already in use
			end
			Remotes.ShopLook:FireServer(if DecorRules.owns(Decor, current, look.id) then "use" else "buy", look.id)
		end)
		table.insert(tiles, { look = look, frame = frame, button = button })
		table.insert(frames, frame)
	end
	local function update()
		refresh(tiles)
	end
	for _, name in { "ShopLook", "ShopLooksOwned", "Level", "Cash" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
	return frames
end

return LookTiles
