--!strict
-- Your own sword skill's camera moment (Sunfall Cleave, owner 2026-11-07: camera only, the fight runs on and you can
-- still be hit; Config/SwordSkillFx CINEMATIC, the beats in SwordSkillFxRules.cinematicBeat): the camera eases to a low
-- angle beside and behind you looking up as you jump, drifts closer through the charge, at the cleave chases the fire
-- crescent down to where it bursts, holds there, then eases back to your view. A super's cinematic, a dodge before the
-- cleave, the fight's end or your character going cuts it short; your camera is always restored.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SwordSkillFxConfig = require(Shared:WaitForChild("Config"):WaitForChild("SwordSkillFx"))
local SwordSkillFxRules = require(Shared:WaitForChild("Util"):WaitForChild("SwordSkillFxRules"))
local SuperCinematic = require((script.Parent :: Instance):WaitForChild("SuperCinematic"))

local SkillCinematic = {}

local RENDER_NAME = "SwordSkillCinematic"
local UP = Vector3.yAxis
local LATCH = 0.25 -- seconds the camera takes to swing from the charge shot onto the crescent

type Saved = { cameraType: Enum.CameraType, cframe: CFrame, fov: number, subject: Instance? }
local saved: Saved? = nil

local function smooth(a: number): number
	return a * a * (3 - 2 * a)
end

-- Your camera back as it was
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

-- Plays for your character's `root`: the crescent leaves `release` seconds in and bursts at `impact` (on the ground)
-- `travel` seconds later; `live()` false before the cleave (a dodge) cuts it short
function SkillCinematic.play(root: BasePart, impact: Vector3, release: number, travel: number, live: () -> boolean)
	local camera = workspace.CurrentCamera
	if not camera or SuperCinematic.isPlaying() then
		return
	end
	SkillCinematic.stop()
	local cfg = SwordSkillFxConfig.CINEMATIC
	local was: Saved = { cameraType = camera.CameraType, cframe = camera.CFrame, fov = camera.FieldOfView, subject = camera.CameraSubject }
	saved = was
	local started = os.clock()
	local base = root.Position
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local forward = if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
	local right = forward:Cross(UP)
	local focus = base + UP * cfg.lookUp
	local function aside(o: { side: number, back: number, up: number }): CFrame
		return CFrame.lookAt(base + right * o.side - forward * o.back + UP * o.up, focus)
	end
	local low, close = aside(cfg.low), aside(cfg.close)
	local from = base + UP * (cfg.lookUp - 1)
	local to = impact + UP * 2
	local function chase(a: number): CFrame
		local point = from:Lerp(to, a)
		local c = cfg.chase
		return CFrame.lookAt(point - forward * c.back + UP * c.up, point + forward * c.ahead)
	end
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - started
		local beat, a = SwordSkillFxRules.cinematicBeat(t, release, travel, cfg)
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
			view = close:Lerp(chase(a), smooth(math.clamp((t - release) / LATCH, 0, 1)))
		elseif beat == "impact" then
			view = chase(1)
		elseif beat == "back" then
			view = chase(1):Lerp(was.cframe, smooth(a))
		else
			SkillCinematic.stop()
			return
		end
		camera.CFrame = view
		local zoom = if beat == "rise" then smooth(a) elseif beat == "back" then 1 - smooth(a) else 1
		camera.FieldOfView = was.fov + (cfg.fov - was.fov) * zoom
	end)
end

return SkillCinematic
