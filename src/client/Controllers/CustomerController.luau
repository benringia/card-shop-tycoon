--!strict
-- Customers on this client (spec 2026-11-06-customers-design). A collector (model attribute WantedCard, set by
-- CustomerService) shows the card they want, the whole time they're in the shop, in a thought bubble over their head:
-- the card's face in a cotton candy bubble with two small dots trailing down to the head. Looks only; the server
-- decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CreamTheme = require(Config:WaitForChild("CreamTheme"))
local Customers = require(Config:WaitForChild("Customers"))
local CardFace = require(((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util"):WaitForChild("CardFace"))

local CustomerController = {}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function round(target: GuiObject, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = target
end

local function outline(target: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(CreamTheme.rowEdge)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
end

-- The trailing dots of a thought bubble, smaller toward the head
local function addDot(gui: BillboardGui, size: number, x: number, y: number)
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromOffset(size, size)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(0.5, x, 1, y)
	dot.BackgroundColor3 = rgb(CreamTheme.row)
	round(dot, UDim.new(1, 0))
	outline(dot)
	dot.Parent = gui
end

local function showWanted(model: Model)
	local cardId = model:GetAttribute("WantedCard")
	local card = if typeof(cardId) == "string" then Cards.ById[cardId] else nil
	local head = model:WaitForChild("Head", 5)
	if not card or not head or head:FindFirstChild("WantedBubble") then
		return
	end
	local look = Customers.COLLECTOR.thought
	local bubbleWidth = look.cardWidth + look.padding * 2
	local bubbleHeight = look.cardHeight + look.padding * 2

	local gui = Instance.new("BillboardGui")
	gui.Name = "WantedBubble"
	gui.Size = UDim2.fromOffset(bubbleWidth, bubbleHeight + 18)
	gui.StudsOffset = Vector3.new(0, look.offsetY, 0)
	gui.MaxDistance = look.maxDistance
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromOffset(bubbleWidth, bubbleHeight)
	bubble.BackgroundColor3 = rgb(CreamTheme.row)
	round(bubble, UDim.new(0, 12))
	outline(bubble)
	bubble.Parent = gui

	local face = Instance.new("Frame")
	face.Size = UDim2.fromOffset(look.cardWidth, look.cardHeight)
	face.Position = UDim2.fromOffset(look.padding, look.padding)
	face.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, false, false)

	addDot(gui, 9, -6, -13)
	addDot(gui, 6, -11, -4)
	gui.Parent = head
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	if model:GetAttribute("WantedCard") ~= nil then
		task.spawn(showWanted, model)
	end
end

function CustomerController.Start()
	task.spawn(function()
		local folder = workspace:WaitForChild("Customers")
		folder.ChildAdded:Connect(watch)
		for _, model in folder:GetChildren() do
			watch(model)
		end
	end)
end

return CustomerController
