# Attack animations and effects (creatures, bosses, wild monsters) and boss debuffs

Combat week, project after "You in the fight" (spec `2026-11-02-you-in-the-fight-design.md`, branch `you-in-the-fight`).
Written 2026-11-02 from a conversation with the owner; marked **(my call)** where the owner didn't decide.

## Why

Fights work but look static. Creatures stand at their fight spot and do a tiny step toward the target when they hit
(`BattleService.lunge`, `Combat.LUNGE_STUDS`); bosses glow before an attack and draw a closing ring for big ones, but
their bodies barely move; wild monsters do the same small lunge. The owner wants fights to look alive: creatures that
run around, charge up and let go with a visible effect (a fireball, a 3-hit combo), bosses with real attack animations
and effects, and wild monsters that animate too. The players are mostly kids: every attack must read clearly.

## Goals

1. **Creatures** (your party's, in every fight mode: wild, boss, group, Dungeon, PvP) move around during a fight,
   charge before each attack, and attack with a visible element effect.

**Who sees it** (owner): the players in a fight see its attacks. Players outside a wild, boss or Dungeon fight see
today's simple step and hit (the Frontier redesign will give boss fights their own arenas anyway, so nobody watches
them). In the PvP arena, everyone sees the attacks: the spectators in the stands get the same events and effects as the
two fighters.
2. **Bosses** have two kinds of attack with good animations and effects:
   - **Normal attack**: no ring on the ground; a wind-up, a strike, an impact effect.
   - **Special attack**: the ring on the ground (as today) plus a big wind-up and a big effect matching the ring.
3. **Wild monsters** have a normal attack only, with an animation and an effect.
4. **Boss debuffs**: getting hit by a boss's special attack gives the player a short debuff, one kind per boss.

## Non-goals

- No change to who hits whom, when, or how hard (except the debuffs and the boss retune they need). The server's fight
  sim (`src/server/Util/BattleSim.luau`) stays the authority; animations and effects are the client's picture of it.
- No hand-made animation per creature (there are about 70 cards).
- Frontier bosses 4-6 (Frost Tyrant, Storm Sovereign, Rift Devourer) get no animations here: they have no models of
  their own yet (the Frontier redesign, concept C, will make them). They do get their debuffs.
- No new damage numbers or HUD layout beyond the debuff indicator.

## Anti-goals (would make it a failure even if it works)

- An effect that lands visibly before or after the damage number / HP change (the hit must look like it causes it).
- Long loss of control for the player (stuns over 1 second). Kids find that the most frustrating thing.
- Effects so busy that a group fight drops frames on phones, or hides the boss's warning ring and glow.
- Attacks that all look the same: element and boss identity must show.

## Current state (for the builder)

- Fights: `BattleService` runs `BattleSim` at `Combat.TICK_RATE` (10/s) and broadcasts events (`Remotes.BattleEvent`:
  `attack`, `ability`, `telegraph`, `ring`, `down`, ...) and snapshots to fight members. `BattleController` (client)
  shows them: damage numbers (`floatText`), `HitFx` sparks/flash, `RingFx` closing rings, the combat HUD.
- Fighters in the world are server-moved invisible markers: creatures in `workspace.Creatures` (drawn by
  `CreatureController` with `CreatureVisuals`), monsters and bosses in `workspace.Monsters` (drawn by
  `MonsterController`). Fight spots: `BattleService` `fight.spots`; `lunge` moves a marker toward its target for 0.15 s.
- Rigged models: creature cards (Originals pack, Meshy + `tools/blender/rig_kit.py`, bone names for `Util/PetRig`),
  bosses `meadowWarden`, `caveBroodQueen`, `emberColossus` (Meshy, `rig_<boss>.py`) and `prismHydra`
  (`build_prismHydra.py`), and the six wild species in `assets/monsters` (Ash Wolf, Cave Bat, Magma Golem, Mossling,
  Puddle Crab, Spark Beetle; `rig_<species>.py`). Bones are driven procedurally on the client by `Util/PetAnimator`
  (walk, breath, tail, fidgets) and boss moments (`Util/BossMoments`: the intro roar pose).
- Boss telegraphs: quick hits (`telegraph` event, `QUICK_WARNING` + `HIT_GRACE`), big attacks (`ring` event with shape
  `slam` or `swipe` and its warning). `windUp` sets marker attributes `WindUp`, `WindUpKind` ("quick" | "big"),
  `WindUps`; `MonsterController` glows the boss (orange big, red quick).
- Sword moves were keyed in Blender on the R15 body (`tools/blender/anim_kit.py`), exported per frame to JSON and turned
  into KeyframeSequences by `tools/anim/build_kfs.luau` (docs/animations.md); the owner publishes them.
