# Party & Summoning — Design

Status: approved in chat 2026-10-21. Roadmap step 3 (DESIGN 5.8). Battles (step 5) will use the party as
the battle team.

## 1. Goals

- A **party of 3** cards; **one summoned at a time**, following its owner around the world, visible to all.
- While summoned it gives its owner a small **element perk**, stronger with rarity and stars.
- Creature art from **free Creator Store models**, mapped to cards by name, with a placeholder fallback.

## 2. Party

- **Add to party** from the binder card view (levelled card, or a plain copy split off into its own card,
  like jobs). **Party** HUD button opens a panel: 3 slots (card face, grade, level, stars, perk text),
  **Summon / Unsummon**, **Remove**.
- Party cards are locked: no display, no job. They **can** be condensed (as the main copy). A working card
  can't join the party.
- Summoning another party card unsummons the current one. Unsummon leaves nobody out.
- Saved: schema v7 `party = { slots = { beastId? x3 }, summoned = slot? }`. Load drops missing cards,
  duplicates and cards that are working; the summoned beast respawns on join.

## 3. Following

- The creature is an unanchored model with a root part driven by `AlignPosition` + `AlignOrientation`
  (works for any model, rigged or not), network owner = its owner for smooth motion. It hovers
  `FOLLOW_OFFSET` beside/behind the owner's character and faces their movement direction, with a gentle bob.
- Size by rarity (`SIZE_BY_RARITY`, Common 0.7 … Legendary 1.4 times the model's base scale).
- Billboard: name, `Grade · Lv · stars`.
- More than `TELEPORT_DISTANCE` away (teleport, fall, respawn) → it snaps next to the owner.
- Removed when unsummoned, when the owner dies (respawns with them), and on leave.

## 4. Perks (`Config/Party.luau`)

| Element | Perk | Effect | Common → Legendary |
|---|---|---|---|
| Ember | Hype | customers arrive more often (spawn interval ÷ (1 + p)) | +5% → +15% |
| Tide | Calm | customers wait longer in the queue (patience × (1 + p)) | +10% → +30% |
| Bloom | Express | deliveries arrive faster (delivery time × (1 − p)) | −10% → −30% |
| Volt | Hustle | you walk faster (WalkSpeed × (1 + p)) | +5% → +15% |
| Shade | Haggle | customers more willing to buy at your price (buy chance × (1 + p), capped at 1) | +5% → +15% |

- Rarity steps: Common, Rare, Very Rare, Epic, Legendary = base × 1, 1.5, 2, 2.5, 3 (where Common = the
  first number above). Each star adds +10% of that value.
- `Util/PartyRules.luau` (pure, Lune-tested): `getPerk(config, element, rarity, stars) -> { kind, value }`.
- Server applies perks through small hooks: CustomerService (spawn interval, queue patience, buy chance),
  StockService (delivery time), the owner's Humanoid WalkSpeed (restored on unsummon).

## 5. Creature art

- New repo folder `assets/creatures/`, mapped by Rojo to `ServerStorage.CreatureModels`.
- Workflow: Toolbox → insert a free creature → right-click the model → **Save to File** →
  `assets/creatures/<CardName>.rbxm` (spaces kept, e.g. `Abyssal Koi.rbxm`). Commit it.
- `CreatureModels` service code: finds the model by card name; on first use clones it, **deletes every
  Script, LocalScript and ModuleScript** inside, unanchors parts, makes them non-colliding and massless,
  picks/creates a root part, and scales it (`Model:ScaleTo`) to the rarity size. No model → placeholder
  (rounded body in the element colour with two eyes).
- Checklist for picking models (in the plan's Studio steps): free, creator you trust, no scripts in the
  Explorer, reasonable part count (< 200), creature-like and roughly the same style.
- DESIGN 5.5 caveat: Glimmerbeasts are an original IP; free models are a stand-in until own/commissioned art.

## 6. Server and remotes

- `PartyService`: party state per player, load/save/unload (registered after CardService and JobService),
  creature spawning and following, perks. CardService `SetPartied`/`IsPartied` lock (like working);
  `TakeBeast` refuses partied cards; JobService refuses partied cards.
- Remotes: `SetPartySlot(slot, target?)` (target = beastId or `{cardId, foil, grade}`; nil = remove),
  `Summon(slot?)` (nil = unsummon), `PartyChanged` (server → owner: slots + summoned + perk). Validated,
  rate-limited.

## 7. Studio tests

1. Binder → Add to party (plain copy becomes its own card) → Party panel shows it; up to 3.
2. Summon: the creature appears and follows you around the shop and street; others see it; Summon another
   card swaps it; Unsummon removes it.
3. Perk shown in the panel; Volt card: you walk faster; Ember: customers come more often (watch the spawn rate).
4. Party cards can't be displayed or given a job; can be condensed (the creature keeps following).
5. Drop a Creator Store model as `assets/creatures/<CardName>.rbxm`: that card's creature uses it, sized by
   rarity, with no scripts left inside; others still use the placeholder.
6. Die / respawn / teleport: the creature comes back to you. Stop → Play: party and summon restored.
