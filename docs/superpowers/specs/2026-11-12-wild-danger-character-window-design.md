# Wild danger, the character window and plain element names

Owner request 2026-11-11/12, launch 2026-11-20. Three connected parts: the Wild becomes dangerous for the player, a
character window shows how strong you are before you go, and the elements get names kids understand.

## Why

Walking into Ember Ridge should feel scary (owner: "they would be scared"). Today wild monsters only fight your
creature; a player with resting creatures is ignored (a chasing monster's contact just gives up). Players also have no
place to see their own strength or the element matchups, and "Ember, Tide, Bloom, Volt, Shade" mean little to kids.

## Goals

1. In the dangerous places, monsters attack the player too, and a weak party makes you feel it.
2. Defense comes from party strength (owner's pick): grow your cards and the Wild hurts less.
3. A character window: your character holding your weapon, your Power, Attack and Defense, and the elements.
4. Element names everywhere players see them: Fire, Water, Nature, Electric, Dark, with image icons, not emoji.

## Non-goals and anti-goals

- Never lose cards, cash, items or progress: a knockout costs only that fight (agreed 2026-11-11).
- The Meadow and the Caves stay calm (Chikin's combat tutorial walks there).
- No pay-to-win: nothing sold makes you tougher.
- No death screen, no long wait, nothing that punishes a kid for exploring.
- Saved data and configs keep the internal element keys (Ember, Tide, Bloom, Volt, Shade): only what players read changes.

## 1. Wild danger

**Dangerous places:** Ember Ridge (the Wild valley's third zone) and every Frontier zone (Frostwood, Stormpeak, The
Rift). The Meadow and the Caves keep today's behaviour exactly, elites there included. **Who catches you** is unchanged:
monsters in aggro zones (Ember Ridge, The Rift) and elites chase you (`WildService`, `aggressive = monster.elite or
zone.aggro`); in Frostwood and Stormpeak only elites chase. **Every fight in a dangerous place** (caught or started by
you) is dangerous: the monster hits you too, and you can be knocked out.

When one catches you (`WildService.OnContact`, today `tryStart` and nothing if you can't fight):

- A creature of yours can fight: if none is out, the first rested card of your party is summoned for you (the lead
  first), and the fight starts as today. You're always in a dangerous fight, with your sword if you have one (without
  one you can only dodge). Its quick hits on you already exist for sword fighters (`CombatMath.getMonsterAttacks`); in a
  dangerous place they come in every fight.
- Every creature resting, you have a sword: a sword-only fight, you against it (your weapon's damage; no card XP).
- No creature and no sword: it roars, shoves you back and leaves you; a big "Your creatures are resting!" card (Util/
  Blocked) tells you why. (My call: knocking out a defenceless new player is no fun.)

Hits on you are shares of your 100 HP as today, scaled by your Defense against the place (section 2). At 0 HP you're down
(`DOWN_SECONDS` 5) and get back up while a creature of yours stands. With none standing you're **knocked out**: the
screen fades and you wake at the healing spring (main game: the town plaza's spring, `Wild.SPRING`; the Frontier: the
spring at its entrance), the fight counted as lost exactly as losing a wild fight today (fainted cards rest as usual),
the monster back at its spot healed. Nothing else lost. A short "Knocked out!" card says what happened.

Feeling it (my calls): a dangerous monster that spots you shows a red "!" over its head and growls before it chases; a
hit on you flashes the screen red (exists: `CombatHud HIT_FLASH`); the zone's name card says "Dangerous" when you enter
Ember Ridge or The Rift.

## 2. Defense from party strength

- **Defense** = your three party cards' Power added up (my call; the mockup said "HP": the same idea, and it uses the
  numbers players already know; a resting card still counts: it's your party's toughness). Power on the Stats tab is
  your strongest card's alone, so the two numbers differ.
- A place's **reference Defense** = 3 x that zone's recommended Power (`Wild` / `Frontier` zones' `recommended`); in a
  boss fight, 3 x the boss's `recommended` (owner 2026-11-12: "apply it to bosses too and rebalance"). In a group fight
  each player's own Defense scales the hits on them.
- A hit on you is multiplied by `reference / Defense`, clamped to **0.5–1.5** (my numbers: a strong party halves hits, a
  weak one takes half again more; never immune). Server-side in the fight sim; a pure, Lune-tested rule.

- **Bosses rebalanced:** `tools/balance/bosses` learns Defense (each simulated party's Power sum against the boss's
  reference) and every ladder boss and the Prism Hydra are retuned to the existing targets: fighting well 85% wins at
  1x the recommended Power and 50% at 0.8x; standing still 60% / 15%. At exactly 1x nothing changes; the 0.8x and
  "best card plus two weaker" rows get harder, the 1.3x rows easier.

## 3. The character window

Layout A v2 (the mockup the owner picked, `.superpowers/brainstorm/.../character-window-v2.html`): a cotton-candy window
titled with your name and shop level.

- **Left:** a 3D view of your own avatar holding your equipped weapon on a glowing podium; drag to turn it.
- **Right, three tabs:**
  - **Stats:** **Power** (your strongest party card's Power: the number the boss board compares with "built for N
    Power"), **Attack** (your equipped weapon's Power, `WeaponRules.power`; the starter sword's without one), **Defense**
    (section 2). One short line under each saying what it means.
  - **Elements:** your three party cards with their element icons; who beats who (Fire beats Nature, Nature beats Water,
    Water beats Fire, Electric and Dark beat each other); "Strong: 1.5x damage · Weak: 0.75x".
  - **Titles** (owner 2026-11-12: "I'm planning to add titles system"): every title as a row, earned ones bright with an
    Equip button, locked ones greyed with how to earn them; the equipped one shows over your name in every place. Today
    there are two (Dungeon Conqueror: clear the Prism Hydra; Crystal Seeker: find the Dungeon's secret chest), picked
    automatically by `BossRules.pickTitle`; now the player chooses (saved), defaulting to today's pick. Titles come from
    one list (Config/Titles: id, name, colour, how to earn, how it's checked) so the coming titles system only adds rows.
- **Bottom:** your weapon card (picture, name, grade, level, element, its skill).
- No "where you're safe" box (owner).
- Opened from a new HUD tile (my call: "Me", with the player's avatar headshot, beside Cards / Bag / Bosses, everywhere,
  not town-only). Mobile-first: on a phone the stage sits above the tabs.

## 4. Element names and icons

| Internal key | Players see | Icon |
|---|---|---|
| Ember | Fire | `UIIcons.Ember` image |
| Tide | Water | `UIIcons.Tide` |
| Bloom | Nature (my call; owner said "and so on") | `UIIcons.Bloom` |
| Volt | Electric | `UIIcons.Volt` |
| Shade | Dark | `UIIcons.Shade` |

- One shared lookup (display name + icon id) used by every player-facing string: card lines in the shop and showcase,
  the binder and its filters, weapon text ("bonds with Fire creatures"), fight banners ("Fire phase!"), the boss plate's
  crest, monster and add bar names, perk chips, tooltips, Pish's and Chikin's lines if they name one.
- The element emoji in fight UI (`Party.PERKS[...].icon`, BattleController's `elementIcon`) become the image icons
  (ImageLabels beside the text).

## Constraints

- Launch 2026-11-20; this is the last content change before testers.
- Server authoritative: damage, knockouts and Defense in the sim and services; clients only show.
- Never fail silently (a refusal is a Blocked card); mobile-first (48 px taps); text ASCII plus emoji only, so icons are
  images.
- BattleController is at Luau's 200-local limit: new UI goes in its own modules.
- Balance: run `tools/balance/wild` after the change; Ember Ridge and The Rift should stay winnable at their recommended
  Power fighting well.

## Left to the builder

Exact HUD tile placement and icon, the "!" look, the knockout fade's timing, the shove's strength, how the 3D view lights
the avatar, element icon sizes per place.

## Decided

- Defense softens boss hits too, and the bosses are rebalanced (owner 2026-11-12).
