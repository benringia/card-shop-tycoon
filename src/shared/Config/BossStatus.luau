--!strict
-- What's on a boss now, as chips under its HP bar with a tooltip each (owner 2026-11-12: "every boss debuff should be
-- shown below their healthbar with tooltips"; BattleSim.statusesOf reports them, Util/BossStatusRules words them,
-- BattleController draws them). `about` fills {value} and {seconds}; `plain` is said when a number is missing.
-- Plain ASCII and emoji only (Gotham and Fredoka draw other symbols as boxes).
return {
	-- left to right under the bar
	ORDER = { "shield", "guarded", "enraged", "stunned", "snared", "cursed", "burning" },
	KINDS = {
		shield = {
			icon = "🛡️",
			name = "Shield",
			color = { 120, 200, 255 },
			about = "Soaks the next {value} damage. Break it to stun the boss!",
			plain = "Soaks damage until it breaks. Break it to stun the boss!",
		},
		guarded = {
			icon = "👥", -- its summons guarding it (🪨 is too new: Roblox draws nothing)
			name = "Guarded",
			color = { 170, 150, 255 },
			about = "Takes {value}% less damage while its summons stand. Beat them first!",
			plain = "Takes less damage while its summons stand. Beat them first!",
		},
		enraged = {
			icon = "😡",
			name = "Enraged",
			color = { 255, 70, 50 },
			about = "Hits {value}% harder. Dodge its attacks!",
			plain = "Hits harder. Dodge its attacks!",
		},
		stunned = {
			icon = "💫",
			name = "Stunned",
			color = { 255, 220, 90 },
			about = "Can't attack for {seconds}s. Hit it now!",
			plain = "Can't attack for a moment. Hit it now!",
		},
		snared = {
			icon = "🌿",
			name = "Snared",
			color = { 120, 220, 96 },
			about = "Attacks {value}% slower for {seconds}s (Vine Snare).",
			plain = "Attacks slower for a while (Vine Snare).",
		},
		cursed = {
			icon = "🌑",
			name = "Cursed",
			color = { 175, 100, 255 },
			about = "Hits {value}% weaker for {seconds}s (Curse).",
			plain = "Hits weaker for a while (Curse).",
		},
		burning = {
			icon = "🔥",
			name = "Burning",
			color = { 255, 130, 40 },
			about = "Takes fire damage every second for {seconds}s (Inferno).",
			plain = "Takes fire damage every second for a while (Inferno).",
		},
	},
	CHIP = 34, -- a chip's side (px)
	PHONE_CHIP = 48, -- on a phone: a tap target
	TOOLTIP_SECONDS = 3, -- a tapped chip's tooltip stays this long
	TOOLTIP_WIDTH = 230,
}
