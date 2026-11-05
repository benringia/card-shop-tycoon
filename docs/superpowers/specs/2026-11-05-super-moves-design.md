# Super moves: cinematic, way more epic (design)

Date: 2026-11-05. Owner approved the fight flow ("okay go for it", option 3 below) and the ten storyboards
(`.superpowers/brainstorm/1549-1793853648/content/super-storyboards.html`, "proceed"). References the owner was shown:
`super-refs.html` in the same folder (Star Rail and Genshin ultimates, Pokémon Z-moves, Roblox battlegrounds games).

## Why

The super moves (the Super button: Epic and Legendary cards only, 15 s cooldown) still use the first-pass look: a few
shared effect pieces (`ElementFx.special`: pillars, shockwaves, ring flashes), one shared chime plus the element's boom,
nothing different by grade, and the four Frontier supers borrow their base move's look (Magma Slam shows yellow
sparkle bolts, Thunderstorm a falling sun). The owner: "since this is epic and legendary skills I want them to be way
epic/cooler looking than the ones we already did" (the pet moves round: Healing Rain, Vine Snare, Overcharge, Curse).
What makes a super epic, in the owner's words: "screen shakes / cinematics / particle effect / sound effects".

## Goals

- Every super is an event: a short cinematic for the player who fired it, big element effects, a heavy impact, layered
  sound. Clearly a tier above the pet moves.
- Ten distinct moves: the six base supers and the four Frontier ones, each with its own look and sounds.
- **The owner's standing rule: the higher the creature's grade (C, B, A, S), the better the move looks and feels**, each
  grade a clear step up; S has extras the others don't.
- Rarity sets the size of the cinematic: Epic a quick swoop, Legendary the full show.

## Non-goals

- What the moves do stays the same (damage, burn, shield, stun, dodge, lifesteal, cooldown); the only mechanic changes
  are the wind-up timing and the caster's player being protected while their camera is away (below).
