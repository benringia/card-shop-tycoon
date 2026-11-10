# Chikin's combat tutorial: design

Owner, 2026-11-10: "lets just reuse necessary components from pish and just add chikin now. I think combat tutorial is
important too." Picks: two visits, the model made with Meshy and Pish's rig, and Pish hands over to Chikin. Launch is
2026-11-19, and the Frontier and Dungeon worlds come after this, so it reuses Pish's pieces wherever it can.

## Why

New players start with an empty party, and nothing teaches it. Without a summoned creature they can't fight, and
Pish's tour never covers fighting. Combat is half the game (the Wild, bosses, weapons), and a kid lost in their first
fight leaves. Chikin is the owner's other dog: a black, curly Shih Tzu x toy poodle mix, about Pish's size. Pish
teaches the shop; Chikin teaches fighting.

## What the player sees

**Hand-over.** Pish's goodbye gets one more line: "My buddy Chikin will teach you to fight!" Then Chikin runs in with
the same arrival shot as Pish (paws, face, wide; `Util/ArrivalShot`). If Pish's tour was skipped, Chikin still comes,
after the skip, with his own Skip.

**Visit 1, the first fight** (right after Pish):
1. Intro: "Woof! I'm Chikin, Pish's buddy!", "Your cards are creatures. Let's train one!"
2. **Party:** Cards → "Tap a card you like!" (built: the binder is a 3D book across pages, so no paw on one card) → "Add to party". Done when the party has a
   card; done at once if it already has one.
3. **Summon:** "Tap it on your party bar to call it out!" (paw on slot 1). Done when a creature is summoned.
4. **To the Wild:** "Let's find a monster in the Wild!" (paw trail to the Wild portal). Done in the Wild valley.
5. **Fight:** "Walk up to a monster to fight it!" (paw over the nearest Meadow monster). Done when a fight starts.
6. **In the fight:** "Your creature fights by itself!", then "Tap the Pet button when it's ready!" (paw on it).
   Done when the fight ends.
7. **Win:** "You won! Your creature got XP." / "Lost? Rest it, or bring another card." Then "Come back at shop level 4
   for your sword! Bye!" He leaves.

**Waiting.** Nothing shows until shop level 4. A level 4 reached before visit 1 ends just waits its turn.

**Visit 2, the sword** (at level 4; it replaces Pish's sword lesson):
1. "You got a sword! Now you fight too!" (the first-sword popup comes first, as today).
2. **To the Wild** and **fight**, as in visit 1.
3. **In the fight:** "Tap Attack!" (paw on Attack), then "Tap Dodge when a hit is coming!" (paw on Dodge), then
   "Use your sword's Skill!" (paw on it). Each is done when it's used, or skipped after a few seconds unused.
4. **Win**, then "The Meadow Warden lives through that portal. Beat it for a trophy!" (paw trail to its portal).
   "Bye!" He leaves.

**Afterwards, Town Chikin.** He walks the town like Town Pish, with his own walk round and a "🐾 Chikin" name tag, but
no petting luck (that's Pish's). He hangs about the Wild portal more often. A Chikin tile has no place in the HUD: the
peeking Pish's "tour again?" card gets a second button, "Chikin's fight lesson", once visit 1 is done.

## Reused from Pish

- The talk card (`Util/TutorialTalk`), paw, ring, trail, spotlight, small Skip and tour card (`Util/TutorialCues`),
  and the arrival shot (`Util/ArrivalShot`).
- The step machine: `Util/TutorialRules` takes a step list, so Chikin's is a second list: record, early, doneAlready,
  skip, replay, sendsCustomer-style once-only flags.
- `PishVisual` becomes a dog visual that takes the dog's name (model, clips, sounds, name tag).
- The model pipeline: `prep_pish.py` / `rig_pish.py` copied for Chikin with his bone positions. All 16 of Pish's clips
  (`anim_pish.py`) run on Chikin's rig (same bone names), saved to `assets/monster-animations/Chikin`.
- The Town walker (`PishService`) runs both dogs.

## New

- **During fights:** Pish's cues hide while a fight is on, but Chikin's must show. In a fight his talk card sits at the
  top centre, small, clear of the combat buttons, and the paw points at the combat HUD's buttons.
- **Saved:** a second tutorial table, `combat`, with the same shape as Pish's, and his own step list. Schema v18:
  existing players count as done (they fight already); new players start at "todo". The migration is tested.
- **Analytics:** a funnel "CombatTutorial" (`AnalyticsService:LogFunnelStepEvent`), one step per step.
- **Dev:** `/chikin reset | step <n>`, `/chikin` (Town Chikin comes to you), and an admin panel section.

## Model

From the concept the owner picks (A, B or C): one Meshy image-to-3D generation (about 30 credits; read the balance
first), prepared and rigged with Pish's scripts. He's about Pish's size (`HEIGHT` 2.6) and smooth (no fur spikes),
with the curls as chunky sculpted bumps. The owner imports the FBX in Studio like Pish, and it's saved as
`assets/npcs/Chikin.rbxm`.

## Out of scope

Combat for the Frontier and Dungeon, PvP, the boss rings (the first boss fight already shows the button names for 3
fights), weapons beyond the free sword, and any petting buff from Chikin.

## My calls (for the owner to check)

- (Changed in the build) the player picks the card; a new player has only Pish's pack's few cards.
- Skipping Pish's tour doesn't skip Chikin: fighting matters, and he has his own Skip.
- Visit 2 replaces Pish's sword lesson, so the player doesn't get two dogs saying the same thing.
- Town Chikin has no buff, so Pish's luck stays special.
- A lost first fight still ends visit 1, with the "rest it or bring another card" line. No forced retry.
