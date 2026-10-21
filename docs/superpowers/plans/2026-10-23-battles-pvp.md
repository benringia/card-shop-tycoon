# Battles Part 2 (PvP + Arena) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players challenge each other to full-party battles for a cash bet held in escrow, fight on the single arena pad (others queue and spectators watch), and go home 10 s after the result.

**Architecture:** BattleSim is generalised from "party vs one monster" to two sides of fighters; the wild BattleService and the new ArenaService both run it. ArenaService owns challenges, escrow, the queue, the arena map, the fight lifecycle and the saved PvP record. Clients get a ChallengeController (prompts and popups) and a PvP mode in the existing BattleController; creature markers carry Hp/MaxHp attributes so everyone sees floating HP bars.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo 7, Lune 0.11 (`lune run tests/run`).

**Spec:** `docs/superpowers/specs/2026-10-23-battles-pvp-design.md`

## Global Constraints

- Server authoritative; all cash through `EconomyService.TrySpend` / `EconomyService.AddCash`; no XP, card drops or resting from PvP.
- Every remote in `src/shared/Remotes.luau`, validated (types, ranges, distance, cash, cap) and rate-limited.
- Tunables in `src/shared/Config/Pvp.luau` (plain data, Lune-loadable): `CHALLENGE_DISTANCE = 15`, `CHALLENGE_SECONDS = 15`, `CHALLENGE_COOLDOWN = 10`, `DECLINE_BLOCK_SECONDS = 30`, `CAP_PER_LEVEL = 50`, `BET_STEP = 5`, `BET_PRESETS = { 0, 10, 25, 50 }`, `RETURN_SECONDS = 10`, `PAD_SIZE = 40`.
- Bet cap = min(challenger cash, target cash, `CAP_PER_LEVEL` × lower shop level), floored to `BET_STEP`; bet 0 = Friendly.
- Win → winner gets 2 × bet; draw (120 s limit, or both leave) → both refunded; leave/reset mid-fight = forfeit.
- One arena pad; one fight at a time; first-come queue; leaving the queue refunds both.
- Schema v9: `pvp = { wins = 0, losses = 0, draws = 0 }` with migration `[8]` + Lune test.
- UI: buttons ≥ 48 px, ASCII plus `·` and emoji, UIKit.
- Cards resting from the wild don't fight in PvP; a player needs ≥ 1 rested party card to challenge or accept.

## Review Focus

1. **Cash changes between challenge and accept** (spent, or below the bet) → accept refused, nothing taken from anyone; partial escrow is always refunded.
2. **Either player leaves while queued, while the challenge is pending, or mid-fight** → pending/queued: both refunded; mid-fight: leaver forfeits, the other gets 2 × bet, both un-held, markers cleaned; never charged twice.
3. **Challenge spam / races**: challenging someone who is fighting, queued, already challenged or challenging; accepting an expired challenge; two players challenging each other at once → refused cleanly.
4. **Wild and PvP overlap**: a wild fight start or travel while in a PvP fight or queue, a challenge while in a wild fight → refused.
5. **A party that changes after the challenge** (cards removed, all resting, summon swapped) → the fight uses the party at fight start; a side with no usable cards can't accept/start.

---

### Task 1: BattleSim with two sides (wild ported)

**Files:**
- Modify: `src/server/Util/BattleSim.luau`, `tests/BattleSim.spec.luau`, `src/server/Services/BattleService.luau`, `src/client/Controllers/BattleController.luau`

