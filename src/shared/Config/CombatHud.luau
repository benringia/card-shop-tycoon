--!strict
-- The boss-fight HUD (spec 2026-11-02-you-in-the-fight-design): style 3 "anime slash" buttons in layout A
-- (UiLayout.combatButtons places them). Each button is a slanted dark panel with neon edges in its colour
-- (tools/textures/make_slant_buttons.py, uploaded), an icon (Config/UIIcons sheet 5; `emoji` if one is missing), a
-- cooldown that drains top-down with the seconds left, and on PC its key on a corner chip. Plain data.
local function rgb(r: number, g: number, b: number): { number }
	return { r, g, b }
end

return {
	SLANT_FILL = "rbxassetid://98874676446555",
	SLANT_EDGE = "rbxassetid://112893972215694",
	PANEL_COLOR = rgb(20, 16, 30), -- the dark face of every button
	PANEL_TRANSPARENCY = 0.15,
	-- name: shown under the button in the first NAME_FIGHTS boss fights (the pet and signature buttons show the
	-- creature's move instead); tip: the tooltip (hover on PC, hold on a phone), titled with that name
	BUTTONS = {
		attack = {
			color = rgb(255, 179, 71), icon = "Attack", emoji = "⚔️", key = "Click", name = "ATTACK",
			tip = "Swing your sword.",
		},
		dodge = {
			color = rgb(77, 163, 255), icon = "Dodge", emoji = "💨", key = "Shift", name = "DODGE",
			tip = "Dash out of the way.",
		},
		skill = {
			color = rgb(167, 139, 250), icon = "SpinSkill", emoji = "🌀", key = "E", name = "SPIN",
			tip = "Spin and hit everything around you.",
		},
		pet = {
			color = rgb(74, 222, 128), icon = "Paw", emoji = "🐾", key = "R", name = "PET MOVE",
			tip = "Your creature's special move.", -- PET_TIPS says what each element's does
		},
		signature = {
			color = rgb(250, 204, 21), icon = "Sparkle", emoji = "✨", key = nil, name = "SUPER MOVE",
			tip = "Your creature's super move.",
		},
		swap = {
			color = rgb(200, 205, 220), icon = "Swap", emoji = "🔄", key = "1-3", name = "SWAP",
			tip = "Switch to another creature.",
		},
		run = { color = rgb(248, 113, 113), icon = "Run", emoji = "🏃", key = nil, name = "RUN", tip = "Leave the fight." },
	},
	-- The pet button's tooltip by the creature's element (its ability, Config/Combat ABILITIES)
	PET_TIPS = {
		Ember = "Throw a fireball.",
		Tide = "Heal your creature.",
		Bloom = "Slow the boss down.",
		Volt = "Attack super fast.",
		Shade = "Make the boss hit weaker.",
	},
	NAME_FIGHTS = 3, -- boss fights that show the buttons' names (saved per player: swordFights)
	TIP_HOLD = 0.4, -- seconds a phone tap is held to show the tooltip (that press doesn't act)
	TIP_HOVER = 0.25, -- seconds the mouse rests on a button before its tooltip shows
	TIP_WIDTH = 230,
	COOLDOWN_SHADE = 0.45, -- transparency of the dark drain over a button cooling down
	READY_FLASH = 0.25, -- seconds a button glows when it's ready again
	PERK_CHIP_HEIGHT = 20, -- pixels: the fight perk chip under your creature's bar
	PERK_TOAST_SECONDS = 1.8, -- a swap shows the new creature's perk this long
	-- A boss's debuff on you (Config/Bosses DEBUFFS; the owner's approved look): a chip under the perk chip with the
	-- seconds left and a draining bar, a badge on your portrait, an effect on your character (Util/DebuffFx)
	DEBUFFS = {
		Entangled = { emoji = "🌿", name = "Tangled", color = { 63, 174, 74 } },
		Poison = { emoji = "🧪", name = "Poisoned", color = { 139, 230, 90 } },
		Burn = { emoji = "🔥", name = "Burning", color = { 255, 122, 26 } },
		Chilled = { emoji = "❄️", name = "Chilled", color = { 124, 200, 255 } },
		Shocked = { emoji = "⚡", name = "Shocked", color = { 255, 225, 74 } },
		Weakened = { emoji = "💔", name = "Weak", color = { 167, 123, 255 } },
	},
	DEBUFF_BADGE = 28, -- pixels: the badge on the portrait's corner
	-- Top-left: your headshot in a ring with your creature's card on a badge, then your HP and your creature's
	STATUS_WIDTH = 0.32, -- of the screen's width
	STATUS_MAX_WIDTH = 340,
	DOWN_COLOR = rgb(248, 113, 113),
	-- HP bars in the "slanted neon" look (tools/textures/make_hp_bars.py, uploaded): parallelograms slanted like the
	-- buttons, a dark rim around a sunken well, a glowing edge in the bar's colour, a tick every 20% and a shaded fill
	-- (top to bottom colours). A hit drops the fill at once, leaves a ghost of the lost HP that holds, then drains, and
	-- flashes the bar white; a heal moves a pale lead ahead and the fill rises to it. Util/HpBarRules times it.
	HP_BAR = {
		BACK = "rbxassetid://83947078396240",
		EDGE = "rbxassetid://124697916056376",
		FILL = "rbxassetid://109702317103896",
		TICK = "rbxassetid://127889649311570",
		IMAGE_HEIGHT = 40, -- pixels: hp_back and hp_fill are drawn at twice a 20 px bar
		EDGE_PAD = 16, -- pixels of glow around hp_edge's bar
		RIM = 6, -- pixels of rim around hp_back's well
		SLANT = 0.325, -- the slant's run per pixel of height (tan 18 degrees)
		TICKS = 5, -- a tick every 20%
		TICK_TRANSPARENCY = 0.6,
		GLOSS = 0.45, -- transparency of the shine along the top of the well (fading out by 38% down)
		GHOST_HOLD = 0.35, -- seconds the lost HP stays before draining
		GHOST_DRAIN = 0.45,
		HEAL_RISE = 0.5, -- seconds the fill takes to rise after a heal
		FLASH = 0.18, -- seconds of the white flash on a hit
		HEIGHT = 20, -- pixels: your bar and the boss's
		SMALL_HEIGHT = 15, -- your creature's
		PLAYER = { edge = rgb(62, 224, 138), top = rgb(157, 255, 208), bottom = rgb(18, 122, 69) },
		CREATURE = { edge = rgb(34, 197, 94), top = rgb(127, 240, 170), bottom = rgb(14, 101, 50) },
		BOSS = { edge = rgb(255, 90, 74), top = rgb(255, 157, 138), bottom = rgb(125, 21, 16) },
		GHOST = { top = rgb(255, 138, 122), bottom = rgb(224, 54, 42) }, -- red: the HP you just lost
		BOSS_GHOST = { top = rgb(255, 244, 201), bottom = rgb(255, 213, 106) }, -- pale gold reads on a red bar
		HEAL_LEAD = { top = rgb(184, 255, 212), bottom = rgb(184, 255, 212) },
	},
	PORTRAIT = {
		SIZE = 66, -- pixels, the ring's outside (phones: PHONE_SIZE)
		PHONE_SIZE = 54,
		RING = 4, -- pixels of ring around the headshot
		BADGE = 0.42, -- the creature badge, of the ring's size
		RING_COLORS = { rgb(125, 255, 192), rgb(62, 224, 138), rgb(26, 110, 67) }, -- light top-left to dark
		HURT_COLORS = { rgb(255, 154, 143), rgb(255, 74, 58), rgb(122, 20, 20) },
		HURT_SECONDS = 0.35, -- the ring stays red this long after a hit
		SHAKE = { seconds = 0.25, offsets = { { -4, 1 }, { 4, -1 }, { -3, 0 }, { 2, 1 } } }, -- pixels at 20/40/60/80%
	},
	-- The screen's edges flash red when you're hit (not your creature): about half a second, stronger for a bigger
	-- share of your HP; below LOW_SHARE they keep pulsing softly (0 turns the pulse off)
	HIT_FLASH = {
		IMAGE = "rbxassetid://125905162394540",
		COLOR = rgb(200, 0, 0),
		SECONDS = 0.55,
		MIN = 0.35, -- opacity of the lightest hit
		PER_SHARE = 2, -- more opacity per share of your HP lost (a 30% hit flashes fully)
		LOW_SHARE = 0.3,
		PULSE_SECONDS = 1.1,
		PULSE_MIN = 0.15,
		PULSE_MAX = 0.45,
	},
}
