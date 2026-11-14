# Shop windows and achievement decor (2026-11-14)

Owner: "Add windows to the decor, certain decors must unlock at a certain level or achievement", then "no, I want an
actual window player can put on their walls not a painting", approved the playback with "go".

## Intent
Real see-through windows the owner of a shop cuts into its side and back walls: the town outside shows through them
(people outside see in). Some decor unlocks by an achievement, not only by shop level.

## The windows
- Five styles (concept `.superpowers` mockup "windows.png"): Square (4 x 4, white frame, cross bars), Wide (8 x 4,
  three panes, a flower box on the sill), Arched (4 x 7, wooden frame, round top), Porthole (4 x 4, a thick brass ring,
  round glass), Stained glass (4 x 7, purple, blue, teal and gold panes in lead lines).
- Real holes: the wall is rebuilt around each window (the outer white wall and the inner layer: the back feature wall
  or a side liner with the shop look's wallpaper). Round and arched tops are filled with the frame's colour round the
  curve (a porthole in a brass plate, an arch in a wooden frame), so every hole is a rectangle.
- Placement: from the Shop menu's Decor tab, a window ghost slides along the side or back wall under the pointer,
  snapping every 2 studs; click (tap) to place. One fixed height: the bottom 1 stud over the decor band (my call), so
  windows line up. Not on the glass front. Kept 1 stud from the corners, never overlapping each other. Shelves may stand
  in front of a window.
- Editing: a placed window has an owner-only prompt: Move (place it again) or Sell (half its price back, as shelves).
- Cap: 6 windows a shop (my call). Each counts toward the decor part of the rating (2 points, the stained glass 3).
- Saved: data.windows = { { style, side ("left" | "right" | "back"), at (studs from the wall's middle, a whole even
  number) } }; schema 26.

## Prices and unlocks (my calls)
| Style | Price | Unlock |
|---|---|---|
| Square | $300 | shop level 3 |
| Wide | $600 | shop level 6 |
| Arched | $900 | shop level 9 |
| Porthole | $1,200 | beat the Frost Tyrant |
| Stained glass | $2,500 | beat the Prism Hydra |

Achievement decor uses the titles' checks (Util/TitleRules: boss clears, stats...) without needing a title: the Pack
Statue now needs 500 packs opened (it was shop level 18). A locked tile says what's needed ("Beat the Prism Hydra").
The server checks it on every buy (Util/Blocked when not).

## Not in this round
Windows on the glass front, free height, curtains, views painted into windows, plushies.

## Plan (inline, owner's usual)
1. Config/Windows + Util/WindowRules (snap, clamp, overlap, cap, unlock reasons, the wall cut into pieces) with tests;
   TitleRules.meets for a single check.
2. Saved data v26 (windows) with a migration test.
3. Server: WindowService (load/save, PlaceWindow / MoveWindow / SellWindow remotes, validation, cash via
   EconomyService, achievement checks via TitleService.Meets), PlotService.SetWindows (wall pieces, the window models
   from Util/WindowLooks, the look's liners cut too), the rating's decor points, achievement decor in PlacementService.
4. Client: the Decor tab's window tiles, the wall placement ghost (WindowController), the owner's Move / Sell prompt,
   locked tiles with their requirement.
5. Dev command `/window <style> <left|right|back> <at>`, admin panel, DESIGN.md, docs, Studio check.
