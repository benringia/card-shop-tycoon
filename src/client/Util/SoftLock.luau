--!strict
-- The soft lock in fights (owner 2026-11-15, look A: "Ring under the enemy + arrow over it"; Config/SoftLock,
-- Util/SoftLockRules): no camera lock. Tap or click an enemy, press Tab or the fight's Target button to lock it: a gold
-- ring under it and a bobbing gold arrow over it with "Target"; your sword turns to it as you attack
-- (SwordController's soft aim asks `locked`) and the server points your creature at it (Remotes.SoftLock,
-- BattleSim.setFocus). Tapping it again, or it falling, lets go. With nothing locked a soft white ring shows who your
-- sword would hit (the nearest in front, SwordRules.aimTarget). SwordController starts and stops it with the fight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SoftLockConfig = require(Config:WaitForChild("SoftLock"))
local Swords = require(Config:WaitForChild("Swords"))
local SwordFx = require(Config:WaitForChild("SwordFx"))
local SoftLockRules = require(Shared:WaitForChild("Util"):WaitForChild("SoftLockRules"))
local SwordRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SoftLock = {}

type Target = SoftLockRules.Target
type Look = { color: { number }, glow: { number }, outline: number, glowTransparency: number, pulse: number }

local player = Players.LocalPlayer
local getTargets: (() -> { Target })? = nil
local lockedId: string? = nil
local sentId: string? = nil
local lastSent = 0
local pendingSend = false
local connections: { RBXScriptConnection } = {}
local folder: Folder? = nil
local ringPart: Part? = nil
local glowPart: Part? = nil
local arrowAnchor: Part? = nil
local arrowGui: BillboardGui? = nil
local segments: { BasePart } = {}
local press: { at: Vector2, clock: number }? = nil

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

-- The server hears the lock (one change per REMOTE_GAP; the latest one goes)
local function send()
	if sentId == lockedId then
		return
	end
	local wait = SoftLockConfig.REMOTE_GAP - (os.clock() - lastSent)
	if wait > 0 then
		if not pendingSend then
			pendingSend = true
			task.delay(wait, function()
				pendingSend = false
				send()
			end)
		end
		return
	end
	lastSent = os.clock()
	sentId = lockedId
	Remotes.SoftLock:FireServer(lockedId)
end

local function setLock(id: string?)
	if id ~= lockedId then
		lockedId = id
		send()
	end
end

local function flat(name: string, image: string): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 0.05, 1)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = image
	decal.Parent = part
	part.Parent = folder
	return part
end

-- The arrow over a locked target: the owner's pick, three glossy gold chevrons (Config/SoftLock ARROW.image)
local function buildArrow()
	local anchor = Instance.new("Part")
	anchor.Name = "TargetArrow"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	local size = SoftLockConfig.ARROW.size
	gui.Size = UDim2.fromOffset(size, size)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor
	local picture = Instance.new("ImageLabel")
	picture.Name = "Chevrons"
	picture.BackgroundTransparency = 1
	picture.Image = SoftLockConfig.ARROW.image
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Size = UDim2.fromScale(1, 1)
	picture.Parent = gui
	arrowAnchor = anchor
	arrowGui = gui
end

-- The neon pieces of the solid ring (SEGMENTS.count, each a short curved-looking block round the circle)
local function buildSegments()
	segments = {}
	for index = 1, SoftLockConfig.SEGMENTS.count do
		local piece = Instance.new("Part")
		piece.Name = `Ring{index}`
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Material = Enum.Material.Neon
		piece.Parent = folder
		table.insert(segments, piece)
	end
end

