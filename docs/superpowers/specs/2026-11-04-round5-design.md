# Round 5: calm hovers, card view, Assign job, Boss Ladder, sharp pack pictures, quieter level-ups

Owner's notes 2026-11-04 after round 4, picked from the mockup `round5.html` (visual companion,
`.superpowers/brainstorm/13775-1793692558/content/`): **1 A, 2 A, 3 A, 4 A, 5 A**. Branch `hud-creature-pals`
(continue; nothing merged or pushed until the owner says).

## Intent

Round 4 made the windows prettier. Using them, the owner found the motion and a few screens tiring:

- Shop buttons have "too much animations"; the motion should feel "premium/cute/smooth/simple".
- In the Card Condenser the row text "increase sizes for split second and then goes back to normal it looks awkward".
- On the Boss Ladder "when you hover a boss other bosses move too". The whole window "needs to be reworked".
- The card view could be better ("suggest a better UI than what we have now"). The job picker should say
  "Assign job", show icons and make Cancel the warning colour.
- The pack and deck box pictures in Order Stock and Prices look low quality, and some are cut off.
- Level-up sounds are "too loud, too much. change it or make me choose".
- The town music is still too quiet.
- The binder tooltip should sit by the card you're hovering, not off at the binder's edge.

Root causes found while preparing the mockups:

- Every soft button, row, tile and slot in a window grows under the mouse with a bouncy (overshooting) ease
  (`Util/Motion.hover` through `UIKit` `noGreyHover`).
  - Growing text snaps up a font size for a moment: the Condenser pop.
  - A growing item inside a list or row layout takes more room, so its neighbours move: the Boss Ladder push.
  - A button inside a tile grows on top of its tile growing: the busy Shop.
- The pack and deck box pictures are live 3D models in 38 x 56 px ViewportFrames (`Util/ProductPicture`). That
  makes them soft, and the framing clips their top and bottom.
- A level-up plays four sounds stacked: rise, beam, chime and fanfare.

## Goals (what gets built)

1. **Hover and press, look A ("Soft glow")**: nothing changes size under the mouse. Buttons glow, rows and tiles get
   a soft lilac edge, and a press is a small quick squish with no bounce.
2. **Binder tooltip** beside the hovered card.
3. **Card view, layout A ("This copy first")**.
4. **Assign job, layout A ("Two big tiles")**.
5. **Boss Ladder, layout A ("List and detail, like the Condenser")**.
6. **Order Stock and Prices pictures, option A**: a sharp picture of the real pack and deck box.
7. **Level-up sounds**: one soft sound, three sets to choose from in game.
8. **Town music** louder.

## Non-goals

- **The combat UI.** "dont touch the combat UI's": fight HUD, victory and defeat screens, combat buttons.
- **The binder's card hover** (round 4: "snappy, no border", approved). It stays as it is.
- **The HUD tiles' own squish** (`Util/Hud`), the party bar Party button's hover hop, and the HUD's look. My call:
  the owner's notes name windows, not the HUD. Only the Party button's press changes (section 1).
- The Frontier redesign, footstep sounds, and round 4's other deferred minors.
- The level-up pillar's look, its timing, and when it is held back.

## Anti-goals (a failure even if it works)

- Anything moving, growing or jumping when the mouse passes over it in a window (neighbours shifting, text
  changing size).
- A hover hiding a row's selection: the chosen row's gold ring must still show under the mouse.
- The Boss Ladder losing anything it shows today: requirements, tricks, drops and odds, chests, loot timer, soft
  cap, the travel button and the hints.
- The card view needing more taps for anything it does today.
- A pack or deck box picture that is blurry, clipped or touching its row's edge.
- A level-up that is louder than the town around it, or plays more than two sounds.

## Constraints

Round 4's constraints still bind (see `2026-11-04-round4-design.md`, Constraints):

- **Server and data:** the server is authoritative, and every remote is validated and rate-limited.
- **Code:** numbers go in `src/shared/Config`. Pure logic goes in Roblox-free modules with a Lune test written first.
- **UI:** use the cotton candy kit, and tap targets are at least 48 px. Check every screen in the landscape phone
  emulator. UI text is ASCII plus `·` and emoji only, so stars and arrows are icons, never glyphs.
- **Sounds:** Roblox-licensed only (ProSoundEffects / APMOfficial).
- **Blend files:** delete raw `*_Src` objects and purge orphans before saving. Check that the `blendermcp_*key*` /
  `*secret*` fields are empty (print lengths only) before committing.
