# Windows in the creature pals look: "Cream & candy"

Owner-approved direction, 2026-11-03 (pick A of two). Mockup:
`.superpowers/brainstorm/13775-1793692558/content/panels-hover-fonts.html` (section 1, option A).

## Why

The HUD now has the creature pals look (cream party cushion, candy tiles with thick white outlines,
`docs/superpowers/specs/2026-11-03-hud-creature-pals-design.md`), but every window still uses the old dark slate look
(look E). The owner wants the windows to match the HUD so the game reads as one family.

## Goals

- Every window players open in town and the Frontier shares the HUD's look: cream bodies, thick white outlines, soft
  shadows, a header band in the colour of the window's HUD button, white rounded rows and slots, brown text, candy
  buttons with white outlines.
- Text stays easy to read: body text and numbers at least 4.5:1 contrast on their surface (cream and white), button
  labels at least 3:1 (light buttons keep dark text, as UIKit picks today); header titles rely on their dark outline.
- Card art, rarity, grade and element colours keep their meaning.

## Non-goals (stay exactly as they are)

- **The binder** (the 3D book, its pages, the desk, the binder screen's own buttons and labels).
- **Every fight screen**: the boss and wild fight HUDs, the victory and defeat screens, damage numbers, the boss plate,
  ring warnings, the in-fight Shop button.
- The pack opening stage, the loading screen, the welcome cinematic, card faces, world name tags and price tags.
- The HUD itself (already done).
- Layouts, sizes and what any button does.

## Anti-goals

- Light text left on a cream surface anywhere (white labels that become unreadable).
- A light theme that leaks into a fight or the binder.
- Glare: no pure white body fills over large areas (the body is cream; white is for rows, slots and outlines).

## Scope: the windows

Built with `UIKit.panel` today: Party, Shop Jobs, Prices, Set Price, Shop (build menu), Shelf, Order Stock, Boss
Ladder, Card Condenser, Grading Station, Cards (card case browse), Pick a card and the showcase card case, The
Frontier, Rarity guide, the first-sword popup, and the Studio admin panel. Built their own way: the Bag (opened from
the Bag tile, drawn over the binder's backdrop) and the card detail window (a card's details beside its big face).
Their shared pieces get the look too: rows, stat cards, pills, bars, tabs, empty slots, count chips, the close
button, the window's drop shadow, the dim behind a window, and small confirm dialogs.

## The look (mockup A)

- **Body:** a soft top-to-bottom cream gradient (`#fff8ee` to `#f6e3c9`), a thick white outline (4 px), rounder
  corners (about 22 px), a soft drop shadow under it instead of the black drop lip.
- **Header band:** the window's HUD button colour as a gradient, its icon and a white FredokaOne title that keeps a
  dark outline (so it reads on the light mint and sky bands too):
  Bag coral, Cards and card detail blue, Bosses purple, Party lilac, Shop mint, Prices sky, Jobs pink (the Manage
  tray's colours by its order), every other window sky.
- **Rows, slots, stat cards:** white with a soft cream edge (`#f0dcc2`) and a slightly darker cream base line;
  empty slots a deeper cream; the selected one a gold ring.
- **Text:** brown (`#6b4a2a`) for body and numbers, a lighter brown for secondary text, a dark amber (about
  `#a85d10`, dark enough to read on white) for hints and small headings; Montserrat Bold body and FredokaOne titles
  (already applied).
- **Bars:** cream tracks with today's green fills; XP bars blue as now.
- **Buttons:** today's candy colours (gold main action, blue other, red remove or leave, green summoned) with a 3 px
  white outline instead of the black one, white text with a soft outline; light buttons keep dark text.
- **Close button:** red circle with a white outline on the window's corner.
- **Pills and chips** (rarity, grade, element, counts): their colours as now, with white outlines instead of black.
- **Tooltips over windows:** unchanged (dark with a gold edge reads well over cream).

## Constraints

- Colour and size numbers in config: a cream theme next to today's dark tokens (`Config/UIStyle`), the dark set kept
  for the binder and fights; plain-data colours where a Lune test reads them.
- A Lune test checks the cream theme's text and surface pairs meet the contrast floors above.
- UI built in code with `Util/UIKit`; windows opt into the theme through UIKit, not hard-coded colours.
- Phones: nothing changes size; check two landscape phones in the Device emulator.

## Decided by the owner

- Direction A (cream & candy) for the windows, the binder excepted; fights untouched.
- Body font Montserrat Bold, titles FredokaOne (done); bouncy hover on HUD buttons (done).

## Calls I made (the owner can overrule)

- Header colours follow each window's HUD button; windows without a button get sky blue.
- Tooltips stay dark with a gold edge.
- The pack opening stage keeps its look (it's a scene, like the binder).
- The Studio admin panel gets the look too (it's a window).
- Small confirm dialogs and the dim behind a window follow the theme.

## Left to the builder

- Exact cream shades for secondary surfaces and borders within the palette above.
- How windows opt in (a theme argument to `UIKit.panel`, or a default with the binder opting out).
- The order windows are converted in.
