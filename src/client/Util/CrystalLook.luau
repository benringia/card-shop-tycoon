--!strict
-- The Dungeon's crystal-touched monsters (spec 2026-11-11-dungeon-puzzles; Config/Dungeon CRYSTAL_LOOK): the fight
-- rooms reuse the Frontier's species, so in the Dungeon each one grows a few rainbow prism shards out of its back
-- and glows softly (a Highlight). A look only, on this client; the monster's stats never change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Dungeon = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Dungeon"))

local CrystalLook = {}

local GLOW = Color3.fromRGB(170, 140, 255)

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- Shards along the top of `model` (welded to `root`, so they move with it) and its glow; `height`: the model's height
function CrystalLook.apply(model: Model, root: BasePart, height: number)
	local look = Dungeon.CRYSTAL_LOOK
	local box, size = model:GetBoundingBox()
	local colors = Dungeon.COLORS.CRYSTALS
	for index = 1, look.shards do
		local along = (index - (look.shards + 1) / 2) / look.shards -- spread front to back along the back
		local tall = height * (0.16 + 0.06 * ((index % 2) + 1))
		local shard = Instance.new("Part")
		shard.Name = "CrystalShard"
		shard.Anchored = false
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CanTouch = false
		shard.Massless = true
		shard.CastShadow = false
		shard.Material = Enum.Material.Neon
		shard.Color = rgb(colors[(index - 1) % #colors + 1])
		shard.Transparency = 0.15
		shard.Size = Vector3.new(height * 0.07, tall, height * 0.07)
		local lean = if index % 2 == 0 then 0.35 else -0.35
		shard.CFrame = box * CFrame.new(0, size.Y / 2 - tall * 0.15, along * size.Z * 0.7) * CFrame.Angles(lean, 0, lean * 0.5) * CFrame.new(0, tall / 2, 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = shard
		weld.Parent = shard
		shard.Parent = model
	end
	local glow = Instance.new("Highlight")
	glow.Name = "CrystalGlow"
	glow.FillColor = GLOW
	glow.FillTransparency = 1 - look.glow
	glow.OutlineColor = GLOW
	glow.OutlineTransparency = 0.5
	glow.DepthMode = Enum.HighlightDepthMode.Occluded
	glow.Parent = model
end

return CrystalLook
