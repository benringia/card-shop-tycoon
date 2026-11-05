# Customers with Personalities Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Customers of four types (kid, collector, bargain hunter, big spender) that behave differently, kids who rip a pack at your counter and may sell you their pull, haggles, your own counter price, reactions to your shop, a shop rating (sign + tips chip), then customers who stroll the town and pick a shop.

**Architecture:** Every decision is a pure, Lune-tested rule in `src/shared/Util` (types, offers, haggles, collector, reactions, rating, walkers) reading plain numbers from `Config/Customers`. The server services (`CustomerService`, a new `OfferService`, a new `RatingService`, `RegisterService`, later `TownWalkerService`) apply them; the client only draws (checkout panel, bubbles, reveal, rating chip). No saved-data change.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), Studio MCP checks, `lune run tools/economy/sim`.

**Spec:** `docs/superpowers/specs/2026-11-06-customers-design.md` (owner approved 2026-11-06)

## Global Constraints

- Server authoritative: types, pulls (grades rolled only on the server), prices, acceptances decided on the server; clients send intents through remotes defined in `src/shared/Remotes.luau`, validated (types, ranges, owner, behind their register) and rate-limited with `src/server/Util/RateLimiter.luau`. Never trust a client price: the server recomputes the allowed range.
- Cash only through `EconomyService` (`AddCash`, `TrySpend`); cards only through `CardService.GiveCard(player, cardId, foil, grade)`.
- Every tunable number in `src/shared/Config/Customers.luau`; pure modules don't require siblings (Lune has no `script`).
- No player data schema change.
- Mobile first: tap targets ≥ 48 px; cotton candy windows (`UIKit.panel` default theme, `UIKit.colorsFor`); text plain ASCII + emoji; stars drawn with the `Star` UIIcon, never "★".
- Customers stay server R15 rigs (`NpcMotion.createRig`), at most `MAX_PER_PLOT` (4) per plot.
- Kid offers: only Very Rare or better; offer chance Very Rare 0.40, Epic 0.30, Legendary 0.30, times grade factor C 1.15, B 1.0, A 0.85, S 0.7; asking price worth × (0.90-1.0); ceilings: at most 4 offers an hour per shop, never two Legendary offers within 3 hours (per session); kids' pulls never touch the owner's pity.
- Collectors pay up to 1.3 × the card's worth. Type mix: plain 0.55, kid 0.20, collector 0.10 (only with a Glass Showcase), bargain 0.10, big spender 0.05 (from shop level 11).
- Rating: parts stocked 0.35, prices 0.25, displays 0.15, happy 0.25, decor 0 (until the Decor system); 1.0-5.0; spawn gap ×1.4 at 1 star, ×1.0 at 3, ×0.6 at 5.
- Licensed sounds only (Pro Sound Effects creator 7462895450 / APM 7462718749); every new skill-style sound in `Config/SuperFx`/`MoveFx` would need `Config/SoundLevels` (not expected here).
- Client files aren't parsed by Lune: after each client edit check VS Code "Luau Syntax Check" diagnostics, then Studio Output after Play.

## Review Focus

