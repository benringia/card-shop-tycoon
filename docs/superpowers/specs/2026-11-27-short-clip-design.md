# A short clip for TikTok, Shorts and Reels: design (2026-11-27)

## Why
More players. A ~22 s vertical clip of real gameplay the owner posts on TikTok, YouTube Shorts and Instagram Reels.
The game page video (Creator Hub) waits for the late-game recording the owner makes on 2026-11-28; this clip uses the
early-game recordings of 2026-11-27 (`Documents/clipping/OneMorePack`, five files, 57 min, 1080p60 with game sound).
The game is 16+ until it has 250 engaged players, so kids who see the clip can't join yet (the owner knows).

## Goals, non-goals, anti-goals
- Goals: a hook in the first second; the loop in order (pull a card, it comes alive, it beats a boss, loot, sell
  cards in your shop, one more pack); an invite to play (owner: "add an upsell element that invites people to play").
- Non-goals: the game page video; music (the owner adds a sound in the app); voice-over.
- Anti-goals: words that claim what the footage doesn't show (Design rules: marketing tells the truth); words or the
  invite under TikTok's own buttons (right edge, x 955-1065, y 860-1600 of 1080 x 1920) or caption (y 1640 and down);
  a first second that looks like an ad (the invite comes in after the hook).

## Constraints
1080 x 1920, 60 fps, H.264 (CRF 18, yuv420p, faststart) and AAC; Fredoka Bold words (`tools/ui-art/fonts`), plain
ASCII; white with the UI's dark plum outline, the key word gold. Two exports: with the game's sound (short fades at each
cut) and silent: Roblox licenses its music for use inside Roblox only and gameplay videos with it get copyright claims,
so the silent one plus a sound from the app's library is the safe post.

