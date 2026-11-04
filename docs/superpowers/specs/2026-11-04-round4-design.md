# Round 4: covers, windows, sounds, loading, shop levels to 100 and the level-up pillar

Owner's notes 2026-11-04, picked from the mockups `round4.html`, `round4b.html` and `round4c.html` (visual companion,
`.superpowers/brainstorm/13775-1793692558/content/`). Branch `hud-creature-pals` (continue; nothing merged or
pushed until the owner says).

## Intent

The game plays end to end; this round polishes what players meet first, and makes shop levels feel rewarding.
The owner, in their words:

- Players should feel the satisfaction of always levelling up, but stats stay as they are: only the numbers change,
  and the unlocks get spread across the new levels.
- Binder covers shouldn't spoil the creatures: "I want them to discover the creatures."
- Windows still looking old or cluttered (Card Condenser, Order Stock) get the cotton candy style the rest has.
- Nothing should pop in late after the loading screen: "make sure all of the necessary things are loaded before
  removing the loading screens."

## Goals (what gets built)

1. **Binder set covers** with new creature-free paintings (First Spark and Frontier) and a candy logo.
2. **Binder card hover**: snappy but smooth, with no border.
3. **Card Condenser**: layout A, "Tidy two panes".
4. **Order Stock**: layout A, "Slim rows, price on the button".
5. **Summon and unsummon sounds** replaced.
6. **Loading screen** waits for everything a first window needs (product models, icons, pack fronts, covers, level-up
   effect textures).
7. **Party portraits**: the level number on a portrait's chip counts up as the XP sparks land.
8. **Shop levels go to 100** on a gentler curve. Today's unlocks keep about the same XP, and each level up gives a
   small reward.
9. **Level-up effect**:
   - When the shop levels up: a light pillar and a spinning rune circle on the player.
   - Every 10th level the pillar is a rainbow and gives a pack.
   - When a creature levels up: a smaller pillar in its element colour.
   - Sounds go with it, with options the owner can choose between in game.

## Non-goals

- Typing a price in the Prices window (owner: "No for now").
- The Bag hiding the HUD (owner: "bag is fine for now").
- Changing creature levels. Their 1-30 cap, the fight stats, boss balance and card values are untouched; the owner
  confirmed "only the shop".
- **The combat UI.** "dont touch the combat UI's": fight HUD, victory and defeat screens, combat buttons.
- Footstep sounds, the Frontier redesign, round 3's deferred minors (later rounds).
- Tuning the late-game levelling pace beyond the curve below. That gets measured in play later.

## Anti-goals (a failure even if it works)

- A cover that shows any creature, silhouette or card.
- Anything cut off or clipped in the Condenser, including when a button grows on hover.
- The loading screen lifting while the Prices or Order Stock pictures are still grey.
- A level-up effect so busy it hides the player. The owner removed the rays, the confetti and the ground shockwave
  ring: "pillar and spinning circle is enough."
- Rewards or levels decided on the client.

## Constraints

These come from CLAUDE.md and stay binding.

**Server and data**
- Server authoritative.
- Cash and XP change only through EconomyService.
- Packs roll only on the server.
- Every remote is defined in `Remotes.luau`, validated and rate-limited.

**Numbers, logic and tests**
- Tunable numbers live in `src/shared/Config`. Numbers a test reads go in plain-data configs (Lune can't build
  Color3).
- Pure logic goes in Roblox-free modules with Lune tests, registered in `tests/run.luau`. Write the test first.

**UI**
- Windows use the cotton candy kit (`UIKit.panel`, `UIKit.colorsFor`, soft buttons).
- Tap targets are at least 48 px. Check in landscape phone layout (Device emulator, e.g. `samsung_galaxy_a06`).
- Text is plain ASCII plus `·` and emoji. Glyphs like ★ and → draw as empty boxes, so use the `Star` and `Next`
  icons from `Config/UIIcons`.

**Assets**
- Sounds: Roblox-licensed only (ProSoundEffects / APMOfficial).
- Art: paintings come from Figma's image generator; effect textures are rendered in Blender (via the Blender MCP)
  with the same pipeline as the pack-opening effects. Both are uploaded as images and are not synced by Rojo.
- Blend files: delete raw `*_Src` objects and purge orphans before saving. Check that the scene's
  `blendermcp_*key*` / `*secret*` fields are empty (print lengths only) before committing.

