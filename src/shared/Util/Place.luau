--!strict
-- Which place this is. frontier.project.json sets the Workspace attribute PlaceKind = "Frontier"; the main game
-- has none. Server and client entry scripts start only that place's services, and the wild code reads its world
-- (zones, species, drops) from getWorld().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Wild = require(Config:WaitForChild("Wild"))
local Frontier = require(Config:WaitForChild("Frontier"))

local Place = {}

function Place.isFrontier(): boolean
	return workspace:GetAttribute("PlaceKind") == "Frontier"
end

-- The wild map's config here: the Frontier's in the Frontier, the server wild map's in the main game
function Place.getWorld(): typeof(Wild)
	return if Place.isFrontier() then Frontier :: any else Wild
end

return Place
