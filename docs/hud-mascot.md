# HUD mascot

The creature peeking over the party bar (spec `docs/superpowers/specs/2026-11-03-hud-creature-pals-design.md`).
Today it's Pish (round 5, 2026-11-10; Cindercub before), and tapping him is the Pish button
(`HudMascotView.onTap`, TutorialController). Everything about it is in `src/shared/Config/HudMascot.luau`; the code (`Util/HudMascotView`,
`Util/HudMascotRules`) never names it, so replacing it is new pictures plus that file.

## Make the pictures

1. Generate one picture with Figma's image generator (card art file "Card Shop Tycoon - Card Art",
   `gemini-3.1-flash-image`, 1536 x 1024) holding two stickers on a flat plain pure green (#00FF00) background:
   - left, large: the creature peeking over a ledge, seen from the front, only its head and two front paws visible,
     paws resting side by side along the bottom edge, everything below them cut off by a straight line;
   - right, small, well apart: its tail alone.
   Describe the creature in the card art's painterly style (see `docs/card-art.md`); for a real pet, describe it from
   its photo (colours, markings, ears, eyes) and ask for "cute chibi" so it matches the HUD. Avoid green in the
   creature, or pick another flat background colour and change `cutout.py`'s keying.
2. `python tools/ui-art/cutout.py <picture.png> assets/ui/mascot <Name>_peek <Name>_tail` keys out the green, splits
   the two stickers and saves transparent PNGs (at most 512 px).
3. Upload both (Studio MCP `upload_image` from a local web server, e.g. `python -m http.server` in
   `assets/ui/mascot`), then draw each in a Play session and check `IsLoaded`.

## Fill in `Config/HudMascot`

- `name`, `images.peek`, `images.tail`: the new ids.
- `size`: keep each picture's own width-to-height shape (the peek sticker about 72 px wide).
- `eyes`: each eye's box on the peek picture as shares of its width and height (find the dark eye pixels with
  Pillow, as done for Cindercub), for blinking.
- `lid`: the fur colour right round the eyes; `crease`: the line drawn across a closed eye.
- `tail.at`, `tail.angle`: where the tail's bottom sits (pixels from the cushion's left end, down from its top edge)
  and how it leans; `tail.period`, `tail.degrees`: its sway.
- `voice`: its chirp when tapped (a Roblox-licensed Pro Sound Effects or APM sound), quiet.
- `tapArea`: keep it at least 69 px each way (48 px at the smallest HUD scale) and covering the paws.
- `headroom`, `offset`, `clipPad`: only if the new sticker is much taller, needs to sit elsewhere, or gets cut off
  while breathing.

Run `lune run tests/run HudMascotRules` (it checks the ids and eye boxes), then look at it in Studio on PC and a phone.
