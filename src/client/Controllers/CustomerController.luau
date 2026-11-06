--!strict
-- Customers on this client (spec 2026-11-06-customers-design). A collector (model attribute WantedCard, set by
-- CustomerService) shows the card they want, the whole time they're in the shop, in a thought bubble over their head:
-- the card's face in a cotton candy bubble with two small dots trailing down to the head. A kid who ripped a pack at the
-- counter (attribute Pulled = "<cardId>|<grade>|<foil 0/1>") shows their best card growing in over their head for
-- everyone nearby: Very Rare or better with a cheer and the pack opening's hit sound, a Legendary with a light beam
-- (Config/Customers REVEAL). Looks only; the server decides everything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Cards = require(Config:WaitForChild("Cards"))
local CreamTheme = require(Config:WaitForChild("CreamTheme"))
local Customers = require(Config:WaitForChild("Customers"))
local PackOpening = require(Config:WaitForChild("PackOpening"))
local Rarities = require(Config:WaitForChild("Rarities"))
local BeastRules = require(Shared:WaitForChild("Util"):WaitForChild("BeastRules"))
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

local function rarityOrder(rarity: string): number
	local tier = Rarities.Tiers[rarity]
	return if tier then tier.order else 0
end

local function playHit(rarity: string, parent: Instance)
	local key = if rarity == "Legendary" then "hitLegendary" elseif rarity == "Epic" then "hitEpic" else "hitRare"
	local id = PackOpening.SOUNDS[key]
	if not id or id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = PackOpening.VOLUMES[key] or 0.5
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

local function watch(model: Instance)
	if not model:IsA("Model") then
		return
	end
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
