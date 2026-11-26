# Weapons round 4 part 3: mutation words players know, and the boss pass

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner's check of part 2 (the mutation choice read as a price, the Forge hid the mutation, Essence had a
plain icon, Essence only from drops), then the spec's part 3: mutation sizes and boss numbers from the sims.

**Architecture:** Pure rules in `Util/MutationRules` and `Util/WeaponText` (Lune-tested); the reveal's choice panel
(`WeaponRevealController`) and the Forge (`ForgeController`) draw them; `WeaponService` marks a Forge roll's waiting
choice so it gives no Essence (saved, schema v45). Boss numbers in `Config/Bosses`, mutation sizes in
`Config/Mutations`, both from `tools/balance/bosses`.

**Tech Stack:** Luau, Rojo, Lune tests (`lune run tests/run`), Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-25-weapons-round4-design.md` (part 3) and the owner's picks on the mockups
(artifact DHTyU65aygVNQiU1A1774G, 2026-11-26: "R1 and icon A, go", "player should only get essence in drops. not in
the forge mutations").

## Global Constraints

- Words players know (playbook "Game UI words"): CURRENT and NEW! cards, "Keep current" / "Take new", a reward as
  "You get [Essence icon] +N"; a price never with a plus.
- Essence only from boss drops: the choice after the Forge's Mutate gives none, now or after a rejoin.
- Mockups matched exactly (R1: desktop panel 520 wide, cards 2 px rarity edge, buttons 52 px (48 on a phone), tag 11,
  name 18, effect 13; phone: no top line, the tag in the name row).
- Tap targets >= 48 px; text ASCII plus `·`; the rarity colours are `Config/Rarities` (CardFace.getRarityColor).
- Saved shape change: SCHEMA_VERSION 45, a MIGRATIONS step with its Lune test, DESIGN 10.4.
- Boss targets (spec): fights well 85% at 1x / 50% at 0.8x, stands still 60% / 15%; the weapon limits (spec
  2026-11-06 4.6): no weapon lets a 0.8x party win more than 85% fighting well on its tier boss, +10 Grade S never more
  than halves a 1x fight. Boss 1 stays easier (it's the first).

## Review Focus

1. A Forge roll's choice after a rejoin: still no Essence (the saved flag read back), and an old save's waiting choice
   (no flag) still gives it.
2. A second roll while a Forge choice waits settles it as Keep current with no Essence.
3. The panel when both mutations share a rarity, when the new one is the first (Nice!), and a Legendary's long line
   on a phone.
4. The Forge row for a weapon with no mutation, and the list chips not overlapping the Grade line.
5. Boss changes leave the Steel Sword's still rows near target (the sword doesn't touch them).

---

### Task 1: The Essence icon

**Files:** Create `tools/ui-icons/make_essence.py`, `assets/ui/icons/Essence.png`; Modify `src/shared/Config/UIIcons.luau`,
`src/shared/Config/Items.luau`.

- [ ] Move the scratch generator into `tools/ui-icons/make_essence.py` (the XP Tonic's flask recoloured violet, three
  sparkles; option A only) and write `assets/ui/icons/Essence.png` (256 px).
- [ ] Upload it (Studio MCP `upload_image` from `python -m http.server` on 127.0.0.1), add `Essence` to UIIcons,
  `mutationEssence.icon = "Essence"`.
- [ ] `lune run tests/run` passes (ItemRules checks every item icon).

### Task 2: Essence only from drops

**Files:** `src/shared/Util/MutationRules.luau`, `src/shared/Util/WeaponRules.luau`, `src/server/Services/WeaponService.luau`,
`src/shared/Config/Data.luau`, `src/server/Util/Migrations.luau`; tests `tests/MutationRules.spec.luau`,
`tests/WeaponRules.spec.luau`, `tests/Migrations.spec.luau`.

**Interfaces:** Produces `MutationRules.Pending = { id, rarity, forge: boolean? }`;
`MutationRules.resolve(cfg, have, new: Pending, take) -> (Mutation?, number)` gives 0 Essence when `new.forge`;
`WeaponRules.read` keeps a saved pending's `forge = true`; `Offer.essence` zeros and `source = "forge"` for it.

- [ ] Tests first: resolve with a forge pending gives 0 either way and keeps the right one; a drop pending as before;
  WeaponRules.read keeps `forge` only when it's `true`; Migrations v45 no-op.
- [ ] Implement; WeaponService stores `forge = true` on a Forge roll's pending, copies it in the snapshot, zeros the
  offer's Essence and passes the source on rejoin (Pending).

### Task 3: The choice panel R1

**Files:** `src/shared/Util/WeaponText.luau` (or MutationRules words), `src/client/Controllers/WeaponRevealController.luau`;
test `tests/WeaponText.spec.luau`.

**Interfaces:** Produces `WeaponText.choice(offer) -> { top: string?, cards: { { tag, name, rarity, icon, effect, button,
gets: number? } } }` (the current card first; `gets` nil when no Essence).

- [ ] Tests first: a drop with different rarities ("Keep current" gets the new one's Essence, "Take new" the old one's),
  a Forge roll (no `gets`, its own top line), a first mutation (one NEW! card, "Nice!").
- [ ] Draw it as the mockup (desktop and phone), the Essence icon beside "You get".

### Task 4: The Forge's Mutate tab

**Files:** `src/shared/Util/WeaponText.luau`, `src/client/Controllers/ForgeController.luau`; test `tests/WeaponText.spec.luau`.

- [ ] Tests first: `WeaponText.mutationRow(words?)` ("CURRENT MUTATION", "Scholar · creature XP from fights +3%",
  "Rare"; none: "None yet: this roll gives its first!"); `outcome("mutate")` gives the pill and no line.
- [ ] The row under the recipe, a 3 px rim in the rarity colour round the weapon's card, a chip on owned list rows
  ("Rare · Scholar").

### Task 5: The boss pass

**Files:** `src/shared/Config/Mutations.luau`, `src/shared/Config/Bosses.luau`, DESIGN.md.

- [ ] Sims (200 fights a row, solo): each boss with the weapon players bring (the previous boss's), +0 C, +5 B and +10
  S, with no mutation, a Rare one and each Legendary; the targets and limits above.
- [ ] Set mutation sizes and boss numbers to hold them; record the rows in DESIGN 5.11.

### Task 6: Docs

- [ ] DESIGN (5.11 words, the Forge, Essence from drops only, 10.4 v45), CLAUDE.md test list, the vaults.
