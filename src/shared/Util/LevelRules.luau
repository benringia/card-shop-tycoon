--!strict
-- XP → level maths shared by EconomyService and the HUD (the maths itself is Util/LevelMath; no level cap).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Levels = require(Config:WaitForChild("Levels"))
local Products = require(Config:WaitForChild("Products"))
local Shelves = require(Config:WaitForChild("Shelves"))
local LevelMath = require((script.Parent :: Instance):WaitForChild("LevelMath"))

local LevelRules = {}

function LevelRules.getLevelForXp(xp: number): number
	return LevelMath.getLevelForXp(Levels, xp)
end

-- Total XP needed to reach a level
function LevelRules.getRequiredXp(level: number): number
	return LevelMath.getRequiredXp(Levels, level)
end

-- XP earned inside the current level and the XP that level spans
function LevelRules.getProgress(xp: number): (number, number)
	return LevelMath.getProgress(Levels, xp)
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
