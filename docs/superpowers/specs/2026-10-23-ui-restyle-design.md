# UI restyle — design

The game's screens get the bright, clean look of the reference screenshots the owner shared (blue gradient
headers, light-blue panels, white cards, chunky buttons with a bottom lip, a red close button on the corner),
plus snappy animations and five reworked screens. Branch: `feature/ui-restyle` (from `feature/card-design`).

Built in five parts, one at a time, each checked in Studio before the next: **A** HUD and base style,
**B** Binder 2.0, **C** Rarity guide, **D** Card inspector, **E** Build menu.

## Intent

- Players should find the UI pleasant and readable at a glance, on phones first.
- The binder should feel like a real collector's binder, the rarest pulls easy to read about (odds) and to
  admire (inspector).
- The Build menu should show what you're buying (a picture of every model), not a list of names.

Non-goals: the town redesign (a separate project), new game systems, monetisation screens (Robux shop).
Anti-goals: copying another game's art or layout exactly; images that can fail to load (everything here is
built from UI objects, our own uploaded images, or 3D models already in the game); any change to what the
server allows (all screens keep sending the same remotes).

## Constraints (from CLAUDE.md, unchanged)

Mobile-first: tap targets ≥ 48px, test on a landscape phone. HUD buttons clear of the thumbstick and jump
button. UI built in code with `Util/UIKit`; card faces with `Util/CardFace`. Text: plain ASCII, `·` and emoji
only. Panels made with `UIKit.panel` hide touch controls while open. All numbers in `Config`.

## Base style (done in Part A, already started)

`Util/UIKit` carries the look, so every panel changes at once:

- Colours: Panel (light blue body), Row (white cards), Accent (blue-violet: primary buttons, selected tabs),
  Success, Danger (red), Locked, Ink and InkSoft (navy text on light surfaces), Outline, header gradient.
- `UIKit.panel`: blue gradient header with the title, white border, red close button on the top-right corner,
  light body, scrolling list. `UIKit.header`, `UIKit.closeButton`, `UIKit.outline` are public for custom screens.
- `UIKit.button`: rounded, a darker lip along the bottom (a gradient, so colour changes keep it), outline, and
  text that picks white or navy for the button colour (unless the caller set a colour).
- `UIKit.label` with Colors.Text / Subtext picks white or navy from the surface behind it, and re-picks when
  the label moves or its background changes.
- Header height stays close to the old title row, so panels that put a subtitle under the title still fit.

## Part A — HUD and animations

Layout (all from one HUD module so positions stay consistent):

| Spot | Contents |
|---|---|
| Left, middle: a blue **Manage** tile (icon above label) | Tapping fans out white round buttons in an arc: 🔨 Build, 💲 Prices, 👷 Jobs, 🐾 Party. Manage turns into a white ✖ that closes the fan. Opening any of them closes the fan. |
| Bottom centre: blue tiles | 📖 Cards (binder, key B), 🎒 Bag (key I). Contextual tiles appear in the same row while usable: Rip a pack (T), Drop box (G) — orange. |
| Top centre: pills | A dark pill with 💵 cash; a round level badge with the level number; a ✨ Star Shards pill. Under them a small status pill with XP to the next level. |
| Bottom right | Party bar and buff badge, as now. |
| Frontier | "Back to the shops" sits just under the top pills. |

- A `Util/Hud` module owns the layout: controllers register their button (`Hud.tile`, `Hud.fanButton`,
  `Hud.contextTile`) with an icon, label, key hint and order, instead of positioning their own. Visibility
  rules (contextual tiles, Frontier) stay in the controllers.
- Animations (`Util/Motion`, numbers in `Config/UIMotion`): press squash (0.95) and spring back; fan buttons
  pop out one after another (about 0.25s in total) and fold back fast; panels open with a quick scale-up from
  0.85 and fade, close with a fast shrink-fade; pills bump when their number changes. Every `UIKit.panel`
  gets the open/close motion automatically (it watches Visible).
- The old bottom-right cash / level / XP status moves to the top pills; toasts stay where they are.

## Part B — Binder 2.0

A full-screen binder instead of a panel:

- **Cover page** on the left of the first spread: the set's name, "34 / 35" progress, a big emblem, in the
  set's colour. Later spreads are two pages of pockets with rings down the middle.
- **Set tabs** on the binder's left edge: FIRST SPARK, FRONTIER (one per set in `Cards.BySet`); tapping jumps
  to that set's cover.
