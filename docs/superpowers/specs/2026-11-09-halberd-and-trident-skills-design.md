# Magma Halberd and Tidal Trident skills (weapons round 2.5, part 2)

Owner's words, 2026-11-09:

- Magma Halberd: "since magma halberd is very rare something simple is fine. we can just do one big swipe. with flaming
  horizontal slash effects"
- Tidal Trident: "the player strike the ground with the trident, while the trident is stuck to the ground, torrents of
  water appears from the ground"

The owner said "proceed" to both playbacks, my guesses included. Each skill replaces Piercing Rush on that weapon only.
The Forge Spear keeps Piercing Rush.

## 1. Why

The Halberd (Very Rare) and Trident (Epic) still share the Forge Spear's Piercing Rush. The Titan's Lance got its own
skill in part 1. Each boss spear should feel like its own weapon, and the skill's size should follow its rarity:
the Halberd simple, the Trident bigger, Titan's Wrath the biggest.

## 2. Rules shared by both

The same rules as every skill: 0.9 of a hit in total, an 8 s cooldown, a dodge before the hit cancels it, the quick
switch is locked while it plays, and you're free to act again from the hit. Neither moves you (no rush or lunge): both
hit around where you stand, turned the way you face as the skill starts (soft aim as for every skill). Effects are exaggerated (the owner's
standing ask); others see the light version within range (`SwordSkillFx` `OTHERS`).

## 3. Magma Cleave (Magma Halberd)

**The move (storyboard):**

1. **Wind-up:** the halberd pulled back over the right shoulder in both hands. The blade's glow brightens and embers
   gather on it.
2. **The swipe (the hit):** one huge horizontal swing across your front, right to left. A big crescent of fire follows
   the blade (orange-red, white-hot core), shedding flames and embers, with a thinner flame slash just behind it.
3. **Impact:** every foe caught gets the pack hit in Ember (`Util/PackHit`), sized to the foe; one solid shake.
4. **Follow-through:** the blade ends low on the left, the fire crescent fading into smoke and falling embers.

No charge stance, no fissure, no camera moment.

**Numbers (my call; tuned to the animation's markers):** the wind-up from about 0.1 s to 0.5 s, the hit at 0.6 s,
the move about 1.2 s long, free from the hit. Hit shape: a half circle in front of you, 11 studs out (a new skill
shape kind `arc`: `radius` 11, `angle` 180, centred on your facing; Lune-tested in `SwordRules`).

## 4. Torrent Strike (Tidal Trident)

**The move (storyboard):**

1. **Raise:** the trident lifted overhead in both hands, prongs down; water swirls round the prongs.
2. **Slam:** driven prongs-first into the ground just ahead. A splash ring bursts out, glowing blue cracks spread
   across the ground; a shake.
3. **Torrents (the hit):** while the trident stays stuck in the ground, columns of water burst up in two quick
   waves: a close ring round you, then a wider ring further out. Each column throws spray, falling droplets and mist,
   with a splash ring at its foot. Every foe caught gets a big column right under it and the pack hit in Tide, sized
   to the foe. A bigger shake, and a short camera pull-back on your own (`Util/SkillCinematic`) to show the torrents.
4. **Pull free:** the columns fall back as rain and mist; you pull the trident out.

**Numbers (my call):** the raise from 0 to about 0.45 s, the slam at 0.55 s, the torrents (the hit) at 0.75 s, the
second wave for show at about 1.0 s, held until about 1.5 s, the move about 1.9 s long, free from the hit. Hit shape:
everything within 12 studs all round you (the existing `spin` shape, `radius` 12). The Chill perk applies as usual.

## 5. What it needs (both)

- **Config:** `magmaHalberd` and `tidalTrident` movesets in `Config/Swords`, built like `titansLance`: the spear's
  cuts, sounds, cues and animations shared, their own skill, skill cues and `fx.skill`; `Config/Weapons`
  `moveset = "magmaHalberd"` / `"tidalTrident"`.
- **Hit shape:** `SwordRules` gains the `arc` kind (Halberd); the Trident reuses `spin`.
- **Animations:** `tools/blender/anim_magma_halberd.py` and `anim_tidal_trident.py` on the spear's rig helpers
  (folders `MagmaHalberd`, `TidalTrident`, skill only; `run_sword_moves.py --sword magma_halberd` / `tidal_trident`),
  previews shown to the owner, `build_kfs`, the owner publishes both (exact paths given), ids into `Config/Swords`.
- **Effects:** `Config/SwordSkillFx` looks `magmaCleave` and `torrentStrike` (beats for every step above), drawn by
  `Util/SwordSkillFx`; the Trident's camera moment in `Util/SkillCinematic`; shakes as above.
- **Sounds:** licensed Pro Sound Effects only, measured into `Config/SoundLevels`. Halberd: a heavy whoosh, a fire
  burst on the swipe. Trident: the slam, the splash, the torrents surging, the rain falling back.
- **HUD:** `Config/CombatHud` SKILLS: `magmaHalberd` "Magma Cleave" with icon `HalberdFlames` (my pick; HalberdSpin
  spare), `tidalTrident` "Torrent Strike" with icon `TridentWave` (my pick; TridentDrops spare), both from the glyphs
  already cut in `assets/ui/icons`, uploaded into `Config/UIIcons`; tooltips and `SkillText` words.
- **Preview:** `/skillfx halberd skill` and `/skillfx trident skill` (and the admin panel's buttons) show the new
  skills.
- **Balance:** same power and cooldown as every skill; `tools/balance/bosses` re-run with both to confirm they stay
  inside the limits.
- **Docs:** DESIGN.md 5.11, `docs/animations.md`, CLAUDE.md (the new Blender scripts), the vault.

## 6. Non-goals

- Changing either weapon's Power or perk (Eruption, Chill stay).
- The Forge Spear's skill (keeps Piercing Rush).
- New Figma icon art, unless the owner turns down the spare glyphs.
- The scythes (weapons round 3).

## 7. Left to the builder

- Exact effect particle counts, sizes and colours (inside the storyboard and the exaggerated look).
- Exact animation keys and marker times (near the numbers above).
- Which licensed sounds fit best.
