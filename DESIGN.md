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
- Each shelf type holds a set number of product units.
- Customers can only buy what's on shelves. Empty shelves = lost sales.

| Shelf | Capacity | Cost | Unlock |
|---|---|---|---|
| Small Pack Rack | 24 packs | $100 | Start (1 free) |
| Wall Shelf | 48 packs | $350 | Shop Lv 3 |
| Big Display Rack | 96 packs | $1,200 | Shop Lv 6 |
| Glass Showcase | 6 single cards | $800 | Shop Lv 4 |
| Accessory Hook | 20 accessories | $250 | Shop Lv 5 |

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
| Epic | Purple | $5 – $20 |
| Legendary | Gold, animated | $40 – $150 |

**Foil variant:** any card can roll foil (holo shimmer UI effect). Foil = 3x value. Chance: 4% per card.

### 5.3 Pack contents & odds (Set 1 Base Pack)
Each pack = 5 cards:
- Slots 1–3: Common
- Slot 4: Common 70% / Rare 30%
- Slot 5 ("hit slot"): Rare 80% / Epic 17% / Legendary 3%

**Odds are always visible in-game** (pack info button). Required by Roblox for any paid random items, and we show them for everything anyway.

### 5.4 Set 1 — "First Spark" (30 cards)
15 Common, 9 Rare, 4 Epic, 2 Legendary. Placeholder names, art TBD.

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

### 5.5 Card art plan
- MVP: simple flat creature art, consistent style. Rarity frames + foil shimmer (UIGradient animation) do a lot of the heavy lifting.
- All art must be original and uploaded as decals/images to Roblox.

### 5.6 What you do with pulled cards
- **Binder:** collection book UI, shows owned/missing, completion %.
- **Showcase:** put singles in a glass case in your shop. Customers (NPC) may buy them at your set price. Other players can buy them too.
- **Quick sell:** sell back to the "market" for 70% of market value (cash sink-ish, prevents hoarding dead commons).
- **Trading (post-MVP):** player to player trade window.

### 5.7 Pack opening feel (important)
- Tap pack → tear animation → cards fan out face down → tap to flip each.
- Hit slot flips last with a build-up. Rarity-colored glow + sound. Legendary = screen flash, server-wide chat announcement ("Ben pulled a FOIL Solarion!").
- "Open all" button for fast opening once players have lots of packs.

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
- Starting shop: small room, 1 Small Pack Rack, register, order computer.

### 7.2 Shop levels (XP per sale = sale price rounded, min 1)

| Lv | XP needed | Unlocks |
|---|---|---|
| 1 | 0 | Base |
| 2 | 150 | Card Sleeves |
| 3 | 500 | Wall Shelf |
| 4 | 1,200 | Glass Showcase |
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
2. Buy singles from other players' showcases
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
└── src/
    ├── server/                 # → ServerScriptService
    │   ├── init.server.luau    # boots services
    │   └── Services/
    │       ├── DataService.luau      # ProfileStore, load/save, defaults
    │       ├── PlotService.luau      # claim/release plots, build saved layout
    │       ├── EconomyService.luau   # cash, XP, levels (ONLY place cash changes)
    │       ├── StockService.luau     # orders, deliveries, shelf stock
    │       ├── PlacementService.luau # validate + place/move/sell shelves
    │       ├── CustomerService.luau  # NPC spawn, pathing, buying, queue
    │       ├── RegisterService.luau  # checkout flow
    │       ├── PackService.luau      # server-side pack rolls
    │       ├── CollectionService.luau# binder, showcase, quick sell
    │       └── MonetizationService.luau # passes, dev products, ProcessReceipt
    ├── client/                 # → StarterPlayerScripts
    │   ├── init.client.luau
    │   └── Controllers/
    │       ├── UIController.luau
    │       ├── OrderController.luau
    │       ├── PlacementController.luau
    │       ├── RegisterController.luau
    │       ├── PackOpeningController.luau
    │       └── BinderController.luau
    └── shared/                 # → ReplicatedStorage
        ├── Config/
        │   ├── Cards.luau      # Set 1 card list
        │   ├── Rarities.luau   # odds, values, colors
        │   ├── Products.luau   # stock catalog
        │   ├── Shelves.luau
        │   ├── Levels.luau
        │   ├── Upgrades.luau
        │   └── Monetization.luau # pass/product IDs
        ├── Remotes.luau        # all RemoteEvents/Functions defined in one place
        └── Util/
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

### 10.4 Player data schema (v1)
```lua
{
    version = 1,
    cash = 200,
    xp = 0,
    level = 1,
    shopName = "",
    upgrades = {},          -- { [upgradeId] = true }
    stock = {},             -- { [productId] = unitsInBackroom }
    layout = {},            -- { { shelfId, gridX, gridZ, rotation, contents = { productId, units } } }
    prices = {},            -- { [productId] = price }
    cards = {},             -- { [cardId] = { normal = n, foil = n } }
    showcase = {},          -- { { cardId, foil, price } }
    unopenedPacks = {},     -- { [packId] = n }
    stats = { packsOpened = 0, customersServed = 0, totalEarned = 0 },
    purchases = {},         -- processed dev product receipt IDs (for idempotency)
}
```
Bump `version` and write a migration whenever the shape changes.

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
- [ ] Small Pack Rack placement (grid, rotate)
- [ ] Pricing UI for booster packs
- [ ] NPC customers: walk in, pick packs, queue, leave if waiting too long
- [ ] Register checkout
- [ ] Cash + XP + levels 1–5
- [ ] Pack opening (Set 1, server rolls, flip animation, foil effect)
- [ ] Binder UI
- [ ] Quick sell cards
- [ ] Saving with ProfileStore
- [ ] Server pull announcements

**Out (later):** showcase selling to players, trading, staff, expansions, card battles, Set 2, events, most cosmetics.

**Milestone after MVP (v0.2):** showcase + player-to-player singles, game passes live, expansions, more shelves. Soft launch, watch retention (D1/D7) before adding big features.

---

## 12. Open questions
- Final game name and card game name (Glimmerbeasts is placeholder).
- Card art style and who makes it.
- Should customers sometimes ask for specific singles ("got any Voidmaw?") as a quest-like hook?
- Offline earnings: yes/no? (Usually boosts retention but needs care with balance.)
- Cash payment with making change, or keep checkout one-tap?
