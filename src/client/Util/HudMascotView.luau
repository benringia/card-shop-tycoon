--!strict
-- The mascot peeking over the party cushion (spec 2026-11-03-hud-creature-pals-design; who it is in Config/HudMascot,
-- its timing in Util/HudMascotRules). Its sticker sits over the cushion's left end with its paws on the edge and its
-- tail poking up behind it. It breathes and its tail sways (looping tweens), it blinks now and then (one timer), it
-- ducks behind the cushion when you summon, unsummon or swap (HudMascotView.duck), and a tap makes it bounce and
-- chirp. It lives in the party bar, so it hides whenever the bar does.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudMascot = require(Shared:WaitForChild("Config"):WaitForChild("HudMascot"))
local HudMascotRules = require(Shared:WaitForChild("Util"):WaitForChild("HudMascotRules"))

local HudMascotView = {}

local CFG = HudMascot
local body: Frame? = nil -- the sticker's frame inside the clip: breathes, and slides down to duck
local bounceScale: UIScale? = nil
local duckDistance = 0 -- pixels a full duck moves the sticker down
local duckStart: number? = nil
local duckConnection: RBXScriptConnection? = nil
local bounceConnection: RBXScriptConnection? = nil

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

local function loop(target: Instance, seconds: number, goal: { [string]: any })
	TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), goal):Play()
end

-- A closed eye over each eye box: a lid in its fur colour with a small dark curve
local function makeLids(peek: ImageLabel): { Frame }
	local lids: { Frame } = {}
	for _, eye in CFG.eyes do
		local lid = Instance.new("Frame")
		lid.Name = "Lid"
		lid.BorderSizePixel = 0
		lid.BackgroundColor3 = rgb(CFG.lid)
		lid.Position = UDim2.fromScale(eye.x, eye.y)
		lid.Size = UDim2.fromScale(eye.w, eye.h)
		lid.Visible = false
		lid.ZIndex = peek.ZIndex + 1
		lid.Parent = peek
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = lid
		local crease = Instance.new("Frame")
		crease.BorderSizePixel = 0
		crease.BackgroundColor3 = rgb(CFG.crease)
		crease.AnchorPoint = Vector2.new(0.5, 0.5)
		crease.Position = UDim2.fromScale(0.5, 0.6)
		crease.Size = UDim2.new(0.8, 0, 0, 2)
		crease.ZIndex = lid.ZIndex + 1
		crease.Parent = lid
		table.insert(lids, lid)
	end
	return lids
end

local function blinkLoop(lids: { Frame })
	task.spawn(function()
		while lids[1] and lids[1].Parent do
			task.wait(HudMascotRules.nextBlink(math.random(), CFG))
			for _, lid in lids do
				lid.Visible = true
			end
			task.wait(CFG.blink.seconds)
			for _, lid in lids do
				lid.Visible = false
			end
		end
	end)
end

local function chirp()
	local sound = Instance.new("Sound")
	sound.SoundId = CFG.voice.id
	sound.Volume = CFG.voice.volume
	sound.PlaybackSpeed = CFG.voice.pitch.min + math.random() * (CFG.voice.pitch.max - CFG.voice.pitch.min)
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 3)
end

-- A tap: a little bounce (HudMascotRules.bounce) and its chirp
local function bounce()
	local scale = bounceScale
	if not scale then
		return
	end
	if bounceConnection then
		bounceConnection:Disconnect()
	end
	local started = os.clock()
	bounceConnection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		scale.Scale = HudMascotRules.bounce(t, CFG)
		if t >= CFG.tap.seconds and bounceConnection then
			bounceConnection:Disconnect()
			bounceConnection = nil
		end
	end)
	chirp()
end