- **Studio MCP:** ask before changing the place.
- **Docs:** keep DESIGN.md, CLAUDE.md, memory and the Obsidian vault in sync.

Also:

- **No size or position animation on hover.** Hover may change colour, transparency, glow and stroke only.
- **Hover never writes properties a controller owns.** That means a button's `BackgroundColor3`, its text colour,
  and a row's own outline (it marks the selection). A hover effect lives in its own child objects, so a controller
  recolouring a button mid-hover is never undone when the mouse leaves.

## 1. Hover and press (look A, "Soft glow")

What the owner felt in the mockup's live demo, at about 0.15 s in and a little faster out, eased out with no
overshoot:

- **Soft buttons** are `UIKit.button`, `iconButton` and the like in a themed window or in the binder. On hover:
  - Their own-colour glow (the `Glow` image `UIKit.glow` puts under them) brightens and spreads a few px.
  - Their colour lifts a touch, for example with a faint white sheen (at most about 10 % white, so text stays as
    it is).
- **Rows, tiles, slots and other buttons in a window** are the ones `UIKit.creamWindow` softens. On hover:
  - They get a soft lilac edge, about RGB 217 194 242, with a faint lilac glow and a very light tint.
  - A row that is chosen (gold ring) keeps its ring visible. The hover sits outside or under it, never over it.
- **Press** applies to soft buttons and the party bar's Party button, which use the squishy press today:
  - A quick squish to about 0.96 and back, with no bounce past full size.
  - The deeper 0.9 dip and its 1.05 overshoot go.
- **Touch:** there is still no hover, and presses are as above.
- All of it is in one place: `Util/Motion` (hover and press) and `UIKit` (`noGreyHover`, `softButton`). The numbers
  go in `Config/UIMotion` and `Config/BabyColors`. Remove `hoverScale` and `rowHoverScale` along with the scale
  hover.
- This fixes the Condenser pop and the Boss Ladder push at the root. No per-window patches.
- **Old hovers go** (my call). `CardBuyController` (its rows) and `ShowcaseController` (`addHover`) tint rows by
  writing `BackgroundColor3`, which breaks the rule above and would stack on the lilac edge. Remove them.
- **What doesn't light up** (my call): fully transparent click areas, and buttons drawn in the disabled (`Locked`)
  colour.

## 2. Binder tooltip

- It opens **beside the hovered pocket**, the same for a mouse hover and a held finger on phones:
  - Right of the pocket with `TOOLTIP_GAP` if it fits on screen, else left of it.
  - If neither fits, above or under it.
  - It never covers the hovered card. It may cover the neighbouring pockets.
- `UiLayout.beside` already does this placement given an anchor rect. The anchor becomes the pocket rect, not the
  binder's. Pin the pocket-anchored cases with a Lune test.

## 3. Card view (layout A, "This copy first")

The card face on the left and the Flip button stay as they are. The right panel, top to bottom:

1. **Header**: the name and the worth range pill, unchanged. Phones keep today's slimmer header.
2. **Pills row**: rarity, element, number, copies. Unchanged, and still hidden on phones as today.
3. **"THIS COPY" box** with a gold outline. It is today's chosen-copy box moved to the top and given a top line:
   - The top line: a small "THIS COPY" heading, the grade pill, the level, the stars, a FOIL tag if foil, and this
     copy's worth on the right.
   - The four stat tiles (Power, HP, Attack, Speed).
   - The XP bar and the next-star bar.
   - The busy line ("Working: Cashier" / "In your party"), as today. Phones still hide it.
4. **"ALL COPIES, BEST FIRST"** heading and today's copies list. It holds every copy, with the gold ring on the
   chosen one and the BEST tag on the best, and fills the remaining height and scrolls.
   - My call: the list keeps the chosen copy too, so it is never missing from the list you pick from.
5. **Buttons**: "Add to party" and **"Assign job"** (renamed from "Give a job"). Their busy and locked states are
   unchanged ("In party", "Working: X", "Jobs at shop Lv 20", "Slots full (1/1)").

No information is added or removed; it is reordered and grouped. On phones the copies list may show only two
rows; it scrolls.

## 4. Assign job (layout A, "Two big tiles")

