--!strict
-- A station window's job (spec 2026-11-12-timed-upgrades-revive-design: one job at a time, the item inside till its
-- time is up, "Finish now" for Robux): while the Condenser, Grading Station or Forge holds one, a soft veil covers the
-- window's actions with a card: what's inside and what it's becoming, a countdown with its bar, and "Finish now · R$ X"
-- (the developer product for the time left: SkipS / SkipM / SkipL; "Coming soon" while its id is 0). The window's X
-- still closes it. Counts down from Util/StationJobs.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Monetization = require(Config:WaitForChild("Monetization"))
local Upgrades = require(Config:WaitForChild("Upgrades"))
local UpgradeRules = require(Shared:WaitForChild("Util"):WaitForChild("UpgradeRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientUtil = script.Parent :: Instance
local UIKit = require(ClientUtil:WaitForChild("UIKit"))
local StationJobs = require(ClientUtil:WaitForChild("StationJobs"))
local ScreenClear = require(ClientUtil:WaitForChild("ScreenClear"))
local ProductPrice = require(ClientUtil:WaitForChild("ProductPrice"))

local JobPanel = {}

local CARD = { width = 380, height = 236 }
-- The skip product for this much time left: its id (0: not created yet)
local function productFor(left: number): number
	local id = Monetization.PRODUCTS[`Skip{UpgradeRules.tier(Upgrades, left)}`]
	return if typeof(id) == "number" then id else 0
end

-- The veil and card over `window` (a UIKit.panel) for `station`
function JobPanel.attach(window: Frame, station: string)
	local palette = UIKit.colorsFor(window)
	local veil = Instance.new("TextButton") -- a button, so taps on the actions under it go nowhere
	veil.Name = "JobVeil"
	veil.Text = ""
	veil.AutoButtonColor = false
	veil.Position = UDim2.fromOffset(0, UIKit.HEADER_HEIGHT)
	veil.Size = UDim2.new(1, 0, 1, -UIKit.HEADER_HEIGHT)
	veil.BackgroundColor3 = palette.row
	veil.BackgroundTransparency = 0.25
	veil.ZIndex = 40
	veil.Visible = false
	veil.Parent = window
	UIKit.corner(veil, 18)

	local card = Instance.new("Frame")
	card.Name = "JobCard"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(CARD.width, CARD.height)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.ZIndex = 41
	card.Parent = veil
	UIKit.corner(card, 18)
	UIKit.outline(card, palette.rowEdge, 3)
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(CARD.width, CARD.height)
	fit.Parent = card

	local function line(text: string, font: Enum.Font, size: number, color: Color3, y: number, height: number): TextLabel
		local label = UIKit.label(card, text, font, size, color)
		label.Position = UDim2.new(0, 16, 0, y)
		label.Size = UDim2.new(1, -32, 0, height)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 42
		return label
	end
	line(`In the {Upgrades.STATIONS[station] or station}`, Enum.Font.FredokaOne, 15, palette.hint, 12, 18)
	local name = line("", Enum.Font.FredokaOne, 22, palette.ink, 32, 26)
	local detail = line("", Enum.Font.GothamBold, 14, palette.inkSoft, 58, 18)
	local clock = line("", Enum.Font.FredokaOne, 28, palette.ink, 82, 32)
	local track = Instance.new("Frame")
	track.Position = UDim2.new(0, 24, 0, 120)
	track.Size = UDim2.new(1, -48, 0, 10)
	track.BackgroundColor3 = palette.rowEdge
	track.ZIndex = 42
	track.Parent = card
	UIKit.corner(track, 5)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UIKit.Colors.Accent
	fill.ZIndex = 43
	fill.Parent = track
	UIKit.corner(fill, 5)
	local finish = UIKit.button(card, "Finish now", UIKit.Colors.Accent)
	finish.Name = "FinishNow"
	finish.AnchorPoint = Vector2.new(0.5, 0)
	finish.Position = UDim2.new(0.5, 0, 0, 144)
	finish.Size = UDim2.fromOffset(240, 48)
	finish.ZIndex = 42
	local note = line("It comes back on its own when the time is up.", Enum.Font.GothamBold, 12, palette.inkSoft, 200, 18)
	note.TextWrapped = true

	local productId = 0
	finish.Activated:Connect(function()
		if productId == 0 then
			return -- "Coming soon": the button says so
		end
		Remotes.SkipUpgrade:FireServer(station)
		ScreenClear.prompt()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
	end)

	local sinceDraw = 0
	local function draw()
		local job = StationJobs.get(station)
		veil.Visible = job ~= nil
		if not job then
			return
		end
		name.Text = job.name
		detail.Text = job.detail
		clock.Text = UpgradeRules.clock(job.left)
		fill.Size = UDim2.fromScale(math.clamp(1 - job.left / job.total, 0, 1), 1)
		productId = productFor(job.left)
		local price = ProductPrice.of(productId)
		finish.Text = if productId == 0 then "Finish now · Coming soon" elseif price then `Finish now · R$ {price}` else "Finish now"
		finish.AutoButtonColor = productId ~= 0
		finish.BackgroundTransparency = if productId == 0 then 0.45 else 0
	end
	StationJobs.onChanged(draw)
	RunService.Heartbeat:Connect(function(dt)
		sinceDraw += dt
		if window.Visible and sinceDraw >= 0.25 then
			sinceDraw = 0
			draw()
		end
	end)
	window:GetPropertyChangedSignal("Visible"):Connect(draw)
	draw()
end

return JobPanel
