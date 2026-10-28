# The Dungeon and the Final Boss Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a third place, the Dungeon, entered from the Frontier: three rooms of elite packs with HP carried between
them, then the Prism Hydra (5 element phases), its blocky rigged model, and the conquest moment.

**Architecture:** the pure parts are Lune-tested:
- boss phases in `BattleSim` / `BossRules`;
- the run rules in a new `Util/DungeonRules`;
- all numbers in a new `Config/Dungeon` and in `Config/Bosses`.

Server code runs by place:
- **Frontier:** `DungeonGateService` checks entry and teleports a solo player or group into a reserved Dungeon server.
- **Dungeon:** `DungeonService` builds the cavern (`Util/DungeonBuilder`) and runs the rooms through `BattleService`
  (new: monster packs, carried HP, HP reported at fight end). It hands the chamber fight to `BossService`
  (new: `StartRun`).

On the client:
- `DungeonController` shows the run's progress;
- `BattleController` shows the phases and the conquered screen;
- `MonsterController` animates the boss rig;
- `TitleController` draws titles in every place.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Blender MCP for the model,
Roblox Studio MCP for Play checks.

**Spec:** `docs/superpowers/specs/2026-10-29-dungeon-final-boss-design.md` (builds on
`docs/superpowers/specs/2026-10-28-boss-ladder-design.md` and DESIGN.md 5.10).

## Global Constraints

- Server authoritative. Every remote is in `src/shared/Remotes.luau`. Each one validates its args and is rate-limited
  with `server/Util/RateLimiter`.
- All tunable numbers live in `src/shared/Config`; services hold no magic numbers. Pure rules go in Roblox-free
  modules with Lune tests, and new spec files are registered in `tests/run.luau`.
- `--!strict`. SourceOrder test: no local used above its definition, no module used without a require.
- Dungeon place id `79143483483478` (`Config/Places.DUNGEON_PLACE_ID`). Port 34874 for `dungeon.project.json`;
  Workspace attribute `PlaceKind = "Dungeon"`.
- Prism Hydra numbers:
  - id `prismHydra`, title "Crown of Every Element", place `"Dungeon"`, ladder index 7;
  - shop level 22, unlocked by 10 `fragment_prismHydra`, recommended Power about 2400, level about 55.
- Phases: 100-80% Tide shield, 80-60% Volt thunderclap, 60-40% Shade adds, 40-20% Bloom heal, under 20% Ember enrage.
- Balance targets (solo, after the three rooms):
  - best+2 (one card at recommended Power, two at 60%) wins about 50-60%;
  - maxed+2 (one maxed card, two Lv 1) wins at most about 50%;
  - three cards at recommended Power win about 75-85%;
  - three maxed win at most about 90%.
- Room target: the recommended party reaches the Hydra with about two thirds of its HP.
- Rooms: packs of 2-3 elites from Frontier species at Lv 45-50. A room win pays normal elite XP and cash, with no
  cards and no items.
- A fainted group member stays in the fight until it ends, then is out of the run (back to the Frontier). Fragments
  are taken only when the Hydra fight first starts.
- UI text: ASCII plus `·` and emoji only. Tap targets at least 48px. Boss music stays `Bosses.MUSIC_ID` at volume
  0.1.
- No new saved shape. The title comes from `bosses.prismHydra.cleared`.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Work on branch `dungeon-phase4`. The
  user approves in Studio before any merge.

## Review Focus

1. The Bloom phase heals the Hydra back above 40%. The phase must never step back; phases only advance. Pinned in
   Task 2: "phases never go back after a heal".
2. A creature that fainted in room 1 has its normal 3 minute rest expire before room 3. It must still stay out for
   the rest of the run. Pinned in Task 3 (`canFight` with hp 0) and Task 6 (BattleService skips hp-0 cards even when
   rested).
3. Teleport data is missing (Studio), garbage, or claims 50 players. The expected run size must be clamped to
   1..`Bosses.GROUP_MAX`. Pinned in Task 3: "expectedSize clamps and survives junk".
4. The player who leads a room disconnects mid-fight. The room fight goes on for the others, and the run never
   waits for them. Pinned in Task 8 as a Studio Local Server check.
5. The fragments are gone between the portal and the boss (spent, or a stale record). The Hydra start must refuse
   with the usual "Needs 10 ..." message and not crash the run. Pinned in Task 9: `StartRun` reuses `whyNotMember`;
   Studio check with 0 fragments.

---

### Task 1: Config: the Hydra, its items, `Config/Dungeon`, the Dungeon place

**Files:**
- Modify: `src/shared/Config/Bosses.luau` (type, LADDER, `prismHydra`, `riftDevourer` fragment drop and first clear)
- Modify: `src/shared/Config/Items.luau` (`fragment_prismHydra`, `trophy_prismHydra`, following the other fragments and trophies)
- Modify: `src/shared/Config/Places.luau` (`DUNGEON_PLACE_ID = 79143483483478`)
- Modify: `src/shared/Config/Town.luau` (`TROPHY_LOOK` entry for `trophy_prismHydra`: a prism-coloured gem)
- Create: `src/shared/Config/Dungeon.luau`
- Test: `tests/BossRules.spec.luau`, new `tests/Dungeon.spec.luau` (register in `tests/run.luau`)

