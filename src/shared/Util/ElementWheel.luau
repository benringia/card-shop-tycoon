--!strict
-- The character window's element wheel (owner 2026-11-12, pick A): where its arrows go, one per "beats" in
-- Config/Combat, from the winner's icon to the beaten one's, starting and stopping `clear` px from their centres; a
-- pair that beat each other (Electric and Dark) gets two arrows pushed `pairOffset` px apart, one each side of the
-- line. Pure, Lune-tested; client Util/ElementWheelView draws it.
local ElementWheel = {}

export type Point = { x: number, y: number, nameAbove: boolean? }
export type Arrow = { from: string, to: string, x1: number, y1: number, x2: number, y2: number }

function ElementWheel.arrows(beats: { [string]: { string } }, nodes: { [string]: Point }, clear: number, pairOffset: number): { Arrow }
	local list: { Arrow } = {}
	for from, beaten in beats do
		for _, to in beaten do
			local a, b = nodes[from], nodes[to]
			if a and b then
				local dx, dy = b.x - a.x, b.y - a.y
				local length = math.sqrt(dx * dx + dy * dy)
				if length > clear * 2 then
					local ux, uy = dx / length, dy / length
					-- both ways: each arrow keeps to its own right of the line
					local back = table.find(beats[to] or {}, from) ~= nil
					local side = if back then pairOffset else 0
					local nx, ny = -uy * side, ux * side
					table.insert(list, {
						from = from,
						to = to,
						x1 = a.x + ux * clear + nx,
						y1 = a.y + uy * clear + ny,
						x2 = b.x - ux * clear + nx,
						y2 = b.y - uy * clear + ny,
					})
				end
			end
		end
	end
	table.sort(list, function(p, q)
		return if p.from == q.from then p.to < q.to else p.from < q.from
	end)
	return list
end

return ElementWheel
