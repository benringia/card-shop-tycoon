# Card Shop Tycoon — Game Design Doc

> Working title. Roblox game inspired by TCG card shop simulators.
> This doc is the source of truth for scope, systems, numbers and code structure.
> If something in code disagrees with this doc, either fix the code or update the doc. Don't let them drift.

---

## 1. The pitch

You run a trading card shop. Order stock, fill your shelves, set prices, ring up customers, and grow a tiny corner store into the biggest card shop on the server. Between customers, rip packs yourself to chase legendary pulls, show off your best cards in display cases, and sell singles to other players.

**Audience:** Roblox core (mostly 9–16), mobile-first, but the shop management angle also pulls older players.

**Design pillars**

1. **Satisfying routine.** Restocking, scanning, and counting cash should feel good, like the Steam shop sims.
2. **The pull.** Pack opening is the dopamine hit. It needs to look and sound amazing, even at low rarities.
3. **Show it off.** Your shop and your cards are visible to everyone on the server. Status drives spending.
4. **Short sessions work.** A 5-minute session on mobile should still feel like progress.

---

## 2. Core loop

```
Order stock (computer) → Restock shelves → Set prices
        ↑                                      ↓
 Buy upgrades / expand  ←  Earn cash  ←  Customers buy & check out
        ↑
 Open packs yourself → pull rares → display / sell singles / keep in binder
```

**Moment to moment:** walk around your shop, carry boxes from the delivery spot to shelves, scan items at the register, open a pack while waiting for the next customer.

**Session goal:** hit the next shop level / afford the next upgrade.

**Long term:** max out your shop, complete the card set binder, own the rarest cards on the server.

---

## 3. World layout

- One server = **6 shop plots** around a central street/plaza.
- Players spawn in the plaza, claim a free plot (or auto-assign on join).
- Plaza has: leaderboard (richest shops), a "featured shop" sign, later a tournament hall.
- Plots are fixed size but have **expansion zones** that unlock (walls move back / second room opens).
- Other players can walk into your shop and see your shelves and display cases.

---

## 4. Shop systems

### 4.1 Plots
- Claim on join. Release on leave. Shop layout loads from saved data.
- Plot owner name + shop name shown on a sign out front. Shop name is player-chosen (filtered with TextService).

### 4.2 Ordering stock
- Computer in the back room opens the **Order UI** (catalog of products unlocked so far).
- Ordering costs cash immediately. Delivery arrives after a short delay (10s at start, upgradable) as boxes at the delivery spot.
- Player picks up a box (carry it, one at a time at start) and places it on a shelf to stock it.

### 4.3 Shelves & placement
- Shelves are placed in the shop on a **grid** (placement mode: rotate, move, sell back for 50%).
- Each product shelf holds a set number of product units; card cases hold single cards (see 5.6).
- Customers can only buy what's on shelves. Empty shelves = lost sales.

| Shelf | Capacity | Cost | Unlock |
|---|---|---|---|
| Small Pack Rack | 24 packs | $100 | Start |
| Glass Showcase | 6 single cards, NPC customers buy | $250 | Start |
| Collector Case | 6 single cards, other players buy | $300 | Start |
| Wall Shelf | 48 packs | $350 | Shop Lv 3 |
| Accessory Hook | 20 accessories | $250 | Shop Lv 5 |
| Big Display Rack | 96 packs | $1,200 | Shop Lv 6 |

### 4.4 Pricing
- Each product has a **market price** (shown in UI). Player sets their sell price per product type.
- Customer willingness to buy depends on price vs market:
  - ≤ market: almost always buys
  - up to +20%: sometimes buys
  - +20% to +50%: rarely
  - > +50%: never, and leaves a little annoyed (shows a 😠 bubble)
- Sweet spot is slightly above market. This is the "skill" part of the sim.

### 4.5 Customers (NPCs)
- Spawn from the street, walk in using PathfindingService.
- Each customer has a small shopping list (1–3 items), browses shelves, picks items, joins the register queue.
- If they wait too long in the queue they leave (no sale).
- Customer spawn rate scales with **shop rating** (cleanliness of stock, price fairness, decor score).
- Keep NPC count capped per plot (start 4 max at once) for performance. Use simple rigs, no fancy animations at first.

### 4.6 Register / checkout
- Player stands at register, customer puts items on counter, player clicks/taps each item to scan, then confirms payment.
- Payment: cash (make change, later feature) or card (instant). MVP = one tap to confirm total.
- Later: hire a cashier to automate.