**Interfaces:**
- Produces:
  - `Boss.place: "Wild" | "Frontier" | "Dungeon"`.
  - `Boss.phases: { BossPhase }?` with `export type BossPhase = { below: number, element: string, mechanics: Mechanics }`. Each phase is active while HP share `< below`; the first has `below = 1`.
  - `Boss.announceEverywhere: boolean?`.
  - `Bosses.LADDER[7] == "prismHydra"`.
- `Config/Dungeon` returns:
  - `ROOMS: { { species: { string }, count: number, level: number } }` (3 rooms);
  - `BOSS = "prismHydra"`;
  - `ARRIVAL_WAIT: number` (seconds to wait for the whole group);
  - `OUT_DELAY: number` (seconds before an out player is sent back);
  - layout: `ORIGIN`, `HALL`, `ROOM_RADIUS`, `ROOM_GAP`, `CHAMBER = { x, y, z }`, colours, `LIGHTING`;
  - `ROOM_INTRO_SECONDS: number`.

- [ ] **Step 1: Write the failing tests**

In `tests/BossRules.spec.luau`, update "six bosses" to 7 and the place rule to Wild 1-3, Frontier 4-6, Dungeon 7, then add:

```lua
["config: the Prism Hydra has five phases, one per element, in falling order"] = function()
	local hydra = Bosses.BOSSES.prismHydra
	expect.equal(Bosses.LADDER[7], "prismHydra", "last on the ladder")
	expect.equal(hydra.place, "Dungeon", "its place")
	expect.equal(hydra.shopLevel, 22, "shop level")
	expect.equal(hydra.unlock and hydra.unlock.count, 10, "10 fragments")
	local phases = hydra.phases :: { any }
	expect.equal(#phases, 5, "five phases")
	expect.equal(phases[1].below, 1, "the first starts at full HP")
	local seen = {}
	for index, phase in phases do
		seen[phase.element] = true
		if index > 1 then
			expect.equal(phase.below < phases[index - 1].below, true, `phase {index} below the one before`)
		end
	end
	for _, element in { "Tide", "Volt", "Shade", "Bloom", "Ember" } do
		expect.equal(seen[element], true, element)
	end
	expect.equal(phases[1].mechanics.shield ~= nil and phases[2].mechanics.thunderclap ~= nil and phases[3].mechanics.adds ~= nil and phases[4].mechanics.heal ~= nil and phases[5].mechanics.enrage ~= nil, true, "shield, clap, adds, heal, enrage")
end,
["config: the Rift Devourer drops the Hydra's fragments"] = function()
	local rift = Bosses.BOSSES.riftDevourer
	expect.equal(rift.fragment, "fragment_prismHydra", "its fragment")
	local inDrops, inChest = false, false
	for _, drop in rift.drops do inDrops = inDrops or drop.item == "fragment_prismHydra" end
	for _, grant in rift.firstClear do inChest = inChest or (grant.item == "fragment_prismHydra" and grant.count == 3) end
	expect.equal(inDrops and inChest, true, "drop and 3 in the first clear")
end,
```

Also extend the existing "every item a boss names exists" check, or add one, so that the items `fragment_prismHydra`
and `trophy_prismHydra` exist in `Config/Items`.

`tests/Dungeon.spec.luau`:

