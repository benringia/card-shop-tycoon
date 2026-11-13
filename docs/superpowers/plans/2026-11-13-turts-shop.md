# Turts' Rug Shop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turts, the owner's dog, sells 3 random offers from a rug that moves round the town every 8-minute restock, with premium cash prices, a Robux "restock now", and abuse-proof server rules.

**Architecture:** Pure rules and plain-data config (`Util/TurtsRules`, `Config/Turts`) hold the clock, the weighted roll, the buy check, the spot choice, the price rule and the head shake, Lune-tested. `TurtsService` (server) owns the global restock (same clock in every server, seeded with a server-only salt), the marker Turts stands on, each player's saved purchases and the Robux re-roll. `TurtsController` (client) draws Turts (PishVisual with Pish's clips plus a code head shake), his rug, each player's own offers on it, the timer, the toast and the shop window. Models come through the Pish/Chikin Blender pipeline; code-built stand-ins until the owner imports them.

**Tech Stack:** Roblox Luau (`--!strict`), Rojo, Lune tests (`lune run tests/run`), ProfileStore via DataService, Blender MCP + Meshy (done: `assets/blender/Turts/Turts_raw.glb`).

**Spec:** `docs/superpowers/specs/2026-11-13-turts-shop-design.md`

## Global Constraints

- Server authoritative; every remote in `src/shared/Remotes.luau`, args type-checked, rate-limited (`Server/Util/RateLimiter`), prices recomputed on the server.
- All cash through `EconomyService` (`TrySpend`); items through `ItemService` (`GiveItem`).
- Tunable numbers in `src/shared/Config`; pure logic in Roblox-free `src/shared/Util` modules that don't require siblings.
- Saved data: bump `SCHEMA_VERSION` (23 -> 24) in `Config/Data.luau`, a step in `server/Util/Migrations.luau` with a Lune test, types/template in DataService, DESIGN.md 10.4; `save` does nothing for a player never loaded.
- Never fail silently: refusals through `Server/Util/Blocked.tell`.
- UI: `UIKit.panel` cotton-candy window, tap targets >= 48 px, ASCII text plus `·` and emoji only.
- Restock every 480 s on `floor(os.time() / 480)`; 3 different offers; each buyable once per player per restock; `PREMIUM = 1.5`; prices and values exactly the spec's table.
- Robux product key `TurtsRestock`, id 0 ("Coming soon") until the owner sets it in `Config/Monetization` PRODUCTS.
- Main game only (not Frontier, not Dungeon). Turts' photo, concepts and raw model stay out of git.
- Commit and push only after the owner's OK (owner rule); the commit steps below are local commits on main.

## Review Focus

1. A buy sent in the last second before a restock lands after it: refused with the "Turts restocked!" card, no cash taken, no item given.
2. A player who bought "restock now" and stays past the next timer restock: their stock becomes the new global one, purchases reset with it.
3. A player who rejoins (or hops servers) mid-restock: same offers, already-bought ones still SOLD.
4. Turts' spot never on a walker stop, walker exit, crosswalk, shop door or plaza prop, and never the same spot twice in a row.
5. A Legendary Pack's Legendary rolls the stingy pity grades, and every price stays >= 1.5x its usual value (the Gold Seal above $10,000).

---

### Task 1: Turts config and rules

**Files:**
- Create: `src/shared/Config/Turts.luau`, `src/shared/Util/TurtsRules.luau`, `tests/TurtsRules.spec.luau`
- Modify: `tests/run.luau` (register `TurtsRules`)

