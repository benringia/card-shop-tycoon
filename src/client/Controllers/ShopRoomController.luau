--!strict
-- Shop rooms (spec docs/superpowers/specs/2026-11-23-shop-rooms-design.md; Config/ShopRooms): the owner's Unlock
-- prompt on each locked door of their own shop (made here, so visitors never see one; its RequireLevel shows the lock
-- and the level before it's pressed, BlockedController), and the moment a room opens near you: a sparkle burst in its
-- doorway and a chime. The door, its name plate and the room's lights are the server's (PlotService.SetRooms); the
-- owner's words come as a toast (RoomService). A door sliding open is renamed "<door>Opening" by the server: that,
-- not the OpenRooms attribute, marks a real unlock (a save loading its open rooms has no moment).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local RoomsConfig = require(Config:WaitForChild("ShopRooms"))
local PlotConfig = require(Config:WaitForChild("Plots"))
local Placement = require(Config:WaitForChild("Placement"))
local ShopRooms = require(Shared:WaitForChild("Util"):WaitForChild("ShopRooms"))
local OrderRules = require(Shared:WaitForChild("Util"):WaitForChild("OrderRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local ClientUtil = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Util")
local SoundBank = require(ClientUtil:WaitForChild("SoundBank"))

local ShopRoomController = {}

local player = Players.LocalPlayer
local DOORS = ShopRooms.doors(RoomsConfig, ShopRooms.grid(PlotConfig.WIDTH, PlotConfig.DEPTH, Placement.GRID_SIZE))
local CHECK_SECONDS = 0.5
local MOMENT_REACH = 60 -- studs from the doorway: who sees the sparkles and hears the chime
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLD = Color3.fromRGB(255, 225, 140)

local burstFor: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function addPrompt(part: BasePart, door: ShopRooms.Door)
	local room = RoomsConfig.ROOMS[door.room]
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UnlockRoom"
	prompt.ActionText = "Unlock"
	prompt.ObjectText = `{room.name} · {OrderRules.money(room.price)}`
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("RequireLevel", room.level)
	prompt.Triggered:Connect(function()
		Remotes.UnlockRoom:FireServer(door.room)
	end)
	prompt.Parent = part
end

-- Sparkles out of the doorway in its name plate's new colour, and a chime, for anyone near
local function burst(plot: Model, door: ShopRooms.Door, folder: Instance)
	local floor = plot:FindFirstChild("Floor")
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not floor or not floor:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return
	end
	local at = floor.CFrame * CFrame.new(door.x, floor.Size.Y / 2 + door.height / 2, door.z)
	if (root.Position - at.Position).Magnitude > MOMENT_REACH then
		return
	end
	local sign = folder:FindFirstChild("Sign")
	local color = if sign and sign:IsA("BasePart") then sign.Color else GOLD
	local anchor = Instance.new("Part")
	anchor.Name = "RoomOpenFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(door.width, door.height, 0.2)
	anchor.CFrame = at
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Color = ColorSequence.new(color, GOLD)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Rate = 0
	emitter.Parent = anchor
	local sound = SoundBank.make(RoomsConfig.UNLOCK_SOUND)
	sound.Parent = anchor
	anchor.Parent = workspace
	emitter:Emit(60)
	sound:Play()
	task.delay(3, function()
		anchor:Destroy()
	end)
end

local function check()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in plots:GetChildren() do
		local rooms = if plot:IsA("Model") then plot:FindFirstChild("Rooms") else nil
		if not rooms then
			continue
		end
		local own = plot:GetAttribute("OwnerUserId") == player.UserId
		for _, door in DOORS do
			local folder = rooms:FindFirstChild(door.room)
			if not folder then
				continue
			end
			local opening = folder:FindFirstChild(door.part .. "Opening")
			if opening and not burstFor[opening] then
				burstFor[opening] = true
				burst(plot :: Model, door, folder)
			end
			local part = folder:FindFirstChild(door.part)
			if own and part and part:IsA("BasePart") and not part:FindFirstChild("UnlockRoom") then
				addPrompt(part, door)
			end
		end
	end
end

function ShopRoomController.Start()
	task.spawn(function()
		while true do
			check()
			task.wait(CHECK_SECONDS)
		end
	end)
end

return ShopRoomController
