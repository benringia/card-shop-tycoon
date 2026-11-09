# Weapons round 3: the scythes

Date 2026-11-09. Owner's brainstorm the same day; storyboards and concepts on
https://claude.ai/artifact/PCJiVgqYze5xDJrxcSxzFX. Builds on rounds 1 (swords, the weapon system), 1.5 (sword
skills), 2 (spears, the quick switch) and 2.5 (the boss spears' own skills). Everything those rounds settled applies
unless this document says otherwise: Power, grades, upgrades, element bond, the Armory, the Forge window, the drop
cinematic, the glow ladder, grips per family, `SwordRules` hit shapes checked on the server, free after the hit, the
one 12 s skill cooldown that starts full when a fight opens, sounds licensed and measured, animations keyed in Blender
and published by the owner.

## 1. Intent

The third and last weapon family. In the owner's words: "epic. I want exaggerated moves, wide slashes in all
directions", "a bit slower but still flashy", and an own skill for every boss scythe. Scythes are the group weapon:
where the sword is all-round and the spear reaches far in a line, a scythe hits everything round you, in front and
behind, with big slow sweeps and long trails. Kids should feel like a reaper.

Success: the four scythes are in the game like the swords and spears (forge or boss drop, Armory, quick switch, Forge
upgrades), they play differently from both other families, and each boss scythe's skill is a spectacle that grows with
its rarity.

## 2. Decided by the owner

| What | Decision |
|---|---|
| Feel | epic, exaggerated, wide slashes in all directions; a bit slower than the sword but still flashy |
| Skills | each boss scythe its own skill; the Forge Scythe has the basic scythe skill |
| Moves | as storyboarded (section 5) |
| Forge Scythe skill | Reaping Cyclone |
| Widow's Reaper skill | B, Eight Legs |
| Storm Reaper skill | B, Storm Cyclone |
| Rift Reaper skill | B, Thousand Cuts |
| Concepts | B for all four (section 4) |
| Thousand Cuts' vanish | half-faded and still hittable, like every other skill (no untouchable moment) |
| The Forge machine's own model | later, not this round |

## 3. Goals, non-goals, anti-goals

- **Goals**: the four scythes made `ready`, with models, portraits, glow maps, a `scythe` moveset, four skills, perks,
  sounds, HUD skill buttons, admin preview buttons, balance inside round 1's limits.
- **Non-goals**: the Forge machine's own model (the owner: later), PvP weapons, trading weapons, new screens (the Armory, Boss Board, Forge window and drop cinematic
  already list scythes as "Coming soon" and only need them to become ready), changes to swords or spears.
- **Anti-goals**: a scythe that plays like a slower sword (narrow cuts in front); effects so dense that the boss's ring
  warnings can't be read; a skill reaching so far that a player hits the boss from outside its swipe (moves stay inside
  12 studs; skills may go further, as Titan's Wrath's 14).

## 4. The scythes

