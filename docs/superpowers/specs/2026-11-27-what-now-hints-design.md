# What now? hints (design)

Date: 2026-11-27. Status: approved by the owner ("1, go"): look 1, the bubble with Pish's face on the arrow. Mockups
drawn on the owner's shop in Studio: https://claude.ai/artifact/Xgfrt8TvPYpeWWCar5KERY.

## Why
The owner asked how to apply "never let a player go idle" to One More Pack, and picked idea A: a hint for every player
at every level that points at the one best next thing. The launch funnel (Launch results, to 11-22) shows where people
stop: 8 -> 4 before Chikin's sword, and 4 -> 1 between his level 4 visit and the Meadow Warden's portal, the point
where the tours end and nothing points the way. Today only two narrow helpers exist: the quest bubble by the Phone
(computers only, 40 s idle, every 5 min; Util/QuestRemind) and Pish's stuck helper (first hour only, a box waiting or
an order to place; LessonRules.nudge). A grows them into one system.

## Goals
- A player who has done nothing for a while always gets one clear, doable next step: Pish's short words and the gold
  arrow (the tutorial's ArrowCue, its edge arrow, its ground arrows) on the thing to use.
- It works at every level, on phones and computers, in town and in the Wild valley.
- One system: it replaces the quest bubble (QuestController's reminder) and the stuck helper's Pish visits.

## Non-goals
- No Pish model walking over (that stays for the tours and his lesson visits).
- Not in the Frontier or Dungeon places (the Dungeon has its objective line); the main place only.
- No new rewards for following a tip.

## Anti-goals (a failure even if it works)
- Nagging: a tip while the player is busy, the same tip over and over, or one right after joining.
- Covering what it points at, or the guides' own cards.
- A tip the player can't act on (the owner 2026-11-18: never send someone to order what they can't pay for).

## Approaches (the owner picked A)
- A, a "What now?" hint (picked): one tip at a time, from a priority list, when idle. Covers the measured drop and
  reuses the arrows built today.
- B, meanwhile lines on every timer: cheap, a follow-up.
- C, Take me there for the next goal; D, small surprises every few minutes: later, if A isn't enough.

## The tips, first match wins (words are drafts; final words in config)
1. A customer waits at the register with no Cashier on duty: "Customers are waiting! Ring them up." The register.
2. A daily or weekly quest done, not claimed: "A quest is done! Claim it." The Phone.
3. A box waits on the delivery pad or in your hands: "Put your box on a shelf!" The shelf it fits (StockHint's choice),
   else the pad.
4. Shelves empty and the cash covers the cheapest box (LessonRules.cheapestBox): "Order packs to sell!" The order
   computer.
5. A station's job done and waiting to be taken out (UpgradeRules.showsReady): "Your card is ready! Take it out." That
   station.
6. The next main quest build is affordable: "You can build the <name>!" Build.
7. Packs or deck boxes in the Bag: "Open your <n> packs!" ("1 pack") The Bag.
8. A boss's loot is ready and the party is strong enough for it: "The <boss>'s loot is ready!" The Wild portal in
   town, its gate in the Wild valley, with arrows on the ground.
9. A quest still going: "Quest: <text> · <progress>/<goal>" (QuestRemind.words' nearest quest). The Phone.
10. Nothing else, in town: "Hunt monsters in the Wild!" The Wild portal, with arrows on the ground.

## When it shows (my calls, numbers in config)
- Idle: stood still 30 s (no key, click or stick, not moving), or 2 minutes with nothing earned (cash and XP unchanged)
  while walking around; and free (Util/PlayerBusy: no fight, window, register, placing, cinematic).
- Never in the first 60 s after joining, during Pish's or Chikin's tours, or during Pish's lesson visits.
- At most one tip every 2 minutes; the same tip not again for 5 minutes.
- It goes when the player does it, after 20 s, or on its x (that tip stays quiet the rest of the session).

## How it's built (my calls)
- The server picks the tip: it holds every fact (quests, boxes, shelves, cash, stations, builds, Bag, boss timers and
  Power) and already does this for the stuck helper. The client decides when (idle) and draws it. One RemoteEvent in
  Remotes.luau: client asks, server answers with the tip or nil; rate-limited.
- Pure rules in a shared Util (which tip, when it may show, its words), Lune-tested; numbers and words in a Config.
- The look (the owner's pick 1): a white bubble with Pish's face, the words and a small x, standing on the gold arrow:
  over it on a HUD button or a thing in the world, beside it when the arrow waits at the screen's edge. The arrow is
  TutorialCues.pointAt; far walks add TutorialCues.trail.
- Analytics: a custom event when a tip shows and when it's followed (through AnalyticsGate), to see if tips help.
- Retired: QuestController's idle reminder and the stuck helper's nudges (server checkStuck, the client's NUDGES),
  their tests moved to the new rules.

## Left to the builder
Where each fact is read on the server, how the client finds each target (the tutorial's Target resolution), the
bubble's exact placement next to an arrow at the screen's edge, and the Studio commands to show each tip.