- Creature attacks are instant in the sim: there's no event before a creature's or boss's auto-attack lands today.

## Design

### 1. Creatures

**Moving** (owner): during a fight a creature doesn't stand still. It circles its fight spot / the target at a short
distance, darting about, facing its target. Purely visual on each client (the server's marker stays the truth; sims
don't use creature positions). It pauses to charge.

**Charging** (owner): before each attack it stops for a beat, crouches, and a glow in its element colour builds on it.

**Attacking**: by element **(my call, owner accepted the playback)**:

| Element | Normal attack | Element ability (Pet button), bigger |
|---|---|---|
| Ember | a fireball that arcs to the target and bursts | Fireball: a big charged fireball, bigger burst |
| Tide | a water blast that splashes | Wave: a water wave washing over your creature (it heals) |
| Bloom | a 3-hit vine whip | Vine Snare: vines wrap the target (it's slowed) |
| Volt | a lightning zip to the target and back | Overcharge: a crackling aura, then rapid zips |
| Shade | a 3-hit shadow-claw combo | Curse: dark mist swirls on the target (it hits weaker) |

Epic and Legendary **signatures** get their own effect per signature kind (`Combat.SIGNATURES` kinds: Inferno,
TidalShield, Stampede, Eclipse, Supernova, Devour).

A 3-hit combo is one sim attack: the visual shows three quick hits, the damage number appears once on the hit that
matches the sim's (the last, or split visually: builder's call as long as the total matches and numbers don't lie).

**Timing**: the sim decides when an attack lands. To show a charge and a projectile *before* it lands, the client needs
to know an attack is coming: the sim emits a new event shortly before each auto-attack of a creature (and of a boss or
wild monster, for their wind-ups), e.g. `{ type = "charge", from = id, to = target, seconds = lead }`, `lead` from
config. The client schedules charge, release (projectile flight) and impact so the impact lands with the `attack`
event. This must not change any fight's outcome or draw extra randoms (existing BattleSim tests and the balance tool
numbers must stay the same). Abilities and signatures are used on command and land at once today; they get a short
release animation that ends with the event (or the builder adds a small sim delay if that reads better and the
balance tool shows no change).

**How it's made (my call)**: no per-creature hand animation. Poses come from the bones creatures already have
(`PetRig` / `PetAnimator`: crouch, lunge, bite, swipe, tail lash), chosen by body type the rig guesses; creatures
without bones (placeholders) just move and glow. Effects are built in code (Parts, ParticleEmitters, Beams, Trails,
uploaded textures) like the sword's sparks and rings; Blender effect sheets (flipbooks, like the pack opening's) only
where code can't look good enough.

### 2. Bosses (1-3 and the Prism Hydra)

**Normal attack** (owner): no ring. A short wind-up (rear back, raise a limb) while today's warning glow shows, then a
strike that fits the boss's body, and an impact effect where it lands (dust burst, claw slash, element flash). Used for
both its auto-attacks on creatures and its quick hits on players (the quick hit keeps its warning so dodging works).

**Special attack** (owner): the ring on the ground as today, plus a big wind-up during the ring's warning (roar, rear
up, gather energy; element particles pull in, the glow grows) and a release effect matching the ring's shape: a slam
becomes a shockwave with flying debris; a swipe cone becomes a wide slash arc or breath blast. Bigger bosses look
bigger.

**One special per boss, one ring shape each** (owner). Today every ring is a 50/50 slam or swipe draw
(`BattleSim.luau` near line 607), per player. Each boss gets a fixed shape in `Config/Bosses` instead; the sim keeps
drawing that random number and ignores it, so outcomes and the balance tool don't move. Moves and shapes **(my call;
the owner saw the moves in the playback)**:

| Boss | Normal | Special | Ring shape |
|---|---|---|---|
| Meadow Warden (Bloom) | branch swipe | root slam: roots burst from the ground | slam (circle) |
| Cave Brood Queen (Shade) | claw stab | web spit: a sticky spray | swipe (cone) |
| Ember Colossus (Ember) | fist punch | lava slam: molten shockwave | slam (circle) |
| Frost Tyrant (later visuals) | - | - | slam (circle) |
| Storm Sovereign (later visuals) | - | - | slam (circle) |
| Rift Devourer (later visuals) | - | - | swipe (cone) |
| Prism Hydra (by phase) | head bites | prism beam, coloured by the current phase's element | swipe (cone) |

**Ring colour** (owner): the warning rings turn orange (or a similar, more noticeable colour) instead of today's look,
so they stand out on every arena floor. The exact colour is picked from a mockup at the start of the boss phase.

Each strike's impact frame lands exactly when the sim's hit lands.

