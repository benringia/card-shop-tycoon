# Customers with personalities: design

Date: 2026-11-06. Owner's ask: "I like the customers to be not just some mindless bots who go to your shop then buy or
not buy a card ... suggestions on how they behave that fits our core loop, that is also fun." Picked from suggestions
and mockups (`.superpowers/brainstorm/6296-1793900324/content/customer-looks-and-counter.html`, `counter-offer.html`).

## Why

Today every customer is the same: walk in, pick from a 1-3 item list, buy if the price is fair, queue, pay. The shop
works but nothing in it is memorable, and the cards you pull, grade and display barely touch the customers (30% of them
glance at one showcase card). This round gives customers reasons to be noticed and makes the shop's other systems
(packs, showcases, the binder, your creature, prices) matter to them.

## Goals

1. **Customer types you can tell apart on sight**, each wanting something different: Kid, Collector, Bargain hunter,
   Big spender (plus today's plain customers).
2. **Kids open a pack at your counter and may offer you a good pull**, which you can buy for your binder.
3. **Bargain hunters haggle** at your counter.
4. **Your own price**: for a kid's card and for a haggle you can counter with the number you want.
5. **Customers react to your shop**: they stop at your best displayed cards ("whoa"), crowd round a Legendary, pet your
   summoned creature.
6. **A shop rating (1-5 stars)** from how your shop is run, shown on your shop sign and in a chip with tips; it speeds
   up customers.
7. **Phase 2: customers in the town**: a few stroll the plaza, sit on benches, then walk into an open shop of their
   choosing (weighted by rating and what they want).

## Non-goals (this round)

- Regulars who remember you, events (release-day lines, rush hour), shoplifters: possible later rounds.
- New customer models (the Cute Pets pack stays unused here): customers keep today's blocky R15 look.
- Customers selling cards they didn't just pull; player-to-player offers; dialogue.
- Saving anything new: no player data schema change.

## Anti-goals (would make this a failure even if it works)

- **A money loop**: buying cheap from kids and selling dear to collectors, again and again.
- **Kids replacing pack opening**: if good cards come more from kids than from your own rips, the main thrill dies.
  The economy simulator's targets (`lune run tools/economy/sim`: hours to the first Legendary, to a Grade S Legendary)
  must not move noticeably.
- **A town that tanks the frame rate**: the town is near its budget ([[town design perf rules]]).
- **Clutter**: labels over every head, panels popping up away from the register.

## Constraints (from the project rules)

- Server authoritative: types, pulls (grades rolled only on the server), prices, acceptances all decided on the server;
  the client sends intents through remotes in `Remotes.luau`, validated (types, ranges, owner at their register) and
  rate-limited. Never trust a client price: the server recomputes the allowed range.
- Cash only through `EconomyService`; cards through `CardService.GiveCard` with their grade.
- Numbers in `Config/Customers` (and friends); rules the client previews live in pure `src/shared/Util` modules,
  Lune-tested.
- Mobile first: tap targets 48 px or more; cotton candy windows; text plain ASCII + emoji (stars drawn as the `Star`
  image, not ★).
- Customers stay server R15 rigs (`NpcMotion`), at most `MAX_PER_PLOT` (4) per plot.

## Decided with the owner

### 1. Types: props plus an icon as they walk in (option B)

- Each type adds clothing, a prop and colours to today's blocky customer: **Kid** smaller with a cap and a pack in hand,
  **Collector** glasses and a binder, **Bargain hunter** bucket hat and a coupon, **Big spender** shades and a gold
  chain, a few sparkles.
- As they come through your door an icon pops over them for a few seconds then fades (kid 🎒, bargain hunter 🏷️, big
  spender 💎 or UIIcons equivalents). The **Collector instead shows the card they want, the whole time**, in a thought
  bubble (its real card face), so you can check your showcases.

### 2. Offers and haggles in the checkout panel (option A), with your own counter

- Both happen in the panel you scan and charge in (`RegisterController`'s checkout panel, middle-right), only while you
  stand at your register.
- **Kid's card**: the card's real face, name, rarity, grade, its asking price and what it's worth. Buttons **Buy**,
  **Counter**, **No thanks**.
- **Haggle**: "Bargain hunter offers $X for $Y of stock (-N%)". Buttons **Deal**, **Counter**, **No**.
- **Counter (option A)**: − / + buttons that each move 5% of the value, quick chips (-20%, -15%, -10%, Worth), the price
  big in the middle, and the customer's face reacting to the number (😀 sure / 😐 maybe / 😠 no way) without showing
  exact odds. **Offer** and **Back**. No typing (the owner ruled typed prices out earlier).
- How a counter plays out (agreed):
  - **Kid**: asks about what the card's worth. Each kid has a lowest price they'll take. Offer at least that and they
    hand it over; below it they say no, you get one more try, then they keep the card and leave.
  - **Bargain hunter**: offers less than your total. Counter with a number between their offer and your total: close
    enough and they pay it, too greedy and they walk without buying (items back on the shelves). **No** also sends them
    off without buying.
  - **A working Cashier card**: kids don't offer (they only sell to you), and the cashier meets a haggle halfway on its
    own.

### 3. Shop rating on your sign plus a chip with tips (option A)

- 1 to 5 stars (one decimal inside), on your shop's street sign (Star images) for everyone to see.
- A chip for you (HUD) with the stars and number; tapping it opens tips: what's helping (✅) and what to fix (⚠️).

### Fairness of kid offers (agreed)

- Kids open the pack they just bought from you with that pack's real odds; their pulls never touch your pity counters.
- A kid only offers a **Rare or better** pull, at about what it's worth for its grade (a small "friend" discount at
  most, ~10%).
- **A cap** on offers per hour; a Legendary offer is a rare celebrated moment (spotlight, sound) that can't repeat soon.
  *(My call for the numbers: at most 4 kid offers an hour per shop, at most one Legendary offer every 3 hours, both
  counted per session; the economy simulator decides if they move.)*
- **Collectors pay a modest premium** (about 1.3x what the card's worth) so buy-from-kid, sell-to-collector isn't a
  reliable loop.
- The economy simulator gets kid offers added and its targets are checked.
- A fresh pull is always level 1, 0 stars (it can't be "maxed").

### Town walkers (agreed, phase 2)

- A few customers stroll the plaza, sit on the benches, look at the fountain, then pick an **open** shop (its owner in
  the game) and walk in.
- They choose by **rating and what they want** (a collector heads for a shop showing their card), not at random.
- They add to the customers who arrive from each shop's street; they don't replace them.
- A server-wide cap (about 8), fixed paths (the plaza's lanes to the shop doors), measured before and after.

## The behaviours (my calls where marked)

- **Mix** *(my call)*: of customers arriving at a shop, about 55% plain, 20% kid, 10% collector (only when the shop
  has a Glass Showcase), 10% bargain hunter, 5% big spender (from shop level 11, when the booster box unlocks).
- **Kid**: shops for the cheapest pack product (1-2 packs). After paying they rip one pack at the counter (a short
  reveal over the counter everyone nearby sees: the card pops up, a cheer for Rare+). If it's Rare or better, the offer
  comes up in your panel; otherwise they leave happy.
- **Collector** *(my call)*: wants one card: half the time one you own (binder or display) so it can happen, half any
  Set 1 card weighted by rarity (something to chase). Walks the Glass Showcases; buys the wanted card at up to about
  1.3x its worth; otherwise leaves with a disappointed bubble. Also buys from the shelves like a plain customer.
- **Bargain hunter** *(my call)*: shops like a plain customer but tolerates one price band higher; at the counter, once
  everything is scanned, offers 10-25% under the total instead of paying it.
- **Big spender** *(my call)*: arrives with sparkles, takes a booster box if one is stocked (else 6-12 packs), happy up
  to about +30% over market; tips a little on top when the price is at or under market.
- **Reactions** *(my call)*: a customer passing within a few studs of a Glass Showcase or Collector Case holding an
  Epic, Legendary or foil card stops ~1.5 s with a "whoa" bubble; a Legendary on display can hold up to 3 at once. A
  customer near your summoned creature may stop to pet it (a heart bubble, your creature plays a happy fidget). Each
  reaction counts as a happy moment for the rating.

## Rating (my calls)

- Four parts, weighted: **shelves stocked** (share of product shelves with stock) 35%, **fair prices** (average of
  your current prices' customer bands vs market) 25%, **displays** (Epic or better / foil cards on display, Legendaries
  count most) 15%, **happy customers** (paid, happy reactions vs annoyed, gave up, no stock, over the last 20
  customers) 25%.
- Mapped to 1.0-5.0 and smoothed so it moves over a minute or two, not per customer.
- Effect: the spawn gap scales from ×1.4 (1 star) to ×0.6 (5 stars), with 3 stars equal to today's flow (so a shop
  run the way most are today doesn't change); town walkers choose shops by rating (phase 2). More customers is more
  income, so the economy simulator is rerun assuming a well-run shop (about 4 stars) and its targets checked.
- Not saved: it's worked out live from your shop (a fresh join starts from what's on your shelves; the happy-customer
  part starts neutral).

## What's left to the builder

- Exact asset ids for props (built from parts like the plaza's townsfolk, or the town kit), the "whoa" and "petting"
  bubble icons, the reveal effect for a kid's rip (reuse pack-opening pieces), sounds (Roblox-licensed PSE/APM only).
- The checkout panel's layout details within the cotton candy kit; where exactly the rating chip sits on the HUD.
- Patience while an offer waits (the kid keeps standing at the counter; after the usual checkout patience they leave
  with their card), and what the queue behind them does (waits as today).
- Walker paths, bench seats and the shop-choice weighting formula (rating, plus a bonus for a wanted card on display).
- Tests: pure rule modules for types, offers and counters, haggles, rating and walker choice.

## Order

1. Phase 1 (in the shop): types and looks, kid rip + offer + counter, haggle + counter, collector, big spender,
   reactions, rating (sign + chip), economy sim check.
2. Phase 2 (the town): walkers on the plaza and into shops, measured.