**Interfaces:**
- Produces (`Config/Turts`, plain data):
  - `RESTOCK_SECONDS = 480`, `PICKS = 3`, `PREMIUM = 1.5`, `PRODUCT = "TurtsRestock"`, `BEACON_SECONDS = 30`, `RUG_RADIUS = 4`
  - `OFFERS: { [string]: Offer }`, `Offer = { item: string, count: number, price: number, value: number, weight: number, excited: boolean?, name: string }` with ids and numbers from the spec table: `vrPack` (item `vrPack`, $25, value 10, weight 16), `epicPack` ($75, 25, 8, excited), `legendaryPack` ($600, 300, 2.5, excited), `wildOre10` (item `wildOre`, count 10, $400, 165, 20), `xpTonic` ($120, 35, 16), `starShard` ($300, 90, 10), `gradingSeal` ($400, 150, 8), `material_<boss>` for the seven bosses in `Config/Weapons` MATERIALS ($350, 150, 1.5, excited), `goldSeal` ($12,500, 10,000, 1.5)
  - `SPOTS: { { name: string, x: number, z: number } }`: corners `(-80,-32)`, `(80,-32)`, `(-80,32)`, `(80,32)` ("the north-west corner"... -Z is north, +X east) and plaza edge at radius 31 on 45/135/225/315 degrees ("the plaza's south-east edge"...), each facing the road's middle line
  - `SHAKE = { degrees = 7, hz = 3.2 }` (head wobble), `SIT_EVERY = { 20, 40 }` (seconds between sit clips)
- Produces (`Util/TurtsRules`):
  - `restockIndex(now: number, seconds: number): number`, `secondsLeft(now: number, seconds: number): number`
  - `roll(offers: { [string]: any }, picks: number, random: () -> number): { string }` (distinct ids, weighted, sorted by id order of the pick)
  - `canBuy(state: State, index: number, stock: { string }, offerId: string): (boolean, string?)`, `State = { index: number, bought: { string }, personal: { index: number, offers: { string } }? }`, reasons `"restocked"`, `"notInStock"`, `"bought"`
  - `refresh(state: State, index: number): State` — a new restock clears `bought` and drops a `personal` roll from an older restock; the same restock leaves it untouched
  - `stockFor(state: State, index: number, global: { string }): { string }` — the personal roll when `state.personal.index == index`, else the global stock
  - `nextSpot(previous: number?, count: number, random: () -> number): number`
  - `priceOk(offer: any, premium: number): boolean`
  - `shakeAngle(t: number, shake: { degrees: number, hz: number }): number` (degrees)

- [ ] **Step 1: Write the failing tests** in `tests/TurtsRules.spec.luau`:

```lua
["the clock: every server restocks on the same 480 s boundary"] = function()
	expect.equal(TurtsRules.restockIndex(960, 480), 2)
	expect.equal(TurtsRules.restockIndex(959, 480), 1)
	expect.equal(TurtsRules.secondsLeft(959, 480), 1)
	expect.equal(TurtsRules.secondsLeft(960, 480), 480)
end,
["a restock is 3 different offers, rarer ones less often"] = function()
	-- a seeded LCG for random(); 20,000 rolls
	-- each roll: 3 ids, no repeats, all in Turts.OFFERS
	-- appearance share of wildOre10 > vrPack > epicPack > legendaryPack
	-- legendaryPack appears in 4%-12% of restocks (about once every 2 hours at 7.5 an hour)
end,
["buy once per restock, only what's in your stock, and nothing after the restock turns"] = function()
	local state = { index = 5, bought = { "vrPack" } }
	expect.equal(TurtsRules.canBuy(state, 5, { "vrPack", "xpTonic", "starShard" }, "xpTonic"), true)
	expect.equal(select(2, TurtsRules.canBuy(state, 5, { "vrPack", "xpTonic", "starShard" }, "vrPack")), "bought")
	expect.equal(select(2, TurtsRules.canBuy(state, 5, { "vrPack", "xpTonic", "starShard" }, "goldSeal")), "notInStock")
	expect.equal(select(2, TurtsRules.canBuy(state, 6, { "vrPack", "xpTonic", "starShard" }, "xpTonic")), "restocked")
end,
["every price is at least 1.5x its usual value; the Gold Seal above the most it can pay"] = function()
	-- for every offer: TurtsRules.priceOk(offer, Turts.PREMIUM)
	-- Turts.OFFERS.goldSeal.price > max cash of any non-Legendary-S step in Config/Grading COSTS (10000)
	-- no offer sells a key fragment or a trophy (Config/Items: fragment_* ids, trophy = true)
end,
["a rejoin keeps what you bought; a new restock (or an old Robux roll) resets it"] = function()
	local state = { index = 5, bought = { "vrPack" }, personal = { index = 5, offers = { "goldSeal", "xpTonic", "starShard" } } }
	expect.equal(#TurtsRules.refresh(state, 5).bought, 1, "same restock: still bought")
	expect.equal(TurtsRules.stockFor(state, 5, { "vrPack", "wildOre10", "epicPack" })[1], "goldSeal", "your Robux roll")
	local next = TurtsRules.refresh(state, 6)
	expect.equal(#next.bought, 0, "a new restock: nothing bought")
	expect.equal(next.personal, nil, "the Robux roll ends with its restock")
	expect.equal(TurtsRules.stockFor(next, 6, { "vrPack", "wildOre10", "epicPack" })[1], "vrPack", "back to everyone's stock")
end,
["he never sets up on the same spot twice in a row"] = function()
	-- for previous = 1..#SPOTS, many random() values: nextSpot ~= previous, within 1..#SPOTS
end,
["his spots stay clear of walker stops and exits, crosswalks, the plaza's props and the shops"] = function()
	-- each spot: >= RUG_RADIUS + 2 from every WalkerRules.townStops / WalkerRules.exits point,
	-- outside every TownLayout.crosswalks rect grown by RUG_RADIUS, >= RUG_RADIUS + 1 from every
	-- PlazaLayout.footprints(Plaza) circle edge, inside the road (|z| <= streetWidth/2 - SIDEWALK - RUG_RADIUS)
end,
["his head shakes small and quick"] = function()
	-- shakeAngle stays within +-SHAKE.degrees; it changes sign within one period (1/hz)
end,
```

