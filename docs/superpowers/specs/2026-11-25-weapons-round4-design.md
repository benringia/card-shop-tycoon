# Weapons round 4: Attack numbers, a clearer weapon card, a future-proof Prism, and mutations

Owner 2026-11-25. Asked "Prism blade unlocks all the Supers? whats the point of other weapon?", then "later on the game
there will be a new map and new weapons ... Players will then not worry about the new one element weapons" and "which
one is future proof? my plan on the new map is the way you obtain weapon is to do a difficult quests": picked the
future-proof rule (option 2). Then "add passive systems": near-guaranteed boss weapon drops with mutations (Common to
Legendary) glowing over the upgrade glow, "we might want to readjust bosses difficulty". From mockups in real game
screens (artifact SdPB6vGHJmV2US9QuDPcv7): "okay go", then "rearrange this UI to be easily understood", "do we have
better numbers for kids ... rather than x1.30", picked layout A, "attack, mutation and super has the same icon. make
them look different".

Three parts, built and checked one at a time: **1** Attack numbers, the weapon card and the Prism; **2** mutations;
**3** the boss difficulty pass.

## Why

- The Prism Blade unlocked every super, bonded with every creature and hit strong against every foe: once a player had
  it, no element weapon mattered, and a future world's quest weapons wouldn't either.
- A weapon's "Power x1.51" reads as math to a kid; the weapon window packed boxes in boxes and scrolled.
- Weapons drop rarely and then nothing more comes from a boss: mutations give every kill a roll.

## Rules for every world (DESIGN)

1. A creature's super needs a weapon of its element. No exceptions, the Prism Blade included.
2. No weapon bonds with every creature.
3. "Always strong" belongs to the Prism Blade alone.
4. Each world's weapons start above the last world's top Attack.

## Part 1: Attack numbers, the weapon card, the Prism

1. **Attack**: a weapon's Power (the multiplier) shown as a whole number, x 100 rounded: the Steel Sword 100, a +5 Grade
   A Verdant Blade 151, a +10 Grade S Prism Blade 259. Everywhere a weapon's Power shows: the card face ("Attack 151"),
   the weapon window, the Forge ("+8 Attack" an upgrade, "Attack 259" maxed), the versus line ("+41 vs Steel Sword"),
   an unowned weapon's range ("Attack 140 to 209"), the character window's Attack tile ("151"), the Forge's words
   ("more Attack"). The sims and saves keep the multiplier.
2. **The weapon window, layout A** (the right side; the card, the title and the Equip bar as today): the pills (rarity,
   family, element; the Prism's "Always strong"), then
   - a weapon you have: one gold box, the Power icon, "ATTACK" over the number, the grade on its round badge with
     "Grade", "Level +5 / 10" over a gold bar (the Steel Sword: the Attack alone);
   - one you don't: "How to get it" as today, and an Attack row: "Attack 140 to 209", "Grade C at +0 to Grade S at +10";
   - then one row each, an icon, a bold title and one short line, no boxes inside boxes:
     the skill (its own icon and name, a short line: Config/CombatHud SKILLS `short`, the dash's in BUTTONS.skill);
     the perk (an icon by kind, a title and a short line: heal "Heals your creature", burn "Burns the foe", venom
     "Poisons the foe", erupt "Erupts", chill "Chills the foe", chain "Chain lightning", execute "Finishes foes");
     the bond (the element's icon, "Best with Nature creatures", "Unlocks their supers. Hits +15%, supers fill 50%
     faster.");
     the Prism Blade instead: "ALWAYS STRONG" in gold (Elements icon, a gold fill and edge, "Every hit is strong (1.5x)
     against any foe.") and "Supers" (Lock icon, "Doesn't unlock supers: use your creature's element weapon.").
   Distinct icons (owner: attack, mutation and super had the same one): Attack the Power fist, Supers the Lock,
   mutations (part 2) their group's icon (Sword, Shield, Heart) in the rarity colour.
   Sizes as the mockup: the gold box 70 px (the number 36 px), rows 48 px (icon 30, title 15, line 12), 5 px apart.
3. **The Prism Blade** keeps "always strong" (its hits count as the element strong against the foe); loses "every super"
   and "bond with every creature" (WeaponRules.superUnlocked, bond); its own Power 0.87 -> 1.0, so its sword hits stay
   (0.87 x 1.5 x 1.15 = 1.50 before, 1.0 x 1.5 now) and its shown Attack is Power x 1.5 (no bond). Checked with
   tools/balance/bosses against the Hydra limits (spec 2026-11-06 4.6).

## Part 2: mutations (its own plan after part 1's check)

- **Drops**: a boss's weapon drops almost always on a loot win (numbers then the sims). A drop you own is a mutation
  roll; the reveal (today's stage in the mutation's rarity colour) shows it against yours: Take new or Keep mine; the
  other becomes Mutation Essence (more for rarer).
- **One mutation per weapon**, saved on its copy; only the weapon in your hand counts. The Forge's Mutate spends Essence
  to roll one on any weapon (quest weapons too).
- **Groups and list**: Offense (Sharp sword hits, Critical crit chance x2, Element Edge strong hits, Boss Hunter),
  Defense (Tough HP, Guard less damage taken, Quick Step dodge sooner, Thorns), Support (Lifesteal, Pet Boost creature
  ATK and HP, Super Charge, Treasure fight cash, Scholar creature XP). Rarity sets the size (placeholders 3 / 5 / 8 /
  12 / 16%, then the sims); Legendary adds a twist (e.g. Tough: Second Wind; Pet Boost: Rally).
- **Guardrails**: Treasure and Scholar at half and from fights only; no card luck; off in the arena; no copies of the
  weapons' own perks.
- **Look**: the weapon window's YOUR WEAPON box gets its mutation (the group's icon in the rarity colour, the name, what
  it does); the blade a rim and sparkles in the card rarity colour over its upgrade glow.

## Part 3: the boss pass (after part 2)

Rerun tools/balance/bosses with mutations at typical and best rolls and the Prism change, and adjust boss numbers so the
targets hold (well 85% at 1x, 50% at 0.8x; still 60% / 15%).

## Not in this round

The new map, quest weapons, trading, keeping several copies of a weapon.

## Tests (part 1)

- WeaponText: Attack as a whole number (rounding), the card's "Attack 151", powerGain "+8 Attack", versus "+41 vs Steel
  Sword", powerRange "Attack 140 to 209", "more Attack" in the Forge's words, the perk rows' titles and short lines by
  kind, the bond row, the Prism's rows, every skill's short line present and one line long.
- WeaponRules: the Prism unlocks no super and bonds with nobody; its shown Power is Power x STRONG; an element weapon
  unchanged.
- Studio: the window for an owned element weapon, an unowned one, the Steel Sword and the Prism; the Forge's numbers;
  the character window; a phone; no errors. Then the owner's check.
