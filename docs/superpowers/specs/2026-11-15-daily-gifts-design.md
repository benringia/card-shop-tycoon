# Daily, weekly and monthly gifts

Owner 2026-11-15: "lets add the daily reward", then "go, can we also have weekly and monthly. design must feel like a
WIN. yes 10 min timer should start when they actually start playing"; window layout A (the calendar strip) picked from
the mockups (`.superpowers/brainstorm/.../daily-gifts.html`). Their 2026-11-09 list wanted the daily reward "shown only
after 10-15 min of play".

## Why

A reason to come back every day (daily), keep coming most days (weekly) and stay all month (monthly), and a reason to
keep playing past the first minutes each session (the 10-minute wait). Every gift should feel like a win: most days
give something you open (the game is One More Pack).

## What the player gets

- **Daily gift**, a 7-day round, then it starts over at day 1:
  1. $300 + First Spark Pack; 2. XP Tonic; 3. Very Rare Pack; 4. Wild Ore x10; 5. Grading Seal; 6. Star Shard;
  7. BIG GIFT: Epic Pack + 15 minutes of 2x Luck (a free taste of the Store's luck).
- **Weekly Chest**: earned on the 5th day you claim a daily gift in a week (weeks start Monday, UTC). Epic Pack, Star
  Shard, $1,000.
- **Monthly Chest**: earned on the 20th day you claim a daily gift in a month (UTC); the launch month (November 2026)
  needs 8. Legendary Pack, 30 minutes of 3x Super Luck, $5,000. Opening it tells the whole server.
- An earned chest waits until opened (never lost when the week or month ends); its bar starts over with the new week
  or month.

## Rules

- One daily gift per UTC day, after 10 minutes of play that day. Play time counts only once the player's first visit
  (the prologue and Pish's tutorial) is done, in every place (town, Wild, Frontier, Dungeon).
- Missing days never resets anything: the round carries on from the day you reached (owner said "go" to this).
- Gifts are claimed in the main game (the Phone and the window are town HUD; the Frontier and the Dungeon count time).
- Server authoritative: the server counts play time, decides what is claimable, rolls nothing (all gifts are fixed),
  grants cash through EconomyService, items through ItemService, luck through LuckService. The client only asks to
  claim "daily" | "weekly" | "monthly". Refusals go through Util/Blocked.

## Look (layout A)

- A **Gift** tile on the HUD's side under the Phone: Pish's present picture, the time left ("7:32") counting down, a
  red "!" and a bounce when something is ready. Hidden until the first visit is done.
- The **Daily Gifts window** (UIKit panel, pink Bag header): 7 day tiles in a row (done ones ticked and faded, today's
  glowing and bobbing with CLAIM! or its time left, day 7 wide and golden "BIG GIFT"), then the Weekly Chest bar
  (purple, "3 / 5 days", what's inside, "new week Monday") and the Monthly Chest bar (gold, "12 / 20 days"), each with
  an OPEN! button once earned.
- **The win moment** (all three): the screen dims, light rays turn, the gift drops in (daily: Pish's present picture;
  weekly: the boss chest tinted purple; monthly: tinted gold) and rattles three times, harder each time, with a rising
  sound; it bursts in confetti and stars with a big title ("DAY 3!", "WEEKLY CHEST!", "MONTHLY CHEST!", rainbow for the
  big ones), then its gifts flip in one by one as cards. A pack among them gets **OPEN IT NOW!** (rips it straight from
  the Bag); **Nice!** closes. A chest earned by this claim plays right after.

## Built from

`Config/Gifts` (plain data), `Util/GiftRules` (pure, Lune-tested: days, weeks from Monday, months from the day number,
play time, what's claimable, claiming, the gifts in words), `GiftService` (server), `GiftController` and `Util/GiftWin`
(client), remotes `GiftState` and `GiftClaim`, saved `gifts` (schema 30). Studio: `/gift ready | day <1-7> | week <n> |
month <n> | reset` and the admin panel's "Gifts" buttons.

## Calls made by Claude (owner can change)

- Weekly needs 5 days, monthly 20 (launch month 8); the chest contents above.
- Idle time still counts as play (no AFK detection).
- The win moment is on screen (2D, plus the 3D chest in a viewport); Pish appears as his present picture rather than
  walking up in the world (Town Pish is one shared dog per server).
