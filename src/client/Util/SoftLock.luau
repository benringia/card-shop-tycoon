--!strict
-- The soft lock in fights (owner 2026-11-15; Config/SoftLock, Util/SoftLockRules): no camera lock. Tap or click an
-- enemy, press Tab or the fight's Target button to lock it: a cyan outline on it and bobbing cyan chevrons over it,
-- nothing on the ground (owner 2026-11-16, pick A: a ring there passed for a boss's warning); your sword turns to it as
-- you attack (SwordController's soft aim asks `locked`) and the server points your creature at it (Remotes.SoftLock,
-- BattleSim.setFocus). Tapping it again, or it falling, lets go. With nothing locked a faint white outline shows who
-- your sword would hit (the nearest in front, SwordRules.aimTarget). SwordController starts and stops it with the fight.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local SoftLockConfig = require(Config:WaitForChild("SoftLock"))
local Swords = require(Config:WaitForChild("Swords"))
local SoftLockRules = require(Shared:WaitForChild("Util"):WaitForChild("SoftLockRules"))
local SwordRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordRules"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local SoftLock = {}

type Target = SoftLockRules.Target
type Look = { outline: { number }, outlineTransparency: number, fill: { number }, fillTransparency: number, pulse: number }

local player = Players.LocalPlayer
local getTargets: (() -> { Target })? = nil
local lockedId: string? = nil
local sentId: string? = nil
local lastSent = 0
local pendingSend = false
local connections: { RBXScriptConnection } = {}
local folder: Folder? = nil
local targetOutline: Highlight? = nil
local arrowAnchor: Part? = nil
local arrowGui: BillboardGui? = nil
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

-- The outline on the target: one Highlight, moved onto whoever's shown, drawn over everything
local function buildOutline()
	local glow = Instance.new("Highlight")
	glow.Name = "TargetOutline"
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Enabled = false
	glow.Parent = folder
	targetOutline = glow
end

-- The arrow over a locked target: the owner's pick, three glossy chevrons, cyan (Config/SoftLock ARROW.image)
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


local function rootOf(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

-- Your feet's height: the arenas are flat, so any enemy stands there (where a tap looks for it, the arrow's floor)
local function groundY(root: BasePart): number
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local hip = if humanoid then humanoid.HipHeight else 2
	return root.Position.Y - root.Size.Y / 2 - hip
end

local function find(targets: { Target }, id: string?): Target?
	for _, target in targets do
		if target.id == id then
			return target
		end
	end
	return nil
end

-- Each frame: the lock lets go once its enemy is gone; the outline and arrow sit on the locked enemy, or (a faint white
-- outline, no arrow) on the one your sword would hit
local function step()
	local root = rootOf()
	local glow, anchor, gui = targetOutline, arrowAnchor, arrowGui
	if not getTargets or not root or not glow or not anchor or not gui then
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
		glow.Adornee = nil
		glow.Enabled = false
		anchor.Parent = nil
		return
	end
	local style: Look = if lockedId then SoftLockConfig.LOCKED else SoftLockConfig.AUTO
	-- the enemy's model (BattleController's sword targets carry it; a Dungeon pylon is its part)
	local model = (shown :: any).model
	glow.Adornee = if typeof(model) == "Instance" and model.Parent then model else nil
	glow.Enabled = glow.Adornee ~= nil
	glow.OutlineColor = rgb(style.outline)
	glow.OutlineTransparency = style.outlineTransparency
	glow.FillColor = rgb(style.fill)
	glow.FillTransparency = math.clamp(style.fillTransparency + style.pulse * math.sin(os.clock() * 5), 0, 1)
	local y = groundY(root)
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
	buildOutline()
	buildArrow()
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

-- The fight ends: nothing locked, the outline and arrow gone
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
	folder, targetOutline, arrowAnchor, arrowGui = nil, nil, nil, nil
end

return SoftLock