### 4.7 Shop level & rating
- **Shop XP** from every sale. Levels unlock new products, shelves, expansions.
- **Shop rating** (1–5 stars) affects customer flow. Factors: % shelves stocked, prices vs market, decor points.

---

## 5. Cards & packs

### 5.1 The card game (lore/IP)
Original IP, no real-world TCGs. Working name: **Glimmerbeasts**.

Five elements, each with its own color and frame:

| Element | Color | Vibe |
|---|---|---|
| Ember | Orange/red | fiery, aggressive |
| Tide | Blue | calm, tricky |
| Bloom | Green | cute, nature |
| Volt | Yellow | fast, chaotic |
| Shade | Purple | spooky, rare-feeling |

### 5.2 Rarities

| Rarity | Frame | Market value range |
|---|---|---|
| Common | Grey | $0.10 – $0.50 |
| Rare | Blue | $1 – $3 |
| Very Rare | Cyan | $3 – $6 |
| Epic | Purple | $5 – $20 |
| Legendary | Gold, animated | $40 – $150 |

**Foil variant:** any card can roll foil (holo shimmer UI effect). Foil = 3x value. Chance: 4% per card.

### 5.3 Pack contents & odds (Set 1 Base Pack)
Each pack = 5 cards:
- Slots 1–3: Common
- Slot 4: Common 70% / Rare 30%
- Slot 5 ("hit slot"): Rare 68% / Very Rare 15% / Epic 14% / Legendary 3%

**Odds are always visible in-game** (pack info button). Required by Roblox for any paid random items, and we show them for everything anyway.

### 5.4 Set 1 — "First Spark" (35 cards)
15 Common, 9 Rare, 5 Very Rare, 4 Epic, 2 Legendary. Placeholder names, art TBD.

| # | Name | Element | Rarity |
|---|---|---|---|
| 1 | Cindercub | Ember | Common |
| 2 | Puffpuddle | Tide | Common |
| 3 | Sprouthop | Bloom | Common |
| 4 | Zappit | Volt | Common |
| 5 | Gloomlet | Shade | Common |
| 6 | Ashbeak | Ember | Common |
| 7 | Shellshy | Tide | Common |
| 8 | Mossmole | Bloom | Common |
| 9 | Fizzlebug | Volt | Common |
| 10 | Wispurr | Shade | Common |
| 11 | Coalbit | Ember | Common |
| 12 | Driplet | Tide | Common |
| 13 | Petalpaw | Bloom | Common |
| 14 | Sparkrat | Volt | Common |
| 15 | Hushmoth | Shade | Common |
| 16 | Blazehound | Ember | Rare |
| 17 | Reefray | Tide | Rare |
| 18 | Thornback | Bloom | Rare |
| 19 | Boltlynx | Volt | Rare |
| 20 | Nightowl | Shade | Rare |
| 21 | Magmaw | Ember | Rare |
| 22 | Mistfin | Tide | Rare |
| 23 | Vinewyrm | Bloom | Rare |
| 24 | Stormjack | Volt | Rare |
| 25 | Infernox | Ember | Epic |
| 26 | Abyssal Koi | Tide | Epic |
| 27 | Thunderhorn | Volt | Epic |
| 28 | Eclipse Fox | Shade | Epic |
| 29 | Solarion | Ember | Legendary |
| 30 | Voidmaw | Shade | Legendary |
| 31 | Emberwing | Ember | Very Rare |
| 32 | Tidecaller | Tide | Very Rare |
| 33 | Briarhorn | Bloom | Very Rare |
| 34 | Voltkit | Volt | Very Rare |
| 35 | Duskstalker | Shade | Very Rare |

### 5.5 Card art plan
- MVP: simple flat creature art, consistent style. Rarity frames + foil shimmer (UIGradient animation) do a lot of the heavy lifting.
- All art must be original and uploaded as decals/images to Roblox.

### 5.6 What you do with pulled cards
- **Binder:** collection book UI, shows owned/missing, completion % (cards on display count as owned).
- **Glass Showcase:** put singles on display for NPC customers. Some customers (about 30%) look at it; whether they
  take a card depends on your price vs its market value, using the same bands as packs (4.4). They pay at the register.
  If they give up in the queue, the card goes back in the case.
