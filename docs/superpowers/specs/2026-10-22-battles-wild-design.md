# Battles, part 1: combat core and the server wild map

Roadmap step 5 (DESIGN 5.8), first of three sub-projects:

1. **Combat core + server wild map** (this spec)
2. PvP challenges and arena (later spec)
3. Frontier (a separate Roblox place shared by players from every server: high-level monsters, exclusive
   valuable drops) and boss challenges for groups (later spec)

## 1. Goal

Give cards a real use beyond the shop: fight wild monsters with your party to level your cards. This is the main
way cards level up (shop jobs give a slow trickle). The server wild map is early-game content (monster Lv 1–15),
solo fights only. The combat core built here is reused unchanged by PvP, the Frontier and bosses.

Success: a new player walks through the plaza portal, fights Meadow monsters with their summoned creature, calls
in a second party card, uses abilities, wins XP split across their party, sometimes gets a card, and loses
without losing anything but time.

## 2. Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Fight style | Real-time auto-battle; each fighter has ability buttons with cooldowns |
| Abilities | One per element for every card, plus a signature ability on the 6 Epic/Legendary cards |
| Location | The wild map is an area of the same place/server, reached through a plaza portal |
| Fighters | Your summoned creature leads; during the first 5 s you may call in one more party card (max 2 of yours) vs 1 monster |
| XP | Split evenly across all 3 party cards (whether or not they fought) |
| Rewards | Card XP + a little cash + a chance at a card of the zone's elements |
| Monsters | Separate species (not cards), each with an element |
| Starting fights | Low-level monsters are passive (press Fight); elites, and normal monsters in the top zone, chase you |
| Losing | No loss of XP, cash or cards. Fainted creatures rest 3 minutes |
| Healing spring | In the plaza centre between the shops; standing near it makes resting 3x faster |
| Run | A chance, shown on the button; failure costs a free monster hit and a 3 s wait |
| Zone gates | None: a "Recommended Lv" sign per zone and levels on monster name tags |
| Other players | Solo fights only on the server map (group fights come with bosses) |
| Map | Placeholder built in code; replaceable later by a model in `assets/maps/` with tagged spawn spots |

## 3. Combat rules

All numbers live in `Config/Combat.luau`; the values here are starting points to tune.

**Fighters.** Your summoned creature must be rested to start a fight. During the first `CALL_IN_SECONDS` (5) a
"Call in" button shows for each of your other rested party cards; pick one and it joins. Then the window closes.
Fighter stats are the card's HP / ATK / SPD (BeastRules.getStats). A monster's stats come from its species and level.

**Attacks.** Each fighter attacks its target on its own timer:
`interval = clamp(ATTACK_BASE × SPD_REFERENCE / SPD, ATTACK_MIN, ATTACK_MAX)` with ATTACK_BASE 2 s,
SPD_REFERENCE 10, ATTACK_MIN 0.8 s, ATTACK_MAX 2.5 s (a Common ~2 s, a Legendary ~1 s).
Damage = `round(ATK × elementMultiplier × random(0.9, 1.1))`, at least 1. The monster attacks one of your fighters
(the one with the lowest HP share, ties to the leader).

**Element wheel.** Strong ×1.5, weak ×0.75, otherwise ×1:
- Ember > Bloom > Tide > Ember (each beats the next; the reverse is weak)
- Volt and Shade are strong against each other

**Element abilities** (one button per fighter, cooldown `ABILITY_COOLDOWN` 8 s):

| Element | Ability | Effect |
|---|---|---|
| Ember | Fireball | hit for 2.5× ATK |
| Tide | Wave | heal every one of your fighters 25% of its max HP |
| Bloom | Vine Snare | monster attacks 40% slower for 4 s |
| Volt | Overcharge | this fighter's next 3 attacks come at twice the speed |
| Shade | Curse | monster ATK −30% for 5 s |

**Signature abilities** (second button, cooldown `SIGNATURE_COOLDOWN` 15 s):

| Card | Ability | Effect |
|---|---|---|
| Infernox | Inferno | burns the monster for 6 s (each second 0.4× ATK) |
| Abyssal Koi | Tidal Shield | your fighters absorb damage up to 30% of this fighter's max HP |
| Thunderhorn | Stampede | hit for 2× ATK and stun the monster 2 s |
| Eclipse Fox | Eclipse | this fighter dodges every attack for 3 s |
| Solarion | Supernova | hit for 4× ATK |
| Voidmaw | Devour | hit for 2× ATK; heal itself half the damage |

Abilities use element multipliers like attacks. Effects of the same kind refresh, not stack.

