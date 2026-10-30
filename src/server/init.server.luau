--!strict
-- Server entry point. Requires and starts each service in dependency order.
-- Services that store player data register with DataService in their Start(); DataService starts
-- last and then drives every player's join (load) and leave (save, unload).
local Services = script:WaitForChild("Services")

local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local MonetizationService = require(Services:WaitForChild("MonetizationService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local CardService = require(Services:WaitForChild("CardService"))
local ItemService = require(Services:WaitForChild("ItemService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local ShowcaseService = require(Services:WaitForChild("ShowcaseService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local StockService = require(Services:WaitForChild("StockService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local PackService = require(Services:WaitForChild("PackService"))
local CondenserService = require(Services:WaitForChild("CondenserService"))
local GradingService = require(Services:WaitForChild("GradingService"))
local JobService = require(Services:WaitForChild("JobService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local WildService = require(Services:WaitForChild("WildService"))
local BattleService = require(Services:WaitForChild("BattleService"))
local ArenaService = require(Services:WaitForChild("ArenaService"))
local BossService = require(Services:WaitForChild("BossService"))
local FrontierService = require(Services:WaitForChild("FrontierService"))
local TownService = require(Services:WaitForChild("TownService"))
local SceneryService = require(Services:WaitForChild("SceneryService"))
local DevService = require(Services:WaitForChild("DevService"))
local DungeonService = require(Services:WaitForChild("DungeonService"))
local DungeonGateService = require(Services:WaitForChild("DungeonGateService"))

local Place = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Place"))

if Place.isDungeon() then
	-- The Dungeon place (one run per reserved server): the run, its fights and the final boss
	EconomyService.Start()
	MonetizationService.Start()
	CardService.Start()
	ItemService.Start()
	JobService.StartLocksOnly() -- before PartyService: cards with a shop job stay out of the party
	PartyService.Start()
	WildService.Start() -- the Dungeon's monsters (no wild map)
	BattleService.Start()
	BossService.Start() -- the Prism Hydra's chamber
	DungeonService.Start() -- the run: arrivals, rooms, carried HP (after BattleService and WildService's cavern)
	FrontierService.Start() -- back to the Frontier
	DevService.Start() -- Studio only
	DataService.Start() -- last: starts loading players
elseif Place.isFrontier() then
	-- The Frontier place: no plots or shop systems, only what the shared high-level map needs.
	-- Data handlers load in this order (and unload in reverse), as in the main game.
	EconomyService.Start()
	MonetizationService.Start()
	CardService.Start()
	ItemService.Start()
	JobService.StartLocksOnly() -- before PartyService: cards with a shop job stay out of the party
	PartyService.Start()
	WildService.Start() -- the Frontier map, its spring and monsters
	BattleService.Start()
	BossService.Start() -- the Frontier bosses: after BattleService and WildService (it uses both)
	FrontierService.Start() -- the Return portal and home button: back to the main game
	DungeonGateService.Start() -- the Dungeon portal: checks, groups, the teleport (after WildService builds the plaza)
	DevService.Start() -- Studio only
	DataService.Start() -- last: starts loading players
else
	PlotService.Start() -- builds the plots everything else uses
	-- Data handlers load in this order (and unload in reverse). CardService loads before
	-- PlacementService so displayed cards that can't be restored go back to the binder.
	EconomyService.Start()
	MonetizationService.Start()
	PricingService.Start()
	CardService.Start()
	ItemService.Start()
	PlacementService.Start()
	StockService.Start()
	ShowcaseService.Start()
	CustomerService.Start()
	RegisterService.Start()
	PackService.Start()
	CondenserService.Start()
	GradingService.Start()
	JobService.Start() -- after CardService, PlacementService and StockService: it loads after them
	PartyService.Start() -- after JobService: party loading checks which cards are working
	WildService.Start() -- wild map, plaza portal, spring and monsters
	BattleService.Start() -- after PartyService: unloads first, so a fight ends before the party unloads
	ArenaService.Start() -- PvP: after BattleService and PartyService (it uses both)
	BossService.Start() -- the boss ladder: after BattleService and WildService (it uses both)
	FrontierService.Start() -- the plaza Frontier portal (after WildService builds the plaza)
	TownService.Start() -- street, decor, portal frames and lighting around the plots and portals
	SceneryService.Start() -- terrain round the town and in the portal areas (after TownService)
	DevService.Start() -- Studio only
	DataService.Start() -- last: starts loading players
end

print(`[Server] Booted ({if Place.isDungeon() then "Dungeon" elseif Place.isFrontier() then "Frontier" else "main game"})`)
