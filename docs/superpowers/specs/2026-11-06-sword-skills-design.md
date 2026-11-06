# Sword skills and effects (weapons round 1.5): design

Owner request 2026-11-06, before the spears (weapons round 2): "shouldn't we be adding different effects on the
swords first?". Today every round 1 sword (Forge Sword, Verdant Blade, Sunforged Blade, Prism Blade) swings the
Steel Sword's twelve moves and differs only in its slash colour, hit colour and aura, so in a fight they feel the
same. This round makes each one feel like its own weapon. Round 1's spec deferred it ("giving each sword its own
combo is a later animation round", section 3.5).

## 1. What the owner decided

- **Same basic attacks:** the three combo cuts keep today's animations (forehand, backhand, the jumping finisher) and
  their damage and timing.
- **Each sword's own effects on them:** every slash shows the sword's effect (the owner's example: the Sunforged
  Blade leaves a fire trail on every slash), and the finisher (cut 3) has a bigger signature effect (the owner's
  example: the ground cracks open with glowing lava).
- **Each sword's own skill animation and effect** (the skill button / key), keyed in Blender like the sword-moves
  round.
- The four skills below were proposed and approved ("lets do it").
- The Steel Sword keeps today's look and its dash slash.

## 2. The four swords

| Sword | Slashes (cuts 1-3) | Finisher (cut 3's slam) | Skill |
|---|---|---|---|
| **Forge Sword** (Common, the element picked when forged) | a trail in its element's colour, small sparks of its element on hit | a burst of its element where the slam lands: a flame puff (Ember), a splash (Tide), leaves (Bloom), sparks (Volt), shadow (Shade) | **Elemental Spin**: a full spin slash that throws a ring wave of its element out along the ground |
| **Verdant Blade** (Rare, Bloom) | leaves and petals shed off each swing | roots and thorns burst up out of the ground under the foe | **Thornline**: stab the blade into the ground; a line of thorny vines erupts toward the foe and snaps shut |
| **Sunforged Blade** (Epic, Ember) | a fire trail on every slash | the ground cracks open with glowing lava where the slam lands | **Sunfall Cleave**: raise the blade while sunlight gathers into it, then one huge swing launches a fiery crescent wave that explodes on the boss |
| **Prism Blade** (Legendary, every element) | rainbow arcs | prism shards in all five colours burst out | **Prism Judgment**: point the blade at the boss; five ghost blades (Ember, Tide, Bloom, Volt, Shade) appear in a ring above, strike down one after another, then a rainbow pillar |

The skills grow in scale with rarity: the Common's is a simple spin, the Legendary's a full summoning.

## 3. How the skills work (my calls)

- **Same strength:** every new skill deals today's skill damage in total (power 0.9 x the weapon's Power) on today's
  cooldown (8 s), so boss balance doesn't move. Only the motion, the shape it hits and the look change.
- **Their shapes** (what the server counts as hit; pure rules in `Util/SwordRules`, Lune-tested, like the dash's):
  - Elemental Spin: every foe within 9 studs of you, all at once.
  - Thornline: a straight line from you toward your aim (the existing `aimTarget` pick, else where you face), 18 studs
    long and 4 wide, at the hit moment. You don't move.
  - Sunfall Cleave: a line toward your aim, 24 studs long and 6 wide; the crescent wave travels at about 40 studs a
    second, and each foe takes its damage when the wave reaches it.
  - Prism Judgment: your aimed foe (the nearest target within 24 studs in front of you; none, the nearest within 24
    around you; none at all, it whiffs like a missed skill). Five strikes 0.15 s apart, each 1/5 of the damage.
- The server checks the shape from its own record of where you stood (as the dash slash does today); it doesn't take
  the client's word for what was hit.
- The skills keep today's skill cooldown display, keys and buttons; only the Steel Sword dashes.

## 4. Looks (my calls)

- **Reuse what exists** where it fits: the super moves' lava `crack` texture for the Sunforged finisher and Sunfall's
  explosion, the Pet moves' `vine` and `bark` textures for the Verdant's thorns, the attack textures (`flame`, `glow`,
  `spark`, `shard`, `smoke`), the sword's `crescent` for the waves, the weapon models themselves (tinted) for the Prism
  Blade's ghost blades. New textures only where nothing fits.
- **Colours:** the weapon's element colours (`Config/WeaponLooks` glow, deep, trail); the Forge Sword by its picked
  element; the Prism Blade by every element (and in fights its trail stays the colour strong against the foe, as now).
- **Upgrades:** the effects keep their shape at every level and grow with the trail's scale from +7 (`trailScale`
  1.2 / 1.35 / 1.5). No other ladder change.
