# Cotton candy UI: baby colours, soft buttons, squircle tiles, 3D avatars

Owner-approved direction, 2026-11-03: look **A "Cotton candy"**, HUD tile **1 "Squircle, the icon pops out"**, party
avatar **b "Element-coloured rim"**. Mockup: `.superpowers/brainstorm/13775-1793692558/content/baby-pastel.html`. The
owner's screenshot of the earlier window mockup (Bag beside Party) is the layout to keep: same windows, same pieces,
restyled.

## Why

The owner's notes on the cream & candy round (`2026-11-03-cream-windows-design.md`, built, not yet merged):

- "Move away from this glossy shadow at the bottom": the dark lip band along the bottom of every candy button.
- "Commit to baby colours, soft buttons/windows, cute/magical colourful pet style UI, make the button colours pop."
- The binder's buttons (close, filter) should get the new look too.
- HUD tiles: hover effects overlap the neighbouring tiles; the Cards, Bag, Manage and Bosses shapes look hand-drawn
  (the ears and horns are stacked boxes) and their hover looks awkward. Wanted: snappy, squishy, high quality motion.
- Party avatars: the white rings are hard to see on the cream cushion. Give them depth, make them look 3D.
- Fight screens stay untouched.

## Goals

- One cute, bright, soft family across the HUD, every window and the binder's buttons.
- No dark band or dark drop shadow under any button, tile or window: soft glows in the thing's own colour instead.
- HUD tiles that read as clean stickers and move like soft toys.
- Party portraits that stand out from the cushion and show each creature's element at a glance.
- Text keeps its contrast floors: body text and numbers 4.5:1 on their surface, button labels 3:1.

## Non-goals (stay exactly as they are)

- Every fight screen and piece of fight UI: boss and wild fight HUDs, the in-fight Shop button, victory and defeat
  screens, damage numbers, ring warnings, boss plates.
- The binder's book itself: pages, card slots, the desk, the set tabs on the book's edge, the page counter, the set
  progress card. Only the binder screen's buttons change (see below).
- Tooltips (dark with a gold edge), the pack opening stage, the loading screen, the welcome cinematic, card faces,
  world name tags and price tags.
- The party cushion itself, the cash pill, the level pill with its paw prints, the buff chip and the mascot.
- Layouts, sizes and what any button does (tiles keep their size; nothing on a phone grows).

## Anti-goals

- Light text on a light fill with nothing to separate it (white on pastel needs its deeper outline).
- A dark lip, black drop shadow or glossy bottom band anywhere in the new look.
- Hover that lets one tile draw over, or push into, its neighbour.
- The new look leaking into a fight screen.

## The look (mockup A, "Cotton candy")

- **Colours:** six baby colours that pop, each with a light and a deep shade:
  bubblegum pink `#ff7fb8`, mint `#3fd6a0`, sky `#4fb4ff`, lilac `#a274ff`, butter `#ffc93f`, peach `#ff9468`
  (light shades about `#ffc4df`, `#a9f2d5`, `#b4e0ff`, `#dccbff`, `#ffe7a3`, `#ffd0bb`). Ink (body text) a soft plum
  `#5b3d6e`.
- **Buttons:** a flat fill in one baby colour, a 3 px white outline, a soft glow of the same colour under it (a blurred
  shape, not a hard shadow), a faint lighter band along the top edge. No dark lip, no darkening down the face. White
  labels with a soft outline in the colour's deep shade; light buttons (butter) keep plum text. Main action butter,
  other choices sky, remove or leave pink, summoned/confirm mint, disabled a soft grey-lilac.
  Pressing squishes the button (squash wide and short, spring back with a little overshoot), snappy.
- **Windows:** a milky pink-lavender body (`#fff8fd` at the top to `#f6ecff` at the bottom), a 4 px white outline,
  round corners, a soft lilac glow under the window instead of the dark shadow. The header band in the baby colour of
  the window's HUD button (light shade at the top to the full colour), white title with its icon. Round pink close
  button with a white outline and a pink glow.
- **Inside windows:** white slots, rows and stat cards with a soft lilac base line under them (`#f0def5`), empty slots
  a pale lilac (`#f4e6fa`), detail boxes a very pale lilac, the chosen thing a butter ring, count chips lilac with
  white text. Bars keep green fills on a pale track.
- **Meaning colours** (good, bad, Power, hints, fair price) stay deep enough to read on the new surfaces; their exact
  shades are re-checked by the contrast test against the new body and slot colours.
- **Pills and chips** (rarity, grade, element, counts) keep their colours, white outlines.

## The binder's buttons

The binder screen's own buttons take the cotton candy button look: the close button (round pink, as in windows), the
filter (magnifier) button, the page arrows, the Cards / Bag tabs and the Rarity guide button. Their sizes and places
stay. The book and everything on it stay as they are. The binder keeps its dark colour theme for the rest of its
chrome.

## HUD tiles (pick 1, "Squircle, the icon pops out")

- Every HUD tile (Cards, Bag, Bosses, Manage and its tray's tiles, Admin, the Rip and Drop context tiles) is one clean
  rounded square: a soft gradient from the colour's light shade at the top to the full colour, a 4 px white outline and
  a soft glow of its own colour under it. The ears and horns go.
- The icon is big and sits over the tile's top edge (about three quarters of the tile wide, a quarter of it above the
  edge) with a small soft shadow, like a sticker popping out. The label sits inside at the bottom, the key letter in a
  white circle on the bottom-right corner.