- **Collector Case:** singles for other players only. Visitors press E on a card, confirm the price, and buy;
  cash goes to the owner, the card to the buyer's binder. The server rejects the buy if the price changed after
  the buyer saw it.
- Card prices default to market value; +/- steps are 10% of market value, capped at 3× market.
- Cards on display leave the binder while shown and come back when removed. A case can't be sold while it holds cards.
- **No quick sell.** Cards only earn money by selling to customers or players, which keeps pulls tied to running the shop.
- **Trading (post-MVP):** player to player trade window.

### 5.7 Pack opening feel (important)
- Tap pack → tear animation → cards fan out face down → tap to flip each.
- Hit slot flips last with a build-up. Rarity-colored glow + sound. Legendary = screen flash, server-wide chat announcement ("Ben pulled a FOIL Solarion!").
- "Open all" button for fast opening once players have lots of packs.

### 5.8 Glimmerbeasts (cards that grow)
Direction: TCG card shop meets creature collecting. Cards become beasts that grow, work and fight.
Full spec: `docs/superpowers/specs/2026-10-20-beast-cards-design.md`.

Roadmap (one sub-project at a time):
1. **Beast cards** — level, XP, stars, grades, stats, value (done).
2. **Shop jobs** — beasts work in your shop (replace hired staff, 7.4).
3. **Party & summoning** — summon beasts to follow and fight beside you.
4. **Star merging** — the Condenser combines duplicates to raise stars (spec `2026-10-20-stars-condenser-design.md`).
5. **Battles** — real-time auto-fight between players' parties.

Plain copies stack by card, foil and grade; a copy becomes an individual card (keeping its grade) the first time it gains XP or a star.

**Grades** (spec `2026-10-20-card-grades-design.md`): every pulled card rolls a grade on the server, fixed forever.

| Grade | Chance | Stats and value |
|---|---|---|
| C | 55% | +0% |
| B | 30% | +3% |
| A | 13% | +6% |
| S | 2% | +10% |

**Power** = HP + 5 × ATK + 5 × SPD, shown on cards. Rarity always beats grade at equal level and stars: the best
copy of a rarity (best element, S, foil) has less Power than the worst copy of the next rarity (unit-tested).

| Beast field | Meaning |
|---|---|
| `id` | GUID, unique per beast |
| `cardId` | which Set 1 card |
| `foil` | boolean |
| `level` | 1–30 |
| `xp` | progress toward the next level |
| `stars` | 0–5 (every card starts at 0) |

Base stats by rarity:

| Rarity | HP | ATK | SPD |
|---|---|---|---|
| Common | 60 | 12 | 10 |
| Rare | 80 | 16 | 12 |
| Very Rare | 100 | 21 | 14 |
| Epic | 135 | 27 | 17 |
| Legendary | 180 | 36 | 20 |

Element multipliers: Ember ATK ×1.20 · Tide HP ×1.20 · Bloom HP and ATK ×1.10 · Volt SPD ×1.25 · Shade ATK and SPD ×1.10.
Then × level `1 + 0.06 × (level − 1)`, × stars `1 + 0.15 × stars`, × foil 1.05, rounded.

Value (the market value used everywhere): `card.value × (foil ? 3 : 1) × (1 + 0.10 × (level − 1)) × STAR_VALUE[stars]`,
`STAR_VALUE` for 0–5 stars = `{ 1, 6, 15, 30, 50, 80 }` (roughly the duplicates condensed plus a bonus).

XP from level L to L+1: `round(50 × L^1.5)`. Extra XP carries over; at Lv 30 XP stops (stored as 0).
Stars come only from the Condenser (Plan B, not built yet; no level gate, levels raise stats only). Duplicates per star (`STAR_COSTS`):

| Step | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | Total |
|---|---|---|---|---|---|---|
| Duplicates | 4 | 8 | 12 | 16 | 24 | 64 |

The binder shows the next step on every card ("Stars 0/5 · condense 4 duplicates for the next star").
Player-facing text says "Owned" and "levelled", never "fresh" or "raised".
Numbers live in `Config/Beasts.luau`. Studio: `/beastxp <amount>` gives XP to your best levelled card or rarest plain card.

---

## 6. Products (stock you sell)

