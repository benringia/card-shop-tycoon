# Boss Groups (Phase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2-4 players fight one shared boss: the leader opens a group at the gate, others join within 15 s, the boss
scales with the group, and each player who helped enough gets their own loot roll.

**Architecture:** One fight, many players. `BattleSim` learns fighter owners (one call-in per owner, abilities only on
your own fighters, per-fighter damage dealt/taken, a player leaving withdraws only their fighters). `BattleService`'s
`Fight` becomes a fight with members (a solo fight is a group of one), so Wild fights, solo bosses and group bosses
share one code path. `BossService` runs the lobby at each gate and passes each member's contribution to the reward
rules. Pure rules (group scaling, contribution) live in `Util/BossRules`.

**Tech Stack:** Roblox Luau, Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP for Studio checks.

**Spec:** `docs/superpowers/specs/2026-10-28-boss-ladder-design.md` (section 5 Groups, section 7.4 Contribution, section 8 UI)

## Global Constraints

- Optional, 2-4 players. The party leader starts the fight at the gate; others join within 15 s from the gate.
- Scaling with party size n: boss HP x (1 + 0.8 (n - 1)), ATK x (1 + 0.15 (n - 1)). Solo stays possible.
- Loot is rolled per player (everyone who contributed gets their own full roll; nothing is split).
- Contribution: loot needs at least 10% of the damage dealt or 15% of the fight tanked, and the player must have the
  boss unlocked. Max 4 players.
- Carried players (below the contribution share), user's call 2026-10-28: a "carried roll": item chances x0.25
  (`Bosses.CARRIED_FACTOR`), never fragments, no first-clear chest, no daily bonus; the loot cooldown and soft cap
  still apply. XP and cash as usual.
- Fight HUD: boss HP bar, phase banner, group members' HP. Boss gate prompt: Fight (solo), Start group, Join.
- Server authoritative; every remote validated and rate-limited (CLAUDE.md). No magic numbers: values in `Config/Bosses`.
- No new saved data: groups are per fight (schema stays v12).
- PvP (ArenaService) and plain Wild fights behave exactly as before.

## Review Focus

- A group member leaves the game, dies or runs mid-fight: only their fighters leave; the others fight on; the fight
  ends only when nobody is left. Tested in Task 2 (`withdraw`), checked in Task 3/4 Studio steps.
- One player tries to use another member's ability or call in another member's reserve (forged remote): refused.
  Tested in Task 2.
- The leader leaves or walks away during the 15 s lobby: the next member leads, or the lobby closes with nothing taken.
  Checked in Task 4 (2-player Local Server).
- A member who joined without the boss unlocked: their fragments are used only if the fight really starts.
  Checked in Task 4.
- A carried player (almost no damage, almost no hits taken) gets XP, cash and only the carried roll (x0.25, no
  fragments, no chests). Tested in Task 1 (`contributed`, `carriedDrop`), shown on the end screen in Task 5.

---

### Task 1: Group config and pure rules

**Files:**
- Modify: `src/shared/Config/Bosses.luau`, `src/shared/Util/BossRules.luau`
- Test: `tests/BossRules.spec.luau`

**Interfaces:**
- Produces: `Bosses.GROUP_MAX = 4`, `Bosses.JOIN_SECONDS = 15`, `Bosses.GROUP_HP_STEP = 0.8`,
  `Bosses.GROUP_ATK_STEP = 0.15`, `Bosses.CONTRIBUTION_DAMAGE = 0.10`, `Bosses.CONTRIBUTION_TANK = 0.15`,
  `Bosses.CARRIED_FACTOR = 0.25`.
- Produces: `BossRules.carriedDrop(config, item: string, chance: number, isFragment: boolean): number` (the chance a
  carried player rolls: 0 for fragments, `chance * CARRIED_FACTOR` otherwise).
- Produces: `BossRules.groupStats(config, hp: number, atk: number, size: number): (number, number)` (both rounded).
- Produces: `BossRules.contributed(config, dealt: number, taken: number, totalDealt: number, totalTaken: number): boolean`.

- [ ] **Step 1: Write the failing tests**

```lua
["groupStats: HP +80% and ATK +15% per extra player"] = function()
	expect.equal(select(1, BossRules.groupStats(Bosses, 1200, 9, 1)), 1200, "solo HP")
	local hp, atk = BossRules.groupStats(Bosses, 1200, 9, 2)
	expect.equal(hp, 2160, "2 players HP"); expect.equal(atk, 10, "2 players ATK (10.35)")
	hp, atk = BossRules.groupStats(Bosses, 4800, 18, 4)
	expect.equal(hp, 16320, "4 players HP"); expect.equal(atk, 26, "4 players ATK (26.1)")
end,
["contributed: 10% of the damage or 15% of the hits taken"] = function()
	expect.equal(BossRules.contributed(Bosses, 10, 0, 100, 100), true, "10% damage")
	expect.equal(BossRules.contributed(Bosses, 9, 15, 100, 100), true, "15% tanked")
	expect.equal(BossRules.contributed(Bosses, 9, 14, 100, 100), false, "carried")
	expect.equal(BossRules.contributed(Bosses, 0, 0, 0, 0), true, "nothing happened: no penalty")
end,
["carriedDrop: a quarter of the chance, never fragments"] = function()
	expect.equal(BossRules.carriedDrop(Bosses, "xpTonic", 0.6, false), 0.15, "tonic")
	expect.equal(BossRules.carriedDrop(Bosses, "fragment_caveBroodQueen", 0.7, true), 0, "fragment")
end,
```

