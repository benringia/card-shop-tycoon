# Wild bosses and their arenas (design)

Status: written 2026-11-01 after the user picked every boss and its size; the user said proceed to the playback. A
builder check followed; its four questions are settled in "Claude's calls after the builder check" (none needed the
user).

## Intent

The main game's three Wild bosses (boss ladder 1-3) still fight as part-built placeholder shapes, and their arenas are
bare squares of terrain floating in empty sky: a ring of posts, a dozen zone props and the same meadow root arch as the
way home in all three. The user redesigned the Wild valley and gave its six monsters real models, then noticed the
bosses and arenas had been left behind ("I forgot about it"). Each boss gets a real model and each arena becomes a place
of its own that frames that boss, so the fight at the end of each zone feels like the end of a zone.

The user picked each boss from three concepts painted in its arena, then picked their size from three to-scale lineups,
and asked for them to be big.

## The three bosses and arenas (all picked by the user)

Concept paintings, chosen from nine: `.superpowers/brainstorm/4253-1793516022/content/boss-w1.png`, `boss-q2.png`,
`boss-c3.png` (git-ignored scratch; the first build step copies each into `assets/blender/<Folder>/` as its
`_concept.png`). Boss ids, names, numbers and mechanics stay as they are (`Config/Bosses`).

1. **Meadow Warden** (`meadowWarden`, Bloom, the first boss): **"Elder Warden"**. A hunched, bulky giant made of an
   ancient hollow tree trunk and grey boulders; a carved stone mask for a face with two glowing green eyes; branching
   antler-like boughs with blossoms; a thick moss beard; flowers blooming on its shoulders; huge root-fingered hands
   that drag on the ground. Two legs, long arms. **Arena: the Warden's grove.** A sunken forest clearing ringed by
   enormous mossy standing stones and giant old trees with huge roots, a carpet of flowers, shafts of sunlight,
   fireflies.
2. **Cave Brood Queen** (`caveBroodQueen`, Shade, heals below half HP): **"Broodmother"**. A giant bat-winged spider: a
   dark plated body, leathery bat wings folded on its back, eight thick legs, a cluster of glowing violet eyes, fangs,
   and a big translucent crystal egg sac on its abdomen glowing violet. **Arena: the Broodmother's hollow.** A cave with
   a rock roof: thick grey webs between stalagmites, cocoons hanging from the ceiling, blue-violet glowing crystals,
   bones on the floor, dim cold light. The creepiest of the three, as the user saw it.
3. **Ember Colossus** (`emberColossus`, Ember, enrages below half HP): **"Magma Behemoth"**. A colossal, heavy
   four-legged beast built like a giant armoured rhino: a domed back of cracked basalt plates with lava glowing between
   them and smoking vents on top, rows of obsidian spikes, a huge horned head with a blazing mouth, thick pillar legs
   dripping lava. *Claude's call, shown to the user in the concept notes:* push it more rhino than tortoise (the
   painting's spiky shell sits near a famous turtle character). **Arena: the Behemoth's lava field.** Cracked ground
   split by glowing lava fissures, charred dead trees, jagged obsidian shards, falling ash, ringed by cliffs, an
   erupting volcano behind under a red-orange sky.

## Decided by the user

- The three designs above, each with the arena painted around it.
- **Size B, "Huge"** (studs): Elder Warden **17 tall**; Broodmother **12 tall, about 24 wide**; Magma Behemoth **17
  tall, about 28 long**. For scale: a player is about 5, the biggest Wild monster (Magma Golem) 6.5, and the Prism Hydra
  (the final boss) stays the biggest at 24.5.
- Proceed with the playback below (the user said "proceed" to it, guesses included).

## Goals

1. **Real boss models**, made the way the six Wild monsters were (docs/creatures.md "Wild monsters"): a clean picture
   of each picked design, Meshy image to 3D through the Blender MCP, our own rig scripts (`tools/blender/rig_kit.py`,
   one `rig_<boss>.py` each), glow masks on a SurfaceAppearance, saved as `assets/monsters/<bossId>.rbxm` (the existing
   boss-model path: MonsterController already loads a boss's model by its id). **The user approves each model in a
   turnaround render before it is rigged.** Style family: the monsters' "wild-touched" (feral, glowing eyes without
   pupils, glowing growths of the element), bigger and more menacing: these are bosses.
