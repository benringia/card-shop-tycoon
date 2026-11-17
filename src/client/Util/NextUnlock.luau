--!strict
-- The shop's next unlock under its level bar (owner 2026-11-17, the first 15 minutes: a new player always has a next
-- goal): "Lv 3: Card Sleeves +1", from what each level opens (Products, the Build menu's shelves, cases and fixtures,
-- the first sword, shop jobs, the bosses; LevelUpRules.nextUnlockText). Follows the Level attribute; empty at the top.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Products = require(Config:WaitForChild("Products"))
local Shelves = require(Config:WaitForChild("Shelves"))
local Swords = require(Config:WaitForChild("Swords"))
local Jobs = require(Config:WaitForChild("Jobs"))
local Bosses = require(Config:WaitForChild("Bosses"))
local LevelUpRules = require(Shared:WaitForChild("Util"):WaitForChild("LevelUpRules"))
local UIKit = require((script.Parent :: Instance):WaitForChild("UIKit"))

local NextUnlock = {}

local player = Players.LocalPlayer

-- Everything a shop level opens, products first (they're what a level-up usually means to a new shop)
local function unlocks(): { { level: number, name: string } }
	local list = {}
	for _, product in Products.List do
		if not product.bulk then -- the Bulk Bin is the unlock (its shelf below)
			table.insert(list, { level = product.unlockLevel, name = product.name })
		end
	end
	for _, def in Shelves.List do
		if not def.requiresItem and def.kind ~= "Decor" then -- trophies come from bosses; decor is its own tab
			table.insert(list, { level = def.unlockLevel, name = def.name })
		end
	end
	table.insert(list, { level = Swords.UNLOCK_SHOP_LEVEL, name = "Your first sword" })
	table.insert(list, { level = Jobs.UNLOCK_LEVEL, name = "Shop jobs" })
	for _, id in Bosses.LADDER do
		local boss = Bosses.BOSSES[id]
		if boss and boss.shopLevel then
			table.insert(list, { level = boss.shopLevel, name = boss.name })
		end
	end
	return list
end

-- A small outlined line at `position` in `parent`, `width` px wide
function NextUnlock.attach(parent: GuiObject, position: UDim2, width: number): TextLabel
	local list = unlocks()
	local label = UIKit.label(parent, "", Enum.Font.FredokaOne, 12, Color3.new(1, 1, 1))
	label.Name = "NextUnlock"
	label.Position = position
	label.Size = UDim2.fromOffset(width, 15)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.ZIndex = 3
	UIKit.outlined(label, 1.5)
	local function refresh()
		local level = tonumber(player:GetAttribute("Level")) or 1
		local text = LevelUpRules.nextUnlockText(level, list)
		label.Text = if text then `🔓 {text}` else ""
		label.Visible = text ~= nil
	end
	player:GetAttributeChangedSignal("Level"):Connect(refresh)
	refresh()
	return label
end

return NextUnlock