- Colours: Manage butter, Cards sky, Bag pink, Bosses lilac; the Manage tray's tiles mint, peach, sky and lilac by
  their order; Admin a soft grey-lilac; Rip and Drop peach. Manage still deepens while its tray is open.
- **Hover** (mouse only): a quick squash (wide and short), a stretch as it hops up, and a settle a little bigger and
  higher, about 0.45 s in all; leaving springs it back. The hovered tile always draws above its neighbours, and its
  biggest size never reaches the next tile. **Press:** squashes flat at once, springs back on release. Touch gets the
  press only.
- The Party pill on the cushion gets the same press squish and a small hop on hover.

## Party avatars (pick b, "Element-coloured rim")

- Each portrait sits in a thick rim in its creature's element colour (Ember peach, Tide sky, Bloom mint, Volt butter,
  Shade lilac), a light-to-full gradient on the rim, a deeper ring of the same colour showing under it (the rim's
  thickness, offset down) and a soft shine across its top. A thin white ring between the rim and the picture; the
  picture looks sunk in (a soft dark fade at its top edge).
- The slot number chip is white with an outline in the element colour.
- The summoned creature stays bigger, sits a little higher and keeps its orange OUT tag. Empty slots keep their look.

## Constraints

- Colours and look numbers live in config (a baby colour set next to the windows' theme, plain data where a Lune test
  reads them); no magic numbers in controllers.
- A Lune test checks: every text colour 4.5:1 on every window surface; every baby colour's deep shade at least 3:1
  against white (so white labels outlined in it read); the price bands still apart in hue.
- UI stays built in code through `Util/UIKit` and `Util/Hud`; fights never pass through the new button or tile code.
- Soft glows need a blurred rounded-shape picture (made by a script, uploaded once, stretched with 9-slice and tinted).
- Phones: nothing changes size; the popped-out icons must not cover anything above the tile row (the party cushion's
  mascot, the status column). Check two landscape phones in the Device emulator.

## Calls I made (the owner can overrule)

- The tray tiles are mint, peach, sky and lilac; Admin grey-lilac; Rip and Drop peach (eight tiles, six colours).
- Windows without a HUD button get a sky band (as before).
- The binder's set tabs on the book's edge stay as they are (they belong to the book).
- Window buttons get the same squishy press as the HUD tiles.
- The cushion, cash and level pills stay cream and white (already soft; the owner didn't ask to change them).
- Named kit colours map to baby colours automatically (gold to butter, blue to sky, red to pink, green to mint, neutral
  rows to white).
- On the binder, the open tab and chosen filter chips are butter, the rest white; the filters panel stays dark.
- The HUD icons stay the same pictures, just bigger, with a tinted copy as their shadow.

## Where the soft look applies (answers to the builder check)

- **Which buttons:** buttons inside a window that has the window theme (every `UIKit.panel` window from the cream
  round, plus the Bag, card detail, confirm boxes and challenge popups that use the window look), the binder screen's
  buttons (it opts in), and the HUD tiles (built by `Util/Hud`). Nothing else changes: a button built outside a themed
  window or the binder keeps today's look. That covers every fight screen, the pack opening and its results, the
  welcome cinematic, the loading screen, the Dungeon's run HUD, the placement bar and the Frontier's "Back to the
  shops" button. The opt-in is inherited by everything inside the window or binder, like the theme is today.
- **Which colour each button gets:** automatic for the kit's named colours, so most call sites don't change: the main
  action gold (`Colors.Accent`) becomes butter, `Colors.Secondary` sky, `Colors.Danger` pink, `Colors.Success` mint,
  `Colors.Locked` grey-lilac, and the neutral row colours (`Colors.Row`, `Colors.Panel`, the palette's row) white with
  plum text. The few buttons that pass a colour of their own (for example the case's price stepper blue) are converted
  by hand to the nearest role. Rarity, grade and element chips keep their colours.
- **The binder's buttons:** every button on the binder screen gets the soft look, the filters panel's buttons and its
  close button included (the filters panel itself, like the rest of the binder's chrome, stays dark). The open Cards
  or Bag tab and chosen filter chips are butter, the others white with plum text.
- **The popped-out icons** are today's HUD icon pictures (`Config/UIIcons`), shown bigger; their small shadow is a
  copy of the same picture tinted dark, faded and offset down. No new icon art.
- **The soft glow picture** is made by a script (a blurred rounded shape, white on clear), uploaded once through the
  Studio MCP as earlier UI art was, and drawn 9-sliced and tinted under each button, tile, avatar and window. A
  window's glow may fall outside the window onto the dimmed screen behind it.
- **Hover size:** the squash peaks at most 10% wider, the settle at about 6% bigger (today 7%). A test checks that the
  hovered tile at its widest, with its key chip, stays inside the gap to the next tile; the soft glow may overlap
  (it's drawn under every tile).
- **The contrast test** covers the colours declared in config (the window theme and the baby colours); controllers
  already take their text colours from the theme's palette.

## Left to the builder

- Exact light and deep shades within the values above, tuned to pass the contrast test.
- How the soft button look is switched on (for example an attribute the binder screen and windows set) as long as
  fight screens and anything else unthemed keep today's button look.
- Whether the theme keeps its "cream" name in code.
- The exact squash, stretch and timing numbers, within "snappy, about 0.45 s".
