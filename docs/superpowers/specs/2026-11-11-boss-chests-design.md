# Boss chests (weapon drop choice)

Date: 2026-11-11. Owner's request (launch list, then this session): "after each boss 3 or 4 chest appear the drop rate is
the same but we make the player choose 1 chest to open, if the player opens a weapon, it reveals the weapon, if not it
reveals a random item and reveals the weapon somewhere in the non chosen chest with '?' on it." Then: "Your chest: the
weapon if it dropped, otherwise an item that helps the player craft the weapon with random quantities. show the weapon.
the drop rates remain. if the boss drops a weapon, a weapon will appear on the chest that player choose no matter which
chest it is." Placement: option B, the reveal stage (owner pick from the mockups). "Make sure it's abuse proof."

Built before the Dungeon redesign: the Prism Hydra at the Dungeon's end uses it, and the Dungeon's secret chest reuses
its chest model and opening.

## Intent

A boss win ends with a moment of choice and suspense: three chests, you pick one, it bursts open. The weapon drop
(rare: Rare 1% + 0.5% pity a kill ... Legendary 0.1% + 0.02%) becomes a reveal you take part in, and a miss still pays
something toward making that weapon and shows what you are hunting.

## Goals

- Three chests after every full-loot win of a boss with a weapon (all seven: Meadow Warden ... Prism Hydra), on the
  reveal stage the pack opening and the weapon drop already use.
- Your pick: the boss's weapon if it dropped (always the chest you picked), otherwise that weapon's material, 1-3.
- The other two open after yours: on a miss, one shows the weapon with a "?" and one a material amount; on a drop,
  both show material amounts.
- Today's drop odds, pity, grades and "Already yours" refunds, unchanged.
- Abuse-proof (below).

## Non-goals

- No change to drop odds, pity, other loot (cash, XP, xpTonic, keys, seals, star shards), the daily bonus or first-clear
  rewards.
- No Robux, no rerolls, no paid extra picks.
- No chests for wild monsters, elites, Dungeon rooms or wins without full loot.

## Anti-goals (a failure even if it works)

- The pick changing the odds, or any way to open a second chest, reroll, or keep a better result.
- Losing loot by leaving, teleporting, resetting or closing the screen.
- The pick screen blocking play for long or covering the fight HUD; tiny chests on phones.

## When chests appear

On a boss win where `BossRules.rollsWeapon(factor, carried)` is true (full loot: no soft cap or over-power shrink, not
carried) and the boss has a ready weapon (`weaponOf[bossId]`). Per player: in a group every eligible member gets their
own roll and their own chests; carried members and reduced-loot wins get none (as today they roll no weapon). A first
clear on the same win shows its victory chest first, then the boss chests.

## The roll (server, at the win, before any pick)

In `BossService.onBossWin`, when chests apply:
1. The boss's weapon material entry in `boss.drops` (`material_<bossId>`) is skipped for this win: the chests replace it.
2. The weapon rolls as today (`rollWeapon`: `WeaponRules.dropChance` at the record's pity, `BossService.DropWeapon`
   gives it at once, pity via `BossRules.nextWeaponPity`). Its cinematic, light column and announcement no longer fire on
   a timer: they fire when the chest opens.
