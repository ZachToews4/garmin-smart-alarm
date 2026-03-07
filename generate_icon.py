#!/usr/bin/env python3
"""
Generate the Smart Alarm launcher icon (70x70 px PNG).
Draws a classic alarm clock on a dark blue rounded-square background.
"""

from PIL import Image, ImageDraw
import math, os

SIZE    = 70
HALF    = SIZE // 2
OUT     = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "resources", "drawables", "launcher_icon.png")

# ── Palette ───────────────────────────────────────────────────────────────────
BG          = (18,  42,  100)   # dark navy
BG_GRAD     = (10,  25,   65)   # slightly darker for "bottom" of bg
CLOCK_FACE  = (255, 255, 255)   # white clock body
CLOCK_RIM   = (200, 220, 255)   # light blue rim
BELL_COL    = (255, 210,   0)   # yellow bells
HAND_COL    = (255,  80,  80)   # red alarm hands
TICK_COL    = (140, 160, 200)   # subtle tick marks
SHINE       = (255, 255, 255, 80)  # alpha highlight

# ── Canvas ────────────────────────────────────────────────────────────────────
img  = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
d    = ImageDraw.Draw(img)

# ── Background: rounded square ────────────────────────────────────────────────
r = 14  # corner radius
d.rounded_rectangle([0, 0, SIZE-1, SIZE-1], radius=r, fill=BG)
# Subtle top-highlight for depth
d.rounded_rectangle([2, 2, SIZE-3, SIZE//2], radius=r-2, fill=BG_GRAD + (60,))

# ── Bell feet (two small rounded bumps at the bottom) ────────────────────────
foot_r = 4
foot_y = SIZE - 12
d.ellipse([HALF - 16 - foot_r, foot_y - foot_r,
           HALF - 16 + foot_r, foot_y + foot_r], fill=BELL_COL)
d.ellipse([HALF + 16 - foot_r, foot_y - foot_r,
           HALF + 16 + foot_r, foot_y + foot_r], fill=BELL_COL)
# Connect feet with a bar
d.rectangle([HALF - 16, foot_y - 2, HALF + 16, foot_y + 2], fill=BELL_COL)

# ── Bell domes (two on top of the clock) ─────────────────────────────────────
bell_r = 7
bell_y_top = 9
# Left bell
d.pieslice([HALF - 21 - bell_r, bell_y_top,
            HALF - 21 + bell_r, bell_y_top + bell_r * 2],
           start=180, end=0, fill=BELL_COL)
# Right bell
d.pieslice([HALF + 21 - bell_r, bell_y_top,
            HALF + 21 + bell_r, bell_y_top + bell_r * 2],
           start=180, end=0, fill=BELL_COL)
# Hammer dots
d.ellipse([HALF - 21 - 2, bell_y_top + bell_r - 2,
           HALF - 21 + 2, bell_y_top + bell_r + 2], fill=(255,255,255))
d.ellipse([HALF + 21 - 2, bell_y_top + bell_r - 2,
           HALF + 21 + 2, bell_y_top + bell_r + 2], fill=(255,255,255))

# ── Clock body ────────────────────────────────────────────────────────────────
clock_cx  = HALF
clock_cy  = 38
clock_r   = 20

# Rim (slightly larger circle)
d.ellipse([clock_cx - clock_r - 2, clock_cy - clock_r - 2,
           clock_cx + clock_r + 2, clock_cy + clock_r + 2],
          fill=CLOCK_RIM)

# Face
d.ellipse([clock_cx - clock_r, clock_cy - clock_r,
           clock_cx + clock_r, clock_cy + clock_r],
          fill=CLOCK_FACE)

# ── Tick marks (12 positions) ─────────────────────────────────────────────────
for i in range(12):
    angle = math.radians(i * 30 - 90)
    major = (i % 3 == 0)
    r_outer = clock_r - 1
    r_inner = clock_r - (4 if major else 2)
    x1 = clock_cx + r_outer * math.cos(angle)
    y1 = clock_cy + r_outer * math.sin(angle)
    x2 = clock_cx + r_inner * math.cos(angle)
    y2 = clock_cy + r_inner * math.sin(angle)
    d.line([(x1, y1), (x2, y2)],
           fill=(100, 120, 160), width=2 if major else 1)

# ── Clock hands (alarm set at ~7:00) ─────────────────────────────────────────
# Hour hand — pointing to 7
hour_angle  = math.radians(7 * 30 - 90)   # 7 o'clock = 210°
hour_len    = clock_r - 7
d.line([(clock_cx, clock_cy),
        (clock_cx + hour_len * math.cos(hour_angle),
         clock_cy + hour_len * math.sin(hour_angle))],
       fill=(30, 30, 80), width=3)

# Minute hand — pointing to 12
min_angle = math.radians(-90)   # 12 o'clock = top
min_len   = clock_r - 4
d.line([(clock_cx, clock_cy),
        (clock_cx + min_len * math.cos(min_angle),
         clock_cy + min_len * math.sin(min_angle))],
       fill=(30, 30, 80), width=2)

# Center dot
d.ellipse([clock_cx - 2, clock_cy - 2,
           clock_cx + 2, clock_cy + 2], fill=(30, 30, 80))

# ── Alarm indicator lines (small chevrons in red at ~7:00 position) ───────────
alarm_angle = math.radians(7 * 30 - 90)
ax = clock_cx + (clock_r - 5) * math.cos(alarm_angle)
ay = clock_cy + (clock_r - 5) * math.sin(alarm_angle)
d.ellipse([ax - 2, ay - 2, ax + 2, ay + 2], fill=HAND_COL)

# ── Subtle gloss highlight (top-left arc) ─────────────────────────────────────
shine = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd    = ImageDraw.Draw(shine)
sd.pieslice([clock_cx - clock_r + 2, clock_cy - clock_r + 2,
             clock_cx + 2,           clock_cy + 2],
            start=200, end=310, fill=(255, 255, 255, 40))
img = Image.alpha_composite(img, shine)

# ── Save ──────────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img.save(OUT)
print(f"Saved {OUT}")