**Run.** Chance = `clamp(0.5 + 0.03 × (leaderSPD − monsterSPD), 0.2, 0.9)`, minus 0.15 against elites (still at
least 0.2). The button shows it ("Run 62%"). Success ends the fight with no rewards and no fainting. Failure: the
monster makes a free attack at once, and Run waits 3 s.

**End.**
- **Win** (monster HP 0): rewards (section 4.4).
- **Lose** (all your fighters at 0 HP): each fighter that fainted rests (section 5). The fight ends; the monster
  heals and walks off.
- A fighter at 0 HP while the other still stands is fainted: it falls over and rests after the fight.
- Leaving the game, resetting your character or the monster despawning counts as a successful Run.
- Target length 20–40 s against a monster of your level; monster HP is tuned for that.

**Simulation.** The server steps each fight at `TICK_RATE` (10 Hz) with a seeded random number generator.
`BattleSim` is pure (no Roblox APIs): `new(fighters, monster, seed)`, `step(state, dt) -> events`,
`useAbility(state, fighter, kind) -> (ok, reason?)`, `callIn(state, fighter)`, `tryRun(state) -> boolean`.
Events (`attack`, `ability`, `effect`, `faint`, `end`) go to the player's client to animate. Clients never decide
anything.

## 4. The server wild map

### 4.1 Getting there
- A portal in the plaza moves you (instant, same server) to the wild entrance, far from the plots.
- At the entrance a "Return to shop" portal, and a **Shop** HUD button while in the wild, move you back to your
  plot. Your summoned creature follows (the marker teleports with you).
- Your shop keeps running while you are in the wild.

### 4.2 Zones (placeholder build)

| Zone | Sign | Monster Lv | Elements |
|---|---|---|---|
| Meadow | Recommended Lv 1+ | 1–5 | Bloom, Tide |
| Caves | Recommended Lv 5+ | 5–10 | Shade, Volt |
| Ember Ridge | Recommended Lv 10+ | 10–15 | Ember, Volt |

Built in code: flat ground per zone in its own colour, part trees and rocks, paths between zones, signs, and spawn
points as tagged parts (`WildSpawn` with a `Zone` attribute). A later model `assets/maps/Wild.rbxm` replaces the
placeholder; code reads the same tags, so nothing else changes.

### 4.3 Monsters
- Two species per zone, each with an element: Mossling (Bloom slime), Puddle Crab (Tide), Cave Bat (Shade),
  Spark Beetle (Volt), Magma Golem (Ember), Ash Wolf (Ember). Each has base HP / ATK / SPD in `Config/Wild.luau`;
  at level L stats are × `1 + MONSTER_GROWTH × (L − 1)`.
- About 8 alive per zone, respawning 20–40 s after being beaten, level random within the zone range.
- **Elites**: 1 in 10 spawns, gold name tag, ×1.6 stats, ×3 rewards, better drop odds, chase you within
  `AGGRO_RADIUS` (25 studs). Normal monsters in Ember Ridge chase you too; elsewhere they are passive.
- Passive monsters wander near their spawn. A "Fight" prompt shows within 10 studs. A chasing monster that reaches
  you starts the fight itself (only if you have a rested summoned creature and are not in a fight; otherwise it
  gives up).
- A monster in a fight is locked to that player. Monsters sleep (no movement) with no player within 100 studs.
- Drawn like creatures: the server moves an invisible marker in `workspace.Monsters` with attributes Species,
  Level, Elite, Element; each client draws a placeholder (a distinct shape per species in its element colour) or a
  model from `assets/monsters/<Species>.rbxm` (same script stripping, part cap and Lune script gate as creatures).

### 4.4 Rewards (win)
- **XP**: `XP_BASE × level ^ XP_EXPONENT` (start 12 × L^1.3), ×3 for elites, split evenly across the 3 party
  cards (rounded down, at least 1 each). Plain party copies become individual cards as XP always does.
- **Cash**: `CASH_PER_LEVEL × level` (start $0.40/level), ×3 for elites, through EconomyService.
- **Card drop**: 5% (normal) / 20% (elite). A random Set 1 card of the zone's elements, rarity by pack-style
  odds, grade rolled on the server, given through CardService.
- Tuned so clearing a zone's levels takes roughly 10–20 fights.

## 5. Resting and the healing spring
- A fainted card rests `REST_SECONDS` (180). Saved as `resting = { [beastId] = restUntil }` (Unix time); offline
  time counts.
- The healing spring stands in the plaza centre. Each second you stand within `SPRING_RADIUS` (12 studs), every
  resting card of yours gets `SPRING_SPEED − 1` (2) extra seconds off (3x speed).
