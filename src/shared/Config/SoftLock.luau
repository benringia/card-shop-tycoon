--!strict
-- The soft lock in fights (owner 2026-11-15; no camera lock): tap or click an enemy, press Tab or the fight's Target
-- button to lock it; your sword turns to it when you attack and your creature attacks it (BattleSim.setFocus); tap it
-- again or it falls and the lock lets go. The marker (owner 2026-11-16, pick A: "lock target color could easily be
-- mistaken for a boss attack ring"): nothing on the ground, which is for danger only (a boss's orange closing rings);
-- the target glows with a cyan outline (a Highlight on its model) far round the wheel from the warning's orange, and
-- three glossy cyan chevrons bob over it. With nothing locked a faint white outline shows who your sword would hit.
-- Client Util/SoftLock, Util/SoftLockRules. Plain data: tests/SoftLockRules.
return {
	KEY = "Tab",
	TAP_PIXELS = 14, -- a press that moves less than this...
	TAP_SECONDS = 0.35, -- ...and lets go within this is a tap (more: turning the camera)
	PICK_SLACK = 24, -- px round an enemy's outline a tap still lands on it
	-- The outline on the target (a Highlight drawn over everything, so tall grass can't hide it): its colour and
	-- transparency, a soft fill, and how much the fill breathes
	LOCKED = { outline = { 90, 225, 255 }, outlineTransparency = 0, fill = { 90, 225, 255 }, fillTransparency = 0.8, pulse = 0.08 },
	AUTO = { outline = { 255, 255, 255 }, outlineTransparency = 0.5, fill = { 255, 255, 255 }, fillTransparency = 1, pulse = 0 },
	-- the owner's pick 2 (2026-11-16): three glossy chevrons, recoloured cyan for pick A (assets/ui/target/
	-- TargetChevronsCyan.png from TargetChevrons.png, the gold set cut from a Figma sheet by
	-- tools/ui-art/cut_product_picture.py); px across, studs over its top, studs up and down, a second
	ARROW = { image = "rbxassetid://103021169786772", size = 64, above = 1.5, bob = 0.35, bobSpeed = 4 },
	-- a big boss's head reaches the top HUD (its HP bar): the arrow slides down its body to stay this many px below the
	-- screen's top
	ARROW_MIN_Y = 125, -- the chevrons are 64 px tall, centred: all of them under the boss bar
	REMOTE_GAP = 0.2, -- seconds between lock changes sent to the server
}