- [ ] **Step 2: Run** `lune run tests/run`. Expected: the three new tests FAIL (functions missing).
- [ ] **Step 3: Implement** the config values and both functions (a zero total counts as a full share).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass.
- [ ] **Step 5: Commit** `git commit -am "Boss groups: scaling and contribution rules"`

### Task 2: BattleSim owners, withdraw and contribution

**Files:**
- Modify: `src/server/Util/BattleSim.luau`
- Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- Produces: `FighterInput.owner: string?` (a player's UserId as a string; nil = the side's only owner, as now).
- Produces: `BattleSim.callIn(state, id: string, owner: string?): (boolean, string?)`: one call-in per owner (nil
  owner keeps today's one-per-side rule); calling in removes only that owner's other reserves; another owner's
  reserve -> `false, "missing"`.
- Produces: `BattleSim.useAbility(state, id, which, owner: string?)`: a fighter of another owner -> `nil, "missing"`.
- Produces: `BattleSim.withdraw(state, owner: string): { Event }`: that owner's fighters and reserves leave (field
  `left = true`, never targeted, not fainted, not rested); if side A has nobody standing, `finish(state, "run")`.
- Produces: `BattleSim.contribution(state, owner: string): { dealt: number, taken: number, totalDealt: number, totalTaken: number }`
  over side A; every hit (attacks, abilities, burn) adds to the attacker's `dealt` and the target's `taken`.
- Produces: snapshot fighters gain `owner` and `left`; reserves stay ids.

