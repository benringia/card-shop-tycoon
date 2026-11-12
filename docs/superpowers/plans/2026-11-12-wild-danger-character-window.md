# Wild Danger, Defense, Character Window and Element Names Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Wild's dangerous places hurt the player, Defense from party Power softens every hit on a player (bosses
included, rebalanced), a character window (Stats / Elements / Titles) shows your strength, and elements read Fire,
Water, Nature, Electric, Dark with image icons.

**Architecture:** Pure rules in `src/shared/Util` (Lune-tested): `ElementNames`, `DefenseRules`, `DangerRules`,
`TitleRules`, `CharacterStats`. The fight sim scales hits on a player by a per-fighter `defenseScale` BattleService
computes; WildService/BattleService handle contact, sword-only fights and knockouts; a new `TitleService` owns the
equipped title; the client gets `CharacterController` (window) and `Util/CharacterStage` (3D avatar).

**Tech Stack:** Luau, Rojo, Lune tests (`lune run tests/run`), Studio MCP checks, `tools/balance/bosses` and
`tools/balance/wild`.

**Spec:** `docs/superpowers/specs/2026-11-12-wild-danger-character-window-design.md`

## Global Constraints

- Launch 2026-11-20; work on `main`, uncommitted until the owner's OK (CLAUDE.md: "After I confirm a system works ...
  commit, and push"). Ledger: `.superpowers/sdd/2026-11-12-wild-danger-character-window/progress.md`.
- Server authoritative; every remote in `src/shared/Remotes.luau`, validated and rate-limited (`Util/RateLimiter`).
- All tunable numbers in `src/shared/Config`; pure modules don't require siblings (no `script` in Lune).
- Never fail silently: refusals through server `Util/Blocked`.
- Text: plain ASCII plus `·` and emoji only; element icons are images (`Config/UIIcons` Ember/Tide/Bloom/Volt/Shade,
  client `Util/Icon.make`).
- Saved data keeps the internal element keys; changing the saved shape bumps `Config/Data.SCHEMA_VERSION` (19 -> 20)
  with a `Migrations` step and test, DESIGN 10.4.
- BattleController is at Luau's 200-local limit: new UI in its own modules, no new file-level locals there (group into
  an existing table or a module).
- Mobile-first (48 px taps); windows via `UIKit.panel` (cotton candy).
- Client files: compile-check with the scratchpad `compile_check.luau` (Lune never parses `src/client`).

## Review Focus

1. An empty or partly empty party (0-2 cards) gives Defense from what's there and never divides by zero (0 -> the
   weakest scale, 1.5). Test in Task 2.
2. A title that isn't earned (a tampered remote) or no longer exists (a removed config row) never shows: refused, or
   the automatic pick. Tests in Task 7.
3. Contact while the player is already fighting, locked, or in a calm zone changes nothing from today. Test in Task 4
   (`DangerRules.onContact`).
4. An unknown element key (`"None"` for a player fighter, nil) never errors in `ElementNames`: it reads back as given.
   Test in Task 1.
5. A knockout only follows a lost wild fight in a dangerous place; boss and Dungeon losses keep their own flow. Test in
   Task 4 (`DangerRules.knockout`).

---

### Task 1: Element names and icons everywhere players read them

**Files:**
- Create: `src/shared/Config/ElementNames.luau`, `src/shared/Util/ElementNames.luau`, `tests/ElementNames.spec.luau`
- Modify: `src/shared/Util/WeaponText.luau:76,364`, `src/shared/Config/Weapons.luau:56,121,188`,
  `src/client/Controllers/CardBuyController.luau:221`, `src/client/Controllers/ShowcaseController.luau:259,553`,
  `src/client/Controllers/ForgeController.luau:525`, `src/client/Controllers/BossBoardController.luau:736`,
  `src/client/Controllers/BattleController.luau` (the `elementIcon` emoji: crest, bar names, adds/enemy rows, the
  "{kind} phase!" banner), `src/client/Util/CombatHud.luau` (perk chip icon), binder element filter labels if any,
  `tests/run.luau`, `tests/WeaponText*.spec` / `tests/WeaponsConfig.spec.luau` where they assert old names
- Test: `tests/ElementNames.spec.luau`

