--!strict
-- The Dungeon run's line (Dungeon place only): a slim strip at the top left with where the run is ("Room 2 of 3", "The
-- Prism Hydra's chamber"), the server's run messages as toasts, and a Leave button (tap twice) back to the Frontier.
-- The run itself is DungeonService's.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local UIController = require(Controllers:WaitForChild("UIController"))

local DungeonController = {}

local LINE_WIDTH = 230
local LINE_HEIGHT = 30
local BUTTON_SIZE = 48
local TOP = 8
local LEFT = 96 -- clear of the Manage tray
local CONFIRM_SECONDS = 3

local line: TextLabel
local leaveButton: TextButton
local confirmUntil = 0

local function textFor(state: any): string
	local stage = state.stage
	if stage == "waiting" then
		return "⏳ Waiting for your group..."
	elseif stage == "room" then
		return `⚔ Room {state.room} of {state.rooms}`
	elseif stage == "boss" then
		return "🐉 The Prism Hydra's chamber"
	elseif stage == "won" then
		return "🏆 Dungeon conquered!"
	elseif stage == "out" then
		return "Out of the run"
	end
	return "The Dungeon"
end

local function onRun(state: unknown)
	if typeof(state) ~= "table" then
		return
	end
	local run = state :: any
	line.Text = textFor(run)
	line.Visible = true
	if typeof(run.message) == "string" and run.message ~= "" then
		UIController.Notify(run.message, run.stage == "out", 3)
	end
end

local function onLeave()
	local now = os.clock()
	if now > confirmUntil then
		confirmUntil = now + CONFIRM_SECONDS
		leaveButton.Text = "Sure?"
		task.delay(CONFIRM_SECONDS, function()
			if os.clock() >= confirmUntil then
				leaveButton.Text = "Leave"
			end
		end)
		return
	end
	confirmUntil = 0
	leaveButton.Text = "Leave"
	Remotes.DungeonLeave:FireServer()
end

function DungeonController.Start()
	local gui = UIController.GetScreenGui()
	line = UIKit.label(gui, "The Dungeon", Enum.Font.FredokaOne, 16, UIKit.Colors.Text)
	line.Name = "DungeonRun"
	line.Position = UDim2.fromOffset(LEFT, TOP)
	line.Size = UDim2.fromOffset(LINE_WIDTH, LINE_HEIGHT)
	line.BackgroundColor3 = UIKit.Colors.Panel
	line.BackgroundTransparency = 0.25
	line.TextXAlignment = Enum.TextXAlignment.Center
	UIKit.corner(line, 10)
	leaveButton = UIKit.button(gui, "Leave", UIKit.Colors.Danger)
	leaveButton.Name = "DungeonLeave"
	leaveButton.Position = UDim2.fromOffset(LEFT + LINE_WIDTH + 8, TOP - (BUTTON_SIZE - LINE_HEIGHT) / 2)
	leaveButton.Size = UDim2.fromOffset(BUTTON_SIZE * 1.6, BUTTON_SIZE)
	leaveButton.TextSize = 15
	leaveButton.Activated:Connect(onLeave)
	Remotes.DungeonRun.OnClientEvent:Connect(onRun)
	Remotes.DungeonRun:FireServer() -- the arrival message may have come before this listened
end

return DungeonController
