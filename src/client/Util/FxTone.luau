--!strict
-- Effects toned to the scene round you (the owner 2026-11-10: "the particles are too bright on a white map like this.
-- is it posible to make the particles dynamic? like when I cast my prism sword skill I only see white flashes instead of
-- the animation/rays of different colors"; Config/FxTone, maths in Util/FxToneRules). Every effect particle, beam and
-- trail that appears in the world is noted as made; how bright the scene is comes from the ground under the camera and
-- the fog. On bright ground (snow) effects add less light and blend their colours in (additive light on white adds up
-- to white) and their glowing white cores fade; on dark ground they're as made. When the scene's brightness changes
-- (walking from snow onto rock) the ones still out are toned again. The world's own weather and scenery are left alone
-- (Config/FxTone skip); a stage high above you (the pack opening, the binder) has no ground under the camera: as made.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cfg = require(Shared:WaitForChild("Config"):WaitForChild("FxTone"))
local FxToneRules = require(Shared:WaitForChild("Util"):WaitForChild("FxToneRules"))

local FxTone = {}

local CAMERA_REACH = 80 -- studs under the camera the ground is looked for

type Entry = { lightEmission: number, brightness: number, color: { number }, transparency: NumberSequence }
local tracked: { [Instance]: Entry } = setmetatable({} :: any, { __mode = "k" })
local level = 0

local function rgb(color: Color3): { number }
	return { color.R * 255, color.G * 255, color.B * 255 }
end

-- The palest a colour sequence gets on each channel's dimmest keypoint: white only when every keypoint is white
local function dimmest(sequence: ColorSequence): { number }
	local low = { 255, 255, 255 }
	for _, point in sequence.Keypoints do
		local c = rgb(point.Value)
		for channel = 1, 3 do
			low[channel] = math.min(low[channel], c[channel])
		end
	end
	return low
end

local function faded(sequence: NumberSequence, fade: number): NumberSequence
	if fade <= 0 then
		return sequence
	end
	local points = {}
	for _, point in sequence.Keypoints do
		table.insert(points, NumberSequenceKeypoint.new(point.Time, FxToneRules.fadeValue(point.Value, fade), point.Envelope))
	end
	return NumberSequence.new(points)
end

-- Whether `item` belongs to the world's own weather or scenery (its top-level Workspace child is in Config skip)
local function skipped(item: Instance): boolean
	local top = item
	while top.Parent and top.Parent ~= workspace do
		top = top.Parent :: Instance
	end
	return top.Parent ~= workspace or table.find(Cfg.skip, top.Name) ~= nil
end

local function apply(item: Instance, entry: Entry)
	local toned = FxToneRules.tone(entry, level, Cfg)
	local effect = item :: any
	effect.LightEmission = toned.lightEmission
	effect.Brightness = toned.brightness
	effect.Transparency = faded(entry.transparency, toned.fade)
end

local function onAdded(item: Instance)
	if not (item:IsA("ParticleEmitter") or item:IsA("Beam") or item:IsA("Trail")) or skipped(item) then
		return
	end
	local effect = item :: any
	local entry: Entry = {
		lightEmission = effect.LightEmission,
		brightness = effect.Brightness,
		color = dimmest(effect.Color),
		transparency = effect.Transparency,
	}
	tracked[item] = entry
	if level > 0 then
		apply(item, entry)
	end
end

-- How bright the scene is now: the ground straight under the camera (terrain: its material's colour; a part: its
-- colour) and the haze (the Atmosphere's colour, else the fog's); nothing under the camera (a stage): 0
local function measure(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { camera }
	params.RespectCanCollide = true
	params.IgnoreWater = true
	local hit = workspace:Raycast(camera.CFrame.Position, Vector3.new(0, -CAMERA_REACH, 0), params)
	if not hit then
		return 0
	end
	local ground = if hit.Instance == workspace.Terrain then workspace.Terrain:GetMaterialColor(hit.Material) else (hit.Instance :: BasePart).Color
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local haze = if atmosphere then atmosphere.Color else Lighting.FogColor
	return FxToneRules.level(rgb(ground), rgb(haze), Cfg)
end

function FxTone.Start()
	workspace.DescendantAdded:Connect(onAdded)
	task.spawn(function()
		while true do
			local ok, now = pcall(measure)
			local next = if ok then now else 0
			if math.abs(next - level) > Cfg.retone or (next == 0 and level ~= 0) then
				level = next
				for item, entry in tracked do
					if item.Parent then
						apply(item, entry)
					end
				end
			end
			task.wait(Cfg.check)
		end
	end)
end

-- The scene's tone now, 0 (as made) to 1 (bright ground: effects toned)
function FxTone.level(): number
	return level
end

return FxTone
