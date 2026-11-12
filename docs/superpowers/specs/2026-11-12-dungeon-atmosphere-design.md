# The Dungeon's atmosphere: the Hydra's welcome, objectives, danger

Owner 2026-11-12: "when entering a room there should be a small objective at the top right of the screen guiding
players on what they need to do; arenas should be bigger; now design the dungeon: immersive, sound, dangerous feels,
ambiance", and for the opening "a cinematic with something like the hydra's eyes but not showing the hydra yet, some
roars, some eerie music". Storyboard `.superpowers/brainstorm/10083-1794407287/content/dungeon-intro.html`; the owner's
"go" with one change: **the objective is simple text, no box**. Builds on `2026-11-11-dungeon-puzzles-design.md`.
Launch 2026-11-20.

## Why

The run plays well but feels like a lit corridor. The final boss's lair should feel like walking into something's
mouth: the Hydra is there from the first second, never seen until its chamber. And kids must always know what to do
next (the anti-goal of the puzzles round).

## Goals

1. **The welcome** (about 9.5 s, every player's own camera, when the run opens): (1) the way back slams shut behind
   you, dust; (2) the hall's braziers die one by one, eerie music starts (drone + soft choir); (3) the camera drifts
   into the dark, drips and breathing; (4) one pair of glowing eyes opens deep in the dark, the music drops out; (5)
   four more pairs open, high and wide apart, each head's element colour (the Hydra's `heads`), five growls; (6) the
   eyes narrow, a huge roar, the screen shakes, dust rains, the wall crystals flare; (7) the eyes snap shut, the title
   "THE DUNGEON / Something waits below..." with one heartbeat, then the camera eases back to you and the objective
   appears. **The Hydra is never shown.** The full welcome plays the first time a player ever enters; after that a
   ~3 s short one (eyes open, roar). Anyone can skip (a Skip button, tap or click). Saved: `data.dungeon.seenIntro`
   (part of schema 19, not released yet: the v19 migration adds it with `secretFound`).
2. **The objective**: top right, plain text (no panel, no box): a small "OBJECTIVE" label over one short line, with
   its progress where there is one. Per step: "Defeat the guardians" (monsters left), "Lead the light to the prism",
   "Hold every plate" (held/needed), "Break the crystal pylons" (broken/3) then "Defeat the guardians", "Strike the
   crystals in the door's order" (lit/5), "Defeat the Prism Hydra". A soft chime and a small pop when the step changes.
   Readable on any background (white text, dark outline), clear of the mobile buttons; hidden during the welcome.
3. **Bigger arenas**: the fight rings about 40% wider (radius 28 -> 40), the Hydra's chamber 36 -> 48 (its own
   `arenaRadius`); the cavern's layout follows.
4. **Danger all the way down** (client only, no damage): now and then the Hydra's eyes open for a moment in a dark
   spot ahead and vanish; a distant roar about once a minute (dust falls round you, a small tremble), louder room by
   room; music that tightens towards the chamber (the eerie bed, then a heartbeat layer near the end); spot sounds
   round you (drips, pebbles, chains, whispers, crystal chimes) through the Soundscape system; thicker fog and darker
   light, the crystals and braziers the light.

## Non-goals

- Traps or hazards that hurt players (danger is a feeling: the owner's "dangerous feels").
- Showing the Hydra before its chamber; a new boss intro (its fight intro stays).
- Changing the puzzles, fights or balance (bigger rings don't change the fights' numbers).

## Anti-goals

- A long unskippable cutscene every run (kids replay the Dungeon: short after the first time, always skippable).
- Spooky enough to scare young kids off: eerie and big, no jump-scare flashes or screams.
- Ambience that costs phones frame time: few lights, sounds through the existing systems, effects only near the camera.

## Constraints

- Server authoritative: the welcome and ambience are client looks; the server only says when the run opens and which
  welcome (full/short) from the save, and marks it seen.
- Every tunable number in `Config/Dungeon` (INTRO beats, AMBIENCE timings and volumes, OBJECTIVES text); pure logic
  (which welcome, the objective's line, the next roar, how loud) in Lune-tested modules.
- Sounds: licensed Pro Sound Effects / APM (like the Wild's); music quiet (the owner's Wild audio taste).
- Text: plain ASCII plus emoji, FredokaOne / Montserrat (CLAUDE.md UI rules).

## Left to the builder

Exact camera path and timings within the beats, which sounds (searched in the licensed libraries), the eyes' look
(glowing parts or billboards), dust and shake sizes, the objective's exact font sizes and position, how the music
layers. Calls made without the owner: the short welcome after the first time; skip always available; danger never
hurts; fight rings 40 and chamber 48.
