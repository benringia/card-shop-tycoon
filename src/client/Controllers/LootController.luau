--!strict
-- Boss loot on the ground (BossService): this player's own drops pop out of the boss and scatter round it; walking
-- over one asks the server to pick it up (it checks the drop is yours and you're close). Nothing here replicates, so
-- nobody else sees your drops. Nothing is collected by itself: loot has to be picked up.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local Bosses = require(Config:WaitForChild("Bosses"))
local Items = require(Config:WaitForChild("Items"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Controllers = script.Parent :: Instance
local UIController = require(Controllers:WaitForChild("UIController"))

local LootController = {}

local player = Players.LocalPlayer
local POP_SECONDS = 0.6 -- the arc out of the boss
local POP_HEIGHT = 4
local BOB = { height = 0.6, swing = 0.25, speed = 3, spin = 2 }
local RETRY_SECONDS = 1 -- ask again if the server didn't answer
local sentAt = 0 -- os.clock() of the last pickup request (one request names every drop in reach)
local FLY = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local DROP_COLOR = Color3.fromRGB(255, 205, 80)

type Drop = { part: BasePart, item: string, count: number, from: Vector3, target: Vector3, born: number, askedAt: number }
local drops: { [string]: Drop } = {}

local function itemName(id: string): (string, string)
	local item = Items.ITEMS[id]
	if not item then
		return id, ""
	end
	return item.name, if string.match(item.icon, "^%a") then "" else item.icon -- emoji icons only
end

local function vector(raw: any): Vector3?
	if typeof(raw) == "table" and typeof(raw.x) == "number" and typeof(raw.y) == "number" and typeof(raw.z) == "number" then
		return Vector3.new(raw.x, raw.y, raw.z)
	end
	return nil
end

local function spawnDrop(id: string, item: string, count: number, from: Vector3, target: Vector3)
	local part = Instance.new("Part")
	part.Name = "BossLoot"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.4, 1.4, 1.4)
	part.Material = Enum.Material.Neon
	part.Color = DROP_COLOR
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.new(from)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 34)
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	local name, icon = itemName(item)
	label.Text = `{icon} {if count > 1 then `{count} x ` else ""}{name}`
	label.Parent = gui
	gui.Parent = part
	part.Parent = workspace
	drops[id] = { part = part, item = item, count = count, from = from, target = target, born = os.clock(), askedAt = 0 }
end

-- Picked up: it flies to you and the toast says what you got
local function taken(id: string)
	local drop = drops[id]
	if not drop then
		return
	end
	drops[id] = nil
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if root then
		TweenService:Create(drop.part, FLY, { CFrame = root.CFrame, Size = Vector3.new(0.3, 0.3, 0.3) }):Play()
		task.delay(FLY.Time, function()
			drop.part:Destroy()
		end)
	else
		drop.part:Destroy()
	end
	local name, icon = itemName(drop.item)
	UIController.Notify(`{icon} +{drop.count} {name}`, false, 1.5)
end

local function onLoot(payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.taken) == "string" then
		taken(payload.taken)
		return
	end
	local from = vector(payload.from)
	if not from or typeof(payload.drops) ~= "table" then
		return
	end
	for _, entry in payload.drops do
		local target = vector(entry)
		if typeof(entry) == "table" and target and typeof(entry.id) == "string" and typeof(entry.item) == "string" and typeof(entry.count) == "number" then
			spawnDrop(entry.id, entry.item, entry.count, from, target)
		end
	end
end

local function step()
	local now = os.clock()
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local ask: { string } = {}
	for id, drop in drops do
		local age = now - drop.born
		local position: Vector3
		if age < POP_SECONDS then
			local share = age / POP_SECONDS
			position = drop.from:Lerp(drop.target, share) + Vector3.new(0, POP_HEIGHT * math.sin(math.pi * share) + BOB.height * share, 0)
		else
			position = drop.target + Vector3.new(0, BOB.height + math.sin(now * BOB.speed) * BOB.swing, 0)
		end
		drop.part.CFrame = CFrame.new(position) * CFrame.Angles(0, now * BOB.spin, 0)
		local near = root ~= nil and (root.Position - drop.target).Magnitude <= Bosses.LOOT_CLIENT_REACH
		if near and age >= POP_SECONDS and now - drop.askedAt >= RETRY_SECONDS and #ask < Bosses.LOOT_PICKUP_BATCH then
			table.insert(ask, id)
		end
	end
	-- One request for every drop in reach, never faster than the server's limit (so none is turned away)
	if #ask > 0 and now - sentAt >= Bosses.LOOT_PICKUP_COOLDOWN then
		sentAt = now
		for _, id in ask do
			drops[id].askedAt = now
		end
		Remotes.PickUpLoot:FireServer(ask)
	end
end

function LootController.Start()
	Remotes.BossLoot.OnClientEvent:Connect(onLoot)
	RunService.RenderStepped:Connect(step)
end

return LootController
