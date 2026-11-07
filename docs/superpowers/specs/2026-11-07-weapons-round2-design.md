# Weapons, round 2: spears, the quick weapon switch, the sword hold (design)

Owner 2026-11-07: "okay lets do round 2", then "size of the spear, animation, how the character holds the spear. also
update the player on how it holds the sword right now it's awkward and the sword is flat. now that we have other weapon
types. add a quick switch ui to scroll through different types of weapons", "no stance, just make it look not awkward by
holding the sword the right way. not flat. Proceed". Builds on round 1 (`2026-11-06-weapons-round1-design.md`, section 2
"The whole plan") and the sword skills round (`2026-11-06-sword-skills-design.md`).

## 1. Why

Round 1 built the weapon system with swords only. Round 2 adds the second family, so a spear must feel unlike a sword
the moment you press attack: its size, the way it's held and its own moves (long reach, narrow thrusts, a lunge). With
two families a player owns weapons that fight differently, so switching between them has to be one tap, not a trip to
the Armory. And the sword, today held with its flat forward, has to look right before anything is built on its grip.

### Goals
- Four spears that read as spears from across an arena, held upright at your side between moves.
- One shared spear moveset that plays clearly differently from the sword combo, at the same damage a second.
- A quick switch on the HUD: step through every weapon you own, in town, the Wild and boss fights.
- Swords held the right way (done, section 3).

### Non-goals
- Each high spear's own skill and effects: the next round (2.5), like the sword skills round after round 1. This round
  every spear uses one shared skill, Piercing Rush.
- Scythes (round 3), the Forge's own model, PvP weapons, trading or selling weapons.
- Renaming the sword-named code (`Config/Swords`, `SwordController`, the `Sword*` attributes): it now carries every
  family's moveset; a rename is churn with no player-visible gain (my call).

### Anti-goals
- A spear that plays like a long sword (same arcs, same rhythm).
- A spear that beats the sword everywhere: reach is paid for with narrow arcs (spec round 1, 4.6 limits still hold).
- Switching as a free combo extender or a way to dodge skill cooldowns.
- A spear clipping through the ground or towering over the head in town.

## 2. Decided by the owner (2026-11-07, visual companion)

| Question | Pick |
|---|---|
| Quick switch | **A, weapon chip with arrows** (tap the arrows, swipe the chip or press Q) |
| Spear size | **B, Heroic: 8.5 studs** (1.6x a 5.2-stud avatar; the swords are about 5) |
| Spear grip when drawn | **C, one hand, upright at the side**, the butt by the foot; every move starts by swinging it down |
| Concepts | **A for all four** (below) |
| Moves | **OK as storyboarded** (section 5) |

The concept art (Figma, `gpt-image-2.5-flare`, 1024 x 1536) is approved as made; Meshy turned each into a model the same
day (`assets/blender/<Name>/concept_A.png` and `<Name>_raw.glb`, out of git; Meshy credits 1000 before).

## 3. Done: the sword hold

Every sword model has its edge along X and its flat along Z, and the hand grip only tilted it (-140 degrees about X), so
the flat faced forward: in Studio, over the 8 sword moves (3 cuts, the dash slash, 4 skills), the flat led 63-92% of
each swing. `Swords.HAND_GRIP.twist = 90` turns it a quarter turn about the blade after the tilt: the flat faces the
palm, the edge leads 63-92%. Same animations, back placement unchanged. Blender's `anim_kit.hand_grip()` matches, so
every later animation is keyed with the right grip. Commits `90be310`, `246399c` on branch `weapons-round2`; still to
check in Studio with the synced code.

## 4. The spears