2. **Bones that move like the creature.** PetRig-named bones and a per-boss style (`Party.CREATURE_STYLE` keyed by
   boss id, as the Prism Hydra is): the Warden lumbers on two legs swinging its long arms; the Broodmother's eight legs
   walk in a wave (pairs 0..3, already supported and tested) with her wings on wing chains; the Behemoth walks heavily
   on four legs. Each has a jaw where the design has one.
3. **A signature move each** (playback guess the user accepted), on `Party.SIGNATURE` with effects in particles and
   lights, never by animating a SurfaceAppearance (each one whose strength keeps changing costs about 6 ms of render
   CPU, DESIGN 10.5):
   - the Warden slams its roots into the ground (a stomp-like move with a ground ring and a burst of leaves/petals);
   - the Broodmother's egg sac flares when her heal fires (the existing heal moment), a violet burst from the sac;
   - the Behemoth's vents erupt with smoke and embers when it enrages (the existing enrage moment), and keep smoking
     while it is enraged.
4. **A roar at the start of each fight** (playback guess accepted): today's intro has a camera shake and a name card
   but no boss sound; each boss gets its own roar sound at the intro's roar moment.
5. **Arenas that are places, not floating squares.** Each of the three looks above, built at all four copies of its
   arena (`Bosses.ARENA_COPIES`, the copies at `WildValley.ARENA_FIELD`), fully enclosed so no empty sky shows at the
   edges from anywhere a player or the fight camera can be (cliffs, giant trees or cave walls all round; the cave has a
   roof). The fight's ring, barrier, gate and leash keep working as today.
6. **The way home matches the zone.** Each arena's exit portal in its own zone's look: the meadow keeps the root arch;
   the caves and the ridge get a portal that belongs to them (see "Left to the builder").
7. **Sound per arena** (playback guess accepted): each arena has its own looping ambient sound (birds, wind and leaves
   in the grove; dripping, a low hum and skittering in the hollow; rumbling, crackling lava and wind in the lava field),
   positional like the town's (`Scenery.SOUNDS` style), from Roblox's free audio library. The existing low boss drone
   (`Bosses.MUSIC_ID`) still plays during fights.
8. **Fighters fit the bigger bosses.** Each boss's `ringRadius` (how far its fighters stand from it) and `introShot`
   (its intro camera) are set for its new size, as the Prism Hydra's are.
9. **60 fps** at graphics levels 1 and 10 in each arena with a fight running, measured the same way as the valley
   (DESIGN 10.5); the terrain stays within its cap.
10. **Docs kept in sync:** DESIGN (boss ladder section 5.10, the Wild valley arena paragraph, file tree, 10.5),
    docs/creatures.md (the boss models), CLAUDE.md where commands or files change, the Obsidian vault (roster, decisions,
    lessons).

## Non-goals

- No change to the fights: HP, ATK, SPD, levels, drops, keys, mechanics and groups stay as they are.
- No new hazards in the arenas (nothing that hurts or pushes players); danger is in the look and the sound.
- No new boss names: the concept titles ("Elder Warden", "Broodmother", "Magma Behemoth") were working names; the
  bosses keep their ids, names, titles, trophies and key fragments. *Claude's call:* renaming would ripple through items,
  trophies and titles for no gain the user asked for.
- Not the Frontier: its redesign (concept C, on hold) and bosses 4-6 come later. The Prism Hydra and the Dungeon are
  untouched.
- No change to how the boss portals in the valley work or look (the obsidian arches stay).

## Anti-goals (a failure even if it works)

- A boss that looks like a card creature or reads as a famous character (the user's standing rule after Zappit read as
  Pikachu): no giant-turtle Behemoth, no cute spider.
- Empty sky or the void visible past an arena's edge, or an arena that reads as a square plate.
- Bosses that don't look big next to their fighters, or a Prism Hydra that no longer looks like the biggest boss.
- Frame drops in an arena fight on a phone; animated SurfaceAppearance glows.
- A spider so detailed or fast it reads as a horror game rather than a creepy-but-fun boss (it stays in the stylized
  cartoon look of the monsters).

## Constraints (from the project)

- Server authoritative; all tunables in `src/shared/Config`; pure logic in Roblox-free modules with Lune tests; `--!strict`.
- Code lives in the repo; Studio-only steps (FBX import, setting a SurfaceAppearance's `ColorMapContent` and
  `EmissiveMaskContent`, saving rbxm files) are the user's hand-off, as with the monsters.