It replaces the "Which job?" chooser. It opens from "Assign job" and covers the panel under its header, like the
party chooser covers it:

- **Title line**: the `Job` icon and **"Assign job"**, with "Job slots: used / total" on the right (from the
  `JobSlots` / `JobsUsed` attributes).
- **One big tile per job** in `Jobs.JOBS`, side by side:
  - The job's icon from `Jobs.JOB_INFO` (Restocker: Shelves; Cashier: Register), drawn large (about 56 px).
  - Its name and its `JOB_INFO.text`.
  - "Works: <word>": this copy's speed word from `JobRules.speedWord`, coloured by its tone, as the Jobs panel says
    it.
  - Tapping a tile assigns that job (`Remotes.AssignJob`, as today) and closes the picker.
  - Tiles take the section 1 row hover.
- **Cancel**: full width under the tiles, **pink** (`UIKit.Colors.Danger`, the warning colour of the close X), with
  the `Close` icon. It closes without assigning.
- On phones the tiles stay side by side. Their tap areas are well over 48 px.

## 5. Boss Ladder (layout A, "List and detail")

It is the same window (title, size limit, the K key and the Bosses tile), rebuilt as two panes like the Card
Condenser.

**Left: the seven bosses, top to bottom** (ladder order 1 to 7), one row each:

- The disc with the boss's icon, its ring in the step colour as today: gold beaten, green ready, red too weak, grey
  locked.
- "1. Meadow Warden".
- A status chip with words (Beaten / Ready / Too weak / Locked).
- The first boss still to beat also wears today's "Next" tag.
- The chosen row has the gold ring. Rows take the section 1 hover, and nothing moves.
- The status chips replace today's legend (the key), which goes.
- Today's gold climb path goes with the horizontal row. My call: add a thin vertical line behind the discs only if
  the list looks bare.
- On phones the chips give way to the ring colour and today's small badges, and every row is at least 48 px tall.
- The list scrolls if it doesn't fit.

**Right: the chosen boss.** Everything today's two columns show, regrouped:

- **Banner** across the top in the boss's colour (`BossTints.key`):
  - A big disc with its icon, its name, its title and its status chip.
  - Text colour chosen so it reads on that fill (`tests/ContrastRules`). The fills are Color3s in `Cards.ELEMENTS`,
    which Lune can't load, so the test reads a plain RGB copy of them.
- **Pills** under it: element (or "???" / "All elements"), where it lives, "Bring X". Same rules and tooltips as
  today.
- **Two columns**, each scrolling when needed:
  - "TO FIGHT IT": the checklist (shop level, key fragments, Power with its bar), then "WATCH OUT" with its tricks
    or the "???" surprise.
  - "REWARDS": the loot timer pill, each win's drops with their current odds, the First win and First win today
    chests (or "collected"), cash and XP every win, full drops left today, and the over-power line.
- **Footer**, always visible:
  - The next-step words in their colour (beaten / ready / too weak / reach level / collect keys).
  - Their action button where today has one ("Party", "See it").
  - The travel button ("Take me there" / "Go home") or, where you can't travel from here, the hint ("Enter the
    Dungeon portal in the Frontier." and the like).

Opening it selects the same boss as today (`defaultStep`). The live loot timer keeps ticking in the pill.

## 6. Order Stock and Prices pictures (option A)

- Packs and deck boxes show a **sharp picture of the real model**: the same First Spark pack and deck box as on the
  shelves, turned a little as today.
  - They are rendered once as transparent PNGs, at least 256 px tall, and uploaded as images. Their ids go in a
    config, per pack look and kind.
  - They are drawn as an image fitted inside the picture area with a margin, so nothing touches or crosses the row's
    edge.
- **Fallback:** a pack look with no picture yet shows the drawn icon (`BoosterPack` / `DeckBox`).
- **The 3D path goes:** `ProductPicture`'s ViewportFrame, its redraw helpers, and `redrawAll`'s caller in the
  loading screen.
  - The loading screen's shop step preloads the new pictures.
  - It keeps preloading `PackModels`, because the shelves and the opening stage still use them.
- **Rendering method:** the builder's choice, between a Blender render of the models
  (`assets/blender/Pack/`, `build_pack.py`, `build_deckbox.py`) and a large Studio ViewportFrame capture cut out
  against a key colour. The PNGs are kept in the repo under `assets/ui/`. Don't touch the owner's open Blender scene
  unsaved: render in a separate background Blender, or ask.

