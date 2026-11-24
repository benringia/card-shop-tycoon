# Shop variety and storage reasons: design

Owner's asks, 2026-11-24: "now we need to add something to make the player have the reason to store it in storage
racks", then "do 1 and 2 ... customers dont buy directly from the storage racks. customers only buy from shelves",
"B and 2, make it just 10% off. boxes need to be carried to the storage racks not automatically", "on mid to late game
players start spamming only the boxes not the other ones. any idea how to make them buy and display all products?",
"okay do your picks. so how can we make the player know all this?", then "OK go" on the teaching mockups.

Mockups: pallet deal and away selling (https://claude.ai/artifact/MbjxQGuuksz5D3Wnx5gDBU, picks B and 2, at 10%) and
how players learn it (https://claude.ai/artifact/QocvP9QY1Zek8payPjxRiU, approved as drawn).

## Why

- Storage racks (2026-11-24) hold boxes but give no reason to keep any there.
- Mid to late game shops stock only the First Spark Booster Box: a box sale makes $30, a Deck Box $3, a pack or a
  sleeve $1. Customers pick evenly from every unlocked product (`CustomerService.pickShoppingList`), so a box-only shop
  already makes about 85% of a full shop's profit per customer, and the rating's Stocked part counts shelves with
  stock, not products, so it scores full.
- Today's feedback hides it: a customer who misses a product shows a thinking face and "Aw, they don't have it.", and
  its review says "Shelves were empty" or "Nothing left to buy..." even with full racks of packs.

## Goals

1. A reason to fill racks: pallet deals and longer away selling.
2. A reason to stock every product: variety counts in the rating, and "Found it all!" pays a bonus.
3. Players learn all of it in play: customers say what they missed, the Phone and the order computer name it, Pish says
   it once.

Non-goals: customers never buy from racks (racks only refill shelves); no new products; no saved-data change; no
change to the packs-only early game (the economy sim's shop).

## 1. Pallet deal (order computer, pick B)

- 6 or more boxes of one product in one order: those boxes cost 10% less (`Config/OrderComputer` PALLET
  `{ boxes = 6, off = 0.10 }`). 6 First Spark boxes: $288 becomes $259.20.
- Boxes land on the delivery pad like any order (its 12 spots still cap an order); you or a Restocker carry them to
  racks. Nothing goes onto a rack by itself.
- One rule for both sides: `OrderRules.cartCost` applies the deal; the server (StockService) charges what it computes,
  never a client's number.
- Each card on a computer: a meter of 6 little box slots under the profit pill, filling with the boxes in the cart:
  "6 for -10%" with none, "N more: -10%" with some, gold slots on a wooden pallet and "PALLET -10%!" at 6 or more; then
  the price shows struck through and the deal price in green, and the profit pill turns gold with the deal's profit.
  The tablet grows 40 px taller so the row fits and two rows of cards still show whole.
- A phone's card: the 6 slots over the bottom-left of its picture (gold at 6), the deal price in green.
- The cart: a line at the deal has a gold PALLET chip, its full price struck over the deal price and "N boxes · 10%
  off"; a green "Pallet savings -$x" row sits above the total when any line is at the deal.

## 2. Away selling with racks (pick 2)

- Today: up to 2 h away, shelves sell `UNITS_PER_MINUTE` 2 units a minute at your prices' buy chances.
- New, only while a Restocker works (a card with the Restocker job) and racks hold boxes:
  - The first 2 h: shelves sell as today, and the Restocker refills them from racks: a product's rack units join its
    shelves' stock. Only products that have a shelf (a Products shelf whose product is it, even empty) can be refilled.
  - Each rack holding boxes adds 30 min (`RACK_MINUTES`), up to 2 h more (`MAX_EXTRA_MINUTES`, 4 h in all). That
    extra time sells only what is still in the racks (a rack with one box can't buy a free half hour).
  - Units sold come off shelves first, then rack boxes, half-used boxes first; a box emptied leaves the rack.
- No Restocker: away selling is exactly today's. Racks are never sold from without one.
- Welcome back card (pick 2): under the cash line, a white panel with the Restocker's card picture, "<Card> kept your
  shelves full", "N boxes from your storage racks", a bar of the time selling (blue: shelves, green: storage) with
  "2h from shelves" and "+1h 30m from storage" under it; the hint: "More racks of boxes: up to 4 h of selling while
  you're away." With racks of boxes and no Restocker, no panel and the hint "Give a card the Restocker job: your racks
  keep your shop selling up to 4 h while you're away."
- The panel shows when any rack box was used or extra time was given.

## 3. Variety counts in the rating

- The rating's Stocked part becomes half "shelves stocked" (today's share of product shelves with stock) and half
  "products stocked": unlocked products (the shop level, and a boss for the Frontier Pack; never Bulk Cards) with stock
  on some shelf, over all unlocked products (`RATING.productShare = 0.5`). A shop with 1 of 4 products loses about half
  a star here; its unhappy customers (already counted) cost about another half.
- Its tip names what's missing: "Stock Card Sleeves", "Stock Card Sleeves and Deck Boxes", "Stock Card Sleeves and 2
  more"; with nothing missing, today's "Restock empty shelves". Names: `VARIETY.names` (Booster Packs, Card Sleeves,
  Deck Boxes, Booster Boxes, Frontier Packs).

## 4. "Found it all!"

- A plain customer whose list holds 2 or more different products and who takes at least one of each pays 10% of their
  products' total on top (`FOUND_ALL { share = 0.10, minProducts = 2, types = { plain } }`), rounded to cents, through
  EconomyService, with the tips' side toast "Found it all! +$4.20". They say "Found it all!" (or "Everything I
  wanted!", "This shop has it all!") instead of their goodbye. Kids, collectors, bargain hunters and big spenders never
  get it. A packs-only shop (one product) never gives it.
- Its visit counts as a good one for the rating (outcome "foundAll" in place of "paid"); its review: 5★ "Found
  everything! 🛍️" or "Had all I wanted! ✨", half the time.

## 5. Teaching

- A customer who misses a product: the collector's thought bubble holds that product's picture with a pink "?"
  (in place of the thinking face), and the line names it: "No sleeves? Aww.", "Where are the deck boxes?", "I came for
  booster boxes..."; kids: "Nooo, no packs?", "Aww, no sleeves...". The word is `Config/Offline` PLURALS (sleeves,
  deck boxes, ...).
- Reviews name it: a visit that bought something but missed a product is "partial", 3★ "No sleeves here 😕" or
  "Wanted deck boxes too 😕"; one that found nothing is "noStock", 1★ "No deck boxes at all 😢" or "Couldn't find any
  sleeves 😢" (collectors and an empty shop keep today's lines). The rating counts a partial visit as today's noStock
  did (a bad outcome; its sale still counts as paid).
- The order computer's pink tag: "Customers want this!" on an unlocked product no shelf has ever held (no Products shelf
  whose product is it), with the card's edge pink; "Shelf empty" when a shelf of it ran empty; "Shelves low" as today.
