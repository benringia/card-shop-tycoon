# Loading screen: the binder, with Pish, Chikin and Turts

Owner, 2026-11-13: "Update/Redesign loading screens. Update to the new One More Pack game name. Make sure all loading
screens load necessary assets before letting the player in game. Redesign loading screen and font style to match our
core loop." Picked from mockups: the binder (direction C), with "instead of the actual cards from the game, I want it
to be Pish, Chikin, and Turts", facing you, their names on the cards. Approved mockup:
`.superpowers/brainstorm/9845-1794546987/content/loading-binder-dogs-front.html`.

## Why

The game is now called **One More Pack**. The loading screen is the first thing a player sees: it should say the name,
show the core loop (collecting cards into a binder) and the game's faces (the owner's three dogs, Pish, Chikin and
Turts), and never let anyone in before what they need is there (no models popping in, no grey ground).

## What it looks like

- Each world's own painting behind the binder, dimmed most in the middle so the binder reads (owner: "can we add
  backgrounds per world?"; mockup `loading-places-bg3.html`): town, Pish and Chikin's shop at night (the pack
  opening's backdrop, `Config/PackOpening` BACKDROP.IMAGE; the two peek out from the corners); the Wild, the First
  Spark cover's flowery valley (as the Wild screen today); the Frontier, Frostwood (`LOOKS.Frontier` BACKDROP today);
  the Dungeon, the Crystal Abyss (new, Figma-generated: floating islands, chain bridges, the crystal castle, a violet
  swirl below; `assets/ui/loading/dungeon_abyss.jpg`). One image each, fetched first; until it's in, the place's dark
  gradient shows. No cost after the screen goes (it's destroyed when it fades).
- A binder open across the middle (about 70% of the width, the world showing round it): dark leather (`Config/Collection` BOOK colours), a gold dashed stitch line inset
  round the edge, three chrome rings down the middle.
- Left page: 3 x 3 card pockets (dark, a thin lighter edge, a faint plastic glint).
- Right page: a big count "N / 9" (Bangers, the place's accent colour, a darker drop under it), the step text below
  (Montserrat Bold / Gotham Bold, white), a tip in a cream bubble (dark plum text).
- A pink ribbon across the top, over the binder's top edge: "ONE MORE PACK" (Bangers, white, dark pink drop).
- As loading goes, a card slides into the next pocket from the upper right (rotated, a little big, settling with an
  overshoot). The cards are the 9 dog cards: 3 each of Pish, Chikin and Turts, each dog posed with his own clips and
  facing you, over a game element scene, his name on a plate at the bottom (baked into the picture: no font to load).
  Each card keeps a rarity rim colour (Legendary gold, Epic purple, Very Rare teal, Rare blue).
- When all 9 are in: the step reads "Ready!" in gold, a short beat, then the screen fades.

## Goals

1. **The name.** "One More Pack" wherever players read the game's name: `Config/Game` NAME (Pish's welcome reads it),
   `Config/LoadingScreen` TITLE, `Config/Welcome` TITLE ("Welcome to One More Pack!"). Docs and comments that name the
   game (`Config/Places` comment, DESIGN.md, CLAUDE.md "Published as") follow. The Roblox experience's own name is set
   on Creator Hub by the owner.
2. **One binder screen for every loading screen**: joining each place (main game, Frontier, Dungeon), the screen
   carried through a teleport (`TeleportService` arriving gui), and the Wild portal (`WildLoadingController`, today the
   green portal swirl). One builder (`ReplicatedFirst.LoadingScreen.LoadingGui`) builds and animates it; the Wild
   controller requires it from ReplicatedFirst.
3. **Each place keeps its colour** on the accents (count, stitch line, "Ready!") and its painting behind the binder:
   town gold, Wild green, Frontier icy blue, Dungeon crystal violet; the place's name above the count outside town
   ("THE WILD", "THE FRONTIER", "THE DUNGEON", Bangers in the accent colour). The ribbon is the same pink everywhere
   (the brand). Tips stay per place.
4. **Real progress, nothing let in early.** Pockets filled follow the existing progress share (`LoadingRules.progress`
   on join, `WildLoadingRules` in the Wild): 0 to 8 while loading, the 9th only when every step is done. The screen
   stays until then:
   - Main game: character, save, card art, shop pictures and town meshes, creature, fight gear (today's steps).
   - Frontier: those plus its valley (today's step).
   - **Dungeon (new):** those plus its cavern: the area round you streamed in, ground under your feet, and
     `workspace.Dungeon`'s meshes and textures fetched.
   - Wild portal: ground, scenery, monsters, sounds (today's steps).
   - The screen's own pictures (the 9 cards) are fetched first, so a card is drawn when its pocket fills.
   - You're held still while it shows on join too (your root anchored on your own device, as the Wild screen does),
     so nobody walks off under the screen.
   - The safety caps stay (join 30 s, Wild 12 s after arriving): a very slow device goes in with what's loaded
     rather than being stuck.

## Non-goals

- No font change elsewhere in the game (the HUD and windows keep Fredoka One / Montserrat).
- No new tips or step wording beyond "Ready!" and the Dungeon's new step.
- Pish's trot sheet (`assets/ui/loading/pish_walk.png`, `tools/blender/build_pish_walk_sheet.py`) is kept for later,
  not used here.

## Anti-goals (a failure even if it works)

- Pockets filling while nothing is loading (fake progress), or a screen that never goes away.
- Dogs side-on or tiny on the cards; names unreadable on a phone.
- Anything popping in right after the screen fades.

## Constraints

- ReplicatedFirst runs before `Shared` replicates: the screen's script waits for its configs as today, and Roblox's
  own screen stays until they arrive.
- Words, ids, colours and numbers in `Config/LoadingScreen` (plain data, Lune-tested); pure rules in
  `Util/LoadingRules` (pockets from progress, each place's look) with Lune tests.
- Mobile-first: landscape phone, nothing clipped, the cards' names readable at phone size.
- The 9 cards are images (`assets/ui/loading/dog_cards/cards/`, made by `tools/ui-art/make_dog_cards.py`, not synced),
  uploaded, ids in `Config/LoadingScreen` DOG_CARDS. First the dogs' models rendered in Blender; since 2026-11-14
  (owner: "change it to an art") paintings in the card art's style (docs/card-art.md).
- Fonts on this screen are Roblox's built-in Bangers and Gotham/Montserrat (no font upload).

## Calls I made (the owner can change them)

- The Wild portal's green swirl screen (owner's pick, 2026-11-05) becomes the binder too, in Wild green.
- The ribbon always says ONE MORE PACK; the place's name goes above the count.
- The cards' order is shuffled each load (each card keeps its rim colour).
- Holding the character still on join.

## Left to the builder

Exact sizes and offsets at phone and desktop widths, tween timings, the glint and shadow details.
