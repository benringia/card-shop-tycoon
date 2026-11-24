--!strict
-- The Storage Rack's look (spec docs/superpowers/specs/2026-11-24-storage-racks-design.md; owner 2026-11-24, pick A of the
-- mockups): a warehouse rack of navy steel posts, orange beams front and back under three plywood decks, braced ends and
-- a yellow STORAGE sign on the top beam. Built from parts like the selling shelves (Util/ShelfLooks); Util/Props draws
-- it for Town.SLOTS StorageRack. The model stands on y = 0 with its front (the sign, the boxes' stickers) toward -Z, as
-- every shelf's. Numbers: Config/Storage RACK, the decks' heights SPOTS.decks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Storage = require(Config:WaitForChild("Storage"))
local ShopDetail = require(Config:WaitForChild("ShopDetail"))

local StorageRackLook = {}

local RACK = Storage.RACK

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function add(model: Model, name: string, size: Vector3, cframe: CFrame, color: { number }, material: Enum.Material, shadow: boolean?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = rgb(color)
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = shadow ~= false
	part.Parent = model
	return part
end

-- The sign's word on its front, drawn like the shop's other screens (ShopDetail.SCREEN_DISTANCE: closer for visitors
-- through Util/ShopLod)
local function writeSign(part: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0.6
	gui.MaxDistance = ShopDetail.SCREEN_DISTANCE
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.92, 0.8)
	label.Position = UDim2.fromScale(0.04, 0.1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = RACK.signText
	label.TextColor3 = rgb(RACK.signInk)
	label.Parent = gui
end

function StorageRackLook.draw(model: Model, size: Vector3)
	local width, height, depth = size.X, size.Y, size.Z
	local postX = width / 2 - RACK.inset
	local postZ = depth / 2 - RACK.inset
	local beamLength = width - 2 * RACK.inset - RACK.postWidth -- between the posts
	local metal, plastic, wood = Enum.Material.Metal, Enum.Material.SmoothPlastic, Enum.Material.Wood
	for _, x in { -postX, postX } do
		for _, z in { -postZ, postZ } do
			add(model, "Post", Vector3.new(RACK.postWidth, height, RACK.postWidth), CFrame.new(x, height / 2, z), RACK.post, metal)
			add(model, "Foot", Vector3.new(0.55, 0.08, 0.55), CFrame.new(x, 0.04, z), RACK.foot, metal, false)
		end
		-- each end: three rungs between the front and back posts, two braces zigzagging between them
		local rungs = { 0.6, height * 0.485, height - 0.8 }
		for _, y in rungs do
			add(model, "Rung", Vector3.new(0.1, 0.1, postZ * 2 - RACK.postWidth), CFrame.new(x, y, 0), RACK.post, metal, false)
		end
		for index = 1, 2 do
			local reach = postZ - 0.15
			local from = Vector3.new(x, rungs[index], if index == 1 then -reach else reach)
			local to = Vector3.new(x, rungs[index + 1], if index == 1 then reach else -reach)
			add(model, "Brace", Vector3.new(0.08, 0.08, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), RACK.post, metal, false)
		end
	end
	local beamZ = depth / 2 - 0.12
	for _, top in Storage.SPOTS.decks do
		for _, z in { -beamZ, beamZ } do
			add(model, "Beam", Vector3.new(beamLength, RACK.beamHeight, RACK.beamDepth), CFrame.new(0, top - RACK.beamHeight / 2, z), RACK.beam, plastic)
		end
		add(model, "Deck", Vector3.new(beamLength, RACK.deckThick, depth - 0.38), CFrame.new(0, top - RACK.deckThick / 2, 0), RACK.deck, wood)
	end
	for _, z in { -beamZ, beamZ } do
		add(model, "TopBeam", Vector3.new(beamLength, RACK.beamHeight, RACK.beamDepth), CFrame.new(0, height - 0.2, z), RACK.beam, plastic)
	end
	writeSign(add(model, "Sign", Vector3.new(2.6, 0.55, 0.04), CFrame.new(0, height - 0.2, -(depth / 2 - 0.03)), RACK.sign, plastic, false))
end

return StorageRackLook
