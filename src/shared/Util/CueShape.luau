--!strict
-- The shapes of the tutorial's cues (Config/Cues; client Util/TutorialCues): the ring's and the spotlight hole's
-- corner from the thing they're on, and the ping ring's growth. Pure, Lune-tested (tests/CueShape).
local CueShape = {}

export type Size = { w: number, h: number }
export type Corner = { scale: number, offset: number }

-- The corner radius (px) of a ring standing `pad` px off a thing of `size` whose own corner is `corner` (a UICorner's
-- scale and offset; nil: none found, the ring keeps `fallback`). Never rounder than the thing itself. `scale`: how
-- much bigger the thing is drawn than designed (its UIScales: a computer's HUD grows); `size` is as drawn, so a corner
-- given in px grows with it
function CueShape.radius(size: Size, corner: Corner?, pad: number, fallback: number, scale: number?): number
	if not corner then
		return fallback
	end
	local short = math.max(0, math.min(size.w, size.h))
	local own = math.min(corner.scale * short + corner.offset * (scale or 1), short / 2)
	return math.max(0, own) + pad
end

-- How far off a thing its ring stands: just outside the thing's own outline (`stroke` px as designed, drawn times
-- `scale`; nil: it has none), `ring.gap` px clear
function CueShape.pad(stroke: number?, scale: number, ring: { gap: number }): number
	return (stroke or 0) * scale + ring.gap
end

-- Whether a piece inside a button fills it (its face: the piece whose corner is the button's shape), not a key cap,
-- a label or a glow
function CueShape.fills(piece: Size, target: Size): boolean
	if target.w <= 0 or target.h <= 0 then
		return false
	end
	local wide, tall = piece.w / target.w, piece.h / target.h
	return wide >= 0.8 and wide <= 1.15 and tall >= 0.8 and tall <= 1.15
end

-- Where the arrow goes for a button at `target` (its left edge and width, px) on a screen `screenW` wide: on its
-- "right" when it hugs the left edge (a side-column tile: over it the paw sat on the tile above), else "above"
function CueShape.pointerSide(target: { x: number, w: number }, screenW: number, sideShare: number): string
	if screenW > 0 and target.x + target.w <= screenW * sideShare then
		return "right"
	end
	return "above"
end

-- Where the arrow for a thing off the screen waits, and its turn (owner 2026-11-27, spec
-- 2026-11-27-tutorial-arrows-design: a goal off the screen or behind the camera showed nothing). `rel`: the thing in
-- the camera's frame (x right, y up, z ahead: positive in front); `view`: the screen (px). In front: on the edge along
-- the way from the screen's middle to it, inside `margin` px of the sides and the band between the `top` and `bottom`
-- shares of the height (clear of the talk card and the bottom tiles). Behind: at the nearer side, half way down the
-- band. `rotation`: degrees clockwise from pointing down (the arrow's picture)
function CueShape.offscreen(rel: { x: number, y: number, z: number }, view: Size, cfg: { margin: number, top: number, bottom: number }): { x: number, y: number, rotation: number }
	local left, right = cfg.margin, view.w - cfg.margin
	local top, bottom = view.h * cfg.top, view.h * (1 - cfg.bottom)
	if rel.z <= 0 then
		local onRight = rel.x >= 0
		return { x = if onRight then right else left, y = (top + bottom) / 2, rotation = if onRight then -90 else 90 }
	end
	local dx, dy = rel.x, -rel.y
	local cx, cy = view.w / 2, view.h / 2
	if math.abs(dx) < 1e-9 and math.abs(dy) < 1e-9 then
		return { x = cx, y = cy, rotation = 0 }
	end
	local reach = math.huge
	if dx > 0 then
		reach = math.min(reach, (right - cx) / dx)
	elseif dx < 0 then
		reach = math.min(reach, (left - cx) / dx)
	end
	if dy > 0 then
		reach = math.min(reach, (bottom - cy) / dy)
	elseif dy < 0 then
		reach = math.min(reach, (top - cy) / dy)
	end
	reach = math.max(0, reach)
	-- from -180 up to 180 (atan2 of a -0 height gives -180 for straight left, not 180)
	local rotation = (math.deg(math.atan2(dy, dx)) - 90 + 180) % 360 - 180
	return { x = cx + dx * reach, y = cy + dy * reach, rotation = rotation }
end

-- The ping ring `t` seconds in: how many px it has grown and its transparency (it starts over every `period`)
function CueShape.ping(t: number, cfg: { period: number, grow: number, from: number }): (number, number)
	local phase = (t % cfg.period) / cfg.period
	return cfg.grow * phase, cfg.from + (1 - cfg.from) * phase
end

return CueShape
