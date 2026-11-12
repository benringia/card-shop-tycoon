--!strict
-- The phone HUD, slimmed (owner 2026-11-13, pick A): the cash as the one pill shows it, and how far the level badge's
-- XP ring is drawn (UIController). Pure, Lune-tested.
local CompactHud = {}

-- Cash on a phone: whole dollars with commas ("$53,661"), millions short ("$1.25M")
function CompactHud.money(cash: number): string
	local whole = math.max(0, math.floor(cash))
	if whole >= 1000000 then
		local millions = string.format("%.2f", whole / 1000000)
		millions = string.gsub(string.gsub(millions, "0+$", ""), "%.$", "")
		return `${millions}M`
	end
	local text = tostring(whole)
	local done = text
	repeat
		text = done
		done = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
	until done == text
	return `${done}`
end

-- The XP ring at `share` full: how far its right half and then its left half turn (each a half circle clipped, its
-- stroke's gradient turned 0-180 degrees), the right half first
function CompactHud.ring(share: number): (number, number)
	local degrees = math.clamp(share, 0, 1) * 360
	return math.clamp(degrees, 0, 180), math.clamp(degrees - 180, 0, 180)
end

-- How far the HUD mascot (Config/HudMascot: its peek picture, its paws `overlap` down over the bar) pokes up over the
-- party bar's top edge, px before the HUD's scale; 0 with no picture
function CompactHud.mascotRise(cfg: any): number
	if cfg.images.peek == "" then
		return 0
	end
	return cfg.size.peek[2] - cfg.offset.overlap
end

-- How far up the phone's column moves (the mascot's room `rise` at the HUD `scale`), into the strip beside Roblox's top
-- bar (`inset` px tall; the column starts `top` px under it), never closer than 4 px to the screen's top
function CompactHud.lift(rise: number, scale: number, inset: number, top: number): number
	return math.max(0, math.min(rise * scale, inset + top - 4))
end

return CompactHud