**Interfaces:**
- Produces: `ElementNames.display(key: string?, cfg): string` (unknown or nil -> the key or ""),
  `ElementNames.all(cfg): { string }` (keys in wheel order). Config: `{ Ember = "Fire", Tide = "Water", Bloom = "Nature",
  Volt = "Electric", Shade = "Dark", ORDER = { "Ember", "Bloom", "Tide", "Volt", "Shade" } }`.

- [ ] **Step 1: Write the failing test** `tests/ElementNames.spec.luau`:
  `["every element has its plain name"]`: display("Ember") == "Fire", "Tide" == "Water", "Bloom" == "Nature",
  "Volt" == "Electric", "Shade" == "Dark"; display("None") == "None"; display(nil) == "".
  `["weapons and their text use the plain names"]`: `Weapons.ById.forgeSword_Ember.name == "Fire Forge Sword"`;
  `WeaponText` line for an Ember weapon contains "Fire" and "bonds with Fire creatures", not "Ember".
  `["no player text shows a raw element key"]`: a source scan of `src/client` and `src/shared/Util` (Lune `fs`, like
  `tests/SourceOrder`) finds no template interpolating `.element}` or `{event.kind} phase` outside `ElementNames`
  calls, and no `Party.PERKS[...].icon` use in `BattleController`.
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL ("could not resolve child component \"ElementNames\"").
- [ ] **Step 3: Implement** the config and `ElementNames`; route every site in Files through `display`; weapon
  names built from the display name (ids keep `_Ember`). In BattleController replace the emoji with `Icon.make` image
  icons (the plate crest an ImageLabel; bar and row names an icon beside the text in a horizontal list); the banner reads
  "Fire phase!" without an emoji. CombatHud's perk chip shows the element's image icon.
- [ ] **Step 4: Run** `lune run tests/run` and compile-check the touched client files — Expected: all PASS / compiles.
- [ ] **Step 5: Ledger** `Task 1: complete (tests: lune run tests/run -> N passed)`.

### Task 2: Defense rules and the sim's hit scale

**Files:**
- Create: `src/shared/Util/DefenseRules.luau`, `tests/DefenseRules.spec.luau`
- Modify: `src/shared/Config/Combat.luau` (add `DEFENSE = { min = 0.5, max = 1.5, partySize = 3 }`),
  `src/server/Util/BattleSim.luau` (`FighterInput.defenseScale: number?`, kept on the fighter; `hurtPlayer` multiplies
  `amount` by it), `tests/BattleSim.spec.luau`, `tests/run.luau`

**Interfaces:**
- Produces: `DefenseRules.defense(powers: { number }): number` (sum, empty -> 0);
  `DefenseRules.reference(recommended: number, cfg): number` (`cfg.DEFENSE.partySize * recommended`);
  `DefenseRules.scale(defense: number, reference: number, cfg): number` (`clamp(reference / defense, min, max)`,
  defense <= 0 -> max); `DefenseRules.zoneBoss(bosses, place: string, zone: number): string?` (the ladder boss whose
  `place` and `zone` match: the reference for a Wild or Frontier zone, whose own `recommended` is a level, not Power).
- Consumes: nothing.

- [ ] **Step 1: Write the failing tests:** `DefenseRules.spec`: defense({1000, 600, 600}) == 2200; defense({}) == 0;
  reference(2400) == 7200; scale(7200, 7200) == 1; scale(14400, 7200) == 0.5; scale(3600, 7200) == 1.5 (clamped from 2);
  scale(0, 7200) == 1.5; zoneBoss(Bosses, "Wild", 3) == "emberColossus"; zoneBoss(Bosses, "Frontier", 3) ==
  "riftDevourer" (check the real ids/places in Config/Bosses). `BattleSim.spec`
  `["a player's defenseScale scales the hits on them"]`: two identical boss fights with a player fighter at
  defenseScale 0.5 and 1.5 (use `bossFightWithPlayer` with a fixed `playerAttacks`), run 20 s, the 0.5 player's
  `taken` is about a third of the 1.5 player's (ratio within 0.25-0.45); no `defenseScale` behaves as 1.