| Product | Wholesale (box) | Units | Market price / unit | Unlock |
|---|---|---|---|---|
| First Spark Booster Pack | $48 / box | 24 | $3.00 | Start |
| Card Sleeves | $30 / box | 20 | $2.50 | Lv 2 |
| Deck Box | $60 / box | 10 | $9.00 | Lv 5 |
| First Spark Booster Box (sealed) | $90 each | 1 | $120 | Lv 7 |
| Set 2 Booster Pack | TBD | 24 | TBD | Lv 10 |

Player can also open their own stock instead of selling it. Trade-off: sell for safe profit, or gamble on a big pull.

---

## 7. Progression & economy

### 7.1 Start
- Starting cash: **$200**
- Starting shop: small room, register, order computer. No shelves: the first Small Pack Rack is bought from the Build menu.

### 7.2 Shop levels (XP per sale = sale price rounded, min 1)

| Lv | XP needed | Unlocks |
|---|---|---|
| 1 | 0 | Base |
| 2 | 150 | Card Sleeves |
| 3 | 500 | Wall Shelf |
| 4 | 1,200 | — |
| 5 | 2,500 | Accessory Hook, Deck Box, Expansion 1 |
| 6 | 5,000 | Big Display Rack |
| 7 | 9,000 | Sealed Booster Box |
| 8 | 15,000 | Hire Restocker |
| 9 | 24,000 | Hire Cashier, Expansion 2 |
| 10 | 36,000 | Set 2 |

### 7.3 Upgrades (one-off purchases)

| Upgrade | Effect | Cost |
|---|---|---|
| Faster Delivery I/II/III | Delivery 10s → 6s → 3s → instant | $300 / $900 / $2,500 |
| Carry Cart | Carry 3 boxes at once | $600 |
| Bigger Queue | Customers wait 50% longer | $400 |
| Street Sign | +10% customer spawn rate | $750 |
| Expansion 1 | +50% floor space | $2,000 |
| Expansion 2 | Second room | $8,000 |

### 7.4 Staff (post-MVP but planned)
- Superseded: beast shop jobs (5.8 roadmap step 2) replace hired staff.
- **Restocker:** moves boxes from delivery to shelves automatically. Hourly wage in-game cash.
- **Cashier:** checks out customers automatically, slightly slower than player.
- Staff keep earning only while player is online (no offline earnings in MVP).

### 7.5 Tuning goals
- First upgrade within ~3 minutes.
- Shop Lv 5 in about 1–1.5 hours of play.
- Lv 10 in about 8–10 hours.
- These are targets. Tune after playtesting, keep numbers in config files so it's easy.

---

## 8. Monetization

Principle: sell **convenience, speed and looks**, not "win". Never sell anything that makes another player's experience worse.

### Game passes (one-time)
| Pass | Effect | Suggested price |
|---|---|---|
| 2x Cash | Double sale income | 299 R$ |
| Auto Restock | Shelves refill from stock automatically | 199 R$ |
| VIP | Gold name tag, VIP shop theme, +1 NPC cap | 149 R$ |
| Extra Showcase Slots | +6 showcase slots | 99 R$ |
| Fast Open | Instant pack opening animation skip + Open All x10 | 79 R$ |

### Developer products (repeatable)
| Product | Effect | Suggested price |
|---|---|---|
| Cash packs | $1k / $5k / $25k in-game | 25 / 99 / 399 R$ |
| Lucky Hour | +50% Epic/Legendary odds for 60 min (new odds shown in UI) | 49 R$ |
| Customer Rush | 2x customer spawns for 15 min | 29 R$ |

### Cosmetics
- Shop themes (floor, walls, lighting): retro arcade, neon, cozy wood, etc.
- Register skins, sign styles, card sleeve colors in binder.

### Other
- Private servers enabled (cheap price).
- Premium payouts: just having engaging sessions helps here.

**Rule:** anything with a random result bought with Robux must show odds before purchase.

---

## 9. Social features (post-MVP order)
1. Server-wide pull announcements (MVP, cheap win)
2. Buy singles from other players' Collector Cases (done)
3. Trading window (with confirm + both sides lock)
4. Leaderboards: richest shop, rarest collection
5. Play Glimmerbeasts at tables (simple card battle mini-game), tournaments bring customers
6. Weekly limited packs / events

---

## 10. Tech architecture

### 10.1 Tooling
- **Rojo** for syncing files into Studio. Code lives in the repo, not in Studio.
- **Wally** for packages.
- **ProfileStore** for player data (session locking, safe saves).
- Optional later: Selene (linter), StyLua (formatter).

