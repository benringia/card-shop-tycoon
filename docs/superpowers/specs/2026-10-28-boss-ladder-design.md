# Battles, part 3b: the boss ladder

Roadmap step 5 (DESIGN 5.8), part 3b. The combat core (part 1), PvP (part 2) and the Frontier (part 3a) are done.
This adds the creature side's destination: a ladder of bosses, each a stepping stone to the next, ending in a final
boss that needs an almost maxed-out creature. It closes the core loop: packs -> duplicates -> grades and stars ->
beat the next boss -> rewards that help you climb -> the next boss.

## 1. Goal

Give growing creatures a purpose beyond the Arena. Seven bosses, gated by keys earned from the boss before, each
dropping what helps you beat the next one (levels first, then stars, then grades). Grindy by design (several kills
per key), never farmable (section 7), solo-able, faster in an optional group.

## 2. Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Ladder | 7 bosses: 3 in the Wild, 3 in the Frontier, the final boss in the Dungeon place |
| Gating | Boss Keys: each boss drops fragments of the next boss's key; a key takes several kills (the grind) |
| Rewards | Every boss drops what helps you climb: XP Tonics, Star Shards, Grading Seals, Gold Seals; no new cards |
| First clears | A trophy for the shop (placeable, visitors see it) and a server announcement |
| Groups | Optional, up to 4; boss stats scale with party size; everyone gets full loot if they contributed |
| Attempts | Unlimited fights; loot protected by a saved per-boss loot cooldown, a daily soft cap, an over-power penalty, a contribution rule and item caps (section 7) |
| Final boss | Balanced for a Legendary at Lv 30, 4-5 stars, grade A or S |
| Numbers | All in `Config/Bosses.luau`; fragment counts and drop rates tuned with the economy simulator |

## 3. The ladder

| # | Boss (working name) | Where | Unlock | Recommended Power | Mechanic it teaches | Drops (besides fragments, cash, XP) |
|---|---|---|---|---|---|---|
| 1 | Meadow Warden | Wild, Meadow | open | starter party | element weakness | XP Tonics |
| 2 | Cave Brood Queen | Wild, Caves | 3 fragments from 1 | a levelled Rare | heals: burst her down | XP Tonics, Star Shards |
| 3 | Ember Colossus | Wild, Ember Ridge | 5 from 2 | a starred Epic | enrage at 50% HP | Grading Seals |
| 4 | Frost Tyrant | Frontier, Frostwood | 5 from 3 | Epic 2 stars, grade B+ | shields: break them first | Grading Seals, Star Shards |
| 5 | Storm Sovereign | Frontier, Stormpeak | 8 from 4 | Legendary 2 stars | stuns: bring SPD | Gold Seals |
| 6 | Rift Devourer | Frontier, The Rift | 8 from 5 | Legendary 3 stars, grade A | summons adds | Gold Seals, Star Shards |
| 7 | Final boss | Dungeon place | 10 from 6 | Legendary Lv 30, 4-5 stars, grade A/S | all of the above | a big chest of everything |

- A key is consumed when you start a boss for the first time; after the first clear the boss stays open forever.
- Recommended Power is shown on the boss board and the boss gate; fighting under it is allowed (risky).
- Boss models: Meshy originals like the creatures (docs/creatures.md), large, one per boss. Placeholders first.

## 4. Boss fights

- Same combat core as the Wild and Frontier: the summoned leader plus call-ins, real-time auto-battle, Run %.
- A boss is a monster with its own stats (much higher HP), a phase list and 1-3 mechanics (`Config/Bosses`):
  heal, enrage below an HP fraction, a shield that must be broken before damage lands, stuns, adds.
- Boss arena: a fenced ring at the end of each zone (Wild, Frontier) with a gate showing the boss, its lock state,
  recommended Power and your loot cooldown. The final boss's arena is in the Dungeon place (a third place,
  reached from the Frontier's Dungeon portal, same pattern as the Frontier).
- A boss HP bar across the top of the screen during the fight; phase changes flash and announce ("Enraged!").
- Losing costs nothing but the creatures resting, as now.

## 5. Groups

- Optional, 2-4 players. The party leader starts the fight at the gate; others join within 15 s from the gate.
- Scaling with party size n: boss HP x (1 + 0.8 (n - 1)), ATK x (1 + 0.15 (n - 1)). Solo stays possible; groups are
  faster and safer.