**Interfaces:**
- Produces:
  - `export type FighterInput = { id: string, element: string, hp: number, atk: number, spd: number, signature: string?, elite: boolean? }`
  - `export type SideInput = { fighters: { FighterInput }, reserves: { FighterInput }?, abilities: boolean, canRun: boolean }`
  - `BattleSim.new(combat, sideA: SideInput, sideB: SideInput, seed: number): State`
  - Fighter ids inside the sim are `"a:" .. id` / `"b:" .. id`; every event's `from`/`to` and every snapshot id uses them.
  - `BattleSim.step(state, dt): { Event }`; `BattleSim.callIn(state, id): (boolean, string?)` (prefixed id); `BattleSim.useAbility(state, id, which): ({ Event }?, string?)`; `BattleSim.tryRun(state, side: "a" | "b"): { Event }`; `BattleSim.forfeit(state, side): { Event }`
  - `state.result`: `"a"` | `"b"` | `"draw"` | `"run"`. Timeout → `"run"` if side A `canRun` (wild, as in part 1), else `"draw"`.
  - `BattleSim.snapshot(state)` → `{ time, result, sides = { a = SideSnapshot, b = SideSnapshot } }`, `SideSnapshot = { fighters = { { id, hp, maxHp, element, abilityIn, signature?, signatureIn, fainted } }, reserves = { id }, callInFor, runIn, runChance, shield }`
  - `BattleSim.getFighter(state, id)` → `{ hp, maxHp, fainted }?` (for marker HP attributes)
  - Fainted fighters for resting: `BattleSim.getFainted(state, side): { string }` (unprefixed ids).

- [ ] **Step 1: Port the part 1 tests to the new API.** Add helpers in the spec: `wild(leader, reserves, monster, seed)` builds side A `{ fighters = { leader }, reserves = reserves, abilities = true, canRun = true }` and side B `{ fighters = { monster (id "m") }, abilities = false, canRun = false }`; refer to ids as `"a:a"`, `"a:b"`, `"b:m"`; results `"win"` → `"a"`, `"lose"` → `"b"`; `tryRun(state)` → `tryRun(state, "a")`. Every part 1 test keeps its assertions.
- [ ] **Step 2: Add new tests:**
  - `"3v3 even parties end with a winner and replay by seed"`: two sides of 3 identical-stat fighters (`hp 200, atk 12, spd 10`, elements Ember/Tide/Bloom on both), both `abilities = true, canRun = false`; runs to end; result is `"a"` or `"b"`; same seed → same concatenated event string.
  - `"Wave heals only its own side"`: side A Tide user + damaged ally, side B damaged fighter; after Wave, side B HP unchanged, side A HP up.
  - `"Curse hits the enemy the fighter targets"`: side B two fighters, one at lower HP share; after Curse, that one's attacks deal less over 3 s than without Curse; the other's unchanged.
  - `"timeout is a draw when neither side can run"`: 0-ATK sides, `canRun = false` both → `result == "draw"` after `MAX_FIGHT_SECONDS`.
  - `"forfeit ends the fight for the other side"`: `forfeit(state, "a")` → `result == "b"`, one `end` event, later `step` returns no events.
- [ ] **Step 3: Run tests** — Expected: FAIL (old API).
- [ ] **Step 4: Rewrite BattleSim** to the Produces interface. Every fighter targets the standing enemy with the lowest HP share (ties: list order). Per-fighter effects: stun, slow, curse, burn (+ tick), dodge, overcharge; per-side shield. Target abilities (Fireball, Supernova, Devour, Stampede, Curse, Snare, Inferno) act on the caster's current target; Wave/TidalShield on the caster's side; Overcharge/Eclipse on the caster. A side with `abilities = false` never casts (monsters). Run chance from side's first fighter vs enemy side's first fighter, elite penalty from that enemy's `elite`. Keep the current LCG (same seeds replay the same wild fights).
- [ ] **Step 5: Run tests** — Expected: all pass (ported + new).
- [ ] **Step 6: Port BattleService (wild)** to the new API: side B monster input id `"m"` with `elite`; marker lookup via a `markers: { [prefixedId]: BasePart }` map in the fight (leader `"a:"..leaderId`, extra `"a:"..extraId`, monster `"b:m"`); results `"a"` → win, `"b"` → lose; resting from `getFainted(state, "a")`. `BattleStarted` gains `markers = { [prefixedId]: BasePart }` and `side = "a"`; snapshots are the new shape.
- [ ] **Step 7: Port BattleController**: read `snapshot.sides[mySide]` for my fighters/reserves/callInFor/run, the other side for the enemy row (wild: the one monster in the top bar as now); `UseAbility`/`CallIn` send prefixed ids; floating numbers use the `markers` map from `BattleStarted` (drop the name-based lookup).
- [ ] **Step 8:** Build, syntax, tests, then Studio smoke list for the wild unchanged (fight, call-in, abilities, run, lose, rest). **Commit** "BattleSim: two sides; wild fights ported"

