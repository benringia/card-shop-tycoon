--!strict
-- The welcome flight's finale at your shop (the owner 2026-11-11: "dont add drawn confetti. search for a free/safe
-- particle/VFX on creator store that suits this cinematic"; Config/Welcome FINALE): confetti shooting up from two
-- cannons either side of the door, tilted inward (Onogork's Confetti Particle Emitter's particles, each colour
-- flickering as it tumbles), and over the sign a star burst, gold stars twinkling and a soft glow (the Euphoric Games
-- VFX Pack's). Built with Util/PackEmitter, in the world in front of the shop, cleared after FINALE.seconds.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Welcome = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Welcome"))
local ElementFx = require((script.Parent :: Instance):WaitForChild("ElementFx"))
local PackEmitter = require((script.Parent :: Instance):WaitForChild("PackEmitter"))

local WelcomeFx = {}

local UP = Vector3.yAxis

local function holder(cframe: CFrame, size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = ElementFx.folder()
	Debris:AddItem(part, Welcome.FINALE.seconds)
	return part
end

-- A confetti colour's flicker between its light and dark sides, in step with Onogork's size flicker
local function flicker(colors: { { number } }): { any }
	local keys = {}
	for step = 0, 10 do
		table.insert(keys, { step / 10, if step % 4 < 2 then colors[1] else colors[2] })
	end
	return keys
end

local function burst(part: BasePart, spec: any, count: number)
	local emitter = PackEmitter.make(spec, 1, nil)
	emitter.Parent = part
	emitter:Emit(count)
end

-- Its textures downloaded ahead (WelcomeController calls this as the flight starts)
function WelcomeFx.preload()
	local cfg = Welcome.FINALE
	local circle = table.clone(cfg.confetti.emitter)
	circle.texture = cfg.confetti.circle
	PackEmitter.preload({ cfg.confetti.emitter, circle, cfg.burst.emitter, cfg.stars.emitter, cfg.glow.emitter })
end

-- The finale at the shop whose door is `door` (on the ground), facing `outward` (to the street)
function WelcomeFx.finale(door: Vector3, outward: Vector3)
	local cfg = Welcome.FINALE
	local flat = Vector3.new(outward.X, 0, outward.Z)
	local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, 1)
	local right = forward:Cross(UP).Unit
	local confetti = cfg.confetti
	for _, side in { -1, 1 } do
		local base = door + right * side * confetti.side + UP * confetti.up + forward * 2
		-- its top tilted toward the door, so both showers meet over it
		local cframe = CFrame.fromMatrix(base, right, UP) * CFrame.Angles(0, 0, math.rad(side * confetti.tilt))
		local cannon = holder(cframe, Vector3.one)
		for index, colors in confetti.palette do
			local spec = table.clone(confetti.emitter)
			spec.texture = if index % 2 == 0 then confetti.circle else confetti.emitter.texture
			spec.colorKeys = flicker(colors)
			burst(cannon, spec, confetti.count)
		end
	end
	local sign = door + forward * 1.5
	burst(holder(CFrame.new(sign + UP * cfg.burst.up), Vector3.one), cfg.burst.emitter, cfg.burst.count)
	local box = cfg.stars.box
	burst(holder(CFrame.lookAt(sign + UP * cfg.stars.up, sign + UP * cfg.stars.up + forward), Vector3.new(box[1], box[2], box[3])), cfg.stars.emitter, cfg.stars.count)
	burst(holder(CFrame.new(sign + UP * cfg.glow.up), Vector3.one), cfg.glow.emitter, cfg.glow.count)
end

return WelcomeFx
