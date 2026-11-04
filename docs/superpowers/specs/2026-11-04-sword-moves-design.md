# Sword moves: anime, hack-and-slash

Owner's notes 2026-11-04. Picks from the reference page `sword-refs.html` ("do your picks"), and the approved previews
`sword-v3.html` (visual companion, `.superpowers/brainstorm/13775-1793692558/content/`):
- **1 A:** a snappy, light combo with a heavier finisher.
- **2 B:** the dash slash replaces the spin.
- **3 C:** a candy sparkle arc on each swing.
- **4 A:** a star burst on each hit, with a ring on big hits.

The owner's bar, in his words: "satisfying/smooth/dramatic/animeish/hack and slash style not robloxy stiff", and "the
finisher has to be both hands holding the sword". Then "build it. do your best to make it look natural/good".

The build goes on a new branch from `main` (`sword-moves`).

## Intent

Today's sword moves (spec `2026-11-02-you-in-the-fight-design.md`) work but feel stiff:
- every key eases the same way and every joint moves at once;
- the moves are sampled at 30 fps;
- the root motion slides back at the end;
- the slash effect only appears on a hit.

The fix is the craft hack-and-slash games use:
- a held wind-up, a near-instant swing, a follow-through that settles;
- joints breaking one after another, like a whip;
- real forward lunges;
- cuts that chain before their recovery ends;
- strong effects with a short freeze on each hit.

## Goals (what gets built)

1. **Four new moves for the Steel Sword**, as approved in the v3 previews. The keys are in the spike
   `anim_sword_v3.py`, which moves into `tools/blender/anim_starter_sword.py`.
   - **Cut 1, forehand:** coil right with the sword cocked high and the free hand aimed at the target, then snap a
     diagonal cut down across while lunging in, overshoot and settle. 0.60 s; strike at 0.217 s.
   - **Cut 2, backhand:** from low on the left (where Cut 1 ends), a rising sweep out to the right onto the toes.
     0.58 s; strike at 0.183 s.
   - **Cut 3, finisher, both hands on the hilt throughout:** a deep crouch, then a high leap with a full spin while
     the sword rises overhead, then a falling two-handed slam into the ground, with the impact held. 0.88 s; strike
     at 0.40 s.
   - **Special, dash slash:** a deep draw stance at the left hip with a charged pause, then a 9-stud dash drawing the
     sword in one cut. The low follow-through freezes while the cut lines appear behind, then a flick back up.
     1.0 s; the cut lines and their damage at 0.62 s.
2. **Animation tools that make moves like these** (`tools/blender/anim_kit.py`):
   - per-key easing;
   - the joint overlap (hips, chest, shoulder, elbow, wrist);
   - a two-hand grip (an IK target on the sword's handle, blended in and out);
   - export at 60 fps;
   - export **in place**: the travel is taken out of the animation, because the game moves you for real.
3. **The feel in the game:**
   - **Lunges:** each cut moves you forward for real during its swing, like the dodge's dash. Cut 1 about 1.1 studs,
     Cut 2 about 0.8, Cut 3 about 2.6, matching the previews. You never slide back.
   - **Cuts that chain:** the next cut can start at the current cut's **cancel point** (end of its follow-through)
     instead of its full length, so the combo flows. The recovery plays only when you stop attacking.
   - **The dash slash moves you about 9 studs for real.** It goes through foes like the dodge, with the same "carry on
     out of a foe" rule. It hits **every foe along the path** when the cut lines appear.
4. **Effects** (built in Blender like the pack and level-up effects, uploaded as images):
   - **Candy sparkle arc:** a crescent in the sword's slash colour on **every swing**, hit or not. It lies in the
     swing's plane, wipes along in the swing's direction, sheds small stars and fades. Each cut has its own arc shape
     (diagonal down, rising, vertical) to match its move.
   - **Hit:** a spiky star burst plus today's white flash on what you hit. The freeze on a hit is a little longer for
     cuts and longer still for the finisher and the dash slash. Shake as today, bigger for those two.
   - **A ring** snaps out on finisher and dash-slash hits.
   - **Dash slash:** after-images along the dash, and two crossing cut lines that appear on each foe hit, a beat after
     you pass.
   - **The finisher's landing** puffs a small dust ring at your feet.

## Non-goals

- **The combat UI** ("dont touch the combat UI's"): the fight HUD, buttons and screens. No new buttons; the skill
  button now does the dash slash.
- The dodge, draw, sheath, flinch, down, get-up, ready and run moves.
- Other swords (the Forge, later). The tools and config should make a second sword's moves easy, but none is built.
- Changes to boss attacks or wild monsters.

## Anti-goals (a failure even if it works)

- Motion that still looks stiff or robotic: uniform easing, joints moving together, a combo that stutters between
  cuts.
- Sliding back after a lunge, or the root snapping at the end of a move.
- A lunge that pushes you into or through a boss. Lunges stop short of a foe's edge; only the dash goes through.
- A combo that's slower to play than today, or hits that land later than the swing shows.
- Effects that hide a boss's wind-up glow or its closing rings.
- The client deciding damage, reach, or how far the dash may carry you.

## Constraints

- **Server authoritative:**
  - The server decides when a cut lands (`hitAt`), which cut a tap starts (now with the cancel point) and what it
    reaches, from where your character stands at that moment.
  - The movement itself (lunges, the dash) is client physics like today's dodge.
  - For the dash slash the server checks the path from where you stood when it started to where you are when the
    lines appear, clamped to the dash's longest possible length plus a little slack.
- **Damage balance:**
  - The combo's damage per second stays what it is today, measured on the **chained** cycle (my call: each cut runs
    to its cancel point, the last to its length, as a player tapping on plays it: 0.34 + 0.32 + 0.88 = 1.54 s),
    within 2 %. `SwordRules.comboPowerPerSecond` and both balance sims switch to the cancel points; cut powers are
    rescaled to match.
  - The skill's power and cooldown stay.
  - Re-run `tools/balance/bosses` and `tools/balance/wild`; their targets must still hold.
