# UI project 2: the 3D binder ("Collector's Desk")

Agreed with the user on 2026-10-29: of three mockups (A Collector's Desk, B Big Pages, C The Binder Shelf) the user
picked **A**. Mockup: `.superpowers/brainstorm/3177-1793255093/content/binder-concepts.html` (git-ignored; open it
through the brainstorm companion, it turns pages). Calls marked **(Claude's call)** were not chosen by the user;
change them freely.

## 1. Intent

The binder is the screen players open most: it is the collection, the way into every card, and the goal of the game
("complete the card set binder"). Today it is a flat 2D book that fakes a page turn by squashing a frame. It has known
problems that UI pass 1 deliberately left for this project: squeezed pages, a cramped cover page, tiny labels under
the cards, set tabs cut off at the book's edge.

Project 2 replaces the 2D book with a **real 3D ring binder lying open on a wooden desk** under warm lamp light. Its
pages bend as they turn, and a card you pick lifts out of its plastic sleeve. It should feel like a real collector's
binder: the user picked the concept with the most cards on show and the most "real binder" feel over the kid-sized
big pages.

This is project 2 of 3 (the agreed order): (1) the style kit and 2D screens (done, merged 2026-10-29); (2) this
binder; (3) cards in the world (shelf card models, bigger cards in bigger glass cases).

## 2. Goals, non-goals, anti-goals

Goals
- The binder screen is a 3D scene: a desk, a lamp, an open ring binder (section 3).
- 3 x 3 pockets per page, 18 cards a spread, in plastic sleeves that catch the lamp light (section 4).
- Real page turns: the page bends and lifts from its outer edge, travels over the rings and lands, with a shadow and
  a page sound (section 5).
- Set dividers as coloured plastic tabs sticking out of the binder's right edge (section 6).
- Hovering a card shows its tooltip, as today; clicking one lifts it out of its sleeve toward you, then the card view
  opens (section 7).
- Everything the binder does today keeps working (section 8).
- Works on phones in landscape (section 9).

Non-goals
- Project 3 (cards in the world) and any change to shop displays.
- Changes to collection data, saving, or what counts as owned: this is a client-only rebuild; no server or remote
  changes are expected.
- The card view (CardDetailController and the 3D card) and the Bag's contents: kept as they are. The Bag's phone
  layout stays on the backlog.
- New sets, set art, or card art.

Anti-goals (would make it a failure even if it technically works)
- Slower to use than today: finding a card, turning pages quickly (holding E or tapping fast) and getting to the card
  view must feel at least as quick.
- Frame drops or a long freeze when opening the binder or turning pages on a mid-range phone.
- Anything of the game world showing through or behind the scene (other players, customers' bubbles, the sky).
- Losing a current feature (list in section 8).
- Unreadable on phones: if the 3 x 3 cards can't be told apart on a landscape phone, the design has failed there.

## 3. The scene

- **Where:** like the card view, the scene lives on a stage far from the world, seen only by the local player
  (parts under the camera or in a client-only folder). It has its own stage position, apart from the card view's
  (`Inspector.STAGE_POSITION`), because the card view opens from the binder and the binder must be there again when
  it closes. Nothing of the world may be visible: the desk and a dark backdrop fill the view. Roblox's top bar strip
  is covered as today.
- **Camera:** fixed, looking down at the open binder from a little in front, so the binder reads as lying on the desk
  at an angle (the mockup tilts the book about 24 degrees). A narrow field of view keeps the far page from looking
  much smaller than the near one. The camera fits the binder into the screen area the 2D corner buttons leave free
  (section 8), the way `getBookLayout` fits the 2D book today.
- **Desk:** a wooden counter top filling the view, warm wood with visible planks.
- **Lamp:** warm light pooled on the binder, darker toward the edges of the screen. A real light in the scene, so the
  sleeves catch it.
- **Binder:** black leather case with a stitched seam around the edge (as today's 2D design, `Collection.BOOK`
  colours), dark grey pages, a chrome ring rail down the middle with three rings. Pages sit around the rings.
- Built in code from parts and materials (Roblox has Wood, Leather, Metal, Glass) **(Claude's call)**; a modelled
  binder (Blender) only if the code-built one looks plain. How the rings are made is the builder's choice.

## 4. Pages and pockets

- **3 x 3 pockets per page on every screen**, 18 cards a spread (the user's pick; no phone fallback to bigger pockets,
  see section 9).
- Each pocket: a plastic sleeve over the card. The card face is today's (`Util/CardFace`: `render` for owned cards,
  `renderMissing` for the "?" slot with its number), so rarity rims, foil and Legendary looks stay the same. The sleeve
  gets a soft glint that moves a little with the lamp light (a real see-through material or a glint overlay, the
  builder's choice).
- The chips under each card stay ("Owned 3", or "x3" with "B · Lv 4 · Job · Party"), drawn small along the sleeve's
  bottom edge on the page.
- **Spread 1** of each set is the set's cover on the left page (today's cover: the pack art, set name, "30 / 35
  collected", worth, a progress bar) and the first 9 cards on the right. Later spreads hold 18 cards. Card order,
  spreads and the page counter follow `Util/BinderSpreads` with 9 pockets a page.
- Only the open spread needs full card faces. Pages that aren't showing need nothing drawn.

## 5. Turning pages

- **What "real" means here:** the turning page is not a stiff board. It lifts at its outer edge first and bends as it
  travels over the rings, flattening as it lands. It darkens as it stands up and casts a shadow on the page underneath
  (the mockup's shading is the minimum). Around half a second a turn **(Claude's call; tune by feel)**.
- **Sound:** a soft paper or plastic page-turn sound on each turn (a free Creator Store sound; none exists in the game
  yet).
- **Ways to turn:** Q / E and the on-screen arrows (as today); a swipe across the binder (as today on phones);
  clicking the page itself, right page forward and left page back; and dragging the page's outer edge, where the
  page follows the pointer and finishes the turn or falls back on release.
- **Fast turning:** pressing E several times quickly, or holding it, must not wait for each turn to finish. Turns
  overlap or skip ahead so the player can riffle through a set (anti-goal: slower than today).
- Turning stops at the first and last spread, as today.
- **Performance:** a bending page with full card faces on both sides may be too heavy to build per turn. A lighter
  version of the cards on the moving page (art and rim only) while it turns is acceptable; full faces must be back
  the moment it lands. The approach is the builder's choice, within the anti-goals.

## 6. Sets

- Sets are dividers: coloured plastic tabs sticking out of the binder's right edge, one per set in `Collection.SETS`
  order, labelled with the set's name, in its colour (`Collection.SET_COLORS`). The open set's tab sticks out further,
  as today. Tabs are never cut off by the screen edge or the corner buttons.
- Clicking a tab opens that set at its spread 1. A short page riffle or the binder closing and reopening on the new
  set is fine; the builder picks.
- One set is open at a time, as today: filters, the page counter and the progress card are per set.

## 7. Cards: hover and pick

- **Hover (mouse):** the card's tooltip (`Util/CardTips`, as today), beside the binder, level with the card, never
  covering a card. The pocket under the pointer lifts slightly or brightens so it's clear which card is meant.
- **Hold (touch):** holding a finger on a card for `UIStyle.LONG_PRESS` shows the same tooltip; lifting hides it.
- **Click / tap:** the card slides up out of its sleeve and comes toward the camera, then the card view opens on it
  (CardDetailController, unchanged). Closing the card view returns to the binder on the same spread. The lift must
  not delay the card view noticeably (around a third of a second).
- Missing cards ("?") show the "Not found yet" tooltip as today and don't open the card view.

## 8. Kept from today

All of this keeps working, in the 2D layer over the 3D scene unless noted:
- Cards and Bag tabs top left; key B opens the binder, I opens it on the Bag tab; the Bag window opens over the scene.
- Filters (F) top right: search, Show All / Owned / Missing, Sort by Set / Value / Copies / Rarity, rarity chips. The
  pages refill with the filtered cards. While the Filters panel is open the binder moves (or the camera pans) so the
  binder sits fully left of the panel.
- Close button top right; the side and bottom HUD hide while the binder is open.
- Page counter ("2-3 / 9") under the binder; page arrows with Q / E key chips on wide screens.
- Rarity guide button bottom left (its no-spoiler samples and its block on binder tooltips while it is open).
- The set progress card bottom right on wide screens.
- `BinderController.Open(hint)` from the Party and Jobs panels ("Tap a card, then Give a job."), with its toast.
- `BinderController.GetCollection`, `GetGradedStacks`, `GetWorking`, `GetPartied`, `GetBeasts` and the other public
  functions other controllers use: same behaviour.
- The binder refreshes live when the collection, displays, party or jobs change, staying on the same spread when it
  can.

## 9. Phones

- Landscape phones show the whole spread with 3 x 3 pages, as the user picked. The binder takes the full height
  between the slim corner lanes (today's narrow layout: Cards and Bag down the left edge, Rarity guide bottom left,
  Filters under the close button; no arrows, no progress card).
- On a phone the card names on the faces will be small; holding a finger on a card shows its tooltip, and the chips
  keep the count readable. If testing shows cards can't be told apart, report it rather than silently switching to
  bigger pockets: the user decides.
- Tap targets: the tabs, arrows and corner buttons are at least 48 px; a pocket is a target as large as the card.

## 10. Code shape (the builder may refine)

- The 2D book (its pages, flip sheet, case, spine, cover and pocket tiles inside `BinderController`) is replaced, not
  kept alongside. `BinderController` keeps the collection data, filters, sorting, tooltips, the Bag, the public API and
  the 2D overlay; the 3D scene goes in its own module(s) (for example a desk scene and a page-turn module).
- Pure logic goes in Roblox-free modules with Lune tests, per the project rules: anything like the bend of a turning
  page over time, the drag-to-turn release rule, or fitting the binder to the free screen area. `BinderSpreads` keeps
  its tests and gains any new rules it needs.
- Tunable numbers go in `Config/Collection` (or a new `Config/BinderDesk`), not in the code.
- DESIGN.md (the Binder section of 10.6, the file tree, section 13) and the Obsidian vault are updated in the same
  changes, per CLAUDE.md.

## 11. Testing and done

- Lune: the new pure modules and `BinderSpreads`.
- Studio Play (Claude, through the Studio MCP): opening and closing, turning pages every way (keys, arrows, click,
  drag, fast repeated E), sets via the tabs, filters, hover tooltips, picking a card into the card view and back,
  the Bag tab, the Rarity guide, `Open(hint)` from Party and Jobs, and no world showing through. Screenshots of the
  key moments. The Device emulator (landscape phone) for section 9.
- Done when the user has checked it in Studio and approved, then it is merged and pushed (CLAUDE.md workflow).
