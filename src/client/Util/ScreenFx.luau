--!strict
-- Screen shake and flashes for fight effects (spec 2026-11-02-attack-animations-design "Quality bar"; Config/AttackFx
-- SHAKE and FLASH): every hit adds to one shake that dies down (Util/ShakeRules), moving the camera by a smooth rattle
-- on top of wherever the camera script put it; hits away from you shake less. A flash fills the screen with a colour
-- for a moment and fades.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AttackFx = require(Shared:WaitForChild("Config"):WaitForChild("AttackFx"))
local ShakeRules = require(Shared:WaitForChild("Util"):WaitForChild("ShakeRules"))

local ScreenFx = {}

local NOISE_SPEED = 26 -- how fast the rattle moves
local ROLL = 0.025 -- radians of camera roll per stud of shake

local shake = 0
local bound = false
local flashFrame: Frame? = nil

local function bind()
	if bound then
		return
	end
	bound = true
	RunService:BindToRenderStep("FightFxShake", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		if shake <= 0 then
			return
		end
		local camera = workspace.CurrentCamera
		if camera then
			local studs = ShakeRules.offset(shake, AttackFx.SHAKE.MAX_STUDS)
			local t = os.clock() * NOISE_SPEED
			local x = math.noise(t, 0.31) * 2 * studs
			local y = math.noise(0.77, t) * 2 * studs
			local roll = math.noise(t * 0.7, 5.13) * 2 * studs * ROLL
			camera.CFrame *= CFrame.new(x, y, 0) * CFrame.Angles(0, 0, roll)
		end
		shake = ShakeRules.decay(shake, dt, AttackFx.SHAKE.DECAY)
	end)
end

function ScreenFx.shake(amount: number)
	bind()
	shake = ShakeRules.add(shake, amount)
end

-- How far `position` is from you (your character, else the camera's focus)
function ScreenFx.distance(position: Vector3): number
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local camera = workspace.CurrentCamera
	local from = if root then root.Position elseif camera then camera.Focus.Position else position
	return (position - from).Magnitude
end

-- A hit at `position`: its shake, less the further it is from you
function ScreenFx.shakeAt(amount: number, position: Vector3)
	ScreenFx.shake(ShakeRules.falloff(amount, ScreenFx.distance(position), AttackFx.SHAKE.NEAR, AttackFx.SHAKE.FAR))
end

local function frame(): Frame
	if flashFrame and flashFrame.Parent then
		return flashFrame
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FightFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local made = Instance.new("Frame")
	made.Size = UDim2.fromScale(1, 1)
	made.BorderSizePixel = 0
	made.BackgroundTransparency = 1
	made.Active = false
	made.Parent = gui
	flashFrame = made
	return made
end

-- The screen goes `color` at `strength` (0-1) and fades back over `seconds`
function ScreenFx.flash(color: Color3, strength: number, seconds: number)
	local target = frame()
	target.BackgroundColor3 = color
	target.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	TweenService:Create(target, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

return ScreenFx
