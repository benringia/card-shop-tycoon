# Shop variety and storage reasons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pallet deals and Restocker-run away selling give racks a use; variety in the rating and a "Found it all!" bonus make every product worth stocking; customers, reviews, the order computer, the rack clipboard and Pish teach it.

**Architecture:** Rules in pure Lune-tested modules (`OrderRules`, `OfflineRules`, `RatingRules`, `ReviewRules`, `StorageRules`, new `VarietyRules`), numbers and words in configs, servers recompute everything (StockService charges, OfflineService sells, CustomerService pays), clients draw (OrderController, WelcomeBackController, CustomerController, StorageController, ReviewsController, TutorialController).

**Tech Stack:** Luau (--!strict), Rojo, Lune tests (`lune run tests/run [Spec]`), Roblox Studio MCP for the Studio check.

**Spec:** docs/superpowers/specs/2026-11-24-shop-variety-design.md

## Global Constraints

- Pallet: `{ boxes = 6, off = 0.10 }` per product line in one order; money rounded to cents.
- Away selling: `RACK_MINUTES = 30` per rack holding boxes, `MAX_EXTRA_MINUTES = 120`; only with a Restocker; extra time sells rack units only; shelves first, then rack boxes, half-used first.
- Rating: `RATING.productShare = 0.5`; unlocked = `OrderRules.isOpen` (level + boss), never bulk.
- Found it all: `{ share = 0.10, minProducts = 2, types = { plain = true } }`; outcome "foundAll" replaces "paid"; "partial" replaces "noStock" when something was bought.
- Chat lines: plain ASCII, at most `CustomerChat.MAX_CHARS` (34), `%s` = `Config/Offline` PLURALS word. Pish lines at most 60 characters.
- No saved-data change (no schema bump). No new remotes unless a task says so. Server authoritative; no magic numbers in services.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never `sed -i` in `src`.

## Review Focus

1. An order mixing a pallet line and a short line: the server charges exactly the client's shown total (one `cartCost`), and the pallet savings row hides at 0.
2. Away selling with racks but no shelf for a rack's product: those boxes never sell or vanish; without a Restocker nothing changes from today.
3. A rack box partly used offline keeps its remaining units, an emptied one leaves the rack, and the rack's drawing and attributes match (no ghost boxes).
4. "Found it all!" never pays a kid, bargain hunter, big spender, collector or a one-product list, and never pays twice with a tip line said instead.
5. The variety lesson fills its product name even when replayed by `/tutorial lesson variety` (no raw `{product}` on screen).

---

### Task 1: Pallet deal rules and server charge

**Files:**
- Modify: `src/shared/Util/OrderRules.luau`, `src/shared/Config/OrderComputer.luau`, `src/server/Services/StockService.luau`
- Test: `tests/OrderRules.spec.luau`

**Interfaces:**
- Produces: `export type Pallet = { boxes: number, off: number }`; `OrderRules.lineCost(product, boxes, pallet: Pallet?): number`; `OrderRules.cartCost(cart, byId, pallet: Pallet?): number`; `OrderRules.palletSavings(cart, byId, pallet: Pallet?): number`; `OrderRules.dealPrice(product, pallet): number` (one box at the deal); `OrderRules.dealProfitText(product, pallet, short: boolean?): string?`; `OrderRules.meter(boxes, pallet, words): { filled: number, done: boolean, text: string }`; `addLook(..., pallet)`, `checkout(..., pallet)`, `phoneSummary(cart, byId, pallet)` take the pallet last. `Config/OrderComputer.PALLET = { boxes = 6, off = 0.10 }`, WORDS `PALLET_NONE = "%d for -%d%%"`, `PALLET_MORE = "%d more: -%d%%"`, `PALLET_DONE = "PALLET -%d%%!"`, `PALLET_CHIP = "PALLET"`, `PALLET_LINE = "%s · %d%% off"`, `PALLET_SAVINGS = "Pallet savings"`.

