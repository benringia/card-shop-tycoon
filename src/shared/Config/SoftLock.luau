--!strict
-- The soft lock in fights (owner 2026-11-15, look A: "Ring under the enemy + arrow over it"; no camera lock): tap or
-- click an enemy, press Tab or the fight's Target button to lock it; your sword turns to it when you attack and your
-- creature attacks it (BattleSim.setFocus); tap it again or it falls and the lock lets go. With nothing locked a soft
-- white ring shows who your sword would hit. Client Util/SoftLock, Util/SoftLockRules. Plain data: tests/SoftLockRules.
return {
	KEY = "Tab",
	TAP_PIXELS = 14, -- a press that moves less than this...
	TAP_SECONDS = 0.35, -- ...and lets go within this is a tap (more: turning the camera)
	PICK_SLACK = 24, -- px round an enemy's outline a tap still lands on it
	-- The ring under the target (the fight rings' outline and glow decals, Config/SwordFx) and the arrow over it
	-- a thin outline would hide in the tall grass (seen 2026-11-16): a bright outline over a strong glow band, lifted
	LOCKED = { color = { 255, 215, 70 }, glow = { 255, 190, 30 }, outline = 0, glowTransparency = 0.1, pulse = 0.08 },
	AUTO = { color = { 255, 255, 255 }, glow = { 255, 255, 255 }, outline = 0.3, glowTransparency = 0.65, pulse = 0 },
	RING_LIFT = 1, -- studs over the ground: the arenas' tall grass hid it lower (seen 2026-11-16)
	RING_MARGIN = 2, -- studs past the enemy's hit radius
	RING_MIN = 5, -- studs across, at least
	-- the owner's pick 2 (2026-11-16): three glossy gold chevrons (assets/ui/target/TargetChevrons.png, cut from a
	-- Figma sheet by tools/ui-art/cut_product_picture.py); px across, studs over its top, studs up and down, a second
	ARROW = { image = "rbxassetid://132529171087297", size = 64, above = 1.5, bob = 0.35, bobSpeed = 4 },
	-- a big boss's head reaches the top HUD (its HP bar): the arrow slides down its body to stay this many px below the
	-- screen's top
	ARROW_MIN_Y = 125, -- the chevrons are 64 px tall, centred: all of them under the boss bar
	-- a solid ring of neon pieces over the glow (a decal outline alone was too thin in the grass, 2026-11-16)
	SEGMENTS = { count = 36, thick = 0.35, tall = 0.25, lockedTransparency = 0, autoTransparency = 0.55 },
	REMOTE_GAP = 0.2, -- seconds between lock changes sent to the server
}
