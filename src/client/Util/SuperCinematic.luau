--!strict
-- The super move's cinematic on the caster's screen only (spec 2026-11-05-super-moves-design "The four beats"; the
-- owner's pick, option 3: a short camera moment while the fight runs on and your player can't be hit). The camera
-- swoops to your creature (the call), drifts closer as it charges, snaps to the impact shot framing it and its target
-- when the move lands, then eases back to your view; the card's painting slides across with the move's name, the
-- screen takes the element's colour, your character holds still and the HUD fades. Legendary: letterbox bars, a darker
-- grade over the world and a black-and-white impact frame (a soft white flash with the extras switch off). Numbers
-- in Config/SuperFx, the beats and camera framing in Util/SuperFxRules. Everything is restored on every exit.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local Combat = require(Shared:WaitForChild("Config"):WaitForChild("Combat"))
local SuperFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SuperFx"))
local SuperFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SuperFxRules"))
local Extras = require((script.Parent :: Instance):WaitForChild("Extras"))
local ScreenFx = require((script.Parent :: Instance):WaitForChild("ScreenFx"))

local SuperCinematic = {}

export type Args = {
	look: string,
	tier: string,
	grade: string,
	cardName: string,
	art: string?,
	color: Color3,
	creature: BasePart, -- the caster's fight root (at its feet)
	height: number,
	target: BasePart?,
	seconds: number, -- the wind-up: the move lands then
	protect: number, -- control comes back then (the sim's protection)
	hideHud: (hidden: boolean) -> (), -- the fight HUD out (and fight input paused) while it plays
}

local RENDER_NAME = "SuperCinematic"
local IMPACT_HOLD = 0.35 -- seconds the impact shot holds at least, however late the landing arrives
local LATE_IMPACT = 0.3 -- the impact plays by itself this long after the wind-up if its event never came
local IMPACT_FRAME = 0.07 -- seconds of the black-and-white frame

type Running = {
	args: Args,
	started: number,
	impactAt: number?,
	saved: { cameraType: Enum.CameraType, cframe: CFrame, fov: number, subject: Instance? },
	gui: ScreenGui,
	wash: Frame,
	cutIn: Frame,
	bars: { Frame },
	grade: ColorCorrectionEffect?,
	anchored: BasePart?,
	lastBase: Vector3,
	lastFacing: Vector3,
	removing: RBXScriptConnection?,
	ignore: { Instance }, -- what the camera may pass through: characters, monsters, the caster and its target
	side: number, -- which side of the creature the shots stand off to (1 or -1): the one nobody stands in front of
	faded: { [Model]: boolean }, -- characters, creatures and monsters faded out of the way this frame
}

local running: Running? = nil

local function vec(v: Vector3): SuperFxRules.Vec
	return { x = v.X, y = v.Y, z = v.Z }
end

local function v3(v: SuperFxRules.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function smooth(t: number): number
	local c = math.clamp(t, 0, 1)
	return c * c * (3 - 2 * c)
end

-- The eye pulled in front of any solid thing between it and what it looks at (an arena wall, a rock, the boss)
local function pullIn(focus: Vector3, eye: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local hit = workspace:Raycast(focus, eye - focus, params)
	if not hit then
		return eye
	end
	return hit.Position + (focus - hit.Position).Unit * 1.5
end

-- What the camera may pass through: every player's character, the monsters, the caster and its target
local function ignoreFor(args: Args): { Instance }
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	table.insert(ignore, args.creature:FindFirstAncestorOfClass("Model") or args.creature)
	if args.target then
		table.insert(ignore, args.target:FindFirstAncestorOfClass("Model") or args.target)
	end
	return ignore
end

-- Players' characters, creatures and monsters near the creature: what may stand between the camera and it and gets
-- faded out of the way (owner 2026-11-05: "sometimes ... the creature gets covered by the player or the boss").
-- Creatures and monsters are drawn as models at the top of the workspace with an AnimationController (Util/
-- CreatureVisuals); their parts can't be raycast (CanQuery off), so their bounding boxes are tested instead.
local bodies: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function candidates(): { Model }
	local list: { Model } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") then
			local known = bodies[child]
			if known == nil then
				known = child:FindFirstChildWhichIsA("AnimationController", true) ~= nil
				bodies[child] = known
			end
			if known then
				table.insert(list, child)
			end
		end
	end
	return list
end

local REACH = 80 -- studs from the creature a body is checked within
local SHRINK = 0.8 -- of a body's bounding box counts (boxes are bigger than the bodies in them)

-- The bodies between `eye` and any of `points` (the caster's own model left out)
local function blockers(eye: Vector3, points: { Vector3 }, own: Instance): { Model }
	local found: { Model } = {}
	for _, body in candidates() do
		if body ~= own and body.Parent and (body:GetPivot().Position - points[1]).Magnitude < REACH then
			local box, size = body:GetBoundingBox()
			local half = vec(size * 0.5 * SHRINK)
			local from = vec(box:PointToObjectSpace(eye))
			for _, point in points do
				if SuperFxRules.segmentHitsBox(from, vec(box:PointToObjectSpace(point)), half) then
					table.insert(found, body)
					break
				end
			end
		end
	end
	return found
end

-- The caster's chest and head: what the camera must see
local function creaturePoints(run: Running): { Vector3 }
	local base, height = run.lastBase, run.args.height
	return { base + Vector3.new(0, height * SuperFxConfig.CAMERA.focusHeight, 0), base + Vector3.new(0, height * 0.8, 0) }
end

-- A body faded (or back): every part's LocalTransparencyModifier, this screen only
local function fade(model: Model, amount: number)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.LocalTransparencyModifier = amount
		end
	end
end

-- A beat's shot (Util/SuperFxRules.shot); the frame's camera is pulled in front of walls afterwards
local function shotFor(run: Running, beat: string): CFrame
	local args = run.args
	if args.creature.Parent then
		run.lastBase = args.creature.Position
		run.lastFacing = args.creature.CFrame.LookVector
	end
	local target = if args.target and args.target.Parent then vec(args.target.Position) else nil
	-- A look that bursts high over the boss (Supernova's sun) keeps that point in frame too
	local burst = if SuperFxConfig.LOOKS[args.look] then SuperFxRules.look(SuperFxConfig, args.look, args.grade, Extras.enabled()).burst else nil
	local sky = if target and burst then { x = target.x, y = target.y + burst, z = target.z } else nil
	local eye, focus = SuperFxRules.shot(beat, vec(run.lastBase), args.height, vec(run.lastFacing), target, SuperFxConfig, sky, run.side)
	return CFrame.lookAt(v3(eye), v3(focus))
end

-- The side whose close shots have fewer bodies in front of the creature (the first side on a tie)
local function pickSide(run: Running): number
	local own = run.args.creature:FindFirstAncestorOfClass("Model") or run.args.creature
	local points = creaturePoints(run)
	local counts = {}
	for _, side in { 1, -1 } do
		run.side = side
		local count = 0
		for _, beat in { "call", "charge" } do
			count += #blockers(shotFor(run, beat).Position, points, own)
		end
		counts[side] = count
	end
	return if counts[-1] < counts[1] then -1 else 1
end

-- Each frame: whatever body still stands between the camera and the creature fades out, the ones no longer in the way
-- come back
local function clearView(run: Running, eye: Vector3)
	local own = run.args.creature:FindFirstAncestorOfClass("Model") or run.args.creature
	local now: { [Model]: boolean } = {}
	for _, body in blockers(eye, creaturePoints(run), own) do
		now[body] = true
		if not run.faded[body] then
			fade(body, SuperFxConfig.CAMERA.fade)
		end
	end
	for body in run.faded do
		if not now[body] and body.Parent then
			fade(body, 0)
		end
	end
	run.faded = now
end

-- The overlay: the colour wash, the card cut-in with the move's name, Legendary's bars
local function buildGui(args: Args, tier: any): (ScreenGui, Frame, Frame, { Frame })
	local gui = Instance.new("ScreenGui")
	gui.Name = "SuperCinematic"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45 -- over the fight HUD, under the defeat screen and the flash
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.BorderSizePixel = 0
	wash.BackgroundColor3 = args.color
	wash.BackgroundTransparency = 1
	wash.Size = UDim2.fromScale(1, 1)
	wash.Parent = gui
	local bars: { Frame } = {}
	if tier.bars then
		for index, anchor in { 0, 1 } do
			local bar = Instance.new("Frame")
			bar.Name = if index == 1 then "BarTop" else "BarBottom"
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = Color3.new(0, 0, 0)
			bar.AnchorPoint = Vector2.new(0, anchor)
			bar.Position = UDim2.fromScale(0, anchor)
			bar.Size = UDim2.fromScale(1, 0)
			bar.ZIndex = 3
			bar.Parent = gui
			table.insert(bars, bar)
		end
	end
	local phone = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y < 500
	local cutIn = Instance.new("Frame")
	cutIn.Name = "CutIn"
	cutIn.BackgroundTransparency = 1
	cutIn.AnchorPoint = Vector2.new(0.5, 0.5)
	cutIn.Position = UDim2.fromScale(1.4, 0.42)
	cutIn.Size = UDim2.fromScale(0.62, 0.42)
	cutIn.ZIndex = 2
	cutIn.Parent = gui
	local card = Instance.new("ImageLabel")
	card.Name = "Card"
	card.BackgroundColor3 = Color3.fromRGB(20, 16, 30)
	card.Image = args.art or ""
	card.ScaleType = Enum.ScaleType.Crop
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.fromScale(1, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	card.SizeConstraint = Enum.SizeConstraint.RelativeYY
	card.Rotation = 6
	card.ZIndex = 2
	card.Parent = cutIn
	local shape = Instance.new("UIAspectRatioConstraint")
	shape.AspectRatio = 0.7
	shape.Parent = card
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.06, 0)
	corner.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Color = args.color
	edge.Thickness = 4
	edge.Parent = card
	local ability = Combat.SIGNATURES[args.cardName]
	local name = Instance.new("TextLabel")
	name.Name = "MoveName"
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.Text = `{string.upper(if ability then ability.name else args.look)}!`
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextSize = if phone then 38 else 64
	name.TextXAlignment = Enum.TextXAlignment.Right
	name.AnchorPoint = Vector2.new(1, 0.5)
	name.Position = UDim2.new(0.62, 0, 0.55, 0)
	name.Size = UDim2.fromScale(1.2, 0.3)
	name.ZIndex = 3
	name.Parent = cutIn
	local nameEdge = Instance.new("UIStroke")
	nameEdge.Color = args.color
	nameEdge.Thickness = 4
	nameEdge.Parent = name
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui, wash, cutIn, bars
end

local function tween(item: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(item, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

-- Everything back as it was: camera, character, HUD, overlay, world grade
local function finish(run: Running)
	if running ~= run then
		return
	end
	running = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = run.saved.cframe -- the player's own view, also when cut short (final review)
		camera.CameraType = run.saved.cameraType
		camera.FieldOfView = run.saved.fov
		if run.saved.subject and run.saved.subject.Parent then
			camera.CameraSubject = run.saved.subject
		end
	end
	if run.anchored and run.anchored.Parent then
		run.anchored.Anchored = false
	end
	if run.removing then
		run.removing:Disconnect()
	end
	for body in run.faded do
		if body.Parent then
			fade(body, 0)
		end
	end
	run.faded = {}
	if run.grade then
		run.grade:Destroy()
	end
	run.gui:Destroy()
	local ok, err = pcall(run.args.hideHud, false)
	if not ok then
		warn("[SuperCinematic] HUD back:", err)
	end
end

-- The impact beat: the snap to the impact shot, the shake, the flash or black-and-white frame
local function impactNow(run: Running, t: number)
	if run.impactAt then
		return
	end
	run.impactAt = t
	local args = run.args
	local tier = SuperFxConfig.TIERS[args.tier]
	local look = SuperFxRules.look(SuperFxConfig, args.look, args.grade, Extras.enabled())
	ScreenFx.shake(AttackFx.SHAKE.special * look.shake * 1.6)
	tween(run.cutIn, 0.18, { Position = UDim2.fromScale(-0.5, 0.42) }, Enum.EasingStyle.Quint)
	if tier.impactFrame and Extras.enabled() then
		-- The black-and-white frame (Supernova's S: twice)
		for index = 1, look.impactFrames or 1 do
			task.delay((index - 1) * 0.16, function()
				local frame = Instance.new("ColorCorrectionEffect")
				frame.Name = "SuperImpactFrame"
				frame.Saturation = -1
				frame.Contrast = 1.6
				frame.Brightness = 0.08
				frame.Parent = Lighting
				task.delay(IMPACT_FRAME, function()
					frame:Destroy()
					ScreenFx.flash(Color3.new(1, 1, 1), AttackFx.FLASH.special.strength, AttackFx.FLASH.special.seconds * 1.4)
				end)
			end)
		end
	else
		ScreenFx.flash(Color3.new(1, 1, 1), AttackFx.FLASH.special.strength * (if Extras.enabled() then 1 else 0.6), AttackFx.FLASH.special.seconds)
	end
end

-- Plays the cinematic for one super from your creature (stops any still playing first)
function SuperCinematic.play(args: Args)
	if running then
		finish(running)
	end
	local camera = workspace.CurrentCamera
	local tier = SuperFxConfig.TIERS[args.tier]
	if not camera or not tier then
		return
	end
	local gui, wash, cutIn, bars = buildGui(args, tier)
	local run: Running = {
		args = args,
		started = os.clock(),
		impactAt = nil,
		saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView, subject = camera.CameraSubject },
		gui = gui,
		wash = wash,
		cutIn = cutIn,
		bars = bars,
		grade = nil,
		anchored = nil,
		lastBase = args.creature.Position,
		lastFacing = args.creature.CFrame.LookVector,
		removing = nil,
		ignore = ignoreFor(args),
		side = 1,
		faded = {},
	}
	run.side = pickSide(run)
	running = run
	local ok, err = pcall(args.hideHud, true)
	if not ok then
		warn("[SuperCinematic] HUD out:", err)
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") and not root.Anchored then
		root.Anchored = true -- held still while the camera is away (your device moves your character)
		run.anchored = root
	end
	run.removing = Players.LocalPlayer.CharacterRemoving:Connect(function()
		finish(run)
	end)
	-- The call: wash, cut-in, bars, and Legendary's darker grade over the world
	local call = tier.call
	tween(wash, call, { BackgroundTransparency = 0.8 })
	tween(cutIn, 0.25, { Position = UDim2.fromScale(0.62, 0.42) }, Enum.EasingStyle.Back)
	for _, bar in bars do
		tween(bar, call, { Size = UDim2.fromScale(1, 0.11) })
	end
	local sky = SuperFxConfig.LOOKS[args.look].sky
	if tier.sky and sky then
		-- The look's own sky over the world (deep space, a storm, the world dimming, clouds parting), this screen only
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "SuperGrade"
		grade.Brightness = 0
		grade.Parent = Lighting
		tween(grade, call, {
			TintColor = Color3.fromRGB(sky.tint[1], sky.tint[2], sky.tint[3]),
			Brightness = sky.brightness,
			Saturation = sky.saturation,
			Contrast = sky.contrast,
		})
		run.grade = grade
	end
	local home = run.saved.cframe
	local cfg = SuperFxConfig.CAMERA
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - run.started
		if not run.impactAt and t >= args.seconds + LATE_IMPACT then
			impactNow(run, t)
		end
		local back = math.max(args.protect, (run.impactAt or args.protect) + IMPACT_HOLD)
		local ease = cfg.ease
		local view: CFrame
		if not run.impactAt then
			if t < call + ease then
				view = home:Lerp(shotFor(run, "call"), smooth(t / (call + ease)))
			else
				view = shotFor(run, "call"):Lerp(shotFor(run, "charge"), smooth((t - call - ease) / math.max(0.1, args.seconds - call - ease)))
			end
		elseif t < back - ease then
			view = shotFor(run, "charge"):Lerp(shotFor(run, "impact"), smooth((t - (run.impactAt :: number)) / 0.1))
		elseif t < back then
			view = shotFor(run, "impact"):Lerp(home, smooth((t - (back - ease)) / ease))
		else
			finish(run)
			return
		end
		-- Every frame (the eases between shots too) in front of any wall between it and the creature (review focus 4)
		local chest = run.lastBase + Vector3.new(0, args.height * cfg.focusHeight, 0)
		camera.CFrame = CFrame.new(pullIn(chest, view.Position, run.ignore)) * view.Rotation
		clearView(run, camera.CFrame.Position)
		camera.FieldOfView = cfg.fov
		if t >= back - ease and not run.gui:GetAttribute("Leaving") then
			run.gui:SetAttribute("Leaving", true)
			tween(wash, ease, { BackgroundTransparency = 1 })
			for _, bar in bars do
				tween(bar, ease, { Size = UDim2.fromScale(1, 0) })
			end
			if run.grade then
				tween(run.grade, ease, { Brightness = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) })
			end
		end
	end)
end

-- The move landed (its ability event): the impact beat now
function SuperCinematic.impact()
	local run = running
	if run then
		impactNow(run, os.clock() - run.started)
	end
end

-- The fight ended: once the move has landed (often the killing blow) the cinematic plays out and eases back; before
-- that it cuts back now
function SuperCinematic.release()
	local run = running
	if run and not run.impactAt then
		finish(run)
	end
end

-- Back to the player now (a fizzle, the character gone, leaving)
function SuperCinematic.cut()
	local run = running
	if run then
		finish(run)
	end
end

function SuperCinematic.isPlaying(): boolean
	return running ~= nil
end

return SuperCinematic
