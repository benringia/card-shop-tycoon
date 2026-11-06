# Weapons, round 1: swords, the Forge, boss materials, the Armory, drop cinematics (design)

Owner: Ben. Written 2026-11-06 from the brainstorm the same day (chat). Status: for the owner's review.
Related memory and earlier decisions: weapon families (2026-11-04), the sword-moves round (sword combo, dash skill),
the boss ladder (Config/Bosses), the binder (3D binder, set tabs), the pack opening stage.

## 1. Why

Kids love epic weapons. Today everyone fights with one Steel Sword whose only stat is Power 1, and the bosses pay
cash and items with nothing big to spend them on. Weapons give the game a long chase that sits on top of the shop loop:
a reason to farm bosses (each drops its own weapon material), a cash sink (the Forge), something to flex (glow on your
back, a Grade S +10 Legendary), and a tie to the two things the game is about: **cards** (weapons are shown, graded and
collected like cards, in the binder) and **creatures** (a weapon bonds with a creature of its element).

Success, in the owner's words: weapons that look epic, are valuable, and are **not easy to obtain**. Pace approved:
a Rare boss weapon in about 2 days of regular play, a Legendary in about 2 weeks.

## 2. The whole plan and this round

Three weapon families, each with its own move set (owner 2026-11-04): **swords** (fast, all-round), **spears** (long
reach, narrow thrusts, a lunge), **scythes** (wide slow sweeps that hit groups). Twelve weapons in all, every one its
own model with its own glow:

| | Common (Forge) | Mid | High | Top |
|---|---|---|---|---|
| Swords | Steel Sword (starter, exists), **Forge Sword** | **Verdant Blade**, Meadow Warden: Rare, Bloom | **Sunforged Blade**, Masterwork: Epic, Ember | **Prism Blade**, Prism Hydra: Legendary, all five elements |
| Spears | Forge Spear | Magma Halberd, Ember Colossus: Very Rare, Ember | Tidal Trident, Frost Tyrant: Epic, Tide | Titan's Lance, Masterwork: Legendary, Bloom |
| Scythes | Forge Scythe | Widow's Reaper, Brood Queen: Very Rare, Shade | Storm Reaper, Storm Sovereign: Epic, Volt | Rift Reaper, Rift Devourer: Legendary, Shade |

**Round 1 (this design) builds the whole weapon system and the four new swords** (bold above): the data and saves,
rarity / grade / upgrades / element bond / perks, the Forge, the boss materials (all seven, so players start banking
for later weapons), the Armory tab in the binder (all twelve weapons listed, spears and scythes marked "Coming soon"),
the Boss Ladder showing each boss's weapon, the glow ladder, the forge reveal and the drop cinematic.
Rounds 2 and 3 add the spears and the scythes: their models, their own move sets (like the sword-moves round) and
their config entries; nothing else should need building then.

### Goals
- Four new swords that look as epic as the owner's reference (stylized, ornate, glowing: the AssetBlox "17 stylised
  swords" thumbnail), each with its own glow, perk and slash colours.
- A weapon system any later weapon slots into by config and a model.
- A long, visible chase: materials from bosses, progress shown on every weapon, upgrades that visibly add glow.

### Non-goals (later or never in this round)
- Spear and scythe models and moves (rounds 2 and 3).
- A PvP Arena weapon (the owner plans a PvP ladder there instead).
- Selling weapons for Robux, trading weapons between players, selling weapons to shop customers, the phone.

### Anti-goals (would make this a failure even if it works)
- Plain-looking weapons (the owner turned down the plain store packs).
- Weapons that are quick or easy to get.
- A best weapon that makes the bosses trivial (see 4.6).
- A screen full of particles: glows piling up until nothing reads, or frame rate dropping in town.

## 3. What a weapon is

Every weapon has, fixed per weapon (Config, plain data so Lune tests can load it):
- **Family**: sword, spear or scythe (decides the move set, grip and back placement; round 1: swords only).
- **Rarity**: Common, Rare, Very Rare, Epic, Legendary (the card rarities). Sets its base Power and its resting glow.
- **Element**: one of the five card elements (Ember, Tide, Bloom, Volt, Shade); the Prism Blade is all five; the Steel
  Sword has none. Forge weapons: the player picks the element when forging (3.3).