**Wind-up vs. the dodge cue (my call)**: the sim picks whether a swing hits a creature or becomes a quick hit on a
player only at the swing (`swingAtPlayer`, a random draw), and that must not move earlier (outcomes unchanged). So
before every swing the boss's body does a short **neutral** wind-up (no glow) from the new charge event; at the swing,
a creature hit strikes at once, while a quick hit turns the glow red (today's dodge cue, unchanged) and the body holds
then strikes when the hit lands. Red still means "dodge now". In a group fight, one body plays one strike: the earliest
landing one (creature hits are instant); player quick hits show their red glow and strike on the player targeted when
they land.

**How it's made (my call)**: keyed in Blender on each boss's existing bone rig and exported like the sword moves, with
a bone-rig version of the anim pipeline (the sword kit targets R15 Motor6Ds; bosses are skinned meshes with bones).
`src/client/Util/KeyframePlayer.luau` already plays KeyframeSequences on creature bones on the client with no upload,
so these may not need the owner's publish step (builder's call). While an attack animation plays, `PetAnimator`'s procedural motion on those
bones yields to it and blends back after. If keyed animation on a bone rig turns out not to work well in Roblox, the
builder may fall back to procedural poses, after showing the owner both (as was done for the sword moves).

### 3. Wild monsters

**Normal attack only** (owner), with an animation and an effect. One attack per species **(my call)**: Ash Wolf lunging
bite, Cave Bat dive, Magma Golem ground punch, Mossling headbutt, Puddle Crab pincer snap, Spark Beetle horn charge with
sparks. Keyed in Blender like the bosses (same pipeline), same timing rule (impact with the `attack` event).

### 4. Boss debuffs

Owner asked; agreed on these rules:

- **Only a special attack (ring) hit gives it**, and only to the player hit (not creatures; the Storm Sovereign's
  thunderclap already stuns creatures). Dodging or leaving the ring = no debuff.
- **Short and mild**: 2-4 s. No stun over 1 s.
- **Visible**: an icon with a countdown next to the player's portrait on the combat HUD, and an effect on the
  character (green bubbles for poison, flames for burn, ...).
- **One per boss, by element** (values are starting points for the balance tool):

| Boss | Debuff | Effect |
|---|---|---|
| Meadow Warden | Entangled | slowed a lot (movement) for 2 s |
| Cave Brood Queen | Poison | loses a little HP over 4 s |
| Ember Colossus | Burn | loses HP over 3 s, a bit faster than poison |
| Frost Tyrant | Chilled | slower movement and a slower dodge recharge |
| Storm Sovereign | Shocked | stunned (no attack, no dodge) for 0.5 s |
| Rift Devourer | Weakened | sword hits weaker for 4 s |
| Prism Hydra | by phase | its current phase's element uses the matching debuff above; Shade (two bosses) uses Poison **(my call: it reads for every player, Weakened only matters to sword users)** |

- A new hit while debuffed refreshes it (no stacking) **(my call)**.
- Server-authoritative: the sim (or `BattleService` for movement speed) applies them; HP loss goes through the sim like
  other damage and counts toward the player going down.
- Later potions and food can clear them (not in this project).
- **Balance**: Poison and Burn damage (and the others' effects) go into `tools/balance/bosses`, and bosses get retuned so
  the existing targets hold (well 85% / 50%, still 60% / 15%), as for fight perks.

## Order (phases)

1. Creature attacks (seen in every fight).
2. Boss attacks (bosses 1-3, then the Hydra).
3. Wild monster attacks.
4. Boss debuffs (all 7 bosses' logic; visuals on the HUD and characters).

Each phase starts with a mockup or render the owner approves before it's built (owner rule: always show mockups for
visual decisions), and ends with a Studio check the owner judges.

## Constraints

- Project rules in `CLAUDE.md` (server authoritative, numbers in `src/shared/Config`, pure logic in `src/shared/Util`
  with Lune tests, docs kept in sync, `--!strict`).
- Performance: phones in group fights (up to 4 players: 4 creatures, 4 players, a boss, adds). Effects respect the
  existing low-graphics switch (`Extras.enabled()` used by `MonsterController`) and the town perf rules.
- Text in UI: ASCII plus `·` and emoji only.
- Assets: no ripped game audio; sounds from Roblox's licensed Pro Sound Effects, as for the sword.
- Animations the owner publishes must be owned by the game's owner (a user account).

## Left to the builder

- Exact orbit pattern, charge length, projectile speed, particle counts, colours (within the mockups the owner approves).
- How body types map to procedural creature attack poses.
- The bone-rig export details and file layout of the new animation pipeline.
- Sounds for creature, boss and monster attacks (from Pro Sound Effects).
- Exact debuff numbers after the balance retune.
