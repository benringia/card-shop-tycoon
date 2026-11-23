--!strict
-- The Shop window's tiles (BuildController's shelves, Util/LookTiles' looks, WindowController.Tiles' windows: each
-- builds the same tile, a picture at the top, a name, a line, a button along the bottom; Config/ShopTiles).
-- dress: the catalog look (owner 2026-11-23, pick A of artifact VSged5WBCtnhC9mcjegfiu): the line under the name as
-- chips (Util/ShopTileRules.chips), a coin beside a price, "You have N" over the picture (the tile's Owned attribute).
-- compact: on a phone (pre-launch QA 2026-11-19) a row tile, picture on the left, so it shows whole in a phone's short
-- list. The tiles' pieces are found by where their builders put them (the picture at 8, 8; the name and the line under).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopTiles = require(Shared:WaitForChild("Config"):WaitForChild("ShopTiles"))
local ShopTileRules = require(Shared:WaitForChild("Util"):WaitForChild("ShopTileRules"))
local OrderRules = require(Shared:WaitForChild("Util"):WaitForChild("OrderRules"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local Icon = require(ClientUtil:WaitForChild("Icon"))

local ShopTile = {}

local PICTURE_AT = UDim2.fromOffset(8, 8)
local NAME_Y = ShopTiles.FULL.picture + 12
local DETAIL_Y = ShopTiles.FULL.picture + 34

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- A small rounded label (the chips, the owned badge)
local function tag(parent: Instance, text: string, height: number, textSize: number, fill: Color3, ink: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.fromOffset(0, height)
	label.BackgroundColor3 = fill
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.TextColor3 = ink
	label.Text = text
	label.Parent = parent
	UIKit.corner(label, height / 2)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = label
	return label
end

-- The list's grid cell: two row tiles to a row on a phone, three tiles filling the row elsewhere
function ShopTile.cell(phone: boolean): (UDim2, UDim2)
	if phone then
		local look = ShopTiles.PHONE
		return UDim2.new(1 / look.columns, -look.gap, 0, look.height), UDim2.fromOffset(look.gap, look.gap)
	end
	local full = ShopTiles.FULL
	return UDim2.new(1 / full.columns, -full.gap, 0, full.height), UDim2.fromOffset(full.gap, full.gap)
end

-- The line under the name as chips: the builders' line split at " · " (the first chip mint, the rest lavender)
local function chips(tile: GuiObject, line: TextLabel)
	local look = ShopTiles.CHIPS
	local row = Instance.new("Frame")
	row.Name = "Chips"
	row.BackgroundTransparency = 1
	row.Position = line.Position
	row.Size = UDim2.new(1, -20, 0, look.height)
	row.ClipsDescendants = true
	row.ZIndex = line.ZIndex
	row.Parent = tile
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row
	local function fill()
		for _, child in row:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for index, chip in ShopTileRules.chips(line.Text) do
			local colors = if chip.main then look.main else look.soft
			local made = tag(row, chip.text, look.height, look.textSize, rgb(colors.fill), rgb(colors.ink))
			made.LayoutOrder = index
			made.ZIndex = row.ZIndex + 1
		end
	end
	fill()
	line:GetPropertyChangedSignal("Text"):Connect(fill)
	line.Visible = false
end

-- A coin beside a price ("$350"), the two centred together on the button; none on other words ("Use", "🔒 Lv 9")
local function coin(button: TextButton)
	local look = ShopTiles.COIN
	local picture = Icon.make(button, "Coin", UDim2.fromOffset(look.size, look.size))
	picture.Name = "Coin"
	picture.AnchorPoint = Vector2.new(0.5, 0.5)
	picture.ZIndex = button.ZIndex + 1
	local padding = button:FindFirstChildOfClass("UIPadding")
	local function place()
		local price = ShopTileRules.isPrice(button.Text)
		picture.Visible = price
		if padding then
			padding.PaddingLeft = UDim.new(0, if price then look.size + look.gap else 0)
		end
		-- the padding moves the text and the coin alike: the coin sits just left of the text, centred on its row
		picture.Position = UDim2.new(0.5, -(button.TextBounds.X / 2) - look.gap - look.size / 2, 0.5, 0)
	end
	place()
	button:GetPropertyChangedSignal("Text"):Connect(place)
	button:GetPropertyChangedSignal("TextBounds"):Connect(place)
	button:GetPropertyChangedSignal("ZIndex"):Connect(function()
		picture.ZIndex = button.ZIndex + 1
	end)
end

-- "You have N" over the picture's top-left corner while the tile's Owned attribute is above 0
local function ownedBadge(tile: GuiObject)
	local look = ShopTiles.OWNED
	local badge = tag(tile, "", look.height, look.textSize, rgb(look.fill), rgb(look.ink))
	badge.Name = "Owned"
	badge.Position = UDim2.fromOffset(14, 14)
	badge.ZIndex = tile.ZIndex + 5
	local function update()
		local count = tile:GetAttribute("Owned")
		local text = ShopTileRules.ownedText(if typeof(count) == "number" then count else 0)
		badge.Visible = text ~= nil
		badge.Text = text or ""
	end
	update()
	tile:GetAttributeChangedSignal("Owned"):Connect(update)
end

-- A built tile in the catalog look: its line as chips, a coin on its price, the owned badge
function ShopTile.dress(tile: GuiObject)
	for _, child in tile:GetChildren() do
		if child:IsA("TextButton") then
			coin(child)
		elseif child:IsA("TextLabel") and child.Position.Y.Offset == DETAIL_Y then
			chips(tile, child)
		end
	end
	ownedBadge(tile)
end

-- The player's cash in the window's header, beside the close button
function ShopTile.cashChip(panel: GuiObject, headerHeight: number)
	local player = Players.LocalPlayer
	local chip = UIKit.pill(panel, "", Color3.new(1, 1, 1), nil, "Coin")
	chip.Name = "Cash"
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -84, 0, headerHeight / 2)
	chip.Size = UDim2.fromOffset(0, 32)
	chip.TextSize = UIKit.textSize("body")
	chip.ZIndex = panel.ZIndex + 4
	local function update()
		local cash = player:GetAttribute("Cash")
		chip.Text = OrderRules.money(if typeof(cash) == "number" then math.floor(cash) else 0)
	end
	update()
	player:GetAttributeChangedSignal("Cash"):Connect(update)
end

-- How many of each shelf the player has placed, on its tile's Owned attribute (tiles named by their Shelves id),
-- kept up to date as shelves are placed and sold
function ShopTile.trackOwned(list: Instance)
	local player = Players.LocalPlayer
	local watching: { RBXScriptConnection } = {}
	local function count(folder: Instance?)
		local counts: { [string]: number } = {}
		for _, shelf in if folder then folder:GetChildren() else {} do
			local id = shelf:GetAttribute("ShelfId")
			if typeof(id) == "string" then
				counts[id] = (counts[id] or 0) + 1
			end
		end
		for _, tile in list:GetChildren() do
			if tile:IsA("GuiObject") then
				tile:SetAttribute("Owned", counts[tile.Name] or 0)
			end
		end
	end
	local function watch()
		for _, connection in watching do
			connection:Disconnect()
		end
		table.clear(watching)
		local plotId = player:GetAttribute("PlotId")
		local plots = workspace:FindFirstChild("Plots")
		local plot = if typeof(plotId) == "number" and plots then plots:FindFirstChild("Plot" .. plotId) else nil
		local folder = if plot then plot:FindFirstChild("Shelves") else nil
		count(folder)
		if folder then
			local function recount()
				task.defer(count, folder)
			end
			table.insert(watching, folder.ChildAdded:Connect(recount))
			table.insert(watching, folder.ChildRemoved:Connect(recount))
		end
	end
	watch()
	player:GetAttributeChangedSignal("PlotId"):Connect(watch)
end

-- A piece's full-tile layout, kept before a phone's row tile moves it, so expand can put it back
local function remember(child: GuiObject)
	if child:GetAttribute("FullPosition") ~= nil then
		return
	end
	child:SetAttribute("FullPosition", child.Position)
	child:SetAttribute("FullSize", child.Size)
	child:SetAttribute("FullAnchor", child.AnchorPoint)
	if child:IsA("TextLabel") or child:IsA("TextButton") then
		child:SetAttribute("FullTextSize", child.TextSize)
		child:SetAttribute("FullWrapped", child.TextWrapped)
		child:SetAttribute("FullTruncate", child.TextTruncate == Enum.TextTruncate.AtEnd)
	end
end

-- A phone's row tile back as the full tile (the window grew past a phone's height)
function ShopTile.expand(tile: GuiObject)
	for _, child in tile:GetChildren() do
		if not child:IsA("GuiObject") or child:GetAttribute("FullPosition") == nil then
			continue
		end
		child.Position = child:GetAttribute("FullPosition") :: UDim2
		child.Size = child:GetAttribute("FullSize") :: UDim2
		child.AnchorPoint = child:GetAttribute("FullAnchor") :: Vector2
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			child.TextSize = child:GetAttribute("FullTextSize") :: number
			child.TextWrapped = child:GetAttribute("FullWrapped") == true
			child.TextTruncate = if child:GetAttribute("FullTruncate") == true then Enum.TextTruncate.AtEnd else Enum.TextTruncate.None
		end
	end
end

-- A built tile as a phone's row tile
function ShopTile.compact(tile: GuiObject)
	local row = ShopTileRules.row(ShopTiles)
	for _, child in tile:GetChildren() do
		if not child:IsA("GuiObject") then
			continue
		end
		local full = child:GetAttribute("FullPosition")
		local at = if typeof(full) == "UDim2" then full else child.Position -- where its builder put it
		if child:IsA("TextButton") or at == PICTURE_AT or child.Name == "Owned" or at.Y.Offset == NAME_Y or at.Y.Offset == DETAIL_Y then
			remember(child)
		end
		if child:IsA("TextButton") then
			-- the button: under the words, beside the picture, finger-sized
			child.AnchorPoint = Vector2.new(1, 1)
			child.Position = UDim2.new(1, -row.margin, 1, -row.margin)
			child.Size = UDim2.new(1, -(row.beside + row.margin), 0, row.button)
		elseif at == PICTURE_AT then
			child.Size = UDim2.fromOffset(row.picture, row.picture)
		elseif child.Name == "Owned" then
			child.Position = UDim2.fromOffset(row.margin + 2, row.margin + 2) -- the picture's corner
		elseif child:IsA("TextLabel") and at.Y.Offset == NAME_Y then
			child.Position = UDim2.fromOffset(row.beside, row.nameY)
			child.Size = UDim2.new(1, -(row.beside + row.margin), 0, row.nameHeight)
			child.TextSize = ShopTiles.PHONE.nameSize
		elseif at.Y.Offset == DETAIL_Y then
			-- the line, or its chips once dressed
			child.Position = UDim2.fromOffset(row.beside, row.detailY)
			child.Size = UDim2.new(1, -(row.beside + row.margin), 0, if child.Name == "Chips" then ShopTiles.CHIPS.height else row.detailHeight)
			if child:IsA("TextLabel") then
				child.TextSize = ShopTiles.PHONE.detailSize
				child.TextTruncate = Enum.TextTruncate.AtEnd
				child.TextWrapped = false
			end
		end
	end
end

return ShopTile
