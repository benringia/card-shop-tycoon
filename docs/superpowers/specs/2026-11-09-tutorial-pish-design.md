# Tutorial with Pish: design

Approved pieces from the owner's brainstorm, 2026-11-09. Branch `tutorial`.

## 1. Why

The game goes public next week. A first-week launch lives on the first session: a kid who doesn't make a sale in
their first few minutes leaves. Today a new player gets the welcome flight and then an empty shop with no guidance.

The tutorial is led by **Pish**, the owner's own dog (a white Shih Tzu with an underbite and a light brown patch on his
back). He makes the first visit warm and personal, and he stays in the town afterwards as a dog everyone knows.

## 2. Goals, non-goals, anti-goals

Goals
- A brand-new player makes their first sale within about 3 minutes, guided only by Pish, arrows and pictures.
- Kid friendly: **no text, or a word at most** (owner). Everything is shown: Pish runs there, a paw trail leads, a
  bouncing paw marks what to tap, picture bubbles say what to do.
- Pish teaches each new feature when it unlocks, not all at once.
- Every step is measured (onboarding funnel) so we can see where new players quit after launch.

Non-goals (this round)
- The luck system itself (owner: "we will be adding luck in the future"). This round adds only Pish's luck buff and
  the one place luck applies (§7), built so later sources plug in.
- Titles, daily reward, Robux products, the NPC roster (Chikin, Noogin...): other launch-list items.
- Teaching fights in detail (the boss lesson only shows where to go).

Anti-goals (would make it a failure even if it works)
- Walls of text, or a tutorial that freezes the game while a kid waits.
- A skip that's easy to hit by accident, or skipping that loses the gift for ever.
- Two Pishes on screen for a tutorial player, or another player's tutorial Pish showing up in your view.
- Pish stretching or glitching (owner checks this closely: every clip passes `tools/blender/check_stretch.py`).

## 3. What's done already

- **Model**: Meshy from the owner's pick B, straightened, head turned back in line, light brown patch on his back
  (`tools/blender/prep_pish.py`), rigged with PetRig-named bones and a jaw (`rig_pish.py`), head/ears/tail weighted so
  nothing stretches. `assets/blender/Pish/Pish.fbx`, imported into Studio by the owner (2026-11-09).
- **16 clips** (`tools/blender/anim_pish.py`, built to `assets/monster-animations/Pish`, played by `Util/ClipPlayer`):
  idle: sit, sniff, bark, roll, dig, shake, playBow, headTilt, yawnStretch, nap, tailChase, happyHop, scratch;
  for players: petted, point, celebrate. Markers: `Bark1..3`, `DigStart/DigEnd`, `Yawn`. Each starts and ends at
  rest. Walking is the procedural creature walk (`Util/PetAnimator`), as for party creatures.

## 4. Where Pish lives

There are two kinds of Pish, and a player never sees both.