---

### Task 2: PvP rules, config and schema v9

**Files:**
- Create: `src/shared/Config/Pvp.luau`, `src/shared/Util/PvpRules.luau`, `tests/PvpRules.spec.luau`
- Modify: `src/server/Util/Migrations.luau` (`[8]`), `src/shared/Config/Data.luau` (9), `src/server/Services/DataService.luau` (type + template `pvp`), `tests/Migrations.spec.luau`, `tests/run.luau`

**Interfaces:**
- Produces (pure, config passed in):
  - `PvpRules.getBetCap(config, cashA: number, cashB: number, levelA: number, levelB: number): number` — floored to `BET_STEP`, never negative.
  - `PvpRules.isValidBet(config, bet: unknown, cap: number): boolean` — number, integer, ≥ 0, multiple of `BET_STEP`, ≤ cap.
  - `PvpRules.getPayout(outcome: "win" | "lose" | "draw", bet: number): number`
  - `PvpRules.sanitizeRecord(raw: unknown): { wins: number, losses: number, draws: number }` — non-negative integers, missing → 0.
  - `PvpRules.addResult(record, outcome): record` (new table)

- [ ] **Step 1: Failing tests** `tests/PvpRules.spec.luau`:
  - cap: `getBetCap(cfg, 1000, 300, 4, 9) == 200` (50 × 4); `getBetCap(cfg, 1000, 133, 9, 9) == 130`; `getBetCap(cfg, 0, 500, 5, 5) == 0`; negative cash → 0.
  - valid bet: 0 ok; 25 ok with cap 30; 27 no; 35 no with cap 30; -5, 2.5, "10", nil, NaN all no.
  - payout: win 40 → 80; draw 40 → 40; lose 40 → 0; win 0 → 0.
  - record: `sanitizeRecord({ wins = 3, losses = -2, draws = 1.7 })` → `{3, 0, 1}`; `sanitizeRecord("x")` → zeros; `addResult` increments the right field and doesn't mutate its input.
  - Migrations: `"v9: adds an empty pvp record, keeps existing"`.
- [ ] **Step 2: Run** — Expected: FAIL (modules missing / pvp nil).
- [ ] **Step 3: Implement** `Config/Pvp.luau` (Global Constraints values, plus `ARENA_ORIGIN = { x = 0, y = 0, z = -1200 }`, `ARENA_PORTAL = { x = -84, y = 0, z = 0 }`, `LEASH_RADIUS = 18`, `SPAWN_OFFSET = 14`, `ACTION_COOLDOWN = 0.5`), `PvpRules`, migration `[8]`, `SCHEMA_VERSION = 9`, DataService type/template.
- [ ] **Step 4: Run** — Expected: all pass. **Commit** "PvP rules, config and schema v9"

---

### Task 3: ArenaService (map, challenges, escrow, queue, fights, record)

**Files:**
- Create: `src/server/Services/ArenaService.luau`
- Modify: `src/shared/Remotes.luau`, `src/server/init.server.luau` (start after BattleService), `src/server/Services/WildService.luau` (`SetTravelBlocker` → `AddTravelBlocker`, list), `src/server/Services/BattleService.luau` (refuse wild fights when `PartyService.IsLocked`; use `AddTravelBlocker`), `src/server/Services/PartyService.luau` (`IsLocked(player): boolean`), `src/server/Services/DevService.luau` (`/arena`)

