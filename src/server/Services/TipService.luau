--!strict
-- Tips shown the first few times (owner 2026-11-17: "make sure players know you can put packs in the bag"): how many
-- times each tip has shown, saved as tips (Config/Tips, Util/TipRules). A service asks Next when a tip's moment comes
-- and calls Done once the player has done what the tip teaches.
local Services = script.Parent :: Instance
local Util = (Services.Parent :: Instance):WaitForChild("Util")
local DataService = require(Services:WaitForChild("DataService"))
local TipRules = require(Util:WaitForChild("TipRules"))

type PlayerData = DataService.PlayerData

local TipService = {}

local tipsByPlayer: { [Player]: TipRules.Tips } = {}

-- Whether the tip shows now (it's counted when it does); never before the player's tips have loaded
function TipService.Next(player: Player, id: string, shows: number): boolean
	local tips = tipsByPlayer[player]
	if not tips then
		return false
	end
	local updated, show = TipRules.next(tips, id, shows)
	tipsByPlayer[player] = updated
	return show
end

-- The player did what the tip teaches: it never shows again
function TipService.Done(player: Player, id: string, shows: number)
	local tips = tipsByPlayer[player]
	if tips then
		tipsByPlayer[player] = TipRules.done(tips, id, shows)
	end
end

local function load(player: Player, data: PlayerData)
	tipsByPlayer[player] = TipRules.clean(data.tips)
end

local function save(player: Player, data: PlayerData)
	local tips = tipsByPlayer[player]
	if tips then
		data.tips = table.clone(tips)
	end
end

local function unload(player: Player)
	tipsByPlayer[player] = nil
end

function TipService.Start()
	DataService.Register({ name = "TipService", load = load, save = save, unload = unload })
end

return TipService
