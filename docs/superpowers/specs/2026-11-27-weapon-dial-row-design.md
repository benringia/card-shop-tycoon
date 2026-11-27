# Weapon dial as a row (design)

Date: 2026-11-27. Status: approved by the owner ("B, go"), pick B of three mockups
(https://claude.ai/artifact/QKG3ZzZdXSFcNQSc7THGiW: A clean dial, B twin of the party dock, C weapon card).

## Why
The owner: "redesign the weapons dial. also the mutation icon is overlapping with the hotkey". Today's medallion dial
(pick C of 2026-11-14) has five small pieces floating round it, dark weapons on dark circles, and the grade's "S" in a
white circle that reads as a third key next to Q and Z.

## What (pick B: the twin of the party dock)
On a computer, the dial becomes a row like the party dock in the opposite corner:
- the weapon in hand big in the middle (today's 72 px medallion: its rarity's ring with the shine, the element's colour
  inside);
- the one before (left) and the next (right) either side, smaller (44 px), a little lower, on their own element's
  colour with their rarity's ring; tap one to step to it (48 px tap areas);
- the keys under them, Z under the left one and Q under the right one (keyboards only), as 1 and 3 on the party dock;
- the weapon's name always under the big one, white with the dark edge (like "Solarion");
- its level "+4" in a gold pill on its top (none at +0), like "Lv 30";
- its grade as the cards' gold medal on its top-left corner (Config/GradeLook medal pictures), never a white key-like
  circle; its mutation's mark on its top-right (today's, already moved there).
- No faded fourth weapon. With two weapons only the next shows (on the right).
- A switch slides the row a step: the new weapon in hand comes in from its side, the old one moves to the other side,
  one that wasn't showing fades in.
- Unchanged: Q / Z / Shift+Q, the swipe and the stats tip on the big one, the switch's fight cost, where it sits (the
  corner, the computer's bottom bar, over the fight buttons at 0.7 in a computer's fight). A phone keeps the medallion
  alone (64 px, its count, tap and swipe, its name briefly after a switch), now with the grade medal too.

## Build (my calls)
- One pure box for the row (`UiLayout.switchBox`), used by `UiLayout.weaponSwitch`, the controller and the desktop
  bar's room for it (UIController), so they always agree.
- `Util/WeaponSwitch`: the track loses `later`; `rowSpot` replaces `arcPoint` (each side's offset from the middle).
- Numbers in `Config/HudLayout` WEAPON_SWITCH (row gap, drop, rise, name line, medal).