- **Everyone sees them:** other players' slashes, finishers and skills show with their effects (they already see each
  other's swords). Effects are built to the same budget as the creature attack effects (`Config/AttackFx`'s); if a
  crowded fight runs slow in the Studio check, others' effects drop their particles first.
- **Never hide the boss:** effects stay under the boss's attack rings and telegraphs (lower on screen, short-lived,
  no full-screen flashes) so players can still dodge.

## 5. Animations

Four new skill animations, made the way the sword-moves round made the cuts (`docs/animations.md`, "Making or changing
moves"): keyed in a background Blender on `tools/blender/anim_kit.py` (one `anim_<sword>.py` per sword, or one file
with four skills), front and side GIF previews at real speed shown to the owner before Studio, converted by
`lune run tools/anim/build_kfs`, published by the owner (Save to Roblox), ids into `Config/Swords`. Studio plays them
before they're published.

- Elemental Spin: a planted full turn with the blade held out at waist height (about 0.9 s).
- Thornline: a short hop, both hands driving the blade down into the ground in front, a beat holding it there (about
  1.1 s).
- Sunfall Cleave: blade raised overhead, a held charge, then a huge forward swing that follows through low (about
  1.3 s).
- Prism Judgment: blade swept up, then pointed at the boss and held (the command pose) while the ghost blades strike
  (about 1.4 s).

Each skill's `hitAt` (and Judgment's five strike times) must match its animation's Hit markers (as the cuts' do).

## 6. Sounds

Licensed sounds only (Roblox's Pro Sound Effects / APM). Each sword's slashes get a layer of its element (a fire
whoosh on the Sunforged, a leafy rustle on the Verdant, a crystal chime on the Prism, the element's on the Forge
Sword), its finisher a signature hit (lava rumble, roots cracking, a prism shatter, the element's burst) and its skill
its own cues. Kept quiet, at the owner's level for the Forge and drop sounds (2026-11-06: "good, but loud"); each
sound measured into `Config/SoundLevels` like the skill sounds today.

## 7. Where it lives (my calls)

- `Config/Swords` gets one moveset per sword (`forgeSword`, `verdantBlade`, `sunforgedBlade`, `prismBlade`): the same
  combo and cut animations as `starterSword` (shared, not copied by hand), its own `skill` (power, timings, shape) and
  skill animation, and an `fx` entry naming its slash, finisher and skill looks. `Config/Weapons` points each weapon's
  `moveset` at its own (the five Forge Swords share `forgeSword`, coloured by their element).
- The looks' numbers in a plain-data config (`Config/SwordSkillFx`) so tests can read them; client drawing in
  `Util/SwordSkillFx` (one builder per look), called where `SwordController` / `HitFx` draw today's slashes, finisher
  and dash.
- `tests/SwordsConfig` keeps checking every moveset's combo damage a second; new tests: every skill's total power and
  cooldown equal today's, every shape rule, every moveset's `fx` names a look that exists.
- Dev command: `/skillfx <sword> [cut3|skill]` plays a sword's finisher or skill on a dummy (Studio only, admin panel
  buttons), like `/superfx`.

## 8. Order (my call)

One sword at a time, each shown before it's built and checked in Studio before the next: storyboard of its slash,
finisher and skill (visual companion) -> owner OK -> its skill animation previews -> owner OK -> build -> Studio
check. Sunforged Blade first (the owner's own example), then Verdant, Prism, Forge Sword.

## 9. Not in this round

- New basic cut animations (the owner kept today's three).
- Spears and scythes (rounds 2 and 3, after this).
- Any change to damage, cooldowns, weapon Power, perks or the glow.
- The Steel Sword (keeps its dash slash and pale steel).

## 10. Would make this a failure

- Effects that hide the boss's attacks so players can't dodge.
- Phones stuttering when several players fight with effects at once.
- Loud sounds.
- A skill that's stronger or weaker than another just because of its look (all share today's damage and cooldown).
