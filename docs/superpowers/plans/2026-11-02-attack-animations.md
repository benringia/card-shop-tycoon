# Attack Animations and Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Creatures move, charge and attack with element effects; bosses 1-3 and the Prism Hydra get keyed normal and special attacks with effects; the six wild monsters get keyed attacks; boss special attacks give short debuffs.

**Architecture:** The server sim (`BattleSim`) stays the authority. It gains a `charge` event a moment before each auto-attack, fixed ring shapes per boss and player debuffs. The client turns events into pictures through one dispatcher (`Util/FightFx`) used by the fight controller and by PvP spectators. Creature poses are procedural (`PetRig` fidgets). Boss and monster moves are keyed in Blender on their bone rigs and played client-side by `KeyframePlayer`, with no upload. Effects are built in code.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Blender 5 through the Blender MCP (Python), Roblox Studio MCP for checks.

**Spec:** `docs/superpowers/specs/2026-11-02-attack-animations-design.md`

## Global Constraints

- Branch: `attack-animations`, cut from `you-in-the-fight` (unmerged, owner checks pending). Never commit to `main`.
- "No change to who hits whom, when, or how hard (except the debuffs and the boss retune they need)": every existing `BattleSim` test stays green unchanged, and `lune run tools/balance/bosses 200` gives the same numbers as before Task 11.
- "An effect that lands visibly before or after the damage number / HP change" is a failure: impacts land with the `attack` event.
- "No stun over 1 s."
- Effects respect `Extras.enabled()` (the low-graphics switch `MonsterController` uses) and never hide the boss's ring or glow.
- Numbers in `src/shared/Config`; pure logic in `src/shared/Util` with Lune tests; pure modules don't require siblings.
- UI text: ASCII plus `·` and emoji only. Sounds: Roblox-licensed Pro Sound Effects only.
- Each phase starts with a mockup or render the owner approves (owner rule: always show mockups for visual decisions) and ends with a Studio check the owner judges.
- Keep DESIGN.md, CLAUDE.md, docs, memory and the Obsidian vault in sync in the task that changes them.

## Review Focus

