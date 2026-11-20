--!strict
-- The shapes of the tutorial's cues (Config/Cues; client Util/TutorialCues): the ring's and the spotlight hole's
-- corner from the thing they're on, and the ping ring's growth. Pure, Lune-tested (tests/CueShape).
local CueShape = {}

export type Size = { w: number, h: number }
export type Corner = { scale: number, offset: number }

-- The corner radius (px) of a ring standing `pad` px off a thing of `size` whose own corner is `corner` (a UICorner's
-- scale and offset; nil: none found, the ring keeps `fallback`). Never rounder than the thing itself.
function CueShape.radius(size: Size, corner: Corner?, pad: number, fallback: number): number
	if not corner then
		return fallback
	end
	local short = math.max(0, math.min(size.w, size.h))
	local own = math.min(corner.scale * short + corner.offset, short / 2)
	return math.max(0, own) + pad
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

-- Where the paw goes for a button at `target` (its left edge and width, px) on a screen `screenW` wide: on its
-- "right" when it hugs the left edge (a side-column tile: over it the paw sat on the tile above), else "above"
function CueShape.pawSide(target: { x: number, w: number }, screenW: number, sideShare: number): string
	if screenW > 0 and target.x + target.w <= screenW * sideShare then
		return "right"
	end
	return "above"
end

-- The ping ring `t` seconds in: how many px it has grown and its transparency (it starts over every `period`)
function CueShape.ping(t: number, cfg: { period: number, grow: number, from: number }): (number, number)
	local phase = (t % cfg.period) / cfg.period
	return cfg.grow * phase, cfg.from + (1 - cfg.from) * phase
end

return CueShape