**Workflow and docs**
- Studio MCP: reading is fine; ask before changing the place itself. Scripts live only in the repo.
- Keep DESIGN.md, CLAUDE.md, memory and the Obsidian vault in sync with what changes.

## 1. Binder set covers

**Paintings** (Figma, 848 x 1264). The downloaded copies are in the mockup folder above.
- First Spark: `cover-FS-orbs.jpg`, the owner's pick B "Five elements". A radiant golden spark in a dawn sky, with
  five element orbs (Ember, Tide, Bloom, Volt, Shade) circling it over a flowery hilltop.
- Frontier: `cover-Frontier.jpg`. A frosty ridge with glowing crystals under a purple rift and aurora.

**Processing.**
- Store the sources in a new `assets/ui/covers/` (not synced).
- Resize and upload them the way card art is (`docs/card-art.md`).
- Put the ids in Config, e.g. `Collection.SET_COVERS = { ["First Spark"] = id, Frontier = id }`. This replaces
  today's cover art: the pack's `art` for First Spark, `SET_EMBLEMS` for Frontier.

**Look** (mockup `round4c.html` section 1).
- The painting fills the cover.
- A soft dark shade sits at the top and bottom so text reads.
- A thin white inner frame line runs around the edge.
- The set name is a chunky candy logo:
  - FredokaOne with a thick white outline and a drop in a darker colour.
  - Gradient fill: First Spark butter, orange, pink. Frontier ice, sky, lilac.
  - First Spark sets on two lines ("FIRST / SPARK"); Frontier on one.
- A white pill under the logo shows the progress: `Star` icon plus "35 / 35".
- A white pill at the bottom shows the worth: "Worth $105,607".
- The old default-looking title text and the emblem go.

On First Spark the orb ring sits behind the top of the logo. Placing the logo, and darkening the shade a little
there if it doesn't read, is left to the builder.

## 2. Binder card hover

`Util/BinderDesk.highlight` currently snaps the UIScale to `HOVER_SCALE` and turns on a gold "Hover" UIStroke.

New behaviour:
- **Lift:** the card lifts over about 0.14 s with a tiny overshoot (Back out). Its shadow deepens.
- **Release:** it settles back in about 0.1 s.
- **Border:** none at all. Remove the "Hover" UIStroke rather than just turning it off.
- **Timing values:** go in `Config/BinderDesk`.
- **Rapid movement:** moving quickly across cards must never leave one stuck raised. Each card's tween replaces the
  last.

## 3. Card Condenser: tidy two panes

Mockup `round4.html` section 3, option A. Today's window is cluttered and its buttons are cut off, or get cut off on
hover. The new layout:

**Band.** Sky, with the Condenser icon, "Card Condenser" and a count ("2 ready").

**Toolbar.** One row:
- The search box ("Search name or #").
- A three-part `UIKit.segmented` switch: **All / Ready / Raising**.
  - "Ready" means it can take its next star with what it has now.
  - "Raising" means it has copies but isn't ready yet.
