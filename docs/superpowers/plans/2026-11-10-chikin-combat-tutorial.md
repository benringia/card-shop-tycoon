# Chikin's combat tutorial: implementation plan

> For agentic workers: executed natively (superpowers:executing-plans). Steps use checkboxes.

**Goal:** Chikin, the owner's second dog, teaches fighting in two visits (after Pish's goodbye: party, summon, the
Wild, a first fight; at shop level 4: the sword's Attack, Dodge and Skill, then the Meadow Warden's portal).

**Architecture:** A second step list on Pish's machinery. `Util/TutorialRules` runs it; a new `CombatTutorialService`
saves it as `data.combat` (schema v18) and publishes `CombatStep` / `CombatDone`. A new `ChikinController` reuses the
talk card, the cues, the arrival shot and a dog visual that takes the dog's name. Steps inside a fight are client-side
(no reward depends on them); the server saves the steps that matter.

**Tech stack:** Luau, Rojo, Lune tests.

**Spec:** docs/superpowers/specs/2026-11-10-chikin-combat-tutorial-design.md

## Global constraints

- Server authoritative for saved steps. The one new remote, `CombatTutorialAction`, takes next / skip / replay, is
  validated and rate-limited, and gives nothing.
- Every line is short and drawable (the TalkRules test covers ChikinTalk too).
- Existing saves count as done unless Pish's tour is still to do (v18 migration, tested).
- His steps: party, summon, wild, fight, firstWin, level4 (a hidden wait), sword, wild2, fight2, boss.

## Review focus

1. A player who already has a party and a summoned creature passes those steps at once.
2. Pish's lessons and nudges never run while Chikin is leading, and the two dogs are never on screen at once.
3. A fight lost, run from or left mid-tour: the tour moves on (no stuck step).
4. Level 4 reached during visit 1 waits its turn. A replay brings nothing new.
5. During a fight, Chikin's card and cues show (Pish's hide) and keep clear of the combat buttons.

### Task 1: Config, rules and the saved table
Files: `src/shared/Config/Chikin.luau` (STEPS, HEIGHT, SOUNDS / SOUND_PITCH / SOUND_VOLUME, ARRIVAL = Pish's,
VISITS {1..5}, {7..10}, FIGHT_TIP_SECONDS), `src/shared/Config/ChikinTalk.luau` (STEPS intro / now, LOST, FIGHT tips,
LABELS), `src/server/Util/Migrations.luau` v18, `Config/Data` SCHEMA_VERSION 18, DataService template `combat`.
Tests: `tests/ChikinRules.spec.luau` (steps, visits, the hidden wait, every line drawable), Migrations v18.

### Task 2: CombatTutorialService
Files: `src/server/Services/CombatTutorialService.luau`, `src/shared/Remotes.luau` (CombatTutorialAction), init
order. It begins once Pish's tour isn't "todo" and SeenWelcome. A 1 s check covers party, summon, the Wild and level 4;
`WildService.OnContact` covers fight / fight2 starting; `BattleService.OnFightEnded` sets ChikinFightResult; actions
cover next (finishing firstWin and boss), skip and replay. Funnel `CombatTutorial`. Dev: `/chikin reset | step <n>`,
admin panel.

### Task 3: Shared client pieces
Files: `Util/TutorialTalk` (speaker(name): his face and name; atTop(on)), `Util/TutorialCues` (quiet(owner, on);
tourCard labels), `Util/PishVisual` (dog param: model, clips, sounds, tag), `Config/Party` CREATURE_STYLE.Chikin.

### Task 4: ChikinController
Files: `src/client/Controllers/ChikinController.luau`. His arrival (`Util/ArrivalShot`, after Pish has gone), the
talk per step, the targets (Cards tile, the strongest card's Add to party, party slot 1, the Wild portal, the nearest
Meadow monster, the Warden's portal), the tips in a fight (at the top, the paw on the combat buttons), Skip and the
tour card. TutorialController: Pish's hand-over line, not free while Chikin leads, the replay card's second button.

### Task 5: Town Chikin and docs
PishService runs both dogs; TownPishController draws both. DESIGN 7.6, CLAUDE.md, vault and memory.
