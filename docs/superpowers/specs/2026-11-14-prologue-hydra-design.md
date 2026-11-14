# The prologue: you at your strongest, then the Hydra takes it all

Owner 2026-11-14: "STORYTELLING, at the start of the game, I want the player to have MAXXED OUT EVERYTHING battling a
hydra but only two headed that look like the one we have on the final boss in dungeon.. the player will experience
what it's like to be maxed out in the game, the hydra will defeat the player and take everything from him. and then
the game starts, welcome screen, tutorials and so on." Then: "players actually fight. 1. Cinematic 2. Fight
3. cinematic. make the player have our best weapons and pets with best animations." Storyboard approved ("perfect.
lets do it"; `.superpowers/brainstorm/.../content/prologue.html`).

## Why

- The first minute shows the dream: maxed Legendaries, Grade S, the best swords, auras. A new player learns what
  they're working toward before opening a single pack.
- It gives the game a story and a long goal: the Hydra stole your collection; the Dungeon's five-headed Prism Hydra
  is the same Hydra grown from your power. Beating it is your revenge.
- It teaches the fight buttons with everything charged, so the first real boss fight is familiar.

## Goals

- About 90 seconds on a new player's very first join, before the existing welcome flight and Pish's tutorial, which
  then run as today.
- The player really fights: taps cuts, sword skills, supers, swaps creatures and weapons, dodges.
- It looks like the best the game has: the best weapons' skills (Thousand Cuts with the Grim Reaper...), the
  Legendaries' supers with their cinematics, auras, big damage numbers.
- It can't go wrong for the player: they can't lose the fight early, can't get stuck, can skip.

## Non-goals

- No real items, cards, weapons or cash are given or taken. Nothing about the fight is saved but "seen it".
- No change to real fights (BattleService, BattleController, BattleSim) or to the welcome flight or the tutorial
  beyond waiting their turn.
- No multiplayer: only the joining player's screen sees it.
- Players with a save from before it never see it (no replay button in this round).

## Anti-goals (a failure even if it works)

- A new player stuck, lost or confused (no way forward, a black screen, the HUD gone afterwards).
- Anything from the prologue leaking into their save or into real fights (a maxed card in the binder, a weapon owned).
- Long and slow: kids leave. Over two minutes, or nothing to press in the first ten seconds of the fight.
- Feeling unfair or sad without hope: the loss is a story beat that ends with Pish and Chikin and "let's get it all
  back!", never a "you failed" screen.

## The flow

