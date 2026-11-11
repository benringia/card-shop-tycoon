--!strict
-- Footsteps (the owner 2026-11-11; Config/Footsteps): which surface a floor sounds like, when a walking character takes
-- its next step, and which of a surface's sounds plays. Pure, Lune-tested (tests/FootstepRules); FootstepController
-- plays them.
local FootstepRules = {}

-- The surface a floor material (its Enum.Material name) sounds like; nil with no floor to step on (in the air, water)
function FootstepRules.surface(material: string, cfg: any): string?
	if cfg.NONE[material] then
		return nil
	end
	return cfg.MATERIALS[material] or cfg.DEFAULT
end

-- Ground covered since the last step (`carry` studs) after `dt` seconds at `speed` studs a second: a step each `stride`
-- studs, none (and nothing kept) below `minSpeed`
function FootstepRules.advance(carry: number, speed: number, dt: number, stride: number, minSpeed: number): (number, boolean)
	if speed < minSpeed then
		return 0, false
	end
	local covered = carry + speed * dt
	if covered >= stride then
		return covered - stride, true
	end
	return covered, false
end

-- Which of `count` sounds plays (by `roll`, 0-1): never `last` again while there's another
function FootstepRules.pick(count: number, roll: number, last: number?): number
	if count <= 1 then
		return 1
	end
	local options = {}
	for index = 1, count do
		if index ~= last then
			table.insert(options, index)
		end
	end
	return options[math.floor(math.clamp(roll, 0, 0.999999) * #options) + 1]
end

return FootstepRules
