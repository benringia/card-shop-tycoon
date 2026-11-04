# Town HUD redesign: "Creature pals"

Owner-approved direction, 2026-11-03. Mockup: `.superpowers/brainstorm/13775-1793692558/content/hud-directions.html`
(option C).

## Why

The always-on HUD (dark slate tiles, a dark party tray, plain pills) reads as generic and doesn't say what the game is
about. The owner wants it to grow out of the core loop: open packs, collect creature cards, run the shop, summon
creatures and fight with them. Of three mockups (shop counter, holo cards, creature pals) the owner picked **creature
pals**: soft, chunky, cute, with the game's creatures living in the HUD. A cute creature peeking over the party bar was
the owner's own idea and is the centrepiece.

## Goals

- The HUD looks like it belongs to a cute creature-collecting card game at a glance, on phone and PC.
- A mascot creature peeks over the party bar and feels alive (blinks, breathes, reacts to summons and taps).
- The mascot can be swapped for another creature (the owner will replace Cindercub with a creature based on their own
  real-life pet once everything else is final) by changing one config entry and its pictures, no code.
- Nothing moves: every element keeps today's place, size class and behaviour.

## Non-goals

- Panels and windows (Party, Bag, Binder, Bosses, shop menus): untouched.
- Fight HUDs (boss `CombatHud`, the wild fight HUD, the in-fight Shop button), toasts, the loading screen, the
  defeat and victory screens.
- The Frontier's "Back to the shops" button and the Dungeon's run line and Leave button (place-specific, not part of
  the shared HUD).
- New HUD features or buttons. No change to what any button does.
- A sticker per creature (the summoned creature peeking instead of the mascot): maybe later, not now.

## Anti-goals (a failure even if it works)

- Tap targets under 48 px on a phone, or anything covering the mobile thumbstick or jump button.
- A HUD that costs frame time: no per-frame work on more than a handful of instances, no per-frame tweens per tile.
- Clutter: decoration must not make numbers (cash, level, rest timers) harder to read.
- Text with glyphs the fonts can't draw (plain ASCII, `·` and emoji only).

## Scope: what's restyled

Everything that's on screen all the time in town (and the same pieces in the Frontier and Dungeon, which share them):

1. **Side tiles** (`Util/Hud` group Side): Manage, the Admin tile (Studio only).
2. **Manage tray** (`Hud.fanButton`: Build, Pricing, Jobs, Party): the buttons that slide out from Manage.
3. **Bottom tiles** (group Bottom): Cards [B], Bag [I], Bosses [K].
4. **Context tiles** (group Context): Rip [T], Drop [G], shown only when they apply.
5. **Party bar** (`PartyBarController`): the party portrait button, three party slots, slot keys 1-3, the summoned
   slot, resting shade and timer (green "+" at the spring), the slot tooltip.
6. **Status corner** (`UIController`): cash, level and XP.
7. **Buff chip** (`BuffController`): the perk chip above cash.

## The look (from mockup C)

All sizes are today's (`Config/HudLayout`, `Party.BAR`), scaled with the HUD's existing screen scale.

- **Tiles (side, bottom):** a rounded square (corner about a quarter of its size) filled with a soft top-to-bottom
  gradient, a thick white outline (4 px at full scale) and a soft drop shadow (an offset darker copy underneath, no
  blur needed). The icon (`Config/UIIcons`) sits in the upper part, the label in FredokaOne white under it. The key
  letter sits in a small white circle on the bottom-right corner. Colours:
  - Cards: blue (`#7fb8ff` to `#4a7fe0`) with two little round ears on top.
  - Bag: coral (`#ff9e7a` to `#f0603c`) with two little round ears.
  - Bosses: purple (`#c79bff` to `#8a55e0`) with two small white horns.
  - Manage: yellow (`#ffd36b` to `#f2a52b`), no ears.
  - Admin (Studio only): grey, no ears.
  Ears and horns sit behind the tile's outline, poking out of its top edge; they're white-outlined like the tile.