```lua
["rooms: three, packs of 2-3 elites from Frontier species at Lv 45-50"] = function()
	expect.equal(#Dungeon.ROOMS, 3, "three rooms")
	for index, room in Dungeon.ROOMS do
		expect.equal(room.count >= 2 and room.count <= 3, true, `room {index} size`)
		expect.equal(room.level >= 45 and room.level <= 50, true, `room {index} level`)
		for _, species in room.species do
			expect.equal(Frontier.SPECIES[species] ~= nil, true, `room {index}: {species}`)
		end
	end
	expect.equal(Dungeon.BOSS, "prismHydra", "the chamber's boss")
end,
["places: the Dungeon has its id"] = function()
	expect.equal(Places.DUNGEON_PLACE_ID, 79143483483478, "place id")
end,
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `lune run tests/run`. Expected: these fail. Bosses has no `prismHydra`, `Config/Dungeon` doesn't exist, and the
count is 6.

- [ ] **Step 3: Add the config**

Starting values, to be retuned in Task 5:
- hp 40000, atk 30, spd 11, level 55, recommended 2400, `groupAtkStep` 0.5, `minFightSeconds` 120;
- element "Tide" (phase 1's), `mechanics = {}`, `phases` as above;
- adds species "Rift Horror".

Phase timings reuse bosses 2-6, with `heal.below = 0.4` and `enrage.below = 0.2`. Phase 3's `adds.at = { 0.6 }` makes
the adds come as the phase starts.

Rewards:
- drops: Gold Seal, Star Shard, Grading Seal and XP Tonic;
- `firstClear`: `trophy_prismHydra` plus 5 of each item;
- `dailyBonus`: 2 Gold Seals;
- cash 400, xp 10000;
- `announceEverywhere = true`.

Placeholder `shape = "golem"`, `scale = 4.0`, `zone = 1`.

- [ ] **Step 4: Run tests to make sure they pass**

Run: `lune run tests/run`. Expected: all pass. Fix any existing test that hard-codes 6 bosses or two places.

- [ ] **Step 5: Commit**

`git commit -m "Config: the Prism Hydra (boss 7), its fragments and trophy, Config/Dungeon, the Dungeon place id"`

---

### Task 2: Boss phases in BattleSim

**Files:**
- Modify: `src/shared/Util/BossRules.luau` (add `phaseAt`)
- Modify: `src/server/Util/BattleSim.luau` (`FighterInput.phases`, phase switch in `bossMechanics`)
- Test: `tests/BossRules.spec.luau`, `tests/BattleSim.spec.luau`

**Interfaces:**
- Produces:
  - `BossRules.phaseAt(phases: { { below: number } }, share: number, current: number): number`. It returns the highest
    index whose `below > share`, never less than `current`.
  - `BattleSim.FighterInput.phases: { { below: number, element: string, mechanics: Mechanics } }?`.
  - A new event `{ type = "phase", from = <boss sim id>, kind = <element>, damage = <phase index> }`.
  - The boss starts with phase 1's element and mechanics.

- [ ] **Step 1: Write the failing tests**

```lua
-- BossRules.spec
["phaseAt: by HP share, and never back"] = function()
	local phases = { { below = 1 }, { below = 0.8 }, { below = 0.6 } }
	expect.equal(BossRules.phaseAt(phases, 1, 1), 1, "full HP")
	expect.equal(BossRules.phaseAt(phases, 0.79, 1), 2, "under 80%")
	expect.equal(BossRules.phaseAt(phases, 0.1, 1), 3, "skips straight to the last reached")
	expect.equal(BossRules.phaseAt(phases, 0.9, 3), 3, "a heal never takes it back")
end,
```

Add the name to the "every rule exists" list.

In `BattleSim.spec`, make a boss with 3 phases:
- Tide shield `{every=1, fraction=0.05, breakStun=1}`;
- Volt thunderclap;
- Ember enrage `{below=0.2, atkMultiplier=2}`.

Its phase 2 is `below = 0.6` and its phase 3 is `below = 0.3`. Drive it with `BattleSim.step` and direct HP edits
through the test helpers the spec already uses. Tests:
- `"phases: the boss starts as phase 1"`: the boss fighter's element is "Tide" and it has a shield after 1 s.
- `"phases: crossing a threshold switches element and mechanics once"`:
  - set the boss to 59% HP and step;
  - exactly one `phase` event with `kind = "Volt"` and `damage = 2`;
  - the element is now Volt;
  - after 3 more seconds there are no new `shield` events and the side's shield is 0.
- `"phases never go back after a heal"`: in phase 2, set HP to 90% and step. It stays phase 2 and no new phase event
  fires.
- `"phases: a Shade adds phase spawns its adds as it starts"`: a phase with `adds.at = { 0.6 }` and `below = 0.6`,
  entered at 59%. A `spawn` event fires, and the add's element is the phase's.

- [ ] **Step 2: Run them to make sure they fail**

Run: `lune run tests/run`. Expected: `phaseAt` is nil, and BattleSim ignores `phases`.

- [ ] **Step 3: Implement**

`phaseAt` goes in BossRules, which is pure. BattleSim's changes:
- `Fighter` gets `phases`, `phase: number`;
- `makeFighter` applies phase 1 when `input.phases` is set (element, mechanics, shield and clap timers);
- at the top of `bossMechanics`, call `phaseAt`. On a change:
  - set `element` and `mechanics`;
  - reset `shieldReady` and `clapReady` from `state.time`;
  - clear the side's shield;
  - reset `addsDone`, `enraged` and `healReady`;
  - emit the `phase` event.

BattleSim requires BossRules the way it requires CombatMath: the Roblox path when `game` exists, the relative path in
Lune.

- [ ] **Step 4: Run tests to make sure they pass**

Run: `lune run tests/run`. Expected: all pass.

- [ ] **Step 5: Commit**

`git commit -m "BattleSim: boss phases (element and mechanics switch at HP thresholds, never back)"`

---

### Task 3: Carried HP in BattleSim and the run rules (`Util/DungeonRules`)

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (`FighterInput.hpNow`)
- Create: `src/shared/Util/DungeonRules.luau`
- Test: `tests/BattleSim.spec.luau`, new `tests/DungeonRules.spec.luau` (register it)

**Interfaces:**
- Produces:
  - `BattleSim.FighterInput.hpNow: number?`: the fighter starts at `clamp(hpNow, 1, hp)` with `maxHp = hp`. Callers
    never pass 0.
  - `DungeonRules.canFight(hpLeft: { [string]: number }, beastId: string): boolean`: absent means fresh (true), above
    0 is true, 0 is false.
  - `DungeonRules.merge(hpLeft: { [string]: number }, ended: { [string]: number }): { [string]: number }`: a new
    table; `ended` wins.
  - `DungeonRules.isOut(hpLeft: { [string]: number }, partyIds: { string }): boolean`: every party card is at 0, or
    the party is empty.
  - `DungeonRules.expectedSize(data: unknown, max: number): number`: reads `data.runSize` as an integer clamped to
    1..max; anything else gives 1.
  - `DungeonRules.pack(room: { species: { string }, count: number, level: number }, seed: number): { string }`:
    `count` species names, cycling through `room.species` from a seed offset.

- [ ] **Step 1: Write the failing tests**

```lua
-- BattleSim.spec
["hpNow: a fighter starts hurt but keeps its max HP"] = function()
	local state = BattleSim.new(Combat, { fighters = { { id = "x", element = "Ember", hp = 100, atk = 5, spd = 10, hpNow = 40 } }, abilities = false, canRun = false },
		{ fighters = { { id = "m", element = "Tide", hp = 50, atk = 1, spd = 1 } }, abilities = false, canRun = false }, 1)
	local x = BattleSim.getFighter(state, "a:x") :: any
	expect.equal(x.hp, 40, "starts at 40")
	expect.equal(x.maxHp, 100, "max stays 100")
