--!strict
-- What a mouse over a button in a window does (spec 2026-11-04-round5-design section 1, look A "Soft glow"): a soft
-- button's own glow brightens, a row, tile or slot gets a soft lilac edge, and nothing ever changes size. Decided at
-- each hover, so a button a controller greys out stays dark. Pure (no requires, no Roblox APIs), Lune-tested.
local HoverRules = {}

export type Kind = "glow" | "edge" | "none"

-- soft: a cotton candy button (UIKit softButton); backgroundTransparency: the button's own; locked: drawn in the
-- disabled colour; laysOut: the button lays out its own children (a list or grid layout in it), which would stack the
-- hover's pieces in with them, so it gets none (build such content in an inner frame). Invisible click areas and
-- greyed-out buttons don't light up.
function HoverRules.kind(soft: boolean, backgroundTransparency: number, locked: boolean, laysOut: boolean?): Kind
	if locked or laysOut or backgroundTransparency >= 0.99 then
		return "none"
	end
	return if soft then "glow" else "edge"
end

-- A hover layer's corner from its button's (a UDim's scale and offset), `inset` px in: a round button (scale 0.5) stays
-- round, an offset corner gets a little tighter, never below 0
function HoverRules.insetCorner(scale: number, offset: number, inset: number): (number, number)
	return scale, math.max(0, offset - inset)
end

return HoverRules
