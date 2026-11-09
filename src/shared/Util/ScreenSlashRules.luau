--!strict
-- Thousand Cuts' slashes across your own screen (owner 2026-11-09: "the slashes are hard to see. can add the slashes
-- and flashes across the screen"): where each wave's lines cross the screen and the harvest's big X. Positions are
-- shares of the screen (0-1), `length` a share of its diagonal, `angle` degrees. Pure, so Lune tests it; drawn by the
-- client's Util/ScreenSlashes.
local ScreenSlashRules = {}

export type Slash = { x: number, y: number, angle: number, length: number }

-- `count` slashes spread round every angle (an even step from a random start, each jittered by up to a sixth of a step
-- either way, so no two run nearly parallel), each through a random point in the middle 70% of the screen, 1.1-1.3
-- times the screen's diagonal (past its edges)
function ScreenSlashRules.wave(count: number, rand: () -> number): { Slash }
	local slashes: { Slash } = {}
	local step = 180 / math.max(1, count)
	local start = rand() * 180
	for index = 0, count - 1 do
		local angle = (start + index * step + (rand() - 0.5) * step / 3) % 180
		table.insert(slashes, {
			x = 0.15 + rand() * 0.7,
			y = 0.15 + rand() * 0.7,
			angle = angle,
			length = 1.1 + rand() * 0.2,
		})
	end
	return slashes
end

-- The harvest's X: two long slashes crossing at the middle of the screen
function ScreenSlashRules.cross(): { Slash }
	return {
		{ x = 0.5, y = 0.5, angle = 35, length = 1.4 },
		{ x = 0.5, y = 0.5, angle = -35, length = 1.4 },
	}
end

return ScreenSlashRules