- **Signature perk**: one small effect of its own (3.4).
- **Look**: its model, its slash/trail colours (today's `slash` field), its aura and its +10 "Awakened" effect.

And per copy the player owns (saved):
- **Grade** C/B/A/S, rolled when the weapon is made (forged or dropped), like cards.
- **Upgrade level** +0 to +10.

One copy per weapon. Making a weapon you already own instead rolls a new grade and keeps the better one (a "reforge":
the chase for Grade S). A weapon that drops while you own it turns into 10 of its material (my call).

### 3.1 Power
Sword damage today is the summoned creature's ATK x the cut's power x the sword's Power (`BattleSim.swordHit`); the
Steel Sword's Power is 1. A weapon's Power = its rarity's base x its grade x its upgrades:
- Base by rarity (starting numbers, to be tuned in 4.6): Common 1.15 (the Steel Sword stays 1), Rare 1.35, Very Rare
  1.55, Epic 1.8, Legendary 2.1.
- Grade: C x1.00, B x1.05, A x1.10, S x1.15. Grade odds per rarity: the cards' (BeastRules grade roll), so a Grade S
  Legendary is as rare as a Grade S Legendary card.
- Upgrades: +5% each, so +10 is x1.5.

### 3.2 Element bond and the element wheel
- **Bond**: when your summoned creature shares the weapon's element (the Prism Blade bonds with any), your weapon hits
  do x1.15 and your sword hits fill the super meter x1.5 (`Combat.SUPER_METER.sword`).
- **The wheel**: weapon hits use the same element wheel as creatures (`Combat.BEATS`, x1.5 strong / x0.75 weak) against
  the foe's element (my call: it makes the element choice matter in fights, and players already learn it from
  creatures). The Prism Blade always counts as the element strong against the foe's current one (the Hydra changes
  element by phase).

### 3.3 The Forge weapons
The Forge Sword (round 1; the spear and scythe later) comes in the five elements, each its own weapon (its own Armory
pocket, its own grade and level; my call: so a player can keep one for each creature they bond with). One Meshy model,
recoloured in Blender into the five versions (gem, trim, glow colour). They're Common.

### 3.4 Perks (round 1)
Small, readable, and shown in words on the weapon's card (like card skills, `Util/SkillText`):
- Steel Sword: none.
- Forge Sword: none (its element and bond are its edge).
- Verdant Blade (Bloom): every 4th hit heals your creature 2% of its max HP.
- Sunforged Blade (Ember): hits set the foe burning, 3% of your creature's ATK a second for 3 s (refreshes, doesn't
  stack).
- Prism Blade (all elements): always strong against the foe's current element (3.2); its trail shifts to that colour.
Grade S makes the perk's number 20% stronger. The numbers are starting points for 4.6.

### 3.5 Moves
Round 1 swords use today's sword moves (the 12-move set from the sword-moves round) with their own slash and hit
colours and their own aura; giving each sword its own combo is a later animation round (my call, to keep round 1 to
one system). Each family gets its own move set in its round.

## 4. Getting weapons (hard, on purpose)

### 4.1 Boss materials
Each boss drops its own weapon material, an account-bound Bag item (`Config/Items`) like fragments:

| Boss | Material (names are my suggestions) |
|---|---|
| Meadow Warden | Warden Heartwood |
| Cave Brood Queen | Brood Silk |
| Ember Colossus | Colossus Core |
| Frost Tyrant | Frost Heart |
| Storm Sovereign | Storm Crystal |
| Rift Devourer | Rift Shard |
| Prism Hydra | Prism Scale |

