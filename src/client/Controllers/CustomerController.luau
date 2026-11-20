--!strict
-- Customers on this client (spec 2026-11-06-customers-design). A collector (model attribute WantedCard, set by
-- CustomerService) shows the card they want, the whole time they're in the shop, in a thought bubble over their head:
-- the card's face in a cotton candy bubble with two small dots trailing down to the head. A kid who ripped a pack at the
-- counter (attribute Pulled = "<cardId>|<grade>|<foil 0/1>") shows their best card growing in over their head for
-- everyone nearby: Very Rare or better with a cheer and the pack opening's hit sound, a Legendary with a light beam
-- (Config/Customers REVEAL). And what customers say (owner 2026-11-19: "add personalities for the customers like chat
-- bubbles"): a speech bubble over one when its Say attribute changes (Config/CustomerChat, Util/ChatRules), in its
-- type's voice. Looks only; the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CreamTheme = require(Config:WaitForChild("CreamTheme"))
local Customers = require(Config:WaitForChild("Customers"))
local CustomerChat = require(Config:WaitForChild("CustomerChat"))
local ChatRules = require(Shared:WaitForChild("Util"):WaitForChild("ChatRules"))
local RevealSounds = require(Config:WaitForChild("RevealSounds"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local CardFace = require(ClientUtil:WaitForChild("CardFace"))
local UIKit = require(ClientUtil:WaitForChild("UIKit"))

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

local function rarityOrder(rarity: string): number
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.order else 0
end

-- A customer's big pull: its rarity's main reveal hit (Config/RevealSounds), heard round the shop
local function playHit(rarity: string, parent: Instance)
	local look = RevealSounds.BY_RARITY[rarity]
	if not look then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = look.hit[1].id
	sound.Volume = look.hit[1].volume * Customers.REVEAL.hitVolume -- someone else's pull: well under your own
	sound.RollOffMaxDistance = Customers.REVEAL.maxDistance
	sound.Parent = parent
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- A column of light rising from a Legendary pull, fading out
local function lightBeam(at: Vector3)
	local look = Customers.REVEAL.beam
	local beam = Instance.new("Part")
	beam.Name = "PullBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
	beam.Transparency = look.transparency
	beam.Size = Vector3.new(look.height, look.width, look.width)
	beam.CFrame = CFrame.new(at + Vector3.new(0, look.height / 2 - 3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Parent = workspace
	local fade = TweenService:Create(beam, TweenInfo.new(look.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
	fade.Completed:Once(function()
		beam:Destroy()
	end)
	fade:Play()
end

local function showPull(model: Model)
	local value = model:GetAttribute("Pulled")
	if typeof(value) ~= "string" then
		return
	end
	local cardId, grade, foil = string.match(value, "^([^|]+)|([^|]+)|([01])$")
	local card = if cardId then Cards.ById[cardId] else nil
	local head = model:FindFirstChild("Head")
	if not card or not head or not head:IsA("BasePart") or not BeastRules.isGrade(grade) then
		return
	end
	local look = Customers.REVEAL
	local gui = Instance.new("BillboardGui")
	gui.Name = "PullReveal"
	gui.Size = UDim2.fromOffset(look.cardWidth, look.cardHeight + 40)
	gui.StudsOffset = Vector3.new(0, look.offsetY, 0)
	gui.MaxDistance = look.maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local face = Instance.new("Frame")
	face.AnchorPoint = Vector2.new(0.5, 1)
	face.Position = UDim2.fromScale(0.5, 1)
	face.Size = UDim2.fromOffset(look.cardWidth, look.cardHeight)
	face.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = face
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	CardFace.render(face, stroke, card, foil == "1", false, { level = 1, stars = BeastRules.START_STARS, grade = grade :: string })

	local big = rarityOrder(card.rarity) >= rarityOrder(look.cheerFrom)
	if big then
		local cheer = Instance.new("TextLabel")
		cheer.BackgroundTransparency = 1
		cheer.Size = UDim2.new(1, 0, 0, 34)
		cheer.TextScaled = true
		cheer.Text = look.cheer
		cheer.Parent = gui
		playHit(card.rarity, head)
	end
	if card.rarity == "Legendary" then
		lightBeam(head.Position)
	end
	gui.Parent = head

	local grow = TweenInfo.new(look.growSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(scale, grow, { Scale = 1 }):Play()
	task.delay(look.growSeconds + look.holdSeconds, function()
		if not gui.Parent then
			return
		end
		local shrink = TweenService:Create(scale, TweenInfo.new(look.growSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		shrink.Completed:Once(function()
			gui:Destroy()
		end)
		shrink:Play()
	end)
end

-- What the customer says now (its Say attribute): a white speech bubble with a little tail, popping in over the head
-- (above the mood icon; above a collector's card or a kid's pull) and fading after CustomerChat.SECONDS
local CHAT_INK = Color3.fromRGB(80, 60, 90)

local function showChat(model: Model)
	local said = ChatRules.decode(model:GetAttribute("Say"))
	local head = model:FindFirstChild("Head")
	if not said or not head or not head:IsA("BasePart") then
		return
	end
	local kind = model:GetAttribute("CustomerType")
	local line = ChatRules.text(CustomerChat, if typeof(kind) == "string" then kind else "plain", said.moment, said.index, said.word)
	if not line then
		return
	end
	local old = head:FindFirstChild("ChatBubble")
	if old then
		old:Destroy()
	end
	local high = head:FindFirstChild("WantedBubble") ~= nil or head:FindFirstChild("PullReveal") ~= nil
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChatBubble"
	gui.Size = UDim2.fromOffset(CustomerChat.WIDTH, CustomerChat.HEIGHT + 14)
	gui.StudsOffsetWorldSpace = Vector3.new(0, if high then CustomerChat.OFFSET_Y_COLLECTOR else CustomerChat.OFFSET_Y, 0)
	gui.MaxDistance = CustomerChat.MAX_DISTANCE
	gui.LightInfluence = 0
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = holder

	-- the tail: a small square on its corner under the bubble
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 0, CustomerChat.HEIGHT - 2)
	tail.Size = UDim2.fromOffset(18, 18)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.new(1, 1, 1)
	tail.BorderSizePixel = 0
	tail.Parent = holder
	local tailStroke = Instance.new("UIStroke")
	tailStroke.Color = rgb(CreamTheme.rowEdge)
	tailStroke.Thickness = 2
	tailStroke.Parent = tail

	local bubble = Instance.new("Frame")
	bubble.AnchorPoint = Vector2.new(0.5, 0)
	bubble.Position = UDim2.fromScale(0.5, 0)
	bubble.Size = UDim2.fromOffset(0, CustomerChat.HEIGHT)
	bubble.AutomaticSize = Enum.AutomaticSize.X
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.Parent = holder
	round(bubble, UDim.new(0, 16))
	local stroke = Instance.new("UIStroke")
	stroke.Color = rgb(CreamTheme.rowEdge)
	stroke.Thickness = 2
	stroke.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.Parent = bubble
	-- the tail's top half hides behind this patch, so only its point shows under the bubble
	local text = UIKit.label(bubble, line, Enum.Font.FredokaOne, 19, CHAT_INK)
	text.BackgroundColor3 = Color3.new(1, 1, 1)
	text.BackgroundTransparency = 0
	text.BorderSizePixel = 0
	text.AutomaticSize = Enum.AutomaticSize.X
	text.Size = UDim2.new(0, 0, 1, -4)
	text.Position = UDim2.fromOffset(0, 2)
	text.TextXAlignment = Enum.TextXAlignment.Center
	text.TextWrapped = false
	gui.Parent = head

	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(CustomerChat.SECONDS, function()
		if not gui.Parent then
			return
		end
		local shrink = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		shrink.Completed:Once(function()
			gui:Destroy()
		end)
		shrink:Play()
	end)
end

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
	model:GetAttributeChangedSignal("Say"):Connect(function()
		showChat(model)
	end)
	if model:GetAttribute("WantedCard") ~= nil then
		task.spawn(showWanted, model)
	end
	-- A walker becomes a shop's collector at its door (the card arrives then) and leaves it there on the way out
	model:GetAttributeChangedSignal("WantedCard"):Connect(function()
		if model:GetAttribute("WantedCard") ~= nil then
			showWanted(model)
			return
		end
		local head = model:FindFirstChild("Head")
		local bubble = if head then head:FindFirstChild("WantedBubble") else nil
		if bubble then
			bubble:Destroy()
		end
	end)
	-- A kid rips their pack after paying, so Pulled arrives later
	model:GetAttributeChangedSignal("Pulled"):Connect(function()
		showPull(model)
	end)
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