1. A charge whose attack never comes (the attacker was stunned, fainted, swapped out or the fight ended): no projectile or strike may land without an `attack` event. Pinned in Task 2 (`AttackTiming.expired`) and Task 5.
2. An `attack` event with no charge before it (joined mid-fight, packet order, overcharge's 0.4 s gaps): play a short instant strike, never nothing. Pinned in Task 2 (`AttackTiming.schedule` with lead 0).
3. Group fights at full size (4 creatures, 4 players, boss, adds) on phones: per-frame effect counts stay capped, and Extras off cuts particles. Pinned in Task 5 (`FightFxRules.budget`).
4. A debuff on a player who goes down, leaves, or whose fight ends: cleared, WalkSpeed restored, HUD icon gone. Pinned in Task 12 (sim tests) and Task 13 (server restore).
5. The Prism Hydra changing phase mid-debuff or mid-special: the debuff kind is the phase at the hit; the beam colour is the phase at release. Pinned in Task 12 and Task 10.

---

## Phase 1: Creature attacks

### Task 1: Charge events in the sim

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (Event doc comment, `Fighter` type, step loop near the attack scheduling)
- Modify: `src/shared/Config/Combat.luau`
- Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- Produces: event `{ type = "charge", from = fighterId, to = likelyTargetId?, seconds = number }`, sent once per upcoming auto-attack of any non-player fighter, when `nextAttack - time <= Combat.CHARGE_LEAD` (`seconds` = that remaining time, so an interval shorter than the lead still charges). `to` comes from `targetOf(state, fighter, true)` (it draws no random). No charge for a fighter stunned through its `nextAttack`.
- `Combat.CHARGE_LEAD = 0.6`.

- [ ] **Step 1: Write the failing tests**
  - `"every auto-attack is charged first, once"`: run a 1v1 wild fight (`wild(...)` helper) for 20 s. For each `attack` event without `kind` from `a:<leader>`, there's exactly one `charge` from the same id before it, at most `CHARGE_LEAD + 0.1` s earlier.
  - `"charges change nothing: same results and damage as before"`: run the same seeded fight twice, once stripping `charge` events from the output. The non-charge event sequences are identical: compare `type`, `from`, `to`, `damage` in order. Existing tests unchanged prove the seed stream didn't move.
  - `"overcharge's short gaps still charge, with the time left"`: a Volt fighter after `useAbility(..., "element")`. Every `charge.seconds` is `<= interval`.
  - `"a stunned fighter isn't charged"`: set `stunUntil` past `nextAttack`. No charge until the stun ends.
- [ ] **Step 2:** `lune run tests/run BattleSim`. Expected: the 4 new tests FAIL (no charge events).
- [ ] **Step 3:** Add `chargedFor: number` to `Fighter` (the `nextAttack` already charged, init `-1`). In the step loop's standing-fighter pass, before the attack check, emit the charge when due. Document `"charge"` in the Event comment.
- [ ] **Step 4:** `lune run tests/run`. Expected: all pass, the old BattleSim tests unchanged.
- [ ] **Step 5:** Commit `"Sim: a charge event before each auto-attack"`.

### Task 2: Attack timing rules

**Files:**
- Create: `src/shared/Util/AttackTiming.luau`, `src/shared/Config/AttackFx.luau`
- Test: `tests/AttackTiming.spec.luau` (register in `tests/run.luau`; add to CLAUDE.md's test list)

**Interfaces:**
- Produces:
  - `AttackTiming.schedule(lead: number, flight: number): { releaseIn: number, impactIn: number }`. Impact at `lead`; release at `lead - flight`, clamped to 0; flight shortened when `lead < flight`. With lead 0: release 0, impact 0 (instant strike).
  - `AttackTiming.expired(chargedAt: number, lead: number, now: number, grace: number): boolean`. True once `now > chargedAt + lead + grace` with no attack seen. The client drops the charge visual.
  - `AttackTiming.comboTimes(count: number, window: number): { number }`. Hit times inside the window, the last at `window` (where the damage number shows).
- `Config/AttackFx` (plain data):
  - `CHARGE_GRACE = 0.3`
  - `FLIGHT = { Ember = 0.35, Tide = 0.25 }`
  - `COMBO = { count = 3, window = 0.45 }`
  - `ELEMENT = { [element] = { kind = "projectile" | "combo" | "zip", color = rgb } }` (Ember projectile, Tide projectile, Bloom combo, Volt zip, Shade combo)
  - orbit numbers for Task 3: `ORBIT = { radius = 4, speed = 0.8, dart = 1.5 }`
- [ ] **Step 1: Write the failing tests**
  - `schedule(0.6, 0.35)` gives `releaseIn ≈ 0.25`, `impactIn = 0.6`.
  - `schedule(0.2, 0.35)` gives `releaseIn = 0`, `impactIn = 0.2`.
  - `schedule(0, 0.35)` gives `0, 0`.
  - `expired(10, 0.6, 10.85, 0.3)` is false; at `10.91` it's true.
  - `comboTimes(3, 0.45)` is `{0.15, 0.3, 0.45}`.
  - Every `ELEMENT` entry names a known kind.
- [ ] **Step 2:** Run the spec. Expected: FAIL (module missing).
- [ ] **Step 3:** Implement both files.
- [ ] **Step 4:** Run the spec. Expected: PASS.
- [ ] **Step 5:** Commit.

### Task 3: Creatures move around in fights

**Files:**
- Create: `src/shared/Util/FightMotion.luau`
- Modify: `src/client/Controllers/CreatureController.luau` (its per-frame `step`)
- Test: `tests/FightMotion.spec.luau`

**Interfaces:**
- Produces: `FightMotion.offset(seed: number, now: number, cfg: any, charging: boolean): (number, number)`. An x/z offset in studs around the marker. It circles `ORBIT.radius` and darts, is deterministic from `seed` + `now`, and holds still while `charging` (returns the last position, smoothed).
- How the client knows a creature is in a fight: its marker has attribute `Fighting` (check `BattleService` sets it; add it in `BattleService` if missing). The client-only offset is added to the model, not the marker. It faces the target marker from the last charge's `to`, or the fight's foe.
- [ ] **Step 1: Write the failing tests**
  - The offset's length is `<= radius + dart`.
  - The same seed and time give the same result.
  - Two seeds differ.
  - Charging freezes the offset (two times 0.3 s apart give the same offset).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement and wire it into `CreatureController`. Export `CreatureController.SetCharging(marker: BasePart, seconds: number)` (the creature drawn on that marker holds still for `seconds`); Task 5's dispatcher calls it.
- [ ] **Step 4:** Lune passes. Studio: a wild fight shows the creature circling.
- [ ] **Step 5:** Commit.

### Task 4: Creature attack poses

**Files:**
- Modify: `src/shared/Util/PetRig.luau`, `src/shared/Config/Party.luau` (`PET_ANIM.FIDGET_SECONDS`, pose angles)
- Test: `tests/PetRig.spec.luau`

**Interfaces:**
- Produces fidget kinds playable with `PetAnimator.play(rig, kind, now)`:
  - `"charge"`: crouch and lean back, held.
  - `"strike"`: a lunge forward and back.
  - `"combo"`: three quick lunges timed to `AttackTiming.comboTimes`.
  - `"cast"`: rear up and throw forward.
  - Each has a `PetRig.body` and a `PetRig.cue` at its strike frame.
- [ ] **Step 1: Write the failing tests**
  - Each kind's body pose at its peak moves the expected way: `charge` has negative `forward` and lower `lift`; `strike` has positive `forward` at its cue; `combo` cues three times; `cast` has positive `pitch`, then a cue.
  - Each kind has a `FIDGET_SECONDS` entry.
- [ ] **Step 2:** Run `PetRig`. Expected: FAIL.
- [ ] **Step 3:** Implement the poses next to the existing fidgets.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit.

### Task 5: The fight effects dispatcher and creature normal attacks (mockup first)

**Files:**
- Create: `src/client/Util/FightFx.luau` (event → picture), `src/client/Util/ElementFx.luau` (the per-element effect builders), `src/shared/Util/FightFxRules.luau`
- Modify: `src/client/Controllers/BattleController.luau` (`onEvents` hands events to `FightFx`; damage numbers unchanged)
- Test: `tests/FightFxRules.spec.luau`

**Interfaces:**
- Consumes: Task 1 `charge` events; Task 2 `AttackTiming`, `Config/AttackFx`; Task 3 `CreatureController.SetCharging`; Task 4 fidget kinds.
- Produces:
  - `FightFx.new(resolve: { marker: (id: string) -> BasePart?, rig: (id: string) -> any?, element: (id: string) -> string? }): Dispatcher`
  - `dispatcher.onEvents(events: { any }, now: number)`
  - `dispatcher.destroy()`
  - `FightFxRules.budget(active: number, extras: boolean, cfg): boolean`. False when `active >= cfg.MAX_ACTIVE` (`AttackFx.MAX_ACTIVE = 12`), or `>= MAX_ACTIVE_LOW = 4` with extras off.
- [ ] **Step 1: Mockup.** Render the five element attacks (charge glow, fireball arc + burst, water blast splash, vine whip ×3, lightning zip, shadow claw ×3) as an animated companion page (`.superpowers/brainstorm/.../content/creature-attacks.html`), plus Studio screenshots of a code-built fireball spike. Get the owner's approval or changes before Step 2.
- [ ] **Step 2: Write the failing tests**
  - `budget(11, true)` is true; `budget(12, true)` is false; `budget(4, false)` is false.
  - `FightFxRules.kindFor(element)` follows `AttackFx.ELEMENT`.
- [ ] **Step 3:** Run. Expected: FAIL.
- [ ] **Step 4:** Implement:
  - On `charge`: pose `"charge"`, an element glow on the model, `SetCharging`, and schedule release and impact with `AttackTiming`.
  - On the matching `attack`: impact effect at the target and the hit pose. Projectiles home to the actual target.
  - Charges with no attack by `expired`: fade out.
  - Attacks with no charge: instant strike.
  - Sounds from Pro Sound Effects, ids in `Config/AttackFx`.
- [ ] **Step 5:** Lune PASS. Studio: wild fight and boss fight with an Ember, Bloom and Volt creature. Each effect lands with its damage number. Screenshot each.
- [ ] **Step 6:** Commit, with DESIGN (fights section, file tree) and CLAUDE.md (test list) updated.

### Task 6: Ability and signature effects

**Files:**
- Modify: `src/client/Util/ElementFx.luau`, `src/client/Util/FightFx.luau`, `src/shared/Config/AttackFx.luau` (`ABILITY`, `SIGNATURE` sections)
- Test: `tests/FightFxRules.spec.luau`

**Interfaces:**
- On `ability` events, by kind:
  - `Fireball`: big charged fireball, bigger burst.
  - `Wave`: a water wave over the caster.
  - `Snare`: vines wrap the target.
  - `Overcharge`: a crackling aura on the caster.
  - `Curse`: dark mist on the target.
- Signature kinds (`Inferno`, `TidalShield`, `Stampede`, `Eclipse`, `Supernova`, `Devour`) each get one effect, with a short release pose (`"cast"`) ending at the event.
- [ ] **Step 1: Mockup** of the 5 ability and 6 signature effects. Owner approves.
- [ ] **Step 2: Failing test:** every `Combat.ABILITIES` kind and every `Combat.SIGNATURES` kind has an `AttackFx` entry (`FightFxRules.hasEffect(kind)`).
- [ ] **Step 3:** Run. Expected: FAIL.
- [ ] **Step 4:** Implement.
- [ ] **Step 5:** PASS. Studio: use each Pet button kind and one signature, screenshot.
- [ ] **Step 6:** Commit.

### Task 7: PvP spectators see the attacks

**Files:**
- Modify: `src/server/Services/ArenaService.luau` (`broadcast`, fight start), `src/shared/Remotes.luau` (`ArenaWatch`), `src/shared/Config/Pvp.luau` (`WATCH_RADIUS = 60`)
- Create: `src/client/Controllers/ArenaWatchController.luau` (start it in `init.client.luau`, main place only)

**Interfaces:**
- Server:
  - Each broadcast also fires `Remotes.ArenaWatch` to every player within `WATCH_RADIUS` of the arena centre who isn't a fighter, with `{ events, markers }`. `markers` maps sim id to marker; send it with the first watch payload of a fight and on change.
  - Fire `{ ended = true }` at fight end.
  - Server to client only, so no rate limit is needed.
- Client: builds a `FightFx` dispatcher from the markers (elements from marker attributes) and feeds it events. No HUD.
- [ ] **Step 1:** Implement.
- [ ] **Step 2:** Studio Local Server, 3 players: two fight in the arena, the third in the stands sees the creature effects. Screenshot from the third player.
- [ ] **Step 3:** Commit, with DESIGN (PvP section) updated.

## Phase 2: Boss attacks

### Task 8: One ring shape per boss and orange rings (mockup first)

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (`bigAttack`), `src/shared/Config/Bosses.luau` (`playerAttacks.shape` per boss), `src/shared/Config/SwordFx.luau` (`RING_COLOR`)
- Test: `tests/BattleSim.spec.luau`, `tests/BossRules.spec.luau` or a Bosses config test

**Interfaces:**
- `playerAttacks.shape: "slam" | "swipe"`: Meadow Warden slam, Cave Brood Queen swipe, Ember Colossus slam, Frost Tyrant slam, Storm Sovereign slam, Rift Devourer swipe, Prism Hydra swipe (spec table).
- `bigAttack` still draws its random (`local roll = random(state)`) and uses `attacks.shape` when set, else the old coin flip.
- [ ] **Step 1: Mockup:** the ring on the meadow, cave and lava floors in 3 orange tones next to today's white. The owner picks.
- [ ] **Step 2: Write the failing tests**
  - `"a boss's rings all take its shape"`: a 30 s fight with `playerAttacks.shape = "swipe"` gives only `swipe` ring events.
  - `"a fixed shape draws the same randoms"`: outcome and damage sequence equal to the same fight with shape nil, except the ring kinds.
  - Every `Bosses.BOSSES` entry with `playerAttacks` has a `shape` from the spec table.
- [ ] **Step 3:** Run. Expected: FAIL.
- [ ] **Step 4:** Implement. Set `RING_COLOR` to the owner's pick.
- [ ] **Step 5:** PASS. `lune run tools/balance/bosses 200` shows the same numbers as before. Studio screenshot of a ring.
- [ ] **Step 6:** Commit, with DESIGN (boss table: shape column, ring colour) updated.

### Task 9: Bone-rig animation pipeline

**Files:**
- Create: `tools/blender/anim_bone_kit.py`
  - Load a rigged model's .blend from `assets/blender/<Model>/`.
  - Key bone poses with `key_bone(name, frame, euler_deg)`.
  - `export_clip(name, json_dir)`: per frame (30/s), each bone's local transform relative to its rest pose, in Roblox axes (`M = ((-1,0,0),(0,0,1),(0,1,0))`, as `anim_kit.py`), plus markers.
- Modify: `tools/anim/build_kfs.luau` (`--bones` mode: Pose tree by bone hierarchy instead of R15)
- Create: `assets/monster-animations/<Model>/<clip>.rbxm` (build output). Add a Rojo mapping `ReplicatedStorage.MonsterAnimations` in `default.project.json`, `frontier.project.json` and `dungeon.project.json`, and tell the owner to restart `rojo serve`.
- Modify: `src/client/Util/KeyframePlayer.luau`
- Test: `tests/KeyframeTiming.spec.luau`

**Interfaces:**
- `KeyframePlayer.playOnce(player: Player, clip: KeyframeSequence, speed: number, onMarker: ((name: string) -> ())?)`. One-shot over the looping idle/walk. While it plays, `PetAnimator`'s procedural motion on those bones yields: `KeyframePlayer.isPlaying(player): boolean` is checked in `MonsterController`. It blends out over `KEYFRAME_ANIM.ONE_SHOT_BLEND = 0.15` s.
- `KeyframeTiming.oneShotWeight(t: number, length: number, blend: number): number`. Ramps 0 to 1 in `blend`, holds, then 1 to 0 over the last `blend`.
- Clip names per model: `windup`, `strike`, `specialWindup`, `specialRelease`. Wild monsters only `windup` and `strike`. Marker `Hit` on the strike frame.
- [ ] **Step 1: Write the failing tests:** `oneShotWeight(0, 1, 0.15) = 0`, `(0.15, 1, 0.15) = 1`, `(0.5, …) = 1`, `(1, …) = 0`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement the kit, the build mode and `playOnce`. Prove it on one test clip on the Meadow Warden (a 1 s arm raise). Studio: the bones move. If keyed bones don't work well, stop and show the owner a procedural alternative (spec fallback).
- [ ] **Step 4:** PASS. Commit, with docs/animations.md updated with a "Bone rigs" section.

### Task 10: Boss moves and effects (renders first)

**Files:**
- Create: `tools/blender/anim_<boss>.py` for `meadowWarden`, `caveBroodQueen`, `emberColossus`, `prismHydra` (4 clips each, timed to `Config/Bosses` warnings), and their exported `.rbxm` files
- Modify: `src/client/Util/FightFx.luau`, `src/client/Util/ElementFx.luau` (boss impacts and releases), `src/shared/Config/AttackFx.luau` (`BOSS` section: per boss, the impact and release effects and colours), `src/client/Controllers/MonsterController.luau` (play the clips)

**Interfaces:**
- Boss `charge` event: neutral `windup` clip, no glow.
- `attack` on a creature: `strike` with the impact at the target.
- `telegraph` (quick hit on a player): today's red glow; the body holds `windup`, then `strike` lands with the pending hit's `attack` event.
- `ring`: `specialWindup` over the warning, with element particles pulling in. At the hit: `specialRelease` plus a shape effect: a slam shockwave and debris; a swipe slash arc or beam (the Hydra's beam is coloured by its current phase element, marker attribute `Phase`).
- Group fights: the one body plays one strike at a time, the earliest landing (creature hits are instant). Each player's quick hit keeps its own red glow and lands its impact on that player.
- Sounds per boss strike and release, from Pro Sound Effects, ids in `AttackFx.BOSS`.
- [ ] **Step 1: Renders:** front and side GIFs of each boss's 4 clips at real speed, plus effect mockups (shockwave, web spit, lava slam, prism beam). The owner approves per boss.
- [ ] **Step 2:** Key, export and build the clips. Implement the client side.
- [ ] **Step 3:** Studio: `/boss 1 fight`, `/boss 2 fight`, `/boss 3 fight`, and the Dungeon window `/room 4` for the Hydra. The strike and release land with the damage. Screenshots.
- [ ] **Step 4:** `lune run tests/run` PASS. Commit per boss, with DESIGN updated.

## Phase 3: Wild monsters

### Task 11: Wild monster attacks (renders first)

**Files:**
- Create: `tools/blender/anim_<species>.py` for Ash Wolf, Cave Bat, Magma Golem, Mossling, Puddle Crab, Spark Beetle (`windup`, `strike`), and their exports
- Modify: `src/shared/Config/AttackFx.luau` (`MONSTER` section), `src/client/Util/FightFx.luau`

**Interfaces:** same flow as a boss's normal attack. Sounds from Pro Sound Effects, ids in `AttackFx.MONSTER`.
- Ash Wolf: lunging bite.
- Cave Bat: dive.
- Magma Golem: ground punch, dust and lava sparks.
- Mossling: headbutt.
- Puddle Crab: pincer snap.
- Spark Beetle: horn charge with sparks.

- [ ] **Step 1: Renders** of each species' clips plus effect mockups. Owner approves.
- [ ] **Step 2:** Key, export, wire.
- [ ] **Step 3:** Studio: a wild fight with each species (`/wild`, `/elite`), screenshots. `lune run tests/run` PASS.
- [ ] **Step 4:** Commit, with DESIGN updated.

## Phase 4: Boss debuffs

### Task 12: Debuffs in the sim

**Files:**
- Modify: `src/server/Util/BattleSim.luau` (pending ring hits, player fighter state, `swordHit`, `dodge`, step), `src/shared/Config/Bosses.luau`
- Test: `tests/BattleSim.spec.luau`

**Interfaces:**
- `Config/Bosses.DEBUFFS` (starting values, retuned in Task 14):
  - `Entangled = { seconds = 2, slow = 0.6 }`
  - `Poison = { seconds = 4, perSecond = 0.02 }` (share of max HP)
  - `Burn = { seconds = 3, perSecond = 0.035 }`
  - `Chilled = { seconds = 3, slow = 0.3, dodgeCooldown = 1.5 }`
  - `Shocked = { seconds = 0.5 }` (stun; must be `<= 1`)
  - `Weakened = { seconds = 4, sword = 0.7 }`
- Per boss: `debuff = "Entangled" | ... | "byPhase"`. Warden Entangled, Brood Queen Poison, Colossus Burn, Frost Tyrant Chilled, Storm Sovereign Shocked, Rift Devourer Weakened, Hydra byPhase.
- `Bosses.DEBUFF_BY_ELEMENT = { Bloom = "Entangled", Shade = "Poison", Ember = "Burn", Tide = "Chilled", Volt = "Shocked" }`.
- The sim input `playerAttacks.debuff` carries the kind (or `"byPhase"`). A landed ring hit sets `target.debuff = { kind, untilTime, tick }` and refreshes on a new hit (no stacking). Event `{ type = "debuff", to, kind, seconds }`.
- Effects in the sim:
  - Poison and Burn tick each second through `hurtPlayer` (event `{ type = "attack", kind = "Poison" | "Burn", to, damage }`).
  - Shocked: `swordHit` and `dodge` return `"stunned"`.
  - Weakened: sword power × `sword`.
  - Chilled: dodge cooldown × `dodgeCooldown`.
  - The movement slows are the server's (Task 13).
- Cleared when the player goes down, leaves or the fight ends.
- [ ] **Step 1: Write the failing tests**
  - `"a ring hit gives the boss's debuff, a miss doesn't"`: one ring hit gives a `debuff` event of the configured kind; with `ringCheck` false, none.
  - `"poison ticks then ends"`: Poison takes about `4 × 0.02 × maxHp` over 4 s, then stops.
  - `"a new hit refreshes, doesn't stack"`.
  - `"Shocked blocks sword and dodge for 0.5 s"`.
  - `"Weakened sword hits do 70%"` (same seed, compare damage).
  - `"Chilled slows the dodge recharge"`.
  - `"the Hydra's debuff is its phase at the hit"`: Shade phase gives Poison, Ember phase gives Burn.
  - `"down or leaving clears it"`.
  - `"no debuff config: no debuff"` (fights without it unchanged).
  - `"every stun lasts at most 1 s"` (config test).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Pass `debuff` from `BossService` / `BattleService` into `playerAttacks`.
- [ ] **Step 4:** `lune run tests/run` PASS.
- [ ] **Step 5:** Commit.

### Task 13: Debuffs on the server and the HUD (mockup first)

**Files:**
- Modify: `src/server/Services/BattleService.luau` (on `debuff` events: WalkSpeed × `1 - slow` for its seconds, restored on expiry, down, leave and fight end, using the `WalkSpeedBefore` pattern `setDowned` uses)
- Modify: `src/client/Util/CombatHud.luau` (`hud.setDebuff(kind: string?, untilClock: number)`: an icon chip with a countdown by the portrait)
- Create: `src/client/Util/DebuffFx.luau` (an effect on the character per kind: vines, green bubbles, flames, frost, sparks, purple haze)
- Modify: `src/shared/Config/CombatHud.luau` (`DEBUFFS` look: icon/emoji, colour, name)
- [ ] **Step 1: Mockup** of the 6 debuff icons and character effects on the HUD. Owner approves.
- [ ] **Step 2:** Implement.
- [ ] **Step 3:** Studio: `/boss 1 fight`, stand in a ring. You're slowed, the icon counts down, then speed comes back. Repeat for boss 2 (poison ticks) and 3 (burn). Also check a down player and a fight that ends mid-debuff: speed is restored.
- [ ] **Step 4:** Commit, with DESIGN updated.

### Task 14: Balance with debuffs

**Files:**
- Modify: `tools/balance/bosses.luau` (debuffs flow through the sim already; make sure `playerAttacks.debuff` is passed and the tool's sword uses the sim's Weakened/Shocked rules), `src/shared/Config/Bosses.luau` (hp/atk and the debuff numbers)
- [ ] **Step 1:** Run `lune run tools/balance/bosses 200` before and after the debuffs. Record both in the ledger.
- [ ] **Step 2:** Retune the boss HP/ATK and debuff values until the targets hold: well 85% at 1x / 50% at 0.8x; still 60% / 15%. Check 2 players (`lune run tools/balance/bosses 100 2`).
- [ ] **Step 3:** Commit, with DESIGN updated (boss table HP/ATK, debuff table, balance note) and CLAUDE.md if the tool changed.

### Task 16: High-quality effects (owner's quality bar, spec "Quality bar")

**Files:**
- Create: `tools/textures/make_attack_fx.py` (done in the mockup), `assets/ui/fx-attack/*.png` (uploaded; ids in
  `Config/AttackFx` TEXTURES), `src/shared/Util/ShakeRules.luau`, `src/shared/Util/DamagePop.luau`,
  `src/client/Util/ScreenFx.luau`
- Modify: `src/shared/Config/AttackFx.luau` (TEXTURES, GRADE tiers, SHAKE, FLASH, layered SOUNDS),
  `src/shared/Util/FightFxRules.luau` (`tier(grade, cfg)`), `src/client/Util/ElementFx.luau` (textured emitters, beams),
  `src/client/Util/FightFx.luau` (grade extras, shake, flash, sounds), `src/client/Controllers/CreatureController.luau`
  (the view's grade), `src/client/Controllers/BattleController.luau` (ScreenFx, damage numbers)
- Tests: `tests/ShakeRules.spec.luau`, `tests/DamagePop.spec.luau`, `tests/FightFxRules.spec.luau`

**Interfaces:**
- `FightFxRules.tier(grade: string?, cfg) -> { scale, sparks, extra, shake }`: C/B/A/S from `AttackFx.GRADE`, C for
  anything else.
- `ShakeRules.add(trauma, amount) -> number` (capped at 1), `decay(trauma, dt, rate)`, `offset(trauma, maxStuds)` (the
  squared trauma times max), `falloff(strength, distance, near, far)` (full inside near, none past far).
- `DamagePop.at(t, style) -> { scale, rise, alpha, rotation }` and `DamagePop.life(style)`; styles normal, crit,
  strong, weak, heal, tick.
- `ScreenFx.shake(amount)`, `ScreenFx.shakeAt(amount, position)`, `ScreenFx.flash(color, strength, seconds)`.
- [ ] Step 1: failing tests for the pure modules; Step 2: implement; Step 3: upload textures, rebuild ElementFx and
  FightFx, damage numbers; Step 4: Studio check per element at each grade (`/maxcard`), screenshots; Step 5: commit.

### Task 15: Docs and wrap-up

- [ ] Update DESIGN.md (fights, file tree, Config files, 10.6 HUD), CLAUDE.md (new mapping, tools, test list), docs/animations.md, the memory file `combat-week-design.md`, and the Obsidian vault (`Sword combat.md` or a new `Attack effects.md`, Decisions log, Lessons learned).
- [ ] Final whole-branch review (executing-plans / subagent-driven final review), fix pass, then finishing-a-development-branch once the owner confirms.