- The rack clipboard: a green stamp "+30 MIN / AWAY SELLING" while the rack holds boxes and a Restocker works, grey
  "NEEDS A / RESTOCKER" while it holds boxes with none.
- Pish's rack lesson gains a fourth line: "Full racks keep your shop selling while you're away!"
- Pish's new lesson "Customers love choice" (id `variety`): the first time a customer misses an unlocked product, from
  shop level 3, once per save (older saves get it the first time it happens). His paws point at the order computer and
  he says, with Next: "That customer wanted Card Sleeves!", "Shops with every product get more customers!", "Customers
  who find it all pay 10% extra!", "Order some here. Bye!".

## Approaches considered

- Pallet: A, a gold ribbon on every card and a savings line; B, a filling meter on each card (picked: a meter to fill
  is a game kids know and shows the reward where you tap).
- Away selling's card: 1, two green chips; 2, the Restocker's report (picked: gives the pet credit, the bar shows what
  storage added).
- Variety: rating, "Found it all!", a product craze, realistic demand weights (picked the first two; the craze is a
  later fun extra, demand weights a nerf with nothing to see).

## Left to the builder

- Exact pixel positions inside the real tablet, card and Welcome back window, matching the mockups.
- Test commands: `/customer plain all` (a plain customer wanting one of every unlocked product), the admin panel's
  lesson button for `variety`; `/away`, `/storage fill`, `/review` as today.