### 10.2 Folder structure
```
/
├── DESIGN.md
├── default.project.json        # Rojo project
├── wally.toml
├── tests/                      # Lune unit tests for pure modules: lune run tests/run
└── src/
    ├── server/                 # → ServerScriptService
    │   ├── init.server.luau    # boots services
    │   ├── Services/
    │   │   ├── DataService.luau      # ProfileStore, load/save, defaults
    │   │   ├── PlotService.luau      # claim/release plots, build saved layout
    │   │   ├── EconomyService.luau   # cash, XP, levels (ONLY place cash changes)
    │   │   ├── StockService.luau     # orders, deliveries, carrying, stocking shelves
    │   │   ├── PlacementService.luau # validate + place/move/sell shelves, shelf contents
    │   │   ├── PricingService.luau   # player sell prices per product
    │   │   ├── CustomerService.luau  # NPC spawn, pathing, buying, queue
    │   │   ├── RegisterService.luau  # checkout flow
    │   │   ├── PackService.luau      # server-side pack rolls
    │   │   ├── CardService.luau      # binder contents (not named CollectionService to avoid clashing with Roblox's)
    │   │   ├── ShowcaseService.luau  # display cards, price them, player buys, customer card buys
    │   │   ├── DevService.luau       # Studio-only test chat commands
    │   │   └── MonetizationService.luau # passes, dev products, ProcessReceipt
    │   └── Util/
    │       └── RateLimiter.luau      # per-player remote cooldowns
    ├── client/                 # → StarterPlayerScripts
    │   ├── init.client.luau
    │   ├── Controllers/
    │   │   ├── UIController.luau       # cash display, toasts
    │   │   ├── OrderController.luau
    │   │   ├── BuildController.luau    # build menu, shelf prompts, shelf edit menu
    │   │   ├── PlacementController.luau
    │   │   ├── PricingController.luau
    │   │   ├── RegisterController.luau
    │   │   ├── CarryController.luau    # drop carried box
    │   │   ├── PackOpeningController.luau
    │   │   ├── AnnouncementController.luau # big-pull chat messages
    │   │   ├── BinderController.luau   # two-page binder (3x3 pockets), search + filters, hover tooltips
    │   │   ├── ShowcaseController.luau # manage your own card case, marketplace style: listings, details, tooltip, Set price
    │   │   ├── CardBuyController.luau  # visitors browse other players' cases (marketplace style); buy from Collector Cases
    │   │   └── CardEffectsController.luau # rarity glows, sparkles, foil shimmer, listing bursts
    │   └── Util/
    │       └── UIKit.luau              # shared UI building helpers
    └── shared/                 # → ReplicatedStorage
        ├── Config/
        │   ├── Cards.luau      # Set 1 card list
        │   ├── Rarities.luau   # odds, values, colors
        │   ├── Products.luau   # stock catalog
        │   ├── Shelves.luau
        │   ├── Plots.luau      # plot layout and fixtures
        │   ├── Economy.luau    # starting cash/level
        │   ├── Stock.luau      # delivery, carrying
        │   ├── Placement.luau  # grid, placement rules
        │   ├── Pricing.luau    # price limits, customer buy bands
        │   ├── Customers.luau  # NPC spawn, patience, bubbles
        │   ├── Register.luau   # checkout reach, counter items
        │   ├── Packs.luau      # pack slots and odds
        │   ├── PackOpening.luau # reveal timings and sounds (client)
        │   ├── Collection.luau # binder request limits
        │   ├── Showcase.luau   # card case prices, customer card chance, slot layout
        │   ├── CardEffects.luau # per-rarity effects on displayed cards (client)
        │   ├── Announcements.luau # which pulls get a server-wide chat message
        │   ├── Data.luau       # DataStore name, schema version, kick messages
        │   ├── Beasts.luau     # beast stats, value and XP numbers
        │   ├── Levels.luau
        │   ├── Upgrades.luau
        │   └── Monetization.luau # pass/product IDs
        ├── Remotes.luau        # all RemoteEvents/Functions defined in one place
        └── Util/
            ├── PlacementGrid.luau # grid maths shared by client preview + server validation
            ├── PriceRules.luau    # price clamping and buy bands
            ├── BeastMath.luau     # pure beast stat/value/XP maths (no Roblox APIs, Lune-tested)
            ├── BeastRules.luau    # BeastMath bound to the game configs
            ├── CardRules.luau     # card market value and price limits
            └── LevelRules.luau    # XP → level maths and unlock lists
```

