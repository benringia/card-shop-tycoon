--!strict
-- The 3D binder's geometry (pure, Lune-tested; spec 2026-10-29-3d-binder-design.md): where each of a page's pockets
-- sits and which one is under a point, and how far and how offset the camera must be to fit the binder in a
-- rectangle of the screen. Pages are measured in fractions: u from the page's left edge, v from its top.
local BinderFit = {}

export type Layout = { columns: number, rows: number, padX: number, padY: number, gap: number }
export type Box = { u0: number, v0: number, u1: number, v1: number }
type Size = { w: number, h: number }
type Rect = { x: number, y: number, w: number, h: number }

local function pocketSize(layout: Layout): (number, number)
	local width = (1 - 2 * layout.padX - (layout.columns - 1) * layout.gap) / layout.columns
	local height = (1 - 2 * layout.padY - (layout.rows - 1) * layout.gap) / layout.rows
	return width, height
end

-- Pocket `index` (1 at the top left, then along the row) as page fractions
function BinderFit.pocketBox(index: number, layout: Layout): Box
	local width, height = pocketSize(layout)
	local column = (index - 1) % layout.columns
	local row = (index - 1) // layout.columns
	local u0 = layout.padX + column * (width + layout.gap)
	local v0 = layout.padY + row * (height + layout.gap)
	return { u0 = u0, v0 = v0, u1 = u0 + width, v1 = v0 + height }
end

-- Which cell along one axis a fraction falls in (0-based), or nil in a pad or a gap
local function cell(at: number, pad: number, size: number, gap: number, count: number): number?
	local offset = at - pad
	if offset < 0 then
		return nil
	end
	local index = offset // (size + gap)
	if index >= count or offset - index * (size + gap) > size then
		return nil
	end
	return index
end

-- The pocket under a page point, nil in the pads, the gaps or off the page
function BinderFit.pocketAt(u: number, v: number, layout: Layout): number?
	local width, height = pocketSize(layout)
	local column = cell(u, layout.padX, width, layout.gap, layout.columns)
	local row = cell(v, layout.padY, height, layout.gap, layout.rows)
	if not column or not row then
		return nil
	end
	return row * layout.columns + column + 1
end

-- The camera distance (studs) at which a binder `book` studs big, leaning back `tilt` degrees (so it shows
-- h * cos(tilt) tall), fits inside `rect` pixels of a `view`-pixel screen with a vertical field of view fovY
function BinderFit.distance(book: Size, rect: Size, view: Size, fovY: number, tilt: number): number
	local tanY = math.tan(math.rad(fovY) / 2)
	local tanX = tanY * view.w / view.h
	local byWidth = book.w * view.w / (2 * tanX * rect.w)
	local byHeight = book.h * math.cos(math.rad(tilt)) * view.h / (2 * tanY * rect.h)
	return math.max(byWidth, byHeight)
end

-- How far (studs, along the camera's right and up) the binder's centre must sit from the view's axis at `distance`
-- so it shows at the centre of `rect`; up is positive
function BinderFit.shift(rect: Rect, view: Size, distance: number, fovY: number): (number, number)
	local studsPerPixel = 2 * distance * math.tan(math.rad(fovY) / 2) / view.h
	local centreX = rect.x + rect.w / 2
	local centreY = rect.y + rect.h / 2
	return (centreX - view.w / 2) * studsPerPixel, -(centreY - view.h / 2) * studsPerPixel
end

return BinderFit
