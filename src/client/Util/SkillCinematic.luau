--!strict
-- Your own sword skill's camera moment (Sunfall Cleave, owner 2026-11-07: camera only, the fight runs on and you can
-- still be hit; Config/SwordSkillFx CINEMATIC, the beats in SwordSkillFxRules.cinematicBeat), all from the side so the
-- crescent shows whole: the camera eases to a side shot of you looking up as you jump, drifts closer through the charge,
-- at the cleave swings out to a wide side shot framing you, the crescent's flight and the burst, holds there, then eases
-- back to your view. It takes your left or right, whichever a wall or hill blocks least, and comes in front of anything
-- still in the way. A super's cinematic, a dodge before the cleave, the fight's end or your character going cuts it
-- short; your camera is always restored.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SwordSkillFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SwordSkillFx"))
local SwordSkillFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordSkillFxRules"))
local SuperCinematic = require((script.Parent :: Instance):WaitForChild("SuperCinematic"))

local SkillCinematic = {}

local RENDER_NAME = "SwordSkillCinematic"
local UP = Vector3.yAxis

type Saved = { cameraType: Enum.CameraType, cframe: CFrame, fov: number, subject: Instance? }
local saved: Saved? = nil

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- How much of the way from `focus` to `eye` is clear of walls and terrain (characters and effects ignored), 0-1
local function clearShare(focus: Vector3, eye: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { workspace.CurrentCamera }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(focus, eye - focus, params)
	return if hit then (hit.Position - focus).Magnitude / math.max((eye - focus).Magnitude, 1e-3) else 1
end

-- A shot from `eye` at `focus`, brought in front of anything in the way
local function shot(focus: Vector3, eye: Vector3): CFrame
	local clear = clearShare(focus, eye)
	local at = if clear < 1 then focus + (eye - focus) * math.max(0.25, clear - 0.08) else eye
	return CFrame.lookAt(at, focus)
end

-- Whether your skill's camera moment is playing (the finisher's hang zoom stays off the camera then)
function SkillCinematic.isPlaying(): boolean
	return saved ~= nil
end