- [ ] **Step 1: Write the failing tests** (`tests/BattleSim.spec.luau`, using the file's helpers):
  - `"group: each owner calls in one reserve of their own"`: side A fighters p1 (owner "1"), p2 (owner "2"), reserves
    r1 ("1"), r1b ("1"), r2 ("2"); `callIn(state, "a:r2", "1")` -> false; `callIn("a:r1", "1")` -> true;
    `callIn("a:r1b", "1")` -> false; `callIn("a:r2", "2")` -> true.
  - `"group: abilities only on your own fighters"`: `useAbility(state, "a:p2", "element", "1")` -> nil, "missing";
    with owner "2" -> events.
  - `"group: a player leaving takes only their fighters out"`: `withdraw(state, "1")`; p1 `left`, not fainted; the
    boss never targets p1 again over 10 s; `state.result` nil; `withdraw(state, "2")` -> `state.result == "run"`.
  - `"group: damage dealt and taken are tallied per owner"`: run a fight 5 s; `contribution(state, "1").dealt +
    contribution(state, "2").dealt == totalDealt`, `totalDealt > 0`, same for taken.
  - Existing solo/PvP tests stay unchanged and green.
- [ ] **Step 2: Run** `lune run tests/run`. Expected: the four new tests FAIL.
- [ ] **Step 3: Implement** in `BattleSim.luau` (`Side.calledIn` becomes `calledBy: { [string]: boolean }` keyed by
  `owner or ""`; `standing` and `targetOf` skip `left`; tallies in `hit` and `burn`).
- [ ] **Step 4: Run** `lune run tests/run`. Expected: all pass (ArenaService's calls without an owner work as before).
- [ ] **Step 5: Commit** `git commit -am "Battle sim: fighter owners, per-owner call-ins, withdraw, contribution"`

### Task 3: BattleService fights with members

**Files:**
- Modify: `src/server/Services/BattleService.luau`

**Interfaces:**
- Consumes: Task 2 owner API.
- Produces: `BattleService.StartGroupFight(players: { Player }, monster: Monster, scale: { hp: number, atk: number }?): (boolean, string?)`
  (first player is the leader; checks `whyNot` for every player; returns false and the first reason if any fails).
  `BattleService.StartFight(player, monster)` = a group of one.
- Produces: boss rewards hook fight table `{ seconds: number, fighterIds: { string }, contributed: boolean }`
  (`contributed` from `BossRules.contributed` on that member's `BattleSim.contribution`; always true for a group of one).
- Produces: `BattleStarted` payload gains `allies = { [simId] = "<DisplayName> · <Card>" }` (other members' fighters)
  and `group = true` when more than one member; `names` stays the player's own cards only.

- [ ] **Step 1: Studio check plan written down** (service wiring; rules are Tasks 1-2): solo Wild fight (win and
  run), solo boss fight (win), PvP challenge: all behave as before; Output has no errors.
- [ ] **Step 2: Implement.** `Fight` keeps the shared parts (monster, sim, spots, center, ended) and `members:
  { [Player]: Member }` (`leaderId, extraId, extraMarker, partyIds, died, leashWarnedAt`); `fights[player]` points
  every member at the same fight. Per-player paths take the member: call-in and abilities pass
  `tostring(player.UserId)` as owner; `keepNear`, `stillValid` and death/leave run per member and `BattleSim.withdraw`
  that member in a group (in a group of one they end the fight as now); Run in a group of more than one is a leave
  (withdraw), not a chance roll. Events and snapshots go to every member. Leaders stand on an arc facing the boss
  (spread `Bosses.RING_RADIUS`, 4 studs apart). On a win each member still in the game is paid on their own
  `partyIds`; boss items via the hook with their own `fighterIds` and `contributed`. Fainted fighters rest per
  owner. `scale` multiplies the boss's HP and ATK before the sim starts.
- [ ] **Step 3: Run** `lune run tests/run` and `rojo build`, then the Studio checks from Step 1.
- [ ] **Step 4: Commit** `git commit -am "Battle service: fights with members (solo is a group of one)"`

### Task 4: Group lobby at the gate

**Files:**
- Modify: `src/server/Services/WildService.luau` (`BuildBossArenas(onGate, onGroup)`; a second server prompt on the
  gate, `UIOffset` below the first, `BossArena.groupPrompt: ProximityPrompt`)
- Modify: `src/server/Services/BossService.luau` (lobbies, keys, scaled start, contribution into rewards)
- Modify: `src/server/Services/DevService.luau` (`/boss <n> group` opens a group as if the second prompt was used)

**Interfaces:**
- Consumes: Task 1 `groupStats`, `contributed` (via the hook's `contributed`), Task 3 `StartGroupFight`.
- Produces: lobby rules (one lobby or fight per arena):
  - "Start group" (no lobby, arena free): the leader passes the solo checks (lock/fragments, `WhyNotFight`, distance);
    a lobby opens for `JOIN_SECONDS`; the prompt reads "Join group (1/4)".
  - "Join group (n/4)": distance, not full, `canStart` for the joiner, `WhyNotFight`; joined players see "You joined
    <leader>'s group". The leader pressing it again starts at once.
  - At 15 s or when full: each member is re-checked (in game, within `GATE_DISTANCE * 2` of the gate, `WhyNotFight`);
    failed members are dropped with a message; if the leader dropped, the next member leads; with nobody left the
    lobby closes. Then the boss spawns with `groupStats` for the count, keys are taken from members who didn't have
    the boss unlocked, and `StartGroupFight` runs. A failed start takes no keys.
  - The solo prompt while a lobby is open: "A group is forming at the <boss>: join it or wait."
  - Rewards: when `fight.contributed` is false, `onBossWin` gives the carried roll (`carriedDrop` per drop, after the
    usual cooldown/soft-cap/over-power factor; a fragment is any item some boss's `unlock` uses), no first-clear chest
    and no daily bonus, and sets `result.carried = true`. XP and cash are paid anyway.

- [ ] **Step 1: Studio check plan written down**: Test tab -> Local Server, 2 players. Player 1 `/boss 1`, presses
  "Start group"; player 2 `/boss 1`, presses "Join group (1/4)"; after 15 s one Warden spawns with 2160 HP; both fight
  it; both get the end screen; Player 2 leaving mid-fight leaves player 1 fighting; a third press of "Fight boss" while
  the group fights says to wait. Solo `/boss 1 fight` unchanged.
- [ ] **Step 2: Implement.**
- [ ] **Step 3: Run** tests, `rojo build`, the single-player parts in Studio; hand the 2-player check to the user.
- [ ] **Step 4: Commit** `git commit -am "Boss groups: lobby at the gate, scaled boss, per-player loot with contribution"`

### Task 5: Group fight HUD

**Files:**
- Modify: `src/client/Controllers/BattleController.luau`

**Interfaces:**
- Consumes: Task 3 payload (`allies`, `group`), snapshot fighters' `owner`/`left`, Task 4 `summary.boss.carried`.

- [ ] **Step 1: Studio check plan written down**: in a group fight the bar shows your own fighters with buttons, an
  ally row with each member's creature and HP (greyed when they left), Run reads "Leave"; a carried player's end screen
  says "Carried: smaller loot (deal 10% of the damage or take 15% of the hits for full loot)". Solo fights look as before.
- [ ] **Step 2: Implement** (ally row reuses the PvP `enemyRow` bar style; call-in buttons only for ids in your own
  `names`).
- [ ] **Step 3: Run** tests, `rojo build`, Studio screenshots (solo boss fight at least; group with the user).
- [ ] **Step 4: Commit** `git commit -am "Group boss fight HUD"`

### Task 6: Docs

**Files:**
- Modify: `DESIGN.md` (5.10 groups, roadmap "phase 2 done"), `CLAUDE.md` (`/boss <n> group`), Obsidian
  `Core loop and economy.md` and `Decisions log.md`.

- [ ] **Step 1: Update the docs.**
- [ ] **Step 2: Run** `lune run tests/run` and `rojo build`.
- [ ] **Step 3: Commit** `git commit -am "Boss groups docs"`; merge and push after the user approves in Studio.
