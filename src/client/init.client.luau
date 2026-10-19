--!strict
-- Client entry point. Starts each controller; UIController first since others build on its ScreenGui.
local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local OrderController = require(Controllers:WaitForChild("OrderController"))
local PlacementController = require(Controllers:WaitForChild("PlacementController"))
local BuildController = require(Controllers:WaitForChild("BuildController"))
local PricingController = require(Controllers:WaitForChild("PricingController"))

UIController.Start()
OrderController.Start()
PlacementController.Start()
BuildController.Start()
PricingController.Start()
