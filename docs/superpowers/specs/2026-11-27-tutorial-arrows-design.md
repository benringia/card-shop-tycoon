# Tutorial arrows (design)

Owner 2026-11-27 (polish list item 5): "Research some tutorial best practices on roblox on the internet and apply it to
our game. Maybe just use arrows instead of paws. to be simple." Mockups on real frames from the owner's 11-27
recording: https://claude.ai/artifact/CS1X1JKgH9R5JeMQ3J7QLz. Owner: "B and 1, go".

## Why

- Roblox's onboarding guide (Creator Docs: Onboarding, Onboarding techniques) gives as its first visual cues "a bouncing
  arrow pointing at a button in the UI" and "a glowing trail in the world that directs players to a destination"; its
  Hello Kitty Cafe example dims the screen, outlines the button and points an arrow at it. Players skip text, and an
  arrow needs no reading (kids still learning to read, phones). The rest of the guide we already follow: lessons on
  first use, the stuck helper (timed hints), short lines, never interrupting, a funnel event a step.
- The recording shows three faults in today's paw cues: the paw trail draws the whole route, so far prints pile into a
  gold smear at the horizon; the goal's paw sat under the talk card on Chikin's walk to the Wild; and a goal off the
  screen or behind the camera shows nothing.
- Launch weekend's funnel through Pish's tour: 17 woke in town, 15 opened the gift, 12 summoned, 10 built the rack, 8
  finished.

## Goals, non-goals, anti-goals

- Goals: an arrow points at what to use (pick B); arrows lying on the ground show the next stretch of the way (pick 1);
  an arrow at the screen's edge when the goal is off screen; the talk card keeps clear of the goal's arrow.
- Non-goals: the tour's steps and lines (but Chikin's "Follow my paws"), the spotlight, the gold ring and its ping;
  paws as Pish's brand (his face, the tour card's progress paws, the Pet button, the Paw icon).
- Anti-goals: an arrow on top of what it points at or under the talk card; a trail that reads as a portal's glowing
  line; arrows hidden by a closed door (owner 2026-11-10: the paws had to show through it).

## Approaches

- Pick 1, what points at a button: A the recipes' gold arrow turned down; **B a chunky gold arrow with a white sticker
  edge and a dark outline (picked)**: reads on light walls and dark streets alike; C three chevrons lighting up toward
  the button.
- Pick 2, what shows the way: **1 chevrons lying on the ground, only the next stretch (picked)**; 2 a glowing path to
  the goal (looks like the portals' own lines).
- How the ground chevrons are drawn: a SurfaceGui with AlwaysOnTop on a small flat invisible part per chevron (true
  perspective, still drawn over walls and doors) instead of today's flat screen images (can't lie on the ground) or a
  Beam (hidden by walls).

## Design

1. **The pointer** (`Util/TutorialCues.pointAt`, was `pawOn`): the new `ArrowCue` picture where the paw was: over a
   button pointing down, under a top-bar button pointing up, beside a left-column tile pointing left, with the same
   bounce; over a thing in the world, bobbing over it. Its art carries its own white edge and outline: no dark backing
   and no halo. The ring, its dark edge, the ping and the spotlight are unchanged. `scrollPaw` becomes `scrollHint`
   (the arrow sliding down a list).
2. **Off screen** (new): a world thing's arrow that is off the screen or behind the camera waits at the screen's edge
   pointing the way to turn (pure `CueShape.offscreen`): on the edge along the way to it, inside `margin` px and a band
   between the `top` and `bottom` shares of the height (clear of the talk card, the bottom tiles and a phone's
   thumbstick); behind, at the nearer side, half way down the band; it nudges toward the edge.
3. **The trail** (`TutorialCues.trail`): `Chevron` pictures lying flat every `gap` studs along the walking route
   (pathfinding as today), only the next `ahead` beyond the player (pure `TrailRules.progress` and `TrailRules.ahead`),
   the last `fade` fading out, a glow flowing toward the goal. Each is a SurfaceGui (AlwaysOnTop, LightInfluence 0) on
   a small invisible anchored part, client-side. The controllers still redraw the trail every 8 studs; between redraws
   the shown stretch moves with the player.
4. **The talk card** (`Util/TutorialTalk`): with no button to keep clear, it keeps clear of the world arrow's box (its
   bounce included), moving to the bottom when the arrow would sit under it.
5. **Words**: Chikin's "Follow my paws to the Wild!" becomes "Follow the arrows to the Wild!".
6. **Numbers** in `Config/Cues`: `POINTER` (size, min, sideShare), `TRAIL` (gap, ahead, fade, size, lift,
   pixelsPerStud, dim, rotation, max), `OFFSCREEN` (margin, top, bottom). Pictures: `tools/ui-icons/make_cue_arrows.py`
   writes `assets/ui/icons/ArrowCue.png` and `Chevron.png` (ids in `Config/UIIcons`).

## Left to the builder

The art's proportions within the mockup's look, the chevron's turn on its surface (checked in Studio), names inside
the modules.