**Town Pish** (server, one per server, in the main town only, everyone sees him; owner: "pish should walk around the
town, visiting shops").
- Walks the town on the walkers' street paths (`TownWalkerService` / `WalkerRules`, `WalkStep`), at a dog's trot.
- Visits shops: picks an open shop (its owner in the game), walks to its door, sniffs or sits there, moves on.
- Between walks he does a random idle clip (never the same one twice in a row), now and then a short nap.
- **Pettable** by anyone (§7).

**Tutorial Pish** (client only: made on one player's client, so only that player sees him; owner: "when multiple
players are in the tutorial phase at the same time in the same server, only them can see tutorial pish").
- Exists while that player is in the first-visit tutorial or a lesson visit. That player's client hides Town Pish
  meanwhile; everyone else still sees Town Pish.
- Several players in the tutorial at once: each has their own, seen only by them.
- When the tutorial (or a lesson) ends he does the celebrate clip, runs off and disappears; Town Pish shows again.

## 5. The first visit

Starts right after the welcome flight (`WelcomeController`), for a player who hasn't finished or skipped it (saved).
Pish trots up to them at their shop door, barks and wags. The starting shop has a register, the order computer and no
shelves, with $200 (`Economy.STARTING_CASH`).

Steps (each one a funnel step; order fixed; a step completes when the game sees the player do it):

1. **Gift pack.** Pish drops a pack at their feet (the `sparkPack` Bag item, given by the server). A bouncing paw on
   the Bag tile, then on Open. They open it on the pack stage. (Owner: open first: instant reward, no waiting.)
2. **Build a rack.** Paw on the Build tile, then on the Small Pack Rack; a glowing outline where it goes. Placed.
3. **Order stock.** Pish runs to the order computer and points; paw on it, then on the First Spark Booster Packs box,
   then on Order. Ordered.
4. **Stock the rack.** Paw trail from the delivery spot to the rack; carry the box there and restock. Done.
5. **First customer.** The server sends a tutorial customer to this shop at once (a plain customer, the `/customer`
   dev path) who takes packs to the counter. Paw trail to the register; Pish sits by it.
6. **Ring it up.** Paw on the items to scan, then on Charge. The sale goes through: a coin burst, Pish does happyHop.
7. **Gift.** Pish's gift box (in view the whole time, §6) opens: a pack whose last card is **Very Rare or better**
   (my call: every First Spark pack already guarantees a Rare in its last slot). Opened on the stage.
8. **Bye.** Pish does celebrate, a paw-wave, runs off. Tutorial done (saved). Town Pish appears.

Between steps nothing blocks the game: the player can walk around, and a step they do early (e.g. ordering before
building) is counted when its turn comes. If they wander off, Pish runs after them and points back.

Cues, all without words: Pish runs to the spot and barks (`point` clip); a glowing paw-print trail on the ground to
it; a bouncing paw over the UI button or 3D thing to use; a picture bubble over Pish's head (pack, hammer, computer,
box, coin, register: `Config/UIIcons`); a paw row at the top showing steps done and left; a sparkle and a soft
"ding" each time a step completes.

## 6. Skipping (owner: "they can skip. but add some skip discouraging elements")

- Pish's **gift box** sits in a corner of the screen the whole time, with the paw row: the reward is always in view.
- **Skip** is a small round button in a corner that must be **held for 2 s** (a ring fills); a tap does nothing.
- Holding it through: Pish's ears droop, he whimpers, and a card shows the gift box with a red cross. Two buttons:
  a big green paw (keep going, the default) and a small grey skip (really skip).
- Skipped: the tutorial ends without the gift. A small **Pish button** (in the Manage tray) replays it from the
  start any time, and finishing it then still gives the gift once.
- Funnel: a skip is logged with the step it happened at.

## 7. Petting Pish and his luck (owner: "allow players to pet pish", "maybe LUCK for 3 mins")

- A ProximityPrompt on Pish (Town or Tutorial), a paw icon and the word "Pet". Pish stops, faces the player, plays
  `petted`, hearts float up, a happy bark sound.
- Petting **Town Pish** gives **Pish's Luck for 3 minutes** (the server checks the player stands by him; Tutorial
  Pish exists only on one client, so petting him is a cuddle with no luck): shown as a timed buff badge with a clover
  icon by the cash (beside today's
  creature-perk badge, `BuffController`), counting down; its tooltip in a few words.
- My calls (owner to confirm):
  - **What luck does now: better pack pulls.** While it lasts, the last (hit) slot of every pack or Deck Box the
    player opens has its Very Rare, Epic and Legendary weights raised by 25% (the Rare weight takes the difference).
    Server-side in the pack roll, after pity.
  - **Once every 15 minutes per player.** Petting is always allowed (the cuddle plays every time); the luck only
    comes when the last one was 15 minutes ago, so Pish is a lucky treat, not a permanent buff.
  - Built as a `Luck` stat with sources (Pish is the first), so later luck items and passes add to it.