### 10.3 Rules for the code
- **Server authoritative.** Client only sends intents ("I want to order X", "place shelf at Y", "open pack"). Server validates everything and changes state.
- **All cash/XP changes go through EconomyService.** No other script touches cash directly.
- **Pack rolls happen on the server only.** Client just plays the animation for the result it's given.
- Validate remote args (types, ranges, ownership of plot, distance checks for interactions).
- Rate-limit remotes that can be spammed (open pack, scan item, order).
- All tunable numbers live in `shared/Config`. No magic numbers in services.
- Use Luau type annotations (`--!strict` where practical).
- Mobile-first UI: big tap targets, test at phone resolution.

### 10.4 Player data schema (v5)
```lua
{
    version = 5,
    cash = 200,
    xp = 0,
    level = 1,
    shopName = "",
    upgrades = {},          -- { [upgradeId] = true }
    prices = {},            -- { [productId] = price }
    layout = {},            -- { { shelfId, gridX, gridZ, rotation, productId?, units, paid, cards? } }
                            --   cards (card cases): { { slot, cardId, foil, price, grade, beastId?, level?, xp?, stars? } } (stars 0-5)
    fixtures = {},          -- { [fixtureId] = { gridX, gridZ, rotation } } e.g. the moved order computer
    boxes = {},             -- { { productId, units } } on the pad, carried, or ordered but not delivered
    cards = {},             -- { [cardId] = { [grade] = { normal = n, foil = n } } } plain copies in the binder, not on display
    beasts = {},            -- { [beastId] = { cardId, foil, level, xp, stars, grade } } levelled cards in the binder (stars 0-5)
    stats = { packsOpened = 0, customersServed = 0, totalEarned = 0 },
    purchases = {},         -- processed dev product receipt IDs (for idempotency)
}
```
Bump `version` and write a migration whenever the shape changes.
Template and types live in `DataService.luau`. Packs are opened straight from carried boxes, so there is no
separate unopened-packs inventory; unsold stock is saved as `boxes` rather than a backroom count.

Loading is defensive: unknown IDs are dropped, prices re-clamped, level recomputed from XP, and saved shelves
that no longer fit are skipped (cards from a skipped case go back to the binder).
When a player leaves, customers put picked-up stock and cards back before the save.

Schema history: v1 first release; v2 moved displayed cards onto `layout` entries and dropped the unused `showcase` list; v3 added the `beasts` table; v4 made stars start at 0 (old star counts drop by one); v5 gave every copy a grade (rolled per copy on upgrade). A service that didn't load for a player (e.g. no free plot) never overwrites
their saved data.

### 10.5 Performance budget
- Max 6 plots × 4–8 NPCs. NPC movement on server, keep rigs simple.
- Use CollectionService tags for shelves/interactables.
- Stream-friendly: enable StreamingEnabled, test on low-end phone.

---

## 11. MVP scope (v0.1 — first playable)

**In:**
- [x] Rojo project set up and syncing
- [x] Plot claiming (6 plots)
- [x] Order computer + delivery + carrying boxes
- [x] Small Pack Rack placement (grid, rotate)
- [x] Pricing UI for booster packs
- [x] NPC customers: walk in, pick packs, queue, leave if waiting too long
- [x] Register checkout
- [x] Cash + XP + levels 1–5
- [x] Pack opening (Set 1, server rolls, flip animation, foil effect)
- [x] Binder UI
- [x] ~~Quick sell cards~~ (removed: cards now sell through card cases)
- [x] Saving with ProfileStore
- [x] Server pull announcements
- [x] Card cases: Glass Showcase (NPC customers buy) + Collector Case (players buy, with confirm)

**Out (later):** trading, staff, expansions, card battles, Set 2, events, most cosmetics.

**Milestone after MVP (v0.2):** game passes live, expansions, more shelves. Soft launch, watch retention (D1/D7) before adding big features.

---

## 12. Open questions
- Final game name and card game name (Glimmerbeasts is placeholder).
- Card art style and who makes it.
- Should customers sometimes ask for specific singles ("got any Voidmaw?") as a quest-like hook?
- Offline earnings: yes/no? (Usually boosts retention but needs care with balance.)
- Cash payment with making change, or keep checkout one-tap?