- No new supers for other cards; the pet moves and basic attacks don't change.
- The combat HUD's layout doesn't change (it only hides during the caster's camera beat).

## Anti-goals (a failure even if it works)

- The player gets hit by something they couldn't see because the camera was away.
- Other players in a group fight lose control or their view because someone else fired a super.
- Grade S looks like Grade C with bigger numbers.
- Flashing that hurts: the black-and-white impact frame must respect the low-graphics switch (Star Rail had to add a
  setting after players complained about one ultimate's flashing).
- Frame drops in a group fight when several supers go off.
- A copy of a famous game's exact move (keep them ours: the storyboards, not Star Rail's or Pokémon's frames).

## The fight flow (the owner's pick, option 3 "Genshin style")

The fight keeps running for everyone. Firing a super:

1. **The server** starts a wind-up for that super (the existing `casts` path in `BattleSim.useAbility`, which pet
   moves already use with `ABILITY_WINDUP` 0.5 s): the move lands when the wind-up ends. Wind-up length by the card's
   rarity: **Epic 1.5 s, Legendary 2.0 s** *(my call, from the owner's "about 1.5 s / 2 s")*. Each super's entry in
   `Config/Combat` SIGNATURES carries its own wind-up, so a move can be tuned alone.
2. **The caster's player** (their player fighter in boss fights, and in wild fights when they have a sword) **can't be
   hit while their camera is away** (the owner approved exactly this: "while your camera is away, boss attacks can't
   hit you"): from the press until control returns, that is the wind-up plus the impact beat and the camera's ease
   back (**the wind-up + 0.6 s** *(my call)*). It's the same untouchable state as the sword dodge, held longer. Hits
   already on their way and due inside the window miss. **And the boss starts no new quick hits or closing rings aimed
   at the caster's player during the window** *(my call)*: it picks another target as usual (their creature, another
   player). Otherwise a ring started mid-cinematic could close a moment after control returns, before the player could
   react.
3. **The damage, shield, stun, dodge or heal lands at the impact**, the end of the wind-up, so the numbers pop with the
   effect.
4. **Only the caster's own client plays the cinematic.** Everyone else in the fight sees the move in the world from
   their own camera: the creature's pose, the element effects, the impact, positional sound and a lighter shake; no
   camera move, no screen tint, no bars, no flash, no name card on their screen.
   **Sky and lighting changes are the caster's only** *(my call)*: Supernova's deep space, Devour's dimmed world, the
   Eclipse's darkened arena, Thunderstorm's dark sky, every Legendary's sky change happen on the caster's screen inside
   the cinematic (holding the day cycle like the welcome cinematic, `SkyLook.hold`) and ease back with it. The
   **objects** in the sky are in the world for everyone: the black moon and its corona, the storm clouds, the black
   hole, the parting clouds and rays. So nobody else's view is taken over, and four supers at once never fight over
   one shared sky.
5. Wherever a super can be fired (boss fights, group boss fights, wild fights, arena fights) it works the same way.
6. *(my call)* If the caster faints during the wind-up the move fizzles (the existing cast rule) and the cinematic cuts
   back to the player at once. Swapping out the caster during its wind-up is blocked until the move lands.

## The four beats (the caster's screen)

Timings for Epic (1.5 s) / Legendary (2.0 s); the builder fits the exact split to each move.

1. **Call (about 0.3 s):** the camera swoops from the player's view to a low, close shot of the creature. The card's own
   painting slides across the screen with the move's name in big letters (title font, element-coloured outline). The
   screen takes the element's colour (a colour wash). The combat HUD fades out *(my call)*; the character is held
   still and fight keys do nothing until control returns *(my call)*. Legendary: letterbox bars slide in and the sky
   or lighting starts to change.
2. **Charge (Epic about 0.7 s, Legendary about 1.1 s):** the creature's signature pose (its `Party.SIGNATURE` pose in
   `Util/PetRig` where it has one), an aura bursting out, light and particles pulling into it, a rising charge sound.
   A slow-motion feel (effects drift slowly; the fight itself is not slowed).
3. **Impact (the moment the move lands):** the camera snaps to the target (or pulls wide for the shields and dodges).
   A flash (Epic: a white flash; Legendary: a 2-3 frame black-and-white impact frame), a big shake scaled by grade, the
   shockwave and boom.
4. **Linger:** the camera returns to the player's normal view (a short ease, not a cut), the HUD fades back, control
   returns. What stays on the field plays out for its seconds (burning ground, a dome, a dark sky...). Legendary: the
   sky eases back.

Low graphics (the existing `Extras` switch off): no black-and-white frame (a soft white flash instead), fewer
particles, a smaller shake; the camera beat still plays.

## The ten moves (as approved in the storyboards)

Each line: call / charge / impact / linger, then what grows with grade and the S extra. Colours follow the element.

### Inferno (Infernox, Epic, Ember): sets the foe on fire for 6 s

- Infernox from a low angle, an orange wash, "INFERNO!" / it roars to the sky as a fire tornado spins up round it /
  it breathes a torrent and the tornado leaps onto the boss and engulfs it / a ring of fire round the boss, flames
  licking it, embers rising for the 6 s burn.
- By grade: taller tornado, more embers, hotter colours. **S:** the ground cracks into lava under the boss.

### Tidal Shield (Abyssal Koi, Epic, Tide): a shield for your side, 30% of its HP

- The koi leaps from a swirl of water / a huge wave rises behind your side / the wave crashes over you and sets into a
  shining water dome / spirit koi swim round the dome; each hit it absorbs ripples it; it bursts in a splash when used
  up (or when the fight ends).
- By grade: thicker dome, more spirit koi. **S:** a rainbow sheen and a second ring.

### Tidal Blessing (Tideborne Kirin, Legendary, Tide, Frontier): a shield for your side, 35% of its HP

- Clouds part with rays of light, the Kirin rears / a giant water lotus opens under your side / impact frame: its petals
  rise and close into a dome of light-water / a soft rain of light over your side while the dome holds.
- By grade: lotus size, petal count, light rays. **S:** a halo over the Kirin and golden rain.

### Stampede (Thunderhorn, Epic, Volt): a 2x hit and a 2 s stun (1 s on bosses)

- Thunderhorn paws the ground, sparks fly / its horns crackle, lightning wraps its body / a lightning dash through the
  boss with afterimages and a thunderclap / the boss stunned: electric rings spin round its head; a scorched trail on
  the ground.
- By grade: more afterimages, a wider trail. **S:** a bolt from the sky strikes as it passes.

### Magma Slam (Cinder Titan, Epic, Ember, Frontier): a 2x hit and a 2 s stun

- The titan clenches its fists, lava glows through its cracks / it leaps high, the camera tilting up after it / it
  crashes down: lava cracks race to the boss and geysers erupt under it / rocks rain down; a cooling crust holds the
  boss's feet for the stun.
- By grade: longer cracks, more geysers and rocks. **S:** a ring of lava bursts round the landing.

### Eclipse (Eclipse Fox, Epic, Shade): dodges everything for 3 s

- The fox howls at the sky / a black moon slides over the sun and the arena darkens / a ring of violet light bursts
  out and the fox turns to shadow / attacks pass through it in puffs of shadow, afterimages trail it, the eclipse hangs
  above for the 3 s.
- By grade: a bigger corona, more afterimages. **S:** two shadow clones run beside it.

### Rift Step (Riftwalker, Epic, Shade, Frontier): dodges everything for 3 s

- Space cracks like glass round Riftwalker / the cracks open into purple void / it shatters through a rift and blinks
  out / it blinks between rifts; attacks hit empty cracks that seal up.
- By grade: more rifts and shards. **S:** the whole arena's edge cracks for a moment.

### Supernova (Solarion, Legendary, Ember): a huge 4x hit

- Bars; the sky turns to deep space; Solarion rises, glowing / a small sun grows over its hands, pulling light and
  sparks in / impact frame: it hurls the sun down; a white-out and a dome of fire / shockwave rings, rays of light,
  heat shimmer, then the sky returns.
- By grade: a bigger sun, more rings and rays. **S:** two impact frames and pillars of light round the crater.

### Thunderstorm (Stormking, Legendary, Volt, Frontier): a huge 4x hit

- Bars; storm clouds swirl in above the boss / Stormking raises its horns, lightning crawls across the clouds / impact
  frame: a colossal bolt and forked strikes hit the boss / rain, sparks crawling over the ground, thunder rolling away.
- By grade: more forks, a wider storm. **S:** three bolts and a chain of lightning round the arena.

### Devour (Voidmaw, Legendary, Shade): a 2x hit that heals it for half the damage

- Bars; the world dims, Voidmaw's eyes burn violet / a black hole opens behind the boss, pulling everything in /
  impact frame: giant spectral jaws rise from the ground and clamp shut / streams of life flow from the boss into
  Voidmaw (its heal).
- By grade: a bigger black hole, more life streams. **S:** the jaws bite twice (one hit's damage, shown as two bites).

## Sound

Every super gets its own layered sounds: a call sting, a charge riser, the impact (a heavy boom with an element layer:
fire roar, water crash, thunder, rock crunch, void whoosh) and a linger loop or tail where the move lasts (fire
crackle, rain, storm). Roblox-licensed only (Pro Sound Effects or APM, found through the toolbox API as before; never
user uploads). Higher grades add layers. All of them join the fight sounds kept loaded all session
(`Util/CombatPreload` + `Util/SoundBank`), so none starts late. Others in the fight hear them positionally, at the
fight volume (`AttackFx.VOLUME`).

## Screen shake

The impact's shake grows with grade (C small, S big); the caster feels the full shake, others a lighter one if they're
near. Existing shake code (`BattleController` shake, `ShakeRules`) is the starting point.

## How it's built (the parts already decided)

- Plain-data config per move per grade (like `Config/MoveFx`): `Config/SuperFx`, Lune-tested for completeness (every
  super, every grade, sounds, textures, timings).
- Pure rules where there's logic (grade looks, beat timings, camera framing maths): `Util/SuperFxRules`, Lune-tested.
- `BattleSim`: the per-super wind-up, the caster's player untouchable until control returns, no new quick hits or rings
  aimed at them meanwhile, the swap block; tests in `tests/BattleSim.spec.luau` (lands at the impact, the untouchable
  window, no new rings or quick hits on the caster, fizzles on faint, cooldown unchanged).
- Client: the effects (`Util/SuperFx`, routed from `Util/FightFx` like `MoveFx`), the caster's cinematic (camera,
  card cut-in, wash, bars, impact frame, sky/lighting, HUD fade; its own module), all client-side and restored on
  every exit (fight end, faint, leaving).
- A Studio preview, like `/movefx`: `/superfx <move> [C|B|A|S]` on your summoned creature against a dummy, and admin
  panel buttons.
- New textures drawn by a Pillow script (`tools/textures/make_super_fx.py`, uploaded, ids in `Config/SuperFx`). Meshes
  only where a shape needs one (the jaws, the lotus, the tornado funnel are candidates), built by a Blender script in
  a background Blender, never the owner's open one.

## Performance

Measure the frame cost of each move at Grade S in Studio, alone and with four supers at once (a group fight). Keep the
caster's full version and the onlookers' lighter version within the effects budget (`FightFxRules.budget`); low
graphics cuts particles. Report the numbers in DESIGN.

## Balance

The untouchable wind-up makes Epic and Legendary holders a little safer. Run `lune run tools/balance/bosses` before and
after and report the change in DESIGN; numbers stay as they are unless the owner decides otherwise.

## Left to the builder

- The exact camera paths, beat splits inside each wind-up, colours, particle counts, shake strengths and sound picks,
  within the storyboards and this document.
- Whether each effect is parts, beams, particles, textures or a mesh.
- Module names and file layout beyond the ones named here.
- The order the ten moves are built in (each one finished, previewed in Studio and screenshotted before the next).
