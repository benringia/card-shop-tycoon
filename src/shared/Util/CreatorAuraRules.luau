--!strict
-- Where each of the Creator aura's cards is (Config/CreatorAura; client CreatorAuraController): circling the character
-- at chest height, evenly spaced, a lap every LAP seconds, bobbing BOB studs three times a lap so a lap ends where it
-- began. Pure, Lune-tested (tests/CreatorAura).
local CreatorAuraRules = {}

-- Card `index`'s offset from the HumanoidRootPart at `t` seconds (studs: x and z round the circle, y up)
function CreatorAuraRules.place(cfg: any, t: number, index: number): (number, number, number)
	local turn = 2 * math.pi
	local angle = turn * (t / cfg.LAP) + turn * (index - 1) / cfg.COUNT
	local bob = math.sin(3 * turn * (t / cfg.LAP) + index) * cfg.BOB
	return math.cos(angle) * cfg.RADIUS, cfg.HEIGHT + bob, math.sin(angle) * cfg.RADIUS
end

return CreatorAuraRules
