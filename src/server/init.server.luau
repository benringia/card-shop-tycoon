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
local PlacementService = require(Services:WaitForChild("PlacementService"))
local ShowcaseService = require(Services:WaitForChild("ShowcaseService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local StockService = require(Services:WaitForChild("StockService"))
local RegisterService = require(Services:WaitForChild("RegisterService"))
local PackService = require(Services:WaitForChild("PackService"))
local CondenserService = require(Services:WaitForChild("CondenserService"))
local JobService = require(Services:WaitForChild("JobService"))
local PartyService = require(Services:WaitForChild("PartyService"))
local DevService = require(Services:WaitForChild("DevService"))

PlotService.Start() -- builds the plots everything else uses
-- Data handlers load in this order (and unload in reverse). CardService loads before
-- PlacementService so displayed cards that can't be restored go back to the binder.
EconomyService.Start()
MonetizationService.Start()
PricingService.Start()
CardService.Start()
PlacementService.Start()
StockService.Start()
ShowcaseService.Start()
CustomerService.Start()
RegisterService.Start()
PackService.Start()
CondenserService.Start()
JobService.Start() -- after CardService, PlacementService and StockService: it loads after them
PartyService.Start() -- after JobService: party loading checks which cards are working
DevService.Start() -- Studio only
DataService.Start() -- last: starts loading players

print("[Server] Booted")
