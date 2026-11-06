# Weapons Round 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the whole weapon system (data, Power, grades, upgrades, element bond and wheel, perks, boss materials,
the Forge, direct drops with a cinematic, the Armory binder tab, glow ladder) and the four new swords.

**Architecture:** One plain-data catalogue (`Config/Weapons`) and pure rules (`Util/WeaponRules`, `WeaponLookRules`,
`WeaponText`, Lune-tested) shared by both sides. The server owns weapons (`WeaponService`: saves, equip, give) and the
Forge (`ForgeService`: forge, upgrade, reforge at your own Forge machine); `BattleSim.swordHit` takes the equipped
weapon's element, bond and perk. The client draws weapons (`Util/WeaponLook`), the Forge window, the forge reveal and
drop cinematic on the pack-opening stage, the Armory tab and the Boss Board's weapon cards.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), ProfileStore via DataService,
Blender MCP + Meshy for the models, Figma's image generator for concepts, the Roblox Studio MCP for checks.

**Spec:** `docs/superpowers/specs/2026-11-06-weapons-round1-design.md` (owner approved 2026-11-06).

## Global Constraints

- Server authoritative: forge, upgrade, reforge, equip, grade rolls and drops happen on the server; every remote is in
  `src/shared/Remotes.luau`, validated (types, ownership, distance to the player's own Forge machine) and rate-limited
  with `src/server/Util/RateLimiter.luau`; never trust a client cost.
- All cash changes go through `EconomyService`; items through `ItemService` (`GetCount`, `GiveItem`, `TakeItem`).
- All tunable numbers live in `src/shared/Config` as plain data (Lune loads them); pure modules take their config as a
  parameter and require no siblings.
- Saved shape change: `SCHEMA_VERSION` 15 -> 16 in `Config/Data.luau`, a `MIGRATIONS[15]` step with a Lune test,
  DataService types/template, DESIGN.md 10.4. Validate on load; never silently lose a weapon (unknown ids are logged).
- Every weapon copy carries its grade (C/B/A/S, rolled with `BeastRules.rollGrade(roll, rarity)`) and level 0-10.
- Numbers from the spec: base Power by rarity Common 1.15 (Steel Sword stays 1), Rare 1.35, Very Rare 1.55, Epic 1.8,
  Legendary 2.1; grade C x1.00, B x1.05, A x1.10, S x1.15; +5% Power per level, max +10; bond x1.15 damage and x1.5
  sword super-meter fill; element wheel `Combat.BEATS` (x1.5 / x0.75); Grade S perks x1.2; direct drop 1% + 0.5% per
  full-loot kill since the last; a drop you own turns into 10 of its material; reforge costs half (rounded up).
- Costs from the spec: Forge Sword $1,500 + 20 Wild Ore from shop level 6; Rare 15 material + $2,000; Very Rare 25 +
  $5,000; Epic 40 + $12,000; Legendary 60 + $30,000; Sunforged Blade 20 Colossus Core + 10 Warden Heartwood + 10 Brood
  Silk + 5 Star Shards + $25,000. Materials drop only with full loot, chance 0.8, 1-2 each; the daily first-win chest
  adds 2. Wild Ore: 15% from a normal Wild/Frontier monster, 60% from an elite.
- Weapons play no part in PvP. No Robux sales of weapons.
- UI: cotton candy windows (`UIKit.panel` default theme, `UIKit.colorsFor`), FredokaOne/Montserrat via FontStyle, text
  plain ASCII plus `·` and emoji, tap targets >= 48 px, checked on a landscape phone in the Device emulator.
- Looks: one particle aura per weapon; toned down on the back in town (fewer particles, no light); 6 players in town
  carrying +10 weapons stay at 60 fps.
- Studio MCP: reading is fine anytime; ask before changing the place. Studio saves go to the real DataStores: list
  every save change in the report. Never print the Meshy API key; check a `.blend`'s `blendermcp_*key*`/`*secret*`
  fields are empty before committing it; delete raw `*_Src` objects and purge orphans before saving a blend.
- Meshy budget: about 30 credits a generation; round 1 is 4 models (Forge Sword, Verdant Blade, Sunforged Blade, Prism
  Blade) plus at most 2 retries. Ask the owner before any regeneration.

## Review Focus

1. A forge request whose costs the player only partly has, or two requests sent at once: nothing may be taken without a
   weapon given, and never two grades rolled for one payment. (Task 2 `WeaponRules.pay` test; Task 5 per-player busy
   lock and its Studio check.)
2. A save that names a weapon the config no longer has, or an equipped weapon the player doesn't own: it loads with the
   Steel Sword equipped and the unknown entry logged, not an error. (Task 2 `WeaponRules.read` test, used by Task 3.)
3. A boss dropping a weapon the player already owns: it becomes 10 of its material and the cinematic says so, never a
   second copy or a lowered grade. (Task 2 `WeaponRules.give` test.)
4. A weapon whose model isn't imported yet (the new swords before Task 12): fights and the back display use a code-built
   stand-in, never an error. (Task 6 `WeaponLook` fallback and its Studio check.)
5. A Grade S weapon reforged: the better grade is always kept. (Task 2 `WeaponRules.give` test.)

---

### Task 1: The catalogue: `Config/Weapons`, `Config/WeaponLooks`, items

**Files:**
- Create: `src/shared/Config/Weapons.luau`, `src/shared/Config/WeaponLooks.luau`
- Modify: `src/shared/Config/Items.luau` (8 items), `src/shared/Config/Bosses.luau` (drops, dailyBonus),
  `src/shared/Config/Wild.luau` and `src/shared/Config/Frontier.luau` (`ORE_CHANCE`, `ELITE_ORE_CHANCE`),
  `src/shared/Util/CombatMath.luau` (`getRewards` returns `oreChance`), `src/server/Services/BattleService.luau`
  (`payOut`: a normal Wild/Frontier win rolls `oreChance` and gives 1 Wild Ore through `ItemService.GiveItem`;
  Dungeon rooms and bosses don't)
- Test: `tests/WeaponsConfig.spec.luau` (register in `tests/run.luau`), `tests/CombatMath.spec.luau` (oreChance)

**Interfaces:**
- Produces `Config/Weapons` (plain data):
  - `WEAPONS: { Weapon }` in Armory order and `ById: { [string]: Weapon }`, where
    `Weapon = { id: string, name: string, family: "sword"|"spear"|"scythe", rarity: string, element: string?,
    prism: boolean?, ready: boolean, moveset: string?, model: string?, source: Source, perk: Perk? }`,
    `Source = { kind: "starter"|"forge"|"boss"|"masterwork", boss: string?, cost: Cost? }`,
    `Cost = { cash: number, items: { [string]: number }, unlockLevel: number? }`,
    `Perk = { kind: "heal"|"burn"|"prism", every: number?, share: number?, seconds: number? }`.
  - Ids: `starterSword` (Steel Sword, Common, power 1 via `STARTER_POWER = 1`, source starter, moveset `starterSword`),
    `forgeSword_Ember`, `forgeSword_Tide`, `forgeSword_Bloom`, `forgeSword_Volt`, `forgeSword_Shade` (Common, that
    element, forge cost), `verdantBlade` (Rare, Bloom, boss meadowWarden, perk heal every 4 share 0.02),
    `sunforgedBlade` (Epic, Ember, masterwork, perk burn share 0.03 seconds 3), `prismBlade` (Legendary, prism true, boss
    prismHydra, perk prism); not ready yet (`ready = false`): `forgeSpear`, `magmaHalberd` (VR, Ember, emberColossus),
    `tidalTrident` (Epic, Tide, frostTyrant), `titansLance` (Legendary, Bloom, masterwork), `forgeScythe`,
    `widowsReaper` (VR, Shade, caveBroodQueen), `stormReaper` (Epic, Volt, stormSovereign), `riftReaper` (Legendary,
    Shade, riftDevourer). Every round-1 sword uses `moveset = "starterSword"`.
  - Numbers: `RARITY_POWER`, `GRADE_POWER`, `UPGRADE_STEP = 0.05`, `MAX_LEVEL = 10`, `BOND = { damage = 1.15, meter =
    1.5 }`, `PERK_S = 1.2`, `BOSS_COST = { Rare = { material = 15, cash = 2000 }, ["Very Rare"] = { 25, 5000 }, Epic =
    { 40, 12000 }, Legendary = { 60, 30000 } }` (named fields), `REFORGE_SHARE = 0.5`, `DUPLICATE_MATERIAL = 10`,
    `DROP = { base = 0.01, step = 0.005 }`, `UPGRADE = { cash = { 500, 1000, 1500, 2500, 4000, 6000, 8500, 12000, 16000,
    22000 }, material = { 2, 2, 3, 3, 4, 5, 6, 7, 8, 10 }, starShards = { [5] = 1, [10] = 3 }, rarityCash = { Common =
    0.5, Rare = 0.8, ["Very Rare"] = 1, Epic = 1.3, Legendary = 1.6 } }`, `MATERIALS: { [bossId]: itemId }` (meadowWarden
    -> `material_meadowWarden`, ... for all 7 bosses), `WILD_ORE = "wildOre"`, `FORGE_UNLOCK_LEVEL = 6`,
    `TIER_BOSS = { forgeSword = "meadowWarden", verdantBlade = "caveBroodQueen", sunforgedBlade = "frostTyrant",
    prismBlade = "prismHydra" }` (for the balance check).
- Produces `Config/WeaponLooks` (plain data, `{ r, g, b }` colours): per weapon id `{ glow, trail, aura =
  "embers"|"frost"|"petals"|"sparks"|"wisps"|"prism"|"none", awakened = "sunHalo"|"vineCrown"|"prismWings"|"elementRunes",
  portrait = "" }`; the ladder `LADDER = { edge = { [1] = 0.25, [2] = 0.4, [3] = 0.55 }, auraFrom = 4, auraRate = { 4,
  6, 8 }, trailFrom = 7, trailScale = { 1.2, 1.35, 1.5 }, awakenedAt = 10 }`; `BACK = { auraShare = 0.35, light =
  false }`; rarity resting glow `REST = { Common = 0.1, Rare = 0.25, ["Very Rare"] = 0.3, Epic = 0.4, Legendary = 0.5 }`.
- Items: `wildOre` ("Wild Ore") and `material_<bossId>` for the 7 bosses, names from the spec (Warden Heartwood, Brood
  Silk, Colossus Core, Frost Heart, Storm Crystal, Rift Shard, Prism Scale), each with `icon`, `description`, `source`,
  `use = "The Forge in your shop"`. Their `icon` is an emoji for now (Icon draws text when the name isn't a picture);
  Task 12 makes the picture icons.

- [ ] **Step 1: Write the failing tests** in `tests/WeaponsConfig.spec.luau`:

```lua
["every weapon is complete and in the Armory order"] = function()
	expect.equal(#Weapons.WEAPONS, 17) -- Steel, 5 Forge Swords, 3 new swords, 4 spears, 4 scythes
	for _, w in Weapons.WEAPONS do
		assert(Weapons.ById[w.id] == w, w.id)
		assert(Weapons.RARITY_POWER[w.rarity] or w.id == "starterSword", w.id)
		if w.ready then assert(w.moveset and w.model, `{w.id} needs a moveset and a model`) end
		assert(WeaponLooks[w.id], `{w.id} needs a look`)
	end
end,
["each boss drops its own material with full loot, and its daily chest adds 2"] = function()
	for bossId, item in Weapons.MATERIALS do
		assert(Items.ITEMS[item], item)
		local found = false
		for _, drop in Bosses.BOSSES[bossId].drops do
			if drop.item == item then found = true; expect.equal(drop.chance, 0.8); expect.equal(drop.min, 1); expect.equal(drop.max, 2) end
		end
		assert(found, bossId)
	end
end,
["the pace: a Rare weapon in about 2 days, a Legendary in 7-16 (owner's approved pace)"] = function()
	local perDay = Bosses.SOFT_CAP_AFTER * 0.8 * 1.5 + 2 -- full-chance kills x chance x average count + the daily chest
	local rare = Weapons.BOSS_COST.Rare.material / perDay
	local legendary = Weapons.BOSS_COST.Legendary.material / perDay
	assert(rare >= 1.5 and rare <= 3, `Rare {rare} days`)
	assert(legendary >= 6 and legendary <= 16, `Legendary {legendary} days`)
end,
-- tests/CombatMath.spec.luau:
["a Wild win's rewards carry the ore chance: 15%, an elite 60%"] = function()
	expect.equal(CombatMath.getRewards(Wild, 5, false).oreChance, 0.15)
	expect.equal(CombatMath.getRewards(Wild, 5, true).oreChance, 0.6)
end,
["Wild Ore drops from Wild and Frontier monsters"] = function()
	expect.equal(Wild.ORE_CHANCE, 0.15); expect.equal(Wild.ELITE_ORE_CHANCE, 0.6)
	expect.equal(Frontier.ORE_CHANCE, 0.15); expect.equal(Frontier.ELITE_ORE_CHANCE, 0.6)
	assert(Items.ITEMS.wildOre)
end,
```

- [ ] **Step 2: Run** `lune run tests/run WeaponsConfig` — Expected: FAIL (module missing).
- [ ] **Step 3: Write the configs and item/boss/wild entries** with the values above.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass (the BossRules/ItemRules tests still pass with the new drops).
- [ ] **Step 5: Commit** `git commit -m "Weapons: the catalogue, looks, materials and Wild Ore"`

### Task 2: `Util/WeaponRules` (pure)

**Files:**
- Create: `src/shared/Util/WeaponRules.luau`
- Test: `tests/WeaponRules.spec.luau` (register)

**Interfaces:**
- Consumes: `Config/Weapons`, `Config/Combat` (BEATS, STRONG, WEAK) as parameters.
- Produces:
  - `WeaponRules.power(cfg, weaponId: string, grade: string, level: number): number`
  - `WeaponRules.hitElement(cfg, weaponId: string, foeElement: string?, combat): string?` (prism: the element in
    `combat.BEATS` strong against `foeElement`; a plain weapon: its own; Steel: nil)
  - `WeaponRules.bond(cfg, weaponId: string, creatureElement: string?): (number, number)` (damage, meter multipliers;
    prism bonds with any element)
  - `WeaponRules.perk(cfg, weaponId: string, grade: string): Perk?` (Grade S: `share` x PERK_S)
  - `WeaponRules.makeCost(cfg, weaponId: string): Cost?` (forge / boss rarity cost / masterwork; nil for starter and
    not-ready weapons), `WeaponRules.reforgeCost(cfg, weaponId: string): Cost?` (half, rounded up),
    `WeaponRules.upgradeCost(cfg, weaponId: string, toLevel: number): Cost?` (nil past MAX_LEVEL; Forge weapons pay in
    Wild Ore, Steel Sword can't upgrade)
  - `WeaponRules.pay(cost: Cost, cash: number, items: { [string]: number }): (boolean, string?)` (all or nothing; the
    reason names the first missing thing: "cash" or the item id)
  - `WeaponRules.give(owned: { [string]: Owned }, weaponId: string, grade: string, how: "forge"|"reforge"|"drop", cfg):
    (Owned?, number)` where `Owned = { grade: string, level: number }`: the new record (nil when unchanged) and the
    material refund (DUPLICATE_MATERIAL for a drop already owned; 0 otherwise); a reforge/forge of an owned weapon
    keeps the better grade and the level
  - `WeaponRules.dropChance(cfg, pity: number): number` (min(1, base + step x pity)); `WeaponRules.read(cfg, saved:
    unknown, equipped: unknown): ({ [string]: Owned }, string, { string })` (clean table, equipped id or "starterSword",
    the unknown ids it dropped)
  - `WeaponRules.unlocked(cfg, weaponId, shopLevel: number): boolean`

- [ ] **Step 1: Write the failing tests** (values from Global Constraints):

```lua
["Power: rarity x grade x levels; the Steel Sword stays 1"] = function()
	expect.equal(WeaponRules.power(W, "starterSword", "C", 0), 1)
	expect.near(WeaponRules.power(W, "verdantBlade", "C", 0), 1.35, 1e-9)
	expect.near(WeaponRules.power(W, "prismBlade", "S", 10), 2.1 * 1.15 * 1.5, 1e-9)
end,
["bond: same element x1.15 damage and x1.5 meter; prism bonds with any; Steel never"] = function()
	local d, m = WeaponRules.bond(W, "forgeSword_Ember", "Ember"); expect.equal(d, 1.15); expect.equal(m, 1.5)
	d, m = WeaponRules.bond(W, "forgeSword_Ember", "Tide"); expect.equal(d, 1); expect.equal(m, 1)
	d = WeaponRules.bond(W, "prismBlade", "Shade"); expect.equal(d, 1.15)
	d = WeaponRules.bond(W, "starterSword", "Ember"); expect.equal(d, 1)
end,
["the Prism Blade is always strong against the foe's element"] = function()
	expect.equal(WeaponRules.hitElement(W, "prismBlade", "Tide", Combat), "Bloom")
	expect.equal(WeaponRules.hitElement(W, "prismBlade", "Volt", Combat), "Shade")
	expect.equal(WeaponRules.hitElement(W, "verdantBlade", "Tide", Combat), "Bloom")
	expect.isNil(WeaponRules.hitElement(W, "starterSword", "Tide", Combat))
end,
["costs: boss weapons by rarity, the masterwork's recipe, reforge half rounded up"] = function()
	local rare = WeaponRules.makeCost(W, "verdantBlade")
	expect.equal(rare.cash, 2000); expect.equal(rare.items.material_meadowWarden, 15)
	local sun = WeaponRules.makeCost(W, "sunforgedBlade")
	expect.equal(sun.items.material_emberColossus, 20); expect.equal(sun.items.starShard, 5); expect.equal(sun.cash, 25000)
	expect.equal(WeaponRules.reforgeCost(W, "verdantBlade").items.material_meadowWarden, 8)
	expect.isNil(WeaponRules.makeCost(W, "starterSword")); expect.isNil(WeaponRules.makeCost(W, "riftReaper"))
end,
["upgrades: +5 and +10 need Star Shards; none past +10; Forge weapons pay in Wild Ore"] = function()
	expect.equal(WeaponRules.upgradeCost(W, "verdantBlade", 5).items.starShard, 1)
	expect.equal(WeaponRules.upgradeCost(W, "verdantBlade", 10).items.starShard, 3)
	expect.isNil(WeaponRules.upgradeCost(W, "verdantBlade", 11))
	expect.equal(WeaponRules.upgradeCost(W, "forgeSword_Tide", 1).items.wildOre, 2)
	expect.isNil(WeaponRules.upgradeCost(W, "starterSword", 1))
end,
["paying is all or nothing"] = function()
	local cost = { cash = 100, items = { a = 2, b = 1 } }
	local ok, why = WeaponRules.pay(cost, 100, { a = 2 }); expect.equal(ok, false); expect.equal(why, "b")
	ok, why = WeaponRules.pay(cost, 99, { a = 2, b = 1 }); expect.equal(ok, false); expect.equal(why, "cash")
	expect.equal((WeaponRules.pay(cost, 100, { a = 2, b = 1 })), true)
end,
["a drop you already own becomes 10 material; a reforge keeps the better grade and the level"] = function()
	local owned = { verdantBlade = { grade = "S", level = 4 } }
	local rec, refund = WeaponRules.give(owned, "verdantBlade", "C", "drop", W); expect.isNil(rec); expect.equal(refund, 10)
	rec = WeaponRules.give(owned, "verdantBlade", "B", "reforge", W); expect.isNil(rec)
	rec = WeaponRules.give({ verdantBlade = { grade = "B", level = 4 } }, "verdantBlade", "S", "reforge", W)
	expect.equal(rec.grade, "S"); expect.equal(rec.level, 4)
	rec = WeaponRules.give({}, "verdantBlade", "A", "drop", W); expect.equal(rec.grade, "A"); expect.equal(rec.level, 0)
end,
["drop chance: 1% plus 0.5% a kill without one"] = function()
	expect.near(WeaponRules.dropChance(W, 0), 0.01, 1e-9)
	expect.near(WeaponRules.dropChance(W, 10), 0.06, 1e-9)
	expect.equal(WeaponRules.dropChance(W, 500), 1)
end,
["loading: unknown weapons dropped and named, levels clamped, a missing equip falls back to the Steel Sword"] = function()
	local owned, equipped, dropped = WeaponRules.read(W, { verdantBlade = { grade = "Z", level = 99 }, gone = { grade = "S", level = 1 } }, "riftReaper")
	expect.equal(owned.verdantBlade.grade, "C"); expect.equal(owned.verdantBlade.level, 10)
	expect.isNil(owned.gone); expect.equal(dropped[1], "gone"); expect.equal(equipped, "starterSword")
	local _, kept = WeaponRules.read(W, { verdantBlade = { grade = "A", level = 2 } }, "verdantBlade"); expect.equal(kept, "verdantBlade")
end,
```

- [ ] **Step 2: Run** `lune run tests/run WeaponRules` — Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `src/shared/Util/WeaponRules.luau` with the signatures above.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Commit** `git commit -m "Weapons: WeaponRules (power, bond, wheel, costs, pay, give, drops, load)"`

### Task 3: Saves and `WeaponService` (owned, equipped, back display)

**Files:**
- Modify: `src/shared/Config/Data.luau` (SCHEMA_VERSION 16), `src/server/Util/Migrations.luau` (`[15]`),
  `src/server/Services/DataService.luau` (types + template: `weapons = {}`, `equippedWeapon = "starterSword"`),
  `src/shared/Remotes.luau` (`EquipWeapon`, `WeaponsChanged`), `src/server/Services/SwordService.luau`
  (`GetSword` returns the equipped weapon id), `src/server/init.server.luau` (start WeaponService after ItemService)
- Create: `src/server/Services/WeaponService.luau`
- Test: `tests/Migrations.spec.luau` (v16 case)

**Interfaces:**
- Consumes: `WeaponRules.read/give/power/unlocked`, `Config/Weapons`.
- Produces (server):
  - `WeaponService.GetEquipped(player): string?` (nil below `Swords.UNLOCK_SHOP_LEVEL`; else the equipped id, falling
    back to `starterSword`), `WeaponService.GetOwned(player, weaponId): Owned?`,
    `WeaponService.Power(player): number`,
    `WeaponService.Give(player, weaponId, grade, how): (Owned?, number)` (applies `WeaponRules.give`, saves, pays the
    refund through `ItemService.GiveItem(material)`), `WeaponService.SetLevel(player, weaponId, level)`,
    `WeaponService.Changed(player)` (sends `WeaponsChanged` and refreshes the character's attributes).
  - Character attributes (clients draw from them): `Sword` = weapon id (kept name), `SwordGrade`, `SwordLevel`.
  - `Remotes.EquipWeapon(weaponId)`: owned and ready, not in a fight (`BattleService.IsFighting(player)`; add it if
    missing), rate-limited 0.5 s. `Remotes.WeaponsChanged` payload: `{ owned = { [id]: Owned }, equipped = id }`.
  - `SwordService.GetSword(player)` now returns `WeaponService.GetEquipped(player)`'s **moveset** id for the moves and
    the weapon id for the attribute (BattleService reads `Weapons.ById[id].moveset` for cuts and `WeaponService.Power`
    for power).

- [ ] **Step 1: Write the failing test** in `tests/Migrations.spec.luau`:

```lua
["v16: an empty Armory and the Steel Sword equipped; junk cleaned"] = function()
	local data: any = { version = 15 }
	Migrations.run(data, 16)
	expect.equal(typeof(data.weapons), "table"); expect.equal(next(data.weapons), nil)
	expect.equal(data.equippedWeapon, "starterSword"); expect.equal(data.version, 16)
	local junk: any = { version = 15, weapons = "x", equippedWeapon = 5 }
	Migrations.run(junk, 16)
	expect.equal(typeof(junk.weapons), "table"); expect.equal(junk.equippedWeapon, "starterSword")
end,
```

- [ ] **Step 2: Run** `lune run tests/run Migrations` — Expected: FAIL.
- [ ] **Step 3: Implement** the migration, schema 16, DataService fields, `WeaponService` (DataService.Register
  load/save/unload; `save` does nothing for a player it never loaded), the remote, the attributes, and SwordService's
  change; BattleService's cut and skill power become `cut.power * WeaponService.Power(player)` with the moveset from
  `Weapons.ById[id].moveset`.
- [ ] **Step 4: Run** `lune run tests/run` and `rojo build -o <scratch>/test.rbxl` — Expected: all pass, build ok.
- [ ] **Step 5: Studio check:** Play; the Steel Sword still draws and fights (a Meadow Warden fight via `/boss 1
  fight`), Output clean; `data.version` 16 after a save.
- [ ] **Step 6: Commit** `git commit -m "Weapons: saves v16 and WeaponService (owned, equipped, attributes)"`

### Task 4: Weapons in fights: element wheel, bond, perks, and the balance check

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (`swordHit`), `src/server/Services/BattleService.luau` (pass
  `WeaponService.HitInfo`), `tools/balance/bosses.luau` (a `WEAPON` env), `DESIGN.md` (the rows)
- Test: `tests/BattleSim.spec.luau` (or the existing combat spec that covers swordHit)

**Interfaces:**
- Produces: `export type SwordWeapon = { element: string?, prism: boolean, bond: number, meter: number, perk: Perk? }`
  in BattleSim; `BattleSim.swordHit(state, owner, targetId, power, kind, weapon: SwordWeapon?)`: the hit uses
  `weapon.element` against the target's element through the existing wheel (prism: the strong one,
  `WeaponRules.hitElement`), multiplies damage by `weapon.bond`, multiplies the sword's super-meter gain by
  `weapon.meter`, and runs the perk: `heal` (every `every`-th sword hit by this owner heals their creature `share` of
  its max HP), `burn` (the target takes `share` x the creature's ATK a second for `seconds`, refreshed not stacked).
  Without `weapon` it behaves exactly as today.
- `WeaponService.HitInfo(player, creatureElement: string?): BattleSim.SwordWeapon` (added here; built from
  `WeaponRules.hitElement/bond/perk` for the equipped weapon).
- `tools/balance/bosses`: `WEAPON="<id>:<level>:<grade>"` makes every player's sword hits use that weapon's Power,
  element, bond (with the party's best card as the summoned creature) and perk.

- [ ] **Step 1: Write the failing tests** (a minimal sim state the spec file already builds for swordHit):

```lua
["a weapon of the strong element hits x1.5, bonded another x1.15"] = function() ... end,
["the Prism Blade always counts as strong"] = function() ... end,
["Verdant Blade heals the creature 2% on every 4th hit"] = function() ... end,
["Sunforged Blade's burn refreshes, never stacks"] = function() ... end,
["no weapon: the same damage as before"] = function() ... end,
```
  Each asserts the damage events' amounts against `creature ATK x power x multipliers` computed in the test, and the
  heal/burn events by count and size.
- [ ] **Step 2: Run** `lune run tests/run BattleSim` — Expected: FAIL.
- [ ] **Step 3: Implement** swordHit's weapon parameter and BattleService's call (`WeaponService.HitInfo(player)` with
  the summoned creature's element for the bond).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Balance check** (spec 4.6; the spec's "at most 85% at 0.8x" can't hold for bosses already above it
  without weapons, so the check is relative): for each round-1 weapon at `:0:C` and `:10:S` on its `TIER_BOSS`, run
  `lune run tools/balance/bosses 60 1 <boss>` with and without `WEAPON`. Pass: the "well" win rate at 0.8x rises by at
  most 15 points over the Steel Sword's, and the +10 S fight at 1x is never shorter than half the Steel Sword's. If a
  row fails, lower that rarity's `RARITY_POWER` (or the perk) and rerun; write the final rows into DESIGN.md.
- [ ] **Step 6: Commit** `git commit -m "Weapons: element wheel, bond and perks in sword hits; balance rows"`

### Task 5: The Forge (server): machine, remotes, forging, upgrading, reforging

**Files:**
- Modify: `src/shared/Config/Shelves.luau` (a `Forge` def: `id = "Forge", prop = "Forge", name = "Forge", kind =
  "Forge", category = "Fixtures", capacity = 0, cost = 1500, unlockLevel = 6, size = Vector3.new(6, 6, 6)`),
  `src/server/Services/PlacementService.luau` (`isMachine` includes Forge; its info "⚒️ Forge"), `src/shared/Remotes.luau`
  (`ForgeWeapon`, `UpgradeWeapon`, `ReforgeWeapon` client->server; `ForgeResult` server->client)
- Create: `src/server/Services/ForgeService.luau`
- Test: none new (rules tested in Task 2); Studio check.
- Note: the spec (section 6) put the Forge "by the Boss Board in town", but the Boss Board is a HUD window, not a
  place; the Forge is a machine in your own shop like the Condenser (raised with the owner at the plan's handoff).

**Interfaces:**
- Consumes: `WeaponRules.makeCost/reforgeCost/upgradeCost/pay/unlocked`, `WeaponService.Give/GetOwned/SetLevel`,
  `EconomyService` (spend), `ItemService.TakeItem/GetCount`, `PlacementService.GetShelves`.
- Produces: `ForgeResult` payload `{ action: "forge"|"reforge"|"upgrade", weaponId, grade, level, kept: boolean }`
  (kept: a reforge that didn't beat the old grade). Each request: rate-limited 1 s; the player's own Forge machine
  within 12 studs of their character; one request at a time per player (a busy flag, cleared in all paths); costs
  checked with `WeaponRules.pay` against the server's numbers, then taken (cash first through EconomyService, then
  items; if a take fails, refund what was taken and stop), then the grade rolled on the server and given.
  Messages through `Remotes.Notify` for every refusal ("Not enough Warden Heartwood (9/15)").

- [ ] **Step 1: Implement** the Shelves def (placement and the Build menu pick it up like the Condenser), the remotes
  and ForgeService (started after WeaponService in `init.server.luau`).
- [ ] **Step 2: Add Studio commands** in DevService: `/weapon <id> [grade] [level]` (give), `/material <bossId> <n>`
  (its material), and admin panel buttons (`Config/AdminPanel`); list them in CLAUDE.md.
- [ ] **Step 3: Run** `lune run tests/run` — Expected: all pass (AdminPanel config test included).
- [ ] **Step 4: Studio check:** place a Forge (Build -> Fixtures), give materials with `/material`, forge a Forge
  Sword and the Verdant Blade, upgrade to +2, reforge once; spam the Forge button for 2 s and check one result per
  payment (Review Focus 1); walk away 20 studs and check refusals. Output clean. List the save changes.
- [ ] **Step 5: Commit** `git commit -m "Weapons: the Forge machine and ForgeService"`

### Task 6: Weapon looks: the glow ladder in hand and on the back

**Files:**
- Create: `src/shared/Util/WeaponLookRules.luau` (pure), `src/client/Util/WeaponLook.luau`
- Modify: `src/client/Controllers/SwordController.luau` (draw the equipped weapon from `Sword`/`SwordGrade`/`SwordLevel`
  with WeaponLook, hand and back), `src/client/Util/SwordFx.luau` or `HitFx` (trail colour/scale from the look)
- Test: `tests/WeaponLookRules.spec.luau`

**Interfaces:**
- `WeaponLookRules.layers(looks, rarity: string, level: number, grade: string, place: "hand"|"back"): { edge: number,
  aura: number (particles a second, 0 = none), trailScale: number, burst: boolean, awakened: boolean, twinkle: boolean,
  light: boolean }` from `Config/WeaponLooks` LADDER/REST/BACK.
- `WeaponLook.build(weaponId, grade, level, place): Model` — the model from `ReplicatedStorage.WeaponModels` (or a
  code-built stand-in blade in the weapon's glow colour when it's missing: Review Focus 4), plus the glow shell (a clone
  of each `MeshPart` scaled x1.03, Neon, transparency 1 - edge), one ParticleEmitter (its aura texture by `aura`, rate
  by layers), a PointLight (hand only), the awakened effect and the S twinkle. `WeaponLook.update(model, ...)` for a
  level change.

- [ ] **Step 1: Write the failing tests:** +0 Common: edge = REST.Common, aura 0; +3: edge LADDER.edge[3]; +4: aura
  LADDER.auraRate[1]; +7: trailScale 1.2 and burst; +10: awakened; grade S: twinkle; back: aura x BACK.auraShare and
  no light; edge never above 1.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the rules, WeaponLook and SwordController's use; the Steel Sword keeps today's look.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Studio check:** `/weapon sunforgedBlade S 10` then levels 0, 3, 6, 9, 10 (screenshots hand and back);
  a weapon with no model (stand-in, no error); a town test with the frame time in the Output (6 players' worth: spawn
  5 back-display copies on test rigs) at 60 fps.
- [ ] **Step 6: Commit** `git commit -m "Weapons: the glow ladder in hand and on the back"`

### Task 7: The Forge window (client)

**Files:**
- Create: `src/client/Controllers/ForgeController.luau`, `src/shared/Util/WeaponText.luau` (pure),
  `src/client/Util/WeaponFace.luau` (the weapon card face; its interface is in Task 10's block, which uses it too)
- Test: `tests/WeaponText.spec.luau`

**Interfaces:**
- Produces: `WeaponText.stats(cfg, weaponId, owned: Owned?, combat): { { label: string, value: string } }` (Power as
  "x1.62", element and bond, perk in words, grade, +level) and `WeaponText.cost(cost: Cost, have: { [string]: number },
  cash: number, items): { { text: string, enough: boolean } }` ("Warden Heartwood 9/15"); the perk words:
  heal "Every 4th hit heals your creature 2%", burn "Sets the foe burning for 3 s", prism "Always strong against the
  foe's element".
- The window: a cotton candy `UIKit.panel` opened from a client-created owner-only ProximityPrompt on your own Forge
  (the Condenser's pattern), closing when you walk away; three tabs Forge / Upgrade / Reforge; each row a weapon card
  (`WeaponFace`, made here), its cost lines with have/need, one button. Forge-tab rows: every
  ready weapon you can make at your shop level; Coming soon weapons not shown here.

- [ ] **Step 1: Write the failing tests** for WeaponText (the exact words above, Power formatted to 2 decimals, cost
  lines with have/need and `enough`).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** WeaponText and the window.
- [ ] **Step 4: Run** `lune run tests/run`; VS Code diagnostics on the client files — Expected: pass, no new errors.
- [ ] **Step 5: Mockup first:** show the owner the Forge window mockup (visual companion) before building its look;
  build to the picked one.
- [ ] **Step 6: Studio check** on PC and the landscape phone emulator: open, each tab, buttons >= 48 px, a forge.
- [ ] **Step 7: Commit** `git commit -m "Weapons: the Forge window"`

### Task 8: Direct drops, pity and the drop cinematic

**Files:**
- Modify: `src/shared/Util/BossRules.luau` (`Record.weaponPity: number`, read with `readCount`),
  `src/server/Services/BossService.luau` (the roll on full loot), `src/shared/Remotes.luau` (`WeaponDropped`,
  `WeaponAnnouncement`)
- Create: `src/client/Controllers/WeaponRevealController.luau` (Task 9 adds the forge reveal to it)
- Test: `tests/BossRules.spec.luau` (weaponPity read)

**Interfaces:**
- On each full-loot win of a boss whose `Config/Weapons` boss weapon is ready: roll `WeaponRules.dropChance(cfg,
  record.weaponPity)`; on a drop: `WeaponService.Give(player, id, BeastRules.rollGrade(roll, rarity), "drop")`, reset
  pity to 0, fire `WeaponDropped` `{ weaponId, grade, refund }` to the player and, for Epic and Legendary,
  `WeaponAnnouncement` (`displayName, weaponId, grade, userId`) to all; otherwise pity += 1. Carried group members
  never roll it (they get the quarter chances only, like fragments).
- `WeaponRevealController.Drop(payload)`: the cinematic on the pack-opening stage (`Util/OpeningStage` show/bars/flash/
  dim, the level-up pillar's light column in the rarity colour, the weapon's model rising and spinning with
  `WeaponLook` (Task 6) at its grade, its card (`WeaponFace`, Task 7) flipping to show the grade, the banner "<RARITY>! <Name>"; a
  refund shows "Already yours: +10 <material>"); about 6 s, skippable after 2 s by a tap; others nearby see the light
  column in the world; the announcement uses the toast bubbles.
- Studio command `/weapondrop <bossId>` (forces a drop through the same code).

- [ ] **Step 1: Write the failing test** (`weaponPity` read from saved data, missing -> 0, junk -> 0).
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the pity, the roll, the remotes and the controller; mockup the four frames first (the
  spec's storyboard was approved in principle; show the built look in a Studio screenshot before polishing).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Studio check:** `/weapondrop meadowWarden` twice (the second shows the refund), screenshots of each
  frame; Output clean.
- [ ] **Step 6: Commit** `git commit -m "Weapons: boss drops with pity and the drop cinematic"`

### Task 9: The forge reveal

**Files:**
- Modify: `src/client/Controllers/WeaponRevealController.luau` (`Forge(payload)`), `src/client/Controllers/ForgeController.luau`

**Interfaces:**
- `WeaponRevealController.Forge(result: ForgeResult)`: the pack-opening stage with the weapon rising out of an anvil
  glow (a code-built anvil and a glow disc), a 1.5 s build-up, then the grade flash: S gets the Legendary pull's hit
  (`Config/PackOpening` SOUNDS and flash), A the Epic's, B/C a small one; upgrades show the new +level badge popping
  with the glow layer it adds; a reforge that kept the old grade says "Kept your Grade S".

- [ ] **Step 1: Implement** and wire ForgeController to play it on `ForgeResult`.
- [ ] **Step 2: Run** `lune run tests/run`; diagnostics — Expected: pass, no new errors.
- [ ] **Step 3: Studio check:** a forge, a reforge, an upgrade to +4 (the aura appears); screenshots.
- [ ] **Step 4: Commit** `git commit -m "Weapons: the forge reveal"`

### Task 10: The Armory tab and weapon cards

**Files:**
- Modify: `src/client/Util/WeaponFace.luau` (made in Task 7: the locked and Coming soon faces),
  `src/shared/Config/Collection.luau` (`SETS` gains "Armory", its colour and emblem "⚔️"),
  `src/shared/Config/BinderCovers.luau` (an Armory cover, art made in Figma like the others),
  `src/client/Controllers/BinderController.luau` (the Armory set: its pockets from `Weapons.WEAPONS`, owned / locked /
  Coming soon faces, the weapon card view with Equip), `src/client/Controllers/CardInspectorController.luau` (show a
  weapon card)

**Interfaces:**
- `WeaponFace.render(frame: Frame, weaponId: string, owned: Owned?, progress: { have: number, need: number }?)`: owned:
  the portrait (`WeaponLooks[id].portrait`, or the weapon's name over its glow colour until the portrait exists), the
  rarity frame, element chip, grade, +level; locked: a dark silhouette, its source line ("Drops from the Meadow
  Warden", "Masterwork: three bosses' materials + Star Shards", "Forge: Wild Ore"), the progress bar; not ready:
  "Coming soon".
- The weapon card view: `WeaponText.stats` lines, Equip (fires `EquipWeapon`), "Upgrade at the Forge".

- [ ] **Step 1: Implement** WeaponFace's locked faces, the Armory set and the card view (cards stay the binder's; the Armory set
  draws weapons through WeaponFace instead of CardFace).
- [ ] **Step 2: Run** `lune run tests/run` (BinderSpreads/BinderCovers tests updated for the new set); diagnostics.
- [ ] **Step 3: Studio check** on PC and the phone emulator: the Armory tab, an owned card, a locked one with
  progress, Coming soon, Equip changes the back weapon; screenshots.
- [ ] **Step 4: Commit** `git commit -m "Weapons: the Armory tab and weapon cards"`

### Task 11: The Boss Board shows each boss's weapon

**Files:**
- Modify: `src/client/Controllers/BossBoardController.luau` (Rewards column), `src/server/Services/BossService.luau`
  (`BossesChanged` adds each boss's `weaponPity`), `src/client/Controllers/LootController.luau` (a weapon material's
  pickup toast adds its progress: "Warden Heartwood +2 (9/15)", the need from `WeaponRules.makeCost` of that boss's
  weapon, or of the next upgrade once it's owned)

**Interfaces:**
- The Rewards column adds the boss's weapon card (`WeaponFace`, small) with "Its material: Warden Heartwood (chance 80%
  with full loot)" and "Weapon drop chance now: 3.5%" (`WeaponRules.dropChance` with the sent pity).

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Run** `lune run tests/run`; diagnostics.
- [ ] **Step 3: Studio check:** the Bosses board for boss 1 and boss 7; phone layout.
- [ ] **Step 4: Commit** `git commit -m "Weapons: the Boss Board shows each boss's weapon"`

### Task 12: The four new swords (art)

**Files:**
- Create: `assets/blender/<Weapon>/` sources, `tools/blender/build_weapon_<id>.py` (cleanup per weapon on a shared
  `tools/blender/weapon_kit.py`: decimate to <= 4,000 triangles, the grip at the origin, the blade along the model's axis
  like `StarterSword`, named parts `Blade`, `Guard`, `Grip`, `Gem` where they exist), `assets/weapons/ForgeSword_<Element>.rbxm`,
  `VerdantBlade.rbxm`, `SunforgedBlade.rbxm`, `PrismBlade.rbxm`; portraits in `assets/ui/weapon-portraits` (ids in
  `Config/WeaponLooks`)
- Modify: `Config/WeaponLooks` (portrait ids, final colours), `docs/` (a `docs/weapons.md` pipeline note like
  `docs/creatures.md`)

Steps (owner in the loop; each pick shown as a mockup or render first):
- [ ] **Step 1: Concepts:** Figma image generator, two options per sword in the reference's style (stylized, ornate,
  glowing; no text), plus the Forge Sword base; show them in the visual companion; the owner picks one each.
- [ ] **Step 2: Meshy:** read the balance (number only); image-to-3D for each pick (4 generations); report the balance
  after; ask before any retry.
- [ ] **Step 3: Blender cleanup** with the kit (background Blender for builds; never the owner's open Blender); the
  Forge Sword's five element recolours (gem, trim); renders to the owner for approval; slim the blends (no `*_Src`,
  purge orphans, empty key fields) before committing.
- [ ] **Step 4: Owner imports** the FBX into Studio; finish with `lune run tools/weapons/finish_sword` (colours and
  pivots), save to `assets/weapons/`; check the WeaponModels sync.
- [ ] **Step 5a: Item icons:** the 8 new items' pictures on a Figma-generated icon sheet, cut with
  `tools/ui-icons/slice_icons.py`, uploaded, names into `Config/UIIcons` and `Config/Items` (replacing the emoji).
- [ ] **Step 5: Portraits:** each weapon rendered big in a ViewportFrame on magenta, captured with the Studio MCP, cut
  out (`tools/ui-art/cut_product_picture.py`), uploaded; ids into WeaponLooks.
- [ ] **Step 6: Studio check:** each sword in hand and on the back at +0 and +10, its Armory card; screenshots.
- [ ] **Step 7: Commit** `git commit -m "Weapons: Forge Sword, Verdant Blade, Sunforged Blade, Prism Blade models"`

### Task 13: Economy, docs and the round's checks

**Files:**
- Modify: `tools/economy/sim.luau` (the Forge Sword and upgrades to +5 on one boss weapon as a cash sink by the goal),
  `DESIGN.md` (a Weapons section: everything in this plan, the balance rows, the sim results, 10.2 files, 10.4 saves,
  13 backlog: rounds 2-3), `CLAUDE.md` (tests list: WeaponsConfig, WeaponRules, WeaponText, WeaponLookRules; dev
  commands /weapon, /material, /weapondrop)

- [ ] **Step 1: Run** `lune run tools/economy/sim 2000` before and after the sink — Expected: the goal time grows by
  less than 15% (report the numbers either way).
- [ ] **Step 2: Write** the docs.
- [ ] **Step 3: Run** `lune run tests/run`, `rojo build`, `rojo sourcemap default.project.json -o sourcemap.json` —
  Expected: all pass.
- [ ] **Step 4: Commit** `git commit -m "Weapons: economy check and docs"`
