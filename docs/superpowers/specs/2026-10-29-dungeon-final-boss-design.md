# The Dungeon and the final boss (boss ladder phase 4)

Phase 4 of `2026-10-28-boss-ladder-design.md` (read that spec and DESIGN.md 5.10 first: this one builds on both and
keeps every rule they set unless it says otherwise). Agreed with the user on 2026-10-29. Calls marked **(Claude's
call)** were proposed without the user choosing them; change them freely.

## 1. Intent

The final boss is the last step of the ladder and the end of the battle side's first arc (roughly 30-45 hours in for a
dedicated player, spec section 11). It should feel like an expedition, not boss 6 again: a run through a Dungeon where
your party wears down room by room, ending at a godlike boss that tests everything the ladder taught. Beating it is a
big, visible moment, and the game goes on afterwards (the shop keeps running, the Dungeon can be replayed).

## 2. Goals, non-goals, anti-goals

Goals
- A third place, the Dungeon, reached from the Frontier's Dungeon portal (today "coming soon").
- A run: three rooms of elite monster packs, then the final boss. Creatures keep their damage from room to room.
- The final boss, the Prism Hydra: phases that switch its element and use every mechanic of the ladder.
- A blocky Blender model of the Hydra (a remodel of the bought Crystal Titans Rainbow Hydra) with our own rig and
  real animation (each neck moves on its own).
- The conquest moment: death scene, full-screen "DUNGEON CONQUERED", an announcement, a trophy, a title, a big chest.
- Replayable afterwards for loot, under the same farm protection as the other bosses.

Non-goals (later, noted in DESIGN.md section 13)
- Heroic tiers (stronger repeat runs, a leaderboard). Not decided; backlog.
- The ranch: a place to show creatures off (user: "just for showing off"), its own project after phase 4, unlocked
  early in the main game; clearing the final boss adds a special Legendary habitat there.
- New monster models for the rooms; a Meshy model for the Hydra (Meshy credits stay for creatures).

Anti-goals (would make it a failure even if it works)
- A guaranteed win for a maxed party, or an impossible one for the recommended party (spec: balanced for a Legendary
  at Lv 30, 4-5 stars, grade A/S; never a guaranteed kill, like the Frontier tuning).
- Rooms that are a better farm than the Frontier, or loot that can be gained without beating the boss.
- Losing progress unfairly: fragments are never lost on a lost run; a failed teleport never costs anything.
- A messy shared space: runs never overlap or block each other.

## 3. Getting in

- **The place:** a third place in the experience. The user creates it in Creator Hub (Claude can't) and gives its id;
  it goes in `Config/Places` as `DUNGEON_PLACE_ID` (0 keeps the portal "coming soon", like the Frontier was). A
  `dungeon.project.json` syncs it (its own port, Workspace attribute `PlaceKind = "Dungeon"`); `Util/Place` learns
  `isDungeon()` and the entry scripts start only the Dungeon's services there. Same `src`, same saves (DataService
  and the teleport pattern of FrontierService).
- **The key:** the Rift Devourer now drops `fragment_prismHydra` (and its first clear gives 3, like the others); the
  first entry needs 10. As for every boss, the key is consumed only when the Hydra fight starts for the first time;
  after that the boss is open for good. A lost run or a lost first fight never costs fragments **(Claude's call:
  checked at the portal, taken at the boss)**.
- **Shop level:** the Hydra needs shop level 22 (user agreed to the guess; `shopLevel`, `BossRules.levelReady`).
- **The portal:** in the Frontier, "Enter" (alone) or "Start group" / "Join group" with the same lobby rules as boss
  gates (2-4 players, 15 s to join, the leader can start early). Every member is checked (shop level, key or open,
  a rested party card) before the teleport.
- **One run per server (Claude's call):** each run teleports its player or group into a reserved Dungeon server of its
  own (reserved servers), so runs never meet. Reserved servers only work in the published game: in Studio the
  Dungeon window (PlaceKind attribute) starts a run directly through a dev command.

## 4. The run

- **Layout:** a dark prism-crystal cavern built in code like the arenas: coloured light shafts, crystals, an entrance
  hall, three rooms in a line, then the Hydra's chamber. Each room is a sealed ring like a boss arena (same barrier
  and intro rules, a shorter intro); winning a room opens the way to the next.