- Resting cards still follow you when summoned but can't start a fight or be called in. The party bar and Party
  panel show "😴 2:41"; near the spring "Healing faster".
- Items that heal resting cards come later.

## 6. Fight on screen
- Start: a glowing ring on the ground around the monster; the camera pulls back; your character can't walk away
  (movement locked until the fight ends); your leader steps into the ring facing the monster.
- In the world: fighters face each other and lunge to attack; hit flashes and floating numbers ("−24",
  "−36 STRONG!" in orange for strong hits, grey for weak); fainted fighters fall over and fade. Other players see it.
- Fight bar (bottom centre, all buttons ≥ 48 px): monster name, level, element icon, HP bar; for each of your
  fighters a card face, HP bar and ability buttons with cooldown sweeps; "Call in" buttons with a countdown for the
  first 5 s; "Run 62%". HUD buttons and the party bar are hidden during the fight.
- End screen (~4 s): Win shows "+N XP each" for the 3 party cards, cash, and a card flip for a drop. Loss shows
  "Your party fainted · rest 3:00 · the plaza spring heals faster".

## 7. Data and code

**Schema v8**: adds `resting = {}` (beastId → restUntil). Load drops unknown beasts and past times.

| Module | Job |
|---|---|
| `shared/Config/Combat.luau` | attack timing, element wheel, abilities, signatures, run, rest, spring |
| `shared/Config/Wild.luau` | zones, species, levels, spawns, respawn, aggro, rewards, drop odds |
| `shared/Util/CombatMath.luau` | pure: attack interval, damage, element multiplier, run chance, XP split, rewards |
| `server/Util/BattleSim.luau` | pure fight simulation with a seeded RNG, returns events |
| `server/Services/BattleService.luau` | fight lifecycle, remotes, locks, rewards, resting, spring |
| `server/Services/WildService.luau` | placeholder map, portals, spring part, monster spawns, sleep/wake, elites, aggro |
| `client/Controllers/BattleController.luau` | fight bar, call-in, abilities, Run, end screen, hit numbers |
| `client/Controllers/MonsterController.luau` | draws monsters on markers (placeholder or model, motion) |

**Remotes**: `StartFight(monsterId)`, `CallIn(slot)`, `UseAbility(fighterIndex, kind)`, `RunFight()`;
server → client `BattleEvent(events)`, `BattleStarted(snapshot)`, `BattleEnded(result)`, `WildTravel(where)`.
All validated (types, ranges, ownership, distance ≤ 12 studs to the monster, monster free, rested leader, one fight
per player) and rate-limited.

**Locks**: a card in a fight can't be removed from the party, re-summoned, condensed, displayed or given a job
until the fight ends (CardService gains a `fighting` flag like `working` and `partied`). Summon/Unsummon is refused
during a fight.

## 8. Testing

Lune:
- CombatMath: element multipliers (all 25 pairs), attack interval limits, run chance limits and elite penalty,
  XP split sums to at most the total and gives each card at least 1, rewards scale with level and elite.
- BattleSim with a fixed seed: a strong party beats a weak monster; a weak party loses; Fireball/Wave/Curse/Vine
  Snare/Overcharge change the outcome as expected; Stampede stun skips monster attacks; Eclipse dodges;
  call-in only within the window and only once; a failed run gives a free monster attack.
- Migration v8 adds `resting`.

Studio commands: `/wild` (travel to the wild), `/rest` (clear resting), `/elite` (spawn an elite Lv-matched
monster next to you).

Studio tests:
1. Plaza portal → wild entrance; Shop button and return portal bring you home; your shop kept selling.
2. Meadow: walk to a monster, Fight; your summoned creature fights; call in a second card within 5 s; use abilities;
   win: XP split across 3 party cards, cash, sometimes a card flip.
3. Lose on purpose (Ember Ridge at Lv 1): both fainted, "😴" timers on the party bar; Fight refused while resting;
   stand at the plaza spring: timer runs 3x.
4. Run: the % shows; failures cost a hit; success ends the fight.
5. Elites (`/elite`): gold tag, chases you, starts the fight on contact.
6. During a fight you can't summon, remove party cards, condense or assign the fighters. Leaving mid-fight =
   run. Two players fight separate monsters at the same time.
7. Phone (landscape): fight bar buttons are tappable, nothing overlaps the jump button.

## 9. Out of scope (later)
PvP and arenas; the Frontier place and its exclusive drops; bosses and groups; healing items; quests; real
monster and map art.
