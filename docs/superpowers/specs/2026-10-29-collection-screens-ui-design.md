# UI/UX pass 1: style kit and the collection screens

Agreed with the user on 2026-10-29 in a brainstorm with mockups. Mockups: `.superpowers/brainstorm/935-1793212815/content/`
(git-ignored; `style-kit.html`, `card-detail-v2.html`, `compare-kid.html`, `party-v2.html`, `bosses-bag.html`).
Calls marked **(Claude's call)** were proposed without the user choosing them; change them freely.

## 1. Intent

The core loop is done; the screens players touch every minute look unfinished. The user's words: "right now,
everything. specially on binders, party and cards". This pass gives the game one shared visual language (a style kit)
and rebuilds the collection screens with it: the binder hover tooltip, the card detail view, Add to Party, the Party
window, a tooltip on the HUD party cards, the boss ladder and the Bag. Players are often kids: important things must
be readable at a glance through colour, icons and bars, with very little text.

This is project 1 of 3 (agreed order): (1) this style kit and the 2D screens; (2) the 3D binder with real page
flipping; (3) cards in the world (shelf card models, bigger cards in bigger glass cases). The town's design and the
remaining monster models come after the three; the ranch and Heroic tiers after those (DESIGN.md section 13).

## 2. Goals, non-goals, anti-goals

Goals
- A style kit every screen uses: look A ("polished dark", today's navy and gold cleaned up), colour rules for the
  important information, button styles, and icons instead of emojis.
- A fourth icon sheet in the same glossy style for what is missing (list in 3.3).
- The seven screens in section 4 relaid out with the kit, kid-friendly.
- Fix the problems found in the review of today's screens (the list is in 4, by screen).

Non-goals (later projects)
- The binder book itself (page layout, the squeezed cover page, tiny labels under the cards, set tabs cut off): it is
  rebuilt in 3D in project 2, so fixing the 2D book now would be thrown away **(Claude's call)**. Its hover tooltip and
  the card detail view are in this project.
- Shelf card models and the glass cases (project 3); the fight bar redesign and fight juice (backlog, unless the user
  asks); the town; monster models.

Anti-goals (a failure even if it works)
- Walls of text: a kid must get the main point of any screen without reading more than a few words.
- Emojis in the UI (the user asked for icons). Symbols the game's fonts draw as boxes (★ − ✦): use icon images.
- Anything that breaks on phones: tap targets under 48 px, panels that need scrolling for their main content on a
  landscape phone, overlaps with the Roblox buttons or the HUD.
- Losing information players use today (every number shown now stays reachable, if not on the first glance).

## 3. The style kit

### 3.1 Look
Look A: the existing "Midnight & Gold" (`Util/UIKit`, DESIGN.md 10.6), cleaned up: navy panels with a gold rim,
slate rows, chunky buttons with a bottom lip, FredokaOne titles and numbers, Nunito Bold body. Stat cards on a slate
background with an icon on the left. Solid, readable, calm.

### 3.2 Colour rules (the same on every screen)
| What | Rule |
|---|---|
| Rarity | the game's existing colours from `Config/Rarities` (Common grey, Rare blue, Very Rare teal, Epic purple, Legendary gold), so pills match card frames, creature glows and the pack reveal. The user chose this over the mockups' purple / orange; no game-wide recolour |
| Element | its icon (Ember, Tide, Bloom, Volt, Shade already exist) and its colour |
| Grade | pill: S gold, A blue, B green, C grey |
| Money | green, always with the Cash icon |
| Power | orange **(Claude's call)**, with the Power icon; HP, ATK, SPD each with their icon |
| Good / bad | green = ready, enough, better; red = locked, not enough, worse; gold = hints and the selected thing |
| Buttons | gold = the main action, slate = other choices, red = remove / leave; every button has an icon **(Claude's call on the colours)** |
| Stars | star icons (lit / dim), never the ★ character |

Exact colour values live in `Util/UIKit` (or a new `Config/UIStyle`), not in screens.

### 3.3 Icons
No emojis anywhere in these screens. Existing icons (`Config/UIIcons`) are used where they fit (Cash, Cards, Level,
Gem, Heart, Star, Trophy, Lock, Check, Close, Next, Flip, Hourglass, Party, Jobs, Bag, Shard, Gift, the five
elements). A fourth sheet, made like the others (Figma image generator, `tools/ui-icons/slice_icons.py`, uploaded,
ids in `Config/UIIcons`), adds: **Power, HP, ATK (sword), SPD (wing), XP, Copies, Summon, Remove, Job, Key fragment
(one icon, tinted per boss in code), XP Tonic, Grading Seal, Gold Seal**. Until a picture exists, a coloured square
stands in (as in the mockups).

### 3.4 Kid-friendly rule
Lead with a verdict, a picture or a bar; numbers second; sentences last. Comparisons use paired bars where the longer
green bar wins. A few words at most per line. Exact numbers stay available on hover where they matter.

## 4. The screens

### 4.1 Binder hover tooltip
A small card: the card's art, name, set number; chips for rarity, element (icon) and best grade; a 2x2 stat grid
(Power, copies owned, best level, best grade) with icons; worth range in green with the Cash icon; "Click for
details" in gold. It must never cover the card it belongs to or the cards next to it (place it beside the hovered card,
flipping sides near the screen edge).

### 4.2 Card detail view
- The big card stays the **3D card you drag to tilt** (`CardInspectorController`, with the Legendary aura); the user
  chose to keep it over a flat card.
- Nothing of the world may show (the user saw customers walking past: today the solid sheet sits 3.4 studs from the
  camera, so anything closer still shows). While the view is open the camera moves to an empty spot away from the
  world, with the solid backdrop behind the card **(Claude's call on how)**. A ScreenGui backdrop or a ViewportFrame
  won't do: the first hides the 3D card, the second can't draw its face or aura.
- The big card on the left with a Flip button under it; the info panel right beside it (no empty gap), on every screen
  shape.
- Header: name; chips for rarity, element, set number and copies; worth on the right.
- "Your copies" list, best first: grade pill, level, star icons, FOIL / count tag, Power, value. The best copy
  carries a gold **BEST** ribbon (trophy icon); the big card shows a "BEST COPY" ribbon (on the card's own face) while
  that copy is shown.
- The selected copy: Power, HP, ATK, SPD with icons; an XP bar to the next level; a bar for the next star, with what
  it needs in red when you're short; whether it's in the party or working a job.
- Buttons with icons: Add to party (gold), Give a job (says why when it can't, e.g. "slots full (2/2)"), Back.

### 4.3 Add to Party
A chooser over the detail view: "Add <card> to your party", the three party slots (art, name, level, grade, Power,
"+22 if swapped" in green / red). Clicking a slot shows the **kid-friendly comparison**:
- a big verdict badge: "STRONGER +22" (green, check) or "WEAKER -2412" (red);
- the two cards side by side, IN (green border) -> OUT (faded);
- three rows of paired bars with the HP, ATK and SPD icons, the longer green bar wins;
- one short line: element icons ("Shade replaces Ember") and the perk change.
Then "Swap with <card>" (gold) and Cancel. An empty slot fills straight away.

### 4.4 Party window
All three party cards side by side (no scrolling on a landscape phone). Each: art, name, grade pill, level, star
icons, big orange Power, three short bars (HP, ATK, SPD), its perk as element icon + a few words, and buttons:
Summon (gold), XP Tonic (icon with how many you have), Remove (small red). The summoned card glows green with a
**SUMMONED** tag and a green "Summoned" button. The header: "Party", a "Summoned: <card>" chip and the PvP record chip.
Empty slots show "+ Add a card" (opens the binder). Fixes: today only two of three fit and the warning line crowds the
header.

### 4.5 HUD party cards: hover tooltip
Hovering (or long-pressing on touch **(Claude's call)**) one of the three cards beside the PARTY button shows a mini
tooltip: art, name, grade, level, Power, the three bars and the perk, plus a resting timer when it's resting. No need
to open the binder.

### 4.6 HUD: remove the Star Shard pill
The pill with the star-shard icon under the cash goes. Shards stay visible in the Bag (and wherever they are spent).

### 4.7 Boss ladder
A path of seven steps, each a disc with the boss's element icon (the Hydra: a prism gem). Four states, first match
wins **(Claude's call)**:
- **beaten**: gold ring, trophy badge;
- **ready**: green glow, check badge; you can start the fight now (shop level reached, and the boss is open or you
  hold enough key fragments, which are used at the first fight) and your best Power meets what it needs;
- **too weak**: red ring, no badge; you could start it, but your Power is short;
- **locked**: faded, lock badge; below the shop level or short of key fragments.
The state rule is a pure, Lune-tested function. Clicking a step shows its details:
- name, element and where it lives (the Wild zone, the Frontier, the Dungeon);
- two bars, your best Power vs the Power it needs, and a big verdict ("You're ready!" green / "Too weak" red);
- locked: what's missing as a bar instead (shop level, key fragments x / N), red until enough;
- loot ready or its countdown (hourglass), wins today, what it drops (icons);
- **"Take me there"** (gold): to that boss's gate. Approved by the user. In the same place it moves you to the gate
  (like `/boss n` does for testers, through the server and its travel checks); a boss in another place shows "Go to
  the Frontier" (the normal travel) instead; the Hydra shows how to reach it (the Frontier's Dungeon portal) with no
  teleport **(Claude's call on the other-place cases)**.

### 4.8 Bag
- Key fragments: one key-fragment icon tinted per boss, with the number of the boss it opens in a corner chip, so
  every key looks different.
- Trophies: the boss number in the corner and a real count (today a bare "x" shows).
- The info panel goes dark like everything else (today white): big icon, name, "You have n", "What it does", "Where
  to get it".
- Slot counts readable on phones.

## 5. Constraints

- Build UI in code with `Util/UIKit` (and `CardFace` for card faces); one window at a time; `ZIndexBehavior` rules
  from CLAUDE.md; panels hide the thumbstick/jump while open.
- Mobile-first: tap targets 48 px or more; check every screen in the Device emulator on a landscape phone
  (`UIKit.isPhone` exists for phone-only layouts).
- Text: ASCII plus `·` and emoji are allowed by the fonts, but this pass uses no emoji; ★ − ✦ never (they draw as boxes).
- Numbers and colours in config, not in screens. Pure layout/rule logic that can be tested goes in Roblox-free modules
  with Lune tests (e.g. tooltip placement, the comparison verdict, the boss step state).
- "Take me there" goes through a remote that is validated and rate-limited, never trusting the client.
- The user approves each screen in Studio; DESIGN.md 10.6 is updated with the kit.

## 6. Left to the builder

- Exact sizes, spacing and colour values within look A; animation (the existing `Util/Motion` style).
- The order of the screens; how the kit is organised in code (UIKit additions, a `Config/UIStyle`).
- The icon sheet's prompts and the stand-ins until the icons are uploaded.
- Phone variants of each screen, within the constraints above.