- [ ] **Step 2: Run** `lune run tests/run` — Expected: fails loading `Config/Turts` / `Util/TurtsRules`.
- [ ] **Step 3: Implement** `Config/Turts.luau` (values above, the spec's comments) and `Util/TurtsRules.luau`. `roll`: repeat picking one id by weight among those not yet picked until `picks` are chosen (iterate offers in sorted id order so a seed always gives the same roll). `shakeAngle`: `degrees * sin(2*pi*hz*t)` with a slower second sine at 0.37 hz scaling it between 0.6 and 1 so it never looks mechanical.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: all pass.
- [ ] **Step 5: Commit** `git add src/shared/Config/Turts.luau src/shared/Util/TurtsRules.luau tests/TurtsRules.spec.luau tests/run.luau && git commit -m "Turts: restock rules, offers and spots"`

### Task 2: Turts' packs open from the Bag

**Files:**
- Modify: `src/shared/Config/Items.luau` (three items), `src/shared/Util/ItemRules.luau` (`openablePack`), `src/server/Services/PackService.luau` (`OpenItemPack`), `src/server/Services/LevelUpService.luau` (`onOpenBagPack`), `src/shared/Config/UIIcons.luau` if a pack icon is missing
- Test: `tests/ItemRules.spec.luau`

**Interfaces:**
- Produces: items `vrPack` ("Very Rare Pack", `open = "FirstSparkPack"`, `floor = "Very Rare"`), `epicPack` (`floor = "Epic"`), `legendaryPack` (`floor = "Legendary"`, `stingyGrade = true`), each `source = "Turts' rug shop"`, `use = "Bag: tap Open"`, icon `BoosterPack`.
- Produces: `ItemRules.openablePack(config, itemId): (string?, string?, boolean)` — third value `stingyGrade`.
- Produces: `PackService.OpenItemPack(player, productId, floor, itemId, stingy: boolean?)` — with `stingy`, the hit card's grade rolls from `Packs.PITY.LEGENDARY_GRADES`.

- [ ] **Step 1: Write the failing test** in `tests/ItemRules.spec.luau`: `["Turts' packs open from the Bag with their floors; the Legendary Pack's grade is the stingy one"]` asserting `ItemRules.openablePack(Items, "legendaryPack")` returns `"FirstSparkPack", "Legendary", true`, `"epicPack"` returns `"FirstSparkPack", "Epic", false`, `"vrPack"` returns `"FirstSparkPack", "Very Rare", false`, and `"pishGift"` still returns `"FirstSparkPack", "Very Rare", false`.
- [ ] **Step 2: Run** `lune run tests/run` — Expected: FAIL (no such items / no third value).
- [ ] **Step 3: Implement** the items, the third return value, the `stingy` parameter (only the hit card's grade changes), and pass it through `onOpenBagPack`.
- [ ] **Step 4: Run** `lune run tests/run` — Expected: PASS; compile-check `PackService`, `LevelUpService`.
- [ ] **Step 5: Commit** the five files.

### Task 3: Saved Turts state

**Files:**
- Modify: `src/shared/Config/Data.luau` (`SCHEMA_VERSION = 24`), `src/server/Util/Migrations.luau` (step 24), `src/server/Services/DataService.luau` (type + template `turts`)
- Test: `tests/Migrations.spec.luau`

**Interfaces:**
- Produces: `PlayerData.turts: { index: number, bought: { string }, personal: { index: number, offers: { string } }? }`, template `{ index = 0, bought = {} }`.

- [ ] **Step 1: Write the failing test** `["v24 adds Turts' shop state"]`: a v23 save migrates to `turts = { index = 0, bought = {} }`, `schemaVersion == 24`, other fields untouched.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the step, the type and the template; DESIGN.md 10.4 gets the field.
- [ ] **Step 4: Run** — Expected: PASS.
- [ ] **Step 5: Commit.**

### Task 4: TurtsService (server)

**Files:**
- Create: `src/server/Services/TurtsService.luau`, `src/server/Util/TurtsSeed.luau` (the server-only salt: `TurtsSeed.of(index: number): number`)
- Modify: `src/shared/Remotes.luau` (`TurtsStock` server->client, `TurtsBuy` client->server, `TurtsRestockNow` client->server prompt request), `src/shared/Config/Monetization.luau` (`TurtsRestock = 0`), `src/server/init.server.luau` (main game: `TurtsService.Start()` before `DevService.Start()`), `src/server/Services/DevService.luau` (`/turts restock|move|offer <id>`), `src/shared/Config/AdminPanel.luau` (buttons)

**Interfaces:**
- Consumes: Task 1 rules and config, Task 2 items, Task 3 saved shape, `EconomyService.TrySpend`, `ItemService.GiveItem`, `PurchaseService.OnProduct/ProductId`, `Blocked.tell`, `RateLimiter.new`.
- Produces: `workspace.TurtsNpc.Turts` (anchored invisible marker part; attributes `Spot` (number), `SpotName` (string), `RestockIndex` (number), `Excited` (number, +1 each time), `MovedAt` (os.time)); remote payload `TurtsStock(index: number, offers: { string }, bought: { string }, endsAt: number)`; `TurtsService.Start()`.

- [ ] **Step 1: Implement** the service:
  - Each second: `restockIndex(os.time(), 480)`; on change roll the global stock with `Random.new(TurtsSeed.of(index))` and `TurtsRules.roll`, move the marker to `nextSpot`, `Excited += 1`, send every player their stock, toast players in town once ("Turts set up shop by <SpotName>!", `Remotes.Notify`).
  - Per player: `state = TurtsRules.refresh(state, index)` on load and on every restock; stock = `TurtsRules.stockFor(state, index, global)`.
  - `TurtsBuy(offerId)`: type-check string, rate-limit (0.5 s), distance to the marker <= prompt range + 4, `canBuy`; refused reasons -> `Blocked.tell` ("Turts restocked!" / "Not on his rug right now" / "Already bought this restock" / not enough cash); `TrySpend(price)` then `GiveItem(item, count)`, record in `bought`, `Excited += 1` when the offer is `excited`, resend stock.
  - `PurchaseService.OnProduct("TurtsRestock", grant)`: personal roll with a fresh `Random.new()`, saved, stock resent; true.
  - `DataService.Register({ name = "Turts", load, save, unload })`, save only for loaded players.
- [ ] **Step 2: Verify** compile checks; `lune run tests/run` still passes; Studio Play: Output shows no errors, `/turts restock` sends a new stock, `/turts move` moves the marker, buying with enough cash gives the item once and a second buy shows the blocked card.
- [ ] **Step 3: Commit.**

### Task 5: TurtsController and the shop window (client)

**Files:**
- Create: `src/client/Controllers/TurtsController.luau`
- Modify: `src/client/init.client.luau` (main game start), `src/client/Util/PishVisual.luau` only if a `dog` other than Pish/Chikin needs its model lookup widened

**Interfaces:**
- Consumes: the Task 4 marker and remotes; `PishVisual.new(marker, "Turts")`, `PishVisual.play(visual, "sit" | "celebrate")`, `TurtsRules.shakeAngle`, `TurtsRules.secondsLeft`, `UIKit.panel`.

- [ ] **Step 1: Implement**:
  - Turts drawn on the marker (`NpcModels.Turts`; until it exists a stand-in: Chikin's model tinted, or a black block dog), his head bone turned by `shakeAngle` every frame after the clips, `sit` every `SIT_EVERY` seconds, `celebrate` when `Excited` changes.
  - The rug (`PropModels.TurtsRug`, else a stand-in: a round flat cylinder rug, a cushion, a lantern, two crates, a sign) under him at the marker, facing `face`.
  - This player's 3 offers on the rug: a pack offer as the pack model (`Util/PackModels`) tinted by tier, an item offer as a small stand with its icon on a BillboardGui; SOLD ones dimmed with a tag.
  - A billboard over him: "Turts' Shop · 4:12" counting down to the next restock; a 30 s light beacon after he moves.
  - ProximityPrompt "Shop" opens the window: three offer cards (icon/picture, name, what it does from `Config/Items` description, price, Buy or SOLD), the countdown, and "Restock now" (Robux; "Coming soon" while the product id is 0).
- [ ] **Step 2: Verify** in Studio (PC and the phone simulator): the rug and stand-in by a street corner, the timer counting, the window opens, a buy turns its card to SOLD, `/turts move` moves everything with the toast and beacon; screenshots for the owner.
- [ ] **Step 3: Commit.**

### Task 6: Turts' model, rig and clips

**Files:**
- Create: `tools/blender/prep_turts.py` (from `prep_chikin.py`: turn, stand, scale to 1.0 m, ~10,000 triangles), `tools/blender/rig_turts.py` (from `rig_chikin.py`: bone positions measured on Turts)
- Output: `assets/blender/Turts/Turts.blend`, `Turts.fbx`; clips `assets/monster-animations/Turts/` via `DOG=Turts blender -b assets/blender/Turts/Turts.blend --python tools/blender/anim_pish.py` then `lune run tools/anim/build_bone_clips Turts`

- [ ] **Step 1:** Run prep and rig in background Blender; previews (front, side, three-quarter) checked with `look`; `check_stretch.py` on `sit` and `celebrate`.
- [ ] **Step 2:** Owner imports `Turts.fbx` in Studio (Rig Type Custom, Keep Zero Influence Bones); Claude resets the MeshPart pivot rotation and the owner saves it as `assets/npcs/Turts.rbxm`.
- [ ] **Step 3: Verify** in Studio: Turts on his rug with the head shake, a sit and stand, the excited spin; screenshots.
- [ ] **Step 4: Commit** the scripts, the clips and `Turts.rbxm` (not the raw model, concepts or photo).

### Task 7: His rug model

**Files:**
- Create: `tools/blender/build_turts_rug.py` (on `portal_kit`/prop helpers: woven round rug, cushion, lantern, two crates, sign board; one FBX)
- Output: `assets/props/TurtsRug.rbxm` (owner imports the FBX once)

- [ ] **Step 1:** Build in background Blender; render previews for the owner.
- [ ] **Step 2:** Owner imports and saves; Claude checks it drops in for the stand-in.
- [ ] **Step 3: Commit.**

### Task 8: Docs

- [ ] DESIGN.md: a "Turts' rug shop" section (spec summary, numbers, spots, abuse rules), 10.2 file tree, 10.4 saved data; CLAUDE.md: the new test names, dev commands and asset paths; `docs/creatures.md` or the NPC notes: Turts' pipeline; Obsidian: decisions log and lessons. Commit.