-- The pieces round (x, z) at height y, `across` studs wide, in `color`
local function placeSegments(x: number, y: number, z: number, across: number, color: Color3, transparency: number, shown: boolean)
	local look = SoftLockConfig.SEGMENTS
	local radius = across / 2
	local length = 2 * math.pi * radius / look.count * 1.08 -- a little overlap: no gaps
	local frames: { CFrame } = {}
	for index, piece in segments do
		if not shown then
			piece.Transparency = 1
			continue
		end
		local angle = (index - 1) / look.count * math.pi * 2
		piece.Size = Vector3.new(length, look.tall, look.thick)
		piece.Color = color
		piece.Transparency = transparency
		frames[index] = CFrame.new(x + math.cos(angle) * radius, y, z + math.sin(angle) * radius) * CFrame.Angles(0, -angle - math.pi / 2, 0)
	end
	if shown then
		workspace:BulkMoveTo(segments, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function rootOf(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Your feet's height: the arenas are flat, so the ring lies there under any enemy
local function groundY(root: BasePart): number
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position.Y - root.Size.Y / 2 - hip + SoftLockConfig.RING_LIFT
end

local function find(targets: { Target }, id: string?): Target?
	for _, target in targets do
		if target.id == id then
			return target
		end
	end
	return nil
end

local function paint(part: Part, color: Color3, transparency: number)
	local decal = part:FindFirstChildOfClass("Decal")
	if decal then
		decal.Color3 = color
		decal.Transparency = transparency
	end
end

-- Each frame: the lock lets go once its enemy is gone; the ring and arrow sit on the locked enemy, or (white, no
-- arrow) on the one your sword would hit
local function step()
	local root = rootOf()
	local ring, halo, anchor, gui = ringPart, glowPart, arrowAnchor, arrowGui
	if not getTargets or not root or not ring or not halo or not anchor or not gui then
		return
	end
	local targets = getTargets()
	if lockedId and not SoftLockRules.has(targets, lockedId) then
		setLock(nil)
	end
	local look = root.CFrame.LookVector
	local autoId = SwordRules.aimTarget(root.Position.X, root.Position.Z, look.X, look.Z, targets, Swords.SOFT_AIM_RANGE, Swords.SOFT_AIM_ANGLE)
	local shown = find(targets, lockedId or autoId)
	if not shown then
		ring.Parent, halo.Parent, anchor.Parent = nil, nil, nil
		placeSegments(0, 0, 0, 1, Color3.new(), 1, false)
		return
	end
	ring.Parent, halo.Parent = folder, folder
	local style: Look = if lockedId then SoftLockConfig.LOCKED else SoftLockConfig.AUTO
	local pulse = 1 + style.pulse * math.sin(os.clock() * 5)
	local across = math.max(shown.radius * 2 + SoftLockConfig.RING_MARGIN * 2, SoftLockConfig.RING_MIN) * pulse
	local y = groundY(root)
	local spot = CFrame.new(shown.x, y, shown.z)
	ring.Size = Vector3.new(across * SwordFx.RING_FIT.outline, 0.05, across * SwordFx.RING_FIT.outline)
	ring.CFrame = spot
	halo.Size = Vector3.new(across * SwordFx.RING_FIT.glow * 1.08, 0.05, across * SwordFx.RING_FIT.glow * 1.08)
	halo.CFrame = spot + Vector3.new(0, 0.02, 0)
	paint(ring, rgb(style.color), style.outline)
	paint(halo, rgb(style.glow), style.glowTransparency)
	local pieces = SoftLockConfig.SEGMENTS
	placeSegments(shown.x, y, shown.z, across * 0.96, rgb(style.color), if lockedId then pieces.lockedTransparency else pieces.autoTransparency, true)
	if lockedId then
		local arrow = SoftLockConfig.ARROW
		local top = (shown :: any).top or (y + math.max(shown.radius * 2, 5)) -- its model's top when known
		local height = top + arrow.above + arrow.bob * math.sin(os.clock() * arrow.bobSpeed)
		-- under the top HUD (a big boss's head): slide down its body until it's ARROW_MIN_Y px below the screen's top
		local camera = workspace.CurrentCamera
		if camera then
			local low, high = y + 1, height
			if camera:WorldToViewportPoint(Vector3.new(shown.x, high, shown.z)).Y < SoftLockConfig.ARROW_MIN_Y then
				for _ = 1, 10 do
					local middle = (low + high) / 2
					if camera:WorldToViewportPoint(Vector3.new(shown.x, middle, shown.z)).Y < SoftLockConfig.ARROW_MIN_Y then
						high = middle
					else
						low = middle
					end
				end
				height = low
			end
		end
		-- toward the camera by its radius: in front of a big boss's body, not inside it
		local toward = if camera then Vector3.new(camera.CFrame.Position.X - shown.x, 0, camera.CFrame.Position.Z - shown.z) else Vector3.zero
		local nudge = if toward.Magnitude > 0.1 then toward.Unit * shown.radius else Vector3.zero
		anchor.CFrame = CFrame.new(shown.x + nudge.X, height, shown.z + nudge.Z)
		anchor.Parent = folder
	else
		anchor.Parent = nil
	end
end

-- A tap or click on an enemy locks it (on it again: lets go); empty ground keeps the lock
local function tapAt(point: Vector2)
	local camera = workspace.CurrentCamera
	local root = rootOf()
	if not getTargets or not camera or not root then
		return
	end
	local y = groundY(root)
	local onScreen: { SoftLockRules.OnScreen } = {}
	for _, target in getTargets() do
		local height = math.max(target.radius * 1.1, 2.5)
		local middle, visible = camera:WorldToScreenPoint(Vector3.new(target.x, y + height, target.z))
		if visible then
			local right = camera.CFrame.RightVector * target.radius
			local edge = camera:WorldToScreenPoint(Vector3.new(target.x, y + height, target.z) + right)
			local r = (Vector2.new(edge.X, edge.Y) - Vector2.new(middle.X, middle.Y)).Magnitude
			table.insert(onScreen, { id = target.id, x = middle.X, y = middle.Y, r = math.max(r, 20) })
		end
	end
	setLock(SoftLockRules.afterTap(lockedId, SoftLockRules.pick(onScreen, point.X, point.Y, SoftLockConfig.PICK_SLACK)))
end

-- The next enemy (Tab, the Target button): nearest first, on outward, round again
function SoftLock.cycle()
	local root = rootOf()
	if getTargets and root then
		setLock(SoftLockRules.cycle(getTargets(), lockedId, root.Position.X, root.Position.Z))
	end
end

-- The locked enemy's id, or nil
function SoftLock.locked(): string?
	return lockedId
end

-- A fight with your sword starts: `targets` lists the enemies now (BattleController's sword targets)
function SoftLock.start(targets: () -> { Target })
	SoftLock.stop()
	getTargets = targets
	local made = Instance.new("Folder")
	made.Name = "SoftLock"
	made.Parent = workspace
	folder = made
	ringPart = flat("LockRing", SwordFx.RING_OUTLINE)
	glowPart = flat("LockGlow", SwordFx.RING_GLOW)
	buildArrow()
	buildSegments()
	table.insert(connections, RunService.RenderStepped:Connect(step))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode.Name == SoftLockConfig.KEY then
			SoftLock.cycle()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press = { at = Vector2.new(input.Position.X, input.Position.Y), clock = os.clock() }
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		local pressed = press
		if not pressed or (input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch) then
			return
		end
		press = nil
		local point = Vector2.new(input.Position.X, input.Position.Y)
		local moved = point - pressed.at
		if SoftLockRules.isTap(moved.X, moved.Y, os.clock() - pressed.clock, SoftLockConfig) then
			tapAt(point)
		end
	end))
end

-- The fight ends: nothing locked, the ring and arrow gone
function SoftLock.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	connections = {}
	getTargets = nil
	lockedId, sentId, press = nil, nil, nil
	if folder then
		folder:Destroy()
	end
	folder, ringPart, glowPart, arrowAnchor, arrowGui = nil, nil, nil, nil, nil
	segments = {}
end

return SoftLock
