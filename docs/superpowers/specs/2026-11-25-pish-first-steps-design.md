# Pish's first steps: nothing in the way

Owner picks 2026-11-25 ("A and P1, go ahead"), from the findings page https://claude.ai/artifact/3CRZwsw1jc4X7vZ2CAwm4e.

## Why

The onboarding funnel to 11-22 loses 7 of the 17 players who finish the prologue in Pish's first three steps
(present 15, pal 12, rack 10). Two fresh-save runs (iPhone 17 Pro landscape in the device simulator, HUD 750 x 323;
a 1377 x 625 laptop window) found the cause:

- Pish's talk card covers the button he points at, and a tap there hits the card (`PishTalk.Tap`), so nothing
  happens. On a phone it covers the Bag app (the Phone's second row: Bag 286,163 64x64 under the card at 97,146
  420x76) and the Small Pack Rack's $100 button (127,170 232x44); on the laptop it hides most of the $100 button.
  Cause: `Util/TutorialTalk` only knows "top" and "bottom" (`TalkRules.cardAtTop`), and the bottom spot is never
  checked against a target in the middle of the screen. The top spot lost the Bag by 3 px of paw room.
- On a phone Pish says "Open your Bag!" while the glowing button is the Phone (the Bag is an app inside it).
- The rack is placed from the sidewalk: you wake at your door facing out and the tour stays there; a new shelf's
  preview starts under the screen centre, which misses the floor from outside (it falls back to the floor's corner
  cell, off screen) and lands under you, behind the Rotate / Place / Cancel bar, from inside.
- Smaller: the results screen's set bar ("First Spark set 4/37") sits on the card names on a phone.

Goal: every first-visit step can be done by tapping what Pish points at, on a phone, a tablet and a computer.

## Approaches

- Card: **A** (picked) the card moves to the spot that leaves the target clear, full size; B the same but a quarter
  smaller while a window is open on a phone (rejected: small wrapped text, against "tutorial is hard to notice").
- Placing: **P1** (picked) "Let's go inside!" with a paw trail first, then the preview starts in view beside you;
  P2 wake up inside the shop (changes the prologue's last shot); P3 only move where the preview starts.

## Design

1. **The card never covers what Pish points at** (`TalkRules.pickSpot`, `TalkRules.pawBox`, `TalkRules.overlap`;
   `TutorialTalk`, `TutorialCues.skipBox`). Each spot (top, then bottom) is the boxes it fills: the card and, while
   it shows, the docked Skip pill's 84 x 48 tap area. The card takes the first spot that leaves both the target (what
   the gold ring goes round) and the paw's room (82 px square over the paw's button) clear; else the first that leaves
   the target clear (the paw may touch the card); else the one covering least of the target. Manning the register
   ("side") and fights ("top") stay as they are; nothing pointed at: the top. Lessons get the same rule.
2. **The paw points at the button you tap.** A Shop tile's price button is named `Buy`; the rack step's paw goes on
   it while the gold ring stays round the whole tile (as in mockup A; `TutorialCues.pawOn(target, ring)`, Target
   `ring`). Lessons' Shop tile situation does the same.
3. **Pish's Bag lines match a phone.** Where the Bag is an app in the Phone (`Hud.inPhone("Bag")`): Phone shut
   "I brought you a present! Tap the Phone." (gift: "Open it in your Bag! Tap the Phone."), Phone open "Tap Bag.",
   then "Tap my present!" / "Tap my gift!" and "Now tap Open!" as today. A computer keeps "Open your Bag!". The
   trophy lesson gets "Tap the Phone." and "Tap Bag." the same way.
4. **"Let's go inside!"** In the rack step, with no window or Phone open and not placing, a player outside their shop
   (more than `Pish.INSIDE.margin` studs past the floor's front edge, or off its sides or back) hears "Let's go
   inside!" with the paw trail to a spot `Pish.INSIDE.spot` studs inside the front, the paw over it at
   `Pish.INSIDE.height`. Inside, the step goes on ("Shops need shelves! Tap the Phone."). No new step: the funnel's
   numbers stay comparable.
5. **A new shelf's preview starts in view beside you** (every new shelf, not only the tour's: the same problem hits
   anyone placing from a phone). `PlacementController.Begin` casts from screen points left and right of centre at
   half height (`Placement.START.anchors`, tried in order) to the shop floor and takes the nearest free cell within
   `START.reach` cells (`CellSearch.nearest`); none: the free cell nearest you; then today's corner. The preview
   stays there until you tap the floor or move the mouse. In the tour Pish's paw hangs over it with "Tap Place!"
   (no trail), one line red or green (final review: a new line chimes, and a dragged preview flips colour many
   times a second).
6. **Studio's fresh switch** (built for this check): `Config/Data.STUDIO_FRESH` true in Studio loads a brand-new save
   in memory (ProfileStore's Mock) on every Play, never written; off by default, refused outside Studio
   (`SaveSlots.fresh`).

## Not in this round

- The Bag's Open button is 160 x 48 in the window's own size; the whole Bag window is drawn at about half size on a
  short phone (79 x 24 on screen). A phone pass over the Bag window's scale is its own job (backlog).
- The results screen's set bar over the card names on a short phone: keeping the lineup under the bar
  (`PackOpeningLayout.LAYOUT.topReserve` 96 -> 156) shrinks the cards by up to 30% on an 800 x 360 phone (134 -> 93 px
  tall), so it needs a layout pick (smaller cards, a slimmer bar, or the bar elsewhere): backlog, with a mockup.
- The 2 min 20 s from the prologue's start to the first tap: the funnel shows players stay; no trim now.

## Tests

- `tests/TalkRules`: the measured phone cases (Bag in the Phone's second row: top; the Shop app in its first row:
  bottom; the rack tile with the paw on $100: top), the laptop rack case (top), a desktop bottom tile (top), nothing
  pointed at (top), a target both spots cover (the one covering less), Skip counted, the register and fights; every
  new line short and drawable (the existing line tests).
- `tests/TutorialRules`: inside or outside the shop (the wake spot outside, 3 studs past the door inside, off the side
  outside).
- `tests/CellSearch`: the nearest free cell within reach, none past it.
- Studio: fresh-save runs on the phone and the laptop window through the first three steps, then the owner's check.
