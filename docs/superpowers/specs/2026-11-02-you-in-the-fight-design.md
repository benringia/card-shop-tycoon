# You in the fight: the player fights bosses with a sword (combat week, project 1)

Brainstormed with the user on 2026-11-01 and 2026-11-02. Everything marked **(my call)** was settled by Claude, not
the user; everything else is the user's decision or a guess the user read and accepted.

## Intent

Boss fights today are watched, not played: you summon a creature, it trades hits with the boss, and you press its
ability button now and then. The user wants to **actually fight the boss instead of going AFK while the creature
fights**. The player gets a sword, fights beside one summoned creature, and the boss fights back at the player too.
It should feel like a flashy hack-and-slash with anime-style moves, "nothing too crazy".

This is project 1 of combat week. Order agreed with the user:

1. **You in the fight** (this document): the player, the sword, the combat feel kit, boss attacks on the player.
2. Weapons & Forge: one signature sword per boss (rare drop, or forged from that boss's scraps + cash), each with
   damage, an element and its own combo and skill.
3. Boss animation kits and mechanics: real attack animations and unique mechanics per boss.
4. Wild monsters fought with the sword (Wild monster fights, then likely the Dungeon rooms).

## Goals

- In every boss fight the player fights with a sword beside **one** summoned creature, and the boss attacks both.
- Fighting well clearly pays (the fight goes about twice as fast), but a player who doesn't fight still beats the boss
  slowly when their creature is strong enough.
- Attacks feel good: fluid Blender-made animations, hit-stop, shake, flash, sparks, slash trail, damage numbers,
  sounds.
- Dodging matters: bosses get readable, dodgeable attacks now, before their own kits arrive in project 3.
- Works on phones first: icon buttons, soft aiming, no camera fighting.

## Non-goals (this project)

- More swords, the Forge, weapon drops, weapon picking UI (project 2). Only the starter sword exists.
- Per-boss attack animations or unique mechanics beyond today's (project 3).
- The sword in Wild monster fights, Dungeon rooms or the PvP arena (project 4 or later). Those stay creature-only.
- Heals (potions, foods). They come later, but balance must leave room for them (see Balance).
- Weapon types other than swords. One weapon type keeps animation cost down.

## Anti-goals (would make this a failure even if it works)

- **Stiff animation.** The user rejected code-posed animation after comparing it with a Blender cut: "still stiff".
  Animations must be fluid.
- **AFK still being the best way to play.** Fighting has to matter.
- **Unfair hits.** If it looked like you got out of the ring or dodged on your screen, you did (within reason).
- **Phone players fighting the camera** to aim.
- **Cards stop mattering.** Collecting and levelling cards stays the main way to get stronger.
- **Pixel-art effects** in a smooth cartoon 3D game (see References: pixelfx).

## Decisions

### The fight

- Only **one** summoned creature fights in a boss fight. The call-in (a second card joining in the first 5 s) goes away
  in boss fights.
- The creature attacks on its own like today. The **Pet skill** button fires its ability on command.
- **Swap pet** sends a rested party card in for the summoned one, `Combat.BOSS_SWAP_SECONDS` (8 s) apart like today.
  When the summoned creature faints, your healthiest rested party card comes in by itself, like today.
- The boss attacks **you and your creature**. You have an HP bar.
- At 0 HP you are **down**: you kneel, can't act, and your creature fights on. After about 5 s you get back up with
  half your HP, as long as a creature of yours is still standing. No limit on how often.
- You **lose** when you are down **and** no creature of yours can fight: "Teleporting back to town in 3, 2, 1", then
  you are moved out (see "Where a loss sends you"). Nothing is lost; fainted cards rest.
- **Resting goes from 3 to 5 minutes**: `Combat.REST_SECONDS` 180 → 300. It is one constant for every faint (Wild,
  bosses, Frontier, Dungeon), so it changes everywhere. The plaza spring still makes it 3× faster.
- Run (the small button) still leaves the fight, as today.

### Balance

- The user: a player who doesn't fight still kills the boss **slowly**, depending on how strong their creature is
  against the boss. Boss mechanics (project 3) will make them move anyway.
- A creature alone at the recommended Power takes about **twice as long** as the same creature with the player fighting
  well. A strong creature is faster; a weak one loses alone, but good sword play lets a player beat a boss a bit above
  their Power (about 0.8× the recommended Power).
- **Win rates** (user-approved targets for the balance tool, solo; groups at the same Power should land close to them):

| | At the recommended Power | At 0.8× the Power |
|---|---|---|
| Fights well (keeps attacking, dodges rings) | about 85% | about 50% |
| Stands still (the creature does the work) | about 60%, slowly | about 15% |

  Fighting clearly pays, 1× still carries risk for someone standing still, and heals (later) add on top. Bosses come
  out stronger than today for players who don't fight, as the user asked.
- **Sword damage scales off the summoned creature's ATK**, so one starter sword works on bosses 1-7 and better cards
  still make the player stronger. A player who keeps attacking roughly doubles the team's damage (the full combo's
  damage per second ≈ the creature's auto-attack damage per second). Later boss weapons multiply it (say ×1.3) and add
  an element. If no creature of yours is standing, the sword uses the last summoned one's ATK **(my call)**.
- **Player HP is a flat 100** for everyone. Boss hits take a share of it, so a boss feels equally dangerous whatever
  your cards; dodging keeps you standing. Nothing heals you mid-fight except getting back up (heals come later).
- The boss targets the player about **1 in 3** of its attacks; when you are down, everything goes at your creature.
- Boss HP loses the ×1.5 it got when players brought all three cards, and is retuned to the timing above. The ATK
  ×1.2 from the same change is retuned with it **(my call)**.
- **Heals come later** (potions, foods): bosses and monsters are tuned so a player can win without them; heals become
  the safety net.
- The over-power drop cut (strongest card above 2.5× the recommended Power) stays.

### Boss attacks on the player (until project 3)

Every boss gets the same two attacks on the player:

- **Quick hit** at whoever it targets: a short flash on the boss first, so a well-timed dodge avoids it.
- **Big attack**: a marked area on the ground, either a **swipe** (cone in front of the boss) or a **slam** (circle
  aimed under a player), with a warning, then the hit. Step out, or dodge through it.
- Warning look **B, "closing ring"** (user's pick): the area is a thin white outline; a glowing white ring closes in on
  it and the hit lands when it touches the edge. White reads on grass, caves and lava alike. Mockup:
  `.superpowers/brainstorm/4253-1793516022/content/attack-telegraphs.html` (option B).
- The user: **the stronger the boss, the more frequent and dangerous its special attacks.** Starting numbers (in config,
  tuned after playing):

| Boss | Big attack every | Warning | Big hit | Quick hit |
|---|---|---|---|---|
| 1 · Meadow Warden | 10 s | 1.4 s | 30% | 10% |
| 2 · Cave Brood Queen | 9 s | 1.3 s | 35% | 12% |
| 3 · Ember Colossus | 8 s | 1.2 s | 40% | 14% |
| 4 · Frost Tyrant | 7 s | 1.1 s | 45% | 15% |
| 5 · Storm Sovereign | 6.5 s | 1.0 s | 50% | 17% |
| 6 · Rift Devourer | 6 s | 1.0 s | 55% | 18% |
| 7 · Prism Hydra | 5 s | 0.9 s | 60%, sometimes two rings at once | 20% |

  (Percentages are of the player's 100 HP.)
- Your creature keeps taking damage the way it does today and doesn't dodge. The big attack's ring hurts players only
  **(my call)**: creatures stand where BattleService places them and can't step out.
- The wind-up is a simple lean-back and glow on the boss model. Real attack animations come with project 3.
- Today's boss skills (shield, heal, thunderclap, adds, phases) keep working as they are, on the creatures only
  **(my call)**: the thunderclap doesn't stun the player, and enrage, Curse and Tidal Shield don't change hits on the
  player. Bosses hit players only through the quick hit and the big attack.
- When none of a player's creatures is standing, the boss's attacks meant for that side all go at the player
  **(my call)**.

### Scope

- The sword is used in **every boss fight**: the 3 Wild bosses (main game), the 3 Frontier bosses (Frontier place) and
  the Prism Hydra at the end of the Dungeon run.
- Wild monster fights, the Dungeon's rooms and the PvP arena stay creature-only until project 4. They keep the call-in
  **(my call)**: the "one creature" rule comes with the player joining those fights.

### Group fights (2-4 players)

- Everyone brings their sword and one creature. The boss spreads its attacks over all players and creatures; big-attack
  rings land on different players.
- **Each player faces the same danger as solo (my call)**: every big attack puts a ring on every player still up, and
  the quick hits aimed at players grow with the group, the way today's boss hits one more creature per extra player
  (`GROUP_SWINGS_STEP`) so a group can't hide behind spare bodies. With 4 players the Hydra can show up to 8 rings at
  once; rings must stay cheap (a few parts or decals each) and be checked on a phone.
- A member who is down with no creature left doesn't go to town at once: they watch from the side while the others
  fight on, and a win counts for them too. When the whole group is out, everyone gets "Teleporting back to town in 3,
  2, 1".
- Boss HP still scales with group size (`BossRules.groupStats`). Contribution (`BossRules.contributed`) counts sword
  damage as part of a player's damage **(my call)**.

### The starter sword and the player's look

- **Free starter sword at shop level 3** (when boss 1 opens; there is no tutorial). A popup says "You got your first
  sword!" and shows it. Players already past level 3 get it the next time they join. Owning it comes from the shop
  level; showing the popup exactly once needs one saved flag (a small save change under the CLAUDE.md schema rules,
  **my call**).
- The sword is only swung in boss fights **(my call)**; elsewhere it stays on your back (Click keeps its shop uses).
- A plain steel blade, no element.
- **Combo** (tap Attack): cut 1 is the Blender cut the user saw (crouched wind-up, stepping lunge cutting down across the
  body); cut 2 a sideways sweep; cut 3 a leaping overhead slam (bigger hit, small shake).
- **Sword skill**: a spinning slash that hits all around you (handy against the Rift Spawn adds), about 8 s cooldown.
- Every Forge sword later gets its **own** 3-hit combo and skill.
- **Standard body everywhere**, town included: standard torso, arms and legs at standard scale, keeping the player's
  own head, face, hair and accessories (some avatars, like a chicken, have no arms). Done on the server with
  `Humanoid:ApplyDescription`: body parts 0, BodyTypeScale and ProportionScale 0, Height/Width/Depth 1, Head kept
  (proven in the spike).
- **The sword rests on your back everywhere** (it shows off your weapon once Forge swords exist). It is drawn when you
  attack (gleam + draw sound) and put away after 4 s without attacking.
- Capes, wings and backpacks clash with a sword on the back: they are hidden **only during boss fights**.

### Controls

- Full kit with **icons, not text**, style **3 "Anime slash"**: slanted, cut-corner panels with neon edges in each
  button's colour. Layout A from the mockups: big Attack bottom-right, Dodge left of it, Sword skill above Dodge, Pet
  skill above Attack, small Swap pet and Run icon buttons at the bottom centre. Each button shows its cooldown as a sweep
  with the seconds left; on PC a small key label sits on its corner. Mockups:
  `.superpowers/brainstorm/4253-1793516022/content/combat-controls.html` (layout) and `combat-icons.html` (style 3).
- Your HP and your creature's HP sit top-left; the boss bar at the top centre (as in the mockups).
- **Dodge**: a quick dash in the direction you're moving (backward when standing still), about 0.35 s untouchable,
  after-images, about 1 s cooldown.
- **PC keys**: Click = Attack, **Shift = Dodge** (user: "ctrl or shift"; Shift picked), E = Sword skill, R = Pet skill,
  1-3 = Swap to that party card. Roblox binds Shift Lock to Shift by default, so Shift Lock moves to **Ctrl**; otherwise
  every dodge would flip the camera.
- When the summoned creature has a signature ability (Epic and Legendary cards), a second small pet button for it sits
  beside the Pet skill button **(my call)**; the Pet skill button fires its element ability.
- On phones the Swap pet button pops out the rested party cards as small portraits to pick from **(my call)**; with only
  one rested card it swaps straight away.
- These controls replace today's boss fight bar ("Fireball", "Bring in <card>", "Run" text buttons) in boss fights only.

### Aiming and camera

- Attacking with the boss roughly in front of you and within reach turns you toward it by itself (soft aim). The camera
  stays free: no forced lock-on.
- The server checks every hit: reach, facing, combo timing. Hits can't be faked.

### Feel: effects and sound

- Effects the user liked in the spike: **hit-stop, camera shake, white flash on the boss, sparks, damage numbers, slash
  trail**, and **after-images** on dodge. Your damage numbers use a different colour from your creature's.
- Sounds from Roblox's free audio library: a swing whoosh per cut, the hit, the draw ring, the dodge, a chime when a
  ring appears, getting knocked down and getting up.
- Effects are made smooth to match the cartoon 3D look: Blender-rendered flipbooks (the same pipeline as the pack
  opening effects: `tools/blender/build_pack_fx.py` → `tools/textures/make_flipbooks.py`) plus Roblox Trails, Beams and
  ParticleEmitters.

### Animations: made in Blender

- The user chose Blender-made animation over code-posed after comparing them in Studio, for **this and every future
  sword**.
- Rig: the game's standard R15 body in Blender, legs on IK with planted feet (knees need a slight pre-bend), arms
  trailing the body by a frame or two; exported per frame to a KeyframeSequence. The user publishes each animation once
  in Studio; its asset id goes in config.
- Starter sword set: draw, put away, the 3 cuts, the skill, the dodge, a hit flinch, knocked down, getting up, a ready
  stance and a run while the sword is out.
- Each animation gets front and side GIF previews for the user to approve before it is published.

## Where a loss sends you (my call)

"Back to town" means home for the place you are in:

- **Main game** (Wild bosses): the plaza by the healing spring, so fainted cards rest 3× faster.
- **Frontier** (bosses 4-6): the Frontier's entrance spawn. The Frontier has no town, and a cross-place teleport home
  would be slow.
- **Dungeon** (Prism Hydra): out of the run and back to the Frontier, as today.

## Constraints (from the project and the code)

- Read `DESIGN.md` first; update it in the same change when a rule, number or file changes (combat section, boss
  sections, controls, `REST_SECONDS`). Tick the system in DESIGN.md only after the user confirms it works.
- **Server authoritative.** The client sends intents (attack pressed, dodge, skill, pet skill, swap); the server
  validates and changes state. Every remote lives in `src/shared/Remotes.luau`, validates arg types and ranges,
  ownership and distance, and is rate-limited with `src/server/Util/RateLimiter.luau`.
- **All tunable numbers in `src/shared/Config`** (sword moves, player HP, downed time, boss attack ladder, dodge,
  reach). No magic numbers in services.
- Rules both sides use (combo timing, reach and facing checks, ring shapes, damage formula) live in Roblox-free pure
  modules, **Lune-tested** (`lune run tests/run`). Lune can't build Vector3 or CFrame, so geometry uses plain numbers.
  Pure modules don't require siblings.
- Today's boss fights run in `BattleService` on the pure `server/Util/BattleSim.luau` (10 steps a second,
  `Combat.TICK_RATE`), with boss mechanics, swaps, group rules and contribution there; `BossService` owns arenas, gates,
  intro and rewards; `DungeonService` the Hydra's run; `client/Controllers/BattleController.luau` the fight UI. Build on
  these; don't fork a second fight system.
- Update the boss balance tool (`lune run tools/balance/bosses`) to model the player: a player who fights well, one who
  stands still (and so is downed often), at 0.8× / 1× / 1.3× Power, solo and in groups.
- The only save change is the first-sword popup flag. Follow the schema rules in CLAUDE.md (bump `SCHEMA_VERSION`,
  migration with a Lune test, types and template, DESIGN.md 10.4).
- Build the combat so it doesn't depend on where an arena is: the Frontier redesign (on hold) will move the Frontier
  boss arenas later.
- UI: built in code with `Util/UIKit`; buttons through `Util/Hud`, clear of the thumbstick and jump button; tap targets
  at least 48 px; tested in the landscape phone emulator. Text is plain ASCII plus `·` and emoji (Fredoka/Gotham draw
  symbols like ★ as boxes). Icons are images in `Config/UIIcons` (Figma-generated sheets cut by
  `tools/ui-icons/slice_icons.py`).
- Effects run on the clients only; the server sends events. Watch frame time on phones (`rbx-perf-profiling`).
- The animations must be owned by whoever owns the published experience, or they won't play there. In Studio,
  `KeyframeSequenceProvider:RegisterKeyframeSequence` works for unpublished tests.
- Studio MCP: reading the place is fine; ask before changing the place itself. Scripts live only in the repo.
- Security notes for the user's machine and Blender: never print the Meshy API key; before committing a `.blend`,
  check the scene's `blendermcp_*key*` / `*secret*` fields are empty (print lengths only); delete raw `*_Src` objects
  and purge orphans before saving blends.

## Left to the builder

- How the player enters `BattleSim` (a fighter with no auto-attack whose hits come from validated remote intents, or a
  separate track beside it), as long as boss targeting, contribution, group rules and the balance tool see the player.
- Exact per-cut damage factors, reach, facing angle, combo windows and recovery times, as long as the full combo's damage
  per second ≈ the creature's and the targets above hold. pixelfx's published timing data (wind-up, freeze on contact,
  recovery) is a good starting point.
- How latency is handled for dodges and ring hits (for example a short grace window using the client's reported
  timing, capped and checked against server position) so that "it looked like I got out" holds within reason.
- Target fight lengths per boss, from the balance tool, within the 2× rule and `BOSS_MAX_FIGHT_SECONDS` (420 s).
- The starter sword's model (Blender, like the other props, saved as a model under ReplicatedStorage) and how it
  attaches to the back and the hand.
- How the boss's lean-back wind-up is posed (the bosses are rigged; `Util/PetRig`-style poses are fine).
- Sound picks, effect textures and the icon art, each shown to the user before it's final (the user wants mockups or
  renders for every visual decision).
- The order of work, and how to split it into plans.

## References

- **Spike files** (throwaway, git-ignored): `.superpowers/combat-spike/`: `sword_anim_spike.py` (Blender rig, combo cut
  1, renders, per-frame export), `sword_spike4.luau` (Studio test: the Blender cut on Click, a code-made combo on F, E
  spin, Q dodge, sheath, dummy, effects), `combo1.json`, `c1_front.gif`, `c1_side.gif`.
- **Mockups**: `.superpowers/brainstorm/4253-1793516022/content/`: `combat-controls.html`, `combat-icons.html`,
  `attack-telegraphs.html`, `blender-test.html`.
- **pixelfx** (https://patch-gg.github.io/pixelfx/, MIT, 244 2D pixel-art effects): kept as a **reference only**, for
  attack timing ("acting": wind-up, freeze on contact, the target rocking back, recovery), effect ideas (slash smears,
  impact bursts, dash after-images) and palette recolouring per element. Its pixel-art sprites are not used in game.
- **Technical findings from the spike**:
  - Avatars use AnimationConstraint joints; their `Transform` is writable in `RunService.PreSimulation` and overrides
    the Animator.
  - R15 rest joints are axis-aligned with identity attachment rotations.
  - Blender ↔ Roblox axes: x_r = -x_b, y_r = z_b, z_r = y_b (the character faces -Y in Blender, its left is +X). Export
    T_r = M·(Fp⁻¹·Fc)·M with F = pose_bone.matrix @ rest_rot⁻¹, M = ((-1,0,0),(0,0,1),(0,1,0)).
  - KeyframeSequence poses nest HumanoidRootPart > LowerTorso > UpperTorso > …; hit-stop can be
    `AnimationTrack:AdjustSpeed(0)` for a few frames.
- **Existing rules this touches** (DESIGN.md): boss arenas and swaps (~line 875-907), farm protection, groups (~956-976),
  Dungeon run (~1017), Combat config (`src/shared/Config/Combat.luau`), bosses (`src/shared/Config/Bosses.luau`).