- [ ] **Step 1: Write the failing tests** `pallet deal: 6 boxes of one product 10% off` (6 FirstSparkPack: `lineCost` 259.2, `cartCost` of {FSP=6, CardSleeves=2} 319.2, `palletSavings` 28.8; 5 boxes: 240 and savings 0; no pallet given: 288), `pallet meter words` (`meter(0)` filled 0 text "6 for -10%", `meter(2)` filled 2 "4 more: -10%", `meter(6)` and `meter(9)` filled 6 done "PALLET -10%!"), `deal price and profit` (`dealPrice` FSP 43.2, `dealProfitText` "+$28.80 profit a box", short "+$28.80 profit"), `checkout total uses the pallet` (`checkout` text "Order now · $259.20" for 6 FSP with cash 1000).
- [ ] **Step 2: Run** `lune run tests/run OrderRules` — Expected: FAIL (lineCost nil).
- [ ] **Step 3: Implement** in OrderRules (cents rounding per line: `cents(boxCost * boxes * (1 - off))` when `boxes >= pallet.boxes`), config entries, and StockService's order charge `OrderRules.cartCost(cart, Products.ById, OrderComputer.PALLET)` (both the cash check and the charge).
- [ ] **Step 4: Run** `lune run tests/run OrderRules` — Expected: PASS; then `lune run tests/run` all green.
- [ ] **Step 5: Commit** "Pallet deal: 6+ boxes of a product 10% off (rules, server charge)".

### Task 2: Order computer UI: pallet meter, deal price, cart savings, "Customers want this!"

**Files:**
- Modify: `src/client/Controllers/OrderController.luau`, `src/shared/Config/OrderComputer.luau`, `src/shared/Util/OrderRules.luau`
- Test: `tests/OrderRules.spec.luau`

**Interfaces:**
- Consumes: Task 1's pallet functions.
- Produces: `OrderRules.shelfTag` returns `"Customers want this!"` (Config WORDS `WANTED`) when no Products shelf that takes the product has it as its product; "Shelf empty" when one has it with 0 units; "Shelves low" as today. `OrderRules.WANTED` constant exported for the client's outline check.

- [ ] **Step 1: Write the failing test** `shelf tag: customers want what no shelf holds` (no shelves taking it: "Customers want this!"; a shelf with productId X and 0 units: "Shelf empty"; an empty shelf of another product that takes X: "Customers want this!"; a low shelf: "Shelves low").
- [ ] **Step 2: Run** `lune run tests/run OrderRules` — Expected: FAIL.
- [ ] **Step 3: Implement** shelfTag; in OrderController: DESK.MONITOR height 600 -> 640 and a `METER` row (18 px) in the desktop card stack under the profit pill (6 slots 13x11, gap 3; empty slots lilac outline, filled tan, done: gold strip and wooden pallet line), meter words, deal price (struck box cost + green deal price) and gold profit pill at the deal; phone cards: 6 slots 10x8 over the picture's bottom-left, gold at the deal, the price green at the deal; cart lines: PALLET chip, struck full cost over the deal cost, "N boxes · 10% off"; a green "Pallet savings -$x" row above the total rule, hidden at 0; every `cartCost` / `addLook` / `checkout` / `phoneSummary` call passes `OrderComputer.PALLET`; a card tagged WANTED gets its face edge pink (TAG colour, 3 px).
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all green; compile-check OrderController (`lune run <scratch compile_check> src/client/Controllers/OrderController.luau`).
- [ ] **Step 5: Commit** "Order computer: pallet meter, deal prices, savings row, Customers want this! tag".

### Task 3: Variety in the rating and its tip

**Files:**
- Modify: `src/shared/Util/RatingRules.luau`, `src/shared/Config/Customers.luau`, `src/server/Services/RatingService.luau`, `src/client/Controllers/ReviewsController.luau`, `src/client/Controllers/RatingController.luau`
- Test: `tests/RatingRules.spec.luau`