1. **Loading screen** as today (the prologue's models and effects preloaded with the rest).
2. **Act 1, cinematic (~15 s).** Cinema bars, the normal HUD off. Fade in on the Hydra's lair: a crystal arena at night
   high above the world (the Crystal Abyss look: dark sky, fog, crystal pillars and shards, a rune circle on the
   floor). Caption: "Long ago, you were the greatest card master..." The camera circles you: the Rift Reaper in hand,
   a rainbow aura, a maxed title. Your three Legendaries burst out of cards beside you one by one (the summon effect).
   The two-headed Hydra rises at the far side, runes glowing, and roars (camera shake). Big "FIGHT!".
3. **Act 2, you fight (45-60 s).** A fight HUD in the boss fight's look: the Hydra's HP bar on top, big buttons:
   Cut, Skill, Super, Swap creature, Weapon (the three weapons), Dodge. Everything ready, cooldowns short. Your summoned
   Legendary attacks on its own; you cut and skill with your weapon; Super plays the creature's super with its full
   cinematic. Damage numbers are huge. Hints teach as you go ("Tap to cut!", "Use your sword skill!", "SUPER!", "Swap
   to Voidmaw!", "Dodge the ring!"). The Hydra attacks: telegraphed rings to dodge, slams, its roar; being hit only
   flashes the screen (you can't lose). Its HP falls at a set pace so the fight lasts 45-60 s whatever you do: idling
   still gets there, spamming can't end it in 10 s.
4. **Act 3, cinematic (~20 s).** At 25% HP: time slows, its runes flare rainbow, it roars. A prism beam: your
   Legendaries turn back into cards and are sucked into its mouths; your weapons crack and shatter; your aura goes
   out. A third neck bursts out of its chest. You fall. White flash, black. "It took everything." Fade.
5. **Wake up.** You stand in your own (empty) shop; Pish and Chikin bark: "Hey! Are you okay?" / "Let's get it all
   back!" Then the welcome flight plays as today, then Pish's tutorial.

A **Skip** button shows from 5 seconds in (like the welcome flight's): skipping goes straight to step 5.

## The loadout (all max level, max stars, Grade S)

- Weapons: **Rift Reaper** (held first; Thousand Cuts with the Grim Reaper), **Prism Blade**, **Titan's Lance**.
- Creatures: **Solarion** (Supernova), **Voidmaw** (Devour), **Stormking** (Thunderstorm). Solarion is out first.

## The Hydra

The Dungeon's Prism Hydra model (`MonsterModels.prismHydra`) with three of its five necks (`Hydra_0`, `Hydra_3`,
`Hydra_4`) folded back into its chest by their bones' Transforms (tested in Studio 2026-11-14: from the front, side and
back only the inner pair `Hydra_1`, `Hydra_2` shows). For the third head, `Hydra_0` unfolds back out. Its attack and
idle clips are the Prism Hydra's own (ClipPlayer); its runes glow (the boss's SurfaceAppearance, the phase colour).

## Decided by the owner

- Fight for real (taps), in three acts: cinematic, fight, cinematic.
- The best weapons and creatures with the best animations; the loadout above (approved in the storyboard).
- Two heads, the Dungeon Hydra's look; it takes everything; then welcome and tutorials.

## Owner ruling after the first build (2026-11-14)

The first build ran act 2 as a client-only imitation with its own HUD (below, "My calls"). The owner: "why is
everything different to what we already built? just use the combat we already built". So act 2 is now the **real boss
fight**: BattleService against the Prism Hydra (`prismHydra`), BattleController's boss HUD, intro card, swaps,
supers, rings and phases, unchanged for every other fight (all new behaviour sits behind RunOptions `prologue`).
What that changes from the flow above:

- The loadout is **lent on the server** (`PrologueService`: `CardService` / `PartyService` / `WeaponService` `.Lend`),
  in memory only: never saved, levelled, traded or switched; the player's own party is what's saved meanwhile.
- **One weapon** (the Rift Reaper): a boss fight keeps the weapon in hand. Swaps between the three Legendaries are
  the real HUD's.
- Each player's lair has **its own spot** in the sky, chosen by the server (`PrologueRules.arenaCentre`); the server
  spawns the fight's Hydra there (marker attribute `Prologue`: MonsterController folds its three necks, `Util/HydraTuck`).
- The **pace** is kept: the server holds the Hydra's HP between the 35 s and 60 s curves and ends the fight at 25% with
  no rewards, records, rest, knockout or end screen; it hits at 30 (the real one's 46). No hints of our own: the boss
  HUD's button names show as in a player's first boss fights.
- Acts 1 and 3 stay cinematics on the client's own Hydra; act 3 starts where the fight's Hydra stood, and the server
  takes the lent loadout back as the cards fly into it. Only one Legendary bursts out in act 1 (the summoned one; the
  others are the swaps).
- Skip hides while the fight's HUD is up (Run ends the fight and act 3 plays; Skip shows again).

The calls below about a client-only fight and its own HUD no longer hold; the lair, the saved flag, the pacing curves
and Studio commands do.

## My calls (the builder may change these if they don't hold up)

- **Client only.** The whole prologue runs on the player's own screen (a `PrologueController` and pure
  `Util/PrologueRules`), reusing the game's own pieces instead of the real fight: creatures drawn by
  CreatureController from local markers in `workspace.Creatures`; the held weapon by SwordController from a local
  `Sword` attribute on the character; sword moves and effects as `/skillfx` plays them (SwordAnims, SwordSkillFx,
  SkillCinematic); creature attacks, supers and the Hydra's rings as fight events through `Util/FightFx` and
  `SuperCinematic` (as `/superfx` and `/attackfx` do). The real fight code (BattleService, BattleSim,
  BattleController) is untouched: changing it six days before launch risks every boss fight.
- **The HUD** is the prologue's own, built to look like the boss fight's (its slanted buttons, HP bar textures,
  fonts), not BattleController's (which listens to the server).
- **The lair** is built on the client high above the town (about 1,500 studs up, out of sight), with local lighting,
  fog and sky for its length; the character is moved there on the client and back to its shop after. Other players
  never see the lair (they might see the character's position, far out of view).
- **Saved:** `seenPrologue` (data, schema v29): new saves false; every save from before true (a migration), so
  existing players never see it. WelcomeService shows it as the player attribute `SeenPrologue`; the client says when
  it's done (remote `PrologueSeen`), the server saves it. The welcome flight (WelcomeController) and Pish's tutorial
  (TutorialService) wait for `SeenPrologue` as well as what they wait for today.
- **Pacing** in `Util/PrologueRules` (Lune-tested): the Hydra's HP share from time and damage dealt, never above the
  time curve's ceiling (can't drain faster than ~35 s) nor below its floor (always reaches 25% by ~60 s); which hint
  shows; the act timings. Numbers in `Config/Prologue`.
- **Studio:** `/prologue` replays it on your screen (the admin panel too); `/prologue reset` makes your save unseen.

## Left to the builder

- The exact camera paths, captions and timings within each act; the arena's props and lighting.
- How the cards-into-the-Hydra and the shattering are drawn (card faces on parts, particles).
- Which Hydra clips play when, and the ring shapes it uses.
- Sounds (Roblox-licensed only: PSE / APM).

## Owner feedback after playing it (2026-11-15)

"the hydra is deformed. also at the start of the prologue, the solarion is blocking the view. only summon pets when the
cinematic is done. the hydra should knock me down. then a cinematic of me crawling while all the cards are taken from
me, then I blackout, in the town, I slowly open my eyes and see chickin and pish waking me up."

- **The Hydra is its own model**: first the Guardian with three necks cut away (`prismHydraTwin`), which showed a hole
  in its chest once imported; then the owner picked concept A of three: the young Hydra, one head and two crystal buds
  on its chest where the others will grow (`prismHydraYoung`, Meshy, `rig_prismHydraYoung.py`, the boss's bone names).
  HydraTuck is gone; the five-headed swap at the end of act 3 shows it growing them.
- **Act 1 has no creature.** Solarion comes out with the fight (the server's "fight" step summons it).
- **Act 3:** Solarion back into its card under the flash; the Hydra close in front of you; its strike shatters your
  weapon and throws you back tumbling onto your face; you crawl toward it while every card you have flies into its
  mouths; it grows its five heads under a flash; blackout (blur, dark, the caption).
- **The wake-up:** on your back on the street in front of your shop, your eyes (lids with a blink, blur clearing), Pish
  and Chikin leaning in over you with three lines; you get up and they hop; then the welcome flight.
- **No skipping the opening or the fight** (owner, after the young Hydra: "the first fight should not be skippable.
  only after the fight when hydra is taking your cards. also add some music"): Skip from act 3, no Run in the fight.
  Music for each part (lair, fight, taken, wake; APM pieces with options to try by `/music`).
- My calls: the crawl is toward the Hydra (reaching after your cards); the five-headed swap keeps the link to the
  Dungeon's Hydra; you wake outside your shop rather than at the plaza (the tutorial starts there).
