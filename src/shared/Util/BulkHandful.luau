--!strict
-- A handful of bulk cards (Config/Bulk; owner 2026-11-17, "lets do C"): card backs lying in a loose pile, each turned a
-- little, printed with the shop's card back (Pish and Chikin's medallion, Config/CardDesign BACK). The register's
-- counter shows a whole handful (Bulk.PER cards, RegisterService); the Bulk Bin's heaps a few cards each
-- (PlacementService), one part per card, so a full bin stays light.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Bulk = require(Config:WaitForChild("Bulk"))
local CardDesign = require(Config:WaitForChild("CardDesign"))

local BulkHandful = {}

local LOOK = Bulk.LOOK
local THICK = 0.03 -- one card, studs

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- `count` cards (a handful when nil) lying flat, bottom centre at the origin; `seed` turns each its own way, so two
-- heaps never match
function BulkHandful.build(count: number?, seed: number?): Model
	local model = Instance.new("Model")
	model.Name = "BulkHandful"
	local rng = Random.new(seed or 1)
	local width, height = LOOK.CARD[1], LOOK.CARD[2]
	for index = 1, count or Bulk.PER do
		local card = Instance.new("Part")
		card.Name = "Card"
		card.Size = Vector3.new(width, THICK, height)
		card.Color = rgb(LOOK.CARD_BACK)
		card.Material = Enum.Material.SmoothPlastic
		card.TopSurface = Enum.SurfaceType.Smooth
		card.BottomSurface = Enum.SurfaceType.Smooth
		card.Anchored = true
		card.CanCollide = false
		card.CanQuery = false
		card.CanTouch = false
		card.CastShadow = false
		local turn = math.rad(rng:NextNumber(-40, 40))
		local nudge = Vector3.new(rng:NextNumber(-0.07, 0.07), (index - 0.5) * THICK, rng:NextNumber(-0.07, 0.07))
		card.CFrame = CFrame.new(nudge) * CFrame.Angles(0, turn, 0)
		card.Parent = model
		local back = Instance.new("Decal")
		back.Face = Enum.NormalId.Top
		back.Texture = CardDesign.BACK.IMAGE
		back.Parent = card
	end
	return model
end

return BulkHandful
