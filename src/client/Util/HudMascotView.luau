--!strict
-- The mascot peeking over the cash pill on a computer (spec 2026-11-03-hud-creature-pals-design; owner 2026-11-13 pick
-- P1: "over the cash, saying the toasts"; who it is in Config/HudMascot, its timing in Util/HudMascotRules). Its sticker
-- sits behind the pill with its paws behind the top edge and its tail poking up beside it; the toasts come out of its
-- head (HudMascotView.head, UIController). It breathes and its tail sways (looping tweens), it blinks now and then (one
-- timer), it ducks when asked (HudMascotView.duck), and a tap makes it bounce and chirp (the "Support the dev" card).
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
local tapButton: TextButton? = nil -- its tap area (HudMascotView.tapArea)
local pieces: { GuiObject } = {} -- what mount made (its tail, the clip, the tap area): hidden while a tour runs
local hidden = false
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
-- Its squash-and-bounce, silent
local function hop()
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
end

local tapHandlers: { () -> () } = {} -- HudMascotView.onTap

-- A tap: it bounces and chirps, then whoever listens hears of it (Pish's tour offer, TutorialController)
local function bounce()
	if not bounceScale then
		return
	end
	hop()
	chirp()
	for _, handler in tapHandlers do
		task.spawn(handler)
	end
end

-- Puts the mascot on its `seat` (nothing when it has no picture): its paws on the line `baseY` px down from the seat's
-- top (the cash pill's top edge), behind whatever is drawn over that line (HudMascotRules.layout)
function HudMascotView.mount(tile: GuiObject, baseY: number)
	if CFG.images.peek == "" then
		return
	end
	local width, height = CFG.size.peek[1], CFG.size.peek[2]
	local pad = CFG.clipPad
	duckDistance = HudMascotRules.duckTravel(height, CFG)
	local spots = HudMascotRules.layout(CFG)
	local overlap = CFG.perch.overlap

	local tail = Instance.new("ImageLabel")
	tail.Name = "MascotTail"
	tail.BackgroundTransparency = 1
	tail.Image = CFG.images.tail
	tail.AnchorPoint = Vector2.new(0.5, 1)
	tail.Position = UDim2.fromOffset(spots.tail, baseY + CFG.tail.at[2])
	tail.Size = UDim2.fromOffset(CFG.size.tail[1], CFG.size.tail[2])
	tail.Rotation = CFG.tail.angle
	tail.ZIndex = 0 -- behind the tile, poking up past its edge
	tail.Visible = CFG.images.tail ~= ""
	tail.Parent = tile
	loop(tail, CFG.tail.period / 2, { Rotation = CFG.tail.angle + CFG.tail.degrees })

	-- The clip: its bottom edge `overlap` px down behind the tile, so a duck slides the sticker out of sight; `pad` px of
	-- room round the sticker so breathing and bouncing never get cut off. Under the tile's face (its Body, ZIndex 2)
	local clip = Instance.new("Frame")
	clip.Name = "Mascot"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.AnchorPoint = Vector2.new(0, 1)
	clip.Position = UDim2.fromOffset(spots.sticker - pad, baseY + overlap)
	clip.Size = UDim2.fromOffset(width + pad * 2, height + pad)
	clip.ZIndex = 1
	clip.Parent = tile

	local frame = Instance.new("Frame")
	frame.Name = "Body"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromOffset(width, height)
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
	peek.Parent = frame
	loop(peek, CFG.tilt.period / 2, { Rotation = CFG.tilt.degrees })
	local scale = Instance.new("UIScale")
	scale.Parent = peek
	bounceScale = scale
	blinkLoop(makeLids(peek))

	-- Its tap area: centred on it, above the pill's top edge (a tap on the pill is the pill's)
	local tap = Instance.new("TextButton")
	tap.Name = "MascotTap"
	tap.Text = ""
	tap.BackgroundTransparency = 1
	tap.AnchorPoint = Vector2.new(0, 1)
	tap.Position = UDim2.fromOffset(spots.tap, baseY)
	tap.Size = UDim2.fromOffset(CFG.tapArea.w, CFG.tapArea.h)
	tap.ZIndex = 8
	tap.Parent = tile
	tap.Activated:Connect(bounce)
	tapButton = tap
	pieces = { tail, clip, tap }
	HudMascotView.setHidden(hidden)
end

-- The top of its head on screen, where the toasts' tails point (owner 2026-11-12: "make the bubble come out of him");
-- nil while it's hidden or not mounted
function HudMascotView.head(): Vector2?
	local frame = body
	if hidden or not frame or not frame.Parent then
		return nil
	end
	local at, size = frame.AbsolutePosition, frame.AbsoluteSize
	return Vector2.new(at.X + size.X / 2, at.Y + size.Y * 0.12)
end

-- Hides it (a tour on: Util/Hud's calm "mascot" piece) or shows it again; its tail only when it has a picture
function HudMascotView.setHidden(on: boolean)
	hidden = on
	for _, piece in pieces do
		piece.Visible = not on and (piece.Name ~= "MascotTail" or CFG.images.tail ~= "")
	end
end

-- Called after each tap on the mascot (it's the Pish button: TutorialController offers his tour again)
function HudMascotView.onTap(callback: () -> ())
	table.insert(tapHandlers, callback)
end

-- Its tap area while it's mounted (Pish points at it at his goodbye)
function HudMascotView.tapArea(): GuiObject?
	return tapButton
end

-- A silent hop (a toast arriving, UIController); nothing before it's mounted
function HudMascotView.hop()
	hop()
end

-- Ducks behind the pill and pops back up; called again mid-duck it carries on from where it is
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
