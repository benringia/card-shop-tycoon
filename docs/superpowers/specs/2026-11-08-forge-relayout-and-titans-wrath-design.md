# Forge window relayout and Titan's Wrath (weapons round 2.5, part 1)

Owner's picks, 2026-11-08, from the visual companion page `round2-forge-and-lance.html`:

- Forge window: layout **A** ("Before and after"), with one change: the arrow between the two boxes is a picture
  (the kit's blue `Next` arrow icon), not the text "->".
- Titan's Lance: its own Legendary skill, **Titan's Wrath**, built as storyboarded and exaggerated. Its Power stays
  x1.20 ("leave it as is and let Titan's Wrath make it feel Legendary").

## 1. Why

- The Forge window's Upgrade panel was "hard to understand": one dense line ("+0 -> +1: Power x1.32 -> x1.36"), the
  costs as plain text, the stats in words underneath. Players should see at a glance what a tab does, what the weapon is
  now, what it becomes, and what it costs.
- The Titan's Lance is the spear family's Legendary but shares the Halberd's Piercing Rush and reads weaker than a Rare
  on its card (Power x1.20, set by the Prism Hydra's balance limit). Its own epic skill is what makes it feel
  Legendary.

## 2. The Forge window (pick A)

Same window, same tabs, same left list. The right pane changes:

1. **The tab's job, one line under the tabs** (all three tabs, exact text):
   - Forge: "Make a weapon you don't have yet. You pay its materials and cash; it comes out at a random grade, C to S
     (like a card)."
   - Upgrade: "Level a weapon you own up, +0 to +10: more Power and a brighter glow each level. Never fails. +5 and +10
     also need Star Shards."
   - Reforge: "Roll a new grade for half the making cost. You keep the better grade, so it never gets worse. Grade S
     can't be reforged."
2. **The weapon's header:** its card (small; tapping it opens the weapon card view, `WeaponDetailController.Open`,
   where its full stats live), its name, "Grade S · +0" (Forge tab: what it will be: "Grade C to S · +0"), and
   "Common · Ember" (rarity · element; no element: rarity only).
3. **Before and after:** two boxes side by side, the blue arrow picture between them.
   - Upgrade: "Now" (+0, Power x1.32) and "After" (+1, Power x1.36, and the level's glow step from
     `WeaponText.ladderStep`, e.g. "glows brighter"). At +10: one box, "Fully upgraded: Awakened!".
   - Reforge: "Now" (Grade B) and "After" ("C to S, you keep the better"). Grade S: one box, "Already Grade S".
   - Forge: the Forge weapons' element buttons as today, then one box "Comes out C to S, at +0" (my call: no Now box
     for a weapon you don't have).
4. **You pay:** cost chips, one per cost: a picture (the cash icon; each item's `Config/Items` icon) and its words:
   "$250", "2 Wild Ore (you have 11)". Green when you have enough, red when not. They wrap to a second row on a phone.
5. **The one button** as today (what it does, or what's missing).

The weapon's stats in words leave the pane (they're on its card view). Text stays plain ASCII plus `·` and emoji.
The chip and tab words come from pure functions in `Util/WeaponText` (Lune-tested):
`WeaponText.tabLine(tab)` and `WeaponText.costChips(cost, items, cash, itemsCfg)` (each chip: icon, text, enough).
Mobile-first: every tap target 48 px or more; checked in the Device emulator (landscape phone).

## 3. Titan's Wrath

Its own skill in place of Piercing Rush, on the Titan's Lance only (the Halberd and the Trident keep Piercing Rush
until their own skills, later). Same rules as every skill: 0.9 of a hit in total, an 8 s cooldown, a dodge before the
hit cancels it, the switch lock applies.

**The moves (storyboard):**

1. **Charge (long and loud on purpose):** a low wide stance, the lance drawn back in both hands, trembling. Gold and
   green light spirals into its tip, petals and sparks swirl round you, glowing cracks creep out from your feet, the
   screen rumbles and the rumble grows.
2. **Peak:** the tip flashes white, a shockwave ring bursts round your feet, rocks lift off the ground.
3. **Thrust (the hit):** one huge thrust; a beam of light the shape of the lance shoots ahead with a gold shockwave.
4. **Fissure:** a glowing fissure tears along the ground the whole length of the thrust (14 studs), green light and
   thorns bursting out of it; every foe on it is hit; a big shake.
5. **Afterglow:** the fissure glows on and closes, petals drifting down.

**Numbers (my call; tuned to the animation's markers):** the charge from about 0.1 s to 1.2 s, the peak at 1.2 s, the
hit at 1.35 s, the move about 2.2 s long, free (you can act again) from the hit. Hit shape: a line 14 studs long and 4
wide straight ahead (`SwordRules` line). The root stays put (no rush): the beam and fissure carry the reach.

**What it needs:**

- **Config:** a `titansLance` moveset in `Config/Swords`: the spear's cuts, sounds, cues and animations shared, its own
  skill, skill cues and effects; `Config/Weapons` titansLance `moveset = "titansLance"`.
- **Animation:** `tools/blender/anim_titans_lance.py` (on the spear's rig helpers; folder `TitansLance`, skill only),
  previews shown to the owner, `build_kfs`, the owner publishes, the id goes in `Config/Swords`.
- **Effects:** `Config/SwordSkillFx` look `titansWrath` (beats for every step above) drawn by the client's
  `Util/SwordSkillFx`; exaggerated (particles everywhere, big flashes; the owner's standing ask). Your own plays the
  camera moment (`Util/SkillCinematic`: the side hero shot through the charge, the wide shot framing the 14-stud
  fissure) and the shakes: a rumble growing through the charge, a big one on the fissure. Others see the light version
  within range (`OTHERS`).
- **Sounds:** licensed Pro Sound Effects only, kept quiet and measured into `Config/SoundLevels`: a ground rumble
  through the charge, energy gathering, the flash, the thrust's boom, the fissure tearing, thorns bursting.
- **HUD:** `Config/CombatHud` SKILLS.titansLance: name "Titan's Wrath", an icon from the spare lance glyphs already cut
  (`assets/ui/icons`: LanceLeaves, my pick; LanceSun; LanceBloom), uploaded into `Config/UIIcons`; `SkillText` words.
- **Preview:** `/skillfx lance skill` (and the admin panel's button) shows Titan's Wrath.
- **Balance:** same power and cooldown as every skill; the boss balance tool re-run on the Lance to confirm it stays
  inside the limits.

## 4. Non-goals

- The Halberd's and Trident's own skills (later rounds).
- Changing the Lance's Power (stays x1.20, owner 2026-11-08).
- New Figma icon art, unless the owner turns down the spare glyphs.

## 5. Left to the builder

Effect sizes, counts and colours; exact sound picks; the charge's tremble and the thrust's key poses (shown to the
owner as previews first); the Reforge and Forge boxes' exact words beyond the above.