**Interfaces:**
- Produces: `RatingRules.stocked(stocked, shelves, products: number?, open: number?, share: number?)` (2 args: today's); `RatingRules.stockedFix(words, missing: { string }): string`; Config `RATING.productShare = 0.5`, `RATING_TIPS.stocked` gains `stock = "Stock %s"`, `two = "%s and %s"`, `more = "%s and %d more"`; `VARIETY = { names = { FirstSparkPack = "Booster Packs", CardSleeves = "Card Sleeves", DeckBox = "Deck Boxes", FirstSparkBox = "Booster Boxes", FrontierPack = "Frontier Packs" }, lessonLevel = 3 }`. RatingUpdate payload gains `missing: { string }` (names, Products.List order).

- [ ] **Step 1: Write the failing tests** `stocked counts products half` (4 of 4 shelves, 1 of 4 products, share 0.5: 0.625; 2 args unchanged: 1; no open products: shelves only), `stocked tip names what's missing` (none: "Restock empty shelves"; 1: "Stock Card Sleeves"; 2: "Stock Card Sleeves and Deck Boxes"; 3: "Stock Card Sleeves and 2 more").
- [ ] **Step 2: Run** `lune run tests/run RatingRules` — Expected: FAIL.
- [ ] **Step 3: Implement**; RatingService.partsFor counts open products (EconomyService level, BossesCleared) and stocked ones, keeps `state.missing` names, sends them; both clients word the stocked tip with `stockedFix`.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all green.
- [ ] **Step 5: Commit** "Rating: Stocked counts products too; its tip names what's missing".

### Task 4: VarietyRules (pure)

**Files:**
- Create: `src/shared/Util/VarietyRules.luau`, `tests/VarietyRules.spec.luau`; register in `tests/run.luau`
- Modify: `src/shared/Config/Customers.luau`

**Interfaces:**
- Produces: `VarietyRules.foundAll(cfg, kind: string, list: { string }, bought: { [string]: boolean }): boolean`; `VarietyRules.bonus(cfg, total: number): number`; `VarietyRules.word(plurals: { [string]: string }, productId: string): string`; `VarietyRules.toast(words, bonus: number): string` ("Found it all! +$4.20"). Config `FOUND_ALL = { share = 0.10, minProducts = 2, types = { plain = true }, toast = "Found it all! +$%.2f" }`.

- [ ] **Step 1: Write the failing tests** `found it all: a plain customer with every product bought` (2 products both bought: true; one missing: false; one product: false; kid / bargain / bigSpender / collector: false; a product listed twice counts once), `found it all bonus is 10% to the cent` (42 -> 4.2; 3.33 -> 0.33; 0 -> 0), `the missing product's word` (CardSleeves -> "sleeves"; unknown -> "things").
- [ ] **Step 2: Run** `lune run tests/run VarietyRules` — Expected: FAIL (module missing).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `lune run tests/run VarietyRules` — Expected: PASS.
- [ ] **Step 5: Commit** "VarietyRules: found it all, its bonus, the missing product's word".

### Task 5: Customers: missing words, partial visits, Found it all!

**Files:**
- Modify: `src/server/Services/CustomerService.luau`, `src/shared/Config/CustomerChat.luau`, `src/shared/Config/Reviews.luau`, `src/shared/Util/ReviewRules.luau`, `src/server/Services/ReviewService.luau`, `src/shared/Util/RatingRules.luau`, `src/server/Services/DevService.luau`, `src/shared/Config/AdminPanel.luau`
- Test: `tests/ChatRules.spec.luau`, `tests/ReviewRules.spec.luau`, `tests/RatingRules.spec.luau`

**Interfaces:**
- Consumes: VarietyRules (Task 4).
- Produces: outcome callbacks `(owner, outcome, word: string?)`; `CustomerService.OnMissed(callback: (owner: Player, productId: string) -> ())` fired when a missed product is open to the shop and its level is at least `VARIETY.lessonLevel`; the customer model attribute `Missing` (productId) for BUBBLE_SECONDS; `ReviewRules.make(cfg, outcome, rolls, now, word: string?)` (an outcome's `named` lines when a word is given); RatingRules GOOD gains `foundAll`, BAD gains `partial`; chat moment `foundAll`.

- [ ] **Step 1: Write the failing tests** ChatRules: `missing lines name the product` (plain missing line 1 with "sleeves" = "No sleeves? Aww."; every `%s` line filled with "Frontier packs" fits MAX_CHARS + 4) and `found it all lines` (plain has `foundAll`, ASCII, short; add "foundAll" to the spec's MOMENTS); ReviewRules: `reviews name the missing product` (partial with "sleeves", stars 3, line "No sleeves here 😕"; noStock with a word: a named line; noStock without: today's lines; foundAll: 5 stars); RatingRules: `found it all is a good visit, partial a bad one`.
- [ ] **Step 2: Run** `lune run tests/run ChatRules`, `ReviewRules`, `RatingRules` — Expected: FAIL.
- [ ] **Step 3: Implement** configs and rules; CustomerService: keep the list (`customer.list`) and the first missed product, after shopping set `customer.foundAll`, after `searchShelves` set `Missing` (cleared after BUBBLE_SECONDS) in place of the thinking icon, say "missing" with the word, fire "partial" (items bought) or "noStock" with the word, fire OnMissed; at `CompletePurchase` pay the bonus (EconomyService.AddCash, side toast), say "foundAll" (over "tip"), fire "foundAll" instead of "paid"; ReviewService passes the word; DevService `/customer plain all` (a plain customer wanting one of every open product) and its admin button.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all green (SourceOrder, RequireCycles included).
- [ ] **Step 5: Commit** "Customers: say and review the missing product; Found it all! pays 10%".

### Task 6: The missing product's thought bubble (client)

**Files:**
- Modify: `src/client/Controllers/CustomerController.luau`

**Interfaces:**
- Consumes: the `Missing` attribute (Task 5).

- [ ] **Step 1: Implement** a `MissingBubble` like `WantedBubble` (white 84x84 frame, corner 14, lilac edge, the product's picture via client `Util/ProductPicture`, a pink 28 px "?" badge at its top right, two thought dots), shown while `Missing` is set; the chat bubble's raised offset counts it like WantedBubble.
- [ ] **Step 2: Run** `lune run tests/run` (SourceOrder) and the compile check — Expected: green.
- [ ] **Step 3: Commit** "Customers: a thought bubble with the product they missed".

### Task 7: Away selling with racks (rules, rack units, service)

**Files:**
- Modify: `src/shared/Util/OfflineRules.luau`, `src/shared/Config/Offline.luau`, `src/server/Services/OfflineService.luau`, `src/server/Services/PlacementService.luau`, `src/server/Services/JobService.luau`, `src/server/Services/DevService.luau`
- Test: `tests/OfflineRules.spec.luau`

**Interfaces:**
- Produces: `OfflineRules.minutesAway(lastSeen, now, cfg, cap: number?)` (cap defaults to MAX_MINUTES); `OfflineRules.split(minutes, racks: number, restocker: boolean, cfg): (base, extra)`; `export type Stock = { productId: string, shelf: number, rack: number, price: number, chance: number }`; `OfflineRules.planRacks(stock: { Stock }, base, extra, cfg): { fromShelves: { number }, fromRacks: { number }, units: number, cash: number }`; `OfflineRules.boxTakes(boxes: { number }, units: number): ({ number }, number)` (units taken from each box, half-used (fewest) first; boxes touched); Config `RACK_MINUTES = 30`, `MAX_EXTRA_MINUTES = 120`, `REPORT` words. `PlacementService.TakeRackUnits(rack, slot, units): number`; `JobService.GetRestocker(player): { name: string, cardId: string }?` and the player attribute `Restockers` (count). WelcomeBack summary gains `restocker: { name, cardId }?`, `boxes: number`, `base: number`, `extra: number`, `needsRestocker: boolean`.

- [ ] **Step 1: Write the failing tests** `away time: racks add 30 minutes each with a restocker` (split 240 / 3 racks / restocker: 120, 90; no restocker: 120, 0; 100 minutes: 100, 0; 5 racks: extra 120 at most), `planRacks: shelves first, racks refill, extra time sells racks only` (one product, shelf 10, rack 48, chance 1, base 120 extra 0: sells min(240, 58) = 58: 10 from the shelf, 48 from the rack; base 10 extra 30: phase 1 sells 20 (10 shelf, 10 rack), phase 2 sells min(60, 38) = 38 from the rack), `boxTakes: half-used box first, boxes touched` ({24, 10, 24} with 30: takes 10 then 20; touched 2), `minutesAway's cap` (300 minutes, cap 240: 240; no cap: 120).
- [ ] **Step 2: Run** `lune run tests/run OfflineRules` — Expected: FAIL.
- [ ] **Step 3: Implement**; OfflineService: with `JobService.GetRestocker` and racks holding boxes, group shelves by product (a shelf's product even at 0 units), plan with `planRacks`, take shelf units (TakeStock across that product's shelves) then rack units (`boxTakes` order, `TakeRackUnits`), count boxes, fill the summary; else today's path (`plan`) untouched; `needsRestocker` when racks hold boxes and there's no Restocker. JobService sets `Restockers` on load and every job change.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all green.
- [ ] **Step 5: Commit** "Away selling: a Restocker refills from racks, 30 min more a rack (to 4 h)".

### Task 8: Welcome back: the Restocker's report

**Files:**
- Modify: `src/client/Controllers/WelcomeBackController.luau`, `src/shared/Config/Offline.luau`

**Interfaces:**
- Consumes: the summary fields from Task 7.

- [ ] **Step 1: Implement** the report panel (pick 2): white row (CREAM ROW and ROW_EDGE), 56 px round portrait of the card's art with a 3 px stroke, title and box line, the 14 px bar (base share blue, extra green) and its two-word legend; the hint lines; the window's max size grows to fit (460 x 470).
- [ ] **Step 2: Run** `lune run tests/run` and the compile check — Expected: green.
- [ ] **Step 3: Commit** "Welcome back: the Restocker's report and the racks hint".

### Task 9: Rack clipboard stamp and Pish's rack line

**Files:**
- Modify: `src/shared/Util/StorageRules.luau`, `src/shared/Config/Storage.luau`, `src/client/Controllers/StorageController.luau`, `src/shared/Config/PishTalk.luau`
- Test: `tests/StorageRules.spec.luau`

**Interfaces:**
- Produces: `StorageRules.awayStamp(count: number, restockers: number, minutes: number, words): (string?, boolean)` (nil when the rack is empty; active when a Restocker works); WORDS `awayStamp = "+%d MIN\nAWAY SELLING"`, `needsStamp = "NEEDS A\nRESTOCKER"`.

- [ ] **Step 1: Write the failing test** `the away-selling stamp` (empty rack: nil; boxes + 1 restocker: "+30 MIN\nAWAY SELLING", true; boxes + none: "NEEDS A\nRESTOCKER", false).
- [ ] **Step 2: Run** `lune run tests/run StorageRules` — Expected: FAIL.
- [ ] **Step 3: Implement**; StorageController draws the stamp (green or grey, tilted, top right of the paper, clear of the close button) and redraws on the `Restockers` attribute; PishTalk AFTER.storageRack gains "Full racks keep your shop selling while you're away!".
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all green.
- [ ] **Step 5: Commit** "Racks: the away-selling stamp; Pish's fourth rack line".

### Task 10: Pish's "Customers love choice" lesson

**Files:**
- Modify: `src/shared/Config/Pish.luau`, `src/shared/Config/PishTalk.luau`, `src/shared/Util/TalkRules.luau`, `src/client/Controllers/TutorialController.luau`, `src/server/Services/TutorialService.luau`, `src/server/Services/DevService.luau`, `src/shared/Config/AdminPanel.luau`
- Test: `tests/LessonRules.spec.luau`, `tests/TalkRules.spec.luau`, `tests/AdminPanel.spec.luau`

**Interfaces:**
- Consumes: `CustomerService.OnMissed` (Task 5), `VARIETY.names` (Task 3).
- Produces: lesson `{ id = "variety", level = 3, icon = "Order", trigger = "missing", talk = true }`; `TalkRules.product(text, name)` fills `{product}`; player attribute `MissedProduct`; POINT_AT `variety = { part = "OrderComputer" }`.

- [ ] **Step 1: Write the failing tests** LessonRules: `the variety lesson comes from a missed product` (byEvent "missing" gives "variety" once, never again once seen); TalkRules: `a lesson line names the product` ("That customer wanted {product}!" with "Card Sleeves") and every AFTER.variety line at most 60 characters; update lesson counts and the admin panel's lesson list.
- [ ] **Step 2: Run** `lune run tests/run LessonRules`, `TalkRules`, `AdminPanel` — Expected: FAIL.
- [ ] **Step 3: Implement**; TutorialController: a lesson with `talk` starts on its AFTER lines (like a placed one) and fills `{product}` from `MissedProduct` (VARIETY.names; "something new" without it); TutorialService registers OnMissed (sets `MissedProduct`, queues the "missing" event); DevService's lesson replay sets `MissedProduct` to CardSleeves when none.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all green.
- [ ] **Step 5: Commit** "Pish: the Customers love choice lesson".

### Task 11: Docs and the full check

**Files:**
- Modify: `DESIGN.md` (order computer, storage racks, customers, rating, reviews, welcome back, Pish lessons), `CLAUDE.md` (tests list, `/customer plain all`)

- [ ] **Step 1:** Update the docs; run `lune run tests/run` (all green), `rojo build -o <scratch>/test.rbxl`, compile-check every changed client file.
- [ ] **Step 2: Commit** "Shop variety: docs".
