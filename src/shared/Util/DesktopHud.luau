--!strict
-- Where the desktop HUD's pieces go (Config/DesktopHud; drawn by client UIController). Pure, Lune-tested
-- (tests/DesktopHud).
local DesktopHud = {}

export type Piece = { id: string, w: number }

local LAYOUTS = { bar = true, column = true }

-- This screen's desktop layout (Config/DesktopHud LAYOUT): "column" or "bar" on a mouse-and-keyboard screen; nil on a
-- touch screen, or switched off ("corners", or a name we don't know)
function DesktopHud.layout(touch: boolean, cfg: { LAYOUT: string }): string?
	if touch or not LAYOUTS[cfg.LAYOUT] then
		return nil
	end
	return cfg.LAYOUT
end

-- Whether this screen gets a desktop layout at all
function DesktopHud.active(touch: boolean, cfg: { LAYOUT: string }): boolean
	return DesktopHud.layout(touch, cfg) ~= nil
end

-- The column layout's cash: its right edge (px), `TOP.right` in from where the top bar's free room ends (`freeRight`;
-- 0: not known yet, the screen's edge)
function DesktopHud.topRight(freeRight: number, viewW: number, cfg: { TOP: { right: number } }): number
	local edge = if freeRight > 0 then math.min(freeRight, viewW) else viewW
	return edge - cfg.TOP.right
end

-- Whether the quests are a Phone app (Config QUESTS "phone") rather than the strip at the top right: a computer's
-- layouts only (a phone keeps its quest chip by the cash)
function DesktopHud.questsInPhone(layout: string?, cfg: { QUESTS: string }): boolean
	return layout ~= nil and cfg.QUESTS == "phone"
end

-- Where Pish sits on a computer: "quests" (on the quest strip's top edge) while there is one, "corner" (the bottom
-- right, by the weapon dial) with the quests in the Phone; nil off a computer's layouts
function DesktopHud.pishAt(layout: string?, cfg: { QUESTS: string, PISH: boolean }): string?
	if not layout or not cfg.PISH then
		return nil -- off a computer's layouts, or off the HUD altogether (Config PISH)
	end
	return if DesktopHud.questsInPhone(layout, cfg) then "corner" else "quests"
end

-- With no Pish to say them, a computer's toasts sit in the lower right: the stack's bottom-right corner (px), over
-- the weapon dial (`dialHeight` px tall with its margin; 0: no dial showing) so they never cover it
function DesktopHud.toastCorner(view: { w: number, h: number }, dialHeight: number, cfg: { TOASTS: { right: number, bottom: number, gap: number } }): { x: number, y: number }
	local t = cfg.TOASTS
	local lift = if dialHeight > 0 then dialHeight + t.gap else 0
	return { x = view.w - t.right, y = view.h - t.bottom - lift }
end

-- Whether your row (face, shop level, XP, buffs) sits under the cash at the top right: the column layout (the bar
-- layout keeps it beside the cash in its top row)
function DesktopHud.meUnderCash(layout: string?): boolean
	return layout == "column"
end

-- Whether your face sits beside the cash, out of your row: the column layout
function DesktopHud.faceBesideCash(layout: string?): boolean
	return layout == "column"
end

-- Your face beside the cash: its tap area as big as the coin looks (`coin` px at the cash pill's `scale`), the picture
-- inside its white `ring`
function DesktopHud.faceSize(coin: number, scale: number, ring: number): { hit: number, face: number }
	local hit = coin * scale
	return { hit = hit, face = hit - ring * 2 }
end

-- Where the rest of the right column starts (px down): its own start (`default`), or `gap` px under the top row's
-- bottom (`rowBottom`; nil: no top row showing) when that reaches lower
function DesktopHud.columnStart(rowBottom: number?, default: number, gap: number): number
	return if rowBottom then math.max(default, rowBottom + gap) else default
end

-- The top row's top edge (px from the screen's top): its middle level with Roblox's pills (`level`), lower when its
-- coin (`coinH` px, taller than the row's `rowH`) would come within `clear` px of the screen's top
function DesktopHud.cashTop(level: number, rowH: number, coinH: number, clear: number): number
	return math.max(level - rowH / 2, clear + math.max(0, coinH - rowH) / 2)
end

-- Where the side column hangs on a computer: px under the top bar (Config SIDE.top) in a desktop `layout`; nil
-- otherwise (the corners keep it at the screen's middle, a phone has its own top)
function DesktopHud.sideTop(layout: string?, cfg: { SIDE: { top: number } }): number?
	return if layout then cfg.SIDE.top else nil
end

-- The bottom bar: `pieces` left to right (a piece `w` px wide; 0 or less: not showing, left out), `gap` px apart,
-- centred on a screen `viewW` px wide as one, slid over when centred it would come within `clearLeft` px of the left
-- edge or `clearRight` of the right. Returns each showing piece's left edge by id; nil when they don't fit at all (the
-- caller keeps the corners)
function DesktopHud.bar(viewW: number, pieces: { Piece }, gap: number, clearLeft: number, clearRight: number): { [string]: number }?
	local shown: { Piece } = {}
	local total = 0
	for _, piece in pieces do
		if piece.w > 0 then
			table.insert(shown, piece)
			total += piece.w
		end
	end
	total += gap * math.max(0, #shown - 1)
	local room = viewW - clearLeft - clearRight
	if viewW <= 0 or #shown == 0 or total > room then
		return nil
	end
	local x = math.clamp(viewW / 2 - total / 2, clearLeft, viewW - clearRight - total)
	local spots: { [string]: number } = {}
	for _, piece in shown do
		spots[piece.id] = x
		x += piece.w + gap
	end
	return spots
end

-- The top row, `rowW` px wide: beside Roblox's buttons when the top bar's free room (`freeLeft` to `freeRight`, px)
-- holds it (`inBar`), else at the left edge under the bar
function DesktopHud.topRow(freeLeft: number, freeRight: number, rowW: number, cfg: { TOP: { left: number, side: number } }): { x: number, inBar: boolean }
	if freeRight - freeLeft >= rowW + cfg.TOP.left and freeRight > 0 then
		return { x = freeLeft + cfg.TOP.left, inBar = true }
	end
	return { x = cfg.TOP.side, inBar = false }
end

return DesktopHud