**Interfaces:**
- Consumes: BattleSim (Task 1), PvpRules + Config/Pvp (Task 2), `BattleService.IsFighting/IsResting`, `PartyService.GetParty/SetLocked/SetHold/GetMarker/CreateMarker`, `CardService.GetBeast/SetFighting`, `EconomyService.GetCash/GetLevel/TrySpend/AddCash`, `PlotService.GetPlot`, `DataService.Register/OnBeforeLeave`.
- Produces:
  - Remotes: client → server `Challenge(targetUserId: number, bet: number)`, `ChallengeRespond(accept: boolean)`, `ChallengeCancel()` (spectators walk in through the portal prompt, server-side); server → client `ChallengeIncoming({ fromUserId, fromName, bet, yourPower, theirPower, seconds })`, `ChallengeStatus({ state: "sent" | "declined" | "expired" | "cancelled" | "queued" | "starting" | "refused", message?, position? })`.
  - PvP fights reuse `BattleStarted` (with `mode = "pvp"`, `side = "a" | "b"`, `names = { [prefixedId] = cardName }`, `opponentName`, `markers`), `BattleEvent`, `BattleEnded` (`{ mode = "pvp", outcome = "win" | "lose" | "draw", cash = payout, opponentName, returnIn = RETURN_SECONDS, forfeit = boolean }`).
  - `ArenaService.IsBusy(player): boolean` (pending challenge, queued or fighting).
  - Player attributes: `PartyPower` (refreshed every 2 s), `PvpWins`, `PvpLosses`, `PvpDraws`.
  - `UseAbility` from a PvP fighter is handled by ArenaService (BattleService ignores players it isn't fighting for); ArenaService connects its own handler to the same remote and ignores players not in a PvP fight.

- [ ] **Step 1: Arena map** under `workspace.Arena` at `ARENA_ORIGIN`: floor, one pad (cylinder ring `PAD_SIZE`, low wall ring of parts), two side spawn parts at ±`SPAWN_OFFSET` on Z, stands (stepped blocks) on both long sides, sign "Arena", a "Return" portal prompt; plaza portal "Arena" at `ARENA_PORTAL` (prompt moves a player to the stands, streaming first like WildService).
- [ ] **Step 2: Challenges**: state per player `{ outgoing?, incoming?, cooldownUntil, blocked: { [userId]: until } }`. `Challenge` validation order: rate limit; types (`targetUserId` integer, bet number); target exists, not self; neither `IsBusy` nor in a wild fight (`BattleService.IsFighting`); distance ≤ `CHALLENGE_DISTANCE`; cooldown; pair not blocked; both have ≥ 1 usable party card (exists, not resting); `isValidBet(bet, getBetCap(...))`. Then fire `ChallengeIncoming` to the target and `ChallengeStatus("sent")` to the sender; expire after `CHALLENGE_SECONDS` (treated as decline). Decline blocks the pair for `DECLINE_BLOCK_SECONDS`.
- [ ] **Step 3: Accept → escrow**: re-run every check; `TrySpend(sender, bet)` then `TrySpend(target, bet)`; if the second fails refund the first and send `refused` to both. Then append the match to the queue; if the pad is free start it, else `ChallengeStatus("queued", position)` to both. Leaving or `ChallengeCancel` while queued refunds both and drops the match.
- [ ] **Step 4: Fight start**: lock both (`PartyService.SetLocked`), mark fighters (`CardService.SetFighting`), stream and move each player to their spawn, build sides from each party's usable cards (`abilities = true, canRun = false`), seed, place creatures in a line in front of each player (summoned via `SetHold`, others via `CreateMarker`), set marker attributes `Hp`/`MaxHp`, fire `BattleStarted` to each player with their own `side`.
- [ ] **Step 5: Loop**: Heartbeat at `Combat.TICK_RATE`; step, lunges, `Fainted`/`Hp` attributes on markers, `BattleEvent` to both players (each with the full snapshot), leash both players to their half (`Pvp.LEASH_RADIUS` around their spawn); `UseAbility` for a player's own side only (id must start with their side prefix).
- [ ] **Step 6: End**: result → outcomes per player; `forfeit` on leave/reset/character gone (before `DataService` save via `OnBeforeLeave`); both gone the same tick → draw. Payout through `AddCash` with `getPayout`; update records (`addResult`) and attributes; unlock, unhold, clear fighting flags, destroy extra markers and HP attributes; fire `BattleEnded`; after `RETURN_SECONDS` move both home (plot spawn); start the next queued match.
- [ ] **Step 7: Data**: `load` reads `sanitizeRecord(data.pvp)` and sets attributes; `save` writes it (only if loaded); `unload` clears. Server shutdown: `OnBeforeLeave` already refunds/forfeits per player.
- [ ] **Step 8: Wiring**: `PartyService.IsLocked`; BattleService `whyNot` refuses when locked ("You're in a PvP fight."); WildService `AddTravelBlocker` (BattleService and ArenaService both add one); DevService `/arena` (move to the stands).
- [ ] **Step 9:** Build, syntax, tests, sourcemap. **Commit** "ArenaService: challenges, escrow, queue and PvP fights"

---

### Task 4: Client — challenges, PvP fight bar, HP bars, record

**Files:**
- Create: `src/client/Controllers/ChallengeController.luau`
- Modify: `src/client/Controllers/BattleController.luau` (PvP mode), `src/client/Controllers/CreatureController.luau` (HP bar from `Hp`/`MaxHp` marker attributes), `src/client/Controllers/PartyController.luau` (header "PvP W-L-D"), `src/client/init.client.luau`

**Interfaces:**
- Consumes: Task 3 remotes and attributes; `PvpRules.getBetCap` (preview the cap from player attributes `Cash`, `Level`).

- [ ] **Step 1: ChallengeController**: a client ProximityPrompt "Challenge" (ObjectText = their name, `MaxActivationDistance = CHALLENGE_DISTANCE`, key `C` so it doesn't clash with E prompts) on every other player's HumanoidRootPart; hidden while I'm busy. Sender popup (UIKit panel-style frame, not a full panel): title "Challenge <name>", "Your Power N vs M" (from `PartyPower` attributes), bet buttons for `BET_PRESETS` plus "Max" and −/+ `BET_STEP` steppers clamped to the previewed cap, current bet label ("Friendly" for 0), Send / Cancel. Incoming popup: "<name> challenges you", "Bet $X" or "Friendly", both Powers, countdown, Accept / Decline (no answer = decline). Status toasts from `ChallengeStatus` ("Challenge sent", "Declined", "Waiting for the arena... 1 match ahead").
- [ ] **Step 2: BattleController PvP mode** (`mode == "pvp"`): enemy row of compact HP bars (element icon + name) for the other side's fighters; my fighters as now; no Run and no Call-in buttons; end screen "You win! +$80" / "You lose · -$40" / "Draw · bets returned" / "Opponent left · you win +$80" with "Going home in 10..." countdown.
- [ ] **Step 3: HP bars** over any creature marker with `MaxHp` set: small BillboardGui bar (green → red), hidden when the attribute is cleared.
- [ ] **Step 4: Party panel header**: "PvP 12-5-1" from the attributes.
- [ ] **Step 5:** Build, syntax, tests, SourceOrder, sourcemap. **Commit** "Challenges, PvP fight bar, creature HP bars"

---

### Task 5: Docs

- [ ] DESIGN.md: 5.8 part 2 (built, awaiting Studio test) with the rules from the spec; 10.2 tree (`ArenaService`, `ChallengeController`, `Config/Pvp`, `Util/PvpRules`); 10.4 v9 `pvp` + schema history. CLAUDE.md: test list (PvpRules), dev command `/arena`. Commit "Document battles part 2". Studio test list: spec section 9.
