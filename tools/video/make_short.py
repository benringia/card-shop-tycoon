"""Cuts short vertical clips for TikTok, YouTube Shorts and Instagram Reels from the owner's recordings (owner
2026-11-27; design: docs/superpowers/specs/2026-11-27-short-clip-design.md).

    python tools/video/make_short.py <recordings folder> <out folder> [--clip loop|story]
                                     [--voice <kokoro folder>] [--speaker <voice>] [--reuse-video]

The clips (CLIPS):
- loop (default, OneMorePack_short*): ~21 s, full screen: a 608 x 1080 slice of each shot, aimed at its action and
  zoomed to fill 1080 x 1920. Pull a Legendary, it comes alive, it beats a boss, loot, sell cards, one more pack.
- story (OneMorePack_story*): ~26 s, a square: 1080 x 1080 of each shot over a blurred copy of the frame, words in the
  band above. The prologue's Hydra takes every card, the dogs wake you, one pack, the first sale, a boss won, back for
  the Hydra.

Each clip writes <name>.mp4 (the game's own sound) and <name>_silent.mp4 (for a sound added in the app: Roblox licenses
its music for use inside Roblox only, and gameplay videos with it get copyright claims). Needs Pillow and
imageio-ffmpeg (`pip install pillow imageio-ffmpeg`: it brings its own ffmpeg).

--voice adds an AI voice-over said by Kokoro on this computer (`pip install kokoro-onnx soundfile`, then
kokoro-v1.0.onnx and voices-v1.0.bin from github.com/thewh1teagle/kokoro-onnx releases in one folder): writes
<name>_voice.mp4 (the voice over the game's sound, turned down while it speaks) and <name>_voice_only.mp4 (the voice
alone: the safe post, a sound can go under it in the app). Each shot's `say` line starts at its time in the shot, in
the clip's own voice unless --speaker. Never on the game page video: Roblox rejects voice-over there.
--reuse-video takes the picture from the clip's silent file already in the out folder (the sound and voice only).

The words sit at the top and the PLAY FREE badge bottom left, clear of TikTok's own buttons (right edge, y 860-1600)
and caption (y 1640 and down); the badge comes in after the hook so the first seconds don't look like an ad, and the
end card invites to play. Re-cut for new recordings by changing RECORDINGS and a clip's shots (contact sheets with
times help: `ffmpeg -vf fps=1,scale=320:180,tile=6x8`).
"""
import argparse
import math
import os
import shutil
import subprocess
import sys
import tempfile
from typing import NamedTuple

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.normpath(os.path.join(HERE, "..", ".."))
FONT = os.path.join(REPO, "tools", "ui-art", "fonts", "Fredoka.ttf")
ICON = os.path.join(REPO, "assets", "ui", "game-page", "icon_512.png")
PISH = os.path.join(REPO, "assets", "ui", "mascot", "Pish_peek.png")

W, H, FPS = 1080, 1920, 60
SOURCE_W, SOURCE_H = 1920, 1080
SLICE = 608  # the 9:16 slice of a 1080-high frame
INK = (255, 255, 255)
EDGE = (44, 35, 64)  # the UI's dark plum
GOLD = (255, 207, 74)
GREEN = (60, 203, 120)
GREEN_DARK = (32, 150, 86)
SHARPEN = ImageFilter.UnsharpMask(radius=2, percent=45, threshold=3)
WORDS_GAP = 14
POP = 0.22  # seconds a word or a piece takes to pop in
CUT_FADE = 0.03  # seconds of sound faded at each cut
VOICE_GAP = 0.05  # seconds kept between two lines when a slower voice runs long

RECORDINGS = {
    "R1": "Desktop 2026.11.27 - 00.11.46.02.mp4",  # the prologue, Pish's tour, the shop and its register
    "R2": "Desktop 2026.11.27 - 00.42.44.03.mp4",  # Open 10 and the Legendary phoenix
    "R5": "Desktop 2026.11.27 - 01.28.28.06.mp4",  # the phoenix in the Wild, the bosses, their chests
}


class Shot(NamedTuple):
    recording: str
    start: float
    end: float
    aim: tuple  # (seconds into the shot, centre x in the recording) keys, eased between
    words: tuple = ()  # (text, colour, seconds into the shot it pops in; below 0: already up), top line first
    zoom: tuple = (1.0, 1.0)  # at the shot's start and end
    say: tuple = ()  # (seconds into the shot, words the voice-over says)