-- Your camera back as it was (also before a super's cinematic takes the camera: final review 2026-11-07, else the super
-- saves this moment's scripted camera and restores it, leaving the camera stuck)
function SkillCinematic.stop()
	local was = saved
	if not was then
		return
	end
	saved = nil
	RunService:UnbindFromRenderStep(RENDER_NAME)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = was.cframe
		camera.CameraType = was.cameraType
		camera.FieldOfView = was.fov
		if was.subject and was.subject.Parent then
			camera.CameraSubject = was.subject
		end
	end
end

-- A look's own framing (its beats): how long the wide shot holds, how high it looks and stands, and how high above your
-- root the hero shot looks (`focusUp`; a jump's look up by default)
-- `out`: the wide shot never nearer than this (else CINEMATIC.wide.least; Torrent Strike stands far out so its tall
-- columns fit); `ahead`: the wide shot this far toward your front (Thousand Cuts: the Grim Reaper behind you faces
-- where you face, so a side-on shot saw it edge-on)
export type Framing = { hold: number?, lookUp: number?, up: number?, focusUp: number?, out: number?, ahead: number? }

-- Plays for your character's `root`: the skill's effect leaves `release` seconds in and lands at `impact` (on the
-- ground) `travel` seconds later; `live()` false before then (a dodge) cuts it short
function SkillCinematic.play(root: BasePart, impact: Vector3, release: number, travel: number, live: () -> boolean, framing: Framing?)
	local camera = workspace.CurrentCamera
	if not camera or SuperCinematic.isPlaying() then
		return
	end
	SkillCinematic.stop()
	local cfg = SwordSkillFxConfig.CINEMATIC
	local frame = framing or {}
	local timing = { rise = cfg.rise, hold = frame.hold or cfg.hold, back = cfg.back }
	local wideLookUp = frame.lookUp or cfg.wide.lookUp
	local wideUp = frame.up or cfg.wide.up
	local was: Saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView, subject = camera.CameraSubject }
	saved = was
	local started = os.clock()
	local base = root.Position
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local forward = if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
	local right = forward:Cross(UP)
	-- You, up in the jump; the flight from under you to the burst, and its middle
	local focus = base + UP * (frame.focusUp or cfg.lookUp)
	local feet = base - UP * 3
	local flight = Vector3.new(impact.X - feet.X, 0, impact.Z - feet.Z).Magnitude
	local middle = feet:Lerp(impact, 0.5) + UP * wideLookUp
	local viewport = camera.ViewportSize
	local out = SwordSkillFxRules.wideDistance(flight + 4, cfg.wide.margin, cfg.fov, viewport.X / math.max(viewport.Y, 1), frame.out or cfg.wide.least)
	local function eyes(side: number): (Vector3, Vector3)
		local hero = base + right * side * cfg.hero.side + forward * cfg.hero.ahead + UP * cfg.hero.up
		return hero, middle + right * side * out + forward * (frame.ahead or 0) + UP * wideUp
	end
	-- the side a wall or hill blocks least
	local heroRight, wideRight = eyes(1)
	local heroLeft, wideLeft = eyes(-1)
	local rightClear = math.min(clearShare(focus, heroRight), clearShare(middle, wideRight))
	local leftClear = math.min(clearShare(focus, heroLeft), clearShare(middle, wideLeft))
	local heroEye, wideEye = if leftClear > rightClear then heroLeft else heroRight, if leftClear > rightClear then wideLeft else wideRight
	local low = shot(focus, heroEye)
	local close = shot(focus, heroEye:Lerp(focus, cfg.push))
	local wide = shot(middle, wideEye)
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - started
		local beat, a = SwordSkillFxRules.cinematicBeat(t, release, travel, timing)
		if saved ~= was or not root.Parent or SuperCinematic.isPlaying() or ((beat == "rise" or beat == "charge") and not live()) then
			if saved == was then
				SkillCinematic.stop()
			end
			return
		end
		local view: CFrame
		if beat == "rise" then
			view = was.cframe:Lerp(low, smooth(a))
		elseif beat == "charge" then
			view = low:Lerp(close, smooth(a))
		elseif beat == "chase" then
			view = close:Lerp(wide, smooth(math.clamp((t - release) / cfg.latch, 0, 1)))
		elseif beat == "impact" then
			view = close:Lerp(wide, smooth(math.clamp((t - release) / cfg.latch, 0, 1)))
		elseif beat == "back" then
			view = wide:Lerp(was.cframe, smooth(a))
		else
			SkillCinematic.stop()
			return
		end
		camera.CFrame = view
		local zoom = if beat == "rise" then smooth(a) elseif beat == "back" then 1 - smooth(a) else 1
		camera.FieldOfView = was.fov + (cfg.fov - was.fov) * zoom
	end)
end

-- The camera moment for a skill look with one (Config/SwordSkillFx `cinematic`) aimed at `aim` (a look drawn round
-- you frames you where you stand: SwordSkillFxRules.framesOnCaster; nothing to aim at, no moment): its effect leaves at
-- `camAt` (else `release`) and lands after its flight (`speed`; none: at once), held `camHold`, the wide shot
-- `camLookUp` / `camUp`, the hero shot looking `camFocus` above your root (else CINEMATIC's)
function SkillCinematic.forLook(root: BasePart, look: SwordSkillFxConfig.Look, target: Vector3?, live: () -> boolean)
	local beats = look.beats
	local aim = if SwordSkillFxRules.framesOnCaster(look) then root.Position else target
	if not look.cinematic or not beats or not aim then
		return
	end
	local flat = Vector3.new(aim.X - root.Position.X, 0, aim.Z - root.Position.Z).Magnitude
	local travel = if beats.speed then flat / math.max(beats.speed, 1) else 0
	SkillCinematic.play(root, aim - UP * 3, beats.camAt or beats.release, travel, live, {
		hold = beats.camHold,
		lookUp = beats.camLookUp,
		up = beats.camUp,
		focusUp = beats.camFocus,
		out = beats.camOut,
		ahead = beats.camAhead,
	})
end

return SkillCinematic
