# The Dungeon run: puzzles, crystal ruins, a new Prism Hydra

Owner decisions 2026-11-11. Builds on `2026-10-29-dungeon-final-boss-design.md` (the place, the gate, the run, carried
HP, the Hydra's phases), which stays true except where this changes it. Launch is 2026-11-20.

## Why

The Dungeon today is three sealed rings of elites in a row and then the Hydra: the hardest place in the game plays
like a corridor of the same fight. The owner wants it to feel like a real dungeon: puzzles between the fights, a
place that looks like somewhere, a secret to find, and a final boss that looks as good as the Frontier's (its model is
the last blocky Blender build among the bosses).

## Goals

- The run (owner's order): **fight 1 → prism beams → fight 2 → weight plates (secret wall here) → fight 3 with shield
  pylons → element lock → the Prism Hydra.**
- Every puzzle is solvable alone, works for groups of 2-4, needs no reading, takes 30-90 s, and a wrong move only
  resets it (never hurts, never ends the run). Taps on walk-up prompts (ProximityPrompt) only, plus the sword inside
  the pylon fight (swords swing only in fights); no precise jumping.
- **"Make sure it's abuse proof"** (owner): puzzle state lives on the server, rewards are computed there, every action
  is a server-checked prompt with distance and rate limits, and the run's gates refuse to open early even if a client
  walks through a wall.
- A new look for the whole run: **crystal-grown temple ruins** (owner pick C): an old element temple the Hydra's
  rainbow crystals have taken over. Cool indigo stone, carved pillars, broken arches, floor tiles, rainbow crystal
  clusters pushing through. Concept: `.superpowers/brainstorm/10083-1794407287/content/look-c.png` (copy it to
  `assets/blender/DungeonProps/concept_look.png`).
- A **new Prism Hydra model from Meshy** (owner pick B, "temple guardian"): carved blue-grey stone armour plates with
  glowing rune lines between them, rainbow prism crystals bursting from its back and shoulders, a crystal gem on each
  forehead, five heads the same colour. Concept: `content/hydra-b.png` (copy to `assets/blender/PrismHydra/concept_B.png`).

## Non-goals

- New monster species. Fight rooms keep the Frontier's species (owner: "reuse crystal frontier for non boss monster").
- Changing the Hydra fight's rules, numbers or phases. Only its model and look change.
- Changing the gate, the fragments, groups, carried HP, "out" rules or the conquest rewards.
- A second dungeon or harder puzzle variants (later, maybe).

## Anti-goals (it fails even if it works if...)

- A puzzle can be skipped, solved for someone else's reward, or farmed (enter, solve, leave, repeat) for more than the
  fights already pay.
- A kid gets stuck with no idea what to do: every puzzle must be readable from what it shows (a beam that sparkles where
  it stops, plates that light when pressed, the door's symbols in order).
- The rooms cost frame time the town budget can't afford on phones (`town-design-perf-rules`: re-measure).

## The run, room by room

The cavern keeps running along +X from the entrance hall (`Config/Dungeon`, `Util/DungeonBuilder`), now longer: hall →
room 1 (fight) → beam room → room 2 (fight) → plate room (secret alcove off its side) → room 3 (pylon fight) → lock
room → the Hydra's chamber. Each section is sealed by a door the server opens when the section before is done; the
next fight's "Fight" gate also refuses to start until then (the real gate: walls can be walked through by exploiters,
fights can't be started). The run line shows the new steps ("Prism beams", "Weight plates"...). `/room` and the admin
panel's Dungeon section learn the new steps; add `/puzzle solve` (the current puzzle solved, Studio only).

All players in the run share each puzzle (anyone can work any piece). Only members of the run who aren't out can
touch a piece. A puzzle solved stays solved.

### 1. Prism beams (after fight 1)

A beam gem on one wall shoots a golden light beam across the room; 4 crystal mirrors on stands stand on a grid. Tap a
mirror ("Turn") and it turns a quarter (server, rate-limited per player, 0.4 s). The server traces the beam from the
gem through the mirrors; the client draws it along the path the server sends (segments), sparkling where it ends.
When it reaches the door's prism, the prism lights up and the door opens. Wrong turns just send the beam into a wall:
no timer, no fail. Three hand-made layouts; the run picks one by its seed, so it isn't the same every run. The beam
logic is a pure, Lune-tested module (grid, mirror facings, trace, solved). Each layout must be tested solvable and not
solved at the start.

### 2. Weight plates (after fight 2)

Two stone plates (three for runs of 3-4 players); the door opens once all are pressed at the same time, then stays
open. A plate is pressed by a run member's character standing on it (the server checks each member's root position
inside the plate's box every 0.25 s) or by a member's summoned creature **sent** there: tap a plate ("Send
<creature>") and your summoned creature walks onto it and sits. The server already moves each summoned creature's
marker (`workspace.Creatures`, PartyService); sending walks that marker to the plate and holds it there (one plate per
player's creature, released when you resummon, unsummon, leave the room or tap the plate again), so it is server
state, never a client position. Solo: stand on one, send your creature to the other. Plates glow when pressed. A player
who has no creature summoned gets told to summon one. The plates needed are never more than the active members can
cover: `min(plates, 2 x members not out)`, the others dim (a 4-player run down to one player still needs only 2).

**Secret wall:** one wall of the plate room has faint glowing cracks. Tapping it ("Break": your character swings its
sword at it; 3 taps, rate-limited, the cracks spreading) breaks it open for everyone and shows a small alcove with the secret chest. Each run member may
open it once per run (below).

### 3. Fight 3 with shield pylons

The room's pack stands inside a crystal shield fed by 3 pylons round the room (a beam from each pylon to the shield).
While any pylon stands, nothing hurts the pack (creatures' hits and the player's sword show "Shielded!"). Unlike the
other Dungeon rooms (creature-only today), **players fight in this room as in a wild fight** (Attack, Dodge, sword
skill, quick hits on players): their Attack hits the nearest standing pylon while any stands, then the pack. Each
broken pylon cuts its beam and the shield flickers; the last one shatters it. Pylon HP so a player fighting well
breaks all 3 in about 15 s. Rebalance room 3 with `tools/balance` so the run reaches the Hydra as often as today (the
Hydra reached every time with 78-89% HP left at `bosses 200 1 7`). Pylons are server-side targets with HP, damaged
only by the server's own sword hit checks (SwingGate, distance).

### 4. Element lock (after fight 3)

The door shows the Hydra's five phase symbols in order: Tide, Volt, Shade, Bloom, Ember (from `Bosses.prismHydra
.phases`, not hard-coded). Five element crystals stand round the room in a different order. Tap them ("Strike": your character
swings its sword at it) in the door's order; each right one lights its symbol on the door. A wrong one flashes red and the order
resets. The fifth opens the chamber. It teaches the fight: the phases come in that order next.

## Chests

Both reuse the boss chests' model (`Util/ChestModel`, the classic wood chest), smaller, standing in the room (a walk-up
prompt "Open"), not the reveal stage.

- **Puzzle chests:** one appears when each of the three puzzles is solved (beams, plates, lock). Each run member opens
  it once per run: cash and XP about one fight room's pay (the pack's elite XP and cash), through EconomyService. No
  cards or items. Runs need the Hydra open or 10 fragments and one run per reserved server, so this can't out-earn
  the fights.
- **Secret chest:** first find ever: the title **"Crystal Seeker"** over your name in every place (as Dungeon
  Conqueror, which outranks it when you have both). Later finds: a 25% chance of 1 `material_prismHydra` (a Hydra win
  gives it at 80%, 1-2), else a small cash chest. Needs a saved "found the secret" flag: bump `SCHEMA_VERSION` (18 →
  19), a migration with a Lune test, DESIGN 10.4.

## Look

- **Props:** a Blender pack `tools/blender/build_dungeon_props.py` (on the valley-props kit, smooth chunky shapes,
  flat colours, the owner's look C): carved pillars (whole and broken), broken arches, temple wall pieces, floor tile
  slabs, steps, rainbow crystal clusters (5 element colours), rune braziers; and the puzzle pieces: the beam gem, a
  crystal mirror on a stand, the door prism, a stone plate, a pylon, an element crystal, the element-lock door with
  five symbol sockets, the cracked wall and the alcove. One pack FBX the owner imports once and saves as
  `assets/props-import/DungeonProps.rbxm`, split by `lune run tools/props/split_pack` into `assets/props` (as the
  Frontier's; docs/props.md). Code-built stand-ins until they're in, so the puzzles can be played first.
- **Lighting:** cool indigo with rainbow crystal light; few real lights (phones), the crystals glow with
  emission/neon. A light Dungeon soundscape (drips, crystal chimes) through `Config/Soundscape` if time allows.
- **Monsters:** the fight rooms' Frontier species get a crystal look in the Dungeon only: a few rainbow crystal shards
  on the back and a soft rainbow glow, added by code to the model (client), stats unchanged.
- **The Hydra:** Meshy image-to-3D from concept B (one generation; ask before regenerating: credits), then the
  Frontier bosses' pipeline (prep, rig with five neck chains and jaws, clips, `assets/monsters/prismHydra.rbxm`,
  docs/creatures.md). Keeps today's size (scale so it stands about 25 studs), `ringRadius`, intro shot and the phase's
  head lighting (marker attribute `Phase`); its rune lines glow the current phase's element colour.

## Abuse rules (all pieces)

- The client only triggers prompts (and sword swings, already server-checked). The server checks: the player is a
  run member who isn't out, the piece belongs to the current step, the player is within the prompt's distance
  (rechecked server-side), and the action's rate limit (`RateLimiter`).
- Doors and gates: the server opens them. A fight gate or the chamber gate refuses to start unless every step
  before it is done (`DungeonRules`).
- Plates count real character positions and server-side "sent" creatures only; a creature counts only while its owner
  is a member who isn't out and in the plate room.
- Chests: per player per run, rewards rolled and given on the server; the secret title from a saved flag.

## Build order

1. Rules (pure, Lune-tested): the run's steps, beam trace and layouts, plates pressed, lock sequence, pylon shield,
   chest eligibility.
2. The longer layout and the four rooms with code-built stand-in pieces; playable end to end in the Dungeon window.
3. Chests and the saved flag (schema 19).
4. The props pack (Blender), the owner's import, the split, the rooms dressed in look C.
5. Crystal monster look.
6. The Hydra: Meshy, rig, clips, rune glow.
7. Balance room 3, measure frame time, DESIGN/CLAUDE/docs.

## Left to the builder

Room sizes and exact positions; mirror grid size; pylon HP within the 15 s target; the chests' cash/XP within "about
a room's pay"; beam and shield effects; prompt texts; how the rune glow is coloured. Calls I made without the owner:
three beam layouts picked per run; three plates for 3-4 players; Crystal Seeker's later-find odds (25%, 1 material);
players fight in room 3 only; Dungeon Conqueror outranks Crystal Seeker.