end,
-- DungeonRules.spec
["canFight: fresh, hurt, and out for the run (even rested again)"] = function()
	expect.equal(DungeonRules.canFight({}, "a"), true, "never fought")
	expect.equal(DungeonRules.canFight({ a = 12 }, "a"), true, "hurt")
	expect.equal(DungeonRules.canFight({ a = 0 }, "a"), false, "fainted this run")
end,
["merge: the fight's end wins, others kept"] = function()
	local out = DungeonRules.merge({ a = 50, b = 20 }, { a = 0 })
	expect.equal(out.a, 0, "a fainted"); expect.equal(out.b, 20, "b kept")
end,
["isOut: only when every party card is down"] = function()
	expect.equal(DungeonRules.isOut({ a = 0, b = 3 }, { "a", "b" }), false, "b can fight")
	expect.equal(DungeonRules.isOut({ a = 0, b = 0 }, { "a", "b" }), true, "all down")
	expect.equal(DungeonRules.isOut({ a = 0 }, { "a", "c" }), false, "c never fought")
	expect.equal(DungeonRules.isOut({}, {}), true, "no party")
end,
["expectedSize clamps and survives junk"] = function()
	expect.equal(DungeonRules.expectedSize(nil, 4), 1, "Studio")
	expect.equal(DungeonRules.expectedSize({ runSize = 3 }, 4), 3, "group of 3")
	expect.equal(DungeonRules.expectedSize({ runSize = 50 }, 4), 4, "capped")
	expect.equal(DungeonRules.expectedSize({ runSize = 2.5 }, 4), 1, "not an integer")
	expect.equal(DungeonRules.expectedSize("x", 4), 1, "junk")