## 7. Level-up sounds

- **One sound per level-up** (shop or creature) in place of the four stacked. It plays when the badge pops:
  - Every 10th shop level adds one short sting.
  - Volumes are about half of today's loudest: the normal sound around 0.07, the sting around 0.12. They are tuned
    in play.
- **Three sets** to choose from. A set is a normal sound plus a sting, taken from the licensed PSE / APM sounds
  already vetted in `Config/LevelUpFx` options, or close relatives. The defaults below are my call; the owner picks
  the set they like:
  1. Soft sparkle ping (PSE "Synth Sparkle Tone High Pitch Tone Burst Ping 4", `9126076030`) with the "All It
     Takes" sting (`9047103106`).
  2. Bright bell ding (PSE "... Bell Tone Ding 4", `9126073001`, pitch 1.1) with the same sting.
  3. Twirling chime (PSE "Magic Twirling Small High Pitch Spinning Chime 1", `9125644676`) with the "Spinning
     Around" link (`1839881844`) at low volume.
- **Choosing:**
  - The Admin panel gets "Level sound 1 / 2 / 3", and `/levelsound <1-3> [volume]` does the same (the optional
    volume is for tuning in play). Picking a set plays it once.
  - Studio only, like today's picks. The chosen set is the default in config once the owner names it.
- **Creatures:** a creature plays the set's normal sound, quieter and higher (today's `creature` scale and pitch).
- The sounds are preloaded with the level-up images, closing round 4's deferred "level-up sounds not preloaded".
- The rise / beam / chime / fanfare stack and its 12 options and `LevelSoundPick_<moment>` attributes go. Today's
  `/levelsound <moment> <n> [volume]` becomes the set pick.

## 8. Town music

- `Music.TOWN.volume` goes from 0.045 to **0.07** (about +4 dB). The limiter's threshold stays, so its ceiling rises
  by the same amount.
  - My call: on 2026-11-03 the owner asked for "never louder on the loudest part". "Still too low" now outweighs
    that.
  - `tests/MusicRules` follows the new numbers.
- The owner can try other levels with `/music 4 <volume>` (option 4 is today's track). The number they like goes in
  config.

## Left to the builder

- How the hover's glow, sheen, lilac edge and tint are built (child objects, tweens), within the constraints above.
- Exact sizes, paddings and fonts in the card view, the Assign job tiles and the Boss Ladder, following today's kit
  sizes and the mockup.
- Phone layouts for the Boss Ladder list and the card view, within the 48 px rule.
- Where the picture ids live (a new config or `Config/Packs`), the PNG folder name, and the rendering method.
- The level sound config shape and names. Whether a sting's volume is per set.
- Which pure pieces get Lune tests beyond those named here.

## Verification

- `lune run tests/run` is green, with tests written first for:
  - The pocket-anchored tooltip placement.
  - The picture fit (inside the area, with a margin).
  - The level sound sets (three sets, each with a normal sound and a sting, volumes under a cap).
  - `MusicRules` with the new volume.
  - Any new pure helper for the ladder rows or the Assign job tiles.
- `rojo build` succeeds.
- Studio checks (Play through the MCP, screenshots of each):
  - **Shop, Condenser and Boss Ladder:** move the mouse across buttons, tabs, tiles and rows. Nothing moves or
    changes size, and a chosen row's ring shows under the mouse.
  - **Card view:** desktop and the phone emulator, with a copy picked, a working copy, and a copy in the party.
  - **Assign job:** opens and assigns, Cancel is pink, and the speed words show.
  - **Boss Ladder:** desktop and phone, for a beaten, a ready, a too-weak and a locked boss. Everything from today is
    present, and the travel button still travels.
  - **Order Stock, Prices and Set Price:** sharp pictures, nothing clipped, after a cold join.
  - **Level-up:** each sound set for a shop level, a 10th level and a creature.
  - **Town music:** at 0.07.
- Then tell the owner exactly what to judge (stop, then Play).

## DESIGN.md updates

- UI motion: the soft glow hover, the calm press, and nothing growing.
- The card view's layout and "Assign job".
- The Boss Ladder window.
- Product pictures, the level-up sound sets and the music volume.
- The binder tooltip's place.
- The folder structure (picture PNGs and any new config).
- CLAUDE.md: the asset line for the product pictures, and the `/levelsound` command's new form.