- Star Shards work as they do today (my call: the round changes the layout only). "Use Star Shards (7)" is the same
  opt-in toggle as now:
  - With the toggle off, Ready counts copies only, and Condense never spends shards.
  - With it on, Ready counts copies plus shards (up to today's limit), and so do the band's count and the filter.
  - Condense spends shards only when the toggle is on.
- The rarity chips are removed. The list stays sorted by rarity, then name.

**Left pane: a list of slim rows.** Each row shows:
- the card thumbnail with a rarity edge;
- the name, with a mint "Ready" tag when ready;
- a small line like "x21 · 4 copies for the next star" or "3 of 4 copies";
- a thin progress bar toward the next star.

The selected row is highlighted.

**Right pane: the selected card.**
- The card face.
- Its stars before and after (Star icons, plus "0 -> 1 star" in small text or with the `Next` icon).
- Power and Value before and after, with the after values in green.
- Which copy it keeps: "Keeps Grade S · Lv 14 · uses 4 Grade C", with a "Change" link that keeps today's
  copy-picking.
- One big butter button, "Condense +1 star".
- A small sky toggle button, "Use Star Shards (7)" (see the toolbar above).

**Fit and behaviour.**
- Everything fits inside the window on landscape phones and desktops, with room for buttons growing on hover.
  Nothing is clipped.
- The server side and its rules are unchanged (CondenserService, CondenseRules); this is layout only.

## 4. Order Stock: slim rows, price on the button

Mockup `round4.html` section 4, option A.

**Window.** Its band turns sky like the Shop's.

**Rows.** The same slim white rows as the Prices window. Each shows:
- the product picture (`Util/ProductPicture`);
- the name;
- "Box of 24", next to a small mint tag with what each unit sells for ("sells ~$3.00", the market price);
- on the right, one mint button showing the box price ("$48.00"). Tapping it orders.

**Button states.**
- Can't afford it: the button greys out and reads "Need $48".
- Locked by shop level: the button reads "Lv 11" with the `Lock` icon. Today it shows "Lv n".

The server is unchanged (StockService). It still checks the level and the price itself.

## 5. Summon and unsummon sounds

In `Config/Party.SUMMON_SOUNDS`:
- `summon` becomes the options entry "Quiet twinkle cluster": `rbxassetid://9116395089`, volume 0.1, pitch 1.
- `unsummon` becomes the options entry "Soft magic fade": `rbxassetid://9117962385`, volume 0.1, pitch 1.

Mark them "(now)" in the options lists. The `/summonsound` and `/unsummonsound` tools stay.

## 6. Loading screen: everything a first window needs

The owner saw the Prices window's pack pictures grey for a while after joining.

**Root cause first.** Find it before fixing (systematic debugging). Today's guess: the 3D pack models' meshes and
SurfaceAppearance maps are still downloading when the ViewportFrames draw, and `ProductPicture`'s re-parent trick can
run before the maps arrive. Confirm or correct this in Studio.

**What the loading screen waits for**, on top of today's steps (character, save, card art, creature, fight gear):
- The `PackModels` models: pack, deck box and display box, every look, with their meshes and SurfaceAppearance
  textures.
- Every `Config/UIIcons` image.
- The pack fronts (`Config/Packs` art).
- The HUD mascot stickers.
- Both cover paintings.
- The level-up effect textures (section 9).

**How.**
- Images are kept drawn until `IsLoaded`, like the card art today.
- Models are preloaded with `ContentProvider:PreloadAsync`, and the pictures redraw once loaded.
- Add one step, with its text in `Config/LoadingScreen.STEPS` (e.g. "Stocking the shelves..."), and give its share
  through `Util/LoadingRules` (Lune-tested).
- `MAX_SECONDS` (30) still lifts the screen anyway, so nobody gets stuck.

**Acceptance.** In a fresh Studio Play, right after the screen lifts, Prices and Order Stock show every picture fully
textured. Measure the extra load time and report it.

## 7. Party portraits: the level counts up

When a creature's XP sparks land on its portrait (`PartyBarController.ShowXpGains`, round 3), its level chip rolls
from the old level to the new, e.g. "Lv 19" to "Lv 20":
- It uses an eased count like `XpPill.countUp`, over about 0.4 s, with the existing bump.
- The chip keeps showing the old level until the sparks land, even if the new party data arrived first.
- Without sparks (jobs, the XP Tonic, boss fights), the chip updates as today.

## 8. Shop levels 1 to 100

### The curve

The total XP to reach level n (n >= 2) is `BASE_XP · (n − 1) ^ POWER`, rounded to `ROUND_TO`:
- `BASE_XP = 40`, `ROUND_TO = 10`.
- `POWER` is about 2.31, chosen so that Lv 20 is about 36,000 XP, today's Lv 10, where shop jobs open.

The level is capped at `MAX_LEVEL = 100`, which needs about 1.63M XP (about what Lv 30 needs today).

These replace `XP_REQUIRED`, `XP_GROWTH` and `LEVEL_LIMIT` in `Config/Levels`. `Util/LevelMath` stays pure and is
Lune-tested:
- levels are monotonic and each step is bigger than the last;
- Lv 2 = 40;
- Lv 20 is within 1% of 36,000;
- Lv 100 is the cap;
- `getProgress` at the cap returns span 0, so the HUD's XP pill shows "MAX" (`XpPill` already does).
- XP keeps counting past the cap; the level doesn't.

**Pace at the start.** A packs-only shop earns about 30 XP a minute (5.2 customers/min · 2 items · 95% · $3).
Measured from the first sale:

| Level | Total XP | Time (min) |
|---|---|---|
| Lv 2 | 40 | 1.4 |
| Lv 3 | 200 | 7 |
| Lv 4 | 510 | 17 |
| Lv 5 | 980 | 33 |

Today Lv 2 takes 5 min and Lv 4 takes 40 min. Nothing unlocks at Lv 2: it gives the pillar and the cash reward.

### Unlocks move to the level whose XP is nearest today's

| Unlock | Today | New |
|---|---|---|
| Card Sleeves (Products) | 2 | 3 |
| Wall Shelf (Shelves) | 3 | 4 |
| Card Condenser (Shelves) | 4 | 5 |
| Accessory Hook (Shelves), Deck Box (Products) | 5 | 7 |
| Big Display Rack (Shelves) | 6 | 9 |
| First Spark Booster Box (Products) | 7 | 11 |
| Grading Station (Shelves) | 8 | 14 |
| Shop jobs (`Jobs.UNLOCK_LEVEL`) | 10 | 20 |
| Starter sword (`Swords.UNLOCK_SHOP_LEVEL`, with boss 1) | 3 | 4 |
| Bosses 1-7 (`Bosses[*].shopLevel`) | 3, 5, 8, 12, 15, 18, 22 | 4, 7, 14, 26, 34, 43, 57 |

DESIGN.md 7.2 also lists Expansion 1 (Lv 5), Expansion 2 (Lv 9) and Set 2 (Lv 10). They aren't built yet, so they
only change in the table: 7, 17 and 20.

The PvP bet cap is `Pvp.CAP_PER_LEVEL · lower level` and doubles with the new numbers. Halve it to 25 (my call).

Every text that names a level reads its config, so nothing else changes:
- "Unlocks at shop level n"
- the Build, Order and Jobs windows
- the boss board

### Rewards (server, EconomyService)

- **Cash every level:** `REWARD_CASH_PER_LEVEL · level` (my call: 10, so $20 at Lv 2 and $1,000 at Lv 100).
- **A pack every 10th level** (`PACK_EVERY = 10`; Lv 10, 20 ... 100):
  - It's a new Bag item, a First Spark pack. Its id, for example `sparkPack`, is left to the builder.
  - The Bag gets an "Open" button for it.
  - A new validated, rate-limited remote has the server take one item and open a normal First Spark roll (with
    pity and the `packsOpened` stat) through PackService.
  - The opening plays the existing pack opening.
- **Skipped levels:** a sale that crosses several levels gives every level's reward, but plays one effect for the
  final level. The badge rolls from the old level to the new.
- **The toast:** today's "Level n! Unlocked: ..." toast stays and adds the reward ("+$70", "+1 pack").

### Existing saves

The level is already derived from XP on load, so no migration is needed. A saved Lv 10 shop loads as Lv 20 with the
same unlocks. Levels gained this way give no rewards and no effect, because the game isn't released yet (my call).

### HUD

The Level pill fits three digits ("100").

## 9. The level-up effect

Mockup `round4c.html` section 2: the trimmed "C+" version; the creature version as shown there.

### On the player (shop level up)

Timing from the start, about 3 s in all:
1. **0.0 s:** a gold rune circle spins open flat on the ground under the player.
2. **About 0.4 s:** a light pillar shoots up around them. It has a white-hot core inside a soft coloured glow, with
   sparkle motes rising inside it, and the player lights up for a moment.
3. **About 1.0 s:** above the head, a gold star badge pops with the number rolling from the old level to the new,
   and a candy "LEVEL UP!" pops under it.
4. **1.5 to 3 s:** the beam thins away and the circle fades.

Not included: rays, confetti, the ground shockwave ring.

### Every 10th level

The same effect, but:
- the pillar runs pink, butter, mint, sky and lilac up its height;
- the circle is two-toned;
- a small pack picture flies out with "+1 pack".

### On a creature

The creature version is unchanged from the mockup: a smaller pillar and circle in its element's colour (BabyColors
`ELEMENTS`: Ember peach, Tide sky, Bloom mint, Volt butter, Shade lilac), sparkle motes and a chip "Lv 19 -> 20" over
it.

