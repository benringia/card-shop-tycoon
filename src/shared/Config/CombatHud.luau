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
			color = rgb(167, 139, 250), icon = "DashSkill", emoji = "⚡", key = "E", name = "DASH",
			tip = "Dash through and slash everything in your path.",
		},
		pet = {
			color = rgb(74, 222, 128), icon = "Paw", emoji = "🐾", key = "R", name = "PET MOVE",
			tip = "Your creature's special move.", -- what the creature's move does instead, when it has one (SkillText)
		},
		signature = {
			color = rgb(250, 204, 21), icon = "Sparkle", emoji = "✨", key = nil, name = "SUPER MOVE",
			tip = "Your creature's super move.", -- likewise
		},
		swap = {
			color = rgb(200, 205, 220), icon = "Swap", emoji = "🔄", key = "1-3", name = "SWAP",
			tip = "Switch to another creature.",
		},
		run = { color = rgb(248, 113, 113), icon = "Run", emoji = "🏃", key = nil, name = "RUN", tip = "Leave the fight." },
	},
	-- The skill button per sword (owner's picks 2026-11-07): a round 1 sword's own icon (Config/UIIcons), name (its
	-- tooltip's title; shown in capitals under the button) and tooltip, by its Config/Swords moveset; the Steel Sword
	-- (and anything else) keeps BUTTONS.skill. Util/SkillText.swordSkill picks one
	SKILLS = {
		forgeSword = {
			icon = "SpinSkill", name = "Elemental Spin",
			tip = "Spin twice and blast a ring of your sword's element into every foe around you.",
		},
		verdantBlade = {
			icon = "Thornline", name = "Thornline",
			tip = "Plunge your blade into the ground: thorny vines race to the first foe and snap shut on it.",
		},
		sunforgedBlade = {
			icon = "Sunfall", name = "Sunfall Cleave",
			tip = "Leap, charge in the sun, then cleave a fire crescent that bursts on the first foe it hits.",
		},
		prismBlade = {
			icon = "PrismJudgment", name = "Prism Judgment",
			tip = "Five ghost swords circle your target and dive in one by one, then a rainbow pillar.",
		},
		-- every spear (weapons round 2; the owner's pick C, 2026-11-07: a spear with its afterimages)
		spear = {
			icon = "PiercingRush", name = "Piercing Rush",
			tip = "Rush forward tip-first and pierce every foe in a line.",
		},
		-- the Titan's Lance (weapons round 2.5; owner 2026-11-08: the lance wrapped in vines)
		titansLance = {
			icon = "LanceLeaves", name = "Titan's Wrath",
			tip = "Charge in a low stance, then one huge thrust tears a fissure through every foe ahead.",
		},
		-- the Magma Halberd and the Tidal Trident (weapons round 2.5 part 2; spare glyphs, spec 5)
		magmaHalberd = {
			icon = "HalberdFlames", name = "Magma Cleave",
			tip = "One huge flaming swipe hits every foe in front of you.",
		},
		tidalTrident = {
			icon = "TridentWave", name = "Torrent Strike",
			tip = "Slam the trident into the ground: torrents of water burst up round you, hitting every foe near you.",
		},
		-- every scythe (weapons round 3; a spare glyph: a crescent flung out with sparks)
		scythe = {
			icon = "CrescentSparks", name = "Reaping Cyclone",
			tip = "Spin three times, throwing rings of blades that hit every foe round you.",
		},
		-- the Rift Reaper (spec 5.4: the Skull glyph for its summoned Grim Reaper)
		riftReaper = {
			icon = "Skull", name = "Thousand Cuts",
			tip = "Summon the Grim Reaper: a thousand cuts, then it reaps every foe round you.",
		},
	} :: { [string]: { icon: string, name: string, tip: string } },
	-- Under every skill's tooltip (a dodge before a skill's hit cancels its damage: SwordRules.skillDodged)
	SKILL_DODGE_TIP = "Dodging before it lands cancels it.",
	NAME_FIGHTS = 3, -- boss fights that show the buttons' names (saved per player: swordFights)
	TIP_HOLD = 0.4, -- seconds a phone tap is held to show the tooltip (that press doesn't act)
	TIP_HOVER = 0.25, -- seconds the mouse rests on a button before its tooltip shows
	TIP_WIDTH = 230,
	COOLDOWN_SHADE = 0.45, -- transparency of the dark drain over a button cooling down
	-- The Super button's meter (owner 2026-11-06, option A): gold filling it from the bottom with its percent, then a
	-- glow pulsing between `pulse[1]` and `pulse[2]` transparency (`pulse[3]` radians a second) once it's full
	METER = {
		color = rgb(255, 196, 46),
		transparency = 0.35,
		pulse = { 0, 0.4, 4 },
		tip = "Charges as you fight: hits, sword hits and dodges.", -- under the super's own line in its tooltip
	},
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
		Frozen = { emoji = "🧊", name = "Frozen", color = { 170, 228, 255 } },
		Shocked = { emoji = "⚡", name = "Shocked", color = { 255, 225, 74 } },
		Electrocuted = { emoji = "⚡", name = "Electrocuted", color = { 140, 170, 255 } },
		Weakened = { emoji = "💔", name = "Weak", color = { 167, 123, 255 } },
	},
	DEBUFF_BADGE = 28, -- pixels: the badge on the portrait's corner
	-- Top-left: your headshot in a ring with your creature's card on a badge, then your HP and your creature's
	STATUS_WIDTH = 0.32, -- of the screen's width
	STATUS_MAX_WIDTH = 340,
	DOWN_COLOR = rgb(248, 113, 113),
	-- Boss fights: your party under the status (owner 2026-11-05, option A: "add an indication who to summon, for good
	-- UX not just numbers"; its look option C: "Remove strong/weak/out just add an effect or animation or icons for
	-- who's out/dead"). One tile per party card: its painting and name and its key on PC; the one fighting has a light
	-- running round its edge and a heartbeat pulse in place of its name; a fainted card lies face down (the card back's
	-- colours, Config/CardDesign BACK) with dizzy stars, one resting since an earlier fight with a Zzz; while swaps cool
	-- down the others dim with the seconds left. A tap swaps; the strip replaces the Swap button.
	PARTY_STRIP = {
		TILE = 72, -- pixels wide (phones PHONE_TILE)
		PHONE_TILE = 58,
		ART = 0.7, -- the painting's height, of the tile's width
		NAME = 12, -- text size (phones one less)
		GAP = 10, -- pixels between tiles
		TOP = 14, -- pixels below the status (the keys stick out above the tiles)
		EDGE = rgb(74, 64, 96),
		KEY = rgb(244, 195, 58),
		KEY_INK = rgb(43, 37, 64),
		RUN = { color = rgb(74, 222, 128), dark = rgb(27, 22, 38), turn = 200 }, -- the running light; degrees a second
		BEAT = { height = 6, color = rgb(74, 222, 128), seconds = 1.1 }, -- the heartbeat: a bright pulse sweeping across
		FAINTED = "💫",
		RESTING = "Zzz",
		DOWN_NAME = 0.4, -- a face-down card's name transparency
		COOLING_SHADE = 0.45, -- the painting's darkness while the swap cools down
	},
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
		-- The top bar (owner 2026-11-04, design A): a boss's in a gold-edged plate, a normal monster's slim and red,
		-- an elite's gold
		BOSS_PLATE = { edge = rgb(232, 176, 74), top = rgb(255, 122, 90), bottom = rgb(200, 40, 30) },
		MONSTER = { edge = rgb(224, 90, 79), top = rgb(255, 106, 90), bottom = rgb(200, 40, 30) },
		ELITE = { edge = rgb(255, 211, 74), top = rgb(255, 224, 138), bottom = rgb(232, 160, 26) },
	},
	-- The boss plate: a crest with the boss's element, its name big with its title and level under it, the bar with
	-- the HP number; the plate edged in gold. The slim monster bar: name and level over a thin bar, ELITE tag for an elite.
	TOP_BAR = {
		PLATE_HEIGHT = 74, -- pixels (phones: PLATE_PHONE_HEIGHT)
		PLATE_PHONE_HEIGHT = 62,
		CREST = 40, -- pixels, the element crest's ring (phones 32)
		NAME_SIZE = 24, -- phones 18
		TITLE_SIZE = 12, -- phones 10
		GOLD = rgb(232, 176, 74),
		NAME_COLOR = rgb(255, 226, 160),
		TITLE_COLOR = rgb(243, 217, 168),
		CREST_BACK = rgb(58, 20, 20),
		SLIM_WIDTH = 0.34, -- of the screen (phones 0.5), at most SLIM_MAX_WIDTH pixels
		SLIM_MAX_WIDTH = 380,
		SLIM_BAR = 12, -- pixels
		SLIM_NAME = 15,
		ELITE_TAG = rgb(255, 211, 74),
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
		FILL = 0.35, -- the whole screen's red at a full hit's peak (ScreenFx.flash), and how fast it fades
		FILL_SECONDS = 0.3,
		SHAKE = 0.6, -- the camera's jolt at a full hit (ScreenFx.shake)
		MIN = 0.35, -- opacity of the lightest hit
		PER_SHARE = 2, -- more opacity per share of your HP lost (a 30% hit flashes fully)
		LOW_SHARE = 0.3,
		PULSE_SECONDS = 1.1,
		PULSE_MIN = 0.15,
		PULSE_MAX = 0.45,
	},
}
