# Battles, part 2: PvP challenges and the arena

Roadmap step 5 (DESIGN 5.8), second of three sub-projects. Part 1 (combat core + server wild map) is done;
part 3 is the Frontier place and boss challenges.

## 1. Goal

Players challenge each other to party battles for a cash bet. Both accept, both move to an arena pad, their
full parties fight with the same combat rules as the wild, the winner takes the pot, and 10 seconds later both
are back at their shops. Others can watch from the stands.

## 2. Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Fighters | Full parties, all on the field from the start (up to 3 vs 3) |
| Fairness | Real stats; challenge popups show both sides' total Power |
| Stakes | Cash bet held in escrow; winner takes the pot |
| Bet limit | min(challenger cash, target cash, $50 × the lower shop level); Friendly ($0) allowed |
| Arena | One stadium area in the same server with 3 pads and stands; anyone can watch |
| After the fight | Both go back to their shops after 10 s |
| Resting | No resting from PvP: every creature recovers when the fight ends |
| Leaving | Leave, reset or disconnect mid-fight = forfeit (opponent gets the pot); no Run in PvP |
| Draw | The time limit (2 min) ends in a draw: both bets refunded |
| Engine | BattleSim generalised to two sides; wild fights become party vs a one-monster side |

## 3. Challenge flow

1. Walk up to another player (within `CHALLENGE_DISTANCE`, 15 studs): a client-side "Challenge" prompt shows on
   their character.
2. Sender popup: bet slider from Friendly ($0) to the cap in $5 steps, and both parties' total Power
   (BeastRules.getPower summed). "Send".
3. Server checks: both online and loaded, neither in a fight or a pending challenge, both have at least one party
   card that isn't resting from the wild, the sender can afford the bet, the bet is within the cap, distance, the
   sender's challenge cooldown (10 s) and that this pair isn't blocked (30 s after a decline).
4. Target popup: "Ben challenges you · bet $40 · Your Power 1,240 vs 3,980", Accept / Decline, 15 s timer
   (no answer = decline).
5. Accept: server re-checks everything, then takes both bets with `EconomyService.TrySpend` (if either fails,
   the challenge is cancelled and anything taken is refunded). Then a free pad is reserved; if all 3 are busy the
   match waits in a queue ("Waiting for a free arena pad...") and starts when one frees up (escrow already taken;
   leaving the queue refunds both).

## 4. Fight rules

- Each side: the player's party cards that exist and aren't resting from the wild, in slot order. Stats from
  BeastRules.getStats; signatures as in part 1.
- Same combat as part 1: attacks on their own timers, element wheel, element abilities (8 s), signatures (15 s).
- Targeting: every fighter attacks the standing enemy with the lowest HP share (ties: list order).
- Abilities act on the user's side: Wave and Tidal Shield cover your side; Fireball, Supernova, Devour, Stampede,
  Curse, Vine Snare and Inferno hit the enemy that fighter is targeting; Overcharge and Eclipse are on the user.
- No call-in (everyone starts), no Run. The leash from part 1 keeps players on their half of the pad.
- End: a side with no standing fighters loses. `MAX_FIGHT_SECONDS` (120) → draw. A player leaving, resetting or
  their character disappearing → forfeit, that player loses. Both gone in the same tick → draw (refund).
- Payout: win → winner gets 2 × bet; draw → both get their bet back. Through EconomyService only.
- Wins, losses and draws are saved per player and shown in the Party panel ("PvP 12-5-1").
- No resting, no XP, no card drops from PvP.

## 5. The fight engine (BattleSim generalised)

- `BattleSim.new(combat, sideA, sideB, seed, options)`; a side is
  `{ fighters = { FighterInput }, reserves = { FighterInput }?, abilities = boolean, canRun = boolean }`.