| Weapon | Rarity | Element | Source | Length | Concept (A) | Perk (my call) |
|---|---|---|---|---|---|---|
| Forge Spear | Common | any (five, picked when forging) | the Forge, `FORGE_COST` like the Forge Sword | 8.5 | polished steel leaf head, square iron collar with round gems (the element's colour), wood shaft with three steel bands, ring butt cap | none |
| Magma Halberd | Very Rare | Ember | Ember Colossus (material + drops, `BOSS_COST` / `DROP` by rarity) | 8.5 | obsidian axe blade with lava cracks, molten spike tip, back hook, charred shaft, fire gem | **Eruption**: every 5th hit bursts for +60% of that hit |
| Tidal Trident | Epic | Tide | Frost Tyrant | 8.7 | three frosted ice-crystal prongs, sea-glass wave collar, pearl shaft with a silver spiral, aquamarine gem | **Chill**: hits slow the foe's attacks 10% for 3 s (refreshed, no stacking) |
| Titan's Lance | Legendary | Bloom | Masterwork (recipe below) | 9.2 | gold-white lance head with emerald veins, leaf-carved cone guard, living-wood shaft with golden flowers, emerald gem | **Titan's Bloom**: every 4th hit heals your creature 1% of its max HP (tuned from every hit; its own base Power 1.2, as the Prism Blade has its own) |

- Power, grades, upgrades, element bond and Grade S perk (x1.2) work exactly as round 1 (`Config/Weapons`
  `RARITY_POWER` etc.); the catalogue entries already exist with `ready = false` and turn `ready = true`, gaining
  `moveset = "spear"`, a model and a perk. The perk numbers are starting points, tuned with `tools/balance/bosses`
  (`TIER_BOSS`: forgeSpear meadowWarden, magmaHalberd emberColossus, tidalTrident frostTyrant, titansLance prismHydra:
  my call, same tiers as the swords of the same rarity) inside round 1's 4.6 limits.
- The Forge Spear is one model in five element colour maps (`ForgeSpear_<Element>`, ids `forgeSpear_<Element>`, like
  the Forge Sword: `weapon_kit.recolor` on the collar gems and the butt ring, never the head).
- **Titan's Lance Masterwork** (my call, about the Prism Blade's two weeks): $60,000, 30 Warden Heartwood, 20 Frost
  Heart, 20 Storm Crystal, 10 Star Shards. Checked with `tools/economy/sim`-style arithmetic from the
  material drop rates before shipping; the numbers can move, the shape (3 bosses + shards + cash) stays.
- The Armory, the Boss Board, the Forge window and the drop cinematic need no new screens: the spears stop being "Coming
  soon" and show like the swords (card, portrait, glow ladder, sources).

## 5. Holding and the moves