- **Rooms:** each is one group fight against a pack of 2-3 elite monsters (existing Frontier species, about Lv 45-50,
  mixed elements so one strong type can't carry you) on the existing combat core (BattleSim already fights several
  enemies, as with the Rift Spawn). Packs get stronger room by room. Group scaling as for bosses **(Claude's call)**.
- **Damage carries over:** within a run each creature keeps its current HP from room to room (run state on the
  server, never saved). Fainted creatures stay out for the rest of the run (and rest as usual). No healing spring,
  no healing between rooms. Party cards not yet used come in fresh. Swaps and call-ins work as in boss fights.
- **Losing:** a player whose party is all fainted stays in that fight until it ends, like today's group boss fights
  (so a member who fell late still gets the win, its loot and the first clear if they contributed), and only then is
  out of the run and returns to the Frontier; the rest of a group carries on. Leaving the server ends your run. A run
  with nobody left closes its server **(Claude's call)**.
- **Room rewards (Claude's call):** each room win gives the normal elite XP and cash, but no cards and no items. All
  items come from the Hydra.
- **Tuning target:** the recommended party reaches the Hydra with roughly two thirds of its HP; a party well under
  the recommended Power usually falls in room 2 or 3.

## 5. The final boss: the Prism Hydra

- **Name and title:** Prism Hydra, "Crown of Every Element" (id `prismHydra`, place `"Dungeon"`, ladder position 7).
- **Phases by HP, one per element (Claude's call: five phases, so every mechanic and every element of the ladder
  appears; the playback said four):**

  | HP | Element | Mechanic (the same rules as bosses 2-6) |
  |---|---|---|
  | 100-80% | Tide | ice shield (boss 4) |
  | 80-60% | Volt | thunderclap (boss 5) |
  | 60-40% | Shade | adds: Rift Spawn (boss 6) |
  | 40-20% | Bloom | heals below a threshold (boss 2) |
  | under 20% | Ember | enrage (boss 3) |

  Each phase change: a banner ("Volt phase!"), a camera shake, the active head lights up, and element weakness
  switches to the new element. BattleSim needs phases: a list of HP thresholds, each with its element and its
  mechanics (today's mechanics are always on), Lune-tested like the others.
- **Numbers:** in `Config/Bosses` like every boss (level about 55, shop level 22, 10 fragments). Recommended Power
  about 2400 (a Lv 30 Legendary at 4 stars grade S; the maxed card is 2614). Tuned with `tools/balance/bosses`,
  which learns the gauntlet (HP carried in from three rooms) and the phases, against these targets
  **(Claude's call, following the Frontier tuning the user accepted: "not a guaranteed kill")**, solo, after the rooms:
  - "best+2" (one Legendary at the recommended Power, two at 60%): wins about 50-60%;
  - "maxed+2" (one maxed Legendary, two Lv 1 cards): wins at most about 50%;
  - three Legendaries at the recommended Power: wins about 75-85%; three maxed: never more than about 90%.
  - Groups: the same rule as bosses 4-6 (stronger boss, easier kill, never guaranteed).
- **The 30-45 h target:** checked by a rough estimate, not a new simulator (the economy simulator has no boss
  model; building one is out of scope). If the estimate says shop level 22 lands far outside it, lower the Hydra's
  shop level and say so **(Claude's call)**.
- **Rewards:**
  - Drops: Gold Seals, Star Shards, Grading Seals and XP Tonics; no fragments (it's the last boss).
  - A daily bonus, as for the others.
  - Ground loot as for the others: walk over it, nothing is collected by itself.
  - The first-clear chest, "a big chest of everything": trophy, several of each item, a large cash and XP payout.
    It goes straight into the Bag.
- **After the fight:** a portal back to the Frontier opens in the chamber. Players pick up their loot, then leave.
- **Replays:** the usual loot cooldown, daily soft cap, over-power penalty and contribution rule.

## 6. The model

- A blocky remodel of the Crystal Titans Rainbow Hydra (bought, now unused), built by
  `tools/blender/build_prismHydra.py` on `voxel_kit.py`, like the blocky originals (docs/creatures.md "Original
  models"). It should look godlike and big (the biggest boss): a fat, heavy body on four legs (not a dragon's build),
  a crystal crown on its back, five necks.
  - Every head is a crystal head in the same prism look. Each belongs to one element (Ember, Tide, Bloom, Volt,
    Shade) but glows its element colour only while its phase is active: one coloured head at a time, never a rainbow
    of five dragon heads.
  - Why (user's choice): five heads in five colours on a four-legged body reads as Tiamat (Dungeons & Dragons). The
    shared crystal look, the crown and the heavy body keep it ours (the avoid-famous-lookalikes rule).
- The rig: our own skinning (`rig_kit.py` style), with the PetRig role names the code already drives:
  - `Pelvis`, `Spine_*` and the legs;
  - the necks as `Hydra_<head>_<bone>`: PetRig already sways each neck on its own beat and snaps its jaws.
- The user imports the FBX, and it's saved as `assets/monsters/prismHydra.rbxm`: boss models load from MonsterModels
  by boss id.
- MonsterController doesn't animate bones today. For the boss model it starts the creature animator (PetAnimator and
  PetRig), plus these moments:
  - a roar on the intro and at each phase change;
  - the active head rearing up;
  - the death scene: the heads fall one by one.
- Until the model exists, a placeholder shape.

## 7. The conquest moment

- **Death scene:** a few seconds long. The heads collapse one at a time, then a full-screen "DUNGEON CONQUERED" on a
  first clear ("Victory" on later wins).
- **Announcement (Claude's call):** a first clear sends a message to every server of the experience (cross-server
  messaging), "Ben conquered the Dungeon!". It comes once per player, so it can't spam. Inside the reserved server
  the group sees it as well.
- **Trophy:** `trophy_prismHydra`, placed through Build → Trophies like the others, with a prism-coloured gem.
- **Title:** "Dungeon Conqueror" shown over the player's name in every place. It comes from the saved first clear of
  the Hydra (`bosses.prismHydra.cleared`), so it needs no new saved data.

## 8. Everything else that changes

- **The boss board** lists 7 bosses. The Hydra row shows "(the Dungeon)", its phases in short and its shop level.
- **The Frontier portal** sign changes from "coming soon" to the Dungeon's name.
- **Dev commands (Studio):** `/boss 7` and a run starter for the Dungeon window. Both are also buttons in the admin
  panel.
- **Docs:** DESIGN.md 5.10 (the Hydra row, the Dungeon, the run rules), section 13 (Heroic tiers, the ranch),
  CLAUDE.md (the new project file, port, commands and tests), and the Obsidian vault.

## 9. Left to the builder

- The order of the work, and how to split it into tasks.
- Room layouts and sizes, which species go in each pack, their exact levels, and the room rewards' amounts.
- All final numbers (stats, drop chances, chest contents, the phase mechanics' timings), set from the simulators
  against the targets above.
- The model's proportions and palette, and the exact animation poses, within the look described above.
- How the run's state and the reserved-server hand-off are coded, within the rules above (server authoritative,
  remotes validated and rate-limited, all numbers in `Config`, pure rules in Lune-tested modules).

## 10. Constraints

- The user approves each step in Studio before merging.
- Studio can't teleport or reserve servers, so everything must also be testable in a Dungeon window (PlaceKind
  attribute, dev commands).
- No new saved shape is expected. If one turns out to be needed: bump `SCHEMA_VERSION`, add a migration with a Lune
  test, and update DESIGN.md 10.4.
- UI is mobile-first and uses only ASCII, `·` and emoji (fonts draw other symbols as boxes).
- The boss audio stays the quiet ambient drone (`MUSIC_ID`, volume 0.1).