- **Publishing:** the new KeyframeSequences play in Studio unpublished (`SwordAnims` registers them). For the live
  game the owner saves each to Roblox and the ids go in `Config/Swords` (docs/animations.md). This is an owner step
  at the end.
- **Project rules:**
  - Numbers live in `src/shared/Config` (Swords, SwordFx, Combat).
  - Pure rules live in `SwordRules` with Lune tests written first.
  - Sounds: Roblox-licensed only, and today's sword sounds are reused.
  - Blender work runs in a **background** Blender, never in the owner's open file (`anim_kit.build` wipes the scene).
  - Blend hygiene as before.
- Keep DESIGN.md, docs/animations.md, CLAUDE.md, memory and the vault in sync.

## Calls from the builder check (mine)

- **The dash slash doesn't make you untouchable** and shares nothing with the dodge: its own 8 s cooldown, the dodge
  untouched. It gets you out of a ring by moving you, so the balance sims' "fights well" player is unchanged.
- **Walking pauses during a swing.** From a cut's start to its cancel point, and through the dash slash, your walking
  input is held and you don't auto-turn: the lunge carries you, planted feet don't slide, and walking can't push you
  into a boss. Walking comes back at the cancel point; a dodge cancels a swing at any time, so you can still leave a
  ring.
- **Your swing effects are yours.** The arcs, after-images and cut lines play on your own screen. Other players in a
  group fight see your moves (animations replicate) and your hits' bursts as today; no new broadcast.
- **The branch merges after the owner publishes the new moves.** Until then `Config/Swords` keeps the new moves' ids
  empty (Studio plays them unpublished); merging first would leave the live game without them.

## The how, as decided

- **Keys:**
  - Interpolation is set per key: soft (sine ease-in-out) for wind-ups and recoveries; snap (exponential ease-out)
    into and out of the strike; linear through the finisher's spin.
  - Joint lag in frames: chest 1, head 2, shoulder 1, elbow 2, wrist 3, and the free arm 2-4.
- **Two-hand grip:**
  - The left forearm's IK reaches a point 0.55 studs down the handle from the right hand's grip, with the elbow bent
    out and down.
  - Its influence is keyed: on during the crouch (0.02-0.12 s), off in the recovery (0.66-0.80 s).
- **Export:**
  - Every frame at 60 fps; the root's travel is removed (in place).
  - Each move's lunge (distance and when it happens) goes in `Config/Swords` from the same numbers, so animation and
    movement agree.
- **Cancel point:** about the end of each cut's follow-through. Cut 1 about 0.34 s, Cut 2 about 0.32 s. Cut 3 has
  none (the combo ends on it). Tuned in play.
- **The dash slash's path:** as wide as a cut's reach band (a capsule about 4 studs wide). Foes whose edge it touches
  are hit once.
- **Hit freeze:** about 0.08 s on cuts, 0.12 s on the finisher and the dash slash.

## Left to the builder

- How the crescent is drawn in Roblox (a mesh with a gradient texture, a curved Beam, or a flipbook), as long as it
  lies in the swing's plane and wipes along it. The same goes for the burst and cut lines: textures or flipbooks.
- Exact effect timings, sizes and star counts; transition fade times between moves (short, so chaining stays crisp).
- Small pose polish while porting the keys, as long as the moves read as the approved previews.

## Verification

- `lune run tests/run` is green, with tests first for:
  - the cancel point in `SwordRules.nextCut`;
  - the dash path hit test;
  - the lunge that stops short of a foe;
  - damage per second unchanged;
  - the new `Config/Swords` timings (each cut's strike before its cancel point, and its cancel point before its
    length).
- `lune run tools/balance/bosses` and `tools/balance/wild` targets hold.
- Studio, against a wild monster and a boss:
  - the combo chains smoothly with lunges that stop at the boss;
  - the finisher is two-handed;
  - the dash slash carries you through and hits along the path;
  - the arcs, bursts, ring and cut lines play, and the boss's rings stay readable;
  - about 60 fps.
- The owner judges the feel in Studio.
