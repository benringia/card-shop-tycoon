--!strict
-- Which place this is: the Frontier (or the Dungeon) if its place id matches Config/Places (published or opened from
-- the experience in Studio), or if frontier.project.json (dungeon.project.json) set the Workspace attribute PlaceKind. Server and client entry scripts start only that place's services, and the wild code reads its world
-- (zones, species, drops) from getWorld().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Wild = require(Config:WaitForChild("Wild"))
local Frontier = require(Config:WaitForChild("Frontier"))
local Places = require(Config:WaitForChild("Places"))
local WildValley = require(Config:WaitForChild("WildValley"))
local FrontierValley = require(Config:WaitForChild("FrontierValley"))
local MonsterLooks = require(script.Parent:WaitForChild("MonsterLooks"))

local Place = {}

function Place.isFrontier(): boolean
	return game.PlaceId == Places.FRONTIER_PLACE_ID or workspace:GetAttribute("PlaceKind") == "Frontier"
end

function Place.isDungeon(): boolean
	return game.PlaceId == Places.DUNGEON_PLACE_ID or workspace:GetAttribute("PlaceKind") == "Dungeon"
end

-- The wild map's config here: the Frontier's in the Frontier and the Dungeon (its rooms use the Frontier's species),
-- the server wild map's in the main game
function Place.getWorld(): typeof(Wild)
	return if Place.isFrontier() or Place.isDungeon() then Frontier :: any else Wild
end

-- The world config that lists a monster species: this place's own first, then the other's (a boss can summon another
-- world's monster: the prologue's Hydra calls the Frontier's Rift Horrors in the main game); nil for an unknown one
function Place.worldOf(species: string): typeof(Wild)?
	local own = Place.getWorld()
	return MonsterLooks.worldOf({ own, if own == Wild then Frontier else Wild }, species)
end

-- The place's valley config (spec 2026-11-10-frontier-valley-design: one valley engine, two valleys): the Wild valley's
-- in the main game, the Frontier valley's in the Frontier; nil in the Dungeon (its cavern is no valley)
function Place.getValley(): any
	if Place.isDungeon() then
		return nil
	end
	return if Place.isFrontier() then FrontierValley else WildValley
end

return Place
