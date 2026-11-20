--!strict
-- The desktop HUD (owner 2026-11-21): on a mouse-and-keyboard screen the HUD groups by purpose. Three mockups were
-- shown; the owner picked A ("lets go A, and we can drop the rating"), saw it in the game and changed to C ("can you
-- change it to C? Keep combat UI for now."). LAYOUT picks one:
--   "column" (C, in use): the cash on top of the right column, in the top bar's strip over the quests and their
--     chips; your creatures and your row (face, level) bottom left as before; the weapon dial bottom right beside
--     Pish, who peeks over the screen's edge with his toasts; the tiles bottom centre.
--   "bar" (A): what you have (your row, the cash) in a top row beside Roblox's buttons; what you press (creatures,
--     weapon dial, tiles) in one bar at the bottom centre.
--   "corners": as before either (the cash bottom right under Pish).
-- No rating chip in any of them (Config/Customers RATING.chip.hud). The fight HUD is its own (a fight hides these
-- pieces). Touch screens keep their own layout (Util/CompactHud). Rules: Util/DesktopHud; drawn by UIController.
-- Plain data, Lune-tested.
return {
	LAYOUT = "column",
	-- Where a computer's quests live (owner 2026-11-21: "can we just put the quests inside phone and just add a
	-- noticeable notification on the phone everytime there's some changes to the quest or anything that is inside the
	-- phone"): "phone": a Quests app on the Phone, whose tile wears a red count of what waits inside and moves when
	-- something in it changes (Util/PhoneNotice, client Util/Hud.setBadge / notice); "strip": the quest strip at the top
	-- right, as before. With no strip to sit on, Pish waits in the bottom-right corner by the weapon dial
	-- (DesktopHud.pishAt) until a design for him there is picked
	QUESTS = "phone",
	-- The peeking Pish on a computer's HUD: off (owner 2026-11-21, after three designs for him by the weapons: "okay
	-- just remove pish. and make the toast notification appear on the lower right"). true puts him back (on the quest
	-- strip, or in the bottom-right corner with the quests in the Phone: DesktopHud.pishAt). Without him the toasts
	-- are plain bubbles in the lower right: `right` and `bottom` px from the screen's edges, `gap` px over the weapon
	-- dial when it's there (DesktopHud.toastCorner)
	PISH = false,
	TOASTS = { right = 12, bottom = 16, gap = 8 },
	-- Your face at the top right (owner 2026-11-21: "Make the player avatar as small as the coin. then put the avatar
	-- beside the coin"): in the column layout it leaves your row for the cash's line, left of the pill, as big as the
	-- coin looks with its white `ring` (px) included (DesktopHud.faceSize); the line under them (your level, XP bar
	-- and buffs) is `rowHeight` px tall, your buffs left of the bar so the bar ends flush with the cash; `gap` px
	-- between your face and the coin
	FACE = { ring = 3, rowHeight = 36, gap = 10 },
	-- The cash pill's size on a computer (owner 2026-11-21: "reduce size a bit for coin pill"; 1 before)
	CASH_SCALE = 0.85,
	GAP = 14, -- px between the bar's pieces (creatures, weapon dial, tiles), times the HUD's scale
	CLEAR = 12, -- px the bar keeps from the side column on its left and from Pish on its right
	-- The top row: `left` px right of Roblox's buttons and `top` px under the screen's top; `gap` between your row and
	-- the cash; on a window too narrow for it beside the buttons, `side` px from the left edge and `under` px under the
	-- top bar
	-- `right`: the column layout's cash, px from the right end of the top bar's free room (the quest strip's margin)
	-- `level`: px from the screen's top to the middle of Roblox's own pills: the row's middle sits there (owner
	-- 2026-11-21: "Level the coins with the roblox pills to add gap at the coin pill top"), its coin (taller than the
	-- pill) at least `clear` px under the screen's top (DesktopHud.cashTop)
	-- `stack`: the column layout's row of you (face, shop level, XP, buffs) sits this many px under the cash (owner
	-- 2026-11-21: "move character info and level below the coin"); `below`: what follows in that column (the team
	-- strip, the Turts and event pills) starts this far under your row (DesktopHud.columnStart)
	TOP = { left = 10, top = 4, gap = 14, side = 12, under = 6, right = 16, level = 34, clear = 4, stack = 6, below = 14 },
	-- The side column (the Phone, the gift) hangs `top` px under the top bar, below Roblox's buttons, not from the
	-- screen's middle (owner 2026-11-21: "make phone and daily gift move up below roblox"); the room is for the first
	-- tile's icon, which pops out over its top
	SIDE = { top = 24 },
	-- Pish on a computer (owner 2026-11-21: "move pish icon at the top of quests"): perched on the quest strip's top
	-- edge, `inset` px in from its left end, his toasts hanging to his left (Config/Toasts SIDE_*, ToastRules.mode)
	-- `sink`: px more of him behind the strip than his sticker's own hidden foot (owner: "make pish icon look like
	-- he's peeking from the quest box")
	PERCH = { inset = 6, sink = 6 },
}