| Weapon | Rarity | Element | Source | Length (studs) | Concept B | Perk (my call) |
|---|---|---|---|---|---|---|
| Forge Scythe | Common | any (five, picked when forging) | the Forge, `FORGE_COST` | 8 | hammered steel blade with a notched back, iron socket with three round white gems (the element's colour), banded ash shaft, iron spike butt | none |
| Widow's Reaper | Very Rare | Shade | Cave Brood Queen (material + drops by rarity, as the spears) | 8.3 | purple chitin blade with spider-leg spikes along its back and a lilac edge, a spider-body socket with eight glowing eyes, silk-bound black shaft, fang butt | **Venom**: hits poison the foe, 2.5% of your creature's ATK a second for 3 s, refreshed (the Sunforged Blade's `burn` mechanics) |
| Storm Reaper | Epic | Volt | Storm Sovereign | 8.6 | dark steel crescent split by a glowing yellow lightning crack with a cyan edge, a golden thunderbird socket with a yellow gem, navy shaft with gold bands, lightning-bolt butt | **Chain Lightning**: every 4th hit calls a bolt on the target for +40% of that hit, and the bolt arcs to every other foe in the fight for 30% (a new `chain` perk kind; it works against a lone boss too) |
| Rift Reaper | Legendary | Shade | Rift Devourer | 9 | huge obsidian blade cracked with violet rift light, dark crystal spikes, a giant purple eye gem in a silver and black collar, black shaft with glowing purple rune bands, silver crescent butt | **Reap**: +30% damage to foes under 30% of their HP (a new `execute` perk kind) |

- The concept images are `assets/blender/<Name>/concept_B.png` (Figma `rd1ves753oagkIGEJgV4qC`, nodes 142:3, 142:5,
  142:7, 142:9; out of git). The A images sit beside them.
- Catalogue entries exist with `ready = false`; they turn `ready = true` and gain `moveset`, a model and a perk. Power by
  rarity as round 1 (`RARITY_POWER`); a weapon gets its own base Power only if balance needs it (as the Prism Blade and
  Titan's Lance did).
- Balance tiers (`Weapons.TIER_BOSS`, my call, the swords' and spears' tiers by rarity): forgeScythe meadowWarden,
  widowsReaper emberColossus, stormReaper frostTyrant, riftReaper prismHydra. Perk numbers are starting points, tuned
  with `tools/balance/bosses` inside round 1's limits. Most fights have one foe (Wild monsters, most bosses; only the
  Rift Devourer and the Prism Hydra's Shade phase bring adds), so a scythe must hold the sword's damage a second against
  one foe: its "all directions" is the look and the extra reach round you, not extra damage. The balance rows to watch
  are the single-foe ones, plus the Rift Devourer with its adds.
- The Forge Scythe is one model in five element colour maps (`ForgeScythe_<Element>`, ids `forgeScythe_<Element>`, the
  socket gems and butt recoloured, never the blade), like the Forge Sword and Spear.
- The two new perk kinds are simulated in `BattleSim` (server) and counted by the balance tools.

## 5. Holding and the moves

### 5.1 Grip and placement (my calls)
- **In hand, at rest**: upright at the side in one hand like the spear, the blade over your head curving back, the
  grip about a third up the shaft. Every swing brings the second hand onto the shaft (`anim_kit.two_hands`).
- **On the back**: diagonal like the spear, the blade over the shoulder pointing outward, the butt clear of the ground
  and the blade no more than 3 studs over the head on every avatar the spear was checked on.

### 5.2 The scythe moveset (`Config/Swords` entry `scythe`, shared by all four)
Each cut about a third slower than the sword's, so the combo's damage a second against one foe equals the sword's (the
existing `tests/SwordsConfig` DPS check applies; every cut reaches a foe in front of you). Big wind-ups, wide sweeps, long trails in the scythe's colour.

| Move | What | Hit shape |
|---|---|---|
| Ready | upright at the side, one hand | - |
| Cut 1, Reap | wound back, one huge sweep across your front | arc, reach 10, 180 degrees ahead |
| Cut 2, Back Sweep | turning, the blade carves round behind you and comes through your front again | arc, reach 10, 180 degrees ahead (my call after the builder check: every cut soft-aims you at the foe, so a hit behind you would miss the lone foe of most fights; the swing's look wraps behind you, its damage lands as it comes through the front) |
| Cut 3, Whirlwind (finisher) | two full spins, a ring of light all round you, a shake | spin, radius 10 |
| Draw, put away, run, dodge, flinch, down, get up | as the spear's, scythe in hand, checked for clipping | - |

### 5.3 The skills
Every skill: 0.9 of a hit in total, the shared 12 s cooldown, a dodge or switch before the hit cancels it, free after
the hit, you never move. Size follows rarity, as with the spears (Very Rare simpler, Epic bigger, Legendary biggest
with a camera moment). Effects exaggerated (the owner's standing taste), lighter for other players' casts.

- **Reaping Cyclone** (Forge Scythe, and every scythe until its own exists): three spins, each throwing a ring of
  element crescents outward; the third ring is the hit. Spin, radius 9.
- **Eight Legs** (Widow's Reaper): your shadow pools under you, eight ghost scythe blades rise round you like a
  spider's legs and slash outward in every direction, then curl shut and sink back. Spin, radius 9. A solid shake.
- **Storm Cyclone** (Storm Reaper): you spin faster and faster into a lightning tornado that throws lightning
  crescents in every direction, then bursts. Spin, radius 11. A big shake and a camera pull-back.
- **Thousand Cuts** (Rift Reaper): you sink into a rift (half-faded, ghostly; you don't move and you can still be hit,
  the owner's call), dozens of purple slashes cut
  across the area from every direction, then you reappear with one enormous cross slash. Spin, radius 14. The biggest
  shake and a camera moment.

Each skill: its own animation (Blender, published by the owner), sounds, HUD button icon and name (`Config/CombatHud`
SKILLS by moveset), an admin "Sword skills" button and a `/skillfx` name.

### 5.4 Thousand Cuts rebuilt round a Grim Reaper (owner 2026-11-09, after part 1)

The owner, seeing the Rift Reaper with Reaping Cyclone: "the legendary scythe skill is boring. make it flashy violent,
exaggerated. you can even summon a grim reaper as effect. screenshake. ground breaking anything to make it legendary".
The storyboard (Thousand Cuts with the Grim Reaper, five beats) and Grim Reaper concept B (the void reaper king:
crystal crown, one slit eye, the Rift Reaper's eye gem in its chest, armour, a cape fading into smoke) were approved
("go"). It replaces the Thousand Cuts above and comes before the other two boss skills (part 2a).

- **Rules** as every skill: 0.9 of a hit in total, landing once at the harvest on every foe within 14 studs (`spin`);
  the shared cooldown; a dodge or switch before the hit cancels it; free after the hit; you never move and can always
  be hit (the fade is only a look). The Rift Reaper's own moveset (`Config/Swords riftReaper`): the scythe's cuts,
  moves and sounds, its own skill, animation and looks (as the Titan's Lance's).
- **Beats** (about 2.6 s): 1. charge: the scythe raised, violet cracks racing across the ground to 14 studs, the sky
  darkening (your own), a rumble building; 2. the rift: the ground splits open behind you and the Grim Reaper (about 16
  studs, ghostly see-through violet, floating on smoke, holding a giant copy of the Rift Reaper) rises out of it, souls
  swirling, the camera pulling back; 3. a thousand cuts: you fade half into the rift; waves of violet slashes rip across
  the area from every direction, slabs of ground heaving up, a jolt on each wave; 4. the harvest (the hit): you
  reappear with an X slash as the Reaper sweeps its giant scythe a full circle round you; the ground erupts (shockwave
  rings, flung rocks, a pillar of light), the biggest shake in the game; 5. aftermath: the Reaper bursts into smoke and
  rising souls, the cracks glow and close.
- **Camera**: your own cast gets a camera moment framed on you (pull back for the rise, a wide shot through the
  harvest, back). Other players see a light version (fewer slashes and particles, no darkening, the Reaper kept).
- **Making it**: the Reaper from Meshy (concept B), cleaned in Blender, imported by the owner, the giant scythe a scaled
  copy of the Rift Reaper model; the player's move keyed in Blender and published by the owner; the Reaper itself moves
  by code (rise, hover, its harvest spin, dissolve: no rig). Sounds licensed and measured. The HUD button "Thousand
  Cuts" with the Skull glyph (my call: an existing white icon that reads as the reaper).

## 6. Making the models and pictures

- Meshy image-to-3D from each concept B (about 30 credits each, about 120 in all; check the balance before starting and
  say it to the owner), cleaned with `tools/blender/weapon_kit.py` (a scythe mode or sibling to the spear's), the Forge
  Scythe recoloured five ways. The owner imports the FBX files in Studio as for the spears.
- Glow maps, portraits (rendered in Studio, cut out, uploaded), Armory cards, `WeaponLooks` colours: as round 2.

## 7. Order of work (my call)

Like rounds 2 and 2.5, in two parts, each merged when the owner has judged it in Studio:
1. **Part 1**: the models, the moveset and its effects, Reaping Cyclone on all four scythes, perks, portraits, glow
   maps, the scythes made `ready`, balance.
2. **Part 2**: Eight Legs, Storm Cyclone and Thousand Cuts on their scythes.

## 8. Left to the builder

Exact timings, effect counts and colours, sound picks, icon choice, perk numbers within the balance limits, how the
arc's facing offset is written, the Blender keyframes, and anything else not fixed above.
