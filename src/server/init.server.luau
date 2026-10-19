--!strict
-- Server entry point. Requires and starts each service in dependency order.
local Services = script:WaitForChild("Services")

local EconomyService = require(Services:WaitForChild("EconomyService"))
local PlotService = require(Services:WaitForChild("PlotService"))
local StockService = require(Services:WaitForChild("StockService"))

EconomyService.Start()
PlotService.Start()
StockService.Start() -- needs plots built

print("[Server] Booted")