-- Puts the mascot on `cushion` (nothing when it has no picture). The cushion is laid out by a list, so the mascot
-- goes beside it in the bar, over the cushion's top-left corner.
function HudMascotView.mount(cushion: GuiObject)
	local host = cushion.Parent
	if CFG.images.peek == "" or not host then
		return
	end
	local width, height = CFG.size.peek[1], CFG.size.peek[2]
	local pad = CFG.clipPad
	duckDistance = HudMascotRules.duckTravel(height, CFG)
	cushion.ZIndex = 2

	local tail = Instance.new("ImageLabel")
	tail.Name = "MascotTail"
	tail.BackgroundTransparency = 1
	tail.Image = CFG.images.tail
	tail.AnchorPoint = Vector2.new(0.5, 1)
	tail.Position = UDim2.fromOffset(CFG.tail.at[1], CFG.tail.at[2])
	tail.Size = UDim2.fromOffset(CFG.size.tail[1], CFG.size.tail[2])
	tail.Rotation = CFG.tail.angle
	tail.ZIndex = 1 -- behind the cushion, poking up past its edge
	tail.Visible = CFG.images.tail ~= ""
	tail.Parent = host
	loop(tail, CFG.tail.period / 2, { Rotation = CFG.tail.angle + CFG.tail.degrees })

	-- The clip: its bottom edge `overlap` px into the cushion, so a duck slides the sticker out of sight; `pad` px of room
	-- round the sticker so breathing and bouncing never get cut off
	local clip = Instance.new("Frame")
	clip.Name = "Mascot"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(0, 1)
	clip.Position = UDim2.fromOffset(CFG.offset.left - pad, CFG.offset.overlap)
	clip.Size = UDim2.fromOffset(width + pad * 2, height + pad)
	clip.ZIndex = 3
	clip.Parent = host

	local frame = Instance.new("Frame")
	frame.Name = "Body"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromOffset(width, height)
	frame.ZIndex = 3
	frame.Parent = clip
	local breath = Instance.new("UIScale")
	breath.Parent = frame
	loop(breath, CFG.breath.period / 2, { Scale = 1 + CFG.breath.scale })
	body = frame

	local peek = Instance.new("ImageLabel")
	peek.Name = "Peek"
	peek.BackgroundTransparency = 1
	peek.Image = CFG.images.peek
	peek.AnchorPoint = Vector2.new(0.5, 1)
	peek.Position = UDim2.fromScale(0.5, 1)
	peek.Size = UDim2.fromScale(1, 1)
	peek.Rotation = -CFG.tilt.degrees
	peek.ZIndex = 4
	peek.Parent = frame
	loop(peek, CFG.tilt.period / 2, { Rotation = CFG.tilt.degrees })
	local scale = Instance.new("UIScale")
	scale.Parent = peek
	bounceScale = scale
	blinkLoop(makeLids(peek))

	-- Its tap area: on the bar (not in the clip), finger-sized at any HUD scale and over its paws, so a tap on the cub
	-- never reaches the Party pill underneath
	local tap = Instance.new("TextButton")
	tap.Name = "MascotTap"
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.AnchorPoint = Vector2.new(0, 1)
	tap.Position = UDim2.fromOffset(CFG.offset.left, CFG.offset.overlap)
	tap.Size = UDim2.fromOffset(CFG.tapArea.w, CFG.tapArea.h)
	tap.ZIndex = 6
	tap.Parent = host
	tap.Activated:Connect(bounce)
end

-- Ducks behind the cushion and pops back up; called again mid-duck it carries on from where it is
function HudMascotView.duck()
	local frame = body
	if not frame then
		return
	end
	local now = os.clock()
	local current = if duckStart then HudMascotRules.duckShare(now - duckStart, CFG) else 0
	duckStart = now - HudMascotRules.restartAt(current, CFG)
	if duckConnection then
		return -- the running duck picks up the new start
	end
	duckConnection = RunService.Heartbeat:Connect(function()
		local start = duckStart
		if not start or not frame.Parent then
			return
		end
		local t = os.clock() - start
		frame.Position = UDim2.new(0.5, 0, 1, HudMascotRules.duckShare(t, CFG) * duckDistance)
		local duck = CFG.duck
		if t >= duck.down + duck.hold + duck.up then
			frame.Position = UDim2.fromScale(0.5, 1)
			duckStart = nil
			if duckConnection then
				duckConnection:Disconnect()
				duckConnection = nil
			end
		end
	end)
end

return HudMascotView
