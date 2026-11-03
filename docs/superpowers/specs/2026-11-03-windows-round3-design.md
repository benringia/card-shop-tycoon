# Windows round 3: Filters, Prices, Bag, XP pill, party XP sparks, Return to town

Owner picks, 2026-11-03, from `.superpowers/brainstorm/13775-1793692558/content/windows-round3.html`. All in the cotton
candy look (`2026-11-03-cotton-candy-ui-design.md`); fight screens untouched.

## Why

The owner's notes after the cotton candy build: the binder's Filters window still used the old teal style, had too
many buttons and cut-off edges; the Prices window was crowded with buttons too large; the Bag opened with the binder
behind it; the paw prints should give way to numbers and a bar, with XP visibly flying in after a monster win; the
dark "Shop" button in the Wild should say where it goes.

## What gets built

1. **Filters (pick A, "tidy column"):** the binder's Filters window becomes a cotton candy window with a pink band
   and a round pink close. Inside, with room inside every edge: the search box; SHOW as one segmented switch (All,
   Owned, Missing; the chosen part butter); SORT BY as one segmented switch (Set, Value, Copies, Rarity); RARITY as
   small white tags with a colour dot that fill with their rarity colour when picked; at the bottom "N of M cards"
   and "Clear all" (resets show, sort, rarity picks and search). Same filtering as today.
2. **Prices (pick A, "slim rows"):** one slim white row per product: its picture, name (one line, cut with "..."),
   "Market $x" and a small tag in the band colour ("Rarely buy", "Sometimes", ...), and on the right one compact
   stepper: a small round pink "-" and butter "+" either side of the price, on a pale lilac pill. Tapping the price
   lets you type one, as today. The round buttons look small (about 30 px) but their tap areas stay 48 px.
3. **Bag on its own (the one option):** the Bag tile and the I key open the Bag as its own window over the town
   (the HUD hidden, the binder not shown). The binder loses its Cards / Bag tabs and shows only cards.
4. **XP pill (pick B, "big number, thin bar"):** the paw prints go. The level pill shows the level on its star, the
   XP into this level big and exact ("99,800 XP") with the level's total small after it ("/ 226,000"), and a thin
   lilac-to-sky bar under them. When XP changes the number counts up and the bar slides.
5. **Party XP sparks (owner: into the party portraits):** after a won monster fight (not boss fights, which have
   their own screen), glowing lilac sparks fly from where the monster was on screen into each party portrait whose
   creature got XP, then "+N XP" pops over each portrait and its level number counts up if it levelled.
6. **Return to town (pick A):** the Wild's dark "Shop" button becomes a sky cotton candy pill with the Travel icon
   and "Return to town", top centre, same place and size class, same action.

## Constraints

- Numbers in config, pure rules Lune-tested (number formatting, the count-up, the spark path).
- Tap targets at least 48 px; phones unchanged in size.
- Fight screens (boss and wild fight HUDs, victory and defeat screens) untouched; the sparks play after the wild
  fight's toast, over the HUD.

## Calls I made

- The binder without its tabs keeps its other buttons where they are.
- Rarity tags, when picked, fill with their own colour (the round 2 ruling).
- Sparks: 3 to 6 per portrait, about 0.9 s, on a curved path; skipped while a window covers the HUD.
