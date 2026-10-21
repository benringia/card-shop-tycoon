--!strict
-- Which place this is: the Frontier if its place id matches Config/Places (published or opened from the
-- experience in Studio), or if frontier.project.json set the Workspace attribute PlaceKind = "Frontier". Server and client entry scripts start only that place's services, and the wild code reads its world
-- (zones, species, drops) from getWorld().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Wild = require(Config:WaitForChild("Wild"))
local Frontier = require(Config:WaitForChild("Frontier"))
local Places = require(Config:WaitForChild("Places"))

local Place = {}

function Place.isFrontier(): boolean
	return game.PlaceId == Places.FRONTIER_PLACE_ID or workspace:GetAttribute("PlaceKind") == "Frontier"
end

-- The wild map's config here: the Frontier's in the Frontier, the server wild map's in the main game
function Place.getWorld(): typeof(Wild)
	return if Place.isFrontier() then Frontier :: any else Wild
end

return Place
