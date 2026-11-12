# The Dungeon as a world: the Crystal Abyss

Owner request, 2026-11-12: "the dungeon is still a wall and some props. I want it to be world designed. new world model,
like the frontier and wilds. portals/door design, room design and etc." The first thing a player should feel walking in:
**danger**. The owner picked concept **A, "The Crystal Abyss"**, from three
(`.superpowers/brainstorm/956-1794421508/content/world-a.png`; the pieces: `abyss-map.png`, `abyss-arena.png`,
`abyss-gates.png`; copies to keep in `assets/blender/DungeonWorld/` as `concept_*.png`).

## Intent

Today the Dungeon is a long box: a flat floor, two walls, crossing walls with doors, props scattered along the walls,
and the starry sky showing overhead. It works (the run, the puzzles, the welcome, the objective, the new Hydra are all
done and Studio-checked), but it does not look like a place. The Wild and the Frontier are worlds you look out over; the
Dungeon should be one too, and the scariest of the three.

The Crystal Abyss: a giant cave deep underground. A rock ceiling far overhead (stalactites, hanging chains), no sky.
Below everything a bottomless chasm with a faint violet glow. The run is a chain of floating stone islands linked by
narrow bridges, the crystal-grown temple ruins (the owner's look C from the puzzles round) grown into the rock. You see
the next islands ahead of you in the dark. At the end, the Hydra's round door, and behind it the Hydra's arena island.

## Goals

1. **A cave, not a box.** Rock ceiling, far walls lost in fog, no stars or sky anywhere in the place. The flat floor,
   the long side walls and the crossing walls are gone.
2. **Islands over a chasm.** Each step of `Dungeon.STEPS` (fight, beams, fight, plates, fight, lock) is its own island:
   the three fight rings are round islands (radius 40 as today), the three puzzle rooms square-ish islands that keep
   their pieces where the puzzles need them. Islands have rocky undersides hanging into the dark (a broken-off look).
   The Hydra's arena (radius 48) is the last and biggest island, reached through the Hydra's round door at the end of
   the lock island's bridge.
3. **Bridges between islands.** Narrow stone bridges (about 8 studs wide, low broken railings) link each island to the
   next; the chasm on both sides.
4. **The entrance ledge.** The run starts on a ledge against the cave wall: the spawn, steps down, the four hall
   braziers (`HALL_BRAZIERS`, the welcome puts them out), the way back behind you (the welcome's slab still slams it).
5. **The secret.** The plates island's cracked wall still hides the secret chest, now on a small ledge round the side of
   that island.
6. **Three gates, each its own model:**
   - **The Dungeon entrance in the Frontier** (`FrontierValley.DUNGEON_GATE`, today the borrowed `PortalArena` model):
     a cave-mouth stone arch split open in the ground, crystal-grown, five hydra heads carved on top, a violet swirl
     inside, steps going down into it. Its own portal model (`PortalDungeon`), like the Wild's and the Frontier's.
   - **The gate between islands:** a ruined stone arch at the far end of each island, sealed by a violet crystal barrier
     with a hydra-eye symbol until that step is done (today's `Door`/`PuzzleDoor_*`/door roles, same opening rules).
   - **The Hydra's door is the way in** (owner, 2026-11-12, over a backdrop in the cave wall as the concept drew it): a
     huge round stone door carved with a five-headed hydra coiled round it and five element gems as its eyes, standing
     at the end of the lock island's bridge on the arena's near (-X) side, where today's `ChamberDoor` stands. Its gem
     eyes are today's `LockSocket<n>`: they show the strike order right in front of the players at the lock and light
     one by one as the crystals are struck; it opens when the lock is solved, onto the Hydra's arena. The lock puzzle's
     code, the hint and the objective text stay as they are; only the door's look changes.
7. **Falling is death** (owner): a player who falls into the chasm dies and is out of the run, sent back to the Dungeon
   entrance in the Frontier, exactly like leaving the run today (`markOut` + `FrontierService.ReturnToFrontier`). In a
   group the others carry on. The fall is detected on the server (below a kill height under every island). The owner
   plans to let monsters attack and kill players later; that knockout should be able to use the same path.
8. **Danger in the look:** the chasm's glow from below, fog, dust, chains, broken railings, cracked islands. The
   atmosphere round's sounds, roars, glimpses and heartbeat carry over unchanged.

## Non-goals

- No change to the run's rules: steps, puzzles, chests, rewards, monsters, the Hydra fight, the objective lines, the
  welcome's beats (the shots may be re-aimed to the new geometry), the ambience.
- No saved-data change.
- No new monsters, no new boss model.
- No jumping puzzles or parkour: bridges are walked, never jumped.
- Monsters attacking players: planned later (the Wild danger round), not here.

## Anti-goals (a failure even if it works)

- Players falling because of the controls rather than their own carelessness (phone thumbstick drift, camera
  snapping, narrow corners). Falls should be rare and feel fair.
- Falling during a fight: the ring's barrier sits at the island's edge, so nobody falls while fighting. Creatures never
  fall either.
- Looking like the Wild's ember caldera or the Frontier: the Abyss is cool indigo and violet with rainbow crystal light.
- Phones choking: no huge neon planes, few lights, triangle budgets kept.
- Any of today's working pieces breaking: every puzzle, chest, prompt, the `/room`, `/puzzle`, `/tap`, `/dungeonfx`
  dev commands and the admin panel buttons keep working.

## Constraints

- Launch 2026-11-20 (`launch-list`); this round should land in about two days.
- Server authoritative: fall detection, out-of-run, return on the server (DungeonService). Islands and bridges are
  server-built; nothing a client sends decides a fall.
- Built like the Frontier: new props come from Blender scripts (`tools/blender/build_dungeon_props.py` extended, or a
  sibling `build_dungeon_world.py`) on `voxel_kit` / `portal_kit`, as ONE pack FBX the owner imports once and saves as
  `assets/props-import/<Pack>.rbxm`, split by `lune run tools/props/split_pack`. Each prop under 2000 triangles, big
  pieces (the Hydra's door, the entrance arch, an island underside) under 4000. Code-built stand-ins while the pack is
  missing, as today.
- The owner imports models in Studio; Claude never edits the place file without asking (the stray
  `Workspace.DungeonProps` pillar is still awaiting the owner's OK to delete).
- Streaming is on in the Dungeon (radius 1024); the whole run must stay inside what streaming and phones carry.
- Phones: few lights (today one crystal in four carries a light), fog and Atmosphere do the depth.
- Pure layout rules (island spots, bridge ends, the kill height below every island, rings inside islands) live in Lune-
  testable modules/configs, as `tests/Dungeon` does today.
- Text plain ASCII; colours and numbers in `Config/Dungeon`.
- DESIGN.md, docs/props.md, docs/creatures.md (if touched) and CLAUDE.md updated in the same change.

## Decided (by the owner)

- Concept A, the Crystal Abyss.
- The Hydra's door is the way into its arena (where `ChamberDoor` is today), not a backdrop.
- Falling = death: out of the run, back to the Dungeon entrance in the Frontier.
- The three gates as above (entrance portal, island gates, the Hydra's door), each its own design.

## My calls (the owner can overrule)

- **The path winds gently but runs +X overall**: islands sit alternately a little left and right of the line, bridges
  angle between them. The welcome's camera (eyes ahead in +X), the glimpses (+X) and the chamber's x stay valid. A fully
  winding path is out: it would rewrite those for little gain.
- **Bridges about 8 studs wide with low broken railings**: falls from carelessness, never from fiddly controls.
- **A fall:** a short scream and a fade to black on the client, then the server's return. No death screen.
- **Cave and island rock in Terrain** (like the Frontier's SceneryService terrain): the ceiling, the far walls, the
  islands' rocky undersides. Terrain is cheap to draw and looks like rock without new meshes. Ruins, gates, bridges and
  crystals are props.
- **The chasm's glow**: violet fog and Atmosphere plus a few large dim lights low in the chasm, or a far-down dark
  violet surface; never a bright neon plane.
- **The sky**: no stars anywhere (the ceiling hides it; the place's Sky set dark as well).
- **Light shafts** (today's coloured neon columns over the fight rooms) go: they break the cave's ceiling.

## Left to the builder

- Exact island spots, sizes and shapes within the goals; bridge lengths (the welcome's eyes, the objective and the
  run's checks only need the islands' pieces where they are today relative to each island).
- How islands are built (Terrain cylinders with a rock underside, props for the rims) and how many props dress each.
- The kill height and how the server checks it (a Heartbeat sweep of run members, a part below, both).
- The props list beyond the three gates (bridge segments, island rims, stalactites, hanging chains, the floor's hydra
  symbol, the entrance ledge's steps).
- How the Hydra's door's gems map to today's sockets, and how the island gates show "sealed" and "open".
- Re-aiming the welcome's shots to the new entrance ledge (the slab behind you, the braziers, the eyes over the chasm).

## Done when

- `lune run tests/run` passes, with layout tests for the islands, bridges, rings and kill height.
- In Studio, the owner walks the whole run in the Dungeon window: the cave, the islands and bridges, the three gates, a
  fall (out and back to the Frontier), every puzzle and fight as before, the Hydra's door lighting and opening, and the
  new Dungeon portal in the Frontier window.
