# Element callouts: matchups you can see in a fight

Owner 2026-11-25, after the finishing blow: picked D of the combat ideas ("element callouts"), then from three mockups
in real fight frames (artifact 1FgrG82xnTuo6zYRiinLkX) "A" (a chip in your creature's status row; not B, badges on
the creature cards with a switch tip, or C, a start banner), then from today's strong-hit pop beside a bigger one
"bigger, go ahead".

## Why

The element wheel is the biggest lever a kid has (1.5x dealt and 0.75x taken the right way round, Config/Combat), and
a fight never said so: only "-N STRONG!" on a hit. While the mockups were made, Bramblequake (Nature) lost to Fire
monsters twice in a row.

## Approaches

- **A (picked): a chip in your creature's status row**, beside the perk chip (and a computer's Shift key): calm, there
  the whole fight.
- B: a badge under each card of the party strip (what it would deal to this foe) and a "Switch: 1 or 3" tip.
- C: a "WEAK MATCH!" / "STRONG MATCH!" banner for 1.5 s at the start.
- Strong hits: **bigger (picked)** or today's.

## Design

1. **The matchup chip** (CombatHud's ChipRow, the next chip after PerkChip and DodgeKey): your fighting creature's
   element against the foe's (the monster: wild, boss, a Dungeon room's), the way it hits:
   - weak: a soft red pill (fill 254,226,226; edge 243,176,176, 2 px), the foe element's icon, "Weak vs Fire" (body
     font, ink 68,48,40), a red tag (214,72,72) "0.75x" in white;
   - strong: soft green (fill 220,252,231; edge 147,224,168), "Strong vs Water", a green tag (46,160,90) "1.5x";
   - even: no chip.
   Electric and Dark beat each other, so either way round shows green "Strong vs Dark 1.5x" (the chip says how you hit;
   they hit back as hard). Sizes as the mockup: 26 px tall, icon 16, words 11, tag 14 px tall with 9 px text, 8 px in
   from each side, 6 px gaps. The numbers come from Combat.STRONG / WEAK, the names from ElementNames. It pops in like
   the perk chip whenever it appears or changes: a swap, a boss changing element. No chip without a monster foe (the
   arena).
2. **Bigger strong hits**: "-N STRONG!" pops at a crit's size (a 220 x 58 billboard to a 2.1 peak, outline 3; was 150 x
   40 to 1.75) over a gold burst: 12 rays, long and short in turn (64 x 11 and 44 x 7 px before the pop's scale),
   starting 18 px out from the middle and fading toward their tips, over a disc 70 px wide at 45% see-through, colour
   255,196,64. It scales and fades with the number (a second). A boss's hit on your creature stays the biggest (2.2).

Numbers: Config/CombatHud MATCHUP, Config/AttackFx NUMBERS (strong, STRONG_BURST). Pure rules: Util/MatchupRules (the
chip for a matchup), Util/DamagePop.burstRays (the rays' layout). Client: Util/MatchupChip (draws the chip),
Util/StrongBurst (draws the burst, steps with its number).

## Not in this round

- B's badges and tip, C's banner. A callout for the sword's element. The 3D hit effects on a strong hit.

## Tests

- `tests/MatchupRules`: weak, strong, even (nil), Electric against Dark and Dark against Electric, a missing or unknown
  element (nil), the strength tag's words ("1.5x", "0.75x", "2x").
- `tests/DamagePop`: a strong hit pops to a crit's peak, still under a boss's hit; the burst's rays fan all the way
  round, long and short in turn, each one's middle out along its angle (a GUI turns about its own middle).
- Studio: the chip in a weak, a strong and an even fight, after a swap, on a phone; a strong hit's pop and burst; no
  errors; then the owner's check.