- **Where it plays:**
  - on the creature's model in the world, if there is one (the summoned creature, or a shop worker);
  - when there's no model, only the portrait roll from section 7.
- **When it plays:**
  - For the owner, after a won monster fight, it starts when that creature's sparks land, together with the portrait
    roll.
  - With no sparks, it starts at once.
- **The event:** creature levels change only in `CardService.AddXP`; the event comes from there.

### Seen and heard by others

- The server tells every client about a level up: who, what (shop or creature), which creature and the levels, with
  a new server-to-client remote.
- Clients near enough play it, using a range in Config like `SUMMON_SOUNDS.range` (60).
- Others hear it quieter, as 3D sound at the character.
- The owner always sees their own.

### Never during a fight (my call)

Customers and the Cashier job keep earning while the owner fights, so shop level-ups will often land mid-fight.
The game teaches "dodge when the ground glows", so a gold circle under the player could be mistaken for an attack.

- While the player is in a fight (a Wild fight, a boss fight, PvP or the Dungeon), their level-up effect and its
  sounds wait.
- They play once the fight is over, back in the world.
- Rewards and the toast are not delayed.
- Several level-ups that wait merge into one effect for the latest level, with the badge rolling from the level
  before the first.
- The same rule holds for what other players see. Where the wait lives (server or clients) is left to the builder.

