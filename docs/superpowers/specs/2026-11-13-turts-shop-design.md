# Turts' rug shop

Owner, 2026-11-13: "I want to have a shop at the plaza, a dog on the rug selling stuff. called Turts, turts is also one
of my dog ... what she sells are v-rare, epic, legendary packs, items that drops anywhere. highlevel/rarer items have
lower chances to be restocked. after the timer ends, the shop restocks 3 random items. make sure odds stays balanced,
not game breaking, and also not impossible to get."

## Why

A reason to walk the town between shop work and fights, a small hunt ("where's Turts now?"), and a chance at
something exciting every few minutes, the way restock shops pull players back in other Roblox games. It must never
become the cheap route to anything: the owner's words, "make sure the prices are higher than usual. otherwise players
will just wait for restocks. make sure its abuse proof and balance."

## Turts

- The owner's dog (a black shaggy Shih Tzu, like Chikin): cross-eyed with big pupils, an underbite with two little
  teeth, his tongue tip always out. Meshy model from the owner's pick, concept A with bigger pupils
  (`assets/blender/Turts/concept_A3.png`, raw `Turts_raw.glb`; both local only, like Pish's and Chikin's sources).
- Prepared, rigged and animated like Pish and Chikin (`prep_turts.py`, `rig_turts.py`, clips by `anim_pish.py` with
  `DOG=Turts` or his own `anim_turts.py`), about 10,000 triangles, saved to `assets/npcs/Turts.rbxm`.
- Animations (owner): his head always shakes (the main one, a small quick wobble, always playing on top of the rest);
  he sits down and stands up now and then; he spins in place when he's excited. No walk: he never leaves his rug.
- Excited (my call): when a restock lands, and when a player buys an Epic Pack, a Legendary Pack or a boss material
  from him.

## His rug

- A rug with his things on it, not just him (owner: "his rug should have stuff on them too"): my call, a round woven rug
  in warm colours, a cushion he sits on, a lantern, two small crates and a little chalkboard sign "TURTS" with the
  restock time. Built in Blender (`tools/blender/build_turts_rug.py`, no Meshy credits), one model in
  `assets/props/TurtsRug.rbxm`; a parts stand-in until it's saved.
- The 3 items on sale sit on the rug, each player seeing their own stock (client-side): a pack as the real pack model
  (`Util/PackModels`) in its tier's colour, an item as a small stand with its icon floating over it. Bought ones go
  dim with a "SOLD" tag.

## Where he sits

- Owner: "spawn him randomly on the corner of the streets or the side of the plaza with his rug", and he moves "every
  restock".
- A fixed list of spots in config (my call: the four street corners by the crosswalks and four spots along the
  plaza's edge between the lanes), each clear of the walking lanes, shop doors, crosswalks, town walker stops and the
  plaza's props (Lune-tested). Each restock picks one, never the same as the last; every server agrees (it's chosen
  from the restock number).
- When he moves: a short toast "Turts set up shop by <place>!" for everyone in town, and a soft beacon of light over
  his rug for its first 30 seconds, so players can find him. His sign and a small billboard show the time to the next
  restock.

## The restock

