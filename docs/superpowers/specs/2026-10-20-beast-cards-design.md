# Beast Cards — Design (sub-project 1 of the Glimmerbeast direction)

Date: 2026-10-20
Status: Draft for review

## 1. Why

Card Shop Tycoon is moving toward a TCG + Palworld blend: Glimmerbeast cards become creatures you
summon, that work your shop and fight beside you, with real-time player battles later. For that, cards
need real gameplay value instead of just a rarity and a dollar price.

### What the owner asked for
- Cards should "actually have value".
- Palworld parts wanted: **summon & fight beside you** and **work in your shop** (not wild catching,
  not a table card game).
- Battles (later): **real-time, beasts auto-fight**, you pick a team and can trigger special moves.
- Growth: **both** levels from playing **and** star ranks from merging duplicates.
- Storage: **fresh copies stack; a copy becomes an individual beast once it grows**.

### Roadmap (each sub-project gets its own design → plan → build)
1. **Beast cards** — this document. Individual beasts with level, XP, stars, stats and value.
2. **Shop jobs** — assign beasts to restock, run the register, attract customers (replaces DESIGN's
   paid Restocker/Cashier staff). Working earns XP.
3. **Party & summoning** — team of 3 that follows you in the world.
4. **Star merging** — combine duplicates to raise stars.
5. **Battles** — arena, challenges, server-simulated auto-fight, special moves.

Order chosen so cards gain value inside the existing tycoon loop (2) long before battles exist (5).

## 2. Scope of this sub-project

**In:** the beast data model, stats/value/XP rules, save migration, moving beasts through cases and
purchases, UI showing level/stars/stats, a Studio dev command to grant XP.

**Out:** any real XP source (comes with 2 and 5), star merging (4), summoning (3), special moves and
battle stats beyond HP/ATK/SPD (5).

## 3. What a beast is

A **beast** is one specific copy of a card that has started to grow:

| Field | Meaning |
|---|---|
| `id` | GUID, unique per beast |
| `cardId` | which Set 1 card (`FS01`…`FS30`) |
| `foil` | boolean |
| `level` | 1–30 |
| `xp` | progress toward the next level |
| `stars` | 1–5 |

A **fresh copy** is an untouched card: level 1, 0 XP, 1 star. Fresh copies are not individual; they
stay counted in stacks. The first time a fresh copy gains XP (or, later, a star), one copy leaves its
stack and becomes a beast with a new ID.

All numbers below live in a new `src/shared/Config/Beasts.luau`.

### 3.1 Stats (HP, ATK, SPD)

Base by rarity:

| Rarity | HP | ATK | SPD |
|---|---|---|---|
| Common | 60 | 12 | 10 |
| Rare | 80 | 16 | 12 |
| Epic | 110 | 22 | 14 |
| Legendary | 150 | 30 | 16 |

Element multipliers:

| Element | Effect |
|---|---|
| Ember | ATK ×1.20 |
| Tide | HP ×1.20 |
| Bloom | HP ×1.10, ATK ×1.10 |
| Volt | SPD ×1.25 |
| Shade | ATK ×1.10, SPD ×1.10 |

Then: × level growth `1 + 0.06 × (level − 1)` (Lv 30 ≈ 2.74×), × stars `1 + 0.15 × (stars − 1)`
(5★ = 1.6×), × foil 1.05. Each stat is rounded to the nearest whole number.

### 3.2 Value

`value = card.value × (foil ? FOIL_MULTIPLIER : 1) × (1 + 0.10 × (level − 1)) × STAR_VALUE[stars]`

- `FOIL_MULTIPLIER` stays 3 (Rarities config).
- `STAR_VALUE = { 1, 1.5, 2.25, 3.5, 5 }`.
- Example: Cindercub ($0.20) Lv 15, 3★ → 0.20 × 2.4 × 2.25 = **$1.08**.

This becomes the single "market value" used everywhere: customer price bands on Glass Showcases,
case price limits (min $0.01, max 3× value), the default price when a beast goes on display, and the
value line on card faces.

### 3.3 XP and levels

- XP needed to go from level L to L+1: `round(50 × L^1.5)` (≈50 at Lv 1, ≈7,800 at Lv 29).
- Adding XP applies every level-up it covers in one go; leftover XP carries over.
- At Lv 30 XP stops accumulating (stored as 0).

## 4. Save data — schema v3

- `cards` keeps its shape `{ [cardId] = { normal, foil } }` and now means **fresh stacks only**.
- New `beasts`: `{ [beastId] = { cardId, foil, level, xp, stars } }`.
- Displayed-card entries on `layout` (`{ slot, cardId, foil, price }`) gain optional
  `beastId, level, xp, stars`. Absent = a fresh copy.
