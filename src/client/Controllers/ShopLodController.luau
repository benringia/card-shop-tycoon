--!strict
-- Detail other shops drop on this screen (owner 2026-11-24: "add the two fixes", after six full shops were measured
-- against one; Config/ShopDetail, Util/ShopLod, DESIGN 10.5):
--   Other shops' screens: the price tags, shelf headers, machine screens and box prints the server draws from
--   SCREEN_DISTANCE come in to VISITOR_SCREEN_DISTANCE on every plot but yours (a free plot's too); yours keep theirs.
--   Far shops' stock: every shop's shelf stock (what stands in its shelves' StockBox places: display boxes and packs,
--   deck boxes, booster boxes, sleeves, bulk heaps) hides while the camera is past STOCK_HIDE studs from the shop's
--   floor and shows again within STOCK_SHOW. Its screens stop drawing first (66), so no print floats on its own.
-- Only this screen changes (MaxDistance set here, LocalTransparencyModifier); the server and other players see nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ShopDetail = require(Shared:WaitForChild("Config"):WaitForChild("ShopDetail"))
local ShopLod = require(Shared:WaitForChild("Util"):WaitForChild("ShopLod"))

local ShopLodController = {}

local player = Players.LocalPlayer
-- the distance the server gave each screen, before this client changed it
local given: { [SurfaceGui]: number } = setmetatable({}, { __mode = "k" }) :: any
-- whether each plot's stock shows on this screen (nil: not looked at yet, shown as built)
local stockShown: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isOwn(plot: Instance): boolean
	local plotId = player:GetAttribute("PlotId")
	return typeof(plotId) == "number" and plot.Name == "Plot" .. plotId
end

local function fitScreen(gui: SurfaceGui, own: boolean)
	local server = given[gui]
	if server == nil then
		server = gui.MaxDistance
		given[gui] = server
	end
	gui.MaxDistance = ShopLod.screenDistance(ShopDetail, own, server)
end

local function fitScreens(plot: Instance)
	local own = isOwn(plot)
	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("SurfaceGui") then
			fitScreen(descendant, own)
		end
	end
end

-- Whether `thing` (a part or a decal) is shelf stock: inside a StockBox place on a shelf. The delivery pad's boxes are
-- named StockBox too but stand on the plot itself, not in its Shelves
local function isStock(thing: Instance, plot: Instance): boolean
	local inPlace = false
	local node: Instance? = thing
	while node and node ~= plot do
		if node.Name == "StockBox" then
			inPlace = true
		elseif node.Name == "Shelves" then
			return inPlace
		end
		node = node.Parent
	end
	return false
end

local function hide(thing: Instance, hidden: boolean)
	local modifier = if hidden then 1 else 0
	if thing:IsA("BasePart") then
		thing.LocalTransparencyModifier = modifier
	elseif thing:IsA("Decal") then -- a part's modifier leaves its decals (and textures) drawn
		thing.LocalTransparencyModifier = modifier
	end
end

local function showStock(plot: Instance, shown: boolean)
	local shelves = plot:FindFirstChild("Shelves")
	if not shelves then
		return
	end
	for _, descendant in shelves:GetDescendants() do
		if (descendant:IsA("BasePart") or descendant:IsA("Decal")) and isStock(descendant, plot) then
			hide(descendant, not shown)
		end
	end
end

-- Each shop's stock shown or hidden by how far the camera is from its floor
local function step()
	local camera = workspace.CurrentCamera
	local plots = workspace:FindFirstChild("Plots")
	if not camera or not plots then
		return
	end
	local eye = camera.CFrame.Position
	for _, plot in plots:GetChildren() do
		local floor = plot:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			local at = floor.CFrame:PointToObjectSpace(eye)
			local distance = ShopLod.footprintDistance(at.X, at.Z, floor.Size.X / 2, floor.Size.Z / 2)
			local was = stockShown[plot]
			local shown = ShopLod.stockShown(ShopDetail, distance, was ~= false)
			if shown ~= was then
				stockShown[plot] = shown
				if not (was == nil and shown) then -- as built, everything already shows
					showStock(plot, shown)
				end
			end
		end
	end
end

local function watchPlot(plot: Instance)
	fitScreens(plot)
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("SurfaceGui") then
			fitScreen(descendant, isOwn(plot))
		elseif stockShown[plot] == false and (descendant:IsA("BasePart") or descendant:IsA("Decal")) and isStock(descendant, plot) then
			hide(descendant, true) -- restocked, or streamed in, while the shop is far
		end
	end)
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		fitScreens(plot)
	end)
end

function ShopLodController.Start()
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots")
		for _, plot in plots:GetChildren() do
			watchPlot(plot)
		end
		plots.ChildAdded:Connect(watchPlot)
		player:GetAttributeChangedSignal("PlotId"):Connect(function()
			for _, plot in plots:GetChildren() do
				fitScreens(plot)
			end
		end)
		while true do
			step()
			task.wait(ShopDetail.LOD_CHECK)
		end
	end)
end

return ShopLodController
