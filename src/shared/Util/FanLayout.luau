--!strict
-- Where the HUD's Manage fan buttons sit on their arc (pure, Lune-tested). Offsets from the fan's centre in
-- screen pixels: angle 0 points right, positive angles go up (screen y grows downwards).
export type Point = { x: number, y: number }

local FanLayout = {}

function FanLayout.positions(count: number, radius: number, fromDegrees: number, toDegrees: number): { Point }
	local points: { Point } = {}
	for index = 1, count do
		local t = if count == 1 then 0.5 else (index - 1) / (count - 1)
		local angle = math.rad(fromDegrees + (toDegrees - fromDegrees) * t)
		table.insert(points, { x = math.cos(angle) * radius, y = -math.sin(angle) * radius })
	end
	return points
end

return FanLayout