### Art

These are rendered in Blender by a new `tools/blender/build_levelup_fx.py`, in the same pipeline as
`build_pack_fx.py` and `tools/textures/make_flipbooks.py`. Sources go in `assets/blender/LevelUpFx/` and PNGs in
`assets/ui/fx-levelup/`. They're uploaded as images, with ids in a new `Config/LevelUpFx` (plain data).

- **Rune circle:** white, so it can be tinted.
- **Beam:** a vertical gradient with soft edges, white.
- **Mote:** a sparkle (the existing GLOW image may do).

Particle textures must be square. A beam runs a texture's height along its length.

How the 3D parts are built is left to the builder: Beams between attachments, a flat spinning decal or part, a
ParticleEmitter, a BillboardGui for the badge and text, a short PointLight or Highlight for the glow. The budget is
that the full effect runs at 60 fps in the town on the reference PC.

### Sounds

Four moments, each with three Roblox-licensed candidates (ProSoundEffects / APMOfficial) for the owner to try in
game, like the summon sounds. They go in `Config/LevelUpFx` with `options`.

| Moment | When | Sound |
|---|---|---|
| Rise | the circle opens | a magic whoosh |
| Beam | the pillar hits | a soft boom with a shimmer |
| Chime | the badge pops | a bright bell |
| Fanfare | 10th levels only | a short fanfare |

- **Creatures:** the rise and the chime, quieter and pitched up (my call).
- **Ambience:** level-up sounds play over the town music and ambience without ducking them.

## 10. Studio tools

- `/levelfx [level]`: plays the shop effect on you without changing your level. A multiple of 10 plays the rainbow
  version.
- `/beastlevelfx`: plays the creature effect on your summoned creature.
- `/levelsound <rise|beam|chime|fanfare> <n> [volume]`: uses option n for that moment until "0".
- Admin panel buttons for all three (`Config/AdminPanel`).
- `/level <n>` stays.

## Left to the builder

- Component structure, file split and names not fixed above.
- Exact tween timings within the stated feel.
- The cover logo's placement over the orb ring.
- How the 3D effect is assembled (within the 60 fps budget).
- Which licensed sounds become the three options for each moment.
- The Bag item's id and icon.
- How the Condenser's "Change" link opens copy picking (keep today's behaviour).
- Order of work.

## Verification

- `lune run tests/run` is green, with new or changed tests for LevelMath, the unlock remap (each remapped
  unlock sits at the new level whose XP is nearest its XP today, as in the table: Card Sleeves at Lv 3, 200 XP
  against 150 today, is the furthest off), the rewards (cash per level, a pack on multiples of 10, skipped levels
  each rewarded), LoadingRules' new step, the cover config, and the sound options.
- `rojo build` succeeds.
- In Studio Play, through the MCP, with screenshots:
  - the covers;
  - the hover (no border, no stuck card);
  - the Condenser and Order Stock at desktop size and in the phone emulator, with nothing clipped;
  - the Prices pictures right after loading;
  - `/levelfx 7` and `/levelfx 10`;
  - a creature level up;
  - summon and unsummon.
- Frame time measured during the effect in town.
- The owner then judges in Studio: the cover, the hover feel, both windows, the pillar and its sounds (picking the
  options), and the early level pace.

## DESIGN.md updates

- 7.2: the new table, the curve, rewards, the cap, bosses and the sword.
- The binder covers.
- The Condenser and Order Stock layouts.
- The loading steps.
- The level-up effect and its tools.
- The new Bag item and remote.
- The sounds.
- CLAUDE.md's dev command list gets the new commands.
