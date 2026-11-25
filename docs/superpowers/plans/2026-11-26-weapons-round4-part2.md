# Weapons round 4, part 2: mutations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boss weapons drop almost every loot win; a drop of a weapon you own is a mutation roll (Common to Legendary)
you take or turn into Mutation Essence; the Forge's Mutate spends Essence; the weapon in your hand's mutation works in
fights and glows on the blade.

**Architecture:** Plain-data `Config/Mutations` and a pure `Util/MutationRules` (rolls, words, stats, Essence, the
choice) that both sides use. A weapon record gains `mutation` and `pending` (saved, v44). WeaponService owns offers and
the choice; BossService and ForgeService make offers. BattleSim reads per-owner mutation stats (`state.mutations`, like
`state.boosts`); BattleService sets them from the weapon in hand (never in the arena) and pays Treasure and Scholar.
The client draws the mutation row, the choice reveal, the blade's rim and the Forge's Mutate tab.

**Tech Stack:** Luau, Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for the check.

**Spec:** `docs/superpowers/specs/2026-11-25-weapons-round4-design.md` (Part 2), with the owner's approved mockups
(artifact SdPB6vGHJmV2US9QuDPcv7: the mutation row in layout A, the duplicate reveal, the Epic and Legendary blade).

## Global Constraints

- Server authoritative; every remote in `src/shared/Remotes.luau`, validated and rate-limited; never fail silently
  (`Util/Blocked`); dev commands Studio-only (DevService).
- All numbers in `src/shared/Config`; rules both sides use in Roblox-free `src/shared/Util` modules (Lune-tested; no
  Color3/Vector3 in configs a test reads).
- Saved data plain; shape change = `SCHEMA_VERSION` 44 + a `MIGRATIONS[43]` step + a test + DESIGN 10.4.
- Player words plain ASCII plus `·`; supers are "Ultimate" to players (tests/SkillText guard); the Prism's edge is
  "Super effective".
- One mutation per weapon; only the weapon in your hand counts; off in the arena; Treasure and Scholar at half and from
  fights only; no card luck; no copies of the weapons' own perks.