- **Migration v2 → v3:** add `beasts = {}`. Existing cards are already fresh stacks; displayed cards
  without beast fields are fresh copies. Nothing is converted or lost.
- **Load validation** (as today): drop unknown card IDs; clamp level 1–30, stars 1–5, xp to
  `0 … xpToNext(level) − 1`; regenerate an ID if missing or duplicated; a beast that fails
  validation entirely is dropped only if its card doesn't exist.
- DESIGN.md 10.4 is updated to match.

## 5. Code structure

### 5.1 Shared rules — `src/shared/Util/BeastRules.luau` (new)
Pure functions used by server and client, so previews match what the server enforces:
- `getStats(card, foil, level, stars) -> { hp, atk, spd }`
- `getValue(card, foil, level, stars) -> number`
- `getXpToNext(level) -> number`
- `applyXp(level, xp, amount) -> (level, xp)` (handles multiple level-ups and the cap)

`CardRules.getMarketValue(card, foil)` stays for fresh copies and calls `BeastRules.getValue` with
level 1 / 1★. Case price clamping and steps gain a level/stars-aware variant so displayed beasts are
priced against their real value.

### 5.2 Server — `CardService` owns stacks and beasts
Existing API kept where callers rely on it; new API:
- `AddFresh(player, results)` — packs and returned fresh copies (rename of `AddCards`).
- `TakeFresh(player, cardId, foil) -> boolean` — rename of `TakeCard`.
- `AddBeast(player, beast)` / `TakeBeast(player, beastId) -> Beast?` — move a raised beast in or out.
- `AddXP(player, target, amount) -> Beast?` — `target` is a beast ID, or `{ cardId, foil }` for a
  fresh copy (splits one copy into a new beast). Uses `BeastRules.applyXp`.
- Sync to the client becomes `{ stacks, beasts }` on every change.

### 5.3 Cases, customers, player buys
- A case slot's `DisplayedCard` gains optional `beast` data (`id, level, xp, stars`).
- Display from binder: fresh (`TakeFresh`) or a specific beast (`TakeBeast`). Remove returns it the
  same way it came.
- Card parts get `Level` and `Stars` attributes; the card's price label adds a level/stars line.
- Customer buys: band check uses the beast's value. Player buys: the buyer receives the beast as a beast
  (`AddBeast`), or a fresh copy into their stack. Customers who give up return it unchanged.
- Remotes `DisplayCard` gains an optional `beastId`; the buy remote's card check also compares
  `beastId` so a buyer can't be swapped a different beast.

### 5.4 Client UI
- **CardFace:** optional level/stars line (`"Lv 6 · 2-star"` — text, since Roblox fonts can't draw ★)
  and a compact `HP · ATK · SPD` row. Pack reveals show fresh Lv 1 cards.
- **Binder:** tile badge counts fresh + raised (`"x14 · 2 raised"`). Detail view: Lv 1 stats, then a
  list of your raised beasts of that card (level, stars, XP bar, stats, value), strongest first.
  Completion % unchanged (any copy counts).
- **Case picker:** raised beasts listed as their own rows above fresh stacks.
- **Buy confirm:** includes level and stars.

### 5.5 Dev command
`/beastxp <amount>` (Studio only, via DevService): grants XP to your highest-rarity card — an existing
raised beast if you have one, otherwise it splits a fresh copy.

## 6. Error handling and safety
- All XP changes go through `CardService.AddXP` on the server; clients never send levels or XP.
- Remote args validated as today; beast IDs are server-generated GUIDs and checked for ownership.
- Moving a beast is always take-then-give in one server step, so it exists in exactly one place
  (binder, a case slot, a customer's hands, or a buyer's binder).
- The existing before-leave hook already returns customer-held cards before saving; it carries beast
  data unchanged.

## 7. Testing (in Studio)
1. Existing save loads: old cards appear as fresh stacks, displayed cards still in their cases.
2. `/beastxp 500` on a fresh card: one copy splits off as a beast at about Lv 4; the stack count drops by 1.
3. Repeat to Lv 30: XP stops, stats ≈ 2.74× Lv 1, value grows per the formula.
4. Display a raised beast in a Glass Showcase: default price = its value; customers judge against it.
5. Display one in a Collector Case; a second player buys it and receives the same level/stars/XP.
6. Stop → Play: beasts, levels and displayed beasts all come back.
7. Binder detail lists raised beasts strongest first; card faces show level/stars and stats without
   unsupported symbols.