## Approaches
- **A, full screen** (owner's pick): a 608 x 1080 slice of the 1920 x 1080 frame, aimed at each shot's action, zoomed
  to fill the phone. Biggest on a phone and what the platforms' own clips look like; a wide menu loses its edges.
- B, the whole frame in a band with a blurred copy behind: everything shows but the game is small. Weakest.
- C, a 1080 square with a blurred copy behind: sharp, words in their own band; the runner-up.

## Shots (owner: "go with your shots")
| # | Footage | Words |
|---|---|---|
| 1 | Open 10, the gold sky tear, the Legendary phoenix card (R2 0:59.35-1:01.35) | I PULLED A / LEGENDARY |
| 2 | The phoenix swooping past the camera, then landing by its owner (R5 2:46.0-2:47.45) | IT CAME / ALIVE |
| 3 | Ember Colossus: FIGHT!, a crit, a slash, the SUPERNOVA! cinematic, the blast, VICTORY (R5 0:27.9-1:18.6) | IT FIGHTS / BOSSES |
| 4 | Picking a chest, the Magma Halberd, its mutation reveal (R5 1:23.8-1:30.2) | |
| 5 | The register: charge, the change, SOLD! +$9.00 (R1 13:07.4-13:11.0) | SELL CARDS IN / YOUR SHOP (on SOLD!) |
| 6 | The Open 10 grid turning (R2 0:55-0:57), looping back to shot 1 | ONE MORE / PACK... |
| 7 | The end card | |

Built (2026-11-27): the summon in the shop (R5 3:27.5) was a creature flying in and unsummoning, so shot 2 uses the
phoenix's swoop in the Wild; the register's words wait for SOLD! (the change screen fills the top of the slice).

## The play invite (my call; mockup `cta_options.jpg`)
- **The PLAY FREE badge**: a green button at the bottom left (x 36-656, y 1440-1600: clear of TikTok's buttons and
  caption) with the game's icon, "PLAY FREE", "on Roblox" and a play arrow. It slides in after the hook (about 2.5 s)
  and stays until the end card, a soft pulse every few seconds.
- **The end card** (about 2.8 s), over the Legendary's blurred glow: the game's icon pops in, ONE MORE PACK in gold, a
  search bar types "One More Pack" ("Search it on Roblox" under it), and a big PLAY FREE button pulses with Pish
  peeking over it.
- No Roblox logo (its name in words only). "Free" is true: the game costs nothing to play.

## Voice-over (added 2026-11-27, owner: "install it and bake the voice in")
- Kokoro (open model, run on this computer through kokoro-onnx, nothing sent anywhere), voice af_heart at 1.1x; model
  files in `Documents/clipping/tts/kokoro`. Samples of af_heart, af_bella, am_puck and am_michael in
  `clipping/OneMorePack/edit/voice_samples`; `--speaker` swaps it.
- Seven lines, each a shot's `say` (start inside the shot): "I pulled a Legendary...", "and it came alive!", "Now it
  fights bosses for me!", "Bosses drop new weapons!", "Then I sell cards in my own shop...", "and open one more pack!",
  and on the end card "One More Pack! Play free on Roblox!" (spelled "Roeblox" for the voice). SUPERNOVA! and VICTORY
  keep the game's own sound. A line waits when a slow voice runs long; past the clip's end it stops.
- Two more files: `OneMorePack_short_voice.mp4` (the game's sound turned down about 10 dB under the voice) and
  `OneMorePack_short_voice_only.mp4` (the voice alone, the safe post). Never on the game page video.

## The story clip (added 2026-11-27, to post on 11-28)
Owner: "make me another video that I can post tomorrow. this time make it square with blur background (C in your
earlier choices) use a different voice", then, after a storyboard of three ideas (story, shop POV, boss rush): "story
with am_michael, go". `make_short.py --clip story`, 25.7 s, the comeback told with the prologue's own footage:

| # | Footage | Words | Voice (am_michael, 1.05x) |
|---|---|---|---|
| 1 | The young Prism Hydra rises (R1 0:37.0-0:39.8, a slow push in) | A HYDRA STOLE / ALL MY CARDS | "A hydra stole every card I had..." |
| 2 | FIGHT!, fire, slashes; THUNDERSTORM! and its card; -739 (R1 0:47.35-0:49.6, 1:37.1-1:37.7, 1:39.0-1:39.45) | MY LEGENDARIES / COULDN'T STOP IT | "My Legendaries couldn't stop it." |
| 3 | The Hydra over you, swallowing the cards (R1 1:51.3-1:53.7) | IT SWALLOWED / THEM ALL | "It swallowed them all." |
| 4 | "Everything was gone." on black (R1 2:03.5-2:05.0) | EVERYTHING / WAS GONE... | "Everything was gone..." |
| 5 | Your eyes opening on Pish and Chikin (R1 2:08.85-2:11.5) | MY DOGS / WOKE ME UP | "until my dogs woke me up." |
| 6 | The first pack's tear, its RARE! (R1 2:41.7-2:42.6, 2:47.85-2:48.75) | SO I OPENED / ONE PACK | "So I opened one pack," |
| 7 | The shop's very first sale: EXACT!, SOLD! +$3.00 (R1 3:50.3-3:52.55) | SOLD MY / FIRST CARDS | "sold my first cards," |
| 8 | The Meadow Warden: fire, STRONG! hits, VICTORY (R5 2:59.05-3:01.65, 3:03.55-3:04.55) | AND FOUGHT / MY WAY BACK | "and fought my way back." |
| 9 | The Hydra again into a white flash (R1 1:47.6-1:49.9) | NOW I'M COMING / FOR THAT HYDRA | "Now I'm coming for that hydra." |
| 10 | The end card, 3.4 s, over the Hydra's blurred glow | | "One More Pack. Play free on Roblox!" |

Layout C: each shot's 1080 x 1080 square at 1:1 (no scaling: sharp) at y 420-1500 over a blurred, darkened copy of its
9:16 slice (blurred at an eighth of the size: quick), the words in the band above (y 150-400, 104 px), the badge under
the square (y 1478) from 3 s. TikTok's right-hand buttons sit over the square's right edge: nothing important is
aimed there. The prologue is the hook here although the game page video leaves it out (owner 2026-11-20): this is a
social clip. The loop clip renders exactly as before (old and new frames compared byte for byte).

## Build
`tools/video/make_short.py` (new, beside `make_trailer.py`): ffmpeg crops and scales each shot, Pillow draws the words,
the badge and the end card on every frame, the frames go to ffmpeg's encoder; the sound is cut and faded per shot.
Writes `OneMorePack_short.mp4` and `OneMorePack_short_silent.mp4` into `Documents/clipping/OneMorePack/edit`. A line in
CLAUDE.md (Commands) and DESIGN.md (beside the game page video); the vault's decisions log and Launch results'
marketing table.

## Left to the builder
Exact cut points and each shot's slice position (from the footage), the words' and invite's animation timing.