class Layout(NamedTuple):
    square: bool  # False: a 9:16 slice fills the phone; True: a square over a blurred copy of the frame
    words_top: int
    words_size: int
    badge_at: tuple
    square_top: int = 0


class Clip(NamedTuple):
    name: str  # its files: <name>.mp4, <name>_silent.mp4, <name>_voice.mp4, <name>_voice_only.mp4
    shots: list
    layout: Layout
    badge_in: float  # seconds into the clip the PLAY FREE badge slides in
    end_card: float  # seconds
    end_card_back: tuple  # (recording, seconds, centre x): blurred behind the end card
    end_card_say: tuple  # (seconds into the end card, words)
    speaker: str  # the Kokoro voice
    speed: float


FULL = Layout(square=False, words_top=170, words_size=118, badge_at=(36, 1440))
SQUARE = Layout(square=True, words_top=150, words_size=104, badge_at=(36, 1478), square_top=420)


def popping(words: tuple) -> tuple:
    """The same words, popping in as the shot starts."""
    return tuple((text, colour, 0.0) for text, colour, _ in words)


ALIVE = (("IT CAME", INK, -1), ("ALIVE", GOLD, -1))
BOSSES = (("IT FIGHTS", INK, -1), ("BOSSES", GOLD, -1))
LOOP = Clip(
    name="OneMorePack_short",
    shots=[
        # the hook: Open 10 tears the sky and the Legendary phoenix lands
        Shot("R2", 59.35, 61.35, ((0, 960),), (("I PULLED A", INK, -1), ("LEGENDARY", GOLD, 0.85)), (1.0, 1.06),
             say=(0.1, "I pulled a Legendary...")),
        # the phoenix swoops past the camera, then lands by its owner
        Shot("R5", 166.0, 166.38, ((0, 1600),), popping(ALIVE), say=(-0.05, "and it came alive!")),
        Shot("R5", 166.7, 167.45, ((0, 1540), (0.3, 1340), (0.5, 1320), (0.75, 1420)), ALIVE),
        # the Ember Colossus: FIGHT! and a crit, a slash, SUPERNOVA!, its blast, VICTORY (the game's own sound)
        Shot("R5", 27.9, 29.5, ((0, 1000), (1.6, 960)), popping(BOSSES), say=(0.17, "Now it fights bosses for me!")),
        Shot("R5", 30.3, 31.3, ((0, 900),), BOSSES),
        Shot("R5", 71.9, 72.9, ((0, 1150), (0.9, 1612))),
        Shot("R5", 74.5, 76.1, ((0, 960),)),
        Shot("R5", 77.2, 78.6, ((0, 960),)),
        # its chests: pick one, the Magma Halberd, its mutation
        Shot("R5", 83.8, 85.0, ((0, 960),), say=(0.12, "Bosses drop new weapons!")),
        Shot("R5", 86.6, 87.3, ((0, 960),)),
        Shot("R5", 88.85, 90.2, ((0, 960),)),
        # the register: charge, the change, SOLD! (the words wait for SOLD!: the change screen fills the top)
        Shot("R1", 787.4, 787.9, ((0, 980),), say=(0.07, "Then I sell cards in my own shop...")),
        Shot("R1", 788.3, 789.3, ((0, 900),)),
        Shot("R1", 789.6, 791.0, ((0, 800),), (("SELL CARDS IN", INK, 0.0), ("YOUR SHOP", GOLD, 0.0))),
        # Open 10 turning over, back to the hook
        Shot("R2", 55.0, 57.0, ((0, 960),), (("ONE MORE", INK, 0.0), ("PACK...", GOLD, 0.0)),
             say=(0.07, "and open one more pack!")),
    ],
    layout=FULL,
    badge_in=2.4,
    end_card=2.8,
    end_card_back=("R2", 60.6, 960),  # the Legendary's glow
    end_card_say=(0.27, "One More Pack! Play free on Roeblox!"),  # Roblox spelled the way it's said (ROH-blox)
    speaker="af_heart",  # Kokoro's warm American voice; others: af_bella, am_puck, am_michael...
    speed=1.1,
)

