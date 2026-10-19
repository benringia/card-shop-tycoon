--!strict
-- XP → level maths shared by EconomyService and the HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Levels = require(Config:WaitForChild("Levels"))
local Products = require(Config:WaitForChild("Products"))
local Shelves = require(Config:WaitForChild("Shelves"))

local XP_REQUIRED: { number } = Levels.XP_REQUIRED

local LevelRules = {}

LevelRules.MAX_LEVEL = #XP_REQUIRED

function LevelRules.getLevelForXp(xp: number): number
	local level = 1
	for index, required in XP_REQUIRED do
		if xp >= required then
			level = index
		end
	end
	return level
end

-- XP earned inside the current level and XP that level spans; span is nil at max level
function LevelRules.getProgress(xp: number): (number, number?)
	local level = LevelRules.getLevelForXp(xp)
	local floor = XP_REQUIRED[level]
	local nextRequired = XP_REQUIRED[level + 1]
	if not nextRequired then
		return xp - floor, nil
	end
	return xp - floor, nextRequired - floor
end

-- Names of products and shelves that unlock exactly at this level
function LevelRules.getUnlocks(level: number): { string }
	local names: { string } = {}
	for _, product in Products.List do
		if product.unlockLevel == level then
			table.insert(names, product.name)
		end
	end
	for _, shelf in Shelves.List do
		if shelf.unlockLevel == level then
			table.insert(names, shelf.name)
		end
	end
	return names
end

return LevelRules
