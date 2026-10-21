--!strict
-- Motion kit for creature models that have no animations of their own: breathing when standing, a
-- hop-and-waddle walk on the ground, leaning into movement, and hovering for flyers. Returns a pose the
-- client applies to the model each frame. Pure (no requires, no Roblox APIs) so tests/ can run it in Lune.
local CreatureMotion = {}

export type Pose = {
	offsetY: number, -- studs above the ground point
	scaleX: number, -- width/depth multiplier
	scaleY: number, -- height multiplier
	roll: number, -- radians, side to side (waddle / bank)
	pitch: number, -- radians, forward lean
}

type Motion = {
	BREATH_SECONDS: number,
	BREATH_AMOUNT: number,
	HOP_HEIGHT: number,
	STEP_LENGTH: number,
	WADDLE_DEGREES: number,
	LEAN_DEGREES: number,
	LEAN_FULL_SPEED: number,
	LAND_SQUASH: number,
	WALK_SPEED_MIN: number,
	HOVER_HEIGHT: number,
	HOVER_BOB: number,
}

-- Squash-and-stretch that keeps the creature's volume: taller means thinner
local function stretch(scaleY: number): (number, number)
	return 1 / math.sqrt(scaleY), scaleY
end

-- time: seconds (any running clock); speed: studs per second; walked: studs moved so far (drives steps)
function CreatureMotion.getPose(motion: Motion, time: number, speed: number, walked: number, flying: boolean): Pose
	local breath = math.sin(2 * math.pi * time / motion.BREATH_SECONDS)
	local moving = speed >= motion.WALK_SPEED_MIN
	local phase = walked / motion.STEP_LENGTH
	local step = math.sin(math.pi * phase)
	local lean = if moving then math.rad(motion.LEAN_DEGREES) * math.min(speed / motion.LEAN_FULL_SPEED, 1) else 0

	if flying then
		local scaleX, scaleY = stretch(1 + motion.BREATH_AMOUNT * breath)
		return {
			offsetY = motion.HOVER_HEIGHT + motion.HOVER_BOB * breath,
			scaleX = scaleX,
			scaleY = scaleY,
			roll = if moving then math.rad(motion.WADDLE_DEGREES / 2) * step else 0,
			pitch = lean,
		}
	end

	if not moving then
		local scaleX, scaleY = stretch(1 + motion.BREATH_AMOUNT * breath)
		return { offsetY = 0, scaleX = scaleX, scaleY = scaleY, roll = 0, pitch = 0 }
	end

	-- Walking: one hop per step, swaying to the side of the stepping foot, squashing as it lands
	local height = math.abs(step)
	local squash = motion.LAND_SQUASH * (1 - height) ^ 4
	local scaleX, scaleY = stretch(1 - squash)
	return {
		offsetY = motion.HOP_HEIGHT * height,
		scaleX = scaleX,
		scaleY = scaleY,
		roll = math.rad(motion.WADDLE_DEGREES) * step,
		pitch = lean,
	}
end

return CreatureMotion
