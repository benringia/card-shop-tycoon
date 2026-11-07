# Weapons Round 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four playable spears (Forge Spear in five elements, Magma Halberd, Tidal Trident, Titan's Lance) with their own
grip, models, moves, effects and perks, plus a HUD chip that switches weapons in one tap, in fights too.

**Architecture:** Spears are a second `Config/Swords` moveset (`spear`, shared by all four) and four `Config/Weapons`
entries that turn `ready`; grips become per family. The server checks spear hits with `SwordRules` like sword hits; perks
live in `BattleSim.swordPerk`. The switch is a pure ordering module (`Util/WeaponSwitch`) behind a client chip, using the
existing `EquipWeapon` request, now allowed in fights with a server-enforced 1 s swap lock.

**Tech Stack:** Luau (Rojo, `--!strict`), Lune tests (`lune run tests/run`), Blender 5.2 background scripts
(`weapon_kit.py`, `anim_kit.py`), Roblox Studio MCP for checks and uploads, Figma image generation (paid, owner-approved).

**Spec:** `docs/superpowers/specs/2026-11-07-weapons-round2-design.md`

## Global Constraints

- Branch `weapons-round2`; the sword hold fix (`90be310`, `246399c`) is already on it.
- Server authoritative: every hit, equip and swap is validated on the server; every remote rate-limited
  (`Util/RateLimiter`); no client-sent numbers trusted.
