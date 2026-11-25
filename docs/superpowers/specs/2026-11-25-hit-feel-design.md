# Hit feel: monsters that react and come alive

Owner 2026-11-25: "the hits feel weak and monsters just stand there". Picked "stay near their spot but feel alive" (not
real chasing), felt a throwaway test (branch `combat-feel-spike`): "strong feels good", then "stepping is a bit
twitchy" until calmed, then "stepping feels good now". Picked approach A: build what was felt, properly.

## Why

- A monster hit by your sword flashed faintly (fill 0.35 for 0.12 s) under a 0.12-stud camera shake; hit by a
  creature it showed nothing on its body. Nothing ever moved it.
- The 12 valley monsters (Wild and Frontier) have only a wind-up and a strike clip: between attacks they stood frozen
  on their spot. Bosses and the Dungeon's packs already walk round their spot (Util/BossIdleRules, Config/Bosses
  IDLE, IDLE_PACK).

## Approaches

- **A (picked): the felt test, built properly.** Whole-body reactions and stepping on the client, numbers in config,
  pure rules Lune-tested, a cap on how far a monster drifts from its server spot, one reused flash per monster.
- B: A plus keyed flinch and idle clips per valley monster (24 Blender clips): later, if bodies still look stiff.
- C: the server moves the monsters (honest positions, groundwork for chasing): not now; chasing was declined.

## Design

1. **Every hit on a monster reacts** (`MonsterController.React(marker, from, big)`): a white flash (one Highlight per
   monster, reused: fill 0.05 at its strongest, fading over 0.2 s), a jolt away from the hitter and a lean back (1.1
   studs and 15 degrees; out in 0.05 s, back over 0.32 s), a pop to 1.08 of its size, and its own clip frozen 0.07 s.
   A big hit (your finisher, the dash slash, a creature's finishing hit, a super) knocks 2.6 studs, leans 1.4 times as
   far, comes back over 1.6 times as long and freezes 1.5 times as long. A boss takes 0.35 of the jolt and the lean and
   never pops. A fainted monster doesn't react; a summon still climbing out of its rift doesn't pop.
   Hits that react: your and your group's sword hits (BattleController's sword hit, which drew the old faint flash),
   creatures' attacks landing (FightFx: every basic attack, each hit of a combo, the finishing hit big) and supers
   landing (big). Pet button moves don't (their own looks run over time).
2. **Your sword hits shake the camera 2.5 times as hard** (`SwordFx.SHAKE` cut 0.12 -> 0.3 studs, skill 0.3 -> 0.75).
3. **Wild monsters come alive** (valley and Frontier monsters, not bosses or Dungeon packs, which keep theirs): they
   step round their spot like the packs (`BossIdleRules`), calmly: a step every 1.6 to 3.2 s at 4 studs a second,
   within 2.2 studs (0.88 in front, half the radius behind), turning only 30% toward each step so they keep facing the
   fight. They lunge 2.6 studs forward into each strike (out by 30% of the clip, held to 55%, back by its end).
4. **Drift cap**: a wild monster's steps and lunge never take it more than 3 studs (horizontal) from its server spot,
   so a sword swung at what you see still lands (the server judges hits at the spot). A hit's jolt sits on top
   (brief).

All numbers in `Config/HitFeel` (plain data); pure rules in `Util/HitFeel` (reaction, its curve, the clip freeze, the
lunge curve, the drift cap), Lune-tested. The test's `/feel` command and `Util/FeelSpike` are not carried over.

## Not in this round

- Keyed flinch / idle clips (approach B). Real chasing (C). Pet button moves' reactions. PvP (no monsters).

## Tests

- `tests/HitFeel`: a hit pushes away from the hitter (and straight back when the hitter stands on it); a big hit
  knocks further, longer and freezes longer; a boss takes the share and no pop; the curve is 0 at the hit, full at
  0.05 s, gone after its back time; the freeze window; the lunge's shape and end; the drift cap leaves small offsets
  alone and pulls big ones back to 3 studs; the config holds the felt numbers.
- Studio: a wild fight with a weak creature (flashes, jolts, steps, lunges, no errors), a sword fight, a boss hit,
  then the owner's check.
