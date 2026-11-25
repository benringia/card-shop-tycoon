# Finishing blow: the last hit lands

Owner 2026-11-25, after the hit feel: picked A of five combat ideas, the finishing blow, "but no KO popout" (C elite ring
moves, D bigger element callouts, E keyed flinch clips: later; B sword crits and combo not picked). Felt a throwaway
test (branch `finisher-spike`): "strong feels good, freeze the creature too", then "go ahead" on this design.

## Why

A fight's last hit looked like any other: a beaten wild monster held 0.07 s (Config/MonsterKO hitStop) under a 0.3
kick and flew; a beaten boss tipped over at once. Nothing marked the moment you won.

## Approaches

- **Build what was felt (picked; the one sensible way):** a client moment at the knockout, which already starts from
  the server's beaten mark (Fainted) on the last hit.
- Real slow motion: Roblox has no time scale; slowing physics, particles, clips and sounds by hand is big and fragile.
  The hold already reads as the beat.
- A server "finishing hit" flag on the attack event: it arrives with the beaten mark anyway; no gain.

## Design

1. **Only your own fight's last hit, a win** (the fight still running on your screen and the beaten monster its
   monster): every member of a group fight gets it on their screen; anyone else nearby sees today's knockout. The
   beaten mark reaches the client before the fight's end message (the knockout's coins already rely on that).
2. **Wild monster** (valley, Frontier, a Dungeon room's pack): everything holds 0.16 s: the monster in its white flash
   and swell (MonsterKO's beat, longer), your character's animations, and every creature in the fight
   (CreatureController.Freeze). Your camera punches in 8 degrees in 0.05 s, holds, eases back over 0.35 s; a deep thud
   (Pick Impacts 1, volume 0.7); then the knockout launches 1.25 times as hard with a 0.6 kick (elites keep their own
   extra on top). No "KO" text.
3. **Boss**: everything holds 0.4 s: the boss's whole body (its clip and its tip-over; the Hydra's heads drop after),
   flashed white (fill 0.7, fading over the hold and 0.25 s), your character, the fight's creatures. Your camera punches
   in 11 degrees, a deep boom (Deep Hits Big Reverberant Booms 2, volume 0.7), your screen flashes white at 30%
   fading over the hold and 0.2 s, a 1.2 kick; then its death scene and the victory as today.
4. **The camera punch** shares the sword's zoom (SwordController: a finisher cut's hang and the punch never cut each
   other short, the latest owns the view); skipped while a skill's or a super's camera moment owns the view, or the
   camera isn't the player's.
5. **The server keeps a beaten wild monster 2.7 s** (Config/MonsterKO SERVER_SECONDS, was 2.6): the knockout with the
   longer hold (2.59 s) still ends at least 0.1 s (latency) before the server lets the monster go.

Numbers in `Config/FinishingBlow` (plain data: WILD and BOSS moments). Pure rules in `Util/FinishingBlowRules`: the
knockout's beat, launch and kick with or without a moment (elites on top), the whole knockout's length. Client
`Util/FinishingBlow` plays the moment through hooks BattleController wires (which monster is your fight's, the camera
punch, the creatures' hold). The test's `/finisher` switch and `Util/FinisherSpike` are not carried over.

## Not in this round

- A "KO" pop or any text. Slow motion. Others' fights. PvP (no monster). The prologue's Hydra (never beaten).

## Tests

- `tests/FinishingBlowRules`: the felt numbers; holds are beats, not stalls (wild at most 0.2 s, boss 0.5 s); no moment
  gives MonsterKO's own beat, launch and kick (elites' extra included); a moment gives its hold, its launch and kick
  times an elite's extra; the knockout with the wild hold ends at least the margin before SERVER_SECONDS.
- Studio: a wild win (your character, the creature and the monster hold; FOV in and back; launch), a boss win (body,
  clip and tip held, flash, FOV), a phone in the Device emulator (the punch on a phone's fight camera), no errors; then
  the owner's check.