## 8. Lesson visits (Pish pops back when something new opens)

When a level unlocks something, a Tutorial Pish runs to that player (wherever they are in town), barks, points at the
new thing (its HUD tile or its place) with a picture bubble, and leaves after about 20 seconds or when they use it.
Once per player per lesson (saved). Not during a fight or an opening, and not away from the main town: it waits
until they're free and back in town. The level 4 lesson plays with today's first-sword popup, not as a second one.
My list:

| Level | Lesson |
|---|---|
| 3 | Card Sleeves: paw on the order computer, sleeves picture |
| 4 | Your first sword (equip) and the Wild portal: paw trail to the portal |
| 5 | The Card Condenser |
| 6 | The Forge |
| 7 | Deck Boxes and the shop expansion; boss 2 |
| 11 | Sealed Booster Boxes |
| 14 | The Grading Station |
| 20 | Shop jobs |

**Stuck helper.** In a player's first hour, if they sit with an empty rack and no order, or full stock and no customers
for 60 s, Pish trots over and points at what to do next. At most once every 2 minutes.

## 9. Saved data

One `tutorial` table on the player: `firstVisit` ("todo" | "done" | "skipped"), `step` (resume point if they leave
mid-way), `giftClaimed`, `lessons` (seen lesson ids), `pishLuckAt` (os.time of the last luck). Schema bump, a migration
(old saves: `firstVisit = "done"` so existing players aren't sent through it; `giftClaimed = false`), DESIGN.md 10.4.

## 10. Sounds and effects

Licensed sounds only (PSE): barks for the `Bark` markers, a whimper (skip card), a yawn, digging scuffs, a happy
yip for `petted`. Effects: dirt kicked up between `DigStart` and `DigEnd`, hearts on petting, the paw trail, the step
sparkle.

## 11. Measuring it

`AnalyticsService:LogOnboardingFunnelStepEvent` for every first-visit step (1 to 8), plus custom events: skipped (at
step n), gift claimed, lesson shown and used, Pish petted. Visible in the Creator Dashboard's funnels after launch.

## 12. Left to the builder

- Module split (pure step and lesson rules Lune-tested; client controller for Tutorial Pish and the cues; server for
  Town Pish, gifts, the tutorial customer, luck and saves).
- Where the Pish model is stored and mapped (a new `assets/npcs` → `ReplicatedStorage.NpcModels` is the natural home).
- Exact timings, trail look, bubble art (UIIcons), sound picks and levels (`Config/SoundLevels`).
- How each step is detected (existing remotes and attributes: pack opened, placement, order, restock, sale).
- Studio dev commands to test it: reset the first visit, jump to a step, show a lesson, spawn Town Pish beside you
  (existing saves are marked done, so the owner's own save needs a reset), and admin panel buttons for them.

## 13. My calls in this doc (for the owner to check)

- The gift's last card is Very Rare or better (not Rare: every pack already has that).
- Luck = +25% on Very Rare, Epic and Legendary in the hit slot of packs and Deck Boxes; 3 min; once per 15 min.
- The lesson list and levels in §8, and the stuck helper's 60 s / 2 min.
- Existing players never get the first visit (they get lesson visits only for things they unlock from now on).
- Only Town Pish gives luck (the server can't see a client-only Pish to check the player is next to him).
- Town Pish lives in the main town only.

## 14. Amendment 2026-11-10: Pish talks, labels, his walk (owner's Studio check)

The owner played it: "as a new player I dont know what to do here. can add a dialogue instead? for pish explaining
little by little", "pish's walking movement is awkward. he look like he's shaking so fast while walking", "the gift
then arrow button at the top. is that a skip button? improve UX and label everything. I dont want players guessing".
Mockups shown; the owner picked A and A and approved the script, adding "Welcome to (game name)".

- **Pish talks (replaces "no text").** A talk card at the bottom centre (above the HUD tiles, clear of the thumbstick
  and jump button): Pish's face (his model in a little window), "Pish", one short line in big text, a big Next. Each
  step has a few intro lines (Next moves on), then a line for what to do *now* that follows the player: the paw points
  at the real thing, inside windows too (his present in the Bag, then Open; Manage, then Shop, then the Small Pack
  Rack, then "tap to place"; the computer, then First Spark's Order; the box, then the rack; behind the counter, then
  Charge). The goodbye ends after his last line. Lesson visits and nudges say one line too.
- **Script** (owner-approved; the game name is `Config/Game.NAME`, a placeholder until it's decided):
  1 "Hi! I'm Pish!" · "Welcome to <game>!" · "This is your very own card shop!" · "I brought you a present. Open your
  Bag!" · (Bag open) "Tap my present!" · "Now tap Open!"
  2 "Shops need shelves! Tap Manage." · "Tap Shop." · "Pick the Small Pack Rack." · "Put it on the floor and tap to
  place!"
  3 "Empty shelves don't sell. Let's order packs!" · "Walk to the computer." · (order window) "Pick First Spark packs,
  then Order!"
  4 "Your box is here! Pick it up." · "Now put the packs on your rack!"
  5 "Look, a customer! Let them shop."
  6 "They're at the counter! Stand behind it." · "Tap Charge to sell!"
  7 "You made your first sale! Here's my gift: a special pack!" · "Open it in your Bag!"
  8 "You're a real shop owner now!" · "Need me? Tap the Pish button. Bye bye!"
- **A labelled top bar** (replaces the gift box and the bare arrow): "Pish's Tour · 3 of 8", the paw row (left out on a
  narrow phone), "Gift at the end!" with the gift picture, and "Skip tour / hold to skip" with its fill. The "really
  skip?" card gets words: "Skip Pish's tour?", "You'll miss his gift at the end!", "Keep going" (big, green), "Skip".
- **His walk** (research: small dogs take quick, short, low steps with the head up, legs in diagonal pairs when
  trotting, about 2 steps a second walking): he walked at 7 studs/s with a 1.4-stud stride, 5 leg cycles a second (8
  trotting). Now a stroll at 4.5 studs/s and a trot at 8, strides about 2.5 studs (about 1.8 and 3.2 cycles a second),
  less body bob.

## 15. Amendment 2026-11-10 (round 3): a quieter tour, Pish arrives, his gift icons

The owner played the talking version and asked for less on screen and a proper entrance; mockups shown, picks: A, A, B.

- **Small Skip** (pick A): the tour bar is gone. A small labelled "Skip" sits at the top right (left of the HUD's
  right column on a phone). Tapping it opens the tour card: "Pish's Tour · 3 of 8", the paw row, "Finish the tour for
  Pish's gift!" with the gift picture, a big green "Keep going" and a small grey "Skip tour".
- **Spotlight and a calm HUD** (pick A): when Pish points at a button, the screen dims everywhere but that button and
  his card. During the first visit the HUD shows only what the tour uses: the party bar, the weapon switch, the Bosses
  tile and the buff chips are hidden until the visit ends. Nothing dims when he points at a thing in the shop.
- **His name** over his head ("🐾 Pish"), with "pet me for luck!" when you can pet Town Pish (built in round 3's fixes).
- **Pish arrives**: after the welcome flight, a bark off screen; the camera turns to Pish running in, he skids to a
  stop at your feet and barks twice, the camera eases back behind you and his card says "Hi! I'm Pish!". About 4 s; a
  tap skips it. Once per first visit (a replay starts without it).
- **Icons** (pick B): his present at the start is its own item, "Pish's Present" (Pish hugging a ribboned First Spark
  pack; it opens a First Spark pack), and his gift at the end shows a rainbow-foil pack with a purple bow and a paw
  medal. Made with Figma's image generator, cut out, uploaded (Config/UIIcons).
