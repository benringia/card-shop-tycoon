# Shop Jobs — Design

Status: approved in chat 2026-10-21. Roadmap step 2 (DESIGN 5.8): cards work in your shop and replace the
hired staff planned in DESIGN 7.4.

## 1. Goals

- Levelled cards can work two jobs: **Restocker** and **Cashier**.
- They appear in the shop as placeholder creatures and walk around doing the job.
- **SPD = work speed**, **Power = fewer mistakes**. Mistakes only cost time.
- Working earns slow XP: **2 XP per minute** while the owner is online. (Battles and quests will be the
  main way to level later.)
- Slots: jobs unlock at **shop Lv 10** with **1 free slot**; a Robux game pass adds **1 more** (max 2).

## 2. Slots and assigning

- Slot 1 opens at shop level 10. Slot 2 needs the "Extra Job Slot" game pass. Both slots may hold the same job.
- **Assign** from the binder card view: pick a copy → "Assign to job" → Restocker or Cashier → first free
  slot. A plain copy is split off its stack into its own card first (keeps its grade; level 1, 0 stars).
- **Jobs panel** (new HUD button "Jobs"): one row per slot: the card (face, grade, level, stars), job,
  live status ("Carrying Booster Box", "Idle: no boxes", "Scanning 3/5", "Waiting: you're at the register"),
  XP bar, mistake chance and speed, **Unassign**. Locked slot shows "Unlocks at shop Lv 10"; slot 2 without
  the pass shows "Buy slot" (prompts the pass purchase), or "Coming soon" while the pass ID is 0.
- **Working cards are locked:** shown "Working" in the binder; can't be displayed, sold, condensed (as main
  or duplicate — they're individual cards so never duplicates) or assigned twice. Unassign first.
- Unassigning (or the beast being gone on load) frees the slot; the creature walks out and disappears.

## 3. The creature (placeholder)

- An R15 rig (like NPC customers) with every body part in the card's element colour, scaled by rarity
  (Common 0.8× … Legendary 1.3×), and a BillboardGui with the card name, `Grade · Lv` and the job. It walks
  with the customers' pathing (Util/NpcMotion). Spawns just inside the shop front.
- Real creature models replace it in roadmap step 3 (summoning), from the Creator Store.

## 4. Jobs

**Restocker** (loop):
1. If a box waits on the delivery pad and some product shelf can take it (same product with space, or an
   empty shelf that accepts that product), walk to the pad, pick the box up (it leaves the pad), walk to the
   shelf, stock for a few seconds, then `PlacementService.AddStock`.
2. Leftover units: carry to the next shelf that takes them, or put the box back on the pad.
3. **Mistake** (chance per trip): drops the box on the way; it goes back on the pad and the trip restarts.
4. Nothing to do: idle near the pad ("Idle: no boxes" / "Idle: shelves full").
5. Boxes the owner is carrying are never touched.

**Cashier** (loop):
1. When a customer is checking out and the owner is **not** behind the counter, walk behind the register
   and scan one counter item per scan time, then charge exactly like the owner (same cash, XP and stats).
2. **Mistake** (chance per item): mis-scan, the item is scanned again (one extra scan time).
3. **Owner at the register:** the cashier steps aside and waits; the owner scans/charges normally. It
   resumes when the owner leaves the register area.

## 5. Numbers (`Config/Jobs.luau`)

| Name | Value | Meaning |
|---|---|---|
| UNLOCK_LEVEL | 10 | shop level for slot 1 |
| FREE_SLOTS / PASS_SLOTS | 1 / 1 | max 2 |
| XP_PER_MINUTE | 2 | while working and the owner is online |
| REFERENCE_SPD | 12 | SPD that works at base speed |
| SPEED_MIN / SPEED_MAX | 0.6 / 2.0 | clamp on SPD / REFERENCE_SPD |
| WALK_SPEED | 12 | studs/s at base speed |
| STOCK_SECONDS | 2 | stocking one box at base speed |
| SCAN_SECONDS | 1.2 | one item at base speed |
| MISTAKE_MAX / MISTAKE_MIN | 0.20 / 0.03 | at Power ≤ 170 / ≥ 485, linear between |

`Util/JobRules.luau` (pure, Lune-tested): `getSpeedFactor(spd)`, `getMistakeChance(power)`,
`getDuration(baseSeconds, spd)`, `getSlotCount(level, hasPass)`.

## 6. Server

- `JobService` owns workers per player: assignment, the creature, the job loops, status, and a once-a-minute
  XP tick (`CardService.AddXP(player, beastId, XP_PER_MINUTE)`). Workers run only while the owner is online.
- `CardService`: `MakeIndividual(player, cardId, foil, grade) -> Beast?`; `SetWorking(player, beastId, job?)`;
  `TakeBeast`, `Condense` and display refuse working cards. Sync payload gains `working = { [beastId] = job }`.
- `StockService`: `GetWaitingBoxes(player)`, `TakeWaitingBox(player, box) -> boolean`, `ReturnBox(player, box)`,
  `ConsumeUnits(player, box, units)` so restockers share the same boxes (and saves) as the owner.
- `RegisterService`: `GetCheckout(plot)`, `ScanNext(plot) -> boolean`, `ChargeByWorker(plot) -> boolean`, `IsOwnerAtRegister`;
  the owner's charge and the cashier's charge share one function.
- `MonetizationService` (new): `HasPass(player, "ExtraJobSlot")` via `MarketplaceService:UserOwnsGamePassAsync`
  (pcall, cached per session), refreshed on `PromptGamePassPurchaseFinished`. Studio: `/jobslot` toggles a
  dev override. Pass IDs in `Config/Monetization.luau` (`EXTRA_JOB_SLOT_PASS_ID = 0` until created).
- Remotes: `AssignJob(target, job)` (target = beast ID, or `{cardId, foil, grade}`), `UnassignJob(slot)`,
  `JobsChanged` (server → owner: slots, assignments, status). All validated and rate-limited.

## 7. Save — schema v6

- `jobs = { { slot, beastId, job } }`. `MIGRATIONS[5]`: `data.jobs = data.jobs or {}`.
- Load: drop entries whose beast is missing, job unknown, slot out of range or not unlocked; duplicates of
  one beast keep the first. Working flags are rebuilt from `jobs`.

## 8. Studio tests

1. Below Lv 10 the Jobs panel shows slots locked; `/level 10` unlocks slot 1; slot 2 shows Buy slot /
   Coming soon; `/jobslot` unlocks it in Studio.
2. Assign a plain copy as Restocker: it becomes its own card, marked Working, a creature appears.
3. Order stock: the restocker carries boxes to matching shelves; with a weak card, it sometimes drops one
   (box back on the pad). Shelves full → "Idle: shelves full".
4. Assign a Cashier, step away from the register: it scans and charges customers; cash and XP arrive.
   Walk behind the register: it steps aside; you scan normally.
5. After 1 minute working, the card has +2 XP; the Jobs panel XP bar moves.
6. A working card can't be displayed, condensed or assigned twice; Unassign frees it and the creature leaves.
7. Stop → Play: assignments come back, creatures respawn; a card sold/missing frees its slot.