- Sizes 3 / 5 / 8 / 12 / 16% by rarity (placeholders until part 3's sims); Legendary twists: Tough's Second Wind, Pet
  Boost's Rally.
- Look as the mockups: the mutation row "Sharp · Epic mutation" / "Sword hits +12%." in its rarity colour with its
  group's icon (Sword, Shield, Heart); the reveal "MUTATION! Verdant Blade", "Epic · Sharp · sword hits +12%", the
  column in the rarity colour, "Yours now: Rare · Tough (your HP +5%)", Take new / Keep mine; the blade a rim in the
  rarity colour, Legendary also sparkles.

## Review Focus

1. A player who leaves (or crashes) with a choice waiting loses nothing: the offer is saved on the weapon and asked
   again on the next join.
2. A second offer for a weapon whose first is still waiting: the first resolves as Keep mine (its Essence given) before
   the new one waits.
3. A stale or forged choice (wrong id, someone else's weapon, an offer already answered) changes nothing.
4. The arena never sees a mutation (no `setMutation`, no Pet Boost on its fighters).
5. A fight with no mutation draws the same random numbers as before (crit rolls only when a chance exists).

---

### Task 1: Mutation rules, config and the Essence item

**Files:**
- Create: `src/shared/Config/Mutations.luau`, `src/shared/Util/MutationRules.luau`, `tests/MutationRules.spec.luau`
- Modify: `src/shared/Config/Items.luau` (item `mutationEssence`), `tests/run.luau` (register the spec)

**Interfaces:**
- Produces: `export type Mutation = { id: string, rarity: string }`;
  `export type Stats = { sword, crit, strong, boss, hp, taken, dodge, thorns, lifesteal, petAtk, petHp, meter, cash, xp, secondWind, rally: number }`;
  `MutationRules.roll(cfg, rarityRoll: number, kindRoll: number): Mutation`;
  `MutationRules.read(cfg, value: unknown): Mutation?`;
  `MutationRules.stats(cfg, mutation: Mutation?): Stats` (neutral: multipliers 1, chances and shares 0);
  `MutationRules.size(cfg, mutation): number` (a share, half for `half` entries);
  `MutationRules.essence(cfg, mutation: Mutation?): number` (0 for nil);
  `MutationRules.resolve(cfg, have: Mutation?, new: Mutation, take: boolean): (Mutation?, number)` (kept, Essence);
  `MutationRules.words(cfg, mutation): { name: string, title: string, line: string, short: string, yours: string, icon: string, group: string, rarity: string }`;
  `MutationRules.canMutate(cfg, weapons, weaponId: string, owned: { mutation: Mutation?, pending: Mutation? }?, essence: number): (boolean, string?)`.

Config values (plain data): `ODDS` Common .45, Rare .30, Very Rare .15, Epic .08, Legendary .02; `SIZE` .03 .05 .08
.12 .16; `HALF_SIZE` .02 .03 .04 .06 .08; `ESSENCE` 2 / 4 / 8 / 12 / 20; `MUTATE = { essence = 30 }`; `CRIT = 2`;
`GROUPS` offense Sword, defense Shield, support Heart; `LIST` in this order (id, name, group, stat, how, words):
sharp "Sharp" offense sword more "Sword hits +{n}%"; critical "Critical" offense crit add "{n}% chance a sword hit
deals double"; elementEdge "Element Edge" offense strong more "Strong sword hits +{n}%"; bossHunter "Boss Hunter"
offense boss more "Sword hits on bosses +{n}%"; tough "Tough" defense hp more "Your HP +{n}%" twist secondWind 0.3
"Second Wind: once a fight, heal 30% when low"; guard "Guard" defense taken less "You take {n}% less damage";
quickStep "Quick Step" defense dodge less "Dodge ready {n}% sooner"; thorns "Thorns" defense thorns add "{n}% of the
damage you take hits back"; lifesteal "Lifesteal" support lifesteal add "Heal {n}% of your sword damage"; petBoost
"Pet Boost" support pet more "Your creatures' ATK and HP +{n}%" twist rally 0.05 "Rally: teammates' creatures +5%
ATK"; ultimateCharge "Ultimate Charge" support meter more "Ultimates charge {n}% faster"; treasure "Treasure" support
cash more half "Fight cash +{n}%"; scholar "Scholar" support xp more half "Creature XP from fights +{n}%". `LOOK`:
rim transparency by rarity (Common .55 .. Legendary .15), Legendary sparkles (rate, size, lifetime).
Item `mutationEssence`: name "Mutation Essence", icon "Potion", description "Rolls a new mutation on a weapon.",
source "Boss drops of a weapon you have: the mutation you don't keep", use "At the Forge, open Mutate".

- [ ] **Step 1: Write the failing tests** (`tests/MutationRules.spec.luau`):
  "a roll's rarity follows the odds" (roll .0 Common, .44 Common, .46 Rare, .76 Very Rare, .91 Epic, .99 Legendary;
  kindRoll 0 -> sharp, .999 -> scholar); "every mutation has words a child reads" (`words` of sharp Epic: title
  "Sharp · Epic mutation", line "Sword hits +12%.", short "Epic · Sharp · sword hits +12%", yours "Epic · Sharp (sword
  hits +12%)", icon "Sword"; tough Legendary line "Your HP +16%. Second Wind: once a fight, heal 30% when low.";
  treasure Common line "Fight cash +2%."; every LIST entry's words ASCII, no "super"); "stats: neutral without a
  mutation, each stat by its rule" (sharp Epic sword 1.12; guard Rare taken 0.95; quickStep Epic dodge 0.88; critical
  Rare crit .05; petBoost Legendary petAtk 1.16, petHp 1.16, rally .05; tough Legendary hp 1.16, secondWind .3;
  scholar Epic xp 1.06); "Essence for the one you don't keep" (resolve take new from Rare tough: kept new, Essence 4;
  keep mine: kept old, Essence of the new; no old: kept new, 0); "a saved mutation is read only when it's known"
  (unknown id, unknown rarity, non-table -> nil); "Mutate: owned, not the Steel Sword, nothing waiting, enough
  Essence" (reasons "Not yours", "The Steel Sword can't mutate", "Choose your waiting mutation first", "Need 30 Mutation
  Essence"); "the Essence item's words" via ItemRules' existing word checks still passing.
- [ ] **Step 2: Run `lune run tests/run`** — Expected: MutationRules fails (module missing).
- [ ] **Step 3: Implement Config/Mutations, Util/MutationRules, the item.**
- [ ] **Step 4: Run `lune run tests/run`** — Expected: all pass.
- [ ] **Step 5: Commit** "Mutations: the list, the rules, Mutation Essence".

### Task 2: Mutations saved on weapons, offers and the choice

**Files:**
- Modify: `src/shared/Util/WeaponRules.luau` (`Owned` gains `mutation: Mutation?`, `pending: Mutation?`; `read` keeps
  them through `MutationRules.read` given `mutations` cfg; `give` "drop" of an owned weapon returns `(nil, 0)`),
  `src/shared/Config/Weapons.luau` (drop `DUPLICATE_MATERIAL`), `src/shared/Config/Data.luau` (44),
  `src/server/Util/Migrations.luau` (`[43]` no-op), `src/server/Services/WeaponService.luau`,
  `src/shared/Remotes.luau` (`ChooseMutation`), `tests/WeaponRules.spec.luau`, `tests/Migrations.spec.luau`
- **Interfaces:** `WeaponRules.read(cfg, saved, equipped, mutations?)`; `WeaponService.Offer(player, weaponId, mutation:
  Mutation, source: "drop" | "forge"): Offer?` where `Offer = { id: string, weaponId, mutation, have: Mutation?, applied:
  boolean, essence = { take: number, keep: number } }`; `WeaponService.SetMutation(player, weaponId, mutation?)` (dev);
  `WeaponService.MutationStats(player): MutationRules.Stats` (the weapon in hand's; the lent prologue weapon: none);
  `WeaponService.Pending(player): { Offer }`; remote `ChooseMutation(weaponId: string, offerId: string, take: boolean)`;
  `WeaponsChanged` snapshot carries `mutation` and `pending` per weapon; the character attribute `SwordMutation` (rarity
  or nil).
- [ ] Step 1: tests — "loading keeps a known mutation and a waiting one, drops unknown ones"; "a drop of a weapon you
  have gives nothing by itself (its mutation roll is the caller's)"; Migrations "v44 (mutations): weapons come through
  as they were".
- [ ] Step 2: run, watch them fail. Step 3: implement (offer: no mutation yet -> applied at once; else saved as
  `pending` with a fresh offer id; a newer offer resolves the older as Keep mine first; the choice checks the id and
  that it waits, then `MutationRules.resolve`, Essence through ItemService). Step 4: run, all pass. Step 5: commit
  "Mutations: saved on the weapon, offers and the choice".

### Task 3: Near-guaranteed drops, material every win, mutation rolls

**Files:**
- Modify: `src/shared/Config/Weapons.luau` (`DROP` Rare .95, Very Rare .92, Epic .88, Legendary .85, step .15;
  `MATERIAL_EVERY_WIN` Rare 2, Very Rare 2, Epic 1, Legendary 1), `src/shared/Util/ChestRules.luau` (`mine` always
  carries the material count: the weights' count + bonus + every-win; a weapon chest keeps `item`/`count`),
  `src/server/Services/BossChestService.luau` (gives the material whenever `mine.count`),
  `src/server/Services/BossService.luau` (`GiveWeapon`: owned -> `WeaponService.Offer(..., "drop")`, payload carries
  `offer`), `src/client/Controllers/BossChestController.luau` (a weapon chest's card shows its material line),
  `tests/ChestRules.spec.luau`, `tests/WeaponRules.spec.luau`
- [ ] Steps: tests first ("drops come almost every loot win, rarer a little less: 95 / 92 / 88 / 85%, sure by the
  second", "your chest always holds the material: a weapon's too", the old medians test replaced with the ruling),
  watch them fail, implement, all pass, commit "Mutations: boss weapons almost every win, material every win, rolls on
  a weapon you have".

### Task 4: Mutations in fights

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (`state.mutations`; `BattleSim.setMutation(state, owner, stats?)`; `hit`:
  a player's sword hit x sword, x strong on a strong hit, x boss on a boss, crit chance added to Haggle's (rolled only
  when > 0), lifesteal heals the player (event `{ type = "regen", kind = "Lifesteal", to, heal }`); `hurtPlayer`
  (optional `from`): x taken, thorns back at `from` (event `{ type = "thorns", from, to, damage }`), Second Wind once
  under 30% (event `{ type = "regen", kind = "SecondWind", to, heal }`); `dodge` x dodge; `fillMeter` x meter),
  `src/server/Services/BattleService.luau` (at fight start each member's stats; Tough's HP on the player input; Pet
  Boost on that owner's creature inputs (not in `fighterInput`, which the arena shares); Rally on other members'
  creatures; the swap hook re-sets the stats; `payOut` cash x cash (shop XP from the cash before it) and creature XP x
  xp), `tests/BattleSim.spec.luau`
- [ ] Steps: tests first ("Sharp makes a sword hit bigger", "Critical doubles some hits and marks them", "Element
  Edge only on strong hits", "Boss Hunter only on bosses", "Guard and Thorns", "Lifesteal heals the player",
  "Quick Step's dodge comes back sooner", "Ultimate Charge fills the meter faster", "Second Wind once", "no mutation:
  the same fight as before" (same seed, same events)), watch fail, implement, pass, commit "Mutations: in fights".

### Task 5: Words, the weapon window's row, the switch tip

**Files:**
- Modify: `src/shared/Util/WeaponText.luau` (`rows(cfg, hud, looks, combat, weaponId, owned, mutations?)` adds
  `{ kind = "mutation", icon, title, words, rarity }` last; a waiting one `{ kind = "pending", icon = "Sparkle", title =
  "New mutation waiting!", words = "Choose it from the Armory or the next reveal." }`; `stats(cfg, weaponId, owned,
  combat, mutations?)` adds `{ label = "Mutation", value = "Epic Sharp: sword hits +12%" }`),
  `src/shared/Util/WindowRow` type kinds, `src/client/Controllers/WeaponDetailController.luau` (the mutation row tinted
  by its rarity colour, fill and edge as the mockup; a pending row's tap replays its choice),
  `src/client/Controllers/WeaponSwitchController.luau` (passes Config/Mutations), `tests/WeaponText.spec.luau`
- [ ] Steps: tests first ("the mutation row: its group's icon, 'Sharp · Epic mutation', 'Sword hits +12%.'", "the tip
  names the mutation"), fail, implement, pass, commit "Mutations: the weapon window's row and the tip".

### Task 6: The reveal with its choice, the blade's glow

**Files:**
- Modify: `src/client/Controllers/WeaponRevealController.luau` (`Reveal` gains `mutation`; a mutation reveal: banner
  "MUTATION! <weapon>" in the rarity colour, the line under it `short`, the column in the rarity colour, the model with
  the new rim, then a panel: "Yours now: <yours>", two buttons with two lines each ("Take new" over "+<n> Essence",
  "Keep mine" over "+<n> Essence"), "The one you don't keep turns into Mutation Essence"; no mutation yet: "Your first
  mutation on this weapon!" and "Nice!"; no skip while choosing; sends `ChooseMutation`; pending offers from
  `WeaponsChanged` after a join are asked once each), `src/client/Util/WeaponLook.luau`
  (`WeaponLook.mutation(model, rarity?)`: a Highlight rim on the model only, Legendary sparkles on the blade),
  `src/client/Controllers/SwordController.luau` (reads `SwordMutation`, rebuilds on change)
- [ ] Steps: compile-check, Studio: `/mutation offer Epic` shows the choice; Take new and Keep mine each change the
  Armory and the Bag's Essence; the held blade's rim; commit "Mutations: the reveal and the blade's glow".

### Task 7: The Forge's Mutate

**Files:**
- Modify: `src/server/Services/ForgeService.luau` (remote `MutateWeapon(shelfUid, weaponId)`: at your Forge,
  `MutationRules.canMutate` else `Blocked.tell`, take the Essence, roll, `WeaponService.Offer(..., "forge")`, the
  client gets the offer as a reveal), `src/shared/Remotes.luau`, `src/client/Controllers/ForgeController.luau` (a
  Mutate tab on the picture recipe: "Use 30 Mutation Essence to give your Verdant Blade a new mutation!", the Essence
  spot, the weapon's card with its mutation under it, the button "Mutate" over "Instant"), `src/shared/Util/WeaponText`
  (`tabLine` Mutate), `tests/WeaponText.spec.luau`
- [ ] Steps: test the tab line and the sentence first, fail, implement, pass, Studio check, commit "Mutations: the
  Forge's Mutate".

### Task 8: Dev commands, the balance tool, docs, the Studio check

**Files:**
- Modify: `src/server/Services/DevService.luau` (`/mutation <weapon id> <mutation id> <rarity>`, `/mutation offer
  [rarity]` on the weapon in hand, `/mutation clear`), `src/shared/Config/AdminPanel.luau` (section "Mutations"),
  `tools/balance/bosses.luau` (`MUTATION="<id>:<rarity>"` for every player), `DESIGN.md` (5.11 "Mutations", 10.4 v44,
  the task line), `CLAUDE.md` (commands, tests), memory and both vaults.
- [ ] Steps: run the sim with and without a typical (Rare) and the best (Legendary Sharp / Tough) mutation and write
  the numbers in DESIGN; Studio check (window row, reveal both ways, Forge tab, glow, a boss fight with Sharp, the
  Output clean); commit "Mutations: dev commands, the balance option, docs".
