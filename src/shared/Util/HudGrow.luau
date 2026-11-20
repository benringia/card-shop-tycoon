--!strict
-- How much bigger a HUD piece draws on a desktop (Config/HudGrow): 1 at the reference height and under, growing with
-- the screen to the cap; always 1 on a touch screen (the phone's layout has its own sizes). Pure, Lune-tested.
local HudGrow = {}

function HudGrow.scale(height: number, touch: boolean, cfg: { REFERENCE: number, MAX: number }): number
	if touch then
		return 1
	end
	return math.clamp(height / cfg.REFERENCE, 1, cfg.MAX)
end

-- How much a window grows: the HUD's share (`grow`), as far as its `base` size still fits WINDOW_FIT of the screen each
-- way; never under 1 (a window that already fills the screen stays as it is)
function HudGrow.window(grow: number, base: { w: number, h: number }, screen: { w: number, h: number }, cfg: { WINDOW_FIT: number }): number
	if base.w <= 0 or base.h <= 0 then
		return 1
	end
	return math.max(1, math.min(grow, screen.w * cfg.WINDOW_FIT / base.w, screen.h * cfg.WINDOW_FIT / base.h))
end

-- A HUD piece's scale at rest from its attribute (Config/HudGrow ATTRIBUTE); 1 for a piece the HUD doesn't scale
function HudGrow.rest(value: any): number
	return if typeof(value) == "number" and value > 0 then value else 1
end

-- A bump on a piece resting at `rest`: where its scale starts, peaks (`size` times its own) and ends
function HudGrow.bump(rest: number, size: number): (number, number, number)
	return rest, rest * size, rest
end

return HudGrow
