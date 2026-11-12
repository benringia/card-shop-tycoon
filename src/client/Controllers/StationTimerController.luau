--!strict
-- A countdown over your own station machines while they hold a job (spec 2026-11-12-timed-upgrades-revive-design): a
-- small cotton candy tag floating over the Condenser, the Grading Station and the Forge in your shop ("0:28"), gone when
-- the job is. Counts down from Util/StationJobs; your machines are the parts of those names with a ShelfUid in the
-- plot whose OwnerUserId is yours.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local UpgradeRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("UpgradeRules"))

local Controllers = script.Parent :: Instance
local ClientUtil = (Controllers.Parent :: Instance):WaitForChild("Util")
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local StationJobs = require(ClientUtil:WaitForChild("StationJobs"))

local StationTimerController = {}

local STATION_OF = { Condenser = "condenser", GradingStation = "grading", Forge = "forge" } -- machine name -> station
local TAG = { width = 96, height = 34, up = 4.5, maxDistance = 70 }
local player = Players.LocalPlayer

local tags: { [BasePart]: { gui: BillboardGui, label: TextLabel, station: string } } = {}

local function isMine(part: Instance): boolean
	local at: Instance? = part.Parent
	while at and at ~= workspace do
		local owner = at:GetAttribute("OwnerUserId")
		if owner ~= nil then
			return owner == player.UserId
		end
		at = at.Parent
	end
	return false
end

local function tagFor(part: BasePart, station: string)
	if tags[part] then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "JobTimer"
	gui.Size = UDim2.fromOffset(TAG.width, TAG.height)
	gui.StudsOffsetWorldSpace = Vector3.new(0, TAG.up, 0)
	gui.MaxDistance = TAG.maxDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Enabled = false
	gui.Adornee = part
	gui.Parent = part
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Parent = gui
	UIKit.corner(pill, TAG.height / 2)
	UIKit.outline(pill, UIKit.Colors.Accent, 3)
	local label = UIKit.label(pill, "", Enum.Font.FredokaOne, 18, Color3.fromRGB(80, 60, 90))
	label.Size = UDim2.fromScale(1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	tags[part] = { gui = gui, label = label, station = station }
	part.AncestryChanged:Connect(function()
		if not part:IsDescendantOf(workspace) then
			tags[part] = nil
		end
	end)
end

local function consider(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local station = STATION_OF[part.Name]
	if station and part:GetAttribute("ShelfUid") and isMine(part) then
		tagFor(part, station)
	end
end

function StationTimerController.Start()
	for _, descendant in workspace:GetDescendants() do
		consider(descendant)
	end
	workspace.DescendantAdded:Connect(function(descendant)
		task.defer(consider, descendant) -- its ShelfUid and plot are set just after it arrives
	end)
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < 0.25 then
			return
		end
		since = 0
		for _, tag in tags do
			local job = StationJobs.get(tag.station)
			tag.gui.Enabled = job ~= nil
			if job then
				tag.label.Text = `⏳ {UpgradeRules.clock(job.left)}`
			end
		end
	end)
end

return StationTimerController
