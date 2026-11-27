# A duplicate weapon drop at a better grade: design (2026-11-27, small change)

Owner 2026-11-27: "All Weapon drops notify player if the duplicate is a higher grade", then "upgrade and tell them, go".

- **Why:** a boss's duplicate drop rolled a grade and threw it away silently (`WeaponRules.give` returned nothing for a
  drop you own), so a lucky Grade S roll on a weapon you had at C was lost without a word.
- **Approaches:** tell only (the better grade still lost: frustrating), let the player choose (pointless: a better grade
  is better in every way), or upgrade and tell (picked, owner).
- **Design:** a drop you own whose rolled grade is better upgrades yours, keeping its level, its mutation and a choice
  waiting (the same rule as the Forge's reforge, `WeaponRules.give`). `BossService.GiveWeapon` adds
  `gradeUp = { from, to, level }` to the drop's payload. The client plays the steps `WeaponLookRules.dropSteps` names:
  the NEW GRADE reveal ("NEW GRADE A!", "A better Verdant Blade dropped! Yours went from Grade B to A.",
  `WeaponText.gradeUp`), then the drop's mutation roll as before; never the "New weapon!" reveal for one you had.
- **Tests:** WeaponRules (better grade upgrades, same or lower gives nothing), WeaponText (the words, ASCII),
  WeaponLookRules (the steps). Checked in Studio: C to B and C to A upgrades, B rolls after an A left alone, the reveal.