- [ ] **Step 2: Run** — Expected: FAIL (module missing; field ignored).
- [ ] **Step 3: Implement** `DefenseRules` and the sim field.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: PASS.
- [ ] **Step 5: Ledger.**

### Task 3: Defense in every fight (wild and boss)

**Files:**
- Modify: `src/server/Services/BattleService.luau` (player fighter input in `startFight`: `defenseScale`), a helper
  `partyPowers(player): { number }` using `CardService.GetBeast` + `BeastRules.getPower` over the party slots (resting
  cards count), `tests/BossRules.spec.luau` or `tests/DefenseRules.spec.luau` for the reference choice

**Interfaces:**
- Consumes: Task 2's `DefenseRules`.
- Produces: `DefenseRules.referenceFor(boss: any?, bosses, place: string, zone: number?, cfg): number?` — a boss
  fight's `3 x boss.recommended`; a wild fight's zone boss's; nil (scale 1) where neither exists (the Dungeon's rooms).

- [ ] **Step 1: Failing test** `["the reference: a boss's own, a zone's boss's, none for a Dungeon room"]` on
  `referenceFor`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** `referenceFor` and set `defenseScale = DefenseRules.scale(defense(partyPowers(player)),
  reference, Combat)` on each member's player fighter (`@owner`); a nil reference leaves it unset.
- [ ] **Step 4: Run tests** — PASS; Studio: `/boss 1 fight` with `/level` low party vs high party shows smaller/larger
  hit numbers on you.
- [ ] **Step 5: Ledger.**

### Task 4: Wild danger — contact, sword-only fights, knockout

**Files:**
- Create: `src/shared/Util/DangerRules.luau`, `tests/DangerRules.spec.luau`
- Modify: `src/shared/Config/Wild.luau` (zone 3 Ember Ridge `danger = true`; KNOCKOUT and SHOVE numbers),
  `src/shared/Config/Frontier.luau` (all three zones `danger = true`), `src/server/Services/BattleService.luau`
  (`WildService.OnContact` handler; a sword-only `startFight` option `swordOnly`: side a = the player fighter only,
  no leader creature, no card XP in `payOut`; `endFight`: a lost wild fight in a danger zone knocks out),
  `src/server/Util/BattleSim.luau` only if a player-only side doesn't already lose when its player is down,
  `src/server/Util/Blocked.luau` + `src/client/Controllers/BlockedController.luau` (optional `title`/`icon` in the
  payload: "Knocked out!" 💫), `src/shared/Remotes.luau` (Blocked doc), `tests/BattleSim.spec.luau`

**Interfaces:**
- Consumes: Task 3's defense on the player fighter.
- Produces: `DangerRules.onContact(s: { fighting: boolean, locked: boolean, danger: boolean, summoned: boolean,
  summonedRested: boolean, restedSlot: number?, hasSword: boolean }): ("none" | "fight" | "summon" | "swordOnly" |
  "shove", number?)` — calm zone or busy: "none" (today's `tryStart` path stays for calm zones: "fight" when it would
  start today); danger: summoned and rested -> "fight"; else a rested slot -> "summon", slot; else sword -> "swordOnly";
  else "shove". `DangerRules.knockout(result: string, danger: boolean, boss: boolean, run: boolean): boolean` — true
  only for "lose" in a danger zone, not a boss, not a Dungeon run.

