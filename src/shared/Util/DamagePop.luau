--!strict
-- How a damage number moves (Config/AttackFx NUMBERS, drawn by BattleController): it bursts in from small to bigger
-- than its size, settles back, rises and fades at the end; a critical one is bigger, lasts longer and wiggles as it
-- settles. Pure, Lune-tested.
local DamagePop = {}

export type Pose = { scale: number, rise: number, alpha: number, rotation: number }

local function styleOf(style: string, cfg: any): any
	return cfg[style] or cfg.normal
end

local function easeOut(x: number): number
	return 1 - (1 - x) * (1 - x)
end

function DamagePop.life(style: string, cfg: any): number
	return styleOf(style, cfg).life
end

-- The number `t` seconds after it appeared
function DamagePop.at(t: number, style: string, cfg: any): Pose
	local s = styleOf(style, cfg)
	local scale, rotation = 1, 0
	if t < s.pop then
		scale = s.start + (s.peak - s.start) * easeOut(math.max(0, t) / s.pop)
	elseif t < s.pop + cfg.settle then
		local x = (t - s.pop) / cfg.settle
		scale = s.peak + (1 - s.peak) * x * x * (3 - 2 * x)
		if s.wiggle then
			rotation = s.wiggle * math.sin(x * 3 * math.pi) * (1 - x)
		end
	end
	local progress = math.clamp(t / s.life, 0, 1)
	local fadeFrom = s.life * (1 - cfg.fade)
	local alpha = if t <= fadeFrom then 1 else math.max(0, 1 - (t - fadeFrom) / (s.life * cfg.fade))
	return { scale = scale, rise = s.rise * easeOut(progress), alpha = alpha, rotation = rotation }
end

return DamagePop