HYDRA = (("A HYDRA STOLE", INK, -1), ("ALL MY CARDS", GOLD, -1))
LEGENDS = (("MY LEGENDARIES", INK, -1), ("COULDN'T STOP IT", GOLD, -1))
SWALLOWED = (("IT SWALLOWED", INK, -1), ("THEM ALL", GOLD, -1))
GONE = (("EVERYTHING", INK, -1), ("WAS GONE...", GOLD, -1))
PACK = (("SO I OPENED", INK, -1), ("ONE PACK", GOLD, -1))
SOLD = (("SOLD MY", INK, -1), ("FIRST CARDS", GOLD, -1))
FOUGHT = (("AND FOUGHT", INK, -1), ("MY WAY BACK", GOLD, -1))
STORY = Clip(
    name="OneMorePack_story",
    shots=[
        # the hook: the prologue's young Prism Hydra rises
        Shot("R1", 37.0, 39.8, ((0, 960),), HYDRA, (1.0, 1.08), say=(0.15, "A hydra stole every card I had...")),
        # the lent maxed Legendaries throw everything at it: FIGHT!, fire, slashes, Thunderstorm's -739
        Shot("R1", 47.35, 49.6, ((0, 960),), popping(LEGENDS), say=(0.1, "My Legendaries couldn't stop it.")),
        Shot("R1", 97.1, 97.7, ((0, 1340),), LEGENDS),  # THUNDERSTORM! and the Stormking card both in the square
        Shot("R1", 99.0, 99.45, ((0, 960),), LEGENDS),
        # it stands over you and swallows the cards (the game's line under it)
        Shot("R1", 111.3, 113.7, ((0, 1000),), popping(SWALLOWED), say=(0.25, "It swallowed them all.")),
        # "Everything was gone." on black
        Shot("R1", 123.5, 125.0, ((0, 960),), popping(GONE), say=(0.1, "Everything was gone...")),
        # your eyes open on Pish and Chikin
        Shot("R1", 128.85, 131.5, ((0, 840),), (("MY DOGS", INK, 0.3), ("WOKE ME UP", GOLD, 0.3)),
             say=(0.35, "until my dogs woke me up.")),
        # the first pack: the tear, then a RARE!
        Shot("R1", 161.7, 162.6, ((0, 960),), popping(PACK), say=(0.1, "So I opened one pack,")),
        Shot("R1", 167.85, 168.75, ((0, 960),), PACK),
        # the shop's very first sale: the change, EXACT!, SOLD! +$3.00
        Shot("R1", 230.3, 231.05, ((0, 1000),), popping(SOLD), say=(0.05, "sold my first cards,")),
        Shot("R1", 231.35, 232.55, ((0, 980),), SOLD),
        # the Meadow Warden: fire, STRONG! hits, slashes, VICTORY
        Shot("R5", 179.05, 181.65, ((0, 1000),), popping(FOUGHT), say=(0.15, "and fought my way back.")),
        Shot("R5", 183.55, 184.55, ((0, 1000),), FOUGHT),
        # the Hydra again, its crystals shifting, into a white flash
        Shot("R1", 107.6, 109.9, ((0, 1150),), (("NOW I'M COMING", INK, 0.0), ("FOR THAT HYDRA", GOLD, 0.0)),
             say=(0.05, "Now I'm coming for that hydra.")),
    ],
    layout=SQUARE,
    badge_in=3.0,
    end_card=3.4,
    end_card_back=("R1", 108.4, 1150),  # the Hydra's crystal glow
    end_card_say=(0.3, "One More Pack. Play free on Roeblox!"),
    speaker="am_michael",  # a deep storyteller
    speed=1.05,
)
CLIPS = {"loop": LOOP, "story": STORY}


def font(size: int, weight: str = "Bold") -> ImageFont.FreeTypeFont:
    face = ImageFont.truetype(FONT, size)
    face.set_variation_by_name(weight)
    return face


def clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def ease_out_back(p: float) -> float:
    """0 to 1 overshooting a little before it settles: the UI's pop."""
    return 1 + 2.70158 * (p - 1) ** 3 + 1.70158 * (p - 1) ** 2


def smoothstep(p: float) -> float:
    return p * p * (3 - 2 * p)


def frame_count(shot: Shot) -> int:
    return round((shot.end - shot.start) * FPS)


def aim_at(shot: Shot, t: float) -> float:
    keys = shot.aim
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, x0), (t1, x1) in zip(keys, keys[1:]):
        if t <= t1:
            return x0 + (x1 - x0) * smoothstep((t - t0) / (t1 - t0))
    return keys[-1][1]