- Meshy credits: about 3 generations; ask the user before any regeneration. Character-only prompts and pictures (no
  ground, base or props), neutral poses (quadrupeds square and facing forward, the biped in a T-pose or arms out),
  bulky builds, smooth bodies (no fur spikes). Never print the Meshy key; before committing a .blend, check its
  add-on key fields are empty (Blender 5: `bl_system_properties_get()`), delete the raw `*_Src` mesh and purge orphans.
- Terrain cells: the valley plus its 12 arena clearings is about 86.5k of `WildValley.MAX_CELLS` 90k, and the town
  plus valley about 225.5k of `Scenery.MAX_CELLS` 230k (both Lune-tested). Enclosing walls, the cave roof and big
  rocks should be meshes or parts, not new terrain, unless measured and the caps raised with a reason.
- The four copies of each arena stand 1200 studs apart and stream in for whoever fights there; dressing counts four
  times over, so it has to be cheap per copy (reused meshes, few lights, no shadows on small parts).
- Boss names in UI text: plain ASCII plus `·` and emoji only.

## Claude's calls after the builder check

1. **Bosses keep standing.** A boss spawns, stands still and lunges `Combat.LUNGE_STUDS` (1.5) when it attacks
   (DESIGN 5.10); that stays (no change to the fights). The work goes into idles (breathing, fidgets, the signature),
   the attack lunge and the intro roar; gait numbers are still set so the lunge and any step look right, but no
   walk-in is added.
2. **Meshy budget and fallbacks.** About 1,420 credits were left on 2026-11-01, so three image-to-3D generations are
   small; any retry still means asking the user first. The Broodmother is the risky one (eight thin legs, membrane
   wings, a translucent sac): if the generation fuses or loses legs or wings, they are rebuilt as scripted Blender parts
   joined to the generated body (as `build_prismHydra.py` builds its parts), shown to the user like any model.
3. **What sets off each move.**
   - The Broodmother's egg-sac flare plays **only** when her heal fires (never as a random idle: a random flare would
     read as a heal).
   - The Behemoth's vents erupt when it enrages and keep smoking while it is enraged (a replicated state on its marker,
     set by BattleService with the enrage, like the Prism Hydra's `Phase`).
   - The Warden's root slam is its random signature idle (`Party.SIGNATURE`, as the monsters' are); it has no mechanic.
   - At each fight's intro roar moment every boss plays a roar pose with its new roar sound.
   These hook the client's existing heal and enrage moments (BattleController already shakes the camera on them) to
   the boss's model.
4. **Each arena has its own look, never night.** DESIGN section 3 shows boss arenas the fixed afternoon look so fights
   never happen at night; that intent stays, but each arena's look follows its painting: the grove a sunny afternoon
   with shafts of light, the hollow a dim cave, the lava field a red-orange haze with falling ash. The look is applied
   on the client while the player is inside that arena's copy, the way the town's day cycle switches by position. Each
   look's haze hides whatever lies past the walls, so the camera keeps its 128-stud zoom (`StarterPlayer`
   `CameraMaxZoomDistance`): no zoom cap, which players would feel. The look switch gets its own performance check.

## Left to the builder

- How heights are expressed (a per-boss height in `Config/Bosses` beside or instead of `scale`), as long as the three
  sizes above hold and `Util/MonsterLooks.height` stays the one place that computes it.
- Rig details per boss (bone counts, which parts ride role-less bones like the monsters' claws and pincers, where the
  `Fx_` bones sit for the egg sac and the vents), the fidget lists and gait numbers, tuned in Studio.
- How the Warden's grove trees, standing stones, the hollow's cave shell and webs, and the lava field's cliffs and
  volcano are built: reusing the town's and the caldera's meshes (trees, `Volcano`, `CharredTree`, `ObsidianShards`),
  new Blender-built props in `tools/blender/`, parts, or a mix.
- How dark the hollow feels and how (the roof's shade, local lights, a client-side lighting change while inside a
  hollow copy, as the town's day cycle switches by position), as long as the fight stays readable.
- Which existing or new portal models stand as the caves' and ridge's way home (the obsidian arch already exists for
  the ridge; the caves need a stone or crystal arch), and their swirl colours.
- The roar and ambient sounds chosen from the free library, their volumes and ranges.
- Exact `ringRadius` and `introShot` values, found in Studio with the models in place.
