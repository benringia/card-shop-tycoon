--!strict
-- Client entry point. Starts each controller; UIController first since others build on its ScreenGui.
local Controllers = script:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local OrderController = require(Controllers:WaitForChild("OrderController"))

UIController.Start()
OrderController.Start()
