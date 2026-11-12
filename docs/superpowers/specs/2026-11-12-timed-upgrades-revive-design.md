# Timed station upgrades and the paid revive

Owner, 2026-11-12: "forge, condenser, and grading station should have a waiting time on upgrades, the higher the
upgrade the longer wait time. also with an option to pay robux for instant upgrade" and "when I die, can we have a 20
second timer and add an option to be revived at the exact same spot for robux".

## Intent

Upgrades should feel like something worth waiting for, and Robux should buy time, never power: every upgrade is
reachable for free by waiting. Being knocked out in the Wild should have a beat of tension (a countdown) and a way to
keep exploring right where you were.

## The owner's decisions

- Waits are **medium**: a few seconds for the smallest upgrade, **up to 1 hour** for the biggest.
- An item being upgraded is **locked till done**: it can't fight, be sold, be displayed or be equipped.
- Every station action gets a wait: **Condenser +1 star**, **Grading grade up**, **Forge weapon level up**, **Forge
  craft and reforge**. **Crafting takes the longest** (owner: "I think crafting needs the longest").
- The paid revive stands you **up on the spot with your cards rested**.

## Timed upgrades

- **One job per station.** Pressing the action takes the materials (duplicates, cash, items) at once, as today, and puts
  the item **inside the station**: out of the binder / armory, so nothing else can use it. The station shows the item, a
  countdown and "Finish now (R$)"; the station model in the shop gets a small floating timer.
  Starting another job while one runs is refused with a requirement card (Util/Blocked): "The Forge is busy (12:30
  left)".
- **When the timer ends** the item comes back upgraded on its own (binder / armory), with a toast ("Your Grade S
  Voidmaw is ready!"). Offline time counts: anything finished while away is handed back on the next join.
- **Results are rolled when the job starts** (on the server, as today) and kept in the job, so a reforge's grade or a
  craft's weapon is decided once and only revealed at the end.
- **Locked rules.** A card in your party or working a shop job can't go in: the requirement card says so ("Take
  Voidmaw out of your party first"). A weapon going into the Forge that is in your hand is swapped for the Steel Sword.
- **Saved data** (schema v21): `upgrades = { condenser = Job?, grading = Job?, forge = Job? }`, each job plain data:
  its kind (`star`, `grade`, `level`, `reforge`, `craft`), the item as saved elsewhere (card fields with grade, level,
  stars, foil; or weapon id, grade, level), its result, `startedAt` and `finishAt` (os.time). Validated on load like
  the rest; a job that can't be read gives its item back (never lose an item). Also `skipTokens = { S = 0, M = 0,
  L = 0 }` (bought skips not used yet) and `purchases` (the last 100 receipt ids).

### Wait times (tunable, Config)

| Action | Steps |
|---|---|
| Condenser +1 star | to 1 star 30 s, 2 stars 2 min, 3 stars 6 min, 4 stars 15 min, 5 stars 30 min |
| Grading | C to B 1 min, B to A 8 min, A to S 25 min |
| Forge level up | +1 15 s, +2 30 s, +3 1 min, +4 2 min, +5 4 min, +6 7 min, +7 10 min, +8 15 min, +9 22 min, +10 30 min |
| Forge reforge | 20 min |
| Forge craft | 60 min (the longest) |

### Finish now (Robux)

- Three developer products by time left: **Skip S** (up to 5 min left), **Skip M** (up to 20 min), **Skip L** (up to 60
  min). Suggested prices R$ 10 / 25 / 49; the owner sets them on Creator Hub.
- The button names the price of the tier the job is in now (MarketplaceService:GetProductInfo, cached). A purchase that
  lands after the job finished on its own still counts: it finishes the station's next job, or (none) gives back its
  value as a "skip token" the next job uses at once. Nothing bought is ever lost.

## The paid revive

- **Knocked out** (a lost wild fight in a dangerous place, today's DangerRules.knockout) now shows the "Knocked out!"
  card with a **20 second countdown**, two buttons: **"Revive here R$ X"** and **"Wake at the spring"** (go now). You
  lie where you fell, can't move, and monsters leave you alone.
- At 0 you wake at the spring, as today (WildService.SendToSpring).
- **Revive here**: the server checks you're knocked out, cancels the trip, stands you up where you fell, wakes every
  party card (rest timers cleared, as the spring does) and gives a few seconds no monster chases you.
- While the purchase prompt is open the countdown waits (up to a minute). A revive bought after you already woke at
  the spring still wakes your cards: nothing bought is ever lost.
- Boss fights and Dungeon rooms keep their own defeat screens (not part of this).

## Purchases (shared)

- One `ProcessReceipt` for the game (MonetizationService), **idempotent**: each receipt's PurchaseId is kept in the
  player's save (the last 100), granted and recorded together, and reported granted only once the save holds it (the
  roblox-dev-skill's developer-product example with ProfileStore). A purchase from a player whose data isn't loaded
  waits (NotProcessedYet).
- Product IDs live in Config/Monetization `PRODUCTS` (Revive, SkipS, SkipM, SkipL). **The owner creates them on
  Creator Hub**; until an ID is set its button shows "Coming soon" and does nothing (said on the button, never silent).
- Studio test purchases work once the IDs are set.

## Left to the builder

- The station UIs' exact look (the existing Forge / Condenser / Grading windows gain the job panel), the floating
  timer, the KO card's layout: in the windows' cotton candy style, mockups shown to the owner first.
- Tests: wait times and tiers (pure Util), job validation and migration (Lune), receipt idempotency (pure part), the
  KO countdown rules.

## Not doing

- More than one job per station, or speed-ups by other means (only time or Robux).
- Reviving inside boss fights or the Dungeon.
