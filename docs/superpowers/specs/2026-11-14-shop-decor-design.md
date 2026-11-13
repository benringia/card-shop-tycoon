# Shop Decor

Owner 2026-11-14: "next is Decors". He picked shop looks plus placeable pieces for launch, with plushies after
("okay go"), and kept every look, piece and number proposed with the mockups ("nothing, go"). The mockups (six looks
on a real shop in Play, a concept sheet of the twelve pieces) are in the visual companion's `decor-direction` page.

## Why

The Shop menu's Decor tab says "coming soon". The shop rating already has a `decor` part, weighted 0 until this
system exists. Kids want a shop that looks like theirs, and a shop that reads as "theirs" from the street is a reason
to keep playing and to show friends. Decor also gives cash a use beyond shelves and stock, and it ties into the
rating: a decorated shop draws customers a little more often.

## Goals

- A **Looks** row in the Decor tab: six whole-shop interior styles, bought once with cash, switched freely after.
- A **Pieces** grid in the Decor tab: twelve placeable decorations, bought and placed like shelves.
- The rating's decor part gets a real weight, filled by a look plus a handful of pieces.
- It runs on the existing systems: the shelf catalogue, the placement grid and ghost, the rating, saved layouts, the
  Pish lessons.

## Non-goals (launch)

- Creature plushies (after launch; they reuse the heavy creature models).
- Wall-mounted pieces (posters, frames). Pieces stand on the floor grid.
- Changing the outside of shops. Every shop's outside stays the one modern look.
- Robux decor. Cash only (owner: no pay-to-win; cosmetic Robux decor can come later).
- Animated pieces beyond one cheap touch each where noted.

## Anti-goals

- Decor that crowds out shelves: pieces have their own cap and never count against the 30 shelves.
- Decor that makes a busy server slow on phones (see Performance).
- Decor that matters more than running the shop: it is a small part of the rating, and a little of it fills that part.
- Looks that hurt readability: shelves, price tags and cards must stay easy to see in every look.

## What the player sees

### The Decor tab

The Shop menu's Decor tab (today "Decor is coming soon!") shows two sections, top to bottom:

1. **Looks**: a horizontal row of six look tiles. Each tile: a picture of the look (a swatch of its floor, wall
   pattern and trim, or a small render), its name, and a button:
   - "Using" (disabled) on the current look;
   - "Use" on an owned look;
   - the price (green, red if you can't afford it) on an unowned unlocked look;
   - grey "Lv N" while locked. Pressing a locked look shows the Blocked card with the level, like every other lock.

   Buying a look applies it at once. Using an owned look is free.
2. **Pieces**: the usual grid of shelf-style tiles (3D picture of the model, name, price button, "Lv N" when locked),
   because pieces are Shelves catalogue entries with `category = "Decor"`. Buying places the ghost as for any shelf.

### Shop looks

A look dresses the inside of the shop only:
- the floor's colour and material;
- the three inner walls: a liner just inside each wall (the back one is today's FeatureWall) with a tiling wallpaper
  pattern;
- a lower panel band (wainscot) along the three walls;
- a thin glowing trim strip on top of the band.

Some looks add one extra: Neon Arcade a second glow strip near the ceiling, Crystal Cave crystal clusters along the
wall bottoms. The ceiling, lights, front glass and outside are untouched. Visitors see the owner's look.

| Look | Price | Level | Floor | Walls (wallpaper) | Band / trim | Extra |
|---|---|---|---|---|---|---|
| Cozy Wood | free (every shop's default) | 1 | oak planks | warm cream, a soft woodgrain-and-leaf pattern | wood panelling / warm gold | - |
| Candy Pastel | $500 | 3 | pink | mint with sprinkles and little stars | white / pink | - |
| Enchanted Forest | $1,000 | 5 | moss | leaf green with leaves and flowers | dark wood / pale gold | - |
| Neon Arcade | $2,000 | 8 | dark indigo | deep purple with neon grid lines | near-black / cyan | pink strip near the ceiling |
| Crystal Cave | $3,500 | 12 | slate | violet with crystal facets | dark slate / lilac | crystal clusters along the walls |
| Starry Night | $5,000 | 16 | navy marble | night sky with stars and a moon or two | dark navy / gold | - |

Colours start from the mockups; the wallpapers are seamless patterns made with Figma's image generator, uploaded as
images and laid on the liners as `Texture`s. Each pattern stays soft and low-contrast behind the shelves.

### Pieces

Each piece is a `Config/Shelves` entry: `kind = "Decor"`, `category = "Decor"`, `capacity = 0`, a `prop` model slot,
and a new field `decor` (its rating points). Sizes follow the 2-stud grid.

| Piece | Footprint (studs) | Price | Level | Points | Notes |
|---|---|---|---|---|---|
| Potted Plant | 2 x 2 | $80 | 1 | 1 | |
| Star Rug | 6 x 6 | $150 | 1 | 1 | flat; walk over it (no collision) |
| Floor Lamp | 2 x 2 | $120 | 2 | 1 | a small warm light (no shadows) |
| Beanbag | 4 x 4 | $200 | 2 | 1 | |
| Balloon Bunch | 2 x 2 | $250 | 3 | 1 | |
| Gumball Machine | 2 x 2 | $400 | 4 | 2 | |
| Element Pennants | 6 x 2 | $500 | 5 | 2 | five flags in the element colours |
| Fish Tank | 4 x 2 | $900 | 7 | 2 | |
| Arcade Cabinet | 4 x 2 | $1,200 | 9 | 2 | its screen glows |
| Pish & Chikin Standee | 4 x 2 | $1,500 | 10 | 3 | the two dogs holding a card |
| Card Pedestal | 2 x 2 | $2,500 | 13 | 3 | the card back floats over it and turns slowly |
| Giant Pack Statue | 4 x 4 | $4,000 | 18 | 3 | |

Pieces are placed, moved, rotated and sold (half price back) exactly like shelves. Up to **20 pieces** per shop
(`Placement.MAX_DECOR_PER_PLOT`), counted apart from the 30-shelf cap. At the cap, buying another goes through
`Util/Blocked` with the reason. Customers path around pieces as they do around shelves (NpcMotion uses
PathfindingService); the rug doesn't block them.

Changed after the owner tried it (2026-11-14): "some of the decors doesnt make sense, like the fish tank. how can
player get fishes". Pieces that make a player ask how to use or fill them were swapped for card shop things, each
keeping its price, level and points: the Fish Tank became the **Play Table** (a play mat with cards, two stools; 4 x 4),
the Gumball Machine the **Booster Box Tower** (stacked booster boxes, a glowing star; 2 x 2), the Arcade Cabinet the
**Card Frame** (a giant framed card painting on an easel; 4 x 2).

## The rating

- `Config/Customers RATING.parts.decor` goes from 0 to **0.10**; the other weights stay as they are (the rating is a
  weighted mean, so decor is about 9% of it).
- Decor score = `min(1, points / FULL)` with **FULL = 8** points: a look other than Cozy Wood gives **2** points,
  each placed piece its `decor` value. So a bought look plus four or five pieces fills it, or eight cheap pieces.
- This lowers an undecorated shop's rating slightly (a perfect shop with no decor: about 4.6 stars). That is the
  intended nudge. The rating window already shows the decor line ("A cosy shop" / "Decorate your shop").

## Saved data

- New field `decor = { look = "CozyWood", owned = {} }`: the look in use and the looks bought (Cozy Wood is always
  owned and never stored). Bump `SCHEMA_VERSION` 24 -> 25 with a migration that adds the default, and a Lune test.
  DESIGN.md 10.4 updated.
- Placed pieces live in the existing `layout` like shelves; no new shape.
- On load: an unknown look id falls back to Cozy Wood; unknown owned ids are dropped; an in-use look not owned falls
  back to Cozy Wood. Pieces whose id no longer exists are handled the way unknown shelves are today. A layout over the
  piece cap after a config change keeps its first 20 and refunds the rest at full price (never silently lost).

## Server rules

- Remote `ShopLook` (client -> server: `action: "buy" | "use"`, `lookId: string`), defined in `Remotes.luau`,
  validated (types, a known id, unlocked level, owned for "use", not owned for "buy"), rate-limited, cash through
  EconomyService only, the price read from config (never the client). Every refusal goes through `Util/Blocked`.
  No distance check: looks are bought from the menu anywhere in town; the shop changes either way.
- `PlotService` builds the look's liners, band, trim, wallpaper and extras inside the owner's shop when the shop
  loads and on every change, under one folder it replaces. The placement grid is unchanged (liners sit inside the
  walls' outer layer, not on the floor). When the shop is released (the owner leaves), the plot goes back to today's
  empty-plot look.
- The owner's client learns the look in use and the looks owned (attributes on the player or a state event, the
  builder's call) to draw the Looks row.
- Pieces go through PlacementService like shelves; a `Decor` kind holds nothing (like trophies), has its own cap,
  and is skipped by everything that treats shelves as stock or cards (customers, restocking, rating's stocked part,
  jobs).
- RatingService fills the decor part from the shop's look and pieces.

## Models

- The twelve pieces are built in Blender by `tools/blender/build_decor_props.py` in the stylized chunky cartoon
  style of the concept sheet, exported as ONE pack FBX the owner imports once and saves as
  `assets/props-import/DecorProps.rbxm`, split by `lune run tools/props/split_pack` into `assets/props/<Name>.rbxm`
  (docs/props.md gets a "Decor props" section). Until then each slot draws a part-built stand-in (`Util/Props`), so
  the system works on day one.
- Triangle budget: at most 1,500 triangles a piece (the rug and pennants far less).
- The Decor tab's piece tiles use the existing 3D tile pictures; the look tiles use a small swatch built in code from
  the look's colours and wallpaper (no new uploads beyond the wallpapers).

## Pish

A Pish lesson `decor` at level 1 (after his first visit, like the cases): he points at the Decor tab and the first
piece (`shelf = "PottedPlant"`), through the existing `Config/Pish LESSONS` / `LessonRules.forShelf`.

## Performance

- Liners, band and trim are a handful of parts and up to four textures per shop.
- Lamps: one small `PointLight` each, `Shadows = false`, short range.
- Check a full server's worst case (six shops, each at the 20-piece cap, mixed pieces) with the Studio perf tools
  (`rbx-perf-profiling`). If it costs too much on a phone, lower the cap rather than ship it heavy.

## Studio and tests

- Dev command `/decor <look id>` (that look as if owned and in use) and `/decor pieces` (one of every piece in your
  shop's free cells, as many as fit), plus the admin panel's "Decor" section with a button per look.
- Lune tests for the pure rules: the decor score (look points, piece points, the cap at FULL), the look buy/use checks,
  the load clean-up (unknown looks, the in-use look not owned, too many pieces), the migration, and the config (every
  piece's footprint on the grid, a prop slot, points and price; every look's wallpaper id and colours).

## Left to the builder

- The look tile picture's exact layout and the swatch drawing.
- Exact colours and wallpaper prompts (starting from the mockups and the table above).
- How pieces' stand-ins are built (parts, simple shapes).
- Where in the code the shared rules live, following the project's pure-module pattern.

## My calls (not discussed with the owner)

- Cozy Wood becomes every shop's default inside, replacing today's plain walls (a panel band and trim added).
- A look gives 2 points; FULL is 8; decor weight 0.10.
- Lamps get a real light; the Card Pedestal's card turns; nothing else moves.
- The cap at 20 is separate from shelves.
- A Pish lesson for decor at level 1.