- Every 8 minutes (owner's number), on the same clock in every server: restock number = floor(os.time() / 480).
  Everyone in every server sees the same 3 items, so "Turts has a Legendary Pack!" is the same news everywhere.
- Each restock picks 3 different offers by weight (rarer = lower weight). Each offer can be bought once per player per
  restock (owner: "restock also stocks only 1qty per item"); a bundle counts as one.
- Robux "restock now" (owner: "lets add robux restock now"; about 49 R$, new developer product `TurtsRestock`, "Coming
  soon" until its id is set): a fresh roll of 3 offers for that player only, same weights, until the next timer
  restock; the purchases still cost cash.

## What he sells

Prices are "higher than usual" (owner): each one is at least `PREMIUM` (1.5) times what the item costs to earn the
normal way, so waiting for Turts is never cheaper than playing; anything worth a known amount of cash costs more than
that cash. Values from the game's own numbers (economy simulator: a 4-star shop earns about $700 an hour; a First Spark
pack is about $3). All my calls, checked with the simulator before building.

Each offer's usual value (`value` in config, the cash it takes to earn it the normal way: a pack's expected pack
spend, a drop's farming time at $700 an hour) sits next to its price, and a test checks price >= PREMIUM x value.

| Offer | Price | Usual value | Weight | Where the value comes from |
| --- | --- | --- | --- | --- |
| Very Rare Pack (a First Spark pack, its last card Very Rare or better) | $25 | $10 | 16 | a Very Rare or better takes about 3 packs |
| Epic Pack (last card Epic or better) | $75 | $25 | 8 | an Epic or better takes about 7 packs (pity at 40) |
| Legendary Pack (last card Legendary) | $600 | $300 | 2.5 | a Legendary takes about 100 packs; its grade rolls the pity Legendary's way (Grade S 0.2%), so the long Grade S chase stays |
| Wild Ore x10 (one bundle) | $400 | $165 | 20 | 15% from wild monsters: about 67 fights, 14 minutes |
| XP Tonic | $120 | $35 | 16 | 400 creature XP: about a dozen wild fights |
| Star Shard | $300 | $90 | 10 | 3% from Frontier monsters: about 33 fights |
| Grading Seal | $400 | $150 | 8 | mid boss loot (Ember Colossus, Frost Tyrant) and their daily bonus |
| A boss weapon material (one of the seven, each its own offer) | $350 | $150 | 1.5 each | about 1.2 per full-loot win, once per 15 minutes per boss; a boss weapon needs 15-40 |
| Gold Seal | $15,000 | $10,000 | 1.5 | pays one grade step's cash, up to $10,000: always more than it can pay (first written $12,500, under the 1.5x rule) |

Never sold: boss key fragments (they unlock the boss ladder), trophies, Pish's presents.

With these weights, about 7.5 restocks an hour: a Legendary Pack shows up about once every two hours of play, an Epic
Pack two or three times an hour, a boss material once or twice an hour. Rare, not impossible. Packs bought from Turts
open from the Bag (like Pish's gift) and count as packs opened (pity, the leaderboard, titles), like any other.

## Abuse-proofing

- Server authoritative: the stock is rolled on the server (seeded from the restock number and a server-only salt);
  clients get their stock from the server; prices come from server config, never the client.
- Buying (one remote): the offer must be in that player's stock for the current restock and not bought yet, the
  player must be near Turts (prompt range) and have the cash (EconomyService); rate-limited (RateLimiter). A buy that
  arrives just after a restock is refused with a big "Turts restocked!" card (`Util/Blocked`), never silently.
- Saved per player (DataService, new schema step + migration + test): the restock number, the offers bought in it, and
  a "restock now" roll if they bought one. Rejoining, hopping servers or teleporting never resets what they can buy;
  ProfileStore's session lock stops two servers at once.
- "Restock now" goes through PurchaseService's one ProcessReceipt (receipts are already saved and granted once).
- No trading exists, so nothing bought can be resold to another player.
- Lune tests on the pure rules: the roll (3 different offers, weights respected over many rolls), the price rule
  (every price at least PREMIUM x its usual value, the Gold Seal above the most it can pay), the once-per-restock
  check, the restock number at the boundary, the spot choice (never the same spot twice in a row) and the spots'
  clearance.

## The shop window

- His ProximityPrompt "Shop" opens a cotton-candy window (`UIKit.panel`, mobile-first): the 3 offers as cards (icon or
  pack picture, name, what it does, price, Buy or SOLD), the time to the next restock, and the "Restock now" Robux
  button. Locked offers show why (not enough cash) through the usual blocked card.
- Studio dev commands: `/turts restock` (a new roll for you now), `/turts move` (he moves to the next spot), `/turts
  offer <id>` (that offer in your stock), plus admin panel buttons.

## Where it runs

- The main game's town only (the Frontier and the Dungeon have no Turts); open to every player from the start, no
  shop level needed (most offers cost more than a new player has, which is fine: something to save for).
- The "Turts set up shop" toast shows only to players in town, once per restock.

## Out of scope

- Shared stock between players, offers for Robux, selling cards or weapons, a Turts quest line.