- Fighter ids are prefixed by side (`a:<id>`, `b:<id>`) inside the sim; events and snapshots use those ids.
- Effects (stun, slow, curse, burn, dodge, overcharge) live on fighters; shields on sides.
- `step(state, dt)`, `useAbility(state, id, which)`, `callIn(state, id)`, `tryRun(state)`, `forfeit(state, side)`,
  `snapshot(state)`; results are `"a"`, `"b"`, `"draw"`, `"run"`.
- Wild fights: side A = the party (leader + call-in reserves, abilities, can run); side B = the monster (no
  abilities). Behaviour stays as in part 1, and every part 1 BattleSim test is kept (ported to the new API).
- BattleService (wild) and the new ArenaService both use it.

## 6. The arena

- Built in code far from the shops and the wild (`ARENA_ORIGIN`), with a plaza portal "Arena" next to the wild
  one so spectators can walk in, and a "Return" portal in the stands.
- 3 pads in a row, each a ring `PAD_SIZE` (40 studs) across with low walls, side spawn spots and stands around it.
- Fighters are streamed in (RequestStreamAroundAsync) and moved to opposite ends of their pad; their creatures
  (party markers, as for summoned creatures) line up in front of them facing the other side. A floating HP bar
  over each creature lets spectators follow.
- After the result, a 10 s countdown, then both go back to their plot spawns.

## 7. Screens

- Challenge (sender): target name, bet slider + presets (Friendly, $10, $25, $50, max), both Powers, Send / Cancel.
- Challenge (target): sender, bet, both Powers, Accept / Decline with a countdown.
- Fight bar (shared with the wild BattleController): enemy row of compact HP bars with element icons; your
  creatures with HP bars and ability buttons (signature as a second button). All buttons ≥ 48 px. No Run.
- End: "You win! +$80" / "You lose · -$40" / "Draw · bets returned" / "Opponent left · you win +$80", with a
  10 s countdown home.
- Party panel header: "PvP 12-5-1".

## 8. Data, locks and abuse

- Schema v9: `pvp = { wins = 0, losses = 0, draws = 0 }`; load clamps to non-negative integers.
- Escrow is server-side state only. If a player leaves before the fight starts, both bets are refunded; mid-fight,
  the leaver forfeits. The leave path runs in `DataService.OnBeforeLeave` so payouts land before saves. Server
  shutdown mid-fight: both refunded before the final save.
- Locks as in part 1: party changes, summons, condensing, jobs, travel and wild fights are refused for both players
  during a PvP fight (PartyService.SetLocked, CardService fighting flags), and a wild fight blocks challenges.
- Abuse: one pending challenge per player, 10 s challenge cooldown, a decline blocks that pair for 30 s, all
  remotes rate-limited and validated (types, ranges, distance, cash, cap).

## 9. Testing

Lune:
- BattleSim (generalised): all part 1 tests ported; 3v3 even parties end with a winner and replay identically by
  seed; Wave heals only its own side; Curse/Snare/stun hit the targeted enemy; timeout → draw when neither side
  can run; forfeit ends at once with the other side winning.
- PvpRules (pure): bet cap (cash, shop level, Friendly), payout for win/draw/forfeit, record update.
- Migration v9 adds `pvp`.

Studio (Local Server, 2 players):
1. Walk up to the other player → Challenge → set a bet → they see the popup with both Powers → Accept.
2. Both move to a pad; full parties fight; abilities work; spectators in the stands see HP bars.
3. Winner gets 2 × bet, loser's cash dropped by the bet; 10 s later both are home.
4. Decline / no answer: nothing taken; challenging again within 30 s is refused.
5. Leave mid-fight: the other player gets the pot. Reset mid-fight: same.
6. Bets above the cap or above either player's cash are refused. Friendly fights move no cash.
7. Party changes, summons, travel and wild fights are refused during a PvP fight; afterwards everything works.
8. Phone (landscape): challenge popups and the fight bar fit and are tappable.

## 10. Out of scope (later)
Ranked rating and leaderboards; spectator camera; tournaments; the Frontier and bosses (part 3).