- Loot is rolled per player (everyone who contributed gets their own full roll; nothing is split).

## 6. Rewards and items

New items in `Config/Items` (account-bound: never traded or sold):

| Item | Use | Cap |
|---|---|---|
| Boss Key Fragment (one kind per boss) | N make the next boss's key | - |
| XP Tonic | instant card XP to one creature | - |
| Grading Seal | covers one missing duplicate at the Grading Station | at most half of a step's duplicates (like Star Shards) |
| Gold Seal | pays the cash for one grade step | not the Legendary A -> S step |
| Star Shards (exist) | cover missing duplicates for a star | as now (half a star) |

- First clear of each boss: a guaranteed chest (fragments for the next boss, a stack of its items) and a trophy.
- First kill of each boss each day: a daily bonus chest.
- Trophies: a decoration per boss, placed in the shop from the Build menu (new "Trophies" tab); visitors see them.

## 7. Farm protection (all server-side)

1. **Loot cooldown per boss, saved.** Full drops once every 15 minutes per boss per player (Unix time, saved, so
   rejoining or server hopping doesn't reset it). Kills inside the cooldown still give XP and cash.
2. **Daily soft cap.** After the 6th rewarded kill of a boss in a day, each further rewarded kill's item chances are
   x0.75 of the one before, down to a floor of x0.2. Resets daily (UTC).
3. **Over-power penalty.** Party Power above 2.5x the boss's recommended Power shrinks item drops (a maxed player
   can't farm boss 1). Fragments for a boss you've already unlocked are never dropped.
4. **Contribution.** In a group, loot needs at least 10% of the damage dealt or 15% of the fight tanked, and the
   player must have the boss unlocked. Max 4 players.
5. **Account-bound items** (no trading or selling) and **item caps** (section 6), so farmed items can't replace the
   real duplicates or the Legendary A -> S cash.
6. **Server checks.** The fight runs on the server; rewards come only from its result; remotes are rate-limited; a
   kill faster than the boss's minimum fight time (`MIN_FIGHT_SECONDS`) is flagged and gives no loot.

## 8. UI

- **Boss board** (HUD tile, mobile-first): the 7 bosses as a ladder, each with lock state, fragments x/N, recommended
  Power vs your best party Power, loot cooldown, first-clear trophy, today's kills.
- **Boss gate** prompt at each arena: Fight (solo), Start group, Join.
- **Fight HUD:** boss HP bar, phase banner, group members' HP.
- **Results:** loot, fragments progress, cooldown until full loot again, soft-cap note when it applies.

## 9. Data (schema v12)

```lua
bosses = {
    [bossId] = {
        unlocked = false,  -- key used (bosses with no unlock cost start true)
        cleared = false,   -- first clear done (trophy given)
        lootAt = 0,        -- Unix time full loot is available again
        day = 0,           -- UTC day number of the counts below
        rewardedToday = 0, -- rewarded kills today (daily soft cap)
        bonusDay = 0,      -- UTC day the daily bonus chest was last given
    },
},
-- items: new item IDs (fragments, xpTonic, gradingSeal, goldSeal); trophies placed like decorations (layout)
```

Migration v11 -> v12 adds `bosses = {}`. Pure rules (`Util/BossRules`: unlock, loot eligibility, soft-cap factor,
over-power factor, contribution, group scaling) are Lune-tested.

## 10. Phases

1. **Phase 1, Wild bosses 1-3:** `Config/Bosses`, BossService (fights on the existing combat core), mechanics heal and
   enrage, fragments, XP Tonics, Grading Seals (+ Grading Station support), farm protection, boss board, trophies,
   solo only. Placeholder boss models.
2. **Phase 2, groups:** party formation at the gate, scaling, contribution.
3. **Phase 3, Frontier bosses 4-6:** shields, stuns, adds; Gold Seals.
4. **Phase 4, Dungeon place and the final boss.**
5. Meshy boss models alongside, one per boss.

## 11. Balancing

The economy simulator (`tools/economy/sim`) grows a boss model: Power per party over time (levels, stars, grades),
kills per hour per boss, drop and fragment rates. Targets: boss 1 in the first hour, boss 3 within ~5 hours, the
final boss at roughly 30-45 hours for a dedicated player (just past the Grade S + star chase, ~21 h).

## 12. Not in this part

Boss-exclusive cards; trading; ranked boss leaderboards; seasonal bosses.
