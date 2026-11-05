# Pet moves: finished looks and sounds (design)

Date: 2026-11-05. Owner approved the four looks from the animated mockups (`.superpowers/brainstorm/13775-1793692558/content/pet-moves-looks.html`, "yes proceed").

## Why

The owner, after playing: the creatures' moves "look and sound unfinished. every creature." Today every Pet button move
plays one shared wind-up (lift, glow, a spinning ring, the name on a plate), then a basic effect (`ElementFx.special`: a
water dome, five green sticks, an aura, a mist), with the same chime for every move plus its element's normal hit
sound. No move has its own sound, and nothing changes with the card's grade.

This round finishes four of the five Pet button moves (one per element, shared by every creature of that element: 36
creatures in all). Fireball (Ember) is already right and stays as it is. The ten super moves come in a later round.

## The owner's rule for every move

**The higher the creature's grade (C, B, A, S), the better the move must look and feel: its animation, its effects or
both.** C is clean and readable; S is a big moment. Each grade is a clear step up from the one below, never a copy.
This applies to all four moves here and to every move finished later.

## The four moves

Mechanics change only where stated. The numbers below are the owner's, except the ones marked *(my call)*.

### Healing Rain (Tide), was "Wave"

- **Rename:** the move is "Healing Rain" (kind `Rain`). The owner: "rename it to Rain or something since it heals".
- **Mechanic change:** it no longer heals 25% at once. It heals 25% of max HP **over time**: 5 ticks of 5%, one a
  second, the first a second after it lands *(my call: 5 seconds, mirroring Inferno's burn ticks)*. Same targets as
  today: the caster's owner's own standing creatures (in a group fight, never other players' creatures).
  - Casting it again while it runs restarts the 5 ticks; it never stacks *(my call)*.
  - A creature that faints or is swapped out stops healing *(my call)*.
- **Look:** a rain cloud forms over each creature it heals and rain falls on it for the 5 seconds; the creature glows
  soft green-blue; each tick shows a rising "+N" (the real amount) over it, so you can see it healing.
- **By grade** (from the mockup):
  - C: small grey cloud, light drizzle, soft glow, small ticks.
  - B: fuller cloud, steady rain, splashes ripple round its feet, brighter ticks.
  - A: big silver-lined cloud, heavy rain, healing motes rise off the creature, the glow pulses with each tick.
  - S: glowing cloud under a rainbow, shimmering rain, water rings rise round the creature, gold ticks.
- **Tooltip:** the Pet button's tip for Tide reads "Heal your creature over time." (the only combat UI text that
  changes; the owner approved it in the playback).

### Vine Snare (Bloom)

- Mechanic unchanged: the target's attacks are 40% slower for 4 s.
- **Look:** real, noticeable vines or roots burst out of the ground under the target, wrap round its legs and body,
  hold for the 4 seconds while it struggles, then wither and sink. They fit the target: small round a Mossling, huge
  round the Ember Colossus *(my call)*.
- **By grade:**
  - C: two thin vines curl round its legs.
  - B: three leafy vines climb up its body.
  - A: four thorny roots burst out in a spray of dirt and wrap it.
  - S: five huge roots erupt from a glowing crack, bind it top to bottom and burst into flower, with pollen drifting.

### Overcharge (Volt)

- Mechanic unchanged: the next 3 attacks come twice as fast.
- **Look:** three electric orbs appear and circle the creature. **Each of those 3 attacks spends one orb**: the orb
  flies out with the attack and bursts on the target *(my call: it flies with the hit rather than just popping)*. When
  the last one is gone, the move is over. Orbs left over when the creature faints, is swapped out or the fight ends
  just fade.
- **By grade** (the owner: "the higher grade the bigger and dangerous looking the electric ball"):
  - C: three small pale orbs, slow spin.
  - B: bigger, brighter orbs, faster spin.
  - A: crackling orbs with sparks jumping between them; each hit lands with a bolt.
  - S: big blue-white storm orbs chained by lightning; each hit is a thunderbolt with a screen flash (yours only).

### Curse (Shade)

- Mechanic unchanged: the target hits 30% weaker for 5 s.
- **Look:** a dark rune circle opens under the caster while it casts (the owner: "a pentagram-ish below the creature").
  It's a seven-point star in a ring with runes *(my call: not an exact five-point pentagram, so its texture can't trip
  Roblox's image moderation)*. Then a big, noticeable curse sigil (a glowing eye in a broken ring, dripping) sits over
  the target with a dark aura round it, and the target darkens, for the 5 seconds it is weakened.
- **By grade:**
  - C: a faint rune circle; a small sigil, a thin dark haze.
  - B: a brighter spinning circle sends a hex across; the sigil glows over a dark aura.
  - A: a double rune circle; shadow chains hook the target; a pulsing sigil and dark smoke.
  - S: a big blazing rune circle with violet flames; the target goes dark under a huge sigil and pouring shadow.

## Animation

The creature's own motion grows with grade as well as the effects *(my call on how)*: the wind-up lift and the cast
pose are bigger at higher grades (a small hop at C, a big rear-up at S), and each move may use the pose that suits it
(Vine Snare a stomp that raises the vines, Healing Rain looking up into the cloud, Overcharge a shiver as the orbs
appear, Curse a raised cast over the circle). The shared wind-up stays (the owner's design A from 2026-11-04: the lift,
the glow, the ring, the name plate); its name plate reads "HEALING RAIN!" for Tide.

## Sound

Each move gets its own sounds instead of the shared chime, all Roblox-licensed (Pro Sound Effects or APM, found through
the toolbox API as in the memory note `licensed-sound-search`; never user uploads):

- Healing Rain: a rain shower for its 5 seconds and a soft chime with each tick.
- Vine Snare: an earthy burst as the vines break the ground, creaking wood and rustling leaves as they wrap.
- Overcharge: an electric hum while orbs remain and a zap as each one is spent (a thunder crack at S).
- Curse: a dark magic swell as the circle opens, a hex hit on the target and a low drone while it's cursed.

Higher grades sound bigger *(my call)*: an extra layer at A and S (a heavier impact, a deeper boom). The volumes sit
with today's fight sounds (`AttackFx.VOLUME`, the pitch and loudness spread in `AttackFx.VARY`). The owner judges by ear
in Studio and can ask for swaps.

## Who sees it, and where

- The look plays wherever the move fires: wild fights, boss fights (solo and group) and the arena, for every player
  watching (fight effects are client-side, from the sim's events). Grade comes from the creature's card copy (the
  fight view's `grade`, as the basic attacks already use through `AttackFx.GRADE` / `FightFxRules.tier`).
- Grade changes only the look, sound and animation. Damage, healing, slow and weaken numbers do not change with grade
  in this round.

## Constraints

- **Combat UI untouched** (the owner's standing rule), apart from the Tide tooltip text above. No new buttons, no
  layout or style change to the fight HUD.
- **Cheap.** 60 fps on phones in a group boss fight with four creatures casting. Effects stay inside the existing fight
  effect budget (`AttackFx.MAX_ACTIVE`, `MAX_ACTIVE_LOW` with the low-graphics switch off) and clean themselves up. With
  the low-graphics switch off, a move plays no richer than its B look *(my call)*.
- **Server authoritative.** The heal ticks happen in the sim (`server/Util/BattleSim`); clients only draw. Overcharge's
  orbs follow the sim: the client learns from the sim's events which attacks spend an orb, it never counts on its own.
- **Textures** (rune circle, sigil, rain streak, orb glow...) are made by scripts like the other fight textures
  (`tools/textures/`), white with alpha and tinted in game, uploaded as images, ids in config. Models (vines or roots),
  if used, come from Blender in background mode like the other props.
- Numbers live in config (plain data, Lune-tested), pure rules in Roblox-free modules, as everywhere in this project.
- DESIGN.md's ability table and the fight effects paragraph (section with "Pet button moves and super moves wind up
  first") are updated with the change.

## Seeing it in Studio

The owner judges every move at every grade. A Studio-only way to play each of the four moves at a chosen grade quickly,
without a long fight or owning sixteen cards, is part of this work *(my call on the exact form, e.g. an Admin panel
button per move and grade)*.

## Balance

Healing Rain heals the same total, later. Run `lune run tools/balance/bosses` before and after and report the Tide
rows; if the change moves a Tide card's win rate out of the targets in CLAUDE.md, say so and propose a fix (for
example a slightly bigger total) rather than shipping silently.

## Non-goals

- Fireball (done) and the ten super moves (a later round).
- Normal attacks, boss moves, the debuff looks on players.
- Any change to cooldowns, wind-up length, or the Pet button.

## Anti-goals

- A move that still reads as "a coloured blob": each one must show what it does (rain that heals, vines that hold, orbs
  that get spent, a curse you can see on the foe).
- Grades that look the same, or an S look so heavy it drops frames on a phone.
- Any sound that isn't Roblox-licensed.

## Edge cases settled *(my calls)*

- The heal ticks need their own event type: the sim's `heal` event already means a boss healing itself (it shows the
  "Healing!" banner and shakes the screen).
- A stunned creature skips attacks while its fast attacks still count down. Orbs follow the attacks that really
  happen; any orb not spent when Overcharge's fast attacks are used up fades.
- In a fight with two of your creatures out (a wild fight after a call-in), each one healed gets its own rain cloud.

## Left to the builder

How each look is built (particles, beams, parts, meshes), the exact sounds, the poses, the preview tool's form, and the
event fields the client needs (for example which attacks spend an orb, and each heal tick).
