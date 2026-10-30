--!strict
-- The town's day cycle maths (Portal Worlds spec): which phase it is, the blended look for any moment, and the look
-- outside town. Pure, Lune-tested; the phases and looks are in Config/DayCycle. DayCycleController applies the result
-- on each client from the server's start time (workspace attribute DayCycleStart), so it costs no network.
export type Atmosphere = { density: number, offset: number, haze: number, glare: number, color: { number }, decay: { number } }
export type Look = {
	clockTime: number,
	brightness: number,
	exposure: number,
	ambient: { number },
	outdoorAmbient: { number },
	atmosphere: Atmosphere,
	bloom: { intensity: number, size: number, threshold: number },
	saturation: number,
	contrast: number,
	tint: { number },
	sunRays: { intensity: number, spread: number },
}

local DayCycle = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpColor(a: { number }, b: { number }, t: number): { number }
	return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) }
end

-- Hours from a forward to b on the clock (through midnight when b is earlier)
local function clockLerp(a: number, b: number, t: number): number
	return (a + ((b - a) % 24) * t) % 24
end

function DayCycle.loopSeconds(cycle: any): number
	local total = 0
	for _, phase in cycle.PHASES do
		total += phase.seconds
	end
	return total
end

-- The phase's index and the seconds into it at `seconds` into the cycle (wrapping round the loop)
local function locate(cycle: any, seconds: number): (number, number)
	local into = seconds % DayCycle.loopSeconds(cycle)
	for index, phase in cycle.PHASES do
		if into < phase.seconds then
			return index, into
		end
		into -= phase.seconds
	end
	return #cycle.PHASES, cycle.PHASES[#cycle.PHASES].seconds
end

function DayCycle.phaseAt(cycle: any, seconds: number): (string, number)
	local index, into = locate(cycle, seconds)
	local phase = cycle.PHASES[index]
	return phase.name, into / phase.seconds
end

function DayCycle.blend(a: Look, b: Look, t: number): Look
	return {
		clockTime = clockLerp(a.clockTime, b.clockTime, t),
		brightness = lerp(a.brightness, b.brightness, t),
		exposure = lerp(a.exposure, b.exposure, t),
		ambient = lerpColor(a.ambient, b.ambient, t),
		outdoorAmbient = lerpColor(a.outdoorAmbient, b.outdoorAmbient, t),
		atmosphere = {
			density = lerp(a.atmosphere.density, b.atmosphere.density, t),
			offset = lerp(a.atmosphere.offset, b.atmosphere.offset, t),
			haze = lerp(a.atmosphere.haze, b.atmosphere.haze, t),
			glare = lerp(a.atmosphere.glare, b.atmosphere.glare, t),
			color = lerpColor(a.atmosphere.color, b.atmosphere.color, t),
			decay = lerpColor(a.atmosphere.decay, b.atmosphere.decay, t),
		},
		bloom = {
			intensity = lerp(a.bloom.intensity, b.bloom.intensity, t),
			size = lerp(a.bloom.size, b.bloom.size, t),
			threshold = lerp(a.bloom.threshold, b.bloom.threshold, t),
		},
		saturation = lerp(a.saturation, b.saturation, t),
		contrast = lerp(a.contrast, b.contrast, t),
		tint = lerpColor(a.tint, b.tint, t),
		sunRays = { intensity = lerp(a.sunRays.intensity, b.sunRays.intensity, t), spread = lerp(a.sunRays.spread, b.sunRays.spread, t) },
	}
end

-- The look `seconds` into the cycle: the phase's own colours, blending into the next phase's over its last
-- BLEND_SECONDS; the sun creeps from the phase's clockTime to its clockEnd, then on to the next phase's clockTime
function DayCycle.lookAt(cycle: any, seconds: number): Look
	local index, into = locate(cycle, seconds)
	local phase = cycle.PHASES[index]
	local nextPhase = cycle.PHASES[index % #cycle.PHASES + 1]
	local hold = phase.seconds - cycle.BLEND_SECONDS
	local look: Look
	if into < hold then
		look = table.clone(phase.look)
		look.clockTime = clockLerp(phase.look.clockTime, phase.clockEnd, into / hold)
	else
		local t = (into - hold) / cycle.BLEND_SECONDS
		look = DayCycle.blend(phase.look, nextPhase.look, t)
		look.clockTime = clockLerp(phase.clockEnd, nextPhase.look.clockTime, t)
	end
	return look
end

local function phaseLook(cycle: any, name: string): Look
	for _, phase in cycle.PHASES do
		if phase.name == name then
			return phase.look
		end
	end
	return cycle.PHASES[1].look
end

-- The look outside town (the Wild, the Arena, the boss arenas)
function DayCycle.fixedLook(cycle: any): Look
	return phaseLook(cycle, cycle.FIXED)
end

-- The cycle's start time that puts `now` at the start of `phase` (the /time dev command)
function DayCycle.startFor(cycle: any, phase: string, now: number): number
	local at = 0
	for _, entry in cycle.PHASES do
		if entry.name == phase then
			return now - at
		end
		at += entry.seconds
	end
	return now
end

function DayCycle.inTown(cycle: any, x: number, z: number): boolean
	return math.abs(x) <= cycle.TOWN_REGION.HALF_X and math.abs(z) <= cycle.TOWN_REGION.HALF_Z
end

-- The welcome cinematic's time-lapse: 0 = morning, 1 = sunset, through the afternoon
function DayCycle.timelapse(cycle: any, progress: number): Look
	local t = math.clamp(progress, 0, 1)
	local morning, afternoon, sunset = phaseLook(cycle, "morning"), phaseLook(cycle, "afternoon"), phaseLook(cycle, "sunset")
	if t <= 0.5 then
		return DayCycle.blend(morning, afternoon, t * 2)
	end
	return DayCycle.blend(afternoon, sunset, (t - 0.5) * 2)
end

return DayCycle
