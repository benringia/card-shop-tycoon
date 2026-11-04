--!strict
-- What a mouse over a button in a window does (spec 2026-11-04-round5-design section 1, look A "Soft glow"): a soft
-- button's own glow brightens, a row, tile or slot gets a soft lilac edge, and nothing ever changes size. Decided at
-- each hover, so a button a controller greys out stays dark. Pure (no requires, no Roblox APIs), Lune-tested.
local HoverRules = {}

export type Kind = "glow" | "edge" | "none"

-- soft: a cotton candy button (UIKit softButton); backgroundTransparency: the button's own; locked: drawn in the
-- disabled colour. Invisible click areas and greyed-out buttons don't light up.
function HoverRules.kind(soft: boolean, backgroundTransparency: number, locked: boolean): Kind
	if locked or backgroundTransparency >= 0.99 then
		return "none"
	end
	return if soft then "glow" else "edge"
end

return HoverRules
