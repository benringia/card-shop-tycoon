--!strict
local UiLayout = require("../src/shared/Util/UiLayout")
local expect = require("./lib/expect")

local SCREEN = { w = 1000, h = 600 }
local TIP = { w = 200, h = 150 }

return {
	["beside: right of the anchor when it fits"] = function()
		local spot = UiLayout.beside({ x = 100, y = 50, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.x, 168, "right of the card")
		expect.equal(spot.y, 50, "level with it")
	end,
	["beside: flips left near the right edge"] = function()
		local spot = UiLayout.beside({ x = 850, y = 50, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.x, 642, "left of the card")
	end,
	["beside: kept on screen at the bottom"] = function()
		local spot = UiLayout.beside({ x = 100, y = 560, w = 60, h = 80 }, TIP, SCREEN, 8)
		expect.equal(spot.y, 450, "pushed up to fit")
	end,
	["beside: no room either side goes above, never over the card"] = function()
		local spot = UiLayout.beside({ x = 150, y = 300, w = 60, h = 80 }, TIP, { w = 360, h = 600 }, 8)
		expect.equal(spot.y, 142, "above the card")
		expect.equal(spot.x, 80, "centred on it")
	end,
	["above: centred over the anchor, clamped to the screen"] = function()
		local spot = UiLayout.above({ x = 900, y = 500, w = 50, h = 60 }, { w = 230, h = 180 }, SCREEN, 8)
		expect.equal(spot.x, 770, "clamped to the right edge")
		expect.equal(spot.y, 312, "above the slot")
	end,
	["above: no room above goes below the anchor, never over it"] = function()
		-- the HUD party bar on a touch phone sits near the top of the screen
		local spot = UiLayout.above({ x = 600, y = 80, w = 60, h = 80 }, { w = 230, h = 180 }, { w = 750, h = 381 }, 10)
		expect.equal(spot.y, 170, "below the slot")
		expect.equal(spot.x, 515, "centred on it")
	end,
	["beside: no side room falls back around the pocket, not the whole book"] = function()
		local book = { x = 100, y = 40, w = 560, h = 100 }
		local pocket = { x = 500, y = 40, w = 100, h = 100 }
		local spot = UiLayout.beside(book, { w = 260, h = 200 }, { w = 760, h = 500 }, 8, pocket)
		expect.equal(spot.y, 148, "below the top-row pocket")
		expect.equal(spot.x, 420, "centred on the pocket")
	end,
	-- Round 5 (spec section 2): the binder anchors its tooltip on the hovered pocket, so it sits beside that card
	["beside: anchored on a pocket it sits right of that card, over the book"] = function()
		local pocket = { x = 300, y = 120, w = 90, h = 126 }
		local spot = UiLayout.beside(pocket, { w = 260, h = 200 }, { w = 1200, h = 700 }, 8, pocket)
		expect.equal(spot.x, 398)
		expect.equal(spot.y, 120)
	end,
	["beside: a pocket near the right edge puts it on the card's left, never over the card"] = function()
		local pocket = { x = 1000, y = 120, w = 90, h = 126 }
		local spot = UiLayout.beside(pocket, { w = 260, h = 200 }, { w = 1200, h = 700 }, 8, pocket)
		expect.equal(spot.x, 1000 - 8 - 260)
	end,
	["inspectorCard: the card's right edge lands on the panel"] = function()
		local offset, rect = UiLayout.inspectorCard({ w = 1000, h = 500 }, 70, 3, { w = 1.8, h = 2.57 }, 0, 480, 8)
		expect.near(offset, -1.068, 0.01, "studs left of centre")
		expect.near(rect.x + rect.w, 480, 1, "right edge on the panel")
		expect.near(rect.h, 305.9, 1, "about 61% of the height")
		expect.near(rect.y, 97, 1, "centred vertically")
	end,
	["inspectorCard: a phone keeps the card on screen"] = function()
		local _, rect = UiLayout.inspectorCard({ w = 844, h = 390 }, 70, 3, { w = 1.8, h = 2.57 }, 0, 100, 8)
		expect.near(rect.x, 8, 1, "never off the left edge")
	end,
	["detailPanelLeft: the 3D card and the panel centred as a pair on wide screens"] = function()
		-- card 330 + gap 16 + panel 520 = 866 wide, centred on 1920: starts at 527, the panel after the card
		expect.equal(UiLayout.detailPanelLeft(1920, 330, 16, 520, 16), 873, "centred pair")
	end,
	["detailPanelLeft: a narrow screen keeps the panel on screen first"] = function()
		-- the pair doesn't fit: the panel sits at its right margin (the card clamps to its own left margin)
		expect.equal(UiLayout.detailPanelLeft(800, 330, 16, 520, 16), 264, "right margin wins")
		expect.equal(UiLayout.detailPanelLeft(750, 200, 16, 420, 76), 254, "phone: clear of the close button")
	end,
	["combat buttons: big enough, on screen, never overlapping, clear of the thumbstick"] = function()
		for _, view in { { w = 844, h = 390 }, { w = 667, h = 375 }, { w = 1920, h = 1080 }, { w = 1280, h = 720 } } do
			local rects = UiLayout.combatButtons(view)
			-- target: the soft lock's button (owner 2026-11-15), above the skill
			local names = { "attack", "dodge", "skill", "pet", "signature", "swap", "run", "target" }
			for _, name in names do
				local r = (rects :: any)[name] :: UiLayout.Rect
				local where = `{name} at {view.w}x{view.h}`
				expect.equal(r.w >= 48 and r.h >= 48, true, `{where}: tap target`)
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{where}: on screen`)
				-- Roblox's thumbstick lives in the bottom-left: the left 40% of the lower half
				local inStick = r.x < view.w * 0.4 and r.y + r.h > view.h * 0.5
				expect.equal(inStick, false, `{where}: clear of the thumbstick`)
			end
			for i, a in names do
				for j = i + 1, #names do
					local r1, r2 = (rects :: any)[a], (rects :: any)[names[j]]
					local overlap = r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h
					expect.equal(overlap, false, `{a} and {names[j]} at {view.w}x{view.h}`)
				end
			end
			expect.equal(rects.attack.w > rects.dodge.w and rects.attack.w > rects.skill.w, true, "Attack is the biggest")
			expect.equal(rects.attack.x > view.w / 2 and rects.attack.y > view.h / 2, true, "Attack sits bottom-right")
		end
	end,
	-- owner 2026-11-20: "on combat UI DESKTOP ONLY. make the icons more compact. I dont think we need to have the dodge
	-- button to be in the desktop version. make the target button small. or even remove it entirely in desktop ... also
	-- make the run button smaller": a click attacks, Shift dodges, Tab targets (and the fight locks one by itself), so
	-- a computer draws Skill, the Pet button, Super and a small Run
	["combat buttons with a mouse: compact, no Attack, Dodge or Target button, a small Run"] = function()
		local CombatHud = require("../src/shared/Config/CombatHud")
		for _, view in { { w = 1920, h = 1080 }, { w = 1891, h = 672 }, { w = 1280, h = 720 }, { w = 844, h = 390 } } do
			local where = `{view.w}x{view.h}`
			local rects: any = UiLayout.combatButtons(view, true)
			local full = UiLayout.combatButtons(view)
			for _, gone in { "attack", "dodge", "target" } do
				expect.isNil(rects[gone], `{where}: no {gone} button`)
			end
			expect.isNil(rects.run, `{where}: Run sits in the top bar (owner 2026-11-20: "do all"), not in the corner`)
			local names = { "skill", "pet", "signature", "swap" }
			for i, a in names do
				local r = rects[a] :: UiLayout.Rect
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{a} at {where}: on screen`)
				for j = i + 1, #names do
					local r1, r2 = r, rects[names[j]]
					local overlap = r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h
					expect.equal(overlap, false, `{a} and {names[j]} at {where}`)
				end
			end
			-- compact: clearly smaller than a touch screen's, yet easy to click
			assert(rects.pet.w <= full.pet.w * 0.8, `{where}: the Pet button is compact`)
			assert(rects.skill.w <= full.skill.w * 0.8, `{where}: Skill is compact`)
			assert(rects.pet.w >= 44 and rects.skill.w >= 44 and rects.signature.w >= 36, `{where}: still easy to click`)
			-- one row along the bottom: Run, Skill, the Pet button in the corner; Super over the Pet button
			expect.near(rects.skill.y, rects.pet.y, 1e-6, "Skill beside the Pet button")
			assert(rects.skill.x + rects.skill.w < rects.pet.x, "Skill left of the Pet button")
			assert(rects.signature.y + rects.signature.h < rects.pet.y, "Super over the Pet button")
			-- the cluster hugs the corner: only things pressed mid-fight
			assert(view.w - rects.skill.x < view.w - full.skill.x, `{where}: the cluster takes less of the screen`)
		end
		-- Run in the top bar: small, a real click target, and it says what it is
		local top = CombatHud.MOUSE_RUN
		assert(top.size >= 36 and top.size <= 48, "Run's top-bar icon is small")
		assert(top.tip ~= "" and top.chanceTip ~= "", "it has a tooltip, with the chance in a wild fight")
		-- the HUD draws no button a computer's layout has no place for
		local rects: any = UiLayout.combatButtons({ w = 1920, h = 1080 }, true)
		for _, name in CombatHud.MOUSE_HIDES do
			expect.isNil(rects[name], `{name} is hidden with a mouse and has no rect`)
		end
		expect.equal(#CombatHud.MOUSE_HIDES, 2, "Dodge and Target")
	end,

	-- owner 2026-11-20, "do all" (the five follow-ups to the compact buttons)
	["a computer's fight HUD: the dodge's cooldown on a Shift keycap, slim party tiles, the locked Super a padlock alone"] = function()
		local CombatHud = require("../src/shared/Config/CombatHud")
		local key = CombatHud.DODGE_KEY
		expect.equal(key.text, "Shift")
		assert(key.dim > 0.3 and key.dim < 0.8, "dimmed while it cools down, still readable")
		local strip = CombatHud.PARTY_STRIP
		assert(strip.SLIM_FOOT < strip.NAME + 12, "a slim tile is shorter than one with its name under the painting")
		assert(strip.SLIM_FOOT >= strip.BEAT.height, "room for the heartbeat")
		expect.equal(CombatHud.SUPER_LOCK.mousePill, false, "no pill naming the weapon with a mouse: the tooltip says it")
		-- owner 2026-11-20: "add hotkey to super skills"
		expect.equal(CombatHud.BUTTONS.signature.key, "F", "the Super has a key")
		local seen = {}
		for name, button in CombatHud.BUTTONS :: any do
			if button.key then
				assert(not seen[button.key], `{name} shares its key with {seen[button.key]}`)
				seen[button.key] = name
			end
		end
	end,

	-- owner 2026-11-27 pick B (the twin of the party dock): the weapon in hand between the one before and the next, the
	-- level pill over it and the name's line under it; the sides' tap areas count
	["weapon switch: the row's box, the sides' tap areas and the name included"] = function()
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20 }
		local w, h = UiLayout.switchBox(look)
		expect.equal(w, 72 + 2 * 8 + 44 + 48, "the middle, two gaps, a side either way and half a tap area past each")
		expect.equal(h, 9 + 72 + 20, "the pill over it, the weapon, the name under it")
	end,

	["weapon switch: smaller in a computer's fight, still over Super, still clickable"] = function()
		-- Config/HudLayout WEAPON_SWITCH's numbers (it needs Roblox to load): 180 px wide out of a fight, 126 in one
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12, compactChip = 64, fightScale = 0.7 }
		for _, view in { { w = 1920, h = 1080 }, { w = 1891, h = 672 }, { w = 1366, h = 768 } } do
			local where = `{view.w}x{view.h}`
			local calm = UiLayout.weaponSwitch(view, look :: any, 1, false, nil, false, nil)
			local fight = UiLayout.weaponSwitch(view, look :: any, 1, true, nil, false, nil, "mouse")
			expect.near(fight.scale, calm.scale * look.fightScale, 1e-6, `{where}: smaller in the fight`)
			assert(look.hit * fight.scale >= 32, `{where}: its weapons are still click targets`)
			local buttons: any = UiLayout.combatButtons(view, true)
			expect.near(fight.y + fight.h, buttons.signature.y - look.gap, 1e-6, `{where}: right over Super`)
			expect.near(fight.x + fight.w, view.w - look.right, 1e-6, `{where}: on the right edge`)
			local touch = UiLayout.weaponSwitch(view, look :: any, 1, true, nil, true, nil, "touch")
			expect.near(touch.scale, 1, 1e-6, `{where}: a touch screen's stays finger-sized`)
		end
	end,
	["wild fight buttons: the Pet button big, all on screen, no overlaps, clear of the thumbstick"] = function()
		for _, view in { { w = 844, h = 390 }, { w = 667, h = 375 }, { w = 1920, h = 1080 }, { w = 1280, h = 720 } } do
			local rects = UiLayout.wildButtons(view)
			local names = { "pet", "signature", "swap", "run" }
			for _, name in names do
				local r = (rects :: any)[name] :: UiLayout.Rect
				local where = `{name} at {view.w}x{view.h}`
				expect.equal(r.w >= 48 and r.h >= 48, true, `{where}: tap target`)
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{where}: on screen`)
				local inStick = r.x < view.w * 0.4 and r.y + r.h > view.h * 0.5
				expect.equal(inStick, false, `{where}: clear of the thumbstick`)
			end
			for i, a in names do
				for j = i + 1, #names do
					local r1, r2 = (rects :: any)[a], (rects :: any)[names[j]]
					local overlap = r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h
					expect.equal(overlap, false, `{a} and {names[j]} at {view.w}x{view.h}`)
				end
			end
			expect.equal(rects.pet.w > rects.run.w and rects.pet.w > rects.swap.w, true, "the Pet button is the biggest")
			expect.equal(rects.pet.x > view.w / 2 and rects.pet.y > view.h / 2, true, "it sits bottom-right")
		end
	end,
	["weapon switch: in a fight, clear of every button layout, on screen, its weapons big enough to tap"] = function()
		-- Config/HudLayout WEAPON_SWITCH (not loadable in Lune) and its SCALE.MIN, the smallest HUD scale; the row (owner
		-- 2026-11-27 pick B): the weapon in hand between the one before and the next, each side drawn `side` px with a
		-- `hit`-sized tap area
		-- touch screens (phones and tablets) always show the medallion alone (UIController's touch layout); the whole
		-- row is a computer's
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12, compactChip = 64 }
		local boxW, boxH = UiLayout.switchBox(look)
		local phones = { { w = 844, h = 390 }, { w = 667, h = 375 }, { w = 740, h = 360 } }
		local tablets = { { w = 1180, h = 820 }, { w = 1024, h = 768 }, { w = 1366, h = 1024 } }
		local desktops = { { w = 1920, h = 1080 }, { w = 1280, h = 720 }, { w = 1366, h = 768 }, { w = 1024, h = 600 } }
		for _, views in { phones, tablets, desktops } do
			local compact = views ~= desktops
			for _, view in views do
				local scale = math.clamp(view.h / 560, 0.7, 1)
				local r = UiLayout.weaponSwitch(view, look, scale, true, nil, compact)
				local where = `{view.w}x{view.h}`
				expect.equal(look.hit * r.scale >= 48, true, `{where}: the weapons on the track are tap targets`)
				expect.equal(look.side < look.hit, true, "they're drawn smaller than their tap area")
				expect.near(r.w, (if compact then look.compactChip else boxW) * r.scale, 1e-6, `{where}: the row's width (a phone: the medallion)`)
				expect.near(r.h, (if compact then look.compactChip else boxH) * r.scale, 1e-6, `{where}: the row's height`)
				expect.equal(r.x >= 0 and r.y >= 0 and r.x + r.w <= view.w and r.y + r.h <= view.h, true, `{where}: on screen`)
				expect.near(r.x + r.w, view.w - look.right, 1e-6, `{where}: on the right edge`)
				for _, rects in { UiLayout.combatButtons(view), UiLayout.combatButtons(view, true), UiLayout.wildButtons(view) } do
					for name, b in rects :: any do
						local overlap = r.x < b.x + b.w and b.x < r.x + r.w and r.y < b.y + b.h and b.y < r.y + r.h
						expect.equal(overlap, false, `{where}: clear of {name}`)
					end
				end
			end
		end
	end,
	-- owner 2026-11-13 (a phone screenshot): on a short phone the switch sat on the party bar, which hangs under the cash
	-- and XP column at the top right; it goes just under whatever it's told to keep clear of, on screen
	["weapon switch: on a phone, under the top-right column and party bar, never on them"] = function()
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12 }
		for _, view in { { w = 750, h = 381 }, { w = 667, h = 375 }, { w = 844, h = 390 } } do
			local column = { x = view.w - 270, y = 8, w = 258, h = 165 }
			local r = UiLayout.weaponSwitch(view, look, 0.7, false, { column })
			local overlap = r.x < column.x + column.w and column.x < r.x + r.w and r.y < column.y + column.h and column.y < r.y + r.h
			expect.equal(overlap, false, `{view.w}x{view.h}: clear of the column`)
			expect.equal(r.y + r.h <= view.h, true, `{view.w}x{view.h}: on screen`)
		end
		local far = UiLayout.weaponSwitch({ w = 1920, h = 1080 }, look, 1, false, { { x = 1600, y = 8, w = 300, h = 165 } })
		expect.near(far.y + far.h / 2, 540, 1e-6, "a big screen: still mid height (the column is far above)")
	end,

	-- owner 2026-11-13 (a PC screenshot): "move weapon lower to close the gap"; then Pish over the cash says the toasts,
	-- which rise over the column: on a computer the switch sits beside the cash column, its foot with the column's, or
	-- just above the column on a window too narrow for that (clear of the bottom tiles in the middle)
	["weapon switch: on a computer, beside the cash column (above it on a narrow window)"] = function()
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12 }
		for _, view in { { w = 1726, h = 567 }, { w = 1920, h = 1080 }, { w = 1366, h = 768 } } do
			local column = { x = view.w - 180, y = view.h - 150, w = 168, h = 138 }
			local r = UiLayout.weaponSwitch(view, look, 1, false, nil, false, column)
			expect.near(r.x + r.w, column.x - look.gap, 1e-6, `{view.w}x{view.h}: left of the column`)
			expect.near(r.y + r.h, column.y + column.h, 1e-6, `{view.w}x{view.h}: its foot with the column's`)
			expect.equal(r.x >= view.w * 0.6, true, `{view.w}x{view.h}: clear of the middle`)
		end
		local narrow = { w = 700, h = 560 }
		local column = { x = narrow.w - 180, y = narrow.h - 150, w = 168, h = 138 }
		local r = UiLayout.weaponSwitch(narrow, look, 1, false, nil, false, column)
		expect.near(r.y + r.h, column.y - look.gap, 1e-6, "narrow: just above the column")
		expect.near(r.x + r.w, narrow.w - look.right, 1e-6, "narrow: on the right edge")
	end,

	["weapon switch: out of a fight, at mid height on the right edge"] = function()
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12 }
		for _, view in { { w = 844, h = 390 }, { w = 1180, h = 820 }, { w = 1920, h = 1080 } } do
			local r = UiLayout.weaponSwitch(view, look, 0.7, false)
			expect.near(r.y + r.h / 2, view.h / 2, 1e-6, `{view.w}x{view.h}: mid height`)
			expect.near(r.x + r.w, view.w - look.right, 1e-6, `{view.w}x{view.h}: right edge`)
		end
	end,

	-- Final review 2026-11-08: on a 667 x 375 phone the Forge pane opened with the Now/After boxes and the costs below
	-- the fold. On phones the boxes (or a Forge weapon's element buttons) sit beside a small card and the cost chips
	-- under them; the tab's line goes last
	["the Forge window on a phone: the card, Now and After (or the elements) and the costs fit above the fold"] = function()
		local look = require("../src/shared/Config/ForgeLayout")
		for _, view in { { w = 667, h = 375 }, { w = 740, h = 360 }, { w = 844, h = 390 } } do
			local pane = UiLayout.forgePhonePane(look, view.h)
			for _, tab in { "Forge", "Upgrade", "Reforge", "Mutate" } do
				local content = UiLayout.forgePhoneContent(look, tab)
				expect.equal(content <= pane, true, `{tab} at {view.w}x{view.h}: {content} px in a {pane} px pane`)
			end
		end
	end,

	-- owner 2026-11-26 ("make sure the mutation on this window is noticeable"): on a phone the Mutate tab's slim
	-- mutation row comes first, over the recipe (its sentence under the fold), so it shows even on a Galaxy A06
	-- (705 x 338: a 121 px pane; in Studio the row under the recipe sat half behind the Mutate button)
	["the Forge's Mutate tab on a phone: the mutation row first, above the fold on a Galaxy A06"] = function()
		local look = require("../src/shared/Config/ForgeLayout")
		local content = UiLayout.forgePhoneContent(look, "Mutate")
		expect.equal(content, look.PAD * 2 + look.MUTATION_ROW.phone + look.GAP + look.CARD.h)
		for _, view in { { w = 705, h = 338 }, { w = 667, h = 375 }, { w = 740, h = 360 } } do
			local pane = UiLayout.forgePhonePane(look, view.h)
			expect.equal(content <= pane, true, `{view.w}x{view.h}: {content} px in a {pane} px pane`)
		end
	end,

	["the binder's Filters window fits its content, and the screen"] = function()
		local look = require("../src/shared/Config/FiltersLayout")
		local baby = require("../src/shared/Config/BabyColors")
		local chrome = look.header + look.inset * 2 + look.footer
		local body = UiLayout.filtersBody(look, baby.SEGMENTED.hit, baby.DOT_TAG.hit)
		-- what Studio measured on 2026-11-04: 354 px of pieces, gaps and edge room
		local rows = baby.DOT_TAG.hit * look.rarityRows + look.gap * (look.rarityRows - 1) -- the tag rows wrap with a gap
		local drawn = look.search + look.headingRow * 3 + baby.SEGMENTED.hit * 2 + rows
		expect.equal(body, drawn + look.gap * 6 + look.edge * 2, "the search box, headings, switches and every rarity row")
		local top, size = UiLayout.filtersFrame(1080, look, body)
		expect.equal(top, look.top, "a tall screen: under the binder's close and magnifier")
		expect.equal(size, body + chrome, "as tall as its content, not stretched down the screen")
		top, size = UiLayout.filtersFrame(625, look, body)
		expect.equal(top, look.shortTop, "a short screen: from the top, over the corner buttons")
		expect.equal(size, body + chrome, "still showing everything without scrolling")
		for _, height in { 330, 340, 370 } do
			top, size = UiLayout.filtersFrame(height, look, body)
			expect.equal(top + size + look.shortBottom <= height, true, `a landscape phone {height} px tall: on screen`)
			expect.equal(size > chrome, true, `a landscape phone {height} px tall: a body to scroll`)
		end
	end,
	-- Owner 2026-11-05 (a screenshot): the swap comparison's last row sat under the Swap and Back buttons on a short
	-- screen. Content taller than its space shrinks to fit, never below a floor, and never grows
	["content taller than its space shrinks to fit, within a floor"] = function()
		expect.near(UiLayout.fitScale(306, 300, 0.65), 300 / 306, 1e-9, "a little too tall: just enough smaller")
		expect.equal(UiLayout.fitScale(200, 300, 0.65), 1, "fits: as it is")
		expect.equal(UiLayout.fitScale(1000, 300, 0.65), 0.65, "far too tall: no smaller than the floor")
		expect.equal(UiLayout.fitScale(0, 300, 0.65), 1, "nothing laid out yet")
		expect.equal(UiLayout.fitScale(300, 0, 0.65), 1, "no space measured yet")
	end,

	-- Owner 2026-11-17 ("make sure nothing is cutoff/overlapping on all devices"): on a short phone a fight's party strip,
	-- under the status, sat on Roblox's thumbstick ring (on a Galaxy A06 the ring's middle was on the first tile, so a
	-- thumb meant to walk unsummoned the creature). It moves to the bottom row, beside the fight buttons, clear of the ring
	["party strip: on a short phone it leaves the thumbstick's ring for the bottom row beside the buttons"] = function()
		local ring, clear = { right = 104, top = 94 }, 8
		for _, case in {
			{ view = { w = 706, h = 281 }, statusBottom = 150, what = "Galaxy A06, a wild fight with a sword" },
			{ view = { w = 706, h = 281 }, statusBottom = 137, what = "Galaxy A06, a boss fight" },
			{ view = { w = 667, h = 317 }, statusBottom = 150, what = "iPhone SE, a wild fight with a sword" },
		} do
			for _, count in { 1, 2, 3 } do
				local w = count * 58 + (count - 1) * 10
				local under = { x = 12, y = case.statusBottom + 14, w = w, h = 64 }
				for _, layout in { UiLayout.combatButtons(case.view), UiLayout.wildButtons(case.view) } do
					local buttons = {}
					for _, r in layout :: any do
						table.insert(buttons, r)
					end
					local where = `{case.what}, {count} cards`
					local spot = UiLayout.partyStripSpot(case.view, under, buttons, ring, clear, 58, 48)
					expect.equal(spot ~= nil, true, `{where}: moves`)
					local s = spot :: UiLayout.StripSpot
					local r = { x = s.x, y = s.y, w = w * s.scale, h = 64 * s.scale }
					expect.equal(58 * s.scale >= 48, true, `{where}: its tiles still tap targets`)
					expect.equal(r.x >= ring.right + clear, true, `{where}: right of the ring`)
					expect.equal(r.y >= 0 and r.y + r.h <= case.view.h, true, `{where}: on screen`)
					for _, b in buttons do
						local near = r.x < b.x + b.w + clear and b.x < r.x + r.w + clear and r.y < b.y + b.h and b.y < r.y + r.h
						expect.equal(near, false, `{where}: clear of the button at {math.round(b.x)},{math.round(b.y)}`)
					end
				end
			end
		end
	end,
	["party strip: where it ends clear of the thumbstick's ring it stays under the status"] = function()
		local ring = { right = 104, top = 94 }
		local function buttonsFor(view: UiLayout.Size): { UiLayout.Rect }
			local list = {}
			for _, r in UiLayout.combatButtons(view) :: any do
				table.insert(list, r)
			end
			return list
		end
		-- an iPhone 14 (844 x 332 under the top bar): the strip ends at 228, the ring starts at 238
		local phone = { w = 844, h = 332 }
		expect.equal(UiLayout.partyStripSpot(phone, { x = 12, y = 164, w = 194, h = 64 }, buttonsFor(phone), ring, 8, 58, 48), nil, "a taller phone")
		local tablet = { w = 1180, h = 762 }
		expect.equal(UiLayout.partyStripSpot(tablet, { x = 12, y = 180, w = 236, h = 80 }, buttonsFor(tablet), ring, 8, 72, 48), nil, "a tablet")
	end,
	["party strip: with no room in the bottom row either it stays under the status"] = function()
		-- a made-up narrow, short screen: between the ring and the buttons not even 48 px tiles fit
		local view = { w = 420, h = 281 }
		local buttons = {}
		for _, r in UiLayout.combatButtons(view) :: any do
			table.insert(buttons, r)
		end
		expect.equal(UiLayout.partyStripSpot(view, { x = 12, y = 164, w = 194, h = 64 }, buttons, { right = 104, top = 94 }, 8, 58, 48), nil, "stays")
	end,
	-- owner 2026-11-20 ("Do. C": the combat HUD tidy, "weapon dial joins the skills"): in a fight the dial sat at mid
	-- height, far over the skills; it sits right over the buttons in its column (the Super button), for the layout on
	-- screen
	["weapon switch: in a fight it sits right over the fight buttons in its column"] = function()
		local look = { chip = 72, side = 44, hit = 48, row = 8, drop = 8, rise = 9, name = 20, gap = 6, right = 12, compactChip = 64 }
		local cases = {
			{ view = { w = 1920, h = 1080 }, layout = "mouse", compact = false },
			{ view = { w = 1366, h = 768 }, layout = "mouse", compact = false },
			{ view = { w = 844, h = 390 }, layout = "touch", compact = true },
			{ view = { w = 1180, h = 820 }, layout = "touch", compact = true },
			{ view = { w = 844, h = 390 }, layout = "wild", compact = true },
			{ view = { w = 1920, h = 1080 }, layout = "wild", compact = false },
		}
		for _, case in cases do
			local view = case.view
			local where = `{view.w}x{view.h} {case.layout}`
			local r = UiLayout.weaponSwitch(view, look, 1, true, nil, case.compact, nil, case.layout)
			local rects: any = if case.layout == "wild" then UiLayout.wildButtons(view) else UiLayout.combatButtons(view, case.layout == "mouse")
			local top = math.huge
			for name, b in rects do
				local overlap = r.x < b.x + b.w and b.x < r.x + r.w and r.y < b.y + b.h and b.y < r.y + r.h
				expect.equal(overlap, false, `{where}: clear of {name}`)
				if r.x < b.x + b.w and b.x < r.x + r.w then
					top = math.min(top, b.y)
				end
			end
			expect.near(r.y + r.h, top - look.gap, 1e-6, `{where}: right over the top button in its column`)
			expect.near(r.x + r.w, view.w - look.right, 1e-6, `{where}: on the right edge`)
			expect.equal(r.y >= 0, true, `{where}: on screen`)
		end
		local unknown = UiLayout.weaponSwitch({ w = 1920, h = 1080 }, look, 1, true, nil, false, nil)
		for _, rects in { UiLayout.combatButtons({ w = 1920, h = 1080 }) :: any, UiLayout.combatButtons({ w = 1920, h = 1080 }, true), UiLayout.wildButtons({ w = 1920, h = 1080 }) } do
			for name, b in rects do
				local overlap = unknown.x < b.x + b.w and b.x < unknown.x + unknown.w and unknown.y < b.y + b.h and b.y < unknown.y + unknown.h
				expect.equal(overlap, false, `no layout told: clear of every layout's {name}`)
			end
		end
	end,
}