- **Navigation:** a page counter pill under the binder ("2-3 / 14"); arrow buttons beside it with key hints:
  Q / E one spread back / forward, A / D jump to the first / last spread of the set. Close (✖) top-right.
- **Filters button (F)** opens a Filters panel on the right: search, Show (All / Owned / Missing), Sort by
  (Set / Value / Copies / Rarity), rarity chips (multi-select). While it's open the binder shrinks and slides
  left so both fit; closing it slides the binder back. The old filter chip row goes.
- **Set progress card** bottom-right: set name, cards owned "34 / 35" with a bar, and the set's total value
  of owned copies.
- **Rarity guide button** bottom-left opens Part C.
- Pockets keep the current tile (card face, chip row with copies and best grade/level); missing cards show the
  "?" / "Found in the Frontier" slot. Tapping a card opens the inspector (Part D) instead of the old detail
  view; the copies list, Add to party and Jobs actions move into the inspector's info panel.
- Pocket count per page still comes from `PocketLayout` (3 x 3 on big screens, fewer on phones).

## Part C — Rarity guide

A panel listing every rarity from most common to rarest, grouped (Common · Rare and Very Rare · Epic and
Legendary · Frontier). Each entry: a sample card face of that rarity, the rarity name, the chance that any one
card pulled from a First Spark pack is that rarity, and "about 1 in N cards". Then a short section on Foil
(chance and value multiplier) and Grades (C/B/A/S chances and their bonus), and a line that Frontier cards
are found in the Frontier, never in packs.

- The odds are worked out from `Config/Packs` (each slot's weights, averaged over the pack's slots),
  `Rarities.FOIL_CHANCE` and `Beasts.GRADE_CHANCES` by a pure `Util/OddsRules` module with a Lune test, so the
  guide can never drift from the real rolls. Today: Common 74%, Rare 19.6%, Very Rare 3%, Epic 2.8%,
  Legendary 0.6% of cards pulled.

## Part D — Card inspector

Tapping a card (binder, cases you manage) opens the inspector:

- A **real 3D card** placed in front of the camera (a thin part with the card face on its front and the card
  back on its back, both drawn with `CardFace`), behind it a dark backdrop. Drag (mouse or touch) to tilt it;
  it eases back to facing you when released. **Flip** turns it over (and a swipe past the edge flips too).
  Its rarity glow, foil holo, Grade S rim and the Legendary element aura (Part of the card design work) all
  show on it.
- An **info panel** beside it: name, value, rarity chip, card number "#06 / 35", grade and growth, then the
  copies list (best first) with Add to party / Assign job / Condense hints as the old detail view had, and
  Flip / Close buttons.
- Closing restores the camera. While open, character controls are paused.

## Part E — Build menu

The Build menu becomes a "Build" panel in the reference's style:

- Category tabs along the top: Shelves (Products), Cases (Glass Showcase, Collector Case), Fixtures (Condenser
  and other non-shelf fixtures), Decor (future). Categories come from a `category` field added to each entry in
  `Config/Shelves` (no new saved data).
- A grid of tiles. Each tile: a **3D picture of the actual model** (a ViewportFrame with the prop model from
  `Util/Props`, or its code stand-in), the name, and a price button. Locked items show "Lv 8" on a grey button;
  ones you can't afford show the price in red. Tapping buys/places exactly as the current menu does.
- The shelf edit menu (move, sell, set prices) gets the new style but keeps its behaviour.

## Testing

- Lune: `OddsRules` (rarity, foil and grade odds; per-slot averaging; sums to 1) and any other pure layout
  helpers (fan positions, page counts) get specs. Existing tests stay green.
- Studio, each part: desktop and landscape phone in the Device emulator; every panel opens and closes with
  its motion; nothing overlaps the thumbstick or jump button; keys still work (B, I, T, G, Q/E/A/D/F in the
  binder); two players see their own HUD.

## Docs

DESIGN.md: the HUD layout (section 4 UI), the binder, rarity guide, inspector and build menu notes, new files
(`Util/Hud`, `Util/Motion`, `Util/OddsRules`, `Config/UIMotion`) in 10.2. CLAUDE.md: the UI section mentions
`Util/Hud` for HUD buttons.

## Builder's calls (left open on purpose)

Exact colours and sizes beyond the palette above, icon emoji, the arc's radius, the backdrop for the
inspector, and how the binder's cover emblem is drawn — tuned while building and judged in screenshots.
