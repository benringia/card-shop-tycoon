# Loot ready again: design (2026-11-27, small change)

Owner 2026-11-27: "add a notification if boss timer resets", then "go" on the proposal below.

- **Why:** a boss gives loot every 7 minutes; nothing told players when a timer ran out, so they had to keep opening
  the board to check. (A bought reset already says "All boss timers reset!")
- **Approaches:** a client-side countdown (lost on a rejoin or another place, two clocks to keep in step) or the server
  watching each timer (picked: it knows the truth, in every place).
- **Design:** `BossService` watches the timers the player started in this server, plus ones still running when they
  came; once a second it collects every watched timer that ran out (`BossRules.dueLoot`, ladder order) and sends one
  toast (`BossRules.readyWords`, `Bosses.LOOT_READY`: one or two bosses by name, more by count) and
  `Remotes.BossLootReady` (the boss ids). The client counts them on the Bosses tile or Phone app (`Hud.setBadge`; every
  `Hud.tile` now has a count like the Phone's apps) and pings the Phone; opening the board clears it. A bought reset
  stops the watching (it has its own words).
- **Dev:** `/bosstimer <1-7> <seconds>` and an admin panel button (`BossService.DevSetLootIn`, behind DevAccess).
- **Tests:** BossRules (dueLoot: watched, ran out, ladder order; readyWords), DevGate (the new dev function). Checked in
  Studio: two timers, one toast for both; the Bosses app's count, the Phone's total, cleared on opening the board.