- [ ] **Step 1: Failing tests:** every `onContact` branch above, including `fighting = true` -> "none" and a calm
  zone -> today's behaviour; `knockout` true only for ("lose", danger, not boss, not run). BattleSim
  `["a sword-only fight: the player alone, lost when they're down"]`: side a = `playerInput("1")` only, a monster that
  hits players; run until result; result == "b" and the player was down.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** Contact: "summon" calls `PartyService.SummonSlot(player, slot)` then `tryStart`;
  "swordOnly" starts with `{ swordOnly = true }`; "shove" pushes the character back from the monster
  (`Wild.SHOVE.speed` on its root, server) and `Blocked.tell(player, "Your creatures are resting! The Wild is
  dangerous.")`. Knockout: after `BattleEnded`, fade (client card) and move the character to the spring (main game
  `Wild.SPRING` + `Wild.KNOCKOUT.offset`; the Frontier its entrance spring, the same one `whyNotPlayer` names), the
  monster healed at home (`WildService.Unlock` + its HP reset as today's loss).
- [ ] **Step 4: Run tests** — PASS. Studio: Ember Ridge (`/wild`, walk there) with resting cards (`/tire`) and a
  sword: an elite catches you -> sword-only fight; lose it -> "Knocked out!" and the plaza spring; in the Meadow the
  same contact does what it did before.
- [ ] **Step 5: Ledger.**

### Task 5: Scare cues

**Files:**
- Modify: `src/server/Services/WildService.luau` (marker attribute `ChasingUserId` while a monster chases a player in
  a danger zone; cleared on give-up/contact), `src/client/Controllers/MonsterController.luau` (a red "!" billboard over
  a monster chasing you + one growl, `Config/Wild.CHASE_CUE` sound id and volume), the trailhead sign
  (`WildService` `TrailProps.trailhead` text) adds "DANGER" under the level line for danger zones.

**Interfaces:**
- Consumes: Task 4's `danger` flags.
- Produces: nothing for later tasks.

Ruling (ledger it): the spec's "zone name card" doesn't exist; the trailhead sign carries "DANGER" instead.

- [ ] **Step 1:** Implement; compile-check; Studio: an Ember Ridge monster chasing you shows "!" once and growls; the
  Ember Ridge trailhead reads DANGER; the Meadow's doesn't.
- [ ] **Step 2: Ledger.**

### Task 6: Boss rebalance with Defense

**Files:**
- Modify: `tools/balance/bosses.luau` (each simulated party's player fighter gets `defenseScale` from its cards'
  Powers vs `3 x boss.recommended`), `tools/balance/wild.luau` (the same vs the zone boss), `src/shared/Config/Bosses.luau`
  (retuned numbers), `tests/SwordsConfig.spec.luau` / `tests/BossRules.spec.luau` rows that pin changed numbers

**Interfaces:**
- Consumes: Task 2's `DefenseRules`.

- [ ] **Step 1:** Run `lune run tools/balance/bosses 300 1` before the tool change; save the table to the ledger.
- [ ] **Step 2:** Teach the tool Defense; rerun.
- [ ] **Step 3:** Retune each ladder boss and the Prism Hydra toward the targets (fighting well: 85% at 1x, 50% at 0.8x;
  standing still: 60% / 15%), changing only `atk` or `playerAttacks.big/quick` per boss; rerun until each row is within
  ±10 points; record before/after per boss in the ledger and DESIGN.
- [ ] **Step 4:** `lune run tools/balance/wild 200 both`: Ember Ridge and the Frontier zones stay winnable fighting well
  (~90%); if not, adjust `Combat.DEFENSE` or the zone's monster numbers and note it.
- [ ] **Step 5:** `lune run tests/run` — PASS (update pinned numbers with the owner's 2026-11-12 reason). Ledger.

### Task 7: Titles

**Files:**
- Create: `src/shared/Config/Titles.luau`, `src/shared/Util/TitleRules.luau`, `src/server/Services/TitleService.luau`,
  `tests/TitleRules.spec.luau`
- Modify: `src/shared/Config/Data.luau` (SCHEMA_VERSION 20; template `title = ""`), `src/server/Util/Migrations.luau`
  (`[19]`: `data.title = if typeof(data.title) == "string" then data.title else ""`), `tests/Migrations.spec.luau`,
  `src/server/Services/BossService.luau` (drop `setTitle`; expose `BossService.Cleared(player, bossId): boolean`,
  keep `SecretFound`; `BossService.OnProgress(callback)` fired where `setTitle` was called),
  `src/shared/Util/BossRules.luau` (remove `pickTitle`; its tests move to TitleRules), `src/shared/Remotes.luau`
  (`Titles`: server -> client `{ earned = { id }, equipped = id }`, client -> server `()` ask; `EquipTitle`: client ->
  server `(id: string)`, "" for automatic), `src/server/init.server.luau` (start TitleService after BossService)

**Interfaces:**
- Produces: Config `{ ORDER = { "dungeonConqueror", "crystalSeeker" }, ById = { dungeonConqueror = { name = "Dungeon
  Conqueror", color = {...}, how = "Clear the Prism Hydra", check = { kind = "bossClear", boss = "prismHydra" } },
  crystalSeeker = { name = "Crystal Seeker", color = {...}, how = "Find the Dungeon's secret chest", check = { kind =
  "secret" } } } }`; `TitleRules.earned(cfg, progress: { cleared: { [string]: boolean }, secret: boolean }): { string }`
  (cfg order); `TitleRules.shown(cfg, equipped: string, earned: { string }): string?` (the equipped one if earned, else
  the first earned, else nil); `TitleRules.canEquip(id: string, earned): boolean` ("" always true).
  Player attribute `Title` keeps its meaning (the shown title's name).

- [ ] **Step 1: Failing tests:** earned/shown/canEquip (an unearned id refused; a removed id falls back to the first
  earned; "" = automatic = today's pick: Dungeon Conqueror before Crystal Seeker); Migrations `[19]` adds `title = ""`
  and keeps a string.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** (TitleService registers with `DataService.Register`; `save` does nothing if `load` never ran;
  `EquipTitle` rate-limited, validated with `canEquip`, refusals via `Blocked.tell`).
- [ ] **Step 4: Run tests** — PASS; Studio: `/tutorial` save at schema 20 loads; equipping changes the name tag.
- [ ] **Step 5: Ledger.**

### Task 8: The character window

**Files:**
- Create: `src/shared/Util/CharacterStats.luau`, `tests/CharacterStats.spec.luau`,
  `src/client/Util/CharacterStage.luau` (a ViewportFrame with a clone of the player's character holding the equipped
  weapon's model, slow drag-to-turn, soft light, podium), `src/client/Controllers/CharacterController.luau`,
  `src/shared/Config/CharacterWindow.luau` (sizes, tab names, the stats' one-line texts, tile spec)
- Modify: `src/client/Controllers/WeaponSwitchController.luau` (`GetState(): { owned, equipped }`),
  `src/client/init.client.luau` (start CharacterController), `tests/run.luau`

**Interfaces:**
- Consumes: Task 1 `ElementNames`, Task 2 `DefenseRules.defense`, Task 7 `Titles` / `EquipTitle` remotes.
- Produces: `CharacterStats.compute(partyPowers: { number }, weaponPower: number): { power: number, attack: number,
  defense: number }` (power = max of the party's, 0 for none; attack = weaponPower; defense = DefenseRules-style sum —
  duplicate the one-line sum, pure modules don't require siblings).

- [ ] **Step 1: Failing test** `CharacterStats.spec`: compute({2614, 1200, 900}, 1240) == { power = 2614, attack =
  1240, defense = 4714 }; compute({}, 0) == { 0, 0, 0 }.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** Window (`UIKit.panel`, title "{DisplayName} · Lv {level}"): left the stage; right three
  tabs — **Stats** (Power, Attack, Defense, one line each), **Elements** (the three party cards with element icons and
  plain names; Fire beats Nature, Nature beats Water, Water beats Fire, Electric and Dark beat each other; "Strong: 1.5x
  damage · Weak: 0.75x" from `Combat.STRONG/WEAK`), **Titles** (rows from `Titles` remote: earned bright with Equip /
  Equipped, locked greyed with `how`; an "Automatic" row); bottom the weapon card (picture from `WeaponLooks`
  portrait, name, grade, level, plain element, skill name). Phone: the stage above the tabs. HUD: `Hud.tile` "Me" (the
  player's headshot via `Players:GetUserThumbnailAsync`, fallback icon), in every place.
- [ ] **Step 4: Run tests + compile-check** — PASS. Studio screenshots of each tab, desktop and the phone emulator.
- [ ] **Step 5: Ledger.**

### Task 9: Docs and final check

**Files:** `DESIGN.md` (a Wild danger / Defense / character window / element names / titles section, data 10.4 schema
20), `CLAUDE.md` (test list: ElementNames, DefenseRules, DangerRules, TitleRules, CharacterStats), memory + Obsidian.

- [ ] **Step 1:** Write the docs; `lune run tests/run`; `rojo build` all three projects — PASS.
- [ ] **Step 2:** Studio pass over every task's check; report to the owner; commit and push only after their OK.