### 5.1 Grip and placement (per family)
- Grips move from one `HAND_GRIP` / `BACK_GRIP` to one per family (`sword` keeps today's values with the twist).
- **Spear in hand**: the model's origin is the right hand's grip, 31% of its length up from the butt, so with the arm
  down the butt rests by the foot and the head stands well over the head (pick C). The two-handed moves (thrust,
  sweep, the finisher's plunge, the rush) bring the left hand onto the shaft with the same IK as the sword finisher's
  (`anim_kit.two_hands`, a point further up the shaft).
- **Spear on the back**: diagonal like the sword, at scale 1 (not the sword's 1.05): its butt must clear the ground on
  every avatar the sword was checked on, and its tip stand no more than 3 studs over the head; steeper than the sword if
  needed (the builder's call within those limits).

### 5.2 The spear moveset (`Config/Swords` entry `spear`, shared by all four spears)
Same damage a second as the sword combo chained (the existing `tests/SwordsConfig` DPS check applies to it). The
numbers are the storyboard's; timings follow the animations' markers.

| Move | What | Hit shape | Notes |
|---|---|---|---|
| Ready | upright at the side, one hand | - | the idle between moves |
| Cut 1, Thrust | swing down into both hands, stab straight ahead with a step | arc, reach 12, 30 degrees | a short lunge like the sword's cut 1 |
| Cut 2, Sweep | pull back low, sweep the head across the front | arc, reach 11, 120 degrees | the group-hitter |
| Cut 3, Sky Pierce | crouch, leap with it raised, plunge tip-first into the ground ahead, pull it out | line, 8 studs to the plunge point, width 3, and a 4-stud burst there (12 in all) | slower, hits hardest (like the sword finisher), a shockwave on the ground |
| Skill, Piercing Rush | crouch and aim, rush 12 studs tip-first, stop upright | dash, 12 studs (max 20 with the existing slack rules), width 3 | power 0.9, cooldown 8: today's skill strength |
| Draw / put away | from the back into the upright guard / back over the shoulder | - | `GRAB_SECONDS` / `RELEASE_SECONDS` style markers |
| Run | holding it upright, slightly forward | - | |
| Dodge, flinch, down, get up | today's body moves, spear in hand | - | reused, checked for the spear clipping the body |

- No spear move reaches past 12 studs, so a boss's swipe (its ring radius + 8) still reaches anyone who can hit it
  (a 12-stud line plus a 4-stud burst would have let the finisher land from outside it; my call, from the plan's review).
- The server checks every hit with `SwordRules` shapes (`line` exists; the finisher's line-plus-burst may need a small
  addition) and `BattleService`, as for swords. Free after the hit (the sword skills round) applies to Piercing Rush.
- Animations are keyed in Blender on `anim_kit` (`anim_spear.py`, the spear prop at its grip), previews shown to the
  owner, `build_kfs`, the owner publishes them, ids into `Config/Swords` (docs/animations.md).
- **Effects** (per spear's colours, like the sword slashes; exaggerated per [[fx-exaggerate]] but readable): the thrust's
  straight streak and tip flash, the sweep's wide arc, the plunge's ground crack and shockwave ring, the rush's trail
  and line of hits. Others see them through the existing SwordCast path, lite version in crowds.
- **Sounds**: licensed Pro Sound Effects only (thrust whoosh and stab, sweep whoosh, leap, plunge impact, rush), measured
  into `Config/SoundLevels` (the `tests/SoundLevel` gate) and kept quiet.
- The HUD skill button for spears: Piercing Rush's own icon, name and tooltip (`Config/CombatHud` SKILLS keyed by
  moveset), from an existing spare icon or the next icon sheet.

## 6. The quick weapon switch (pick A)

- **Where**: a round chip on the right edge, at mid height (clear of the thumbstick, the jump button, the bottom tiles
  and the boss-fight buttons), shown whenever you own two or more weapons; hidden while a `UIKit.panel` window is open.
- **What it shows**: your equipped weapon's portrait in a ring of its rarity colour, with a small `<` and a `>` either
  side (each tap target at least 48 px), a key badge "Q" on keyboards. After a switch, the weapon's name shows under the
  chip for 1.5 s.
- **How**: tap `>` or Q: the next weapon; tap `<` or Shift+Q: the previous; swipe the chip left or right does the same.
  The list is every weapon you own, ordered swords, spears, scythes, then by rarity (Common first), then name; it wraps.
- **The switch**: one `EquipWeapon` request to the server, which validates ownership and rate (today's
  `EQUIP_COOLDOWN`). The character puts the old weapon away and draws the new one with the draw move; the HUD's skill
  button changes to the new moveset's.
- **In a boss fight** (my call, on the mockup): allowed, but a switch takes `SWAP_SECONDS = 1` during which you can't
  attack or use the skill (the dodge still works); the combo restarts; the skill's cooldown is one timer shared by every
  weapon (switching never resets it). The server enforces all three (`BattleService`): a hit or skill request inside the
  swap is refused.
- The Armory's Equip button stays; both go through the same request.

## 7. Models

- The four `_raw.glb` exist (section 2). A spear cleanup in `tools/blender/weapon_kit.py` (a spear mode or a sibling
  kit): about 4,000 triangles and one 1024-pixel colour map (as the swords), scaled to its length (section 4), split
  into **Head** (blade, prongs or axe head plus collar) and **Shaft** (with the butt), the grip point (31% up from the
  butt) on the origin, the head up +Y. One `build_weapon_<id>.py` per spear; the `.blend` saved without `_Src`, orphans
  purged, no key fields.
- The owner imports each FBX; `finish_sword` (or a renamed `finish_weapon`) straightens pivots and sets the PrimaryPart;
  `forge_variants` writes the Forge Spear's five copies. Glow maps (`make_glow_maps.py`: the Magma Halberd's lava cracks,
  the Trident's crystal prongs and gem, the Lance's emerald veins and flowers, the Forge Spear's gems), portraits
  (rendered on magenta, cut out) and `Config/WeaponLooks` entries (glow, deep, trail colours) as for the swords. The
  glow ladder, auras and sparkles apply unchanged; the aura follows the head, not the whole shaft.
- Until a model is in, today's tinted stand-in, at spear length.

## 8. Saves, security, performance

- No saved-shape change: spears are weapons in the existing `weapons` table (`ready` was the only gate). No schema bump.
- Every request stays server-validated: equip ownership, swap timing in fights, hit shapes recomputed on the server.
- One more moveset's animations and sounds preload with the equipped weapon only (as today); an 8.5-stud model at about
  4,000 triangles costs the same as a sword. The aura budget (`BUDGET.nearest`) is unchanged.

## 9. Left to the builder
- Exact animation timings and markers, the effects' look within section 5.2, the sound picks.
- The back angle within 5.1's limits; the chip's exact size and spacing within section 6.
- How the finisher's line-plus-burst is expressed in `SwordRules` (a new shape kind or two checks).
- Whether the spear cleanup is a mode of `weapon_kit` or its own kit.

## 10. Calls I made (for the owner to check)
- Each high spear's own skill waits for round 2.5; Piercing Rush is every spear's skill now.
- The perks (Eruption, Chill, Titan's Bloom) and their numbers.
- The Titan's Lance recipe ($60,000, 30 Warden Heartwood, 20 Frost Heart, 20 Storm Crystal, 10 Star Shards).
- Lengths 8.5 / 8.5 / 8.7 / 9.2 (your 8.5, the top two a little bigger).
- The grip point at 31% of the length from the butt; spears on the back at scale 1.
- Switching in fights: 1 s, no attacks, one shared skill cooldown; Shift+Q for the previous weapon.
- The tier bosses used to balance the spears.
- The code keeps its sword names.