- **Manage tray buttons:** the same tile style, a little smaller (as today), each in its own soft colour, no ears.
- **Context tiles (Rip, Drop):** the tile style in orange (today's `HudLayout.CONTEXT`), no ears.
- **Party bar:** a cream cushion (`#fff6ea` to `#f6dfc4`) with a white outline and a darker cream base line, rounded
  ends. Party slots become round portraits (the card art, as today) in white rings; the summoned one is larger with
  an orange ring, an orange glow and an "OUT" tag above it. The level sits in a white pill under each portrait; the
  slot key (1-3) stays as a small chip. A resting slot goes dark with its timer as today, and green with a "+" at the
  spring as today. An empty slot is a faint ring with a "+" (tapping it picks a card, as today's dashed "+"). A small
  "Party" pill on the cushion's left end replaces the avatar button and opens the Party panel; tapping the cushion's
  empty area does too.
- **Mascot:** see below.
- **Cash:** a green pill (`#8ee09a` to `#3fb35a`) with a white outline; a big gold coin icon overlaps its left end. The
  number is formatted exactly as today.
- **Level and XP:** a white pill; a big gold star overlaps its left end with the level number in it; five paw prints
  (`UIIcons.Paw`) fill left to right with XP progress, each paw filling gradually (a paw is a faint copy with a
  coloured copy clipped to its share on top). The exact numbers ("86k / 225k" style, from today's text) show in a
  tooltip on hover or tap (`Util/Tooltip`).
- **Buff chip:** a small white pill with the perk's emoji and value in the perk's colour.
- **Scale:** each piece keeps today's scaling behaviour (the tiles follow `HudLayout.SCALE`; the party bar and status
  corner keep whatever they do now).

## The mascot

- **Who:** Cindercub now. Everything about it lives in one config entry (`Config/HudMascot`: name, picture ids, eye
  spots for blinking, voice sound id, sizes and offsets). Swapping in another creature means new pictures and that entry.
- **Pictures:** a sticker of the mascot peeking: its head (ears, the flame on top) and its two front paws, cut off
  at the paws, transparent background; and its tail as a second small sticker. Made the way the card art is made
  (Figma's image generator, the card art's painterly style, described from the in-game model and the card art), cut out
  to transparent PNGs, uploaded as images. The owner's real-pet mascot later goes through the same steps.
- **Placement:** behind-and-over the cushion's top edge near its right end, so the paws rest on the edge and the eyes
  are just above it (as in the mockup); the tail hangs down the cushion's right side. It never covers a portrait's
  face, level or timer.
- **Alive:**
  - It breathes (a slow, tiny scale pulse).
  - It blinks every few seconds (random within a range): two small eyelid ovals in its fur colour drawn over its eyes
    for a moment (eye spots and lid colour from the config, so any mascot can blink).
  - Its tail sways slowly.
  - When you summon, unsummon or swap, it ducks down behind the cushion and pops back up a moment later (it's drawn
    in a clipping frame whose bottom edge is the cushion's top).
  - Tapping it makes it bounce and chirp (its voice from the config, quiet, `Party.VOICE`-style pitch wobble). The tap
    doesn't open anything.
- **Cost:** the mascot is a few ImageLabels; its motion is a couple of tweens and one timer, nothing per frame per tile.
- **Hidden with the bar:** it belongs to the party bar, so it hides whenever the bar does (fights hide the status row
  today, `BattleController` `HUD_NAMES`).

## Constraints

- Mobile first: every tap target at least 48 px at the smallest HUD scale (`HudLayout.SCALE.MIN`), nothing over the
  thumbstick or jump button; check landscape phone in the Device emulator.
- UI built in code with `Util/UIKit` (CLAUDE.md); fonts FredokaOne and Nunito Bold via `Util/FontStyle`.
- Numbers in config (`Config/HudLayout` colours and sizes, `Config/HudMascot`), no magic numbers in controllers.
- Pure logic (blink timing, paw fill shares, duck timing) in Roblox-free modules with Lune tests.
- Images uploaded as Roblox images; check every id loads (draw it and read IsLoaded) before calling it done.
- Same HUD in the main game, the Frontier and the Dungeon.

## Decided by the owner

- Direction C, creature pals, as in the mockup.
- A creature peeks over the party bar; Cindercub for now; the owner replaces it later with a creature based on their
  own pet.
- Only the always-on HUD; panels are out of scope.

## Calls I made (the owner can overrule)

- Manage tray buttons and the context tiles (Rip, Drop) get the same candy style.
- A small "Party" pill replaces today's avatar button so new players can still find the Party panel.
- XP exact numbers move into a tooltip; the paws fill gradually rather than in 20% steps.
- Tapping the mascot makes it bounce and chirp and opens nothing.
- The mascot ducks on summon, unsummon and swap; it doesn't react to anything else (pack rips, cash) for now.
- No flame flicker: the flame is part of the head sticker, and splitting it out isn't worth it yet.
- The Admin tile (Studio only) gets a plain grey tile.

## Left to the builder

- Exact pixel offsets, outline and shadow sizes, ear and horn shapes (code-built from rounded frames, or tiny images).
- How the tile style is shared (a UIKit helper or inside `Util/Hud`).
- Timing values (blink range, duck length, breathing period) within "subtle".
- How the paw fill is drawn (clipping frame or UIGradient), as long as it costs nothing per frame.
