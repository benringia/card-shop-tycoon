--!strict
-- Applies a day cycle look (Util/DayCycle) to Lighting and its Atmosphere, Bloom, ColorCorrection and SunRays (made
-- once by TownService). TownService sets the fixed look at start; on each client DayCycleController applies the cycle,
-- and the welcome cinematic holds it (hold) while it runs its own time-lapse.
local Lighting = game:GetService("Lighting")

local DayCycle = require(script.Parent:WaitForChild("DayCycle"))

local SkyLook = {}

local held = false

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

function SkyLook.apply(look: DayCycle.Look)
	Lighting.ClockTime = look.clockTime
	Lighting.Brightness = look.brightness
	Lighting.ExposureCompensation = look.exposure
	Lighting.Ambient = rgb(look.ambient)
	Lighting.OutdoorAmbient = rgb(look.outdoorAmbient)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = look.atmosphere.density
		atmosphere.Offset = look.atmosphere.offset
		atmosphere.Haze = look.atmosphere.haze
		atmosphere.Glare = look.atmosphere.glare
		atmosphere.Color = rgb(look.atmosphere.color)
		atmosphere.Decay = rgb(look.atmosphere.decay)
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = look.bloom.intensity
		bloom.Size = look.bloom.size
		bloom.Threshold = look.bloom.threshold
	end
	local grading = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if grading then
		grading.Saturation = look.saturation
		grading.Contrast = look.contrast
		grading.TintColor = rgb(look.tint)
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Intensity = look.sunRays.intensity
		rays.Spread = look.sunRays.spread
	end
end

-- While held, DayCycleController leaves the lighting alone (the welcome cinematic drives it)
function SkyLook.hold(on: boolean)
	held = on
end

function SkyLook.isHeld(): boolean
	return held
end

return SkyLook