1. The owner walks away from the register or leaves the game while a kid's offer or a haggle is open: it expires after its patience, no cash moves, the kid leaves with the card, the queue moves on (Task 5 test `offer expires`).
2. The owner can't afford the kid's price or counter: the server refuses with a message and nothing changes (Task 6 test via `OfferRules.canPay`).
3. A forged or stale counter (price outside the allowed range, an action for an offer that already ended, another plot's offer): rejected (Task 5 tests `counter range`, Task 6 `stale offer id`).
4. A Cashier card is working when a kid or a bargain hunter reaches the counter, or the owner steps in mid-haggle: no offer from the kid, the cashier settles the haggle at the midpoint, never handled twice (Task 5 test `cashier settles halfway`, Task 6 Studio check).
5. The wanted card or a displayed card sells, or its price changes, while a collector walks to it: re-checked on arrival like `shopForCard` (Task 4 test `collector rechecks`).

---

## Phase 1: in the shop

### Task 1: Customer types and their config

**Files:**
- Modify: `src/shared/Config/Customers.luau` (add `TYPES`, `TYPE_ORDER`, `KID`, `COLLECTOR`, `BARGAIN`, `BIG_SPENDER`, `OFFER`, `HAGGLE`, `REACTIONS`, `RATING`, `WALKERS` tables as the tasks below fill them; this task adds `TYPES` and `TYPE_ORDER`)
- Create: `src/shared/Util/CustomerTypes.luau`
- Test: `tests/CustomerTypes.spec.luau` (register in `tests/run.luau`)

**Interfaces:**
- Produces: `CustomerTypes.pick(cfg: any, context: { hasShowcase: boolean, shopLevel: number }, roll: number): string` (one of "plain", "kid", "collector", "bargain", "bigSpender"); `CustomerTypes.tolerance(cfg: any, kind: string): number` (how many price bands higher this type still buys in: plain 0, bargain 1, bigSpender 1; kid 0, collector 0); `CustomerTypes.buys(cfg: any, kind: string, price: number, market: number, roll: number, perkBonus: number): boolean`.
- `Config/Customers.TYPES[kind] = { weight, needsShowcase?, minLevel?, icon, props = { { part = "Head"|"UpperTorso"|"RightHand", size = {x,y,z}, offset = {x,y,z}, color = {r,g,b}, shape = "Block"|"Ball"|"Cylinder" } }, colors = { torso = {...}, legs = {...} }, scale? }`; `TYPE_ORDER = { "plain", "kid", "collector", "bargain", "bigSpender" }` (stable roll order).

- [ ] **Step 1: Write the failing tests** — `["the mix: weights by type, gated by showcase and shop level"]`: with `context = { hasShowcase = true, shopLevel = 20 }` and rolls 0.0, 0.54, 0.56, 0.76, 0.86, 0.96 expect "plain","plain","kid","collector","bargain","bigSpender" (weights 0.55/0.20/0.10/0.10/0.05 in TYPE_ORDER); with `hasShowcase = false` a roll in the collector band never returns "collector" and the weights renormalise (sum check: picking over 1000 evenly spaced rolls gives 0 collectors); with `shopLevel = 10` no "bigSpender". `["bargain hunters and big spenders tolerate one band more"]`: at price/market 1.3 (band 3, chance 0.15) `buys` with roll 0.3 is false for plain and true for bargain (band 2 chance 0.5); at 1.6 (no band) plain never buys, bigSpender buys with roll 0.1 (band 3). `["every type has an icon and props"]`.
- [ ] **Step 2: Run `lune run tests/run`** — Expected: FAIL (module missing).
- [ ] **Step 3: Implement** `CustomerTypes` and the `TYPES` / `TYPE_ORDER` config. `buys`: the band index of `price/market` in `Pricing.BUY_BANDS` (`#BUY_BANDS + 1` when over the last band), minus `tolerance` (at least 1); an index past the last band never buys; else that band's chance × (1 + perkBonus) > roll. Props per the spec: kid cap + pack in hand, scale 0.82; collector glasses + binder; bargain bucket hat + coupon; big spender shades + gold chain; icons: kid "🎒", bargain "🏷️", bigSpender "💎" (collector shows its card instead).
- [ ] **Step 4: Run `lune run tests/run`** — Expected: all pass.
- [ ] **Step 5: Commit** `git commit -m "Customers: types and their mix (pure rules, config)"`.

### Task 2: Looks, arrival icons and type behaviour in the shop

**Files:**
- Modify: `src/server/Services/CustomerService.luau` (`createModel(spawnCFrame, kind)`, `spawnCustomer`, `pickShoppingList`, `shopFor`, `run`)
- Modify: `DESIGN.md` 4.5

**Interfaces:**
- Consumes: Task 1's `CustomerTypes.pick/buys/tolerance`, `TYPES[kind].props/colors/icon/scale`.
- Produces: `Customer.kind: string`; model attribute `CustomerType`; `CustomerService.OnOutcome(callback: (owner: Player, outcome: string) -> ())` firing "paid", "annoyed", "gaveUp", "noStock", "happyMoment" (Task 9 consumes).

- [ ] **Step 1:** In `spawnCustomer` pick `kind` with `CustomerTypes.pick` (context: owner has a Glass Showcase with a card, `EconomyService.GetLevel(owner)`), build the rig with the type's colours, scale (`NpcMotion` rig `ScaleTo` for the kid) and props (welded, massless, `CanCollide`/`CanQuery`/`CanTouch` false), set `CustomerType`, and show its icon with the existing `showBubble` once it reaches the shop's entry (the collector skips this: Task 4 draws its card).
- [ ] **Step 2:** Behaviour: kid's list is the cheapest unlocked pack product, 1-2 units; bigSpender's list is the booster box (`FirstSparkBox`) if stocked, else 6-12 units of the pack; bargain and bigSpender decide with `CustomerTypes.buys` (others keep today's band check); fire `OnOutcome` at each existing bubble (annoyed / no stock / gave up) and on `CompletePurchase` ("paid").
- [ ] **Step 3:** Big spender tip: when every item's price ≤ market, `CompletePurchase` adds `BIG_SPENDER.tip` (config 0.1) × total through `EconomyService.AddCash` with a "Tip! +$x" side toast.
- [ ] **Step 4: Verify** — `lune run tests/run` passes; Studio (Play, your shop stocked): over a few minutes customers of each type appear with their props and arrival icon; a big spender buys a box or a stack; Output has no errors. Screenshot the types side by side.
- [ ] **Step 5: Commit** `git commit -m "Customers: type looks, arrival icons, kid/bargain/big spender shopping"`.

### Task 3: Collector rules

**Files:**
- Create: `src/shared/Util/CollectorRules.luau`
- Test: `tests/CollectorRules.spec.luau`
- Modify: `src/shared/Config/Customers.luau` (`COLLECTOR = { premium = 1.3, ownedShare = 0.5 }`)

**Interfaces:**
- Produces: `CollectorRules.wanted(cfg: any, owned: { string }, all: { { id: string, rarity: string } }, rollShare: number, rollPick: number): string` (from `owned` when `rollShare < ownedShare` and owned isn't empty, else from `all` weighted by rarity: Common 30, Rare 25, Very Rare 20, Epic 15, Legendary 10); `CollectorRules.buys(cfg: any, price: number, worth: number): boolean` (`price <= worth * premium`).

- [ ] **Step 1: Failing tests** — `["a collector wants a card you own half the time"]` (rollShare 0.2 → an owned id; 0.8 → from `all`; empty `owned` → from `all`); `["rarer cards are wanted less often"]` (over 1000 evenly spaced rolls Legendary count < Common count); `["pays up to 1.3x what it's worth"]` (`buys(cfg, 129, 100)` true, `buys(cfg, 131, 100)` false).
- [ ] **Step 2:** `lune run tests/run` — FAIL. **Step 3:** implement. **Step 4:** PASS. **Step 5:** commit `"Customers: collector rules"`.

### Task 4: The collector in the shop

**Files:**
- Modify: `src/server/Services/CustomerService.luau` (collector run: wanted card, walk Glass Showcases, re-check on arrival)
- Modify: `src/server/Services/ShowcaseService.luau` (add `ShowcaseService.FindCardForCollector(owner: Player, cardId: string): (PlacedShelf?, number?)`)
- Create: `src/client/Controllers/CustomerController.luau` (collector thought bubble; Task 7 adds the kid reveal)
- Test: `tests/CollectorRules.spec.luau` (`["collector rechecks"]`: a pure helper `CollectorRules.stillThere(displayed: { cardId: string, price: number }?, wantedId: string, worth: number, cfg): boolean` false when the slot emptied, holds another card or now costs over the premium)

**Interfaces:**
- Consumes: Task 3. Model attribute `WantedCard` = card id (set at spawn for collectors).
- Produces: client `CustomerController.Start()` registered in `init.client.luau` after `CreatureController`.

- [ ] **Step 1:** Failing test `collector rechecks`; run; implement `stillThere`; run green.
- [ ] **Step 2:** Collector run: also shops the shelves like plain; then `FindCardForCollector`; walks there, waits `BROWSE_SECONDS`, re-checks with `stillThere`, takes it with `ShowcaseService.TakeForCustomer` (checkout at the displayed price) or shows the disappointed bubble ("Thinking") and fires `OnOutcome("noStock")`.
- [ ] **Step 3:** Client `CustomerController`: for every model in `workspace.Customers` (the server's customers folder) with `WantedCard`, a BillboardGui thought bubble over its head holding the card's face (`CardFace`, small) for as long as it stands in the shop; removed with the model.
- [ ] **Step 4: Verify** — tests pass; diagnostics clean; Studio: put a card in a Glass Showcase, wait for a collector wanting it (or force with a temporary dev command `/customer collector <cardId>` added to `DevService`, Studio only, listed in CLAUDE.md), it walks over and buys it; one wanting a card you don't show leaves with the bubble.
- [ ] **Step 5:** Commit `"Customers: collectors hunt the card they want"`.

### Task 5: Offer and haggle rules

**Files:**
- Create: `src/shared/Util/OfferRules.luau`, `src/shared/Util/HaggleRules.luau`
- Modify: `src/shared/Config/Customers.luau`: `OFFER = { chance = { ["Very Rare"] = 0.4, Epic = 0.3, Legendary = 0.3 }, gradeFactor = { C = 1.15, B = 1.0, A = 0.85, S = 0.7 }, askLow = 0.90, askHigh = 1.0, lowestLow = 0.75, lowestHigh = 0.90, perHour = 4, legendaryGap = 10800, step = 0.05, chips = { -0.20, -0.15, -0.10, 0 }, moodBand = 0.05, retries = 1, patience = 25 }`, `HAGGLE = { offLow = 0.10, offHigh = 0.25, gapLow = 0.4, gapHigh = 0.8 }`
- Test: `tests/OfferRules.spec.luau`, `tests/HaggleRules.spec.luau`

**Interfaces:**
- Produces (OfferRules): `wantsToSell(cfg, rarity: string, grade: string, roll: number): boolean`; `asking(cfg, worth: number, roll: number): number`; `lowest(cfg, worth: number, roll: number): number`; `allowed(cfg, history: { offers: { number }, lastLegendary: number? }, now: number, rarity: string): boolean`; `counterRange(worth: number, asking: number): (number, number)` (0.5 × worth to asking); `step(cfg, worth): number`; `mood(cfg, price: number, lowest: number, worth: number): "sure"|"maybe"|"no"` (≥ lowest + moodBand×worth sure, ≥ lowest − moodBand×worth maybe, else no); `moodEdges(cfg, lowest, worth): { sure: number, maybe: number }` (what the client gets, so it never learns `lowest` exactly); `accepts(price: number, lowest: number): boolean`; `expired(cfg, startedAt: number, now: number): boolean`; `canPay(cash: number, price: number): boolean`.
- Produces (HaggleRules): `offer(cfg, total: number, roll: number): number`; `ceiling(cfg, offer: number, total: number, roll: number): number`; `counterRange(offer: number, total: number): (number, number)`; `accepts(price: number, ceiling: number): boolean`; `cashierPrice(offer: number, total: number): number` (midpoint; the bargain hunter always takes it from a cashier); `moodEdges(cfg, ceiling: number, total: number)`.
- All money rounded to cents (`math.round(x * 100) / 100`).

- [ ] **Step 1: Failing tests** (OfferRules): `["only some kids sell: rarity chance times grade"]` — Very Rare C: roll 0.45 true (0.46), 0.47 false; Legendary S: roll 0.20 true (0.21), 0.22 false; Rare and Common always false. `["asks about what it's worth, accepts from its lowest"]` — `asking(cfg,100,0)` 90, `(…,1)` 100; `lowest(cfg,100,0.5)` 82.5; `accepts(82.5,82.5)` true, `accepts(82.49,82.5)` false. `["ceilings: 4 an hour, never two Legendaries within 3 hours"]` — 4 offers in the last 3600 s → false; 3 → true; a Legendary 10000 s ago → Legendary false, Epic true; 10801 s → true. `["counter range and steps"]` — `counterRange(40, 38)` = (20, 38); `step(cfg,40)` = 2. `["the face never gives the price away exactly"]` — moodEdges(sure) = lowest + 0.05×worth, maybe = lowest − 0.05×worth; mood at lowest is "maybe". `["offer expires"]` — `expired(cfg, 0, 25)` true, `(cfg, 0, 24.9)` false. `["can't pay, can't buy"]` — `canPay(10, 10.01)` false.
- [ ] **Step 2: Failing tests** (HaggleRules): `["offers 10-25% under"]` (`offer(cfg,100,0)` 90, `(…,1)` 75); `["counter range is between their offer and your total"]`; `["pays up to their ceiling"]` (`ceiling(cfg,80,100,0)` 88, `(…,1)` 96; accepts 88 at 88, not 88.01); `["cashier settles halfway"]` (`cashierPrice(80,100)` 90).
- [ ] **Step 3:** `lune run tests/run` — FAIL. **Step 4:** implement both. **Step 5:** PASS. **Step 6:** commit `"Customers: offer and haggle rules"`.

### Task 6: Kids rip and offer, bargain hunters haggle (server)

**Files:**
- Modify: `src/server/Services/PackService.luau` (add `PackService.RollForCustomer(productId: string): { PullResult }` — `rollPack` without `applyPity`, no delivery)
- Create: `src/server/Services/OfferService.luau` (registered in `init.server.luau` after `RegisterService`)
- Modify: `src/server/Services/RegisterService.luau` (haggle step before charge; kid hand-off after `completeSale`), `src/server/Services/CustomerService.luau` (kid waits at the counter while its offer is open: `CustomerService.HoldAtCounter(customer, seconds)` / `ReleaseFromCounter(customer)`), `src/server/Services/JobService.luau` (cashier: kids never offer; haggles settle with `HaggleRules.cashierPrice`)
- Modify: `src/shared/Remotes.luau`: `"OfferUpdate"` (server → owner: `{ id: number, kind: "kid"|"haggle", card: { cardId, foil, grade }?, asking: number?, worth: number?, offer: number?, total: number?, range: { number }, step: number, edges: { sure: number, maybe: number }, triesLeft: number }?`, nil = closed), `"OfferAction"` (client → server: `(id: number, action: "accept"|"counter"|"decline", price: number?)`)

**Interfaces:**
- Consumes: Task 5 rules; `PackService.RollForCustomer`; `EconomyService.TrySpend/AddCash/AddXP`; `CardService.GiveCard`.
- Produces: per plot one open offer `{ id, kind, customer, ... }`; model attribute `Pulled` = `"<cardId>|<grade>|<foil 0/1>"` on the kid for clients' reveal (Task 7).

- [ ] **Step 1: Kid** — after `completeSale` for a kid: `RollForCustomer` the pack it bought, set `Pulled` (its best card), and if `OfferRules.wantsToSell` and `allowed` and no Cashier is serving and the owner is behind the register: open an offer (`asking`, hidden `lowest`), send `OfferUpdate`, hold the kid at the counter until accepted, declined, out of tries, or `expired`. Accept / counter ≥ lowest: `EconomyService.TrySpend` (refuse with a Notify when it fails), `CardService.GiveCard(owner, cardId, foil, grade)`, a "+card" toast, record the offer in the per-session history; a Legendary offer also plays the spotlight (Task 7 draws it). Counter below lowest: `triesLeft -= 1`, "no" bubble; at 0 the kid leaves with its card.
- [ ] **Step 2: Bargain hunter** — when its checkout is fully scanned, instead of waiting for Charge: open a haggle (`HaggleRules.offer`, hidden `ceiling`). Deal → charge the offer; Counter → `accepts(price, ceiling)` charges it, else the customer leaves without buying (items back via the existing restore path); No → leaves without buying. A Cashier serving settles at `cashierPrice` at once.
- [ ] **Step 3: OfferAction validation** — `RateLimiter.new(Customers.OFFER_ACTION_COOLDOWN = 0.25)`; reject unless `id` matches the plot's open offer of this player, the player is behind their register (`RegisterService.IsOwnerAtRegister`), `action` is one of three, and for "counter" `price` is a finite number inside `range` (re-derived server-side, never from the client). Stale id → ignored.
- [ ] **Step 4: Verify** — `lune run tests/run` passes; Studio (temporary dev commands `/customer kid [rarity]` forcing the next customer to be a kid whose rip is at least that rarity, `/customer bargain`): buy, counter high (accepted), counter low (refused, then retry, then leaves), walk away (expires, no cash moves), can't afford (message, nothing changes), bargain deal/counter/no; with a Cashier assigned the kid doesn't offer and a haggle settles halfway. Cash and binder checked before and after each.
- [ ] **Step 5:** Commit `"Customers: kids rip and offer their pulls, bargain hunters haggle"`.

### Task 7: The checkout panel's offer and counter, the kid's reveal (client)

**Files:**
- Modify: `src/client/Controllers/RegisterController.luau` (offer / haggle views in the checkout panel, counter stepper)
- Modify: `src/client/Controllers/CustomerController.luau` (the kid's rip reveal over the counter from `Pulled`; Legendary spotlight)
- Modify: `src/shared/Config/Customers.luau` (`PANEL = { width = 230, ... }`, face texts `{ sure = "😀 Sure!", maybe = "😐 Hmm, maybe", no = "😠 No way" }`)

**Interfaces:**
- Consumes: `Remotes.OfferUpdate` payload (Task 6), `OfferRules.mood`-style edges (client compares `price` to `edges`), `CardFace`.
- Produces: `Remotes.OfferAction:FireServer(id, action, price?)`.

- [ ] **Step 1:** Kid view (mockup option A, `counter-offer.html` A): card face, name · rarity · Grade, "$asking (worth $worth)", buttons Buy / Counter / No thanks. Haggle view: "Bargain hunter offers $offer for $total of stock (-N%)", Deal / Counter / No. Counter view: − / + (one `step` each, clamped to `range`), chips (-20%, -15%, -10%, Worth) jumping there, the price large, the face from `edges` (sure ≥ edges.sure, maybe ≥ edges.maybe, else no), Offer / Back. Every button ≥ 48 px; cotton candy colours via `UIKit.colorsFor`.
- [ ] **Step 2:** Kid reveal: when a kid gets `Pulled`, its card pops up over its head (CardFace, grows in, holds 2.5 s), a cheer bubble for Very Rare or better; Legendary adds a light beam and the pack-opening's licensed reveal sound.
- [ ] **Step 3: Verify** — diagnostics clean; Studio: every view at desktop and a landscape phone (Device emulator), screenshots of each; buttons work end to end with Task 6.
- [ ] **Step 4:** Commit `"Customers: offer, haggle and counter in the checkout panel; the kid's reveal"`.

### Task 8: Reactions

**Files:**
- Create: `src/shared/Util/ReactionRules.luau`; Test: `tests/ReactionRules.spec.luau`
- Modify: `src/shared/Config/Customers.luau` (`REACTIONS = { reach = 6, seconds = 1.5, crowd = 3, petChance = 0.35, petReach = 8 }`), `src/server/Services/CustomerService.luau`

**Interfaces:**
- Produces: `ReactionRules.drawsAWhoa(card: { rarity: string, foil: boolean }): boolean` (Epic, Legendary or foil); `ReactionRules.room(watching: number, card): boolean` (a Legendary holds up to `crowd`, any other 1); `ReactionRules.pets(cfg, distance: number, roll: number): boolean`.

- [ ] **Step 1: Failing tests** — `["epic, legendary or foil cards draw a whoa"]`; `["a legendary draws a small crowd"]` (`room(2, legendary)` true, `room(3, legendary)` false, `room(1, epic)` false); `["near your creature, some stop to pet it"]`.
- [ ] **Step 2:** FAIL → implement → PASS.
- [ ] **Step 3:** CustomerService: between shelves, a customer passing within `reach` of a case holding a whoa card with `room` stops `seconds` facing it with a "😮" bubble (`showBubble`), fires `OnOutcome("happyMoment")`; once per customer near the owner's summoned creature (`PartyService.GetMarker`) with `pets` it stops, shows "Heart", and the creature plays its "wag" fidget (marker attribute `PetMe` = time, read by `CreatureController`).
- [ ] **Step 4: Verify** — tests; Studio: an Epic in a case stops passers; a Legendary gathers up to 3; petting shows. **Step 5:** commit `"Customers: they stop at your best cards and pet your creature"`.

### Task 9: Shop rating (rules, service, sign)

**Files:**
- Create: `src/shared/Util/RatingRules.luau`; Test: `tests/RatingRules.spec.luau`
- Create: `src/server/Services/RatingService.luau` (in `init.server.luau` after `CustomerService`)
- Modify: `src/shared/Config/Customers.luau` (`RATING = { parts = { stocked = 0.35, prices = 0.25, displays = 0.15, happy = 0.25, decor = 0 }, history = 20, smoothSeconds = 90, tick = 5, spawnAt1 = 1.4, spawnAt5 = 0.6, displayPoints = { Epic = 1, Legendary = 3, foil = 1 }, displayFull = 6 }`), `src/server/Services/CustomerService.luau` (spawn gap × `RatingService.SpawnScale(owner)`), `src/server/Services/PlotService.luau` (`PlotService.SetSignRating(plot, rating: number?)`: five `Star` ImageLabels on the sign's SurfaceGui, filled by quarters), `src/shared/Remotes.luau` (`"RatingUpdate"`: server → owner `{ rating: number, parts: { { name: string, score: number, weight: number } } }`)

**Interfaces:**
- Produces: `RatingRules.score(parts: { [string]: number }, weights: { [string]: number }): number` (weighted mean of 0-1 scores over parts with weight > 0, mapped to 1 + 4 × mean); `RatingRules.smooth(current: number, target: number, dt: number, seconds: number): number`; `RatingRules.spawnScale(cfg, rating: number): number` (1.4 at 1, 1.0 at 3, 0.6 at 5, linear between); `RatingRules.stocked(stocked: number, shelves: number): number`; `RatingRules.prices(bandChances: { number }): number` (mean of each product's `BUY_BANDS` chance / 0.95, 0 when over the last band); `RatingRules.displays(cfg, cards: { { rarity: string, foil: boolean } }): number`; `RatingRules.happy(history: { string }): number` (paid and happyMoment count good; annoyed, gaveUp, noStock bad; empty → 0.5); `RatingRules.tips(parts, weights): { { name: string, good: boolean } }` (parts with weight > 0, good when score ≥ 0.7). `RatingService.SpawnScale(owner: Player): number`; `RatingService.Get(owner: Player): number`.

- [ ] **Step 1: Failing tests** — `["a well-run shop rates 4.5"]` (stocked 1, prices 1, displays 0.5, happy 0.8 → 1 + 4 × 0.875 = 4.5 with decor weight 0); `["decor counts only once it has a weight"]` (adding `decor = 0` score changes nothing; giving decor weight 0.15 and score 0 lowers it); `["three stars is today's customer flow"]` (`spawnScale(cfg,3)` 1.0, `(…,1)` 1.4, `(…,5)` 0.6, `(…,4)` 0.8); `["a fresh join starts neutral on happiness"]` (`happy({})` 0.5); `["smoothing takes its time"]` (`smooth(3, 5, 5, 90)` between 3 and 3.3); `["tips list each part that counts"]` (decor absent at weight 0).
- [ ] **Step 2:** FAIL → implement `RatingRules` → PASS.
- [ ] **Step 3:** `RatingService`: every `tick` s per claimed plot, gather the four scores (`PlacementService.GetShelves`, `PricingService.GetPrice` vs market per stocked product, cases' cards, the outcome history from `CustomerService.OnOutcome`), smooth, `PlotService.SetSignRating`, fire `RatingUpdate` when it moved by 0.05 or more; history and rating reset on release.
- [ ] **Step 4: Verify** — tests; Studio: stars on your sign; empty shelves drop it over a minute or two; spawn gap follows (log `SpawnScale` once with a dev print removed before commit).
- [ ] **Step 5:** Commit `"Customers: shop rating on the sign, speeding up customers"`.

### Task 10: Rating chip and tips (client)

**Files:**
- Create: `src/client/Controllers/RatingController.luau` (in `init.client.luau`)
- Modify: `src/shared/Config/Customers.luau` (`RATING_TIPS = { stocked = { good = "Shelves stocked", fix = "Restock empty shelves" }, prices = {...}, displays = { good = "Great cards on display", fix = "Put a rare card in a Glass Showcase to draw collectors" }, happy = {...}, decor = {...} }`)

**Interfaces:**
- Consumes: `Remotes.RatingUpdate`, `RatingRules.tips`, `Hud` (a chip beside the cash/XP status, `Hud.hideWith`), `UIKit.panel`.

- [ ] **Step 1:** Chip: five small `Star` images (filled by quarters) and "Shop rating 4.2"; tap opens a cotton candy tips window (✅ good lines, ⚠️ fix lines) from the latest update; hides with the HUD.
- [ ] **Step 2: Verify** — diagnostics clean; Studio desktop and phone screenshots; tips change when you empty a shelf.
- [ ] **Step 3:** Commit `"Customers: rating chip with tips"`.

### Task 11: Economy check and docs

**Files:**
- Modify: `tools/economy/sim.luau` (kids: share 0.20 of customers rip one pack with real odds; offers by `OfferRules.wantsToSell` and the ceilings; the player buys every offer at `asking` when its cash allows, paid from the pack budget; customers ×1/`spawnScale(4)`; `NO_KIDS=1` and `RATING=3` to compare)
- Modify: `DESIGN.md` (4.4, 4.5, 4.6, 4.7, 7.5 numbers, 10.2 files, 13 backlog), `CLAUDE.md` (tests list: CustomerTypes, CollectorRules, OfferRules, HaggleRules, ReactionRules, RatingRules, later WalkerRules; dev commands `/customer ...`)

- [ ] **Step 1:** Run `lune run tools/economy/sim 2000` before (`NO_KIDS=1 RATING=3`) and after; record both in DESIGN 7.5. Expected: median hours to first Legendary and to a Grade S Legendary within ±10% of before; if not, tune `OFFER` / `RATING.spawnAt5` in config and rerun.
- [ ] **Step 2:** Docs; `lune run tests/run` passes.
- [ ] **Step 3:** Commit `"Customers: economy check, docs"`.

## Phase 2: in the town

### Task 12: Town walkers

**Files:**
- Create: `src/shared/Util/WalkerRules.luau`; Test: `tests/WalkerRules.spec.luau`
- Create: `src/server/Services/TownWalkerService.luau` (in `init.server.luau` after `RatingService`)
- Modify: `src/shared/Config/Customers.luau` (`WALKERS = { max = 8, spawnEvery = 20, linger = { 30, 90 }, sitChance = 0.4, ratingPower = 2, wantedBonus = 3 }`), `src/server/Services/CustomerService.luau` (`CustomerService.Adopt(model: Model, plot, owner, kind: string): boolean` — becomes that shop's customer at its entry if the plot has room, else false)

**Interfaces:**
- Produces: `WalkerRules.chooseShop(cfg, shops: { { id: number, rating: number, open: boolean, hasWanted: boolean } }, roll: number): number?` (open shops only; weight rating^ratingPower × (wantedBonus if hasWanted)); `WalkerRules.nextStop(cfg, stops: { { kind: "bench"|"fountain"|"spot", free: boolean } }, roll: number): number?` (free stops only; benches `sitChance` of the time).

- [ ] **Step 1: Failing tests** — `["walkers only go to open shops"]` (all closed → nil); `["better rated shops draw more walkers"]` (over 1000 rolls a 5-star shop beats a 3-star one by about (5/3)^2); `["a collector heads for the shop showing its card"]`; `["they sit on free benches only"]`.
- [ ] **Step 2:** FAIL → implement → PASS.
- [ ] **Step 3:** Service: keeps up to `max` walkers (a type picked like Task 1, same props), spawned at the plaza's edge every `spawnEvery` s while any player is in town; each wanders plaza stops (benches from `PlazaLayout`, the fountain rim, spots on the lanes), sits on a free bench (sit animation as `PlazaNpcController`'s), after `linger` picks a shop with `chooseShop`, walks to its entry (`walkTo` with the existing pathfinding) and `CustomerService.Adopt`s; if refused or no shop is open it wanders again; despawns after 4 minutes.
- [ ] **Step 4: Verify** — tests; Studio with 2 players (Test tab, Local Server): walkers stroll, sit, pick shops (better rated more often), become customers; measure town frame time and server heartbeat before and after with the town perf method (`docs` / DESIGN 10.5); record both. Expected: within the town budget, else lower `max`.
- [ ] **Step 5:** Docs (DESIGN 3/4.5, CLAUDE tests list); commit `"Customers: walkers stroll the plaza and pick a shop"`.