3. No drop (or a drop that couldn't be given: weapons not loaded): the material count rolls from `Config/BossChests`
   MATERIAL weights {1: 0.85, 2: 0.10, 3: 0.05} (average 1.2, the same as today's 80% x 1-2) and is given into the Bag at
   once (`ItemService.GiveItem`), not scattered.
4. The other two chests' contents are made now too (display only, never given): on a miss, one "?" weapon and one
   material amount (same weights); on a drop, two material amounts.
5. A pending set is kept per player: `{ id (GUID), bossId, weapon payload?, material, count, others, opened = false,
   expiresAt }`.

Everything the player gets is saved at the win. The pick only decides which of the three chests shows it.

## The pick (client asks, server answers)

- After the victory screen (`Victory.SECONDS`, as the weapon drop waits today) the server sends `BossChests`
  `{ id, bossId, seconds }`: no contents.
- The client opens the reveal stage (`Util/OpeningStage`) with three chests in a row, gently wobbling, "Tap a chest!"
  and a ring counting down `PICK_SECONDS` (20). Tap, click, or keys 1-3 / gamepad. One tap sends
  `OpenBossChest(id, index)` and the chests stop taking input.
- The server checks: a pending set for this player with that id, not opened, index an integer 1-3, rate-limited
  (`RateLimiter`). Then it marks it opened and answers `BossChestOpened { id, index, contents = { [1..3] } }` with the
  player's own result at the picked index and the two others round it (random order).
- Not picked in `PICK_SECONDS` + 2 s grace: the server opens a random one itself (same answer). A new set for the same
  player (another boss win) opens the old one first.
- On opening with a weapon: the server then fires today's `WeaponDropped` payload (the reveal cinematic on the same
  stage), the light column for players nearby (`WeaponBeacon`) and, for an Epic or Legendary, the announcement. A player
  who left before opening still has the weapon; only the announcement is sent.
- `PlayerRemoving` drops the pending set. Nothing is rolled again on rejoin.

## The look (client, `BossChestController`)

- Three chests on the stage, big enough on a landscape phone (each at least 120 px across); the picked one rises a
  little, the others dim.
- Opening: the lid pops back with a burst of light (gold on a miss, the weapon's rarity colour on a drop), the content
  rises out: the weapon's portrait and name, or the material's icon with "x2" and its goal ("9/15 for Verdant Blade",
  `WeaponRules.materialGoal`). Then the other two open one after the other (0.4 s apart): the "?" chest shows the
  weapon's portrait darkened under a big "?", the others their material amounts.
- A drop then hands over to `WeaponRevealController`'s cinematic on the same stage. A miss closes on a tap after 1.5 s
  or by itself after 5 s.
- Sounds: a chest creak and lid pop, a sparkle for material, the existing weapon reveal sounds for a drop (licensed
  Pro Sound Effects, found with the usual toolbox search).
- The chest: built in code from parts (wooden box, gold trim and lock, a separate lid on a hinge) in the game's soft
  cartoon style, `Util/ChestModel`, so no import step; a Blender or vetted Creator Store model can replace it later
  through the same module.

## Abuse-proofing

- Server-authoritative: the roll, the counts and the other chests' contents are made on the server at the win;
  the client only ever sends a chest index.
- Loot is given at the win, before the chests show: leaving, teleporting, resetting or ignoring the screen loses
  nothing and gains nothing.
- One opening per set (`opened` flag); unknown, stale or other players' set ids are ignored; index validated as an
  integer 1-3; `OpenBossChest` rate-limited.
- Picking a different chest can't change the result (it is decided before the offer); no contents are sent until
  the set is opened.
- No new saved data (no schema change): pity is already saved in each boss record.

## Testing

- Lune (pure `Util/ChestRules`): material count from a roll and the weights (average 1.2), the three contents for a
  pick (mine at the index; a miss has exactly one "?" weapon and one material; a drop has two materials), index
  validation, the timeout's pick, a stale or opened set refused. `BossRules`/`WeaponRules` tests unchanged.
- Studio: `/chests <boss id> [drop|miss]` and an admin panel button show the chests for that boss now (Studio only,
  nothing given); a real win of the Meadow Warden with `/weapondrop`-style forcing for a drop; a group of 2 (each their
  own chests); leaving mid-pick (loot kept); a phone in the Device emulator.

## Left to the builder

Exact chest proportions, wobble and timing values (in `Config/BossChests`), the stage camera framing, which licensed
sounds.

## My calls (owner to check)

- 3 chests, not 4 (bigger on phones, a quicker choice).
- Chests only on full-loot wins (carried and soft-capped wins get none, as they roll no weapon).
- Material 1-3 averaging 1.2, replacing today's material roll (80% x 1-2), so making a weapon takes as long as now; on a
  drop the chest holds the weapon only.
- 20 s to pick, then one opens by itself.
- A code-built chest first.
