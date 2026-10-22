--!strict
-- Snappy UI motion (client only): panels, buttons, HUD fan, number bumps. Seconds and scales.
-- See DESIGN.md (UI) and Util/Motion.
return {
	OPEN_SECONDS = 0.16, -- a panel pops in from OPEN_FROM to full size
	CLOSE_SECONDS = 0.1, -- and shrinks back out
	OPEN_FROM = 0.85,
	PRESS_SCALE = 0.95, -- a button squashes this much while held
	PRESS_SECONDS = 0.06,
	BUMP_SCALE = 1.12, -- a number pill grows this much when its value changes
	BUMP_SECONDS = 0.12,
	FAN_STAGGER = 0.04, -- between each Manage fan button popping out
	FAN_SECONDS = 0.14,
}