end,
["pack: count names from the room's species"] = function()
	local names = DungeonRules.pack({ species = { "A", "B" }, count = 3, level = 45 }, 7)
	expect.equal(#names, 3, "three")
	for _, name in names do expect.equal(name == "A" or name == "B", true, name) end
end,
```

Add a SourceOrder-style "every rule exists" test for DungeonRules, like the other Rules specs.

- [ ] **Step 2: Run them to make sure they fail.** Run: `lune run tests/run`. Expected: `hpNow` is ignored (hp 100)
  and DungeonRules is missing.

- [ ] **Step 3: Implement both.** Write `DungeonRules` pure, with no requires.

- [ ] **Step 4: Run tests to make sure they pass.** Run: `lune run tests/run`. Expected: all pass.

- [ ] **Step 5: Commit.** `git commit -m "BattleSim hpNow; Util/DungeonRules (carried HP, out, run size, packs)"`

---

### Task 4: Places and entry scripts for the Dungeon

**Files:**
- Modify: `src/shared/Util/Place.luau`, `src/server/init.server.luau`, `src/client/init.client.luau`
- Create: `dungeon.project.json` (copy of `frontier.project.json`, `"name": "card-shop-tycoon-dungeon"`,
  `"servePort": 34874`, `PlaceKind = "Dungeon"`)
- Test: `tests/Frontier.spec.luau` (or `tests/Dungeon.spec.luau`)

**Interfaces:**
- Produces:
  - `Place.isDungeon(): boolean`: the place id equals `DUNGEON_PLACE_ID`, or `PlaceKind == "Dungeon"`.
  - `Place.isFrontier()` stays false in the Dungeon.
  - `Place.getWorld()` returns the Frontier config in the Dungeon too, for its species stats.
- Server entry, Dungeon branch, in this order:
  - Economy, Monetization, Card, Item, Party, Wild, Battle, Boss;
  - `DungeonService.Start()` (Task 8);
  - Frontier (for the return teleport), Dev, Data.
  - It prints `[Server] Booted (Dungeon)`.
- Client entry, Dungeon branch: the Frontier list plus `DungeonController` (Task 11). In every branch, also
  `TitleController.Start()` (Task 11). The server's Frontier branch gets `DungeonGateService.Start()` in Task 10.

- [ ] **Step 1: Write the failing test.** Load `dungeon.project.json` with `@lune/serde`. Assert that
  `servePort == 34874` and that `tree.Workspace["$attributes"].PlaceKind == "Dungeon"`.
- [ ] **Step 2: Run it to make sure it fails** (the file doesn't exist).
- [ ] **Step 3: Implement.** Until Tasks 8 and 10 land, the Dungeon branch of each entry script requires only modules
  that exist. Add the `DungeonService` and `DungeonController` lines in those tasks.
- [ ] **Step 4: Run** `lune run tests/run` and `rojo build dungeon.project.json -o <scratch>/dungeon.rbxl`. Expected:
  both pass.
- [ ] **Step 5: Commit.** `git commit -m "Dungeon place: Place.isDungeon, dungeon.project.json (port 34874), entry branches"`

---

### Task 5: Balance tool learns phases and the gauntlet; tune the numbers

**Files:**
- Modify: `tools/balance/bosses.luau`, `src/shared/Config/Bosses.luau` (`prismHydra` stats), `src/shared/Config/Dungeon.luau`
  (room levels and counts)

**Interfaces:**
- Consumes: `FighterInput.phases` and `hpNow` (Tasks 2-3), `Config/Dungeon.ROOMS`, `DungeonRules.pack`.
- Produces: the tool passes `phases = boss.phases` for every boss. When the boss is `Dungeon.BOSS`:
  - each party fights the three rooms first: packs of elites built with `CombatMath.getMonsterStats(Frontier, species,
    level, true)`;
  - HP carries over through `hpNow`, and fainted cards stay out;
  - it prints the average HP share left before the Hydra, then the usual rows plus a "3 x maxed" row.

- [ ] **Step 1: Extend the tool** as above. It is a tool, not production code: verify it by running it.
- [ ] **Step 2: Run** `lune run tools/balance/bosses 200`. Read boss 7's rows.
- [ ] **Step 3: Tune** the `prismHydra` hp/atk/spd, the phase mechanics' numbers, and the room levels and counts until
  the targets in Global Constraints hold:
  - best+2 wins 50-60%;
  - maxed+2 wins 50% or less;
  - rec x1 wins 75-85%;
  - 3 x maxed wins 90% or less;
  - about 66% HP is left before the Hydra.

  Then check `lune run tools/balance/bosses 200 2` and `... 200 4`: groups win more, never 100%.
- [ ] **Step 4: Rough 30-45 h estimate.** Compute the total shop XP for level 22 with `Util/LevelMath`, divided by a
  stated XP-per-hour assumption. Note the result in DESIGN.md 5.10. If level 22 is far outside 30-45 h, lower
  `shopLevel`, keeping the ladder rising, and ledger the ruling.
- [ ] **Step 5: Run** `lune run tests/run` (config tests still pass). **Commit:** `git commit -m "Tune the Prism Hydra and the Dungeon rooms with the balance tool"`

---

### Task 6: BattleService: monster packs, carried HP, HP at fight end, room rewards

**Files:**
- Modify: `src/server/Services/BattleService.luau`, `src/server/Services/BossService.luau` (its `OnFightEnded`
  handler signature)

**Interfaces:**
- Consumes: `FighterInput.hpNow` and `phases`, `DungeonRules.canFight`.
- Produces:
  - `export type RunOptions = { pack: { Monster }?, hpLeft: { [Player]: { [string]: number } }?, run: boolean? }`.
  - `BattleService.StartGroupFight(players: { Player }, monster: Monster, options: RunOptions?): (boolean, string?)`:
    - pack monsters are extra side-b fighters with ids `p1..pn`, standing beside `monster` as adds do, held still;
    - leaders and reserves skip cards where `canFight` is false and pass `hpNow` from `hpLeft`;
    - boss inputs pass `phases = boss.phases`.
  - `BattleService.OnFightEnded(handler: (monster: Monster, result: string, hpLeft: { [Player]: { [string]: number } }) -> ())`:
    `hpLeft` holds each member's fought cards' HP at the end (0 if fainted or benched). Members who left early were
    already recorded at `release`.
  - On a `run` fight's win, `payOut` pays the summed `CombatMath.getRewards(Wild, level, true)` XP and cash of `monster`
    plus the pack. It gives no card, shard or Frontier card rolls.
  - When `whyNotPlayer` meets a summoned leader with hp 0 in `hpLeft`, it returns "That creature is out for this run.
    Summon another." The summoned leader must be able to fight.
  - Pack monsters are defeated when the fight ends.
  - Run fights (`options.run`): Run/Leave means leaving the run. BattleService ends the fight for that member as now;
    DungeonService treats them as out (Task 8).

- [ ] **Step 1: Implement**, keeping the non-run paths identical. Lune can't test this service. The rules it uses are
  tested in Tasks 2-3.
- [ ] **Step 2: Regression check in Studio (main place).** `rojo serve` is running. Play, `/boss 1 fight` and an
  `/elite` fight. Expected: both play exactly as before, the barrier comes down, and Output shows no errors.
- [ ] **Step 3: Run** `lune run tests/run`. Expected: all pass (SourceOrder too).
- [ ] **Step 4: Commit.** `git commit -m "BattleService: monster packs, carried HP, HP at fight end, run rewards"`

---

### Task 7: WildService in the Dungeon, and `Util/DungeonBuilder`

**Files:**
- Modify: `src/server/Services/WildService.luau`
- Create: `src/server/Util/DungeonBuilder.luau`

**Interfaces:**
- Produces:
  - `WildService.Start()` in the Dungeon: the Monsters folder and an empty map folder named "Dungeon"; no map, plaza,
    spawns or wandering spawns; the heartbeat loop on, so markers update.
  - `WildService.GetMapFolder(): Folder`.
  - `WildService.BuildBossArenas` builds `boss.place == "Dungeon"` bosses with `center = Dungeon.CHAMBER`.
  - `DungeonBuilder.build(parent: Instance): DungeonLayout`, where:
    - `export type DungeonLayout = { entrance: CFrame, rooms: { { center: Vector3, gate: BasePart, door: BasePart, barrier: { BasePart }, inside: CFrame, packSpot: CFrame } }, chamberDoor: BasePart, returnSpot: CFrame }`.
    - It builds a prism-crystal cavern from `Config/Dungeon`: floor, walls, crystals, coloured light shafts, the
      entrance hall, three sealed rings in a line (barrier as in `BuildBossArenas`, using `BossRules.ringSegments`),
      a door after each (closed: `CanCollide` true) and the chamber door. It sets `Lighting` from `Dungeon.LIGHTING`.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Studio check (Dungeon window).** Open the Dungeon place in a third Studio window, from Creator Hub →
  the place → Edit, and run `rojo serve dungeon.project.json`. The user does that once; tell them. Play.
  Expected:
  - Output says "Booted (Dungeon)";
  - a screenshot of the hall, a room and the chamber;
  - you spawn at the entrance and nothing errors.
- [ ] **Step 3: Run** `lune run tests/run`. **Commit:** `git commit -m "Dungeon world: WildService dungeon mode and DungeonBuilder"`

---

### Task 8: DungeonService: the run

**Files:**
- Create: `src/server/Services/DungeonService.luau`
- Modify: `src/shared/Remotes.luau` (`DungeonRun`, `DungeonLeave`), `src/server/init.server.luau`
- Modify: `src/server/Services/FrontierService.luau` (export `FrontierService.ReturnToFrontier(player: Player)`)

**Interfaces:**
- Consumes:
  - `DungeonBuilder.build`, `BattleService.StartGroupFight(..., RunOptions)` and `OnFightEnded(monster, result, hpLeft)`;
  - `DungeonRules.*`, `WildService.SpawnAt`, `PartyService.GetParty`. The chamber gate is wired in Task 9.
- Produces, on the server only:
  - Remotes `DungeonRun` (server → client): `{ room: number, rooms: number, stage: "waiting" | "room" | "boss" | "won" | "out", message: string? }`.
  - Remote `DungeonLeave` (client → server, no args, rate-limited): leave the run, back to the Frontier.
  - `DungeonService.GetRun(): Run?` and `DungeonService.SkipTo(room: number)`. `SkipTo` is Studio-only (the `/room` dev
    command): it marks the rooms before `room` cleared and opens their doors.

Run state: `{ members: { Player }, hpLeft: { [Player]: { [string]: number } }, cleared: number, started: boolean }`.

Arrival:
- the first player's join data gives `expectedSize`;
- the run starts when that many have arrived, or after `ARRIVAL_WAIT`;
- latecomers join if no fight has started yet; otherwise they're sent back with a message.

Each room's gate prompt "Fight" (any member):
- the members who can still fight move inside;
- the barrier seals;
- after `ROOM_INTRO_SECONDS`, the pack spawns (`DungeonRules.pack`, `SpawnAt` elite at the room level) and the fight
  starts with `{ pack, hpLeft, run = true }`.

On `OnFightEnded`:
- merge the HP;
- drop the barrier;
- on a win, open that room's door; after room 3, open the chamber door;
- members who are `isOut`, or who ran, get stage "out" and are sent back after `OUT_DELAY`.

The chamber is `BossService`'s arena for `prismHydra`. In this task the run ends at the open chamber door; Task 9
wires its gate.

`FrontierService.ReturnToFrontier` teleports to `FRONTIER_PLACE_ID`; in Studio it only notifies.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Studio check (Dungeon window, solo).** Play. Expected:
  - room 1's pack spawns and fights;
  - the HP left shows on the party bar in room 2's fight;
  - a creature that fainted in room 1 can't come back in room 2 (`/rest` doesn't help);
  - losing gives "out" and the Studio "teleports only work in the published game" message.

  Screenshot each room.
- [ ] **Step 3: Studio check (Local Server, 2 players, Dungeon window), Review Focus 4.** Start room 1 and close the
  leader's client mid-fight. Expected: the fight goes on for player 2, and the next room opens on a win.
- [ ] **Step 4: Run** `lune run tests/run`. **Commit:** `git commit -m "DungeonService: the run (arrival, rooms, carried HP, out, chamber)"`

---

### Task 9: BossService: boss 7, the run start, the title, the cross-server announcement

**Files:**
- Modify: `src/server/Services/BossService.luau`, `src/server/Services/DevService.luau` (`/boss 1-7`; `/room <1-3>`
  in the Dungeon: calls `DungeonService.SkipTo`, Studio only)
- Modify: `src/server/Services/DungeonService.luau`. It calls `BossService.SetRunGate`, and the handler calls
  `BossService.StartRun("prismHydra", the members who can still fight, hpLeft)`. After the Hydra's win a return
  portal opens at `returnSpot`.
- Modify: `src/shared/Config/AdminPanel.luau` (a "Dungeon" section: `/room 1`, `/room 2`, `/room 3`)
- Test: `tests/AdminPanel.spec.luau` (its existing check that every command exists covers `/room`)

**Interfaces:**
- Produces:
  - `BossService.StartRun(bossId: string, players: { Player }, hpLeft: { [Player]: { [string]: number } }): (boolean, string?)`:
    - runs `whyNotMember` for each player with `math.huge` reach (shop level and fragments are checked here);
    - then `startBoss` with `RunOptions { hpLeft, run = true }`;
    - it takes the fragments on the first start, as now.
  - In the Dungeon, the arena's Fight and group prompts call a handler that `DungeonService` sets:
    `BossService.SetRunGate(handler: (player: Player, bossId: string) -> ())`.
  - Player attribute `Title = "Dungeon Conqueror"`: set on load when `prismHydra` is cleared, and at that first
    clear. It works in every place.
  - A first clear of a boss with `announceEverywhere` publishes `MessagingService` topic `"BossCleared"` with
    `{ name, bossId, jobId }`. Every place subscribes in `Start` (pcall'd) and fires `Remotes.BossCleared` to its
    clients, skipping its own `jobId`, which already fired locally.

- [ ] **Step 1: Write the failing test.** AdminPanel.spec: the Dungeon section's commands match DevService's aliases
  (the spec's existing alias check). Expected: FAIL, `/room` is unknown.
- [ ] **Step 2: Implement** everything above.
- [ ] **Step 3: Studio check (Dungeon window), Review Focus 5.**
  - With 0 Hydra fragments, the chamber gate says "Needs 10 Hydra Key Fragments (you have 0)...". Expected: the run
    keeps going.
  - With `/item fragment_prismHydra 10` and `/level` high enough, the Hydra starts, its phases fire banners, and on a
    win the fragments are gone, the Title attribute is set, and BossCleared fires.
- [ ] **Step 4: Run** `lune run tests/run`. **Commit:** `git commit -m "BossService: boss 7 run start, Dungeon Conqueror title, cross-server first-clear message"`

---

### Task 10: Frontier portal, lobby and teleport (`DungeonGateService`)

**Files:**
- Create: `src/server/Services/DungeonGateService.luau` (Frontier only)
- Modify: `src/server/Services/WildService.luau` (the Dungeon portal calls `WildService.SetDungeonHandler(handler)`
  instead of "coming soon"; sign `"The Dungeon"`), `src/server/init.server.luau`

**Interfaces:**
- Consumes: `BossService.GetRecord`, `ItemService.GetCount`, `EconomyService.GetLevel`, `BattleService.WhyNotFight`,
  `BossRules.levelReady`, `BossRules.canStart`, `BossRules.groupPromptText`.
- Produces: portal prompts "Enter" (solo) and "Start group" / "Join group" / "Start now".
  - The lobby follows BossService's rules: `GROUP_MAX`, `JOIN_SECONDS`, the leader starts early, the
    `BossGroupPrompt` tag so `BossBoardController` relabels it for the leader.
  - Each member is checked: shop level 22, Hydra unlocked or 10 fragments owned, `WhyNotFight` nil.
  - Then one `TeleportAsync(DUNGEON_PLACE_ID, members, options)` with `ShouldReserveServer = true` and
    `SetTeleportData({ runSize = #members })`.
  - In Studio it only notifies. When `DUNGEON_PLACE_ID == 0`, the portal says "coming soon".

- [ ] **Step 1: Implement.** Write the lobby as its own small module-level state, mirroring BossService's
  `pruneLobby` / `closeLobby`. Leave BossService's lobby as it is.
- [ ] **Step 2: Studio check (Frontier window).** With shop level under 22, "Enter" gives "The Dungeon opens at shop
  level 22." At level 22 with 10 fragments, it gives the Studio teleport message. Output shows no errors.
- [ ] **Step 3: Run** `lune run tests/run`. **Commit:** `git commit -m "Frontier: Dungeon portal, group lobby and reserved-server teleport"`

---

### Task 11: Client: run HUD, phases, conquered screen, title, board

**Files:**
- Create: `src/client/Controllers/DungeonController.luau`, `src/client/Controllers/TitleController.luau`
- Modify: `src/client/Controllers/BattleController.luau`, `src/client/Controllers/BossBoardController.luau`,
  `src/client/Controllers/AnnouncementController.luau` (Hydra text), `src/client/init.client.luau`

**Interfaces:**
- Consumes: `DungeonRun` / `DungeonLeave`, the `phase` event, `summary.boss.firstClear` with `bossId == "prismHydra"`,
  and the `Title` attribute.
- Produces:
  - **DungeonController:** a slim top-left run line ("Room 2/3 · Prism Hydra next"), stage messages, and a "Leave"
    button (48px or more, `UIKit`) that fires `DungeonLeave` after a confirm.
  - **BattleController:**
    - on a `phase` event: a banner ("Volt phase!") in the element colour, `PHASE_SHAKE`, and the boss bar's element
      icon switches;
    - sets the boss marker's `Phase` attribute (the element) so MonsterController lights that head (Task 12);
    - on a `prismHydra` first-clear summary: a full-screen "DUNGEON CONQUERED" instead of "Victory!".
  - **TitleController:** a small BillboardGui over each character with a `Title` attribute (gold text), in every place.
  - **BossBoardController:** 7 rows. A boss is "away" when its `place` differs from the current one ("Wild" in the
    main game, "Frontier", "Dungeon"): "(the Frontier)" or "(the Dungeon)".

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Studio check (Dungeon window).** Screenshots of the run line, a phase banner, and the conquered screen
  (win the Hydra with `/maxcard` cards and `/level`). Check in the phone emulator that the Leave button clears the
  thumbstick and jump button. Output shows no errors.
- [ ] **Step 3: Run** `lune run tests/run`. **Commit:** `git commit -m "Client: Dungeon run line, phase banners, DUNGEON CONQUERED, titles, 7-boss board"`

---

### Task 12: The Prism Hydra model, rig and animation

**Files:**
- Create: `tools/blender/build_prismHydra.py` (on `voxel_kit.py`), `tools/blender/rig_prismHydra.py` (on `rig_kit.py`),
  `assets/blender/PrismHydra/` (.blend, .fbx, palette)
- Create (user-saved): `assets/monsters/prismHydra.rbxm`
- Modify: `src/client/Controllers/MonsterController.luau` (boss rig animation and head glow), `src/shared/Config/Party.luau`
  or `Config/Bosses` (the Hydra's motion numbers), `docs/creatures.md`

**Interfaces:**
- Consumes: the PetRig roles `Pelvis`, `Spine_*`, legs, `Hydra_<head>_<bone>` (heads 1-5, in the order Ember, Tide,
  Bloom, Volt, Shade); `PetAnimator.attach/step`.
- Produces:
  - **Look:** a blocky model with a fat, heavy body on four legs, a crystal crown on its back, and five necks with
    crystal heads, all in one prism palette.
  - **Rig:** one skinned mesh with every vertex on one bone. It faces -Y in Blender.
  - **MonsterController:** for boss markers with a model, it attaches `PetAnimator` and steps it every frame.
    - Each head bone gets an Attachment with a PointLight and a ParticleEmitter, off by default.
    - When the marker's `Phase` attribute changes, that element's head lights up in its colour and the others go dark.
    - On the boss marker's `Fainted` attribute, the heads drop one by one (PetRig pose blend), over about 3 s.

- [ ] **Step 1: Build in Blender** through the Blender MCP. Keep it to a few thousand triangles. Check that it isn't
  a famous-creature lookalike, especially not Tiamat: one palette, a crown, a heavy body. Delete any `*_Src` objects,
  purge orphans, and check that the scene's `blendermcp_*key*` / `*secret*` fields are empty (print lengths only)
  before saving the .blend. Export the FBX.
- [ ] **Step 2: Hand off to the user:** import the FBX (Rig Type Custom, Keep Zero Influence Bones). Reset the
  MeshPart `PivotOffset` rotation. The user saves the model as `assets/monsters/prismHydra.rbxm`.
- [ ] **Step 3: Implement** the MonsterController animation and glow.
- [ ] **Step 4: Run** `lune run tests/run` (the CreatureAssets script gate covers the new .rbxm). **Studio check:** the
  Hydra sways each neck, the phase head glows, and the death drop plays. Take screenshots.
- [ ] **Step 5: Commit** the scripts, assets and code. `git commit -m "Prism Hydra: blocky model, rig, neck animation, phase head glow, death"`

---

### Task 13: Docs and wrap-up

**Files:**
- Modify: `DESIGN.md` (5.10: the Hydra row, phases, the Dungeon, run rules, title, announcement; section 13: Heroic
  tiers, the ranch and its habitat), `CLAUDE.md` (`dungeon.project.json`, port 34874, `/room`, DungeonRules and
  Dungeon in the test list, the Dungeon window note), the Obsidian vault (decisions, lessons, Home.md index)

- [ ] **Step 1: Write the docs.**
- [ ] **Step 2: Run** `lune run tests/run`. Expected: all pass. **Commit:** `git commit -m "Docs: the Dungeon and the Prism Hydra"`
- [ ] **Step 3: Final whole-branch review**, done by a fresh reviewer per superpowers:executing-plans. Then the fix
  pass, then hand over to the user for the Studio check of all three windows.
