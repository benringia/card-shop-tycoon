--!strict
-- The NEW tag on a Shop or Order Stock tile (owner 2026-11-19: Pish no longer runs in for every unlock; the main quest
-- strip and this tag carry the plain shelves and new stock): a small pink pill at the tile's top right while the
-- thing unlocked at this shop level or the one before (ShopTileRules.isNew). Still, never pulsing.
local NewTag = {}

local NAME = "NewTag"
local PINK = Color3.fromRGB(255, 92, 138)

-- Shows or removes the tag on `tile`
function NewTag.set(tile: Instance?, on: boolean)
	if not tile or not tile:IsA("GuiObject") then
		return
	end
	local tag = tile:FindFirstChild(NAME)
	if not on then
		if tag then
			tag:Destroy()
		end
		return
	end
	if tag then
		return
	end
	local pill = Instance.new("TextLabel")
	pill.Name = NAME
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -6, 0, 6)
	pill.Size = UDim2.fromOffset(44, 20)
	pill.BackgroundColor3 = PINK
	pill.Font = Enum.Font.FredokaOne
	pill.Text = "NEW"
	pill.TextSize = 13
	pill.TextColor3 = Color3.new(1, 1, 1)
	pill.ZIndex = tile.ZIndex + 5
	pill.Parent = tile
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = pill
	local rim = Instance.new("UIStroke")
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Color = Color3.new(1, 1, 1)
	rim.Thickness = 2
	rim.Parent = pill
end

return NewTag