All seven drop from round 1 on, so players bank them for the spears and scythes. They drop **only with full loot**
(today's rules: once per `LOOT_COOLDOWN` 15 minutes per boss, the daily soft cap after 6 rewarded kills, the over-power
shrink, a carried group member's quarter chance), as a new entry in each boss's `drops`. Starting numbers: chance 0.8,
1 to 2 each; tuned so a Rare boss weapon takes about 2 days of regular play and a Legendary about 2 weeks (4.6). The
boss's daily first-win chest adds 2 of its material.

### 4.2 Costs
| Weapon | Cost (starting numbers) | Pace |
|---|---|---|
| Forge Sword | $1,500 and 20 Wild Ore; from shop level 6 | a few hours |
| Rare boss weapon | 15 of its boss's material and $2,000 | about 2 days |
| Very Rare | 25 and $5,000 | |
| Epic | 40 and $12,000 | about a week |
| Legendary | 60 and $30,000 | about 2 weeks |
| Masterwork (Sunforged Blade, Epic) | 20 Colossus Core, 10 Warden Heartwood, 10 Brood Silk, 5 Star Shards, $25,000 | the longest Epic |
| Reforge (a new grade roll) | half the weapon's material and cash | |

**Wild Ore** is new: a common Bag item that Wild and Frontier monsters drop (my numbers: 15% from a normal monster, 60%
from an elite), so the Forge Sword comes from the Wild, not from bosses.

### 4.3 Upgrades +1 to +10
At the Forge. Each level costs more cash and more of the weapon's material (Forge weapons: Wild Ore); +5 and +10 also
need a Star Shard (the Frontier's). Upgrades never fail and never break anything (kids). Each level adds +5% Power and
visibly adds to the glow (5.1).

### 4.4 Direct drops and the drop cinematic
A boss can drop its own weapon outright: 1% per full-loot kill, plus 0.5% for every full-loot kill since without one
(bad-luck protection, like the packs' pity, `Util/PityRules`), so it always comes eventually. Masterworks never drop.
**The drop cinematic** (owner's ask): when the weapon drops, the fight's end freezes for a moment, the screen dims, the
weapon rises out of the boss's loot spot, spinning, in a column of light in its rarity's colour with its aura, the
weapon's card flips over in front of it with its grade, and a banner says its name and rarity ("LEGENDARY!"). Everyone
nearby sees the light column; an Epic or Legendary drop is told to the whole server (like Frontier card pulls,
`Remotes.PullAnnouncement`). Built from what exists: the pack opening stage (`Util/OpeningStage`: bars, flash, rays),
the level-up light pillar (`Util/LevelUpFx`), the card reveal.

### 4.5 The forge reveal
Forging plays like ripping a pack: the pack opening stage with the weapon rising out of an anvil's glow instead of a
pack, a build-up, then the grade flash (an S gets the big hit, like a Legendary pull). Reforging plays it too.

### 4.6 Balance and the economy (hard constraints)
- Sword hits are part of every boss fight's damage. Run `lune run tools/balance/bosses` with each weapon at +0 and at
  +10 Grade S (bonded) on the boss its tier is for, and set the Power numbers so that **no weapon lets a party at 0.8x
  the recommended Power win more than the "fighting well at 1x" target (85%)**, and the best weapon at +10 S never
  more than halves a fight's length at 1x. Write the rows into DESIGN.md.
- Run `lune run tools/economy/sim` with the Forge and upgrade costs as a cash sink; report the change to the goal time.
- Material drop numbers: check the 2-day / 2-week pace against the loot cooldown and the soft cap in a small
  calculation in DESIGN.md (kills a day at full chance x chance x average count).

## 5. Looks

### 5.1 The glow ladder (one job per attribute, not piled up)
| Attribute | Its job |
|---|---|
| Element | the colour: every glow, trail and spark in its element's colours |
| Rarity | the base: its model and its resting glow (Common a soft edge, Rare a clear edge glow, Epic a glowing gem and a light, Legendary also a soft halo) |
| Upgrades | layers over time: +1 to +3 the edges glow brighter each step, +4 to +6 its own aura appears (embers, frost glints, petals, sparks, void wisps...), +7 to +9 a bigger trail and an element burst on every hit, +10 "Awakened": a unique effect per weapon (orbiting runes, a colour-shifting blade, wings of light...) with a one-time cinematic when it's reached |
| Grade | the finishing touch, like cards: S adds the twinkle and sparkle |

Rules: **one particle aura per weapon** (the upgrade aura is the only one); **toned down on the back in town** (fewer
particles, no light), full strength in your hands in a fight; every weapon's effects fit a particle budget measured in
Studio (a town with 6 players carrying +10 weapons stays at 60 fps on the owner's PC and the Device emulator).

### 5.2 The models
Made, not bought (the owner turned down the store packs): concept art first (Figma's image generator), the owner picks
each, then Meshy image-to-3D (about 30 credits a model; the owner had 1120 on 2026-11-06; round 1 is 4 models plus
retries, about 150), cleaned up in Blender with our kit (a few thousand triangles, the pivot at the grip, the blade
along the model's axis like `StarterSword`), saved to `assets/weapons/<Weapon>.rbxm`. The glow is ours, built in
Roblox (neon edge and gem parts, attachments for the aura and the trail), not baked into textures, so every weapon
shares one style and the upgrade ladder can add to it. The Forge Sword's five element versions are recoloured from
one model.

### 5.3 Weapon cards
Weapons are shown as cards (the game's heart): the weapon's portrait (its model rendered big, like the product
pictures: captured in Studio and cut out, uploaded), a rarity frame, an element chip, its grade and +level, its name.

## 6. Where players see and use weapons

- **The Armory** (a new tab in the 3D binder, after First Spark and Frontier, with its own cover): a page per family,
  every weapon a card in a pocket. Owned: the card with its grade and +level, an Equip button in its card view.
  Not owned: a dark silhouette with where it comes from ("Drops from the Meadow Warden", "Masterwork: three bosses'
  materials + Star Shards") and its material progress ("Warden Heartwood 9/15"). Spears and scythes: "Coming soon".
- **The card view** of a weapon (the inspector, like a card's): its stats in words (Power, element and bond, perk,
  grade, +level), Equip, and "Upgrade at the Forge".
- **The Forge**: a forge station in town (my call: by the Boss Board, so boss materials and the Forge sit together),
  a ProximityPrompt opening a cotton candy window with three tabs: Forge (weapons you can make, their costs, what you
  have), Upgrade (your weapons, the next level's cost and what it adds) and Reforge.
- **The Boss Ladder board** shows each boss's weapon card and its material.
- **Your equipped weapon** rides on your back everywhere (as the sword does today) and is the one you fight with. You
  change it outside fights only.
- **PvP**: weapons play no part (PvP fights are creature against creature today, and sword hits only reach bosses and
  Wild monsters, `BattleService` strike); it stays that way so the owner's planned PvP ladder is fair.
- Toasts for materials picked up ("Warden Heartwood +2 (9/15)") through the new toast bubbles.

## 7. Saves, security, performance

- Saved: `data.weapons` = `{ [weaponId]: { grade, level } }` (each Forge element version is its own weaponId),
  `data.equippedWeapon`, and each boss's drop pity (full-loot kills since its weapon last dropped) beside its boss
  record. Schema bump 15 -> 16 with a Migrations step (everyone keeps the Steel Sword; the Steel Sword
  is never saved, it's always there from shop level 4). Validate on load: unknown weapons dropped (logged), grades and
  levels clamped, an equipped weapon you don't own falls back to the Steel Sword.
- Remotes (`Remotes.luau`): Forge, Upgrade, Reforge, Equip. Server-authoritative: the server checks the station's
  distance, the costs (never a client price), ownership and levels, rate-limits each (`RateLimiter`), rolls every grade
  and drop on the server.
- Items: the seven materials and Wild Ore in `Config/Items` (icons on the existing icon sheets or new ones), Bag-listed.
- Performance: the particle budget in 5.1; weapon models a few thousand triangles; the drop cinematic and forge reveal
  reuse the existing stages (client-only, right above the player, `Util/StageSpot`).

## 8. Left to the builder
- Exact names and icons of the materials, the Forge station's model and place, the Armory cover art.
- The particle and light numbers of each glow layer (within the budget and the mockups the owner picks).
- Power, perk, cost and drop numbers within the constraints of 4.6.
- How each weapon's portrait is captured (the product-picture pipeline).

## 9. Calls I made (for the owner to check)
- Round 1 swords use today's moves, recoloured; own combos per sword later.
- Weapon hits use the creatures' element wheel; the Prism Blade is always strong against the boss's current element.
- One copy per weapon; making it again rerolls the grade (keeping the better); a drop you already own becomes 10 of its
  material.
- Wild Ore, a new common Wild drop, pays for the Forge weapons.
- The Forge stands by the Boss Board in town.
- All seven boss materials drop from round 1, before spears and scythes exist.
- No Robux sales of weapons in this round.
- Each Forge element version is its own weapon (five Forge Swords to collect).
- Weapons stay out of PvP.
