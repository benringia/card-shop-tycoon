--!strict
-- Where a glass case's upright, spinning cards stand (UI project 3 spec section 3). Pure, Lune-tested.
-- Positions are card centres in the case part's space: centre at the origin, front at -Z.
export type Vec = { x: number, y: number, z: number } -- as ShelfStock.Vec (pure modules here don't require each other)
export type Upright = {
	cardSize: { x: number, y: number },
	columns: number,
	spacing: number,
	rowDepth: number,
	backRaise: number,
	bedHeight: number,
}

local ShowcaseLayout = {}

-- Rows of `columns` left to right, the front row first; each row behind stands `backRaise` higher
function ShowcaseLayout.uprightSlots(count: number, size: Vec, look: Upright): { Vec }
	local rows = math.max(1, math.ceil(count / look.columns))
	local feet = -size.y / 2 + look.bedHeight * size.y
	local slots = {}
	for index = 1, count do
		local row = (index - 1) // look.columns
		local column = (index - 1) % look.columns
		table.insert(slots, {
			x = (column - (look.columns - 1) / 2) * look.spacing,
			y = feet + look.cardSize.y / 2 + row * look.backRaise,
			z = (row - (rows - 1) / 2) * look.rowDepth,
		})
	end
	return slots
end

return ShowcaseLayout
