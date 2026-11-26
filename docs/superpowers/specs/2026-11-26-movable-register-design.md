# Movable register (testers 2026-11-26, owner's pick A)

Testers: "Make the cash register Moveable". Owner: "A, go" (move it like a shelf, anywhere in the hall with room for
the queue, saved with the shop).

## What moves
The whole checkout as one: the counter (the `Register` part every system reads), its plinth, top and LED strip, the
register unit (screen, drawer, card machine), the counter decor, the cashier's step behind it, the pendant lights over
it and the customers' queue zone in front. Built into a `Checkout` folder in the plot model and moved by one offset,
so `plot.register` stays the same part and everything reading it live (customers' queue spots, the cashier worker's
spot, the counter items, the register station's camera, Pish's cues, the hover tooltip) follows.

## Its footprint
One box on the shop's grid (`Util/CheckoutLayout.box`): as wide as its widest piece, from the queue's end in front to
the cashier step's back (6 x 22.9 studs: 3 x 12 cells), the counter toward the back. Four turns; customers always
queue on its front. It must fit like a shelf (`PlacementGrid.isFree`, its own pieces ignored: `FixtureId` "Register")
and stay in the hall (`CheckoutLayout.inHall`, rows 0-19), so never in a room or on a door's path. The default cell
(`Plots.REGISTER_GRID_X/Z` 1, 7, turn 0) puts the counter where it always stood (0.45 studs nearer the street).

## Moving it
The owner's own "Move" prompt (F) on the counter, like the order computer's: the placement ghost shows the counter, the
step and the queue strip over the footprint grid; Place sends `MoveFixture("Register", x, z, turn)`. The server checks
the cell again and refuses with the locked card while someone mans the register, a customer is checking out or
waiting in line (queued customers step to their spot in a straight line, so a moved queue could strand them on a
shelf), or the cell doesn't fit.

## Saved
`fixtures.Register = { gridX, gridZ, rotation }` beside the order computer's (the same map: no schema change; an old
save has none and keeps the default). Loading puts the register back first (checked against walls, rooms and the
spawn only), then the shelves (nudged off it if they must be), then the computer. A plot handed back resets it.

## My calls
- A move prompt rather than the Edit bar: the register isn't sold, so its only edit is Move (as the computer).
- Refused while anyone waits in line (simplest safe rule; the line empties between waves of customers).
- The hall only, even with rooms open: customers always reach the hall.
