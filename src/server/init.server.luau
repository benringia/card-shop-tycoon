--!strict
-- Server entry point. Requires and starts each service in dependency order.
local Services = script:WaitForChild("Services")

local EconomyService = require(Services:WaitForChild("EconomyService"))
local PricingService = require(Services:WaitForChild("PricingService"))
local PlacementService = require(Services:WaitForChild("PlacementService"))
local CustomerService = require(Services:WaitForChild("CustomerService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local StockService = require(Services:WaitForChild("StockService"))

EconomyService.Start()
PricingService.Start()
-- These register plot callbacks, so they must start before PlotService
PlacementService.Start()
CustomerService.Start()
PlotService.Start()
StockService.Start() -- needs plots built

print("[Server] Booted")