- All tunable numbers in `src/shared/Config`; rules both sides use in `src/shared/Util` (Roblox-free, Lune-tested; pure
  modules don't require siblings).
- UI text plain ASCII (`<`, `>` are fine); tap targets at least 48 px; HUD pieces clear of the thumbstick and jump button.
- Sounds: Pro Sound Effects (Roblox-licensed) only, measured into `Config/SoundLevels`, kept quiet.
- Effects exaggerated but readable (memory fx-exaggerate); others see them through `SwordCast`, lite in crowds.
- Blender: background only (`blender.exe -b --factory-startup --python ...`) except the MCP Blender used for Meshy and
  `_raw.glb` export; `.blend` saved without `_Src`, orphans purged, key fields empty (print lengths only).
- Figma `generate_image` is paid: show sketches in the visual companion first, generate only the owner's pick.
- Studio MCP: inspect freely; ask before changing the place. Scripts only in the repo.
- Spear lengths (studs): forgeSpear 8.5, magmaHalberd 8.5, tidalTrident 8.7, titansLance 9.2. Grip point 31% of the
  length up from the butt. Spears on the back at scale 1.
- Spear moves: Thrust reach 12 / 30 deg; Sweep reach 11 / 120 deg; Sky Pierce line 8 x width 3 plus a 4-stud burst at
  its end (12 in all); Piercing Rush dash 12 studs (maxStuds 20, slack 3), width 3, power 0.9, cooldown 8. Same damage a second as
  the sword combo.
- Perks: Magma Halberd `{ kind = "erupt", every = 5, share = 0.6 }`; Tidal Trident `{ kind = "chill", share = 0.1,
  seconds = 3 }`; Titan's Lance `{ kind = "heal", every = 1, share = 0.01 }`; Forge Spear none.
- Titan's Lance recipe: $60,000, 30 Warden Heartwood, 20 Frost Heart, 20 Storm Crystal, 10 Star Shards.
- `SWAP_SECONDS = 1`; the skill cooldown is one timer per player (`member.skillReady`), never reset by a switch.

## Review Focus

1. A cut or skill queued by the old weapon must not land after a mid-fight switch (cancelled like a dodge). Test: Task 3
   step 1 (`SwordRules.skillDodged` with the swap time) + Task 3 Studio check.
2. A spear's longer reach must never make a spot a boss can't hit: thrust reach + the boss's hit radius stays inside its
   swipe reach for every boss. Test: Task 1 step 1.
3. A player with only the Steel Sword, or below the sword's shop level, sees no chip; an unknown equipped id steps to
   the first weapon. Test: Task 3 step 1.
4. Mashing Q in a fight: each switch restarts the 1 s lock, equips stay rate-limited, the skill cooldown carries over;
   Q typed in chat switches nothing. Test: Task 3 Studio check list.
5. Five Forge Spears owned at once: one Forge row in the Forge window with an element picker, five ordered entries in the
   switch. Test: Task 3 step 1 (order), Task 6 Studio check (Forge window).

---

### Task 1: The spear moveset data, per-family grips and the spear's hit shapes

**Files:**
- Modify: `src/shared/Config/Swords.luau` (types `Cut`, new `Line`; `GRIPS` replaces `HAND_GRIP` / `BACK_GRIP` /
  `BACK_SCALE`; new `SWORDS.spear`)
- Modify: `src/shared/Util/SwordRules.luau` (`Cut` type, `cutReaches`, `anyInReach`)
- Modify: `src/server/Services/BattleService.luau:1375-1394` (`onSwordAttack` uses `cutReaches`)
- Modify: `src/client/Controllers/SwordController.luau` (`place` reads the weapon's family grip; its own reach check uses
  `cutReaches` through `anyInReach`)
- Modify: `tools/blender/anim_kit.py` (`hand_grip(family="sword")` reads the same numbers)
- Test: `tests/SwordsConfig.spec.luau`, `tests/SwordRules.spec.luau`

**Interfaces:**
- Produces: `Swords.GRIPS: { [family: string]: { hand: { y: number, angleX: number, twist: number }, back: { x: number,
  y: number, z: number, angleZ: number }, backScale: number } }` (`sword` = today's values; `spear` = starting values
  `hand = { y = -0.18, angleX = 0, twist = 0 }`, `back = { x = 0, y = 0.6, z = 0.7, angleZ = 160 }`, `backScale = 1`,
  calibrated in Task 6).
- Produces: `Swords.Line = { length: number, width: number, burst: number }`; `Cut.line: Line?` (a line-shaped cut:
  `reach`/`arc` unused when present).
- Produces: `Swords.SWORDS.spear` (`name = "Spear"`, `model = "Spear"`: its animation folder
  `ReplicatedStorage.SwordAnimations.Spear`; `combo` = Thrust, Sweep, Sky Pierce; `skill` = Piercing Rush with a `dash`
  and `shape = { kind = "dash", width = 3, maxStuds = 20, slack = 3 }`; `animations` = the starter's table cloned with
  `ready`, `draw`, `sheath`, `run`, `cut1`-`cut3`, `skill` set to `""` until published; `fx = { slash = "spearStreak",
  finisher = "skyPierce", skill = "piercingRush" }`; `sounds`/`cues` = the starter's until Task 7).
- Produces: `SwordRules.cutReaches(cut: Cut, px: number, pz: number, lookX: number, lookZ: number, target: Target): boolean`.

- [ ] **Step 1: Write the failing tests**

In `tests/SwordsConfig.spec.luau`:
```lua
["the spear moveset: thrust, sweep, sky pierce and piercing rush at the sword's damage a second"] = function()
	local spear = Swords.SWORDS.spear
	expect.equal(#spear.combo, 3)
	expect.equal(spear.combo[1].reach, 12); expect.equal(spear.combo[1].arc, 30)
	expect.equal(spear.combo[2].reach, 11); expect.equal(spear.combo[2].arc, 120)
	expect.equal(spear.combo[3].line.length, 8); expect.equal(spear.combo[3].line.width, 3); expect.equal(spear.combo[3].line.burst, 4)
	expect.near(SwordRules.comboPowerPerSecond(spear.combo), SwordRules.comboPowerPerSecond(Swords.SWORDS.starterSword.combo), 1e-3)
	expect.equal(spear.skill.power, 0.9); expect.equal(spear.skill.cooldown, 8)
	expect.equal(spear.skill.shape.kind, "dash"); expect.equal(spear.skill.dash.studs, 12); expect.equal(spear.skill.dash.width, 3)
	expect.equal(spear.model, "Spear")
end,
["a spear's reach never makes a spot a boss's swipe can't reach"] = function()
	local Bosses = require("../src/shared/Config/Bosses")
	local longest = 0
	for _, cut in Swords.SWORDS.spear.combo do
		longest = math.max(longest, if cut.line then cut.line.length + cut.line.burst else cut.reach)
	end
	for id, boss in Bosses.BOSSES do
		local ring = boss.ringRadius or Bosses.RING_RADIUS
		expect.equal(longest + ring * Bosses.HIT_RADIUS_SHARE <= ring + Bosses.RING_SWIPE_EXTRA, true, id)
	end
end,
["every family has a hand grip, a back grip and a back size"] = function()
	expect.equal(Swords.GRIPS.sword.hand.twist, 90)
	expect.equal(Swords.GRIPS.sword.backScale, 1.05)
	expect.equal(Swords.GRIPS.spear.backScale, 1)
end,
```
Replace the existing `HAND_GRIP.twist` test with the grips test above.

In `tests/SwordRules.spec.luau`:
```lua
["a line cut hits along its length and in the burst at its tip, not beside it"] = function()
	local cut = { power = 1, hitAt = 0.5, length = 1, reach = 0, arc = 0, line = { length = 8, width = 3, burst = 4 } }
	expect.equal(SwordRules.cutReaches(cut, 0, 0, 0, -1, { id = "a", x = 0, z = -5, radius = 0.5 }), true, "on the line")
	expect.equal(SwordRules.cutReaches(cut, 0, 0, 0, -1, { id = "b", x = 3, z = -10, radius = 0.5 }), true, "in the burst at its end")
	expect.equal(SwordRules.cutReaches(cut, 0, 0, 0, -1, { id = "c", x = 4, z = -4, radius = 0.5 }), false, "beside the line")
	expect.equal(SwordRules.cutReaches(cut, 0, 0, 0, -1, { id = "d", x = 0, z = 4, radius = 0.5 }), false, "behind")
end,
["a cone cut still uses reach and arc"] = function()
	local cut = { power = 1, hitAt = 0.5, length = 1, reach = 12, arc = 30 }
	expect.equal(SwordRules.cutReaches(cut, 0, 0, 0, -1, { id = "a", x = 0, z = -11, radius = 0.5 }), true)
	expect.equal(SwordRules.cutReaches(cut, 0, 0, 0, -1, { id = "b", x = 6, z = -6, radius = 0.5 }), false, "outside 30 degrees")
end,
```

- [ ] **Step 2: Run them to see them fail**

Run: `lune run tests/run SwordsConfig` and `lune run tests/run SwordRules`
Expected: FAIL (`spear` nil, `GRIPS` nil, `cutReaches` nil).

- [ ] **Step 3: Implement**

- `Config/Swords`: `GRIPS` as in Interfaces (sword values moved from `HAND_GRIP` / `BACK_GRIP` / `BACK_SCALE`, which go);
  `SWORDS.spear` with the Global Constraints numbers; cut timings start as the sword's (`hitAt` 0.22 / 0.20 / 0.70,
  `length` 0.62 / 0.62 / 1.25, `cancelAt` 0.36 / 0.34) and the powers scaled so the DPS test passes (Task 5 replaces the
  timings with the animations' markers and keeps the test green). The skill's `dash` mirrors the starter's with `studs =
  12`, `width = 3`; `hitAt`/`length` start at the starter's.
- `SwordRules.cutReaches`: a cut with `line` hits a target within `width / 2` of the segment from you to `length` ahead
  (`inDashPath`), or within `burst` of the segment's end (plus the target's radius); otherwise `inReach(..., reach, arc)`.
  `anyInReach` calls `cutReaches`.
- `BattleService.onSwordAttack` passes `SwordRules.cutReaches(cut, px, pz, lookX, lookZ, target)` as `reaches`.
- `SwordController.place`: the family from `Weapons.ById[view.swordId].family` (default `"sword"`), its `GRIPS` entry
  for hand C0 (tilt then twist), back C0 and scale.
- `anim_kit.hand_grip(family="sword")`: the sword's numbers as today; `"spear"`: `GRIPS.spear.hand` (keep the two in
  step by hand, with a comment pointing at `Config/Swords GRIPS`).

- [ ] **Step 4: Run the tests**

Run: `lune run tests/run` → Expected: all pass (1252 + new).

- [ ] **Step 5: Commit**

```bash
git add src/shared/Config/Swords.luau src/shared/Util/SwordRules.luau src/server/Services/BattleService.luau src/client/Controllers/SwordController.luau tools/blender/anim_kit.py tests/SwordsConfig.spec.luau tests/SwordRules.spec.luau
git commit -m "Spears: the spear moveset, grips per family, line cuts"
```

### Task 2: Spear perks, the Forge Spear's elements, the Titan's Lance recipe

**Files:**
- Modify: `src/server/Util/BattleSim.luau:1560-1630` (`swordPerk(state, fighter, target, perk, events, multiplier, element)`)
- Modify: `src/shared/Config/Weapons.luau` (spear entries; `forgeSpear` becomes `forgeSpear_<Element>` x5 like the swords;
  perks; recipe; `TIER_BOSS`; `SWAP_SECONDS = 1`)
- Modify: `src/shared/Util/WeaponRules.luau` (`Perk.kind` doc), `src/shared/Util/WeaponText.luau` (`perkWords`)
- Modify: `src/client/Controllers/BattleController.luau` (event `swordErupt`: a small Ember burst on the target via
  `Util/HitFx`)
- Test: `tests/BattleSim.spec.luau`, `tests/WeaponText.spec.luau`, `tests/WeaponRules.spec.luau`, `tests/WeaponsConfig.spec.luau`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: perk kinds `"erupt"` (every `every`-th hit by this owner, an extra hit on the target of `share` x that hit's
  multiplier, no meter, and an event `{ type = "swordErupt", from, to }`) and `"chill"` (`target.slowUntil = time +
  seconds`, `target.slow = max(current active slow, share)`); `"heal"` with `every = 1` heals on every hit.
- Produces: `Weapons.ById["forgeSpear_<Element>"]` (`family = "spear"`, `moveset = "spear"`, `model = "ForgeSpear_<Element>"`,
  `ready = false` until Task 6), `magmaHalberd`, `tidalTrident`, `titansLance` with `moveset = "spear"`, models
  `MagmaHalberd`, `TidalTrident`, `TitansLance`, perks per Global Constraints, still `ready = false`.
- Produces: `Weapons.SWAP_SECONDS = 1`; `TIER_BOSS.forgeSpear = "meadowWarden"`, `magmaHalberd = "emberColossus"`,
  `tidalTrident = "frostTyrant"`, `titansLance = "prismHydra"`.

- [ ] **Step 1: Write the failing tests**

`tests/BattleSim.spec.luau` (same helpers as the Verdant / Sunforged tests):
```lua
["Magma Halberd erupts on every 5th hit for 60% more"] = function()
	local state = bossFightWithPlayer(5, 1)
	local weapon = { element = "Ember", prism = false, bond = 1, meter = 1, perk = { kind = "erupt", every = 5, share = 0.6 } }
	local erupts, extra = 0, nil
	for i = 1, 10 do
		local damage = {}
		for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
			if e.type == "swordErupt" then erupts += 1 end
			if e.damage and e.to == "b:m" then table.insert(damage, e.damage) end
		end
		if i == 5 then extra = damage end
	end
	expect.equal(erupts, 2)
	expect.equal(#extra, 2, "the hit and its eruption")
	expect.near(extra[2], extra[1] * 0.6, 2)
end,
["Tidal Trident chills the foe 10% for 3 s and never weakens a stronger slow"] = function()
	local state = bossFightWithPlayer(6, 1)
	local weapon = { element = "Tide", prism = false, bond = 1, meter = 1, perk = { kind = "chill", share = 0.1, seconds = 3 } }
	BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon)
	local boss = raw(state, "b:m")
	expect.near(boss.slow, 0.1, 1e-9); expect.near(boss.slowUntil, state.time + 3, 1e-6)
	boss.slow, boss.slowUntil = 0.3, state.time + 10 -- a Snare
	BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon)
	expect.near(boss.slow, 0.3, 1e-9, "the Snare's 30% stays")
end,
["Titan's Lance heals the creature 1% on every hit"] = function()
	local state = bossFightWithPlayer(5, 1)
	raw(state, "a:p1").hp = 100
	local weapon = { element = "Bloom", prism = false, bond = 1, meter = 1, perk = { kind = "heal", every = 1, share = 0.01 } }
	local heals = 0
	for _ = 1, 3 do
		for _, e in BattleSim.swordHit(state, "1", "b:m", 0.5, "Sword", weapon) :: { any } do
			if e.type == "swordHeal" then heals += 1; expect.equal(e.heal, 5, "1% of 500") end
		end
	end
	expect.equal(heals, 3)
end,
```
`tests/WeaponText.spec.luau`: `perkWords` (through `WeaponText.stats`) gives `"Every 5th hit erupts for 60% more"`,
`"Hits slow the foe's attacks 10% for 3 s"`, `"Every hit heals your creature 1%"`.
`tests/WeaponRules.spec.luau`: Grade S chill `share` is `0.12` (x `PERK_S`); `makeCost(Weapons, "titansLance")` is
`{ cash = 60000, items = { material_meadowWarden = 30, material_frostTyrant = 20, material_stormSovereign = 20,
starShard = 10 } }` once ready (test it against a cfg copy with `ready = true`, as the existing masterwork test does).
`tests/WeaponsConfig.spec.luau`: five `forgeSpear_<Element>` entries (family spear, moveset spear) and no `forgeSpear`.

- [ ] **Step 2: Run them to see them fail**

Run: `lune run tests/run BattleSim`, `... WeaponText`, `... WeaponRules`, `... WeaponsConfig` → Expected: FAIL on the new
tests only.

- [ ] **Step 3: Implement** the perks in `swordPerk` (pass the hit's `multiplier * weapon.bond` and `element` in from
`swordHit`; erupt's extra hit goes through `hit(...)` with meter share 0), the catalogue entries, `perkWords` cases
(`every == 1` reads "Every hit"), the `swordErupt` client burst.

- [ ] **Step 4: Run** `lune run tests/run` → Expected: all pass.

- [ ] **Step 5: Commit** `git commit -m "Spears: perks (Eruption, Chill, Titan's Bloom), Forge Spear elements, the Lance recipe"`

### Task 3: The quick weapon switch

**Files:**
- Create: `src/shared/Util/WeaponSwitch.luau`, `tests/WeaponSwitch.spec.luau`
- Create: `src/client/Controllers/WeaponSwitchController.luau` (registered in `src/client/init.client.luau` after
  `SwordController`)
- Modify: `src/shared/Util/WeaponRules.luau` (`equipBlock(shopLevel, unlockLevel)`: fighting no longer blocks)
- Modify: `src/server/Services/WeaponService.luau` (`SetSwapHook(hook: (Player) -> ())`, called after an equip while
  `isFighting(player)`)
- Modify: `src/server/Services/BattleService.luau` (`Member.swappedAt: number?`; the hook sets it and clears `lastCut`;
  `onSwordAttack`/`onSwordSkill` refuse while `os.clock() < swappedAt + Weapons.SWAP_SECONDS`; queued cut strikes and
  skill hits are cancelled by `SwordRules.skillDodged(castAt, hitAt, member.swappedAt)` like a dodge)
- Modify: `src/client/Controllers/SwordController.luau` (after the `Sword` attribute changes in combat: no cut or skill
  for `SWAP_SECONDS`, the HUD's attack and skill buttons drain over it via the `cooldown` callback)
- Modify: `src/client/Controllers/BattleController.luau` (`hud.setSkill(SwordController.EquippedMoveset())` again when
  the character's `Sword` attribute changes during a fight)
- Test: `tests/WeaponSwitch.spec.luau`, `tests/WeaponRules.spec.luau`, `tests/SwordRules.spec.luau`

**Interfaces:**
- Produces: `WeaponSwitch.list(cfg: any, owned: { [string]: any }, unlocked: boolean): { string }`: empty when not
  unlocked; otherwise the Steel Sword plus every owned `ready` weapon, ordered by family (`sword`, `spear`, `scythe`),
  then rarity (Common, Rare, Very Rare, Epic, Legendary), then name.
- Produces: `WeaponSwitch.step(list: { string }, current: string?, delta: number): string?` (wraps; an unknown or nil
  current gives `list[1]`; nil for an empty list).
- Produces: `WeaponSwitch.visible(list: { string }): boolean` (two or more).

- [ ] **Step 1: Write the failing tests**

`tests/WeaponSwitch.spec.luau`:
```lua
["nothing to switch below the sword's shop level, or with only the Steel Sword"] = function()
	expect.equal(#WeaponSwitch.list(Weapons, {}, false), 0)
	local only = WeaponSwitch.list(Weapons, {}, true)
	expect.equal(#only, 1); expect.equal(only[1], "starterSword")
	expect.equal(WeaponSwitch.visible(only), false)
end,
["weapons in order: swords, then spears, each by rarity then name"] = function()
	local cfg = readyCopy(Weapons) -- every spear ready (test helper: a deep copy with ready = true)
	local list = WeaponSwitch.list(cfg, { prismBlade = {}, forgeSpear_Tide = {}, forgeSpear_Ember = {}, verdantBlade = {}, titansLance = {} }, true)
	expect.equal(table.concat(list, ","), "starterSword,verdantBlade,prismBlade,forgeSpear_Ember,forgeSpear_Tide,titansLance")
end,
["not-ready and unknown weapons are left out"] = function()
	local list = WeaponSwitch.list(Weapons, { titansLance = {}, nothing = {} }, true)
	expect.equal(table.concat(list, ","), "starterSword")
end,
["stepping wraps both ways and an unknown weapon starts at the first"] = function()
	local list = { "a", "b", "c" }
	expect.equal(WeaponSwitch.step(list, "c", 1), "a")
	expect.equal(WeaponSwitch.step(list, "a", -1), "c")
	expect.equal(WeaponSwitch.step(list, "zzz", 1), "a")
	expect.isNil(WeaponSwitch.step({}, nil, 1))
end,
```
`tests/WeaponRules.spec.luau`: `equipBlock(10, 4)` is nil (the old "in a fight" case removed), `equipBlock(3, 4)`
still blocks with the shop-level message.
`tests/SwordRules.spec.luau`: `["a weapon switch before a strike lands cancels it"]`: `skillDodged(10, 0.2, 10.1)` true,
`skillDodged(10, 0.2, 9.5)` false, `skillDodged(10, 0.2, nil)` false.

- [ ] **Step 2: Run them to see them fail** → `lune run tests/run WeaponSwitch` (module missing), `... WeaponRules`.

- [ ] **Step 3: Implement** `WeaponSwitch` (pure, no requires), the `equipBlock` change, the server swap lock and hook,
the client lock, the HUD refresh, and the chip:
- `WeaponSwitchController`: a round chip on the right edge at mid height (`AnchorPoint (1, 0.5)`, 64 px, scaled with
  `Hud.scaleWith`), the equipped weapon's portrait (`WeaponLooks.WEAPONS[id].portrait`) in a ring of its rarity colour,
  `<` and `>` buttons (48 px each) either side, a "Q" key badge on keyboards (`UserInputService.KeyboardEnabled`), the
  name under it for 1.5 s after a switch. Q: next, Shift+Q: previous (ignored when `gameProcessed`), a horizontal swipe
  of 30 px or more on the chip: next/previous. Visible when `WeaponSwitch.visible(list)`, not while
  `UIKit.anyPanelOpen()`, hidden with the HUD (`Hud.hideWith`). List from `Remotes.WeaponsChanged` (`owned`,
  `equipped`) and the player's shop level vs `Swords.UNLOCK_SHOP_LEVEL`. A switch fires `Remotes.EquipWeapon`.
- Sounds and motion from `Util/UIKit`/`Util/Motion` (one soft press sound, no resize on hover).

- [ ] **Step 4: Run** `lune run tests/run` → all pass. Check VS Code's Luau syntax diagnostics on the client files
(Lune never parses `src/client`).

- [ ] **Step 5: Studio check** (Rojo connected; Play; `/weapon verdantBlade S 3`, `/weapon prismBlade`):
  chip shows on the right, `<`/`>`/Q/Shift+Q/swipe switch and the character redraws; with only the Steel Sword it's
  gone; typing "q" in chat switches nothing; in `/boss 1 fight`: a switch blocks attacks and the skill for 1 s (buttons
  drain), the skill cooldown carries over, mashing Q keeps the lock going, the skill button shows the new sword's skill;
  a cut started just before the switch deals no damage. Screenshot the chip in town and in the fight; phone landscape in
  the Device emulator.

- [ ] **Step 6: Commit** `git commit -m "Quick weapon switch: the chip, Q, swaps in fights with a 1 s lock"`

### Task 4: The spear models

**Files:**
- Modify: `tools/blender/weapon_kit.py` (`build_spear(name, length, grip_share=0.31)` → `[Head, Shaft]`, `find_head(obj)`)
- Create: `tools/blender/build_weapon_forgeSpear.py`, `build_weapon_magmaHalberd.py`, `build_weapon_tidalTrident.py`,
  `build_weapon_titansLance.py`
- Modify: `tools/weapons/finish_sword.luau` (a model with `Shaft` and no `Grip`: `Shaft` is the PrimaryPart),
  `tools/weapons/forge_variants.luau` (argument `ForgeSword` | `ForgeSpear`; reads `WeaponLooks.FORGE_COLOR_MAPS[model]`)
- Modify: `src/shared/Config/WeaponLooks.luau` (`FORGE_COLOR_MAPS` keyed by model: `ForgeSword = {...}`, `ForgeSpear = {...}`)
- Create (owner step): `assets/weapons/MagmaHalberd.rbxm`, `TidalTrident.rbxm`, `TitansLance.rbxm`,
  `assets/weapons-source/ForgeSpear.rbxm`; then `assets/weapons/ForgeSpear_<Element>.rbxm` x5
- Test: `tests/CreatureAssets.spec.luau` (weapon models: no scripts; a PrimaryPart named `Grip` or `Shaft`)

**Interfaces:**
- Consumes: `assets/blender/<Name>/<Name>_raw.glb` (exist, out of git).
- Produces: models in `ReplicatedStorage.WeaponModels` named per Task 2's `model` fields, origin at the grip (31% up),
  head along +Y, parts `Head` and `Shaft`.

- [ ] **Step 1: Write the failing test**: `tests/CreatureAssets.spec.luau` accepts `Shaft` as a weapon's PrimaryPart and
  requires every `Config/Weapons` spear model to exist once `ready` (skip not-ready ones, as today).
- [ ] **Step 2: Run** `lune run tests/run CreatureAssets` → FAIL only if the PrimaryPart rule rejects `Shaft` (write the
  check so it does today).
- [ ] **Step 3: Implement** `build_spear`: `rig_kit.optimize` (about 4,000 triangles, one 1024 colour map), scale to
  `length`, origin at `min z + grip_share x length` centred on X/Y, `find_head`: the lowest z in the top 45% where the
  smoothed width exceeds 1.6x the shaft's median width (the collar counts as head); split into `Head` (above) and
  `Shaft`; export / preview / save as the swords. Forge Spear: `weapon_kit.recolor` on the collar gems (the Head's lowest
  20%, pale texels) into five `ForgeSpear_<Element>_color.png`.
- [ ] **Step 4: Run** each build in a background Blender:
  `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_weapon_<id>.py`
  Expected: `<Name>.fbx`, `<Name>_color.png`, `<Name>.blend`, previews; the printed head bottom above the grip. Look at
  the previews; check `.blend` key fields empty (lengths only).
- [ ] **Step 5: Owner step**: show the four previews in the visual companion; upload the five Forge Spear colour maps
  (Studio `upload_image` from a local `http.server`) into `FORGE_COLOR_MAPS.ForgeSpear`; the owner imports each FBX
  (3D Importer, Rig Type None) and saves it to the paths above. Then `lune run tools/weapons/finish_sword <path>` for each
  and `lune run tools/weapons/forge_variants ForgeSpear`.
- [ ] **Step 6: Run** `lune run tests/run` → all pass. **Commit** the scripts, tools, configs and `.rbxm` files (not the
  raw GLBs or concepts): `git commit -m "Spears: models (weapon_kit spear cleanup, Forge Spear in five elements)"`

### Task 5: The spear animations

**Files:**
- Modify: `tools/blender/anim_kit.py` (a spear prop: `build(prop="spear", length=8.5)`, Shaft + Head at
  `hand_grip("spear")`; `two_hands(..., along=<studs up the shaft>)` works for the spear)
- Create: `tools/blender/anim_spear.py` (moves `ready`, `draw`, `sheath`, `run`, `cut1` Thrust, `cut2` Sweep, `cut3`
  Sky Pierce, `skill` Piercing Rush; markers `Hit` on every attack, `Grab` on draw, `Release` on sheath)
- Modify: `tools/blender/run_sword_moves.py` (`--sword spear` picks `anim_spear.py` and writes `assets/animations/Spear`)
- Create: `assets/animations/Spear/<move>.rbxm` (via `lune run tools/anim/build_kfs`)
- Modify: `src/shared/Config/Swords.luau` (`SWORDS.spear` timings from the markers; ids once published)
- Test: `tests/SwordsConfig.spec.luau` (the spear's timings pinned to its animations' markers, as the starter's are at
  `tests/SwordsConfig.spec.luau:339`)

- [ ] **Step 1: Key the moves** per the approved storyboard (spec 5.2): ready = upright at the right side, butt by the
  right foot; every attack swings it down into two hands first; the finisher's leap about 4 studs with a short hang, the
  plunge 8 studs ahead; the rush 12 studs. Export previews with
  `run_sword_moves.py -- --sword spear --preview <scratch dir>` and show the frame strips to the owner.
- [ ] **Step 2: Owner step**: the owner approves the previews (fix and re-show anything they flag).
- [ ] **Step 3: Build** `lune run tools/anim/build_kfs` → `assets/animations/Spear/*.rbxm`; note each move's `Hit` /
  `Grab` / `Release` marker times and lengths from its output.
- [ ] **Step 4: Write the failing test** in `tests/SwordsConfig.spec.luau`:
  `["the spear's timings are its animations' markers"]`: `combo[i].hitAt`, `combo[i].length`, `skill.hitAt`,
  `skill.length` equal the numbers from step 3 (each with a label naming the move).
- [ ] **Step 5: Run** `lune run tests/run SwordsConfig` → FAIL (Task 1's starting timings).
- [ ] **Step 6: Set** `SWORDS.spear` timings (`hitAt`, `cancelAt`, `length`, `lunge`, `hang`, `dash.from/to`) from the
  markers; re-scale the cut powers so the DPS test holds. Run `lune run tests/run` → all pass. Studio: each move plays
  from `SwordAnimations.Spear` with the spear in hand.
- [ ] **Step 7: Owner step**: the owner publishes each KFS (Save to Roblox) and sends the ids; they go into
  `SWORDS.spear.animations`. **Commit**: `git commit -m "Spears: the spear moves (Blender, KeyframeSequences, ids)"`

### Task 6: Spears in the game: ready, looks, glow, portraits, grips, the Forge window

**Files:**
- Modify: `src/shared/Config/Weapons.luau` (`ready = true` for the four spear kinds)
- Modify: `src/shared/Config/WeaponLooks.luau` (`forgeSpear_<Element>` via `element(...)` with `FORGE_SPEAR_PORTRAITS`;
  `magmaHalberd = element("Ember", <portrait>)`, `tidalTrident = element("Tide", ...)`, `titansLance = element("Bloom",
  ...)` or own colours; `GLOW_MAPS.ForgeSpear/MagmaHalberd/TidalTrident/TitansLance`)
- Modify: `tools/textures/make_glow_maps.py` (the four spears' glowing regions: the Forge Spear's gems, the Halberd's
  lava cracks and spike, the Trident's prongs and gem, the Lance's emerald veins and flowers)
- Modify: `src/client/Controllers/ForgeController.luau` (Forge rows grouped per family: key `forge<Family>` =
  `forgeSword` / `forgeSpear`, name `Forge Sword` / `Forge Spear`; `weaponOf` uses `` `{entry.key}_{selectedElement}` ``;
  the element buttons likewise)
- Modify: `src/shared/Config/Swords.luau` (`GRIPS.spear` calibrated)
- Modify: `src/client/Util/WeaponLook.luau:206` (a spear's `Head` gets the blade's full aura, ribbons and sparkles:
  `item.Name == "Blade" or item.Name == "Head"`)
- Create: `assets/ui/weapon-portraits/<Name>.png` (not synced)
- Test: `tests/WeaponsConfig.spec.luau` (every ready weapon has a look with a non-empty portrait and a glow map for its
  model)

- [ ] **Step 1: Write the failing test**: every `ready` weapon in `Config/Weapons` has `WeaponLooks.WEAPONS[id]` with a
  non-empty `portrait`, and its model (or its Forge base model) has a `GLOW_MAPS` entry.
- [ ] **Step 2: Run** → FAIL once the spears are set `ready` without looks.
- [ ] **Step 3: Glow maps**: `make_glow_maps.py` → upload → `GLOW_MAPS` ids → `lune run tools/weapons/add_glow_maps`.
  **Portraits**: each spear rendered big on magenta in Studio, cut with `tools/ui-art/cut_product_picture.py`, uploaded,
  ids in `WeaponLooks`. **Forge window** grouping per family.
- [ ] **Step 4: Grips in Studio**: equip each spear (`/weapon <id>`), draw it: the butt by the right foot in the ready
  pose, the head well over the head; on the back: measure the lowest point of the model above the ground (> 0.2 studs
  on the R15 test avatar) and its highest point (<= 3 studs over the head top), adjusting `GRIPS.spear.back` until both
  hold for the 9.2-stud Titan's Lance; screenshot each spear in hand and on the back.
- [ ] **Step 5: Run** `lune run tests/run` → all pass. **Commit** `git commit -m "Spears: ready, looks, glow maps, portraits, grips"`

### Task 7: Spear effects and sounds

**Files:**
- Modify: `src/shared/Config/SwordSkillFx.luau` (looks `spearStreak` kind slash, `skyPierce` kind finisher,
  `piercingRush` kind skill with `beats`; `PREVIEW` names `spear`, `halberd`, `trident`, `lance` →
  `forgeSpear_Ember`, `magmaHalberd`, `tidalTrident`, `titansLance`)
- Modify: `src/client/Util/SwordSkillFx.luau` (the three looks: the thrust's straight streak and tip flash and the
  sweep's wide arc from `slash` by cut index; the plunge's ground crack and shockwave ring at the tip; the rush's trail,
  speed streaks and a flash on each foe hit along the line)
- Modify: `src/shared/Config/Swords.luau` (`SWORDS.spear.sounds` own keys and `cues`; `SOUND_VOLUMES` entries)
- Modify: `src/shared/Config/SoundLevels.luau` (measured)
- Modify: `src/server/Services/DevService.luau` / `Config/AdminPanel` (`/skillfx spear|halberd|trident|lance ...`)
- Test: `tests/SwordSkillFx.spec.luau`, `tests/SoundLevel.spec.luau`, `tests/SwordsConfig.spec.luau` (cues' keys exist)

- [ ] **Step 1: Owner step**: an effects storyboard for the plunge and Piercing Rush in the visual companion (3-4 frames
  each, exaggerated); the owner OKs or adjusts.
- [ ] **Step 2: Write the failing tests**: the three looks exist with their kinds and textures from the existing set;
  `PREVIEW` has the four names; every `SWORDS.spear.cues` key is in `SWORDS.spear.sounds`; every spear sound is in
  `SoundLevels` (the existing gate).
- [ ] **Step 3: Run** → FAIL.
- [ ] **Step 4: Implement** the looks and sounds: pick Pro Sound Effects through the toolbox API (category 3, creator
  7462895450; memory licensed-sound-search): thrust whoosh, stab, sweep whoosh, leap, plunge impact and ground crack,
  rush; measure them with `tools/audio/measure_loudness.luau` into `Config/SoundLevels`.
- [ ] **Step 5: Run** `lune run tests/run` → all pass. **Studio check**: `/skillfx spear cut1|cut2|cut3|skill` for each
  of the four, screenshots of each moment (held camera), frame time with four casting at once
  (`rbx-perf-profiling`), the lite version from a second player's view in a 2-player Local Server.
- [ ] **Step 6: Commit** `git commit -m "Spears: effects and sounds"`

### Task 8: The spear's skill button

**Files:**
- Modify: `tools/ui-icons/slice_icons.py` (`SHEETS[9]`), `src/shared/Config/UIIcons.luau` (`PiercingRush` + spares),
  `src/shared/Config/CombatHud.luau` (`SKILLS.spear = { icon = "PiercingRush", name = "Piercing Rush", tip = "Rush
  forward tip-first and pierce every foe in a line." }`)
- Create: `assets/ui/icons/sheet9.png` and its slices
- Test: `tests/SkillText.spec.luau`

- [ ] **Step 1: Write the failing test**: `SkillText.swordSkill(CombatHud, "spear")` gives icon `PiercingRush`, name
  `Piercing Rush`, and a tip ending with `SKILL_DODGE_TIP`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Owner step**: 2-4 glyph sketches for Piercing Rush in the visual companion (the sword sheet 8 style:
  white, dark purple outline); after the pick, one Figma generation of a 4x4 white glyph sheet on magenta: the pick plus
  spares for round 2.5's spear skills and the scythes; slice (`slice_icons.py sheet9.png 9`), `clean_glyphs.py`, upload,
  ids in `UIIcons`.
- [ ] **Step 4: Run** `lune run tests/run` → all pass; Studio: the skill button in a boss fight with a spear.
- [ ] **Step 5: Commit** `git commit -m "Spears: the Piercing Rush skill button"`

### Task 9: Balance, docs and the final pass

**Files:**
- Modify: `src/shared/Config/Weapons.luau` (perk numbers only if the balance runs require)
- Modify: `DESIGN.md` (5.11 weapons: spears, grips, the switch; files; backlog tick), `CLAUDE.md` (new test names
  `WeaponSwitch`; `forge_variants <model>`; spear build scripts; `anim_spear.py`; sheet 9), `docs/weapons.md` (spear
  cleanup, Forge Spear), `docs/animations.md` (the spear moves), Obsidian vault, memory `weapon-families.md`

- [ ] **Step 1: Balance**: `WEAPON="<id>:10:S" lune run tools/balance/bosses 400 1 <tier boss>` for each spear and its
  `TIER_BOSS`, plus `:0:C`; every row inside round 1's 4.6 limits (0.8x party fighting well at most 85%; +10 Grade S at
  most halves a 1x fight). Adjust only perk numbers; record the rows in DESIGN.md's weapons balance rows.
- [ ] **Step 2: Docs** as listed; `rojo build -o <scratch>/test.rbxl` builds; `rojo sourcemap default.project.json -o
  sourcemap.json`.
- [ ] **Step 3: Run** `lune run tests/run` → all pass. **Commit** `git commit -m "Weapons round 2: balance and docs"`
- [ ] **Step 4: Final Studio pass**: each spear's moves against `/boss 1 fight`, the switch between a sword and a spear
  mid-fight, the Forge window's Forge Spear, the Armory cards; screenshots; then tell the owner exactly what to judge.
