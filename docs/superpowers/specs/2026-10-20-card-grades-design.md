# Card Grades — Design

Status: approved in chat 2026-10-20. Builds on `2026-10-20-stars-condenser-design.md` (stars 0-5,
Very Rare) and changes its Condenser duplicate rule (section 5 below). Built as **Plan A2**, before
the Condenser (Plan B).

## 1. Goals

- Duplicates of a card differ: each copy has a **grade** (C, B, A, S) that boosts its stats and value,
  so players can pick their strongest copy.
- Copies with the same card, foil and grade still **stack** (no clutter).
- **Rarity beats grade:** at the same level and stars, the best possible copy of a rarity is always
  weaker than the worst possible copy of the next rarity up.

## 2. Grades

| Grade | Chance | Stats and value |
|---|---|---|
| C | 50% | +0% |
| B | 30% | +3% |
| A | 15% | +6% |
| S | 5% | +10% |

- Rolled on the server when a card is pulled (packs, `/testpack`). Never changes afterwards.
- Stats: × grade multiplier on HP, ATK and SPD, on top of element, level, stars and foil.
- Value: × the same grade multiplier.
- Config in `Config/Beasts.luau`: `GRADES = { "C", "B", "A", "S" }` (weakest first),
  `GRADE_CHANCES = { C = 0.5, B = 0.3, A = 0.15, S = 0.05 }`, `GRADE_BONUS = { C = 0, B = 0.03, A = 0.06, S = 0.10 }`,
  `DEFAULT_GRADE = "C"`.
- Text: grade shown as `Grade S` (plain letters, no symbols).

## 3. Power and rarity ordering

- **Power = HP + 5 × ATK + 5 × SPD**, shown on card faces and in lists (`Power 485`).
- New base stats (Common and Rare unchanged):

| Rarity | HP | ATK | SPD | Power (no element) |
|---|---|---|---|---|
| Common | 60 | 12 | 10 | 170 |
| Rare | 80 | 16 | 12 | 220 |
| Very Rare | 100 | 21 | 14 | 275 |
| Epic | 135 | 27 | 17 | 355 |
| Legendary | 180 | 36 | 20 | 460 |

- **Rule (unit-tested):** for every adjacent pair of rarities, at levels 1, 15, 30 and stars 0-5,
  max Power of the lower rarity (best element, grade S, foil) < min Power of the higher rarity
  (weakest element, grade C, not foil). Lv 1, 0 stars: Common 214 < Rare 235; Rare 272 < Very Rare 290;
  Very Rare 342 < Epic 375; Epic 442 < Legendary 485.
- Levels and stars are allowed to cross rarities (a Lv 30 Common can beat a fresh Legendary).

## 4. Storage — schema v5

- Plain stacks key by card, then grade and foil:
  `cards = { [cardId] = { [grade] = { normal = n, foil = n } } }`.
- Levelled cards (`beasts`) gain `grade`. Displayed card entries (`layout[i].cards[j]`) gain `grade`.
- A copy becomes an individual card the first time it gains XP or a star; it keeps its grade.
- `MIGRATIONS[4]` (v4 → v5), in `server/Util/Migrations.luau`:
  - each old stack `{ normal = n, foil = m }` becomes per-grade counts, rolling a grade for every copy;
  - each beast and each displayed card without a grade gets one rolled grade.
  - The roll function is passed in (`Migrations.run(data, target, rollGrade)`) so Lune tests use a
    fixed sequence and the server uses `Random`.
- Sanitize on load: unknown grade → `DEFAULT_GRADE`; non-integer or negative counts dropped.

## 5. Where grades show and matter

- **Binder tile:** `Owned N` plus the best grade chip (`S`) and best level chip (`Lv 12`) when present.
- **Binder detail:** one row per stack (`Grade S · Owned 2 · Lv 1 · 0 stars`) and one per levelled
  copy, strongest (Power) first; each row shows grade, HP/ATK/SPD, Power, value; levelled rows also
  XP bar. Star hint as now. Tap a row to show it on the big card.
- **Card face:** grade letter and Power line.
- **Display cases:** a displayed card carries its grade (part attribute `Grade`); case picker tiles,
  case manager rows, browse and buy confirm show it; prices, price limits and customer judgement use
  the graded value. Buying gives the buyer that exact grade.
- **Pack reveal:** shows the rolled grade on each card.
- **Remotes:** `DisplayCard(shelfUid, slot, cardId, foil, beastId?, grade?)` — a plain copy is picked
  by card + foil + grade. Server validates the grade string.
- **`/beastxp` and `AddXP`** take a plain copy of a given grade (best grade first).

## 6. Condenser rule change (Plan B)

Duplicates used are plain copies of the same card, **lowest grade first, normal before foil**.
Levelled or starred copies are never used. The panel lists exactly what will be used
("uses 3 Grade C + 1 Grade B"). The main copy keeps its own grade.

## 7. Studio tests

1. A v4 save loads: every copy is still there, now split across grades; levelled cards keep level/XP/stars.
2. Rip 10 packs: grades appear on reveal; roughly half C, a few S.
3. Binder detail lists stacks by grade, strongest first, with stats and Power; tile shows best grade.
4. Grade S Common Power < any Rare's Power at Lv 1 (compare in binder).
5. Display a Grade S copy: case row, browse and buy confirm show `Grade S`; price default = graded value.
6. Buy it with player 2: player 2 receives Grade S.
7. Stop → Play: grades persist; no copies gained or lost.