def slice_box(centre: float, zoom: float) -> tuple:
    """The 9:16 part of the source frame that fills the phone, kept inside the frame."""
    width, height = SLICE / zoom, SOURCE_H / zoom
    left = max(0.0, min(SOURCE_W - width, centre - width / 2))
    top = (SOURCE_H - height) / 2
    return left, top, left + width, top + height


def square_box(centre: float, zoom: float) -> tuple:
    """The square part of the source frame, kept inside the frame."""
    side = SOURCE_H / zoom
    left = max(0.0, min(SOURCE_W - side, centre - side / 2))
    top = (SOURCE_H - side) / 2
    return left, top, left + side, top + side


def blurred_back(frame: Image.Image, centre: float) -> Image.Image:
    """A blurred, darkened copy of the frame's 9:16 slice behind the square (blurred small: quick)."""
    small = frame.resize((W // 8, H // 8), Image.BILINEAR, box=slice_box(centre, 1.0))
    small = small.filter(ImageFilter.GaussianBlur(5))
    return small.resize((W, H), Image.BICUBIC).point(lambda value: value * 55 // 100)


def compose(layout: Layout, frame: Image.Image, centre: float, zoom: float) -> Image.Image:
    """The phone's picture of one recording frame."""
    if not layout.square:
        return frame.resize((W, H), Image.LANCZOS, box=slice_box(centre, zoom)).filter(SHARPEN)
    image = blurred_back(frame, centre)
    box = square_box(centre, zoom)
    if abs((box[2] - box[0]) - W) < 0.5:
        square = frame.crop(tuple(round(value) for value in box))
    else:
        square = frame.resize((W, W), Image.LANCZOS, box=box).filter(SHARPEN)
    image.paste(square, (0, layout.square_top))
    return image


def shadowed_text(text: str, face: ImageFont.FreeTypeFont, fill, stroke: int) -> Image.Image:
    """Words in the game's look: a dark plum outline and a soft drop shadow."""
    box = ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), text, font=face, stroke_width=stroke)
    image = Image.new("RGBA", (box[2] - box[0] + 30, box[3] - box[1] + 34), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    at = (12 - box[0], 10 - box[1])
    draw.text((at[0] + 6, at[1] + 9), text, font=face, fill=(0, 0, 0, 170), stroke_width=stroke, stroke_fill=(0, 0, 0, 170))
    draw.text(at, text, font=face, fill=fill, stroke_width=stroke, stroke_fill=EDGE)
    return image


def faded(image: Image.Image, alpha: float) -> Image.Image:
    if alpha >= 1:
        return image
    out = image.copy()
    out.putalpha(image.getchannel("A").point(lambda a: int(a * alpha)))
    return out


def paste_scaled(base: Image.Image, piece: Image.Image, centre: tuple, scale: float, alpha: float = 1.0):
    """Pastes a piece with its centre at `centre`, scaled and faded (the pops and pulses)."""
    if scale <= 0.01 or alpha <= 0:
        return
    if abs(scale - 1) > 0.001:
        piece = piece.resize((max(1, round(piece.width * scale)), max(1, round(piece.height * scale))), Image.BICUBIC)
    piece = faded(piece, alpha)
    base.paste(piece, (round(centre[0] - piece.width / 2), round(centre[1] - piece.height / 2)), piece)


def popped(t: float, start: float) -> tuple:
    """Scale and opacity of a piece popping in at `start` (already up when start < 0)."""
    if start < 0:
        return 1.0, 1.0
    p = clamp01((t - start) / POP)
    return 0.55 + 0.45 * ease_out_back(p), clamp01(p * 3)


def play_triangle(draw: ImageDraw.ImageDraw, cx: float, cy: float, size: float, fill):
    draw.polygon([(cx - size * 0.4, cy - size * 0.5), (cx - size * 0.4, cy + size * 0.5), (cx + size * 0.55, cy)], fill=fill)


def rounded_icon(size: int, radius: int, border: int) -> Image.Image:
    icon = Image.open(ICON).convert("RGBA").resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    out = Image.new("RGBA", (size + border * 2, size + border * 2), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle((0, 0, out.width - 1, out.height - 1), radius + border, fill=INK)
    out.paste(icon, (border, border), mask)
    return out


def green_button(width: int, height: int, outline: int) -> Image.Image:
    """A soft green button with a darker bottom edge and a shadow, like the game's buttons."""
    image = Image.new("RGBA", (width + 16, height + 26), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    radius = height // 2
    draw.rounded_rectangle((6, 16, width + 6, height + 16), radius, fill=(0, 0, 0, 120))
    draw.rounded_rectangle((0, 9, width, height + 9), radius, fill=GREEN_DARK, outline=EDGE, width=outline)
    draw.rounded_rectangle((0, 0, width, height), radius, fill=GREEN, outline=EDGE, width=outline)
    return image


def play_circle(draw: ImageDraw.ImageDraw, cx: float, cy: float, radius: float, outline: int):
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=INK, outline=EDGE, width=outline)
    play_triangle(draw, cx + 2, cy, radius * 0.85, GREEN_DARK)


def make_badge() -> Image.Image:
    """PLAY FREE / on Roblox, the game's icon on its left and a play arrow on its right."""
    width, height = 600, 132
    image = green_button(width, height, 6)
    draw = ImageDraw.Draw(image)
    icon = rounded_icon(100, 24, 5)
    image.alpha_composite(icon, (14, (height - icon.height) // 2))
    draw.text((138, 10), "PLAY FREE", font=font(60), fill=INK, stroke_width=5, stroke_fill=EDGE)
    draw.text((140, 74), "on Roblox", font=font(38, "SemiBold"), fill=INK, stroke_width=4, stroke_fill=EDGE)
    play_circle(draw, width - 66, height / 2, 44, 5)
    return image


def badge_layer(base: Image.Image, badge: Image.Image, clip_t: float, clip: Clip):
    """Slides in from the left at the clip's badge_in, then a soft pulse every few seconds."""
    if clip_t < clip.badge_in:
        return
    left, top = clip.layout.badge_at
    p = clamp01((clip_t - clip.badge_in) / 0.4)
    x = -badge.width + (left + badge.width) * ease_out_back(p)
    since = clip_t - clip.badge_in - 0.8
    pulse = clamp01((since % 2.6) / 0.45) if since > 0 else 1.0
    scale = 1 + 0.07 * math.sin(math.pi * pulse)
    paste_scaled(base, badge, (x + badge.width / 2, top + badge.height / 2), scale)


def words_layer(base: Image.Image, lines: list, words: tuple, t: float, layout: Layout):
    for index, ((_, _, start), image) in enumerate(zip(words, lines)):
        scale, alpha = popped(t, start)
        centre_y = layout.words_top + index * (layout.words_size + WORDS_GAP) + image.height / 2
        paste_scaled(base, image, (W / 2, centre_y), scale, alpha)


def ffmpeg_exe() -> str:
    return imageio_ffmpeg.get_ffmpeg_exe()


def source_path(folder: str, recording: str) -> str:
    return os.path.join(folder, RECORDINGS[recording])


def read_frames(path: str, start: float, count: int):
    """The recording's frames from `start`, as RGB images, decoded by ffmpeg."""
    process = subprocess.Popen(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-ss", f"{start:.3f}", "-i", path, "-an", "-vf",
         f"fps={FPS}", "-frames:v", str(count), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE)
    size = SOURCE_W * SOURCE_H * 3
    for _ in range(count):
        raw = process.stdout.read(size)
        if len(raw) < size:
            break
        yield Image.frombytes("RGB", (SOURCE_W, SOURCE_H), raw)
    process.stdout.close()
    if process.wait() != 0:
        sys.exit(f"ffmpeg could not read {path} at {start} s")


def still(folder: str, recording: str, at: float) -> Image.Image:
    return list(read_frames(source_path(folder, recording), at, 1))[0]


class EndCard:
    """The play invite: the icon, ONE MORE PACK, a search bar typing the name, PLAY FREE with Pish peeking."""

    SEARCH = "One More Pack"
    BAR = (110, 880, 940, 1000)
    BUTTON = (150, 1300, 890, 1450)

    def __init__(self, back: Image.Image, centre: float):
        blurred = back.resize((W, H), Image.LANCZOS, box=slice_box(centre, 1.0))
        blurred = blurred.filter(ImageFilter.GaussianBlur(30))
        self.back = Image.blend(blurred, Image.new("RGB", (W, H), EDGE), 0.5)
        self.icon = rounded_icon(430, 70, 12).rotate(-4, resample=Image.BICUBIC, expand=True)
        self.title = shadowed_text("ONE MORE PACK", font(124), GOLD, 12)
        self.hint = shadowed_text("Search it on Roblox", font(50), INK, 6)
        self.bar = self.search_bar()
        self.button = self.play_button()
        pish = Image.open(PISH).convert("RGBA")
        self.pish = pish.resize((250, round(250 * pish.height / pish.width)), Image.LANCZOS)
        self.typing_face = font(64, "SemiBold")

    def search_bar(self) -> Image.Image:
        left, top, right, bottom = self.BAR
        image = Image.new("RGBA", (right - left + 12, bottom - top + 16), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        draw.rounded_rectangle((6, 10, right - left + 6, bottom - top + 10), 60, fill=(0, 0, 0, 120))
        draw.rounded_rectangle((0, 0, right - left, bottom - top), 60, fill=INK, outline=EDGE, width=6)
        draw.ellipse((54, 26, 106, 78), outline=EDGE, width=10)  # the magnifier
        draw.line((98, 70, 122, 94), fill=EDGE, width=14)
        return image

    def play_button(self) -> Image.Image:
        left, top, right, bottom = self.BUTTON
        image = green_button(right - left, bottom - top, 7)
        draw = ImageDraw.Draw(image)
        face = font(92)
        box = draw.textbbox((0, 0), "PLAY FREE", font=face, stroke_width=7)
        draw.text((70 - box[0], (bottom - top - (box[3] - box[1])) / 2 - box[1]), "PLAY FREE", font=face, fill=INK,
                  stroke_width=7, stroke_fill=EDGE)
        play_circle(draw, right - left - 84, (bottom - top) / 2, 53, 6)
        return image

    def frame(self, u: float) -> Image.Image:
        image = self.back.copy()
        scale, alpha = popped(u, 0.0)
        paste_scaled(image, self.icon, (W / 2, 200 + self.icon.height / 2), scale, alpha)
        scale, alpha = popped(u, 0.15)
        paste_scaled(image, self.title, (W / 2, 700 + self.title.height / 2), scale, alpha)
        self.draw_search(image, u)
        alpha = clamp01((u - 1.2) / 0.25)
        paste_scaled(image, self.hint, (525, 1022 + self.hint.height / 2), 1.0, alpha)
        self.draw_button(image, u)
        return image

    def draw_search(self, image: Image.Image, u: float):
        p = clamp01((u - 0.35) / 0.25)
        if p <= 0:
            return
        left, top, _, _ = self.BAR
        rise = (1 - smoothstep(p)) * 40
        paste_scaled(image, self.bar, (left + self.bar.width / 2, top + rise + self.bar.height / 2), 1.0, p)
        typed = self.SEARCH[: int(clamp01((u - 0.6) / 0.8) * len(self.SEARCH))]
        draw = ImageDraw.Draw(image)
        draw.text((left + 150, top + 26 + rise), typed, font=self.typing_face, fill=EDGE)
        typing = u < 1.4
        if typing or int(u * 4) % 2 == 0:
            end = left + 150 + draw.textlength(typed, font=self.typing_face) + 8
            draw.rectangle((end, top + 28 + rise, end + 6, top + 100 + rise), fill=EDGE)

    def draw_button(self, image: Image.Image, u: float):
        left, top, right, bottom = self.BUTTON
        scale, alpha = popped(u, 1.35)
        if u > 1.95:  # a soft pulse every half second once it's up
            q = clamp01(((u - 1.95) % 0.5) / 0.4)
            if 0 < q < 1:
                scale *= 1 + 0.06 * math.sin(math.pi * q)
        paste_scaled(image, self.button, ((left + right) / 2 + 8, (top + bottom) / 2 + 13), scale, alpha)
        self.draw_pish(image, smoothstep(clamp01((u - 1.55) / 0.35)))
        self.draw_tap(image, u, (right - 84, (top + bottom) / 2))

    def draw_pish(self, image: Image.Image, rise: float):
        """Pish comes up from behind the button's top edge and rests his paws on it."""
        if rise <= 0:
            return
        left, top = self.BUTTON[0], self.BUTTON[1]
        paws_line = top + 52  # where his paws rest, in front of the button
        pish_top = paws_line - self.pish.height * rise
        hidden_below = top + (paws_line - top) * rise
        visible = round(hidden_below - pish_top)
        if visible <= 0:
            return
        part = self.pish.crop((0, 0, self.pish.width, min(self.pish.height, visible)))
        image.paste(part, (left + 40, round(pish_top)), part)

    @staticmethod
    def draw_tap(image: Image.Image, u: float, at: tuple):
        """A tap ring from the play arrow, as if a finger pressed it."""
        p = clamp01((u - 2.05) / 0.45)
        if p <= 0 or p >= 1:
            return
        layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
        radius = 50 + 140 * smoothstep(p)
        ImageDraw.Draw(layer).ellipse((at[0] - radius, at[1] - radius, at[0] + radius, at[1] + radius),
                                      outline=(255, 255, 255, int(220 * (1 - p))), width=10)
        image.paste(layer, (0, 0), layer)


def render_video(clip: Clip, folder: str, out: str):
    encoder = subprocess.Popen(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s",
         f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt",
         "yuv420p", "-movflags", "+faststart", out],
        stdin=subprocess.PIPE)
    badge = make_badge()
    words_face = font(clip.layout.words_size)
    clip_t = 0.0
    for number, shot in enumerate(clip.shots, start=1):
        lines = [shadowed_text(text, words_face, colour, 12) for text, colour, _ in shot.words]
        count = frame_count(shot)
        for index, frame in enumerate(read_frames(source_path(folder, shot.recording), shot.start, count)):
            t = index / FPS
            zoom = shot.zoom[0] + (shot.zoom[1] - shot.zoom[0]) * (index / max(1, count - 1))
            image = compose(clip.layout, frame, aim_at(shot, t), zoom)
            words_layer(image, lines, shot.words, t, clip.layout)
            badge_layer(image, badge, clip_t + t, clip)
            encoder.stdin.write(image.tobytes())
        clip_t += count / FPS
        print(f"shot {number}/{len(clip.shots)}: {shot.recording} {shot.start}-{shot.end} s")
    recording, at, centre = clip.end_card_back
    card = EndCard(still(folder, recording, at), centre)
    for index in range(round(clip.end_card * FPS)):
        encoder.stdin.write(card.frame(index / FPS).tobytes())
    encoder.stdin.close()
    if encoder.wait() != 0:
        sys.exit("ffmpeg could not encode the video")


def render_sound(clip: Clip, folder: str, out: str):
    """Each shot's own sound, faded at the cuts, silence under the end card, brought to -14 LUFS."""
    command = [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-y"]
    parts = []
    for index, shot in enumerate(clip.shots):
        length = frame_count(shot) / FPS
        command += ["-ss", f"{shot.start:.3f}", "-t", f"{length + 0.05:.3f}", "-i", source_path(folder, shot.recording)]
        parts.append(
            f"[{index}:a]atrim=0:{length:.4f},asetpts=PTS-STARTPTS,afade=t=in:d={CUT_FADE},"
            f"afade=t=out:st={length - CUT_FADE:.4f}:d={CUT_FADE}[a{index}]")
    streams = "".join(f"[a{index}]" for index in range(len(clip.shots)))
    parts.append(f"{streams}concat=n={len(clip.shots)}:v=0:a=1[joined]")
    parts.append(f"[joined]apad=pad_dur={clip.end_card},loudnorm=I=-14:TP=-1.5:LRA=11[out]")
    command += ["-filter_complex", ";".join(parts), "-map", "[out]", "-ar", "48000", "-c:a", "aac", "-b:a", "192k", out]
    subprocess.run(command, check=True)


def clip_length(clip: Clip) -> float:
    return sum(frame_count(shot) for shot in clip.shots) / FPS + clip.end_card


def voice_lines(clip: Clip) -> list:
    """(seconds into the clip, words) of every shot's line, then the end card's."""
    lines, start = [], 0.0
    for shot in clip.shots:
        if shot.say:
            lines.append((start + shot.say[0], shot.say[1]))
        start += frame_count(shot) / FPS
    lines.append((start + clip.end_card_say[0], clip.end_card_say[1]))
    return lines


def render_voice(clip: Clip, model_folder: str, speaker: str, out: str):
    """The voice-over as one track the clip's length, each line at its time (a line waits when a slow voice runs long)."""
    import numpy
    import soundfile
    from kokoro_onnx import Kokoro

    kokoro = Kokoro(os.path.join(model_folder, "kokoro-v1.0.onnx"), os.path.join(model_folder, "voices-v1.0.bin"))
    if speaker not in kokoro.get_voices():
        sys.exit(f"no voice {speaker!r}; one of: {', '.join(kokoro.get_voices())}")
    length = clip_length(clip)
    track, rate, free_from = None, 0, 0.0
    for at, words in voice_lines(clip):
        samples, rate = kokoro.create(words, voice=speaker, speed=clip.speed, lang="en-us")
        if track is None:
            track = numpy.zeros(round(length * rate), dtype=numpy.float32)
        at = max(at, free_from)
        ends = at + len(samples) / rate
        if ends > length:
            sys.exit(f"the voice runs past the clip's end on {words!r}: shorten a line or pick a quicker voice")
        begin = round(at * rate)
        end = min(len(track), begin + len(samples))
        track[begin:end] += samples[: end - begin]
        free_from = ends + VOICE_GAP
        print(f"voice {at:5.2f}-{ends:5.2f} s: {words}")
    soundfile.write(out, track, rate)


def mix_voice(sound: str, voice: str, out: str, with_game: bool):
    """The voice over the game's sound (turned down while it speaks) or alone, brought to -14 LUFS."""
    voice_in = "aresample=48000,pan=stereo|c0=c0|c1=c0"
    if with_game:
        inputs = ["-i", sound, "-i", voice]
        graph = (
            f"[1:a]{voice_in},loudnorm=I=-15:TP=-2,aresample=48000,asplit=2[key][said];"
            "[0:a][key]sidechaincompress=threshold=0.03:ratio=5:attack=10:release=400[ducked];"
            "[ducked][said]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5:LRA=11[out]")
    else:
        inputs = ["-i", voice]
        graph = f"[0:a]{voice_in},loudnorm=I=-14:TP=-1.5:LRA=11[out]"
    subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-y", *inputs, "-filter_complex", graph, "-map", "[out]",
         "-ar", "48000", "-c:a", "aac", "-b:a", "192k", out],
        check=True)


def mux(video: str, sound: str, out: str):
    subprocess.run(
        [ffmpeg_exe(), "-hide_banner", "-loglevel", "error", "-y", "-i", video, "-i", sound, "-map", "0:v", "-map",
         "1:a", "-c", "copy", "-shortest", "-movflags", "+faststart", out],
        check=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Cuts the vertical clips for TikTok, Shorts and Reels.")
    parser.add_argument("recordings", help="the folder with the owner's recordings")
    parser.add_argument("out", help="the folder the clips are written to")
    parser.add_argument("--clip", choices=sorted(CLIPS), default="loop", help="which clip (default loop)")
    parser.add_argument("--voice", metavar="KOKORO_FOLDER", help="add the AI voice-over (Kokoro's two model files)")
    parser.add_argument("--speaker", help="the Kokoro voice (default: the clip's own)")
    parser.add_argument("--reuse-video", action="store_true", help="take the picture from the clip's silent file in OUT")
    return parser.parse_args()


def main():
    args = parse_args()
    clip = CLIPS[args.clip]
    used = {shot.recording for shot in clip.shots} | {clip.end_card_back[0]}
    missing = [RECORDINGS[key] for key in sorted(used) if not os.path.exists(source_path(args.recordings, key))]
    if missing:
        sys.exit(f"missing recordings in {args.recordings}: {', '.join(missing)}")
    os.makedirs(args.out, exist_ok=True)
    silent = os.path.join(args.out, f"{clip.name}_silent.mp4")
    if args.reuse_video and not os.path.exists(silent):
        sys.exit(f"--reuse-video needs {silent}: run once without it")
    work = tempfile.mkdtemp(prefix="short_")
    try:
        if not args.reuse_video:
            video = os.path.join(work, "video.mp4")
            render_video(clip, args.recordings, video)
            shutil.copyfile(video, silent)
        sound = os.path.join(work, "sound.m4a")
        render_sound(clip, args.recordings, sound)
        written = [silent, os.path.join(args.out, f"{clip.name}.mp4")]
        mux(silent, sound, written[-1])
        if args.voice:
            voice = os.path.join(work, "voice.wav")
            render_voice(clip, args.voice, args.speaker or clip.speaker, voice)
            for suffix, with_game in (("_voice", True), ("_voice_only", False)):
                mixed = os.path.join(work, f"sound{suffix}.m4a")
                mix_voice(sound, voice, mixed, with_game)
                written.append(os.path.join(args.out, f"{clip.name}{suffix}.mp4"))
                mux(silent, mixed, written[-1])
        print(f"wrote {clip_length(clip):.1f} s: " + ", ".join(os.path.basename(path) for path in written))
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
