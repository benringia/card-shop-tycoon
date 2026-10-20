# Stars, Condenser and Very Rare — Design

Status: approved in chat 2026-10-20. Builds on `2026-10-20-beast-cards-design.md` (beast cards) and
replaces its star rules. Covers roadmap step 4 (star merging) early, as the "Condenser".

## 1. Goals

- Every card starts at **0 stars**; **5 stars** is the max.
- Stars come **only** from condensing duplicates. Levels raise stats only; no level gate on stars.
- A **Condenser** machine in the shop combines duplicates of a card into one main card, +1 star per use.
- New rarity **Very Rare** between Rare and Epic, with 5 new cards.
- Player-facing text says **Owned**, never "fresh copy" or "raised".

## 2. Stars

| Star step | Duplicates used | Running total |
|---|---|---|
| 0 → 1 | 4 | 4 |
| 1 → 2 | 8 | 12 |
| 2 → 3 | 12 | 24 |
| 3 → 4 | 16 | 40 |
| 4 → 5 | 24 | 64 |

- Stats: × `1 + 0.15 × stars` (0★ = 1×, 5★ = 1.75×). Level and foil multipliers unchanged.
- Value: `STAR_VALUE` by stars 0–5 = `{ 1, 6, 15, 30, 50, 80 }` (stored 1-based: index `stars + 1`).
  Roughly the copies spent plus a bonus, so condensing never destroys value.
- All numbers in `Config/Beasts.luau`: `MAX_STARS = 5`, `STAR_COSTS = { 4, 8, 12, 16, 24 }`,
  `STAR_STAT_GROWTH = 0.15`, `STAR_VALUE`. `STAR_UPGRADE_LEVEL` is removed.
- `BeastMath`: stars range 0–5 everywhere (sanitize clamps 0–5, non-finite → 0);
  new pure `getCondenseCost(config, stars) -> number?` (nil at 5★). Lune-tested.

A card stays a plain stacked copy until it gains XP or a star; then it becomes an individual card with
its own ID (unchanged from the beast cards spec). A plain copy is level 1, 0 XP, 0 stars.

## 3. Condenser

**Machine:** a new `Shelves` entry, kind `"Condenser"`, capacity 0, `unlockLevel = 4`, price $500.
Bought and placed through the existing build menu; can be moved and sold like any shelf.

**Use:** owner walks up, presses E ("Condense") → Condenser panel:
1. List of the player's cards that have at least one duplicate (rarest first): face, `Owned N`.
2. Tap a card → choose the **main card**: one of its levelled/starred individuals, or a plain copy
   (foil if owned, else normal). Default: the strongest individual, else a plain foil, else plain normal.
3. Shows `Stars 1/5 → 2/5 · uses 8 duplicates (Owned 11)` and the new stats/value preview.
4. **Condense** button (disabled with the reason if not enough duplicates or already 5★).

**Which copies are used:** plain copies of the same card only — normal copies first, then foil.
Levelled or starred individuals are never used as duplicates. The panel says exactly what will be
used ("uses 6 normal + 2 foil"). If the main card is itself a plain copy, it is taken out of the
stack first and does not count as a duplicate.

**Server (`CondenserService`):** remote `Condense(shelfUid, cardId, mainBeastId?, mainFoil?)`.
Validates: rate limit, owns that shelf and it is a Condenser, standing near it, known card, main
exists and matches the card (beast ID owned, or a plain copy of that foil in the stack), main below
5★, enough plain duplicates after taking the main. Then in one step with no yields: take the
duplicates, make the main an individual if it was plain, `stars += 1`, sync the binder, toast
"Voidmaw is now 2 stars!". Nothing changes if any check fails. One star per press.

## 4. Very Rare

- Rarity key and display text: `"Very Rare"`. Order: Common 1, Rare 2, Very Rare 3, Epic 4, Legendary 5.
- Frame color cyan `(40, 210, 200)`, value range $3–$6, base stats HP 95 / ATK 19 / SPD 13.
- New cards (Set 1 grows to 35):

| # | Name | Element | Value |
|---|---|---|---|
| 31 | Emberwing | Ember | $3.00 |
| 32 | Tidecaller | Tide | $3.50 |
| 33 | Briarhorn | Bloom | $4.00 |
| 34 | Voltkit | Volt | $5.00 |
| 35 | Duskstalker | Shade | $6.00 |

- Hit slot (slot 5): Rare 68% / Very Rare 15% / Epic 14% / Legendary 3%. Odds UI reads the config.
- Every per-rarity table gets a Very Rare entry between Rare and Epic: card effects, pack reveal
  stroke/sound, beast base stats. Announcements unchanged (Very Rare is not announced).
- Card IDs `FS31`–`FS35`. Existing IDs and numbers don't change, so saves are unaffected.

## 5. Wording

- Binder tile badge: `Owned 3`, plus `· 2 levelled` when individuals exist.
- Binder detail: summary `Owned 5 · 1 on display`; plain-copies row `Owned 3 · Lv 1 · 0 stars`;
  star hint `Stars 0/5 · condense 4 duplicates for the next star` (`Stars 5/5 · max stars`).
- Browse / buy / case manager: drop "fresh copy", "raised beast" and "(fresh)"; show `Lv · stars` only.

## 6. Save data — schema v4

- `SCHEMA_VERSION = 4`. `MIGRATIONS[3]`: every saved beast and every displayed card entry with a
  `stars` field gets `stars = max(0, stars - 1)` (old 1★ → new 0★). Shape otherwise unchanged.
- A v3 save that never had beasts loads unchanged.

## 7. Studio-only commands

- `/givecard <number> <amount>` — adds plain copies of card #number (for condenser testing).

## 8. Build order

- **Plan A:** stars 0–5 maths + value table, schema v4, Very Rare + 5 cards + odds, wording.
- **Plan B:** Condenser machine, panel, `CondenserService`, `/givecard`.

## 9. Studio tests

1. v3 save with a 1★ beast loads as 0★, same level and XP.
2. Pack odds screen shows Very Rare 15%; `/testpack` and normal packs can roll the new cards; cyan frame and effects.
3. Binder shows 35 cards and `Owned` wording; no "fresh" or "raised" anywhere.
4. Shop Lv 4 unlocks the Condenser in the build menu; place it, walk up, press E.
5. `/givecard 30 70` → condense Voidmaw five times: costs 4/8/12/16/24, stats ×1.75, value ×80;
   the button disables at 5★. Foil duplicates are used only after normals run out.
6. Not enough duplicates → button disabled with the reason; a forged remote changes nothing.
7. Stop → Play: stars persist; condensed copies stay gone.
