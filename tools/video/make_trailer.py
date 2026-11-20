"""Cuts the game page's gameplay video from one long recording (owner 2026-11-20).

    python tools/video/make_trailer.py <recording.mp4> <out.mp4> [--mute]

Needs Pillow and imageio-ffmpeg (`pip install pillow imageio-ffmpeg`: it brings its own ffmpeg).

Roblox's rules for a game's video (Creator Hub, Thumbnails): real gameplay only, no voice-over, no music with lyrics, no
ads or claims; a logo and a few words that describe the gameplay are fine. So: hard cuts of the recording, its own game
sound (short fades at each cut so nothing clicks), a few captions and the game's name on the last shot.

CLIPS: (start, end, caption) in seconds of the recording, in the video's order. Re-cut for a new recording by
changing them; contact sheets with times help (`ffmpeg -vf fps=1,scale=320:180,tile=6x8`).
"""
import os
import subprocess
import sys
import tempfile

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "ui-art", "fonts", "Fredoka.ttf")
SIZE = (1920, 1080)
FPS = 60
INK = (255, 255, 255, 255)
EDGE = (44, 35, 64, 255)  # the UI's dark plum
GOLD = (255, 207, 74, 255)

# (start, end, caption): about 30 s in all
CLIPS = [
    (150.6, 152.8, "RIP PACKS"),  # the pack tears open
    (156.7, 158.7, None),  # RARE! flash and the card
    (656.0, 657.8, None),  # Open 10: fifty cards turning
    (700.0, 701.4, "COLLECT THEM ALL"),  # the binder
    (433.2, 435.5, "RUN YOUR CARD SHOP"),  # exact change, SOLD!
    (110.0, 111.4, None),  # Pish and Chikin
    (325.0, 327.0, "BATTLE WITH YOUR CARDS"),  # a wild fight
    (778.0, 780.0, None),  # the Meadow Warden
    (811.5, 814.0, "BEAT BOSSES"),  # the last hits
    (815.6, 817.0, None),  # VICTORY!
    (823.5, 825.7, None),  # the boss chests
    (16.8, 18.4, None),  # the young Prism Hydra
    (33.4, 36.1, None),  # the maxed Rift Reaper's Thousand Cuts (owner 2026-11-20: "insert a shot with the maxed out scythe")
    (51.8, 54.0, None),  # Supernova
    (1021.5, 1024.0, "@title"),  # the plaza at night, the game's name over it
]
TITLE = "ONE MORE PACK"
CUT_FADE = 0.06  # seconds of sound faded at each cut


def font(size: int) -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT, size)
    face.set_variation_by_name("Bold")
    return face


def caption_png(text: str, path: str):
    """A caption low on the screen: white Fredoka Bold with a dark plum outline; the title big and gold in the middle."""
    image = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    title = text == "@title"
    words = TITLE if title else text
    face = font(190 if title else 92)
    box = draw.textbbox((0, 0), words, font=face, stroke_width=12 if title else 8)
    width, height = box[2] - box[0], box[3] - box[1]
    x = (SIZE[0] - width) / 2 - box[0]
    y = ((SIZE[1] - height) / 2 if title else SIZE[1] - 190 - height) - box[1]
    draw.text((x + 6, y + 8), words, font=face, fill=(0, 0, 0, 120), stroke_width=12 if title else 8, stroke_fill=(0, 0, 0, 120))
    draw.text((x, y), words, font=face, fill=GOLD if title else INK, stroke_width=12 if title else 8, stroke_fill=EDGE)
    image.save(path)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    mute = "--mute" in sys.argv
    if len(args) != 2:
        sys.exit(__doc__)
    source, out = args
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    work = tempfile.mkdtemp(prefix="trailer_")
    command = [ffmpeg, "-hide_banner", "-loglevel", "error", "-y"]
    for start, end, _ in CLIPS:
        command += ["-ss", f"{start}", "-to", f"{end}", "-i", source]
    captions = []
    for index, (_, _, text) in enumerate(CLIPS):
        if text:
            path = os.path.join(work, f"caption_{index}.png")
            caption_png(text, path)
            captions.append((index, len(CLIPS) + len(captions)))
            command += ["-i", path]
    overlay_of = dict(captions)
    parts = []
    for index, (start, end, _) in enumerate(CLIPS):
        length = end - start
        video = f"[{index}:v]fps={FPS},scale={SIZE[0]}:{SIZE[1]},setsar=1,setpts=PTS-STARTPTS[v{index}]"
        if index in overlay_of:
            video = (
                f"[{index}:v]fps={FPS},scale={SIZE[0]}:{SIZE[1]},setsar=1,setpts=PTS-STARTPTS[b{index}];"
                f"[b{index}][{overlay_of[index]}:v]overlay=0:0[v{index}]"
            )
        parts.append(video)
        if not mute:
            parts.append(
                f"[{index}:a]asetpts=PTS-STARTPTS,afade=t=in:d={CUT_FADE},afade=t=out:st={max(0, length - CUT_FADE):.3f}:d={CUT_FADE}[a{index}]"
            )
    streams = "".join(f"[v{i}]" + ("" if mute else f"[a{i}]") for i in range(len(CLIPS)))
    parts.append(f"{streams}concat=n={len(CLIPS)}:v=1:a={0 if mute else 1}[v]" + ("" if mute else "[a]"))
    command += ["-filter_complex", ";".join(parts), "-map", "[v]"]
    if not mute:
        command += ["-map", "[a]", "-c:a", "aac", "-b:a", "160k"]
    command += ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out]
    subprocess.run(command, check=True)
    total = sum(end - start for start, end, _ in CLIPS)
    print(f"wrote {out}: {len(CLIPS)} clips, {total:.1f} s" + (" (no sound)" if mute else ""))


if __name__ == "__main__":
    main()
